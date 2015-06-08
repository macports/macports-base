tclsh=/opt/local/libexec/macports/bin/tclsh8.5

run: port-create.tcl
	$(tclsh) port-create.tcl -url https://www.kernel.org/pub/software/scm/git/git-2.4.2.tar.gz
	$(tclsh) port-create.tcl -url https://www.kernel.org/pub/software/scm/git/git-2.4.2.tar.gz -name foo -version 1.0

test: port-create.tcl all.tcl port-create.test
	$(tclsh) all.tcl
