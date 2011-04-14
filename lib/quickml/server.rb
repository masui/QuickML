#
# quickml/server - a part of quickml server
#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'etc'
require 'socket'
require 'net/smtp'
require 'thread'
require 'thwait'
require 'timeout'
require 'quickml/gettext'
require 'quickml/utils'
require 'time'

module QuickML
  class Session
    include GetText::GetText

    def initialize (config, socket)
      @socket = socket
      @config = config
      @command_table = [:helo, :ehlo, :noop, :quit, :rset, :rcpt, :mail, :data]
      @hello_host = "hello.host.invalid"
      @protocol = nil
      @peer_hostname = @socket.hostname
      @peer_address = @socket.address
      @remote_host = (@peer_hostname or @peer_address)
      @logger = @config.logger
      @catalog = @config.catalog
      @data_finished = false
      @my_hostname = if @config.port == 25 then 
		       Socket.gethostname 
		     else 
		       "localhost"
		     end
      @message_charset = nil
    end

    private
    def helo (mail, arg)
      @hello_host = arg.split.first
      @socket.puts "250 #{@my_hostname}"
      @protocol = "SMTP"
    end

    def ehlo (mail, arg)
      @hello_host = arg.split.first
      @socket.puts "250-#{@my_hostname}"
      @socket.puts "250 PIPELINING"
      @protocol = "ESMTP"
    end

    def noop (mail, arg)
      @socket.puts "250 ok"
    end

    def quit (mail, arg)
      @socket.puts "221 Bye"
      close
    end

    def rset (mail, arg)
      mail.mail_from = nil
      mail.clear_recipients
      @socket.puts "250 ok"
    end

    def mail (mail, arg)
      if @protocol.nil?
	@socket.puts "503 Error: send HELO/EHLO first"
      elsif /^From:\s*<(.*)>/i =~ arg or /^From:\s*(.*)/i =~ arg 
	mail.mail_from = $1
	@socket.puts "250 ok"
      else
	@socket.puts "501 Syntax: MAIL FROM: <address>"
      end
    end

    def rcpt (mail, arg)
      if mail.mail_from.nil?
	@socket.puts "503 Error: need MAIL command"
      elsif /^To:\s*<(.*)>/i =~ arg or /^To:\s*(.*)/i =~ arg
	address = $1
	if Mail.address_of_domain?(address, @config.domain)
	  mail.add_recipient(address)
	  @socket.puts "250 ok"
	else
	  @socket.puts "554 <#{address}>: Recipient address rejected"
	  @logger.vlog "Unacceptable RCPT TO:<#{address}>"
	end
      else
	@socket.puts "501 Syntax: RCPT TO: <address>"
      end
    end

    def received_field
      sprintf("from %s (%s [%s])\n" + 
	      "	by %s (QuickML) with %s;\n" + 
	      "	%s", 
	      @hello_host,
	      @peer_hostname, 
	      @peer_address,
	      @my_hostname,
	      @protocol,
	      Time.now.rfc2822)
    end

    def end_of_data? (line)
      # line.xchomp == "."
      line == ".\r\n"
    end

    def read_mail (mail)
      len = 0
      lines = []
      while line = @socket.safe_gets
	break if end_of_data?(line)
	len += line.length
	if len > @config.max_mail_length
	  mail.read(lines.join('')) # Generate a header for an error report.
	  raise TooLargeMail 
	end
	line.sub!(/^\.\./, ".") # unescape
	line.normalize_eol!
	lines << line
	# I don't know why but constructing mail_string with
	# String#<< here is very slow.
	# mail_string << line  
      end
      mail_string = lines.join('')
      @data_finished = true
      mail.read(mail_string)
      mail.unshift_field("Received", received_field)
    end

    def data (mail, arg)
      if mail.recipients.empty?
	@socket.puts "503 Error: need RCPT command"
      else
	@socket.puts "354 send the mail data, end with .";
	begin
	  read_mail(mail)
	ensure
	  @message_charset = mail.charset
	end
	@socket.puts "250 ok"
      end
    end

    def connect
      def @socket.puts(*objs)
	objs.each {|x|
	  begin
	    self.print x.xchomp, "\r\n"
	  rescue Errno::EPIPE
	  end
	}
      end
      @socket.puts "220 #{@my_hostname} ESMTP QuickML"
      @logger.vlog "Connect: #{@remote_host}"
    end

    def discard_data
      begin
	while line = @socket.safe_gets
	  break if end_of_data?(line)
	end
      rescue TooLongLine
	retry
      end
    end

    def cleanup_connection
      unless @data_finished
	discard_data
      end
      @socket.puts "221 Bye"
      close
    end

    # FIXME: this is the same method of QuickML#content_type
    def content_type
      if @message_charset
        @config.content_type + "; charset=#{@message_charset}" 
      else
        @config.content_type
      end
    end

    def report_too_large_mail (mail)
      header = []
      subject = Mail.encode_field(_("[QuickML] Error: %s", mail["Subject"]))
      header.push(["To",	mail.from],
		  ["From",	@config.postmaster],
		  ["Subject",	subject],
                  ["Content-Type", content_type])

      max  = @config.max_mail_length.commify
      body =   _("Sorry, your mail exceeds the limitation of the length.\n")
      body <<  _("The max length is %s bytes.\n\n", max)
      orig_subject = codeconv(Mail.decode_subject(mail['Subject']))
      body << "Subject: #{orig_subject}\n"
      body << "To: #{mail['To']}\n"
      body << "From: #{mail['From']}\n"
      body << "Date: #{mail['Date']}\n"
      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger,
		     :mail_from => '', 
		     :recipient => mail.from,
		     :header => header,
		     :body => body)
    end

    def close
      return if @socket.closed?
      @socket.close
      @logger.vlog "Closed: #{@remote_host}"
    end

    def receive_mail (mail)
      while line = @socket.safe_gets
	line.xchomp!
	command, arg = line.split(/\s+/, 2)
	command = command.downcase.intern  # "HELO" => :helo
	if @command_table.include?(command)
	  @logger.vlog "Command: #{line}"
	  send(command, mail, arg)
	else
	  @logger.vlog "Unknown SMTP Command: #{command} #{arg}"
	  @socket.puts "502 Error: command not implemented"
	end
	break if command == :quit or command == :data
      end
    end

    def process
      until @socket.closed?
	begin
	  mail = Mail.new
	  receive_mail(mail)
	  if mail.valid?
	    processor = Processor.new(@config, mail)
	    processor.process
	  end
	rescue TooLargeMail
	  cleanup_connection
	  report_too_large_mail(mail) if mail.valid?
	  @logger.log "Too Large Mail: #{mail.from}"
	rescue TooLongLine
	  cleanup_connection
	  @logger.log "Too Long Line: #{mail.from}"
	end
      end
    end

    def _start
      begin
	connect
	timeout(@config.timeout) {
	  process
	}
      rescue TimeoutError
	@logger.vlog "Timeout: #{@remote_host}"
      ensure
	close
      end
    end

    public
    def start
      start_time = Time.now
      _start
      elapsed = Time.now - start_time
      @logger.vlog "Session finished: #{elapsed} sec."
    end
  end

  class Server
    def initialize (config)
      @config = config
      @status = :stop
      @logger = @config.logger
      @server = TCPServer.new(@config.bind_address, @config.port)
    end

    def accept
      running_sessions = []
      @status = :running
      while @status == :running
	begin 
	  t = Thread.new(@server.accept) {|s|
	    process_session(s)
	  }
	  t.abort_on_exception = true
	  running_sessions.push(t)
	rescue Errno::ECONNABORTED # caused by @server.shutdown
	rescue Errno::EINVAL
	end
	running_sessions.delete_if {|t| t.status == false }
	if running_sessions.length >= @config.max_threads
	  ThreadsWait.new(running_sessions).next_wait
	end
      end
      running_sessions.each {|t| t.join }
    end

    def process_session (socket)
      begin
	session = Session.new(@config, socket)
	session.start
      rescue Exception => e
	@logger.log "Unknown Session Error: #{e.class}: #{e.message}"
	@logger.log e.backtrace
      end
    end

    def write_pid_file
      File.safe_open(@config.pid_file, "w") {|f|
	f.puts Process.pid
      }
    end

    def read_pid_file
      pid = nil
      File.safe_open(@config.pid_file, "r") {|f|
	pid = f.gets.chomp.to_i
      }
      pid
    end

    def remove_pid_file
      File.safe_unlink(@config.pid_file) if Process.pid == read_pid_file
    end

    public
    def shutdown
      @server.shutdown
      @status = :shutdown
    end

    def start
      raise "server already started" if @status != :stop
      write_pid_file
      @logger.log sprintf("Server started at %s:%d [%d]",
                          "localhost", @config.port, Process.pid)
      accept
      @logger.log "Server exited [#{Process.pid}]"
      remove_pid_file
    end
  end
end
