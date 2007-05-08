MAN5=		ports.conf.5
MAN7=		portfile.7 portstyle.7 porthier.7 portgroup.7
INSTALLDIR=	${DESTDIR}${prefix}
TOPSRCDIR=	..

ifneq ($(MAKECMDGOALS),distclean)
include ../Mk/dports.autoconf.mk
endif

all:

clean:

test:

distclean: clean
	rm -f prefix.mtree ports.conf macosx.mtree

install:
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${DESTDIR}${portconfigdir}

	cat prefix.mtree | $(MTREE) -U -e -p ${INSTALLDIR} > /dev/null
	if test -L "${INSTALLDIR}/man" ; then \
		rm -f "${INSTALLDIR}/man"; \
	fi

	if test ! -e "${INSTALLDIR}/man" ; then \
		$(LN_S) share/man ${INSTALLDIR}/man; \
	fi
	# Install the ports.conf file. If it's already installed, upgrade it
	if test ! -e ${DESTDIR}/${portconfigdir}/ports.conf ; then \
		set -x; \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 ports.conf ${DESTDIR}${portconfigdir}; \
	else \
		sed -e s/rsync.opendarwin.org/rsync.darwinports.org/ ${DESTDIR}${portconfigdir}/ports.conf > ${DESTDIR}${portconfigdir}/ports.conf.tmp && \
			mv ${DESTDIR}${portconfigdir}/ports.conf.tmp ${DESTDIR}${portconfigdir}/ports.conf; \
	fi

	# Install the sources.conf file. If it's already installed, upgrade it
	if test ! -e ${DESTDIR}${portconfigdir}/sources.conf ; then \
		set -x; \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 sources.conf ${DESTDIR}${portconfigdir}; \
	else \
		sed -e s/rsync.opendarwin.org/rsync.darwinports.org/ ${DESTDIR}${portconfigdir}/sources.conf > ${DESTDIR}${portconfigdir}/sources.conf.tmp && \
			mv ${DESTDIR}${portconfigdir}/sources.conf.tmp ${DESTDIR}${portconfigdir}/sources.conf; \
	fi

	$(SILENT)if test ! -e ${DESTDIR}${portconfigdir}/variants.conf ; then \
		set -x; \
		$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 variants.conf ${DESTDIR}${portconfigdir}; \
	fi
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${DESTDIR}${portconfigdir}
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}/share/darwinports/resources/port1.0/install
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${INSTALLDIR}/share/darwinports/resources/port1.0/install/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 macosx.mtree ${INSTALLDIR}/share/darwinports/resources/port1.0/install/
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 ports.conf.5 ${INSTALLDIR}/share/man/man5
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portfile.7 ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portstyle.7 ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 porthier.7 ${INSTALLDIR}/share/man/man7
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 portgroup.7 ${INSTALLDIR}/share/man/man7
