# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portinstall 1.0
package require portutil 1.0

register com.apple.install target install_main
register com.apple.install provides install
register com.apple.install requires main fetch extract checksum patch configure build
register com.apple.install swdep depends_run depends_lib

# define options
#options make.cmd make.type make.target.all make.target.install

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
    return $rval
}

proc install_main {args} {

    return 0
}

