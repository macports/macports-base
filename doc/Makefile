MAN5=		macports.conf.5
MAN7=		portfile.7 portstyle.7 porthier.7 portgroup.7
INSTALLDIR=	${DESTDIR}${prefix}
TOPSRCDIR=	..

ifneq ($(MAKECMDGOALS),distclean)
include ../Mk/macports.autoconf.mk
endif

all:

clean:

test:

distclean: clean
	rm -f prefix.mtree macports.conf macosx.mtree

install:
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${DESTDIR}${mpconfigdir}

	cat prefix.mtree | $(MTREE) -U -e -p ${INSTALLDIR} > /dev/null
	if test -L "${INSTALLDIR}/man" ; then \
		rm -f "${INSTALLDIR}/man"; \
	fi

	if test ! -e "${INSTALLDIR}/man" ; then \
		$(LN_S) share/man ${INSTALLDIR}/man; \
	fi

	if test ! -e ${DESTDIR}${mpconfigdir}/macports.conf ; then \
		set -x; \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 macports.conf ${DESTDIR}${mpconfigdir}; \
	fi
	if test ! -e ${DESTDIR}${mpconfigdir}/sources.conf ; then \
		set -x; \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 sources.conf ${DESTDIR}${mpconfigdir}; \
	fi
	if test ! -e ${DESTDIR}${mpconfigdir}/variants.conf ; then \
		set -x; \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 variants.conf ${DESTDIR}${mpconfigdir}; \
	fi

	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${DESTDIR}${mpconfigdir}
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}/share/macports/resources/port1.0/install
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${INSTALLDIR}/share/macports/resources/port1.0/install/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 macosx.mtree ${INSTALLDIR}/share/macports/resources/port1.0/install/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 macports.conf.5 ${INSTALLDIR}/share/man/man5
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portfile.7 ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portstyle.7 ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 porthier.7 ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portgroup.7 ${INSTALLDIR}/share/man/man7
