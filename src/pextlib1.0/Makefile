OBJS=		Pextlib.o strsed.o
SHLIB_NAME=	Pextlib
LDADD+=		-ltcl
INSTALLDIR= ${DESTDIR}${PREFIX}/share/darwinports/Tcl/pextlib1.0

.c.o:
	./compile.sh ${CFLAGS} $< -o $@

Pextlib.dylib: ${OBJS}
	@./link.sh ${SHLIB_NAME} ${OBJS}

all: Pextlib.dylib

clean:
	rm -f ${OBJS} `./link.sh -n ${SHLIB_NAME}`

install: all
	mkdir -p ${INSTALLDIR}
	install -c -o "${DSTUSR}" -g "${DSTGRP}" -m 444 `./link.sh -n ${SHLIB_NAME}` ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}

include ../../Mk/dports.mk
