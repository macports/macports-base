all:

clean:

install:
	@if [ ! -e /etc/ports.conf ]; then \
		set -x; \
		install -o root -g wheel -m 644 ports.conf ${DESTDIR}/etc; \
	fi
