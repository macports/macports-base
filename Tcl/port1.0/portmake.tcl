#-*- mode: Fundamental; tab-width: 4; -*-
# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portmake 1.0
package require portutil 1.0

register com.apple.make target build make_main
register com.apple.make provides make
register com.apple.make requires main fetch extract checksum patch configure

# define options
options make.cmd make.type make.target.all make.target.install

proc make_main {args} {
    global portname portpath workdir worksrcdir prefix make.type make.cmd make.worksrcdir make.target.all

    default make.type bsd
    default make.cmd make

    if [info exists make.worksrcdir] {
	set configpath ${portpath}/${workdir}/${worksrcdir}/${make.worksrcdir}
    } else {
	set configpath ${portpath}/${workdir}/${worksrcdir}
    }

    cd $configpath
    if {${make.type} == "bsd"} {
	default make.cmd bsdmake
    }
    default make.target.all all
    system "${make.cmd} ${make.target.all}"
    return 0
}

