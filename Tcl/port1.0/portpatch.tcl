# global port routines
package provide portpatch 1.0
package require portutil 1.0

register_target patch portpatch::main main fetch checksum extract
namespace eval portpatch {
	variable options
}

proc portpatch::main {args} {
	global portname patchfiles

	if ![info exists patchfiles] {
		return 0
	}

	foreach patch $patchfiles {
		puts $patch
	}
	return 0
}
