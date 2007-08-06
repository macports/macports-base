OBJS=       registry.o entry.o sql.o

include ../../Mk/macports.autoconf.mk
include ../../Mk/macports.tea.mk

.PHONY: test

test:: ${SHLIB_NAME}
	${TCLSH} tests/entry.tcl ${SHLIB_NAME}

all:: ${OBJS}

clean::
	rm -f ${OBJS} so_locations

distclean:: clean
