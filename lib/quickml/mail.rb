#
# quickml/mail - a part of quickml server
#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'kconv'

module QuickML
  class MailSender
    def initialize (smtp_host, smtp_port, use_xverp = false)
      @smtp_port = smtp_port
      @smtp_host = smtp_host
      @use_xverp = use_xverp
      @xverp_available = false
    end

    def send (message, mail_from, recipients)
      recipients = [recipients] if recipients.kind_of?(String)
      s = TCPSocket.open(@smtp_host, @smtp_port) 
      send_command(s, nil, 220)
      send_command(s, "EHLO #{Socket.gethostname}", 250)
      if @use_xverp and @xverp_available and (not mail_from.empty?)
        send_command(s, "MAIL FROM: <#{mail_from}> XVERP===", 250)
      else
        send_command(s, "MAIL FROM: <#{mail_from}>", 250)
      end
      recipients.each {|recipient|
        send_command(s, "RCPT TO: <#{recipient}>", 250)
      }
      send_command(s, "DATA", 354)
      message.each_line {|line|
        line.sub!(/\r?\n/, '')
        line.sub!(/^\./, "..")
        line << "\r\n"
        s.print(line)
      }
      send_command(s, ".", 250)
      send_command(s, "QUIT", 221)
      s.close
    end

    private
    def send_command (s, command, code)
      s.print(command + "\r\n") if command
      begin
        line = s.gets
        @xverp_available = true if /^250-XVERP/.match(line)
      end while line[3] == ?-

      return_code = line[0,3].to_i
      if return_code == code
        line
      else
        raise "smtp-error: #{command} => #{line}"
      end
    end
  end

  class Mail
    def initialize
      @mail_from = nil
      @recipients = []
      @header = []
      @body = ""
      @charset = nil
      @content_type = nil
      @bare = nil
    end
    attr_reader :recipients
    attr_reader :charset
    attr_reader :content_type
    attr_accessor :mail_from
    attr_accessor :body
    attr_accessor :bare

    private
    def get_content_type
      if %r!([-\w]+/[-\w]+)! =~ self["Content-Type"]
	$1.downcase
      else
	nil
      end
    end

    def get_charset
      if /charset=("?)([-\w]+)\1/ =~ self["Content-Type"]
	$2.downcase
      else
	nil
      end
    end

    def remove_comment_in_field (field)
      field = field.toeuc
      true while field.sub!(/\([^()]*?\)/, "")
      field
    end

    # foo@QuickML.CoM => foo@quickml.com
    # "foo"@example.com => foo@example.com
    def normalize_address (address)
      name, domain = address.split('@')
      name.gsub!(/^"(.*)"$/, '\1')
      if domain
	name + "@" + domain.downcase
      else
	address
      end
    end

    def collect_address (field)
      address_regex = 
	/(("?)[-0-9a-zA-Z_.+?\/]+\2@[-0-9a-zA-Z]+\.[-0-9a-zA-Z.]+)/ #/
      addresses = []
      parts = remove_comment_in_field(field).split(',')
      parts.each {|part|
	if (/<(.*?)>/ =~ part) or (address_regex =~ part)
	  addresses.push(normalize_address($1))
	end
      }
      addresses.uniq
    end

    public
    def to_s
      str = ""
      each_field {|key, value| str << sprintf("%s: %s\n", key, value) }
      str << "\n"
      str << @body
      str
    end

    def parts
      parts = @body.split(/^--#{Regexp.escape(self.boundary)}\n/)
      parts.shift  # Remove the first empty string.
      parts
    end

    def add_recipient (address)
      @recipients.push(normalize_address(address))
    end

    def clear_recipients
      @recipients = []
    end

    def [] (key)
      field = @header.find {|field| key.downcase == field.first.downcase}
      if field then field.last else "" end
    end

    def unshift_field (key, value)
      field = [key, value]  # Use Array for preserving order of the header
      @header.unshift(field)
    end

    def push_field (key, value)
      field = [key, value]  # Use Array for preserving order of the header
      @header.push(field)
    end

    def concat_field (value)
      lastfield = @header.last
      @header.pop
      push_field(lastfield.first, lastfield.last + "\n" + value)
    end

    def each_field
      @header.each {|field|
	yield(field.first, field.last)
      }
    end

    def looping?
      !self["X-QuickML"].empty?
    end

    def from
      address = if not self["From"].empty?
		  collect_address(self["From"]).first
		else
		  @mail_from
		end
      address = "unknown" if address.nil? or address.empty?
      normalize_address(address)
    end

    def collect_cc
      if self["Cc"]
	collect_address(self["Cc"])
      else
	[]
      end
    end

    def collect_to
      if self["To"]
	collect_address(self["To"])
      else
	[]
      end
    end

    def valid?
      (not @recipients.empty?) and @mail_from
    end

    def empty_body?
      return false if @body.length > 100
      /\A[\s¡¡]*\Z/ =~ @body.toeuc # including Japanese zenkaku-space.
    end

    def multipart?
      %r!^multipart/mixed;\s*boundary=("?)(.*)\1!i =~ self["Content-Type"] #"
    end

    def boundary
      if %r!^multipart/mixed;\s*boundary=("?)(.*)\1!i =~ self["Content-Type"]#"
	$2
      else
	nil
      end
    end


    def read (string)
      header, body = string.split(/\n\n/, 2)
      attr = nil
      header.split("\n").each {|line|
	line.xchomp!
	if /^(\S+):\s*(.*)/=~ line
	  attr = $1
	  push_field(attr, $2)
	elsif attr
	  concat_field(line)
	end
      }
      @bare = string
      @charset = get_charset
      @content_type = get_content_type
      @body = (body or "")
    end

    class << self
      def send_mail (smtp_host, smtp_port, logger, optional = {})
	mail_from = optional[:mail_from]
	recipients = optional[:recipients]
	header = optional[:header]
	body = optional[:body]
        if optional[:recipient]
          raise unless optional[:recipient].kind_of?(String)
          recipients = [optional[:recipient]] 
        end
	raise if mail_from.nil? or recipients.nil? or 
	  body.nil? or header.nil?

	contents = ""
	header.each {|field|
	  key = field.first; value = field.last
	  contents << "#{key}: #{value}\n" if key.kind_of?(String)
	}
	contents << "\n"
	contents << body
	begin
          sender = MailSender.new(smtp_host, smtp_port, true)
          sender.send(contents, mail_from, recipients)
	rescue => e
	  logger.log "Error: Unable to send mail: #{e.class}: #{e.message}"
	end
      end

      def address_of_domain? (address, domain)
	domainpat = Regexp.new('[.@]' + Regexp.quote(domain) + '$',  #'
			       Regexp::IGNORECASE)
	if domainpat =~ address then true else false end
      end

      def encode_field (field)
	field.toeuc.gsub(/[¡¡-ô¤]\S*\s*/) {|x|
	  x.scan(/.{1,10}/).map {|y|
	    "=?iso-2022-jp?B?" + y.tojis.to_a.pack('m').chomp + "?="
	  }.join("\n ")
	}
      end

      def decode_subject (subject)
	NKF.nkf("-e", subject.gsub(/\n\s*/, " "))
      end

      def clean_subject (subject)
	subject = Mail.decode_subject(subject)
	subject.gsub!(/(?:\[[^\]]+:\d+\])/, "")
	subject.sub!(/(?:Re:\s*)+/i, "Re: ")
	return subject
      end

      def rewrite_subject (subject, name, count)
	subject = Mail.clean_subject(subject)
	subject = "[#{name}:#{count}] " + subject
	Mail.encode_field(subject)
      end

      def join_parts (parts, boundary)
	body = ""
	body << sprintf("--%s\n", boundary)
	body << parts.join("--#{boundary}\n")
	body
      end
    end
  end
end

