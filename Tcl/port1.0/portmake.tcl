# global port routines
package provide portmake 1.0
package require portutil 1.0

register com.apple.make target build make_main
register com.apple.make provides make
register com.apple.make requires main fetch extract checksum patch configure

global make_opts

# define options
options make_opts make make.cmd make.type make.target.all make.target.install

proc make_main {args} {
    global make_opts portname portpath workdir worksrcdir prefix

    default make_opts make yes
    default make_opts make.type bsd
    default make_opts make.cmd make
    if ![tbool make_opts make] {
	return 0
    }

    if [info exists make_opts(make.worksrcdir)] {
	set configpath ${portpath}/${workdir}/${worksrcdir}/${make.worksrcdir}
    } else {
	set configpath ${portpath}/${workdir}/${worksrcdir}
    }

    cd $configpath
    if {$make_opts(make.type) == "bsd"} {
	default make_opts make.cmd bsdmake
    }
    default make_opts make.target.all all
    system "$make_opts(make.cmd) $make_opts(make.target.all)"
    return 0
}

