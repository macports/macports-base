# global port routines
package provide portextract 1.0
package require portutil

register_target extract portextract::main main fetch checksum
namespace eval portextract {
	variable options
}

proc portextract::main {args} {
	global portname
	puts "Extracting port: $portname"
	return 0
}
