include ../../../Mk/macports.autoconf.mk

.PHONY: test

$(bindir)/port:
	@echo "Please install MacPorts before running this test"
	@exit 1

test:
	@PORTSRC=$(PORTSRC) $(bindir)/port configure >/dev/null 2>&1
	@cp statefile work/.macports.statefile-unknown-version.state
	@PORTSRC=$(PORTSRC) $(bindir)/port destroot >output 2>&1 || (cat output; exit 1)
	@diff -u master output || (echo "statfile version 3 was accepted, although it shouldn't (this is a hacky test, which might also fail if you change the number of pahses)"; exit 1)
	@PORTSRC=$(PORTSRC) $(bindir)/port clean >/dev/null 2>&1
	@rm output
