OBJS=		Pextlib.o strsed.o
SHLIB_NAME=	Pextlib
LDADD+=		-ltcl
PREFIX?=	/opt/local
INSTALLDIR= ${PREFIX}/share/darwinports/Tcl/pextlib1.0
DSTUSR?=	root
DSTGRP?=	wheel

.c.o:
	./compile.sh ${CFLAGS} $< -o $@

Pextlib.dylib: ${OBJS}
	@./link.sh ${SHLIB_NAME} ${OBJS}

all: Pextlib.dylib

clean:
	rm -f ${OBJS} `./link.sh -n ${SHLIB_NAME}`

install:
	mkdir -p ${INSTALLDIR}
	install -c -o "${DSTUSR}" -g "${DSTGRP}" -m 444 `./link.sh -n ${SHLIB_NAME}` ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}
