SHAREDIR=	/usr/local
MAN1=		portbuild.1

portbuild.1.gz:
	gzip -cn portbuild.1 > portbuild.1.gz

all: portbuild.1.gz

clean:
	rm -f portbuild.1.gz

mkdirs:
	mkdir -p /usr/local/bin
	mkdir -p ${SHAREDIR}/man/man1

install: mkdirs
	install -c -o root -g wheel -m 444 portbuild.1.gz ${SHAREDIR}/man/man1
	install -c -o root -g wheel -m 555 portbuild.tcl /usr/local/bin/portbuild
	install -c -o root -g wheel -m 555 portsall.tcl /usr/local/bin/portsall
