PREFIX?=	/opt/local
INSTALLDIR=	${PREFIX}/share/darwinports/Tcl/port1.0

SRCS=		port.tcl portchecksum.tcl portconfigure.tcl portextract.tcl portfetch.tcl portmain.tcl portbuild.tcl portpatch.tcl portutil.tcl portinstall.tcl portregistry.tcl portdepends.tcl portinstall.tcl portuninstall.tcl portregistry.tcl portdepends.tcl portclean.tcl portpackage.tcl

all:

clean:

install:
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${SRCS}; do \
		install -c -o root -g admin -m 444 $$file ${INSTALLDIR}; \
	done
	../pkg_mkindex.tcl ${INSTALLDIR}
