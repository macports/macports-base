SRCS=		darwinports.tcl

all:

clean:

install:
	@mkdir -p ${DESTROOT}`./tcldir.sh`
	@set -x; for file in ${SRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${DESTROOT}`./tcldir.sh`; \
	done
	@../pkg_mkindex.tcl ${DESTROOT}`./tcldir.sh`

include ../../Mk/dports.mk
