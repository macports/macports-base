SHAREDIR=	/opt/local
ETCDIR=		/etc/ports
MAN7=		portfile.7

portfile.7.gz: portfile.7
	gzip -cn portfile.7 > portfile.7.gz

all: portfile.7.gz

clean:
	rm -f portfile.7.gz
install:
	mkdir -p /etc/defaults
	mkdir -p ${ETCDIR}
	mkdir -p ${SHAREDIR}/man/man7
	@if [ ! -e ${ETCDIR}/ports.conf ]; then \
		set -x; \
		install -o root -g wheel -m 644 ports.conf ${ETCDIR}; \
	fi

	@if [ ! -e ${ETCDIR}/sources.conf ]; then \
		set -x; \
		install -o root -g wheel -m 644 sources.conf ${ETCDIR}; \
	fi

	install -o root -g wheel -m 644 ports.conf.default /etc/defaults/ports.conf
	install -o root -g wheel -m 444 portfile.7.gz ${SHAREDIR}/man/man7
