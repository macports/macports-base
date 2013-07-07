OBJS=		darwintrace.o
SHLIB_NAME=	darwintrace${SHLIB_SUFFIX}
INSTALLDIR=	${DESTDIR}${datadir}/macports/Tcl/darwintrace1.0

include ../../Mk/macports.autoconf.mk

ARCHFLAGS=-arch i386 -arch x86_64
CFLAGS+= -fPIC -Wno-deprecated-declarations -std=c99
CFLAGS+=${ARCHFLAGS}
CFLAGS_PEDANTIC=
SHLIB_LDFLAGS+=${ARCHFLAGS}

all:: ${SHLIB_NAME}

$(SHLIB_NAME):: ${OBJS}
	${SHLIB_LD} ${OBJS} -o ${SHLIB_NAME} ${SHLIB_LDFLAGS} ${LIBS}

clean::
	rm -f ${OBJS} ${SHLIB_NAME} so_locations

distclean:: clean

install:: all
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 ${SHLIB_NAME} ${INSTALLDIR}

test::
