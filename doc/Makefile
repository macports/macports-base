all:

clean:

install:
	@if [ ! -e /etc/ports.conf ]; then \
		set -x; \
		${INSTALL} -o ${BINOWN} -g ${BINGRP} -m 644 ports.conf ${DESTDIR}/etc; \
	fi
