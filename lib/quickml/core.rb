#
# quickml/core - a part of quickml server
#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#
$KCODE='e'
require 'quickml/utils'
require 'quickml/gettext'

module QuickML
  class QuickMLException < StandardError; end
  class TooLargeMail < QuickMLException; end
  class TooManyMembers < QuickMLException; end
  class InvalidMLName < QuickMLException; end
  class InvalidCreator < QuickMLException; end
  class InvalidMembers < QuickMLException; end
  class InvalidSender < QuickMLException; end

  # It preserves case information. but it accepts an
  # address case-insensitively for member management.
  class IcaseArray < Array
    def include? (item)
      if self.find {|x| x.downcase == item.downcase } 
	true
      else
	false
      end
    end

    def delete (item)
      self.replace(self.find_all {|x| x.downcase != item.downcase })
    end
  end

  class IcaseHash < Hash
    def include? (key)
      super(key.downcase)
    end

    def delete (key)
      super(key.downcase)
    end

    def [] (key)
      super(key.downcase)
    end	

    def []= (key, value)
      super(key.downcase, value)
    end	
  end

  class ErrorInfo
    def initialize (count = 0, last_error_time = Time.at(0))
      @count = count
      @last_error_time = last_error_time
    end
    attr_reader :count
    attr_reader :last_error_time

    def inc_count
      @count += 1
      @last_error_time = Time.now
    end
  end

  class QuickML
    include GetText::GetText
    def initialize (config, address, creator = nil, message_charset = nil)
      @config = config
      @address = address
      @name = get_name(@address)
      raise InvalidMLName unless QuickML.valid_name?(@name)
      @short_name = @name.split("@").first

      @return_address = generate_return_address

      @members_file = File.join(@config.data_dir, @name)
      @count_file = File.join(@config.data_dir, @name + ",count")
      @forwardp_file = File.join(@config.data_dir, @name + ",forward")
      @alertedp_file = File.join(@config.data_dir, @name + ",alerted")
      @permanentp_file = File.join(@config.data_dir, @name + ",permanent")
      @unlimitedp_file = File.join(@config.data_dir, @name + ",unlimited")
      @charset_file = File.join(@config.data_dir, @name + ",charset")
      @ml_config_file = File.join(@config.data_dir, @name + ",config")

      @waiting_members_file = File.join(@config.data_dir, @name + 
                                        ",waiting-members")
      @waiting_message_file = File.join(@config.data_dir, @name + 
                                        ",waiting-message")
      @member_added_p = false
      @added_members = []

      @logger = @config.logger
      @catalog = @config.catalog

      if @config.sender_check
        raise InvalidSender unless valid_members?(creator, @config.sender_addresses)
      end
      if newly_created? and @config.creator_check
        raise InvalidCreator unless valid_members?(creator, @config.creator_addresses)
      end

      init_ml_config
      init_members
      init_count
      init_charset

      @message_charset = (message_charset or @charset)
      @logger.log "[#{@name}]: New ML by #{creator}" if newly_created?
    end
    attr_reader :name
    attr_reader :short_name
    attr_reader :active_members
    attr_reader :former_members
    attr_reader :address
    attr_reader :return_address
    attr_reader :count
    attr_reader :charset
    attr_reader :max_members

    def valid_members? (address, pat)
      pat.each do |entry|
	return true if /#{entry}/i =~ address
      end
      false
    end
    
    def self.valid_name? (name)
      /^([0-9a-zA-Z_.-]+)(@[0-9a-zA-Z_.-]+)?$/ =~ name
    end

    private
    def init_ml_config
      ml_config = Hash.new
      begin
        eval(File.open(@ml_config_file).read).each {|key, value|
          ml_config[key] = value
        }
      rescue Exception
      end
      @max_members            = (ml_config[:max_members] or 
                                 @config.max_members)
      @max_mail_length        = (ml_config[:max_mail_length] or 
                                 @config.max_ml_mail_length or
                                 @config.max_mail_length)
      @ml_life_time           = (ml_config[:ml_life_time] or 
                                 @config.ml_life_time)
      @ml_alert_time          = (ml_config[:ml_alert_time] or 
                                 @config.ml_alert_time)
      @auto_unsubscribe_count = (ml_config[:auto_unsubscribe_count] or 
                                 @config.auto_unsubscribe_count)
      write_ml_config
    end

    def confirmation_address
      sprintf("confirm+%d+%s", 
              File.mtime(@waiting_message_file).to_i,
              @address)
    end

    def generate_return_address
      raise unless @address
      raise unless @short_name
      domain_part = @address.split("@").last
      if @config.use_qmail_verp
	# e.g. <foo=return=@quickml.com-@[]>
	@short_name + "=return=" + "@" + domain_part + "-@[]"
      else
	# e.g. <foo=return@quickml.com>
	@short_name + "=return" + "@" + domain_part
      end
    end

    def last_article_time
      if File.file?(@count_file)  then 
	File.mtime(@count_file) 
      else 
	Time.now 
      end
    end

    def get_name (address)
      raise InvalidMLName if /@.*@/ =~ address
      name, host = address.split("@")
      if host.nil?
	return name
      else
	fqdn = host.downcase
	domainpat = Regexp.new('^(.*)' + 
			       Regexp.quote("." + @config.domain) + '$') #'
	if domainpat =~ fqdn 
	  subdomain = $1
	  return name + "@" + subdomain
	else 
	  return name
	end
      end
    end

    def init_count
      @count = 0
      return unless File.exist?(@count_file)
      File.safe_open(@count_file, "r") {|f|
	@count = f.gets.chomp.to_i
      }
    end

    def inc_count
      @count += 1
      File.safe_open(@count_file, "w") {|f|
	f.puts @count
      }
    end

    def init_charset
      @charset = nil
      return unless File.exist?(@charset_file)
      File.safe_open(@charset_file, "r") {|f|
	@charset = f.gets.chomp
      }
    end

    def save_charset
      return if @message_charset.nil?
      File.safe_open(@charset_file, "w") {|f|
	f.puts @message_charset
      }
    end

    def init_members
      @active_members = IcaseArray.new
      @former_members = IcaseArray.new
      @error_members  = IcaseHash.new
      return unless File.exist?(@members_file)
      File.safe_open(@members_file, "r") {|f|
	f.each {|line| 
	  line.chomp!
	  if /^# (.*)/ =~ line  # removed address
	    @former_members.push($1) unless @former_members.include?($1)
	  elsif /^; (.*?) (\d+)(?: (\d+))?/ =~ line
	    address = $1
	    count= $2.to_i
	    last_error_time = if $3 then Time.at($3.to_i) else Time.at(0) end
	    @error_members[address]= ErrorInfo.new(count, last_error_time)
	  else
	    @active_members.push(line) unless @active_members.include?(line)
	  end
	}
      }
    end

    def save_member_file
      File.safe_open(@members_file, "w") {|f|
	@active_members.each {|address| f.puts address}
	@former_members.each {|address| f.puts "# " + address}
	@error_members.each {|address, error_info| 
	  f.printf("; %s %d %d\n", 
		   address, error_info.count, error_info.last_error_time.to_i)
	}
      }
    end

    # satoru@namazu.org => satoru@n...
    def obfuscate_address (address)
      address.sub(/(@.).*/, '\1...')
    end

    def member_list
      _("Members of <%s>:\n", @address) + 
	@active_members.map {|x| obfuscate_address(x)}.join("\n") + "\n"
    end

    def unsubscribe_info
      "\n" +
        _("How to unsubscribe from the ML:\n") +
        _("- Just send an empty message to <%s>.\n", @address) +
        _("- Or, if you cannot send an empty message for some reason,\n") +
        _("  please send a message just saying 'unsubscribe' to <%s>.\n", @address) +
        _("  (e.g., hotmail's advertisement, signature, etc.)\n")
    end

    def generate_header
      header  = sprintf("ML: %s\n", @address)
      @added_members.each {|address|
	header << _("New Member: %s\n", obfuscate_address(address))
      }
      header << "\n"
      header
    end

    def member_added?
      @member_added_p
    end

    def generate_footer (member_list_p = false)
      footer = "\n--\n" + "ML: #{@address}\n" + 
	_("Info: %s\n", @config.info_url)
      footer << unsubscribe_info if member_added?
      footer << "\n" + member_list if member_added? or member_list_p
      footer
    end

    def plain_text_body? (mail)
      (mail["Content-Type"] == "" or 
       %r!\btext/plain\b!i =~ mail["Content-Type"]) and
        (mail["Content-Transfer-Encoding"] == "" or
         /^[78]bit$/i =~ mail["Content-Transfer-Encoding"])
    end

    def rewrite_body (mail)
      header = generate_header if @member_added_p
      footer = generate_footer
      if mail.multipart?
	parts = mail.parts
	sub_mail = Mail.new
	sub_mail.read(parts.first)
	if sub_mail.content_type == "text/plain"
	  sub_mail.body = header + sub_mail.body if header
	  sub_mail.body = sub_mail.body + footer
	end
	parts[0] = sub_mail.to_s
	mail.body = Mail.join_parts(parts, mail.boundary)
      elsif plain_text_body?(mail)
	mail.body = header + mail.body if header
	mail.body += footer
      else
	mail.body
      end
    end

    def remove_alertedp_file
      File.safe_unlink(@alertedp_file)
    end

    def _submit (mail)
      inc_count
      save_charset
      remove_alertedp_file

      subject = Mail.rewrite_subject(mail["Subject"], @short_name, @count)
      body = rewrite_body(mail)
      header = []
      mail.each_field {|key, value|
	k = key.downcase
	next if k == "subject" or k == "reply-to"
	header.push([key, value])
      }
      header.push(["Subject",	subject],
		  ["Reply-To",	@address],
		  ["X-Mail-Count",@count])
      header.concat(quickml_fields)
      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger,
		     :mail_from => @return_address, 
		     :recipients => @active_members,
		     :header => header,
		     :body => body)
    end

    def quickml_fields
      [ ["Precedence",   "bulk"],
        ["X-ML-Address", @address],
	["X-ML-Name",	 @name],
	["X-ML-Info",	 @config.info_url],
	["X-QuickML",	 "true"]]
    end

    def remove_error_member (address)
      @error_members.delete(address)
    end

    def error_count (address)
      if @error_members.include?(address)
	@error_members[address].count
      else
	0
      end
    end

    def allowable_error_interval? (time)
      now  = Time.now
      past = now - @config.allowable_error_interval
      past < time && time <= now
    end

    def inc_error_count (address)
      unless @error_members.include?(address)
	@error_members[address] = ErrorInfo.new
      end
      unless allowable_error_interval?(@error_members[address].last_error_time)
	@error_members[address].inc_count
      end
      @error_members[address].count
    end

    def reset_error_member (address)
      return unless @error_members.include?(address)
      @error_members.delete(address)
      @logger.log "[#{@name}]: ResetError: #{address}"
      save_member_file
    end

    def content_type
      if @message_charset
        @config.content_type + "; charset=#{@message_charset}" 
      else
        @config.content_type
      end
    end

    public
    def exclude? (address)
      name, domain = address.split("@")
      Mail.address_of_domain?(address, @config.domain) or domain.nil?
    end

    def ml_config_exist?
      File.exist?(@ml_config_file)
    end

    def write_ml_config
      File.safe_open(@ml_config_file, "w") {|f|
	f.puts "{"
	f.printf("  :%s => %d,\n", :max_members,     @max_members)
	f.printf("  :%s => %d,\n", :max_mail_length, @max_mail_length)
	f.printf("  :%s => %d,\n", :ml_life_time,    @ml_life_time)
	f.printf("  :%s => %d,\n", :ml_alert_time,   @ml_alert_time)
	f.printf("  :%s => %d,\n", :auto_unsubscribe_count, 
                 @auto_unsubscribe_count)
	f.puts "}"
      }
    end

    def send_confirmation (creator_address)
      header = []
      subject = Mail.encode_field(_("[%s] Confirmation: %s",
				    @short_name, @address))
      header.push(["To",	creator_address],
		  ["From",	confirmation_address],
		  ["Subject",	subject],
                  ["Content-Type", content_type])

      body = _("Please simply reply this mail to create ML <%s>.\n",
               @address)
      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger, 
		     :mail_from => '', 
		     :recipient => creator_address,
		     :header => header,
		     :body => body)
      @logger.log "[#{@name}]: Send confirmation: #{confirmation_address} #{creator_address}"
    end

    def submit (mail)
      return if @active_members.empty?

      if mail.body.length > @max_mail_length
        report_too_large_mail(mail)
        @logger.log "[#{@name}]: Too Large Mail: #{mail.from}"
      else 
        reset_error_member(mail.from)
        start_time = Time.now
        _submit(mail)
        elapsed = Time.now - start_time
        @logger.log "[#{@name}:#{@count}]: Send: #{@config.smtp_host} #{elapsed} sec."
      end
    end

    def inactive?
      return false if forward? or permanent?
      last_article_time + @ml_life_time < Time.now
    end

    def need_alert?
      return false if forward? or permanent?
      alert_time = last_article_time + @ml_alert_time
      now = Time.now
      alert_time <= now && !alerted?
    end

    # FIXME: too similar to report_too_large_mail in server.rb
    def report_too_large_mail (mail)
      header = []
      subject = Mail.encode_field(_("[QuickML] Error: %s", mail["Subject"]))
      header.push(["To",	mail.from],
		  ["From",	@address],
		  ["Subject",	subject],
		  ["Content-Type", content_type])
      max  = @max_mail_length.commify
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

    def report_removed_member (error_address)
      return if @active_members.empty?
      subject = Mail.encode_field(_("[%s] Removed: <%s>", 
				    @short_name, error_address))
      header = []
      header.push(["To",	@address],
		  ["From",	@address],
		  ["Subject",	subject],
		  ["Reply-To",	@address],
		  ["Content-Type", content_type])
      header.concat(quickml_fields)

      body =  _("<%s> was removed from the mailing list:\n<%s>\n", 
		error_address, @address)
      body << _("because the address was unreachable.\n")
      body << generate_footer(true)

      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger, 
		     :mail_from => '', 
		     :recipients => @active_members,
		     :header => header,
		     :body => body)
      @logger.log "[#{@name}]: Notify: Remove #{error_address}"
    end

    def report_ml_close_soon
      return if @active_members.empty?
      subject = Mail.encode_field(_("[%s] ML will be closed soon", 
				    @short_name))

      header = []
      header.push(["To",	@address],
		  ["From",	@address],
		  ["Subject",	subject],
		  ["Reply-To",	@address],
		  ["Content-Type", content_type])
      header.concat(quickml_fields)

      time_to_close = last_article_time + @ml_life_time
      ndays = ((time_to_close - Time.now) / 86400.0).ceil
      datefmt = __("%Y-%m-%d %H:%M")

      body =  _("ML will be closed if no article is posted for %d days.\n\n",
		ndays)
      body << _("Time to close: %s.\n\n", time_to_close.strftime(datefmt))
      body << generate_footer(true)

      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger,
		     :mail_from => '', 
		     :recipients => @active_members,
		     :header => header,
		     :body => body)
      @logger.log "[#{@name}]: Alert: ML will be closed soon"
      File.safe_open(@alertedp_file, "w").close
    end

    def close
      File.safe_unlink(@members_file)
      File.safe_unlink(@count_file)
      File.safe_unlink(@charset_file)
      File.safe_unlink(@alertedp_file)
      File.safe_unlink(@waiting_members_file)
      File.safe_unlink(@waiting_message_file)
      File.safe_unlink(@ml_config_file)
      @logger.log "[#{@name}]: ML Closed"
    end

    def forward?
      File.exist?(@forwardp_file)
    end

    def permanent?
      File.exist?(@permanentp_file)
    end

    def unlimited?
      File.exist?(@unlimitedp_file)
    end

    def newly_created?
      !File.exist?(@members_file)
    end

    def confirmation_waiting?
      File.exist?(@waiting_members_file)
    end

    def alerted?
      File.exist?(@alertedp_file)
    end

    def validate_confirmation (time)
      File.exist?(@waiting_message_file) and 
        File.mtime(@waiting_message_file).to_i == time.to_i
    end

    def prepare_confirmation (mail)
      save_member_file # to create empty ML files.
      File.safe_open(@waiting_message_file, "w") {|f| f.print(mail.bare) }
      add_waiting_member(mail.from)
      mail.collect_cc.each {|address| 
        add_waiting_member(address)
      }
      send_confirmation(mail.from)
    end

    def accept_confirmation
      waiting_members = 
	File.safe_open(@waiting_members_file).readlines.map {|line| 
        line.chomp
      }
      waiting_message = File.safe_open(@waiting_message_file).read
      mail = Mail.new
      mail.read(waiting_message)

      waiting_members.each {|address|
        begin
          add_member(address)
        rescue TooManyMembers
        rescue InvalidMembers
        end
      }
      submit(mail)
      File.safe_unlink(@waiting_members_file)
      File.safe_unlink(@waiting_message_file)
      @logger.log "[#{@name}]: Accept confirmation: #{@addressconfirmation_address} #{@address}"
    end

    def add_waiting_member (address)
      File.safe_open(@waiting_members_file, "a") {|f|
        f.puts address
      }
    end

    def too_many_members?
      (not unlimited?) and (@active_members.length >= @max_members)
    end

    def remove_member (address)
      return unless @active_members.include?(address)
      @active_members.delete(address)
      @former_members.push(address)
      remove_error_member(address)
      save_member_file
      @logger.log "[#{@name}]: Remove: #{address}"
      close if @active_members.empty?
    end

    def add_member (address)
      if @config.member_check
        raise InvalidMembers unless valid_members?(address, @config.member_addresses)
      end
      if exclude?(address)
	@logger.vlog "Excluded: #{address}"
	return
      end
      return if @active_members.include?(address)
      raise TooManyMembers if too_many_members?
      @former_members.delete(address)
      @active_members.push(address)
      save_member_file
      @logger.log "[#{@name}]: Add: #{address}"
      @added_members.push(address)
      @member_added_p = true
    end

    def add_error_member (address)
      return unless @active_members.include?(address)
      prev_count = error_count(address)
      count = inc_error_count(address)
      if prev_count == count
	@logger.log "[#{@name}]: AddError: #{address} (not counted)"
      else
	@logger.log "[#{@name}]: AddError: #{address} #{count}"
      end
      save_member_file

      if error_count(address) >= @auto_unsubscribe_count
	remove_member(address)
	report_removed_member(address)
      end
    end
  end

  class ErrorMailHandler
    def initialize (config, message_charset)
      @config = config
      @logger = config.logger
      @message_charset = message_charset
    end

    private
    def handle_error (ml, error_address)
      @logger.log "ErrorMail: [#{ml.name}] #{error_address}"
      ml.add_error_member(error_address)
    end

    public
    def handle (mail)
      if /^(.*)=return=(.*?)@(.*?)$/ =~ mail.recipients.first
	mladdress = $1 + '@' + $3
	error_address = $2.sub(/=/, "@")
 	@config.ml_mutex(mladdress).synchronize {
	  ml = QuickML.new(@config, mladdress, nil, @message_charset)
 	  handle_error(ml, error_address)
 	}
      else
	@logger.vlog "Error: Use Postfix with XVERP to handle an error mail!"
      end
    end
  end

  class Processor
    include GetText::GetText

    def initialize (config, mail)
      @config = config
      @mail = mail
      @logger = @config.logger
      @catalog = @config.catalog
      if mail.multipart?
	sub_mail = Mail.new
	sub_mail.read(mail.parts.first)
	@message_charset = sub_mail.charset
      else
	@message_charset = mail.charset
      end
    end

    private

    # FIXME: this is the same method of QuickML#content_type
    def content_type
      if @message_charset
        @config.content_type + "; charset=#{@message_charset}" 
      else
        @config.content_type
      end
    end

    def generate_footer
      "\n--\n" + _("Info: %s\n", @config.info_url)
    end

    def report_rejection (ml)
      header = []
      subject = Mail.encode_field(_("[QuickML] Error: %s", @mail["Subject"]))
      header.push(["To",	@mail.from],
		  ["From",	ml.address],
		  ["Subject",	subject])

      body =  _("You are not a member of the mailing list:\n<%s>\n",
		ml.address)
      body << "\n"
      body <<  _("Did you send a mail with a different address from the address registered in the mailing list?\n")
      body <<  _("Please check your 'From:' address.\n")
      body << generate_footer
      body << "\n"

      body << _("----- Original Message -----\n")
      orig_subject = codeconv(Mail.decode_subject(@mail['Subject']))
      body << "Subject: #{orig_subject}\n"
      body << "To: #{@mail['To']}\n"
      body << "From: #{@mail['From']}\n"
      body << "Date: #{@mail['Date']}\n"
      body << "\n"
      if @mail.multipart?
        ["Content-Type", "Mime-Version", 
          "Content-Transfer-Encoding"].each {|key|
          header.push([key, @mail[key]]) unless @mail[key].empty?
        }
        sub_mail = Mail.new
        parts = @mail.parts
        sub_mail.read(parts.first)
        body << sub_mail.body
        sub_mail.body = body
        parts[0] = sub_mail.to_s
        body = Mail.join_parts(parts, @mail.boundary)
      else
        unless @mail["Content-type"].empty?
          header.push(["Content-Type", @mail["Content-type"]]) 
        end
        body << @mail.body
      end

      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger,
		     :mail_from => '', 
		     :recipient => @mail.from,
		     :header => header,
		     :body => body)
      @logger.log "[#{ml.name}]: Reject: #{@mail.from}"
    end

    def report_unsubscription (ml, member, requested_by = nil)
      header = []
      subject = Mail.encode_field(_("[%s] Unsubscribe: %s",
				    ml.short_name, ml.address))
      header.push(["To",	member],
		  ["From",	ml.address],
		  ["Subject",	subject],
                  ["Content-type", content_type])

      if requested_by
	body =  _("You are removed from the mailing list:\n<%s>\n",
		  ml.address)
	body << _("by the request of <%s>.\n", requested_by)
      else
	body = _("You have unsubscribed from the mailing list:\n<%s>.\n", 
		 ml.address)
      end
      body << generate_footer
      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger,
		     :mail_from => '', 
		     :recipients => member,
		     :header => header,
		     :body => body)
      @logger.log "[#{ml.name}]: Unsubscribe: #{member}"
    end

    def report_too_many_members (ml, unadded_addresses)
      header = []
      subject = Mail.encode_field(_("[QuickML] Error: %s", @mail["Subject"]))
      header.push(["To",	@mail.from],
		  ["From",	ml.address],
		  ["Subject",	subject],
                  ["Content-type", content_type])

      body =  _("The following addresses cannot be added because <%s> mailing list reaches the max number of members (%d persons)\n\n",
		ml.address,
                ml.max_members)
      unadded_addresses.each {|address|
        body << sprintf("<%s>\n", address)
      }

      body << generate_footer
      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger,
		     :mail_from => '', 
		     :recipient => @mail.from,
		     :header => header,
		     :body => body)
      @logger.log "[#{ml.name}]: Too Many Members: #{address}"
    end

    def report_invalid_members (ml, invalid_members)
      header = []
      subject = Mail.encode_field(_("[QuickML] Error: %s", @mail["Subject"]))
      header.push(["To",	@mail.from],
		  ["From",	ml.address],
		  ["Subject",	subject],
                  ["Content-type", content_type])

      body =  _("The following addresses cannot be added because <%s> mailing list can join known members only.\n\n",
		ml.address)
      invalid_members.each {|address|
        body << sprintf("<%s>\n", address)
      }

      body << generate_footer
      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger,
		     :mail_from => '', 
		     :recipient => @mail.from,
		     :header => header,
		     :body => body)
      @logger.log "[#{ml.name}]: Invalid Members by #{@mail.from}"
    end

    def report_invalid_mladdress (mladdress)
      header = []
      subject = Mail.encode_field(_("[QuickML] Error: %s", @mail["Subject"]))
      header.push(["To",	@mail.from],
		  ["From",	@config.postmaster],
		  ["Subject",	subject],
                  ["Content-type", content_type])

      body =   _("Invalid mailing list name: <%s>\n", mladdress)
      body <<  _("You can only use 0-9, a-z, A-Z,  `.',  `-', and `_' for mailing list name\n")
      body << generate_footer
      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger,
		     :mail_from => '', 
		     :recipient => @mail.from,
		     :header => header,
		     :body => body)
      @logger.log "Invalid ML Address: #{mladdress}"
    end

    def report_invalid_creator (mladdress)
      header = []
      subject = Mail.encode_field(_("[QuickML] Error: %s", @mail["Subject"]))
      header.push(["To",	@mail.from],
		  ["From",	@config.postmaster],
		  ["Subject",	subject],
                  ["Content-type", content_type])
      body =  _("Invalid Creator: <%s> by <%s>.\n", mladdress, @mail.from)
      body << generate_footer
      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger,
		     :mail_from => '', 
		     :recipient => @mail.from,
		     :header => header,
		     :body => body)
      @logger.log "Invalid Creator: #{mladdress} by #{@mail.from}"
    end

    def report_invalid_sender (mladdress)
      header = []
      subject = Mail.encode_field(_("[QuickML] Error: %s", @mail["Subject"]))
      header.push(["To",	@mail.from],
		  ["From",	@config.postmaster],
		  ["Subject",	subject],
                  ["Content-type", content_type])
      body =  _("Invalid Sender: <%s> by <%s>.\n", mladdress, @mail.from)
      body << generate_footer
      Mail.send_mail(@config.smtp_host, @config.smtp_port, @logger,
		     :mail_from => '', 
		     :recipient => @mail.from,
		     :header => header,
		     :body => body)
      @logger.log "Invalid Sender: #{mladdress} by #{@mail.from}"
    end

    def mail_log
      @logger.vlog "MAIL FROM:<#{@mail.mail_from}>"
      @mail.recipients.each {|recipient|
	@logger.vlog "RCPT TO:<#{recipient}>"
      }
      @logger.vlog "From: " + @mail.from
      @logger.vlog "Cc: " + @mail.collect_cc.join(", ")
      @logger.vlog "bare From: " + @mail['From']
      @logger.vlog "bare Cc: " + @mail['Cc']
    end

    def sender_knows_an_active_member? (ml)
      @mail.collect_cc.find {|address|
	ml.active_members.include?(address)
      }
    end

    def add_member (ml, address)
      begin
	ml.add_member(address)
      rescue TooManyMembers
        @unadded_addresses.push(address)
      rescue InvalidMembers
        @invalid_members.push(address)
      end
    end

    def ml_address_in_to? (ml)
      @mail.collect_to.find {|address|
        address == ml.address
      }
    end

    def submit_article (ml)
      @unadded_addresses = []
      @invalid_members = []
      if ml_address_in_to?(ml)
        add_member(ml, @mail.from)
        @mail.collect_cc.each {|address| 
          add_member(ml, address)
        }
      end
      unless @unadded_addresses.empty?
        report_too_many_members(ml, @unadded_addresses)
      end
      unless @invalid_members.empty?
        report_invalid_members(ml, @invalid_members)
      end
      ml.submit(@mail)
    end

    def to_return_address? (recipient)
      # "return=" for XVERP, "return@" for without XVERP.
      /^[^=]*=return[=@]/ =~ recipient
    end

    def unsubscribe_requested?
      @mail.empty_body? || 
        (@mail.body.length < 500 &&
         /\A\s*(unsubscribe|bye|#\s*bye|quit|ВаІс|Г¦Ва)\s*$/.match(@mail.body.toeuc))
    end

    def unsubscribe_self (ml)
      if ml.active_members.include?(@mail.from)
	ml.remove_member(@mail.from)
	report_unsubscription(ml, @mail.from)
      else
	report_rejection(ml)
      end
    end

    def unsubscribe_other (ml, cc)
      if ml.active_members.include?(@mail.from)
	cc.each {|other|
	  if ml.active_members.include?(other)
	    ml.remove_member(other) 
	    report_unsubscription(ml, other, @mail.from)
	  end
	}
      else
	@logger.vlog "rejected"
      end
    end

    def unsubscribe (ml)
      cc = @mail.collect_cc
      if cc.empty?
	unsubscribe_self(ml)
      else
	unsubscribe_other(ml, cc)
      end
    end

    def acceptable_submission? (ml)
      ml.newly_created? or
        ml.active_members.include?(@mail.from) or
        ml.former_members.include?(@mail.from) or
        sender_knows_an_active_member?(ml) or
        @config.sender_check
    end

    def confirmation_required? (ml)
      @config.confirm_ml_creation and ml.newly_created?
    end

    def submit (ml)
      if ml.exclude?(@mail.from)
	@logger.log "Invalid From Address: #{@mail.from}"
      elsif ml.forward? 
	@logger.log "Forward Address: #{ml.address}"
	ml.submit(@mail)
      elsif confirmation_required?(ml)
        ml.prepare_confirmation(@mail)
      elsif acceptable_submission?(ml)
	submit_article(ml)
      else
	report_rejection(ml)
      end
    end

    def validate_confirmation (confirmation_address)
      m = /^confirm\+(\d+)\+(.*)/.match(confirmation_address)
      time = m[1]
      mladdress = m[2]
      ml = QuickML.new(@config, mladdress)
      if ml.confirmation_waiting? and ml.validate_confirmation(time)
        ml.accept_confirmation
      end
    end

    def to_confirmation_address? (address)
      /^confirm\+/.match(address)
    end

    def process_recipient (recipient)
      mladdress = recipient
      if to_return_address?(mladdress)
	handler = ErrorMailHandler.new(@config, @message_charset)
	handler.handle(@mail)
      elsif @config.confirm_ml_creation and 
	  to_confirmation_address?(mladdress)
        validate_confirmation(mladdress)
      else
	begin
	  @config.ml_mutex(mladdress).synchronize {
	    ml = QuickML.new(@config, mladdress, @mail.from, @message_charset)
            @message_charset = (@message_charset or ml.charset)
	    (unsubscribe(ml); return) if unsubscribe_requested?
	    submit(ml)
	  }
	rescue InvalidMLName
	  report_invalid_mladdress(mladdress)
        rescue InvalidCreator
	  report_invalid_creator(mladdress)
        rescue InvalidSender
	  report_invalid_sender(mladdress)
	end
      end
    end

    public
    def process
      mail_log
      if @mail.looping?
	@logger.log "Looping Mail: from #{@mail.from}"
	return
      end
      @mail.recipients.each {|recipient|
	process_recipient(recipient)
      }
    end
  end
end
