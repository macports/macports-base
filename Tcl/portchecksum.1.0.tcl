# global port routines
package provide portchecksum 1.0
package require portutil

register_target checksum portchecksum::main main fetch
namespace eval portchecksum {
	variable options
}

# define globals
globals portchecksum::options md5file

# define options
options portchecksum::options md5file

proc portchecksum::main {args} {
	global portname
	puts "Checksumming port: $portname"
	return 0
}
