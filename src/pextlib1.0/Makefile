SRCS=		Pextlib.c strsed.c
LIB=		Pextlib
SHLIB_NAME=	Pextlib.dylib
NOPROFILE=	TRUE
LDADD+=		-ltcl
CLEANFILES=	pkgIndex.tcl
INSTALLDIR= /usr/local/share/darwinports/Tcl/pextlib1.0

install:
	mkdir -p ${INSTALLDIR}
	${.CURDIR}/../pkg_mkindex.tcl ${.CURDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} ${SHLIB_NAME} ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} pkgIndex.tcl  ${INSTALLDIR}

afterclean:
	rm -f pkgIndex.tcl

.include <bsd.lib.mk>
