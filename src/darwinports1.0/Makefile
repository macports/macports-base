SRCS=		darwinports.tcl darwinportsui.tcl

all:

clean:

install:
	@mkdir -p `./tcldir.sh`
	@set -x; for file in ${SRCS}; do \
		install -c -o root -g wheel -m 444 $$file `./tcldir.sh`; \
	done
	@../pkg_mkindex.tcl `./tcldir.sh`
