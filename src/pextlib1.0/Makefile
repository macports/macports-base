OBJS=		Pextlib.o strsed.o
SHLIB_NAME=	Pextlib
LDADD+=		-ltcl
INSTALLDIR= ${DESTDIR}${PREFIX}/share/darwinports/Tcl/pextlib1.0
COMPILE=	../../scripts/compile.sh
LINK=		../../scripts/link.sh


.c.o:
	${COMPILE} ${CFLAGS} $< -o $@

Pextlib.dylib: ${OBJS}
	@${LINK} ${SHLIB_NAME} ${OBJS}

all: Pextlib.dylib

clean:
	rm -f ${OBJS} `${LINK} -n ${SHLIB_NAME}`

install: all
	mkdir -p ${INSTALLDIR}
	install -c -o "${DSTUSR}" -g "${DSTGRP}" -m 444 `${LINK} -n ${SHLIB_NAME}` ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}

include ../../Mk/dports.mk
