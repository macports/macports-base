# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portinstall 1.0
package require portutil 1.0

register com.apple.install target install_main
register com.apple.install provides install
register com.apple.install requires main fetch extract checksum patch configure build depends_run depends_lib

# define options
options make.cmd make.type make.target.install contents

set UI_PREFIX "---> "

proc fileinfo_for_index {flist} {
    set rval {}
    foreach fentry $flist {
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

proc install_main {args} {
    global portname portpath workdir worksrcdir prefix make.type make.cmd make.worksrcdir contents make.target.install UI_PREFIX

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
	if [info exists contents] {
	    set plist [fileinfo_for_index $contents]
	    # For now, just write this to a file for debugging.
	    if ![catch {set fout [open "$portpath/pkg-contents" w 0644]}] {
		puts $fout "\# Format: {{filename uid gid mode size {md5}} ... }
		puts $fout $plist
		close $fout
	    } else {
		ui_error "Cannot open $portpath/pkg-contents file."
	    }
	}
    } else {
	ui_error "Installation failed."
	return -1
    }
    return 0
}

