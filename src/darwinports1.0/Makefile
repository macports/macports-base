all:

clean:
	rm -f pkgIndex.tcl

install:
	mkdir -p /System/Library/Tcl/8.3/darwinports1.0
	${.CURDIR}/../pkg_mkindex.tcl ${.CURDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} darwinports.tcl /System/Library/Tcl/8.3/darwinports1.0
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} pkgIndex.tcl /System/Library/Tcl/8.3/darwinports1.0
