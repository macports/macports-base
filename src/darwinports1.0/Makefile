INSTALLDIR=	/System/Library/Tcl/8.3/darwinports1.0
SRCS=		darwinports.tcl darwinportsui.tcl

all:

clean:

install:
	mkdir -p ${INSTALLDIR}
	@set -x; for file in ${SRCS}; do \
		install -c -o root -g admin -m 444 $$file ${INSTALLDIR}; \
	done
	../pkg_mkindex.tcl ${INSTALLDIR}
