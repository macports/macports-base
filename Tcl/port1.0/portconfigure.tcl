# global port routines
package provide portconfigure 1.0
package require portutil 1.0

register com.apple.configure target build portconfigure::main
register com.apple.configure provides configure
register com.apple.configure requires main fetch extract checksum patch

namespace eval portconfigure {
	variable options
}

# define globals
globals portconfigure::options configure configure.type configure.args configure.worksrcdir automake automake.env automake.args autoconf autoconf.env autoconf.args xmkmf libtool

# define options
options portconfigure::options configure configure.type configure.args configure.worksrcdir automake automake.env automake.args autoconf autoconf.env autoconf.args xmkmf libtool

proc portconfigure::main {args} {
	global portname portpath workdir worksrcdir prefix

	if [isval portconfigure::options configure.worksrcdir] {
		set configpath ${portpath}/${worksrcdir}/${configure.worksrcdir}
	} else {
		set configpath ${portpath}/${worksrcdir}
	}

	cd $configpath
	if [testbool portconfigure::options automake] {
		# XXX depend on automake
	}

	if [testbool portconfigure::options configure]  {
		system "./configure --prefix=${prefix} [getval portconfigure::options configure.args]"
	}

	return 0
}
