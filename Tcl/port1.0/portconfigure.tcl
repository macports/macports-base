# global port routines
package provide portconfigure 1.0
package require portutil 1.0

register target configure portconfigure::main 
register requires main fetch extract checksum patch

namespace eval portconfigure {
	variable options
}

# define globals
globals portconfigure::options configure configure.type configure.args configure.worksrcdir automake automake.env automake.args autoconf autoconf.env autoconf.args xmkmf libtool

# define options
options portconfigure::options configure configure.type configure.args configure.worksrcdir automake automake.env automake.args autoconf autoconf.env autoconf.args xmkmf libtool

proc portconfigure::main {args} {
	global portname portpath workdir

	if [isval portconfigure::options configure.worksrcdir] {
		set configpath ${pathpath}/${workdir}/${worksrcdir}/${configure.worksrcdir}
	} else {
		set configpath ${pathpath}/${workdir}/${worksrcdir}
	}

	cd $configpath
	if [isval portconfigure::options automake] {
		# XXX depend on automake
		
	}
		

	return 0
}
