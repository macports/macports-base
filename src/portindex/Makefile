INSTALL     = /usr/bin/install -c
PREFIX     ?= /Library/WebServer/Documents/ports
cgibin      = $(PREFIX)/cgi-bin
portindex   = $(PREFIX)/index
portfiles   = $(PREFIX)/files
srcdir      = .

all: portregister.cgi portsubmit.cgi initialize.sql register.html

%.cgi: %.pl
	@ echo $@
	@ < $< sed "/@@PREFIX@@/s//$(subst /,\/,$(PREFIX))/" > $@

install: all
	mkdir -p ${DESTDIR}$(PREFIX)
	chown www:www ${DESTDIR}$(PREFIX)
	chmod 0775 ${DESTDIR}$(PREFIX)
	$(INSTALL) -m 644 register.html ${DESTDIR}$(PREFIX)
	mkdir -p ${DESTDIR}$(cgibin)
	chown www:www ${DESTDIR}$(cgibin)
	chmod 0775 ${DESTDIR}$(cgibin)
	$(INSTALL) -m 755 portsubmit.cgi ${DESTDIR}$(cgibin)
	$(INSTALL) -m 755 portregister.cgi ${DESTDIR}$(cgibin)
	mkdir -p ${DESTDIR}$(portindex)
	chown www:www ${DESTDIR}$(portindex)
	chmod 0775 ${DESTDIR}$(portindex)
	mkdir -p ${DESTDIR}$(portfiles)
	chown www:www ${DESTDIR}$(portfiles)
	chmod 0775 ${DESTDIR}$(portfiles)
	$(INSTALL) -m 644 initialize.sql ${DESTDIR}$(portindex)

clean:
	rm -f *.cgi
