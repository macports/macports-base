OBJS=		Pextlib.o strsed.o
SHLIB_NAME=	Pextlib
INSTALLDIR= ${DESTDIR}${PREFIX}/share/darwinports/Tcl/pextlib1.0
COMPILE=	../../scripts/config.sh compile
LINK=		../../scripts/config.sh link
SHLIB_SO=	`../../scripts/config.sh shlibname ${SHLIB_NAME}`

.c.o:
	${COMPILE} ${CFLAGS} $< -o $@

Pextlib.dylib: ${OBJS}
	${LINK} ${SHLIB_NAME} ${OBJS}

all: Pextlib.dylib

clean:
	rm -f ${OBJS} ${SHLIB_SO}

install: all
	mkdir -p ${INSTALLDIR}
	install -c -o "${DSTUSR}" -g "${DSTGRP}" -m 444 ${SHLIB_SO} ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}

include ../../Mk/dports.mk
