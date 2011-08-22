OBJS= \
	Pextlib.o strsed.o fgetln.o md5cmd.o setmode.o xinstall.o \
	fs-traverse.o strcasecmp.o vercomp.o filemap.o base32cmd.o \
	sha1cmd.o curl.o rmd160cmd.o sha256cmd.o readline.o uid.o \
	tracelib.o tty.o readdir.o pipe.o flock.o \
	system.o mktemp.o realpath.o
SHLIB_NAME= Pextlib${SHLIB_SUFFIX}
INSTALLDIR= ${DESTDIR}${datadir}/macports/Tcl/pextlib1.0

include ../../Mk/macports.autoconf.mk
include ../../Mk/macports.tea.mk

CFLAGS+= ${CURL_CFLAGS} ${MD5_CFLAGS} ${READLINE_CFLAGS}
LIBS+= ${CURL_LIBS} ${MD5_LIBS} ${READLINE_LIBS}

.PHONY: test

test:: ${SHLIB_NAME}
	${TCLSH} tests/checksums.tcl ./${SHLIB_NAME}
	${TCLSH} tests/curl.tcl ./${SHLIB_NAME}
	${TCLSH} tests/filemap.tcl ./${SHLIB_NAME}
	${TCLSH} tests/fs-traverse.tcl ./${SHLIB_NAME}
	${TCLSH} tests/symlink.tcl ./${SHLIB_NAME}
	${TCLSH} tests/unsetenv.tcl ./${SHLIB_NAME}
	${TCLSH} tests/vercomp.tcl ./${SHLIB_NAME}
