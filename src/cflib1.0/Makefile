OBJS=		CFLib.o
SHLIB_NAME=	CFLib
LDADD+=		-ltcl
INSTALLDIR= ${DESTROOT}${PREFIX}/share/darwinports/Tcl/cflib1.0

.c.o:
	./compile.sh ${CFLAGS} $< -o $@

CFLib.dylib: ${OBJS}
	@./link.sh ${SHLIB_NAME} ${OBJS}

all: CFLib.dylib

clean:
	rm -f ${OBJS} `./link.sh -n ${SHLIB_NAME}`

install: all
	mkdir -p ${INSTALLDIR}
	install -c -o "${DSTUSR}" -g "${DSTGRP}" -m 444 `./link.sh -n ${SHLIB_NAME}` ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}

include ../../Mk/dports.mk
