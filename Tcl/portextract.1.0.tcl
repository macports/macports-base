# global port routines
package provide portextract 1.0
package require portutil

register_target extract portextract::main main fetch checksum
namespace eval portextract {
	variable options
}

# define globals
globals portextract::options

# define options
options portextract::options extract_only extract_command extract_before_args extract_after_args

proc portextract::main {args} {
	global portname workdir distfiles

	# Set up defaults
	default portextract::options extract_only $distfiles
	default portextract::options extract_cmd gzip
	default portextract::options extract_before_args -dc
	default portextract::options extract_after_args "|tar -xf -"

	set portdir [pwd]

	if [file exists $workdir] {
		file delete -force $workdir
	}

	file mkdir $workdir
	cd $workdir

	puts "Extracting port: $portname"
	return 0
}
