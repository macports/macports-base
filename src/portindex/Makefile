INSTALL = /usr/bin/install -c
prefix = /Library/WebServer
cgibin = $(prefix)/CGI-Executables
htdocs = $(prefix)/Documents
portindex  = $(htdocs)/ports/index
portfiles  = $(htdocs)/ports/files
srcdir = .

all: portsubmit.cgi portregister.cgi

portsubmit.cgi: portsubmit.pl
	cp portsubmit.pl portsubmit.cgi

portregister.cgi: portregister.pl
	cp portregister.pl portregister.cgi

install: portsubmit.cgi portregister.cgi initialize.sql
	$(INSTALL) -m 755 portsubmit.cgi $(cgibin)
	$(INSTALL) -m 755 portregister.cgi $(cgibin)
	mkdir -p $(portindex)
	chgrp www $(portindex)
	chmod g+w $(portindex)
	mkdir -p $(portfiles)
	chgrp www $(portfiles)
	chmod g+w $(portfiles)
	$(INSTALL) -m 644 initialize.sql $(portindex)

clean:
	rm -f *.cgi
