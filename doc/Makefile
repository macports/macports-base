MAN7=		portfile.7 portstyle.7
INSTALLDIR=	${DESTDIR}${PREFIX}

all:

clean:

install:
	mkdir -p ${DESTDIR}${ETCDIR}
	mkdir -p ${INSTALLDIR}
	
	cat prefix.mtree.pre | sed -e "s/uname=UNAME/uname=${DSTUSR}/" | \
	sed -e "s/gname=GNAME/gname=${DSTGRP}/" > prefix.mtree
	cat prefix.mtree | mtree -U -d -e -p ${INSTALLDIR} > /dev/null
	@if [ ! -e ${DESTDIR}/${ETCDIR}/ports.conf ]; then \
		set -x; \
		install -o ${DSTUSR} -g ${DSTGRP} -m 644 ports.conf ${DESTDIR}${ETCDIR}; \
	fi

	@if [ ! -e ${DESTDIR}${ETCDIR}/sources.conf ]; then \
		set -x; \
		install -o ${DSTUSR} -g ${DSTGRP} -m 644 sources.conf ${DESTDIR}${ETCDIR}; \
	fi
	install -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${DESTDIR}${ETCDIR}
	install -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${INSTALLDIR}/share/darwinports/resources/port1.0/install/
	install -o ${DSTUSR} -g ${DSTGRP} -m 644 macosx.mtree ${INSTALLDIR}/share/darwinports/resources/port1.0/install/
	install -o ${DSTUSR} -g ${DSTGRP} -m 444 portfile.7 ${INSTALLDIR}/man/man7
	install -o ${DSTUSR} -g ${DSTGRP} -m 444 portstyle.7 ${INSTALLDIR}/man/man7

include ../Mk/dports.mk
