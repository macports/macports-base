include ../../../Mk/macports.autoconf.mk

.PHONY: test

PWD=$(shell dirname `pwd`)

$(bindir)/port:
	@echo "Please install MacPorts before running this test"
	@exit 1

test:
	@PORTSRC=$(PORTSRC) $(bindir)/port clean > /dev/null
	@mkdir -p ../tracetesttmp
	@-[ "`id -u`" == "0" ] && chown $(RUNUSR) ../tracetesttmp
	@([ "`id -u`" == "0" ] && sudo -u $(RUNUSR) touch ../tracetesttmp/delete-trace) || touch ../tracetesttmp/delete-trace
	@([ "`id -u`" == "0" ] && sudo -u $(RUNUSR) touch ../tracetesttmp/rename-trace) || touch ../tracetesttmp/rename-trace
	@([ "`id -u`" == "0" ] && sudo -u $(RUNUSR) mkdir -p ../tracetesttmp/rmdir-trace) || mkdir -p ../tracetesttmp/rmdir-trace
	@rm -f /tmp/hello-trace
	@ln -sf /usr/include/unistd.h /tmp/link-trace2
	@-[ "`id -u`" == "0" ] && chown -h $(RUNUSR) /tmp/link-trace2
	@PORTSRC=$(PORTSRC) $(bindir)/port -t test > output 2>&1 || (cat output; exit 1)
	@rm -f /tmp/link-trace2
	@rm -f /tmp/hello-trace
	@rm -rf ../tracetesttmp
	@sed -e "s|$(PWD)|PWD|g" < output > output.sed
	@diff -u master output.sed 2>&1 | tee difference
	@if [ -s difference ]; then \
		exit 1; \
	else \
		rm -f difference output.sed; \
	fi

clean::
	@PORTSRC=$(PORTSRC) $(bindir)/port clean >/dev/null
	@rm -f output output.sed difference
	@rm -rf ../tracetesttmp
