PACKAGE_NAME=darwinports
PACKAGE_VERSION=1.0
PACKAGE_DIR=${PACKAGE_NAME}${PACKAGE_VERSION}
PREFIX=/System/Library/Tcl/8.3/${PACKAGE_DIR}/

all: install

pkg_index:
	${.CURDIR}/../pkg_mkindex.tcl ${.CURDIR}/

install: pkg_index
	mkdir -p ${PREFIX}
	install ${PACKAGE_NAME}.tcl ${PREFIX}
	install pkgIndex.tcl ${PREFIX}
