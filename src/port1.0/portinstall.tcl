# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portinstall 1.0
package require portutil 1.0
package require portregistry 1.0

register com.apple.install target install_main
register com.apple.install provides install
register com.apple.install requires main fetch extract checksum patch configure build depends_run depends_lib

# define options
options make.cmd make.type make.target.install contents

set UI_PREFIX "---> "

proc fileinfo_for_index {flist} {
    global prefix
    set rval {}
    foreach file $flist {
	if [string match /* $file] {
	    set fentry $file
	} else {
	    set fentry [file join $prefix $file ]
	}
	if ![catch {file stat $fentry statvar}] {
	    set md5regex "^(MD5)\[ \]\\(($fentry)\\)\[ \]=\[ \](\[A-Za-z0-9\]+)\n$"
	    set pipe [open "|md5 $fentry" r]
	    set line [read $pipe]
	    if {[regexp $md5regex $line match type filename sum] == 1} {
		lappend rval [list $fentry $statvar(uid) $statvar(gid) $statvar(mode) $statvar(size) $line]
	    }
	}
    }
    return [list $rval]
}

proc proc_disasm {pname} {
    return [list proc $pname [list [info args $pname]] [info body $pname]]
}

proc install_main {args} {
    global portname portversion portpath categories description depends_run contents pkg_install pkg_deinstall workdir worksrcdir prefix make.type make.cmd make.worksrcdir make.target.install UI_PREFIX

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
    default make.target.install install
    ui_msg "$UI_PREFIX Installing $portname with target ${make.target.install}"
    if ![catch {system "${make.cmd} ${make.target.install}"}] {
	# it installed successfully, so now we must register it
	set rhandle [registry_new $portname $portversion]
	ui_msg "$UI_PREFIX Registering $portname"
	set data {}
	lappend data [list prefix $prefix]
	lappend data [list categories $categories]
	if [info exists description] {
	    lappend data [list description $description]
	}
	if [info exists depends_run] {
	    lappend data [list run_depends $depends_run]
	}
	if [info exists contents] {
	    set plist [fileinfo_for_index $contents]
	    lappend data [list contents $plist]
	}
	if {[info proc pkg_install] == "pkg_install"} {
	    lappend data [list pkg_install [proc_disasm pkg_install]]
	}
	if {[info proc pkg_deinstall] == "pkg_deinstall"} {
	    lappend data [list pkg_deinstall [proc_disasm pkg_deinstall]]
	}
	registry_store $rhandle $data
	registry_close $rhandle
    } else {
	ui_error "Installation failed."
	return -1
    }
    return 0
}

