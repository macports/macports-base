# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portbuild 1.0
package require portutil 1.0

register com.apple.build target build build_main 
register com.apple.build provides build 
register com.apple.build requires main fetch extract checksum patch configure
register com.apple.build swdep build depends_build

# define options
options make.cmd make.type make.target.all make.target.install

proc build_main {args} {
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
	set make.cmd bsdmake
    }
    default make.target.all all
    system "${make.cmd} ${make.target.all}"
    return 0
}

