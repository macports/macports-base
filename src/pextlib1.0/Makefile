SRCS=		Pextlib.c strsed.c
LIB=		Pextlib
SHLIB_NAME=	Pextlib.dylib
NOPROFILE=	TRUE
LDADD+=		-ltcl
INSTALLDIR= /usr/local/share/darwinports/Tcl/pextlib1.0

install:
	mkdir -p ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} ${SHLIB_NAME} ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} pkgIndex.tcl  ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}

.include <bsd.lib.mk>
