include ../Mk/macports.autoconf.mk

TESTS?=checksums-1 cvs-and-patchsites envvariables site-tags trace universal universal-2 xcodeversion dependencies-c

.PHONY: test clean PortIndex

all:

/tmp/macports-tests/opt/local/etc/macports/sources.conf: sources.conf
	@echo setting up test installation
	rm -rf /tmp/macports-tests/
	mkdir -p /tmp/macports-tests/ports
	mkdir -p /tmp/macports-tests/opt/local/etc/macports/
	mkdir -p /tmp/macports-tests/opt/local/share/
	mkdir -p /tmp/macports-tests/opt/local/var/macports/receipts/
	mkdir -p /tmp/macports-tests/opt/local/var/macports/build/
	ln -s $(datadir)/macports /tmp/macports-tests/opt/local/share/
	ln -s $(PWD)/test /tmp/macports-tests/ports/
	cp sources.conf /tmp/macports-tests/opt/local/etc/macports/

/tmp/macports-tests/ports/PortIndex: /tmp/macports-tests/opt/local/etc/macports/sources.conf PortIndex
	cp PortIndex /tmp/macports-tests/ports/PortIndex

PortIndex:
	portindex

clean:
	rm -rf /tmp/macports-tests/
	rm -f PortIndex

$(bindir)/port:
	@echo "Please install MacPorts before running these tests"
	@exit 1

test: clean /tmp/macports-tests/ports/PortIndex /tmp/macports-tests/opt/local/etc/macports/sources.conf
	@for testname in $(TESTS); do\
	    subdir=test/$$testname; \
		echo ===\> test ${DIRPRFX}$$subdir; \
		if [ -e ${DIRPRFX}$$subdir/Makefile ]; then \
			( cd $$subdir && \
				$(MAKE) DIRPRFX=${DIRPRFX}$$subdir/ PORTSRC=$(PWD)/test-ports.conf test) || exit 1; \
		else \
			( cd $$subdir && \
				PORTSRC=$(PWD)/test-ports.conf $(bindir)/port clean > /dev/null && \
				PORTSRC=$(PWD)/test-ports.conf $(bindir)/port test > output 2>&1 \
					|| (cat output; exit 1) && \
			sed -e "s|${PWD}|PWD|g" < output > output.sed && \
			diff output.sed master 2>&1 | tee difference && \
			if [ -s difference ]; then \
				exit 1; \
			else \
				rm -f difference output.sed; \
			fi) \
		fi || exit 1; \
	done
	@rm -rf /tmp/macports-tests/
	@rm -f PortIndex

install:

distclean: clean
