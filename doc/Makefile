PREFIX?=	/opt/local
ETCDIR=		/etc/ports
MAN7=		portfile.7 portstyle.7
DSTUSR?=	root
DSTGRP?=	wheel

all: portfile.7.gz portstyle.7.gz

portfile.7.gz: portfile.7
	gzip -cn portfile.7 > portfile.7.gz

portstyle.7.gz: portstyle.7
	gzip -cn portstyle.7 > portstyle.7.gz

clean:
	rm -f portfile.7.gz portstyle.7.gz
install:
	mkdir -p /etc/defaults
	mkdir -p ${ETCDIR}
	mtree -U -f prefix.mtree -d -e -p ${PREFIX} > /dev/null
	@if [ ! -e ${ETCDIR}/ports.conf ]; then \
		set -x; \
		install -o ${DSTUSR} -g ${DSTGRP} -m 644 ports.conf ${ETCDIR}; \
	fi

	@if [ ! -e ${ETCDIR}/sources.conf ]; then \
		set -x; \
		install -o ${DSTUSR} -g ${DSTGRP} -m 644 sources.conf ${ETCDIR}; \
	fi
	install -o ${DSTUSR} -g ${DSTGRP} -m 644 prefix.mtree ${ETCDIR}
	install -o ${DSTUSR} -g ${DSTGRP} -m 644 ports.conf.default /etc/defaults/ports.conf
	install -o ${DSTUSR} -g ${DSTGRP} -m 444 portfile.7.gz ${PREFIX}/man/man7
	install -o ${DSTUSR} -g ${DSTGRP} -m 444 portstyle.7.gz ${PREFIX}/man/man7
