SHAREDIR=	/usr/local
MAN1=		portbuild.1

all: all-man

clean:

install: maninstall
	${INSTALL} ${COPY} -o ${BINOWN} -g ${BINGRP} -m ${BINMODE} portbuild.tcl /usr/local/bin/portbuild

.include <bsd.man.mk>
