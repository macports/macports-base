MAN7=		portfile.7 portstyle.7 porthier.7
INSTALLDIR=	${DESTDIR}${prefix}
TOPSRCDIR=	..

include ../Mk/dports.autoconf.mk

all:

clean:

distclean: clean
	rm -f prefix.mtree ports.conf

install:
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m 775 ${INSTALLDIR}
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m 775 ${DESTDIR}${portconfigdir}

	cat prefix.mtree | $(MTREE) -U -e -p ${INSTALLDIR} > /dev/null
	$(SILENT)if test ! -e ${DESTDIR}/${portconfigdir}/ports.conf ; then \
		set -x; \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 ports.conf ${DESTDIR}${portconfigdir}; \
	fi

	$(SILENT)if test ! -e ${DESTDIR}${portconfigdir}/sources.conf ; then \
		set -x; \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 sources.conf ${DESTDIR}${portconfigdir}; \
	fi
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${DESTDIR}${portconfigdir}
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m 775 ${INSTALLDIR}/share/darwinports/resources/port1.0/install
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${INSTALLDIR}/share/darwinports/resources/port1.0/install/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 macosx.mtree ${INSTALLDIR}/share/darwinports/resources/port1.0/install/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portfile.7 ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portstyle.7 ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 porthier.7 ${INSTALLDIR}/share/man/man7
