MAN7=		portfile.7 portstyle.7
INSTALLDIR=	${DESTDIR}${PREFIX}

include ../Mk/dports.mk
include ../Mk/dports.autoconf.mk

prefix.mtree:
	cat prefix.mtree.pre | sed -e "s/uname=UNAME/uname=${DSTUSR}/" | \
	sed -e "s/gname=GNAME/gname=${DSTGRP}/" > prefix.mtree

all: prefix.mtree

clean:
	rm -f prefix.mtree

distclean: clean

install:
	mkdir -p ${DESTDIR}${ETCDIR}
	mkdir -p ${INSTALLDIR}

	cat prefix.mtree | mtree -U -d -e -p ${INSTALLDIR} > /dev/null
	@if test ! -e ${DESTDIR}/${ETCDIR}/ports.conf ; then \
		set -x; \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 ports.conf ${DESTDIR}${ETCDIR}; \
	fi

	@if test ! -e ${DESTDIR}${ETCDIR}/sources.conf ; then \
		set -x; \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 sources.conf ${DESTDIR}${ETCDIR}; \
	fi
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${DESTDIR}${ETCDIR}
	mkdir -p ${INSTALLDIR}/share/darwinports/resources/port1.0/install
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${INSTALLDIR}/share/darwinports/resources/port1.0/install/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 macosx.mtree ${INSTALLDIR}/share/darwinports/resources/port1.0/install/
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} ${INSTALLDIR}/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portfile.7 ${INSTALLDIR}/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portstyle.7 ${INSTALLDIR}/man/man7
