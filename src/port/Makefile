MAN1=		port.1
INSTALLDIR=	${DESTDIR}${prefix}
TOPSRCDIR=	../..
SCRIPTS=	portindex portall port

edit = sed \
	-e 's,@TCLSH\@,$(TCLSH),g'

include ../../Mk/dports.autoconf.mk

all: ${SCRIPTS}

portindex: portindex.tcl
	${edit} portindex.tcl > $@

portall: portall.tcl
	${edit} portall.tcl > $@

port: port.tcl
	${edit} port.tcl > $@

mkdirs:
	cat ../../doc/prefix.mtree | $(MTREE) -U -d -e -p ${INSTALLDIR} > /dev/null

clean:
	rm -f ${SCRIPTS}

distclean: clean

install: mkdirs
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 port.1 ${INSTALLDIR}/share/man/man1
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m 775 ${INSTALLDIR}/bin
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 port ${INSTALLDIR}/bin/port
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 portall ${INSTALLDIR}/bin/portall
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 portindex ${INSTALLDIR}/bin/portindex
