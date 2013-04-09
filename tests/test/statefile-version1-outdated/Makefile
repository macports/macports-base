include ../../../Mk/macports.autoconf.mk

.PHONY: test

$(bindir)/port:
	@echo "Please install MacPorts before running this test"
	@exit 1

test:
	@PORTSRC=$(PORTSRC) $(bindir)/port configure >/dev/null 2>&1
	@cp statefile work/.macports.statefile-version1-outdated.state
	@touch -t 197001010000.09 work/.macports.statefile-version1-outdated.state
	@PORTSRC=$(PORTSRC) $(bindir)/port destroot >output 2>&1 || (cat output; exit 1)
	@diff -u master output || (echo "statfile version 1 was outdated but didn't cause a fresh build"; exit 1)
	@PORTSRC=$(PORTSRC) $(bindir)/port clean >/dev/null 2>&1
	@rm output
