.c.o:
	${CC} -c -DUSE_TCL_STUBS ${CFLAGS} ${TCL_DEFS} ${SHLIB_CFLAGS} $< -o $@

$(SHLIB_NAME):: ${OBJS} config.h
	${SHLIB_LD} ${OBJS} -o ${SHLIB_NAME} ${TCL_STUB_LIB_SPEC} ${LIBS}

all:: ${SHLIB_NAME}

clean::
	rm -f ${OBJS} ${SHLIB_NAME} so_locations

distclean:: clean
	rm -f config.h

install:: all
	mkdir -p ${INSTALLDIR}
	install -c -o ${DSTUSR} -g ${DSTGRP} -m 444 ${SHLIB_NAME} ${INSTALLDIR}
	$(SILENT)../pkg_mkindex.tcl ${INSTALLDIR}
