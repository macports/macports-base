OBJS=		Pextlib.o strsed.o
SHLIB_NAME=	Pextlib.dylib
LDADD+=		-ltcl
PREFIX?=	/opt/local
INSTALLDIR= ${PREFIX}/share/darwinports/Tcl/pextlib1.0

.c.o:
	${CC} -DPIC -O -pipe ${CFLAGS} -c $< -o $@

Pextlib.dylib: ${OBJS}
	${CC} -dynamiclib ${OBJS} -o ${SHLIB_NAME} ${LDADD}

all: Pextlib.dylib

clean:
	rm -f ${OBJS} ${SHLIB_NAME}

install:
	mkdir -p ${INSTALLDIR}
	install -c -o root -g admin -m 444 ${SHLIB_NAME} ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}
