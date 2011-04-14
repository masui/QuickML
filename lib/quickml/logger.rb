#
# quickml/logger - a part of quickml server
#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#
require 'quickml/utils'
require 'thread'

module QuickML
  class Logger
    def initialize (log_filename, verbose_mode = nil)
      @mutex = Mutex.new
      @log_file = File.safe_open(log_filename, "a")
      @log_file.sync = true
      @verbose_mode = verbose_mode
    end

    private
    def puts_log (msg)
      @mutex.synchronize {
	time = Time.now.strftime("%Y-%m-%dT%H:%M:%S")
	@log_file.puts "#{time}: #{msg}"
      }
    end

    public
    def log (msg)
      puts_log(msg)
    end

    def vlog (msg)
      puts_log(msg) if @verbose_mode
    end

    def reopen
      @mutex.synchronize {
	log_filename = @log_file.path
      	@log_file.close
      	@log_file = File.safe_open(log_filename, "a")
      }
    end
  end
end
