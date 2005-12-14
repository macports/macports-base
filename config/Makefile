include ../Mk/dports.autoconf.mk

all:

clean:

test:

distclean: clean

install::
	$(INSTALL) -d -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${DESTDIR}${portconfigdir}
	$(INSTALL) -o ${DSTUSR} -g ${DSTGRP} -m 644 dp_version ${DESTDIR}${portconfigdir}
