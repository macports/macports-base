OBJS=		CFLib.o
SHLIB_NAME=	CFLib
LDADD+=		-ltcl
INSTALLDIR= ${DESTDIR}${PREFIX}/share/darwinports/Tcl/cflib1.0
LINK=		../../scripts/link.sh
COMPILE=	../../scripts/compile.sh

.c.o:
	${COMPILE} ${CFLAGS} $< -o $@

CFLib.dylib: ${OBJS}
	@${LINK} ${SHLIB_NAME} ${OBJS}

all: CFLib.dylib

clean:
	rm -f ${OBJS} `${LINK} -n ${SHLIB_NAME}`

install: all
	mkdir -p ${INSTALLDIR}
	install -c -o "${DSTUSR}" -g "${DSTGRP}" -m 444 `${LINK} -n ${SHLIB_NAME}` ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}

include ../../Mk/dports.mk
