include ../Mk/dports.autoconf.mk

TESTS?=checksums-1 cvs-and-patchsites envvariables site-tags trace universal universal-2 xcodeversion dependencies-c

.PHONY: test clean PortIndex

all:

/tmp/macports-tests/opt/local/etc/ports/sources.conf: sources.conf
	@echo setting up test installation
	rm -rf /tmp/macports-tests/
	mkdir -p /tmp/macports-tests/dports
	mkdir -p /tmp/macports-tests/opt/local/etc/ports/
	mkdir -p /tmp/macports-tests/opt/local/share/
	mkdir -p /tmp/macports-tests/opt/local/var/db/dports/receipts/
	mkdir -p /tmp/macports-tests/opt/local/var/db/dports/build/
	ln -s $(datadir)/darwinports /tmp/macports-tests/opt/local/share/
	ln -s $(PWD)/test /tmp/macports-tests/dports/
	cp sources.conf /tmp/macports-tests/opt/local/etc/ports/

/tmp/macports-tests/dports/PortIndex: /tmp/macports-tests/opt/local/etc/ports/sources.conf PortIndex
	cp PortIndex /tmp/macports-tests/dports/PortIndex

PortIndex:
	portindex

clean:
	rm -rf /tmp/macports-tests/
	rm -f PortIndex

$(bindir)/port:
	@echo "Please install macports before running these tests"
	@exit 1
	
test: clean /tmp/macports-tests/dports/PortIndex /tmp/macports-tests/opt/local/etc/ports/sources.conf
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
