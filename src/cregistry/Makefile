# $Id$

OBJS = registry.o entry.o sql.o vercomp.o util.o file.o
STLIB_NAME = cregistry.a
RANLIB = ranlib

SQLEXT_NAME = macports.sqlext
SQLEXT_OBJS = sqlext.o vercomp.o

include ../../Mk/macports.autoconf.mk

all:: ${STLIB_NAME} ${SQLEXT_NAME}

.c.o:
	${CC} -c -DUSE_TCL_STUBS ${CFLAGS} ${CPPFLAGS} ${SHLIB_CFLAGS} $< -o $@

${STLIB_NAME}:: ${OBJS}
	${STLIB_LD} ${STLIB_NAME} ${OBJS}
	${RANLIB} ${STLIB_NAME}

${SQLEXT_NAME}: ${SQLEXT_OBJS}
	${SHLIB_LD} ${SQLEXT_OBJS} -o $@

clean::
	rm -f ${STLIB_NAME} ${SQLEXT_NAME} ${SQLEXT_OBJS} ${OBJS}

distclean:: clean

test:

install:: all
