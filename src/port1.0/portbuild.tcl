# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portbuild 1.0
package require portutil 1.0

register com.apple.build target build_main build_init
register com.apple.build provides build 
register com.apple.build requires main fetch extract checksum patch configure depends_build depends_lib

# define options
options make.cmd make.type make.target.all make.target.install

set UI_PREFIX "---> "

proc build_init {args} {
    global make.type make.cmd make.target.all make.worksrcdir
    default make.type bsd
    default make.cmd make
    default make.target.all all

    switch -exact -- ${make.type} {
	bsd {
	    set make.cmd bsdmake
	}
	gnu {
	    set make.cmd gnumake
	}
    }
}

proc build_main {args} {
    global portname portpath workdir prefix make.type make.cmd make.target.all UI_PREFIX worksrcdir

    if [info exists make.worksrcdir] {
	set configpath ${portpath}/${workdir}/${worksrcdir}/${make.worksrcdir}
    } else {
	set configpath ${portpath}/${workdir}/${worksrcdir}
    }

    cd $configpath
	
    ui_msg "$UI_PREFIX Building $portname with target ${make.target.all}"
    system "${make.cmd} ${make.target.all}"
    return 0
}

