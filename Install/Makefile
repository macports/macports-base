PACKAGE_NAME=darwinports
PACKAGE_VERSION=1.0
PACKAGE_DIR=${PACKAGE_NAME}${PACKAGE_VERSION}
PREFIX=/System/Library/Tcl/8.3/${PACKAGE_DIR}/

all: install

pkg_index:
	./pkg_mkindex.tcl ${PACKAGE_NAME}${PACKAGE_VERSION}

install: pkg_index
	mkdir -p ${PREFIX}
	install ${PACKAGE_DIR}/${PACKAGE_NAME}.tcl ${PREFIX}
	install ${PACKAGE_DIR}/pkgIndex.tcl ${PREFIX}
