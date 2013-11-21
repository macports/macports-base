# This Makefile will only be run on Darwin systems; we can safely use
# Apple-specifics here
SRCS=		$(wildcard *.c)
OBJS=		$(SRCS:%.c=%.o)
SHLIB_NAME=	darwintrace${SHLIB_SUFFIX}
INSTALLDIR=	${DESTDIR}${datadir}/macports/Tcl/darwintrace1.0

include ../../Mk/macports.autoconf.mk

# Yes, we know having $ signs in identifiers is not a very good idea; in the
# case of darwintrace we still need them, though.
CFLAGS_PEDANTIC+=-Wno-dollar-in-identifier-extension
CFLAGS+= -fPIC ${UNIVERSAL_ARCHFLAGS}
SHLIB_LDFLAGS+=${UNIVERSAL_ARCHFLAGS}

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
