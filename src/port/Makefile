SHAREDIR=	/usr/local
MAN1=		port.1

port.1.gz: port.1
	gzip -cn port.1 > port.1.gz

all: port.1.gz

clean:
	rm -f port.1.gz

mkdirs:
	mkdir -p /usr/local/bin
	mkdir -p ${SHAREDIR}/man/man1

install: mkdirs
	install -c -o root -g wheel -m 444 port.1.gz ${SHAREDIR}/man/man1
	install -c -o root -g wheel -m 555 port.tcl /usr/local/bin/port
