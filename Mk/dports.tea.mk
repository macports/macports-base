.c.o:
	${CC} -c -DUSE_TCL_STUBS ${CFLAGS} ${SHLIB_CFLAGS} $< -o $@

$(SHLIB_NAME):: ${OBJS}
	${SHLIB_LD} ${OBJS} -o ${SHLIB_NAME} ${TCL_STUB_LIB_SPEC} ${LIBS}

all:: ${SHLIB_NAME}

clean::
	rm -f ${OBJS} ${SHLIB_NAME}

install:: all
	mkdir -p ${INSTALLDIR}
	install -c -o "${DSTUSR}" -g "${DSTGRP}" -m 444 ${SHLIB_NAME} ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}
