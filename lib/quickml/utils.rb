#
# quickml/utils - a part of quickml server
#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#
$KCODE = 'e'
require 'kconv'
require 'net/smtp'
require 'ftools'

class TooLongLine < Exception; end
class IO
  def safe_gets (max_length = 1024)
    s = ""
    until self.eof?
      c = self.read(1)
      s << c
      if s.length > max_length
	raise TooLongLine
      end
      if c == "\n"
	return s
      end
    end
    if s.empty? then nil else s end
  end
end

class String
  def xchomp!
    self.chomp!("\n")
    self.chomp!("\r")
  end

  def normalize_eol!
    self.xchomp!
    self << "\n"
  end

  def xchomp
    self.chomp("\n").chomp("\r")
  end
end

class TCPSocket
  def address
    peeraddr[3]
  end

  def hostname
    peeraddr[2]
  end
end

class File
  def self.safe_open (filename, mode = "r")
    begin 
      f = File.open(filename, mode)
      if block_given?
	yield(f)
	f.close
      else
	return f
      end
    rescue => e
      STDERR.printf "%s: %s\n", $0, e.message
      exit(1)
    end
  end
end

class Integer
  # commify(12345) => "12,345"
  def commify
    numstr = self.to_s
    true while numstr.sub!(/^([-+]?\d+)(\d{3})/, '\1,\2')
    return numstr
  end
end
