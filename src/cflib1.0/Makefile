OBJS=		CFLib.o
SHLIB_NAME=	CFLib
LDADD+=		-ltcl
INSTALLDIR= ${DESTDIR}${PREFIX}/share/darwinports/Tcl/cflib1.0
LINK=		../../scripts/config.sh link
COMPILE=	../../scripts/config.sh compile
SHLIB_SO=	`../../scripts/config.sh shlibname ${SHLIB_NAME}`

.c.o:
	${COMPILE} ${CFLAGS} $< -o $@

CFLib.dylib: ${OBJS}
	${LINK} ${SHLIB_NAME} ${OBJS} -framework CoreFoundation

all: CFLib.dylib

clean:
	rm -f ${OBJS} ${SHLIB_SO}

install: all
	mkdir -p ${INSTALLDIR}
	install -c -o "${DSTUSR}" -g "${DSTGRP}" -m 444 ${SHLIB_SO} ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}

include ../../Mk/dports.mk
