# $Id$

.SUFFIXES: .m

.m.o:
	${CC} -c -DUSE_TCL_STUBS ${OBJCFLAGS} ${SHLIB_CFLAGS} $< -o $@

.c.o:
	${CC} -c -DUSE_TCL_STUBS ${CFLAGS} ${SHLIB_CFLAGS} $< -o $@

$(SHLIB_NAME):: ${OBJS}
	${SHLIB_LD} ${OBJS} -o ${SHLIB_NAME} ${TCL_STUB_LIB_SPEC} ${SHLIB_LDFLAGS} ${LIBS}

all:: ${SHLIB_NAME}

clean::
	rm -f ${OBJS} ${SHLIB_NAME} so_locations

distclean:: clean

install:: all
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${INSTALLDIR}
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 444 ${SHLIB_NAME} ${INSTALLDIR}
	$(SILENT) $(TCLSH) ../pkg_mkindex.tcl ${INSTALLDIR}
