MAN1=		port.1
INSTALLDIR=	${DESTDIR}${prefix}
TOPSRCDIR=	../..
SCRIPTS=	portmirror portindex port

edit = sed \
	-e 's,@TCLSH\@,$(TCLSH),g' \
	-e 's,@TCL_PACKAGE_DIR\@,$(TCL_PACKAGE_DIR),g'

include ../../Mk/dports.autoconf.mk

all: ${SCRIPTS}

portmirror: portmirror.tcl
	${edit} portmirror.tcl > $@

portindex: portindex.tcl
	${edit} portindex.tcl > $@

port: port.tcl
	${edit} port.tcl > $@

mkdirs:
	cat ../../doc/prefix.mtree | mtree -U -d -e -p ${INSTALLDIR} > /dev/null

clean:
	rm -f ${SCRIPTS}

test:

distclean: clean

install: mkdirs
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 port.1 ${INSTALLDIR}/share/man/man1
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}/bin
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 port portindex portmirror ${INSTALLDIR}/bin/
	cd ${INSTALLDIR}/bin && $(LN_S) -f port portf
