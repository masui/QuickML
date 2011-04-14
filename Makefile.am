SUBDIRS  = lib .
RD   = quickml.en.rd ml-usage.en.rd quickml.ja.rd with-mta.ja.rd

MESSAGES = messages.ja
EXTRA_DIST =	$(RD) $(MESSAGES) quickml.in quickml-ctl.in \
		quickmlrc.sample.in quickml-analog.in
CLEANFILES = quickml quickml-ctl quickmlrc.sample quickml-analog

bin_SCRIPTS  = quickml-analog
sbin_SCRIPTS = quickml quickml-ctl 
quickmlstatedir = $(localstatedir)/quickml

etcdir = $(sysconfdir)
etc_DATA = quickmlrc.sample

quickml: quickml.in
	for i in $(MESSAGES); do\
	  $(RUBY) lib/quickml/gettext.rb $$i quickml.in lib/quickml/*.rb;\
	done
	rm -f quickml
	sed -e 's!%RUBY%!$(RUBY)!g' \
	    -e 's!%SYSCONFDIR%!$(sysconfdir)!g' quickml.in >quickml
	chmod +x quickml
	chmod -w quickml

quickml-analog: quickml-analog.in Makefile
	rm -f quickml-analog
	sed -e 's!%RUBY%!$(RUBY)!g' \
		quickml-analog.in > quickml-analog
	chmod +x quickml-analog
	chmod -w quickml-analog

quickml-ctl: quickml-ctl.in Makefile
	rm -f quickml-ctl
	sed	-e 's!%SBINDIR%!$(sbindir)!g' \
		-e 's!%PIDFILE%!$(PIDFILE)!g' \
		quickml-ctl.in > quickml-ctl
	chmod +x quickml-ctl
	chmod -w quickml-analog

quickmlrc.sample: quickmlrc.sample.in Makefile
	rm -f quickmlrc.sample
	sed	-e 's!%LOCALSTATEDIR%!$(quickmlstatedir)!g' \
	   	-e 's!%DATADIR%!$(datadir)!g' \
	   	-e 's!%USER%!$(USER)!g' \
	   	-e 's!%GROUP%!$(GROUP)!g' \
		-e 's!%PIDFILE%!$(PIDFILE)!g' \
		-e 's!%LOGFILE%!$(LOGFILE)!g' \
		quickmlrc.sample.in > quickmlrc.sample

install-data-local:
	mkdir -p $(quickmlstatedir)
	chown -R $(USER)  $(quickmlstatedir)
	chgrp -R $(GROUP) $(quickmlstatedir)
	chmod 750 $(quickmlstatedir)



HTML = quickml.en.html quickml.ja.html ml-usage.en.html with-mta.ja.html
RDOPT = --require=rd/rd2html-lib.rb\
	--with-css=http://namazu.org/~satoru/satoru.css 

quickml.ja.html: quickml.ja.rd
	rd2 $(RDOPT) \
	--html-title="quickmlサーバ: 超お手軽なメーリングリストシステム"\
	quickml.ja.rd | reformat-rd2html > quickml.ja.html
	html-noarchive quickml.ja.html

quickml.en.html: quickml.en.rd
	rd2 $(RDOPT) \
	--html-title="quickml server: An easy-to-use mailing list system"\
	quickml.en.rd | reformat-rd2html > quickml.en.html
	html-noarchive quickml.en.html

with-mta.ja.html: with-mta.ja.rd
	rd2 $(RDOPT) \
	--html-title="quickmlサーバ: 他のMTAと共存させる方法"\
	with-mta.ja.rd | reformat-rd2html > with-mta.ja.html
	html-noarchive with-mta.ja.html

ml-usage.en.html: ml-usage.en.rd
	rd2 $(RDOPT) \
	--html-title="quickml server: How to Use Mailing List Service"\
	ml-usage.en.rd | reformat-rd2html > ml-usage.en.html
	html-noarchive ml-usage.en.html

html: $(HTML)
