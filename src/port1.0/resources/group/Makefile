INSTALLDIR=	${DESTDIR}${prefix}/share/darwinports/resources/port1.0/group

RSRCS=		perl5-1.0.tcl python-1.0.tcl python24-1.0.tcl ruby-1.0.tcl zope-1.0.tcl

include ../../../../Mk/dports.autoconf.mk

all:

clean:

distclean:

test:

install:
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(SILENT)set -x; for file in ${RSRCS}; do \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
