# $Id$

SCRIPTS=	PortIndex2MySQL

edit = sed \
	-e 's,@TCL_PACKAGE_DIR@,$(TCL_PACKAGE_DIR),g'


include ../../Mk/macports.autoconf.mk


all: ${SCRIPTS}

PortIndex2MySQL: PortIndex2MySQL.tcl
	${edit} $< > $@

clean:
	rm -f ${SCRIPTS}

distclean: clean
