MAN7=		portfile.7 portstyle.7

all:

clean:

install:
	mkdir -p ${DESTDIR}${ETCDIR}
	mkdir -p ${DESTDIR}${PREFIX}
	mtree -U -f prefix.mtree -d -e -p ${DESTDIR}${PREFIX} > /dev/null
	@if [ ! -e ${DESTDIR}/${ETCDIR}/ports.conf ]; then \
		set -x; \
		install -o ${DSTUSR} -g ${DSTGRP} -m 644 ports.conf ${DESTDIR}${ETCDIR}; \
	fi

	@if [ ! -e ${DESTDIR}${ETCDIR}/sources.conf ]; then \
		set -x; \
		install -o ${DSTUSR} -g ${DSTGRP} -m 644 sources.conf ${DESTDIR}${ETCDIR}; \
	fi
	install -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${DESTDIR}${ETCDIR}
	install -o ${DSTUSR} -g ${DSTGRP} -m 444 portfile.7 ${DESTDIR}${PREFIX}/man/man7
	install -o ${DSTUSR} -g ${DSTGRP} -m 444 portstyle.7 ${DESTDIR}${PREFIX}/man/man7

include ../Mk/dports.mk
