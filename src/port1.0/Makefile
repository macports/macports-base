INSTALLDIR=	${DESTDIR}${PREFIX}/share/darwinports/Tcl/port1.0
TARGETSDIR=	${INSTALLDIR}/targets

SRCS=		port.tcl portutil.tcl
TARGETS=	portconfigure.tcl portmain.tcl portbuild.tcl portpatch.tcl portinstall.tcl portinstall.tcl portclean.tcl portpackage.tcl portdestroot.tcl portdeploy.tcl portdistfiles.tcl portdistcache.tcl portcurl.tcl portwget.tcl portcvs.tcl portmd5.tcl portgzip.tcl portbzip2.tcl portzip.tcl portconfigure.tcl portautoconf.tcl portautomake.tcl portxmkmf.tcl portdistclean.tcl portbsdmake.tcl portgnumake.tcl portpbxbuild.tcl

SUBDIR=		resources

all::

clean::

install::
	mkdir -p ${INSTALLDIR}
	mkdir -p ${TARGETSDIR}
	@set -x; for file in ${SRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${INSTALLDIR}; \
	done
	@set -x; for file in ${TARGETS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${TARGETSDIR}; \
	done
	../pkg_mkindex.tcl ${INSTALLDIR}

include ../../Mk/dports.subdir.mk
include ../../Mk/dports.mk
