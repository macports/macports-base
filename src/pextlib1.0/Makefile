OBJS=		Pextlib.o strsed.o
SHLIB_NAME=	Pextlib
LDADD+=		-ltcl
PREFIX?=	/opt/local
INSTALLDIR= ${PREFIX}/share/darwinports/Tcl/pextlib1.0

.c.o:
	./compile.sh ${CFLAGS} $< -o $@

Pextlib.dylib: ${OBJS}
	./link.sh ${SHLIB_NAME} ${OBJS}

all: Pextlib.dylib

clean:
	rm -f ${OBJS} ${SHLIB_NAME}

install:
	mkdir -p ${INSTALLDIR}
	install -c -o root -g wheel -m 444 ${SHLIB_NAME} ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}
