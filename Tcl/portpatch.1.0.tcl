# global port routines
package provide portpatch 1.0
package require portutil

register_target patch portpatch::main main fetch checksum extract
namespace eval portpatch {
	variable options
}

proc portpatch::main {args} {
	global portname
	puts "Patching port: $portname"
	return 0
}
