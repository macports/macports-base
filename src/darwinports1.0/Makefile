SRCS=		darwinports.tcl

all:

clean:

install:
	@mkdir -p `./tcldir.sh`
	@set -x; for file in ${SRCS}; do \
		install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 $$file `./tcldir.sh`; \
	done
	@../pkg_mkindex.tcl `./tcldir.sh`

include ../../Mk/dports.mk
