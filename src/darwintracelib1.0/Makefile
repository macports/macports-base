OBJS=		darwintrace.o
SHLIB_NAME=	darwintrace${SHLIB_SUFFIX}
INSTALLDIR=	${DESTDIR}${datadir}/macports/Tcl/darwintrace1.0

test::

include ../../Mk/macports.autoconf.mk

CFLAGS+= -fPIC
# will need to update this to cope with 64-bit inodes someday
CPPFLAGS+= -D_DARWIN_NO_64_BIT_INODE

all:: ${SHLIB_NAME}

$(SHLIB_NAME):: ${OBJS}
	${SHLIB_LD} ${OBJS} -o ${SHLIB_NAME} ${SHLIB_LDFLAGS} ${LIBS}

clean::
	rm -f ${OBJS} ${SHLIB_NAME} so_locations

distclean:: clean

install:: all
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 ${SHLIB_NAME} ${INSTALLDIR}
