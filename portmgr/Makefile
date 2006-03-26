INSTALLDIR=	${DESTDIR}${datadir}/darwinports/resources/portmgr

SCRIPTS=	PortIndex2MySQL

edit = sed \
	-e 's,@PREFIX\@,$(prefix),g' \
	-e 's,@TCL_PACKAGE_DIR\@,$(TCL_PACKAGE_DIR),g'

include ../Mk/dports.autoconf.mk

all: ${SCRIPTS}

PortIndex2MySQL: PortIndex2MySQL.tcl
	${edit} PortIndex2MySQL.tcl > $@

clean:
	rm -f ${SCRIPTS}

test:

distclean: clean

install:
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${SCRIPTS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 544 $$file ${INSTALLDIR}; \
	done
