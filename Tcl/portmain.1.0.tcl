# global port routines
# the 'main' target is provided by this package
# main is a magic target and should not be replaced
package provide portmain 1.0
package require portutil

register_target main portmain::main
namespace eval portmain {
	variable options
	variable targets
}

# define globals: portname portversion categories maintainers
globals portmain::options portname portversion portrevision categories maintainers workdir worksrc no_worksubdir

# define options: portname, portversion, categories, maintainers
options portmain::options portname portversion portrevision categories maintainers workdir worksrc no_worksubdir

proc portmain::main {args} {
	global portname
	default portmain::options workdir work
	return 0
}
