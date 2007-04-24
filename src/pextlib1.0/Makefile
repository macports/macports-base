OBJS=		Pextlib.o strsed.o fgetln.o md5cmd.o setmode.o xinstall.o \
		fs-traverse.o strcasecmp.o vercomp.o filemap.o \
		sha1cmd.o compat.o curl.o rmd160cmd.o readline.o uid.o
SHLIB_NAME=	Pextlib${SHLIB_SUFFIX}
INSTALLDIR= ${DESTDIR}${datadir}/macports/Tcl/pextlib1.0
export MACOSX_DEPLOYMENT_TARGET=10.3

include ../../Mk/macports.autoconf.mk
include ../../Mk/macports.tea.mk

.PHONY: test

test:: ${SHLIB_NAME}
	${TCLSH} tests/curl.tcl ${SHLIB_NAME}
	${TCLSH} tests/checksums.tcl ${SHLIB_NAME}
	${TCLSH} tests/filemap.tcl ${SHLIB_NAME}
	${TCLSH} tests/fifo.tcl ${SHLIB_NAME}
	${TCLSH} tests/fs-traverse.tcl ${SHLIB_NAME}
	${TCLSH} tests/socketpair.tcl ${SHLIB_NAME}
