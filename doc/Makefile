MAN1=		port.1
MAN5=		macports.conf.5
MAN7=		portfile.7 portstyle.7 porthier.7 portgroup.7
INSTALLDIR=	${DESTDIR}${prefix}
TOPSRCDIR=	..

ifneq ($(MAKECMDGOALS),distclean)
include ../Mk/macports.autoconf.mk
endif

all:

clean:
	rm -f *.{1,5,7}.gz

test:

distclean: clean
	rm -f prefix.mtree macports.conf macosx.mtree

%.1.gz: %.1
	gzip -c $^ > $@

%.5.gz: %.5
	gzip -c $^ > $@

%.7.gz: %.7
	gzip -c $^ > $@

install: ${MAN1:.1=.1.gz} ${MAN5:.5=.5.gz} ${MAN7:.7=.7.gz}
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

	# delete old uncompressed man pages if they exist
	for m in ${MAN1}; do rm -f ${INSTALLDIR}/share/man/man1/$$m ; done
	for m in ${MAN5}; do rm -f ${INSTALLDIR}/share/man/man5/$$m ; done
	for m in ${MAN7}; do rm -f ${INSTALLDIR}/share/man/man7/$$m ; done

	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}/share/macports/resources/port1.0/install
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${INSTALLDIR}/share/macports/resources/port1.0/install/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 macosx.mtree ${INSTALLDIR}/share/macports/resources/port1.0/install/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 port.1.gz ${INSTALLDIR}/share/man/man1
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 macports.conf.5.gz ${INSTALLDIR}/share/man/man5
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portfile.7.gz ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portstyle.7.gz ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 porthier.7.gz ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portgroup.7.gz ${INSTALLDIR}/share/man/man7
