SRCS=		darwinports.tcl darwinports_dlist.tcl

all:

clean:

install:
	@mkdir -p ${DESTDIR}`./tcldir.sh`
	@set -x; for file in ${SRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file ${DESTDIR}`./tcldir.sh`; \
	done
	@../pkg_mkindex.tcl ${DESTDIR}`./tcldir.sh`

include ../../Mk/dports.mk
