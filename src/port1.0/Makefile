INSTALLDIR=	/usr/local/share/darwinports/Tcl/port1.0
SRCS=		pkgIndex.tcl port.tcl portchecksum.tcl portconfigure.tcl portextract.tcl portfetch.tcl portmain.tcl portbuild.tcl portpatch.tcl portui.tcl portutil.tcl portinstall.tcl portregistry.tcl portdepends.tcl portinstall.tcl portregistry.tcl portdepends.tcl

pkgIndex.tcl:
	../pkg_mkindex.tcl ${.CURDIR}

all: pkgIndex.tcl

clean:
	rm -f pkgIndex.tcl

install: all
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${SRCS}; do \
		${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} $$file ${INSTALLDIR}; \
	done
