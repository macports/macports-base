# global port routines
# the 'main' target is provided by this package
# main is a magic target and should not be replaced
package provide portmain 1.0
package require portutil 1.0

register target main portmain::main
namespace eval portmain {
	variable options
	variable targets
}

# define globals: portname portversion categories maintainers
globals portmain::options portname portversion portrevision categories maintainers workdir worksrc no_worksubdir filedir

# define options: portname, portversion, categories, maintainers
options portmain::options portname portversion portrevision categories maintainers workdir worksrc no_worksubdir filedir

proc portmain::main {args} {
	global portname
	default portmain::options workdir work
	default portmain::options filedir files
	return 0
}
