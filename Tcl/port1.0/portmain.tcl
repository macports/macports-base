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

# define globals: portname portversion categories maintainers
globals portmain::options portname portversion portrevision categories maintainers workdir worksrcdir no_worksubdir filedir

# define options: portname, portversion, categories, maintainers
options portmain::options portname portversion portrevision categories maintainers workdir worksrcdir no_worksubdir filedir

proc portmain::main {args} {
	global portname
	default portmain::options workdir work
	default portmain::options filedir files
	default portmain::options portrevision 0
	return 0
}
