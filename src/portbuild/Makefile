SHAREDIR=	/usr/local
MAN1=		portbuild.1

all: all-man

clean:

mkdirs:
	mkdir -p /usr/local/bin
	mkdir -p ${SHAREDIR}/man

install: mkdirs maninstall
	${INSTALL} ${COPY} -o ${BINOWN} -g ${BINGRP} -m ${BINMODE} portbuild.tcl /usr/local/bin/portbuild

.include <bsd.man.mk>
