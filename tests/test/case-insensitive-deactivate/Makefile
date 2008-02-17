include ../../../Mk/macports.autoconf.mk

TESTFILE=$(prefix)/var/macports/case
TESTPORT1=casesensitive
TESTPORT2=CaseSensitivE

.PHONY: test

$(bindir)/port:
	@echo "Please install MacPorts before running this test"
	@exit 1

test:
	@echo port install $(TESTPORT1)
	@sed 's/@name@/$(TESTPORT1)/' Portfile.in > Portfile
	@PORTSRC=$(PORTSRC) $(bindir)/port -x install > output 2>&1 || (cat output; exit 1)
	@if [ ! -f $(TESTFILE) ]; then \
		echo "FAILED: File should exist after install: $(TESTFILE)" && exit 1; \
	fi
	@echo port uninstall $(TESTPORT2)
	@sed 's/@name@/$(TESTPORT2)/' Portfile.in > Portfile
	@PORTSRC=$(PORTSRC) $(bindir)/port -x uninstall > output 2>&1 || (cat output; exit 1)
	@if [ -f $(TESTFILE) ]; then \
		rm $(TESTFILE); \
		echo "FAILED: File should NOT exist after uninstall: $(TESTFILE)" && exit 1; \
	else \
		echo "SUCCESS!"; \
	fi
	rm Portfile
	rm output
