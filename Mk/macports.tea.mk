PKGINDEX ?= pkgIndex.tcl

all:: ${SHLIB_NAME} ${PKGINDEX}

# OBJS are *.o produced from *.c with header dependencies in *.d
OBJSDEP = ${OBJS:.o=.d}
-include ${OBJSDEP}

%.o: %.c
	${CC} -c -DUSE_TCL_STUBS -DTCL_NO_DEPRECATED ${CFLAGS} ${CPPFLAGS} ${SHLIB_CFLAGS} -MMD $< -o $@

$(SHLIB_NAME): ${OBJS}
	${SHLIB_LD} ${OBJS} -o ${SHLIB_NAME} ${TCL_STUB_LIB_SPEC} ${SHLIB_LDFLAGS} ${LIBS}

pkgIndex.tcl: $(SHLIB_NAME)
	$(SILENT) ../pkg_mkindex.sh . || ( rm -rf $@ && exit 1 )

clean::
	rm -f ${OBJS} ${OBJSDEP} ${SHLIB_NAME} so_locations pkgIndex.tcl

distclean:: clean

INSTALLTARGET ?= install-real

install:: $(INSTALLTARGET)
$(INSTALLTARGET):: all
	$(INSTALL) -d -o "${DSTUSR}" -g "${DSTGRP}" -m "${DSTMODE}" "${INSTALLDIR}"
	$(INSTALL) -o "${DSTUSR}" -g "${DSTGRP}" -m 444 ${SHLIB_NAME} "${INSTALLDIR}"
	$(INSTALL) -o "${DSTUSR}" -g "${DSTGRP}" -m 444 pkgIndex.tcl "${INSTALLDIR}"
