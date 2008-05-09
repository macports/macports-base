INSTALLDIR=	${DESTDIR}${prefix}
TOPSRCDIR=	../..
SCRIPTS=	portmirror portindex port

edit = sed \
	-e 's,@TCLSH\@,$(TCLSH),g' \
	-e 's,@TCL_PACKAGE_DIR\@,$(TCL_PACKAGE_DIR),g'

include ../../Mk/macports.autoconf.mk

all: ${SCRIPTS}

.PHONY: always

portmirror: portmirror.tcl always
	${edit} portmirror.tcl > $@

portindex: portindex.tcl always
	${edit} portindex.tcl > $@

port: port.tcl always
	${edit} port.tcl > $@

mkdirs:
	cat ../../doc/prefix.mtree | $(MTREE) -U -d -e -p ${INSTALLDIR} > /dev/null

clean:
	rm -f ${SCRIPTS}

test:

distclean: clean

install: port portindex portmirror mkdirs
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}/bin
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}/var/macports
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 port portindex portmirror ${INSTALLDIR}/bin/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 port-help.tcl  ${INSTALLDIR}/var/macports/
	cd ${INSTALLDIR}/bin && $(LN_S) -f port portf
