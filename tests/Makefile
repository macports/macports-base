include ../Mk/macports.autoconf.mk

TESTS?=checksums-1 cvs-and-patchsites envvariables site-tags trace universal universal-2 xcodeversion dependencies-c dependencies-d dependencies-e case-insensitive-deactivate variants

PWD=$(shell pwd)

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
	$(bindir)/portindex

clean:
	rm -rf /tmp/macports-tests/
	rm -f PortIndex
	rm -f PortIndex.quick
	for testname in $(TESTS); do \
		rm -f test/$$testname/{output,output.sed,difference,work}; \
	done

$(bindir)/port:
	@echo "Please install MacPorts before running these tests"
	@exit 1

# Run all tests
# Use TESTS to choose which tests to run
# For example: make test TESTS="checkums-1 universal"
test: clean /tmp/macports-tests/ports/PortIndex /tmp/macports-tests/opt/local/etc/macports/sources.conf
	@for testname in $(TESTS); do\
	    subdir=test/$$testname; \
		echo ===\> test ${DIRPRFX}$$subdir; \
		if [ -e ${DIRPRFX}$$subdir/Makefile ]; then \
			( cd $$subdir && \
				$(MAKE) DIRPRFX=${DIRPRFX}$$subdir/ PORTSRC=$(PWD)/test-macports.conf test) || exit 1; \
		else \
			( cd $$subdir && \
				PORTSRC=$(PWD)/test-macports.conf $(bindir)/port clean > /dev/null && \
				PORTSRC=$(PWD)/test-macports.conf $(bindir)/port test > output 2>&1 \
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

# Run specific test
# Prepend the directory name with "test-" and use it as target
# For example: make test-checksums-1
test-%:
	$(MAKE) TESTS="$(@:test-%=%)" test

install:

distclean: clean
