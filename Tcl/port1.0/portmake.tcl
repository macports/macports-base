# global port routines
package provide portmake 1.0
package require portutil 1.0

register com.apple.make target build portmake::main
register com.apple.make provides make
register com.apple.make requires main fetch extract checksum patch configure

namespace eval portmake {
	variable options
}

# define options
options portmake::options make make.cmd make.type make.target.all make.target.install

proc portmake::main {args} {
	global portname portpath workdir worksrcdir prefix

	default portmake::options make yes
	default portmake::options make.type bsd
	default portmake::options make.cmd make
	if ![tbool portmake::options make] {
		return 0
	}

	if [info exists portmake::options(make.worksrcdir)] {
		set configpath ${portpath}/${workdir}/${worksrcdir}/${make.worksrcdir}
	} else {
		set configpath ${portpath}/${workdir}/${worksrcdir}
	}

	cd $configpath
	
	if {$portmake::options(make.type) == "bsd"} {
		default portmake::options make.cmd bsdmake
	}
	default portmake::options make.target.all all
	system "$portmake::options(make.cmd) $portmake::options(make.target.all)"

	return 0
}
