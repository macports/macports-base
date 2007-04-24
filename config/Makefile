include ../Mk/macports.autoconf.mk

all:

clean:

test:

distclean: clean

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${DESTDIR}${portconfigdir}
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 mp_version ${DESTDIR}${portconfigdir}
