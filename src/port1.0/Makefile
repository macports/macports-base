INSTALLDIR= /usr/local/share/darwinports/Tcl/port1.0

all:

clean:
	rm -f pkgIndex.tcl

install:
	mkdir -p ${INSTALLDIR}
	${.CURDIR}/../pkg_mkindex.tcl ${.CURDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} pkgIndex.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} port.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} portchecksum.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} portconfigure.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} portextract.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} portfetch.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} portmain.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} portbuild.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} portpatch.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} portui.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} portutil.tcl ${INSTALLDIR}
	${INSTALL} ${COPY} -o ${LIBOWN} -g ${LIBGRP} -m ${LIBMODE} portinstall.tcl ${INSTALLDIR}
