OBJS=		Pextlib.o strsed.o fgetln.o md5cmd.o setmode.o xinstall.o
SHLIB_NAME=	Pextlib${SHLIB_SUFFIX}
INSTALLDIR= ${DESTDIR}${datadir}/darwinports/Tcl/pextlib1.0

include ../../Mk/dports.autoconf.mk
include ../../Mk/dports.tea.mk

LIBS+=		${MD5_LIBS}
CFLAGS+=	-Wall
