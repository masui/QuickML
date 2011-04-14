#
# quickml/gettext - a part of quickml server
#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module QuickML
  module GetText
    module GetText
      def codeconv (text)
	if @catalog && @catalog.codeconv_method
	  text.send(@catalog.codeconv_method)
	else
	  text
	end
      end

      def gettext (text, *args)
	unless @catalog && @catalog.charset == @message_charset
	  return sprintf(text, *args) 
	end

	translated_message = @catalog.messages[text]	  
	if translated_message
	  codeconv(sprintf(translated_message, *args))
	else
	  sprintf(text, *args)
	end
      end

      def gettext2 (text)
	unless @catalog && @catalog.charset == @message_charset
	  return text
	end

	translated_message = @catalog.messages[text]	  
	if translated_message
	  codeconv(translated_message)
	else
	  text
	end
      end

      alias :_ :gettext
      alias :__ :gettext2
    end

    class Catalog
      def initialize (filename)
	load(filename)
	@messages = Messages
	@codeconv_method = CodeconvMethod
	@charset = Charset
      end
      attr_reader :messages
      attr_reader :codeconv_method
      attr_reader :charset
    end

    class MessageValidator
      def initialize (catalog, source_filename)
	@catalog = catalog
	@source_filename  = source_filename
	@has_error = false
      end

      def read_file_with_numbering (filename)
	content = ''
	File.open(filename).each_with_index {|line, idx|
	  lineno = idx + 1
	  content << line.gsub(/\b_\(/, "_[#{lineno}](")
	}
	content
      end

      def collect_messages (content)
	messages = []
	while content.sub!(/\b_\[(\d+)\]\((".*?").*?\)/m, "")
	  lineno  = $1.to_i
	  message = eval($2)
	  messages.push([lineno, message]) 
	end
	messages
      end

      def validate
	@catalog or return
	content = read_file_with_numbering(@source_filename)
	messages = collect_messages(content)
	messages.each {|lineno, message|
	  translated_message = @catalog.messages[message]
	  if not translated_message
	    printf "%s:%d: %s\n", @source_filename, lineno, message.inspect
	    @has_error = true
	  elsif message.count("%") != translated_message.count("%")
	    printf "%s:%d: %s => # of %% mismatch.\n", 
	      @source_filename, lineno, message.inspect, translated_message
	    @has_error = true
	  end
	}
      end

      def ok?
	not @has_error
      end
    end
  end
end

if __FILE__ == $0
  include QuickML::GetText
  if ARGV.length < 2
    puts "usage: ruby gettext.rb <catalog> <source...>"
    exit
  end
  catalog_file = ARGV.shift
  catalog = Catalog.new(catalog_file)

  ok = true
  ARGV.each {|source_file|
    validator = MessageValidator.new(catalog, source_file)
    validator.validate
    ok = (ok and validator.ok?)
  }
  if ok then exit else exit(1) end  
end
