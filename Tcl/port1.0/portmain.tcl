# global port routines
# the 'main' target is provided by this package
# main is a magic target and should not be replaced
package provide portmain 1.0
package require portutil 1.0

register com.apple.main target build portmain::main
register com.apple.main provides main

namespace eval portmain {
	variable options
	variable targets
}

# define options
options portmain::options portname portversion portrevision categories maintainers workdir worksrcdir no_worksubdir filedir distname

proc portmain::main {args} {
	global portname distname
	default portmain::options workdir work
	default portmain::options filedir files
	default portmain::options portrevision 0
	if {[tbool portmain::options no_worksubdir]} {
		default portmain::options worksrcdir ""
	} else {
		default portmain::options worksrcdir $portmain::options(distname)
	}
	return 0
}
