include ../../../Mk/macports.autoconf.mk

.PHONY: test

$(bindir)/port:
	@echo "Please install MacPorts before running this test"
	@exit 1

test:
	@PORTSRC=$(PORTSRC) $(bindir)/port clean > /dev/null
	@sh -c "export PORTSRC=$(PORTSRC); $(bindir)/port info --variants" > output 2>&1 || (cat output; exit 1)
	@diff -u master output 2>&1 | tee difference
	@if [ -s difference ]; then \
		exit 1; \
	else \
		rm -f difference; \
	fi
