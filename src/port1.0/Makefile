INSTALLDIR=	/usr/local/share/darwinports/Tcl/port1.0
SRCS=		port.tcl portchecksum.tcl portconfigure.tcl portextract.tcl portfetch.tcl portmain.tcl portbuild.tcl portpatch.tcl portui.tcl portutil.tcl portinstall.tcl portregistry.tcl portdepends.tcl portinstall.tcl portregistry.tcl portdepends.tcl portclean.tcl

all:

clean:

install: all
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${SRCS}; do \
		${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} $$file ${INSTALLDIR}; \
	done
	../pkg_mkindex.tcl ${INSTALLDIR}
