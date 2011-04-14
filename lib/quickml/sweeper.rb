#
# quickml/sweeper - a part of quickml server
#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module QuickML
  class Sweeper
    def initialize (config)
      @config = config
      @status = :safe
      @logger = @config.logger
    end

    private
    def mlname (filename)
      File.basename(filename)
    end

    def mladdress (name)
      address = name 
      address += if name.include?("@") then "." else "@" end
      address += @config.domain
    end

    def ml_file? (filename)
      File.file?(filename) && QuickML.valid_name?(mlname(filename))
    end

    def sweep_ml (ml)
      if ml.inactive?
	@logger.log "[#{ml.name}]: Inactive"
	ml.close
      elsif ml.need_alert?
	ml.report_ml_close_soon
      end
    end

    def sweep
      @status = :sweeping
      @logger.vlog "Sweeper runs"
      Dir.new(@config.data_dir).each {|filename|
	filename = File.join(@config.data_dir, filename)
	if ml_file?(filename)
	  address = mladdress(mlname(filename))
	  @config.ml_mutex(address).synchronize {
            ml = QuickML.new(@config, address)
            ml.write_ml_config unless ml.ml_config_exist?
	    sweep_ml(ml)
	  }
	end
      }
      @logger.vlog "Sweeper finished"
      @status = :safe
    end

    public
    def start
      @logger.vlog "Sweeper started"
      loop do
	sleep(@config.sweep_interval)
	begin
	  sweep
	rescue Exception => e
	  @logger.log "Unknown Sweep Error: #{e.class}: #{e.message}"
	  @logger.log e.backtrace
	end
      end
    end

    def shutdown
      until @status == :safe
	sleep(0.5)
      end
      @logger.vlog "Sweeper shutdown"
    end
  end
end
