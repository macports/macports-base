MAN7=		portfile.7 portstyle.7

all:

clean:

install:
	mkdir -p ${DESTROOT}${ETCDIR}
	mkdir -p ${DESTROOT}${PREFIX}
	mtree -U -f prefix.mtree -d -e -p ${DESTROOT}${PREFIX} > /dev/null
	@if [ ! -e ${DESTROOT}/${ETCDIR}/ports.conf ]; then \
		set -x; \
		install -o ${DSTUSR} -g ${DSTGRP} -m 644 ports.conf ${DESTROOT}${ETCDIR}; \
	fi

	@if [ ! -e ${DESTROOT}${ETCDIR}/sources.conf ]; then \
		set -x; \
		install -o ${DSTUSR} -g ${DSTGRP} -m 644 sources.conf ${DESTROOT}${ETCDIR}; \
	fi
	install -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${DESTROOT}${ETCDIR}
	install -o ${DSTUSR} -g ${DSTGRP} -m 444 portfile.7 ${DESTROOT}${PREFIX}/man/man7
	install -o ${DSTUSR} -g ${DSTGRP} -m 444 portstyle.7 ${DESTROOT}${PREFIX}/man/man7

include ../Mk/dports.mk
