OBJS=		Pextlib.o strsed.o fgetln.o md5cmd.o setmode.o xinstall.o \
		find.o strcasecmp.o vercomp.o filemap.o \
		sha1cmd.o compat.o
SHLIB_NAME=	Pextlib${SHLIB_SUFFIX}
INSTALLDIR= ${DESTDIR}${datadir}/darwinports/Tcl/pextlib1.0

include ../../Mk/dports.autoconf.mk
include ../../Mk/dports.tea.mk

.PHONY: test

test:: ${SHLIB_NAME}
	${TCLSH} tests/filemap.tcl ${SHLIB_NAME}
