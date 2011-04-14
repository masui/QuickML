rubylib_files =	config.rb  gettext.rb  mail.rb    sweeper.rb  \
		core.rb    logger.rb   server.rb  utils.rb
rubylibdir = $(rubydir)/quickml
rubylib_DATA =	$(rubylib_files) version.rb

EXTRA_DIST = $(rubylib_files) version.rb.in
CLEANFILES = version.rb

version.rb: version.rb.in
	rm -f version.rb
	sed -e 's!%VERSION%!$(VERSION)!g' \
		version.rb.in > version.rb
