OBJS=		Pextlib.o strsed.o
SHLIB_NAME=	Pextlib.dylib
LDADD+=		-ltcl
INSTALLDIR= /usr/local/share/darwinports/Tcl/pextlib1.0

.c.o:
	${CC} ${CFLAGS} -c $< -o $@

Pextlib.dylib: ${OBJS}
	${CC} -dynamiclib -o ${SHLIB_NAME} ${LDADD}

clean:
	rm -f ${OBJS} ${SHLIB_NAME}

install:
	mkdir -p ${INSTALLDIR}
	install -c -o root -g wheel -m 444 ${SHLIB_NAME} ${INSTALLDIR}
	../pkg_mkindex.tcl ${INSTALLDIR}
