# global port routines
package provide portextract 1.0
package require portutil 1.0

register_target extract portextract::main main fetch checksum
namespace eval portextract {
	variable options
}

# define globals
globals portextract::options

# define options
options portextract::options extract_only extract_command extract_before_args extract_after_args

proc portextract::main {args} {
	global portname workdir distname distdir distfiles

	# Set up defaults
	default portextract::options extract_only $distfiles
	default portextract::options extract_cmd gzip
	default portextract::options extract_before_args -dc
	default portextract::options extract_after_args "| tar -xf -"

	if [info exists use_bzip2] {
		setval portextract::options extract_cmd bzip2
	} elseif [info exists use_zip] {
		setval portextract::options extract_cmd unzip
		setval portextract::options extract_before_args -q
		setval portextract::options extract_after_args -d $workdir
	}

	set portdir [pwd]
	puts "Extracting for $distname"
	if [file exists $workdir] {
		file delete -force $workdir
	}

	file mkdir $workdir
	cd $workdir
	foreach distfile [getval portextract::options extract_only] {
		puts -nonewline "$distfile: "
		flush stdout
		set cmd "[getval portextract::options extract_cmd] [getval portextract::options extract_before_args] $distdir/$distfile [getval portextract::options extract_after_args]"
		if [catch {system $cmd} result] {
			puts $result
			return -1
		}
		puts "done"
	}

	cd $portdir
	return 0
}
