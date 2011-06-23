INSTALLDIR=	${DESTDIR}${prefix}
TOPSRCDIR=	../..
SCRIPTS=	portmirror portindex port

edit = sed \
	-e 's,@TCLSH\@,$(TCLSH),g' \
	-e 's,@macports_tcl_dir\@,$(macports_tcl_dir),g'

include ../../Mk/macports.autoconf.mk

.PHONY: mkdirs

all: ${SCRIPTS}

portmirror: portmirror.tcl ../../Mk/macports.autoconf.mk
	${edit} portmirror.tcl > $@

portindex: portindex.tcl ../../Mk/macports.autoconf.mk
	${edit} portindex.tcl > $@

port: port.tcl ../../Mk/macports.autoconf.mk
	${edit} port.tcl > $@

mkdirs:
	< ../../doc/prefix.mtree $(MTREE) -U -d -e -p ${INSTALLDIR} > /dev/null
	< ../../doc/base.mtree $(MTREE) -U -d -e -p ${INSTALLDIR} > /dev/null

clean:
	rm -f ${SCRIPTS}

test:

distclean: clean

install: all mkdirs
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}/bin
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}/var/macports
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 555 port portindex portmirror ${INSTALLDIR}/bin/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 port-help.tcl  ${INSTALLDIR}/var/macports/
	cd ${INSTALLDIR}/bin && $(LN_S) -f port portf
