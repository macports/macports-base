SHAREDIR=	/opt/local
MAN7=		portfile.7

portfile.7.gz: portfile.7
	gzip -cn portfile.7 > portfile.7.gz

all: portfile.7.gz

clean:
	rm -f portfile.7.gz
install:
	mkdir -p /etc/defaults
	mkdir -p ${SHAREDIR}/man/man7
	install -o root -g wheel -m 644 ports.conf /etc/defaults/ports.conf
	install -c -o root -g wheel -m 444 portfile.7.gz ${SHAREDIR}/man/man7
