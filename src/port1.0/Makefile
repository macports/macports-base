PREFIX?=	/opt/local
INSTALLDIR=	${DESTDIR}${PREFIX}/share/darwinports/Tcl/port1.0
DSTUSR?=	root
DSTGRP?=	admin

SRCS=		port.tcl portchecksum.tcl portconfigure.tcl portextract.tcl portfetch.tcl portmain.tcl portbuild.tcl portpatch.tcl portutil.tcl portinstall.tcl portregistry.tcl portdepends.tcl portinstall.tcl portuninstall.tcl portregistry.tcl portdepends.tcl portclean.tcl portpackage.tcl portcontents.tcl portmpkg.tcl

SUBDIR=		resources

all::

clean::

install::
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${SRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	../pkg_mkindex.tcl ${INSTALLDIR}

include ../../Mk/dports.subdir.mk
