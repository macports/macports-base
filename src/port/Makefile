INSTALLDIR=	${DESTDIR}${prefix}
TOPSRCDIR=	../..
SCRIPTS=	portmirror portindex port

edit = sed \
	-e 's,@TCLSH\@,$(TCLSH),g' \
	-e 's,@TCL_PACKAGE_DIR\@,$(TCL_PACKAGE_DIR),g'

include ../../Mk/macports.autoconf.mk

all: ${SCRIPTS}

portmirror: portmirror.tcl
	${edit} portmirror.tcl > $@

portindex: portindex.tcl
	${edit} portindex.tcl > $@

port: port.tcl
	${edit} port.tcl > $@

mkdirs:
	cat ../../doc/prefix.mtree | $(MTREE) -U -d -e -p ${INSTALLDIR} > /dev/null

clean:
	rm -f ${SCRIPTS}

test:

distclean: clean

install: port portindex portmirror mkdirs
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}/bin
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 port portindex portmirror ${INSTALLDIR}/bin/
	cd ${INSTALLDIR}/bin && $(LN_S) -f port portf
