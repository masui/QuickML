#
# quickml/config - a part of quickml server
#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'quickml/utils'
require 'quickml/logger'
require 'quickml/gettext'

module QuickML
  class Config
    def initialize (config = {})
      @data_dir = config[:data_dir]
      @smtp_host = config[:smtp_host]
      @domain = config[:domain]

      raise ArgumentError if @data_dir.nil?
      raise ArgumentError if @smtp_host.nil?
      raise ArgumentError if @domain.nil?

      @smtp_port = (config[:smtp_port] or 25)
      @postmaster = (config[:postmaster] or "postmaster@#{domain}")
      @info_url = (config[:info_url] or "http://QuickML.com/")

      @pid_file = (config[:pid_file] or "/var/run/quickml.pid")
      @max_members = (config[:max_members] or 100)
      @max_mail_length = (config[:max_mail_length] or 100 * 1024) # 100KB
      @max_ml_mail_length = @max_mail_length
      @ml_life_time = (config[:ml_life_time] or 86400 * 30)
      @ml_alert_time = (config[:ml_alert_time] or 86400 * 29)
      @sweep_interval = (config[:sweep_interval] or 3600)
      @allowable_error_interval = (config[:allowable_error_interval] or 8600)
      @max_threads = (config[:max_threads] or 10) # number of working threads
      @timeout = (config[:timeout] or 120)
      @auto_unsubscribe_count = (config[:auto_unsubscribe_count] or 5)

      @log_file = (config[:log_file] or "/var/log/quickml-log")
      verbose_mode = config[:verbose_mode]
      @logger = Logger.new(@log_file, verbose_mode)
      @ml_mutexes = Hash.new
      @catalog = if config[:message_catalog]
		   GetText::Catalog.new(config[:message_catalog]) 
		 else
		   nil
		 end

      @port = (config[:port] or 25)
      @bind_address = (config[:bind_address] or "0.0.0.0")
      @user = (config[:user] or "root")
      @group = (config[:group] or "root")
      @use_qmail_verp = (config[:use_qmail_verp] or false)

      @creator_check = (config[:creator_check] or false)
      @creator_addresses = if config[:creator_addresses]
			     config[:creator_addresses]
			   else
			     [ @domain ]
			   end
      @member_check = (config[:member_check] or false)
      @member_addresses = if config[:member_addresses]
			    config[:member_addresses]
			  else
			    [ @domain ]
			  end

      @sender_check = (config[:sender_check] or false)
      @sender_addresses = if config[:sender_addresses]
			    config[:sender_addresses]
			  else
			    [ @domain ]
			  end

      charset = @catalog.charset if @catalog
      @content_type = "text/plain"

      @confirm_ml_creation = (config[:confirm_ml_creation] or false)

      instance_variables.each {|name|
	self.class.class_eval { attr_reader name.delete('@') }
      }
    end

    def ml_mutex (address)
      @ml_mutexes.fetch(address) {|x|
	@ml_mutexes[x] = Mutex.new
      }
    end

    def self.load (filename)
      self.new(eval(File.safe_open(filename).read))
    end
  end
end
