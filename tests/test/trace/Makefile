include ../../../Mk/macports.autoconf.mk

.PHONY: test

$(bindir)/port:
	@echo "Please install MacPorts before running this test"
	@exit 1

test:
	@PORTSRC=$(PORTSRC) $(bindir)/port clean > /dev/null
	@touch delete-trace
	@touch rename-trace
	@mkdir -p rmdir-trace
	@rm -f create-trace
	@rm -f create-trace-modenv
	@rm -rf mkdir-trace
	@rm -f /tmp/hello-trace
	@rm -f link-trace
	@ln -s /usr/include/unistd.h /tmp/link-trace2
	@-PORTSRC=$(PORTSRC) $(bindir)/port -t test > output 2>&1 || (cat output; exit 1)
	@rm -f link-trace
	@rm -f /tmp/link-trace2
	@rm -f delete-trace
	@rm -f rename-trace
	@rm -f rename-new-trace
	@rm -f create-trace
	@rm -f create-trace-modenv
	@rm -rf mkdir-trace
	@rm -rf rmdir-trace
	@rm -f /tmp/hello-trace
	@sed -e "s|${PWD}|PWD|g" < output > output.sed
	@diff -u master output.sed 2>&1 | tee difference
	@if [ -s difference ]; then \
		exit 1; \
	else \
		rm -f difference output.sed; \
	fi
