INSTALL     = /usr/bin/install -c
PREFIX     ?= /Library/WebServer/Documents/ports
cgibin      = $(PREFIX)/cgi-bin
portindex   = $(PREFIX)/index
portfiles   = $(PREFIX)/files
srcdir      = .

all: portregister.cgi portsubmit.cgi initialize.sql register.html

%.cgi: %.pl
	@ echo $@
	@ cat $< | sed "/@@PREFIX@@/s//$(subst /,\/,$(PREFIX))/" > $@

install: all
	mkdir -p $(PREFIX)
	chown www:www $(PREFIX)
	chmod 0775 $(PREFIX)
	$(INSTALL) -m 644 register.html $(PREFIX)
	mkdir -p $(cgibin)
	chown www:www $(cgibin)
	chmod 0775 $(cgibin)
	$(INSTALL) -m 755 portsubmit.cgi $(cgibin)
	$(INSTALL) -m 755 portregister.cgi $(cgibin)
	mkdir -p $(portindex)
	chown www:www $(portindex)
	chmod 0775 $(portindex)
	mkdir -p $(portfiles)
	chown www:www $(portfiles)
	chmod 0775 $(portfiles)
	$(INSTALL) -m 644 initialize.sql $(portindex)

clean:
	rm -f *.cgi
