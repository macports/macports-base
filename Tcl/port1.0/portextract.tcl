# global port routines
package provide portextract 1.0
package require portutil 1.0

register target extract portextract::main 
register requires extract fetch checksum

namespace eval portextract {
	variable options
}

# define globals
globals portextract::options

# define options
options portextract::options extract_only extract_command extract_before_args extract_after_args

proc portextract::main {args} {
	global portname portpath portdir workdir distname distdir distfiles

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
		setval portextract::options extract_after_args -d $portdir/$workdir
	}

	puts "Extracting for $distname"
	if [file exists $workdir] {
		file delete -force $portdir/$workdir
	}

	file mkdir $portdir/$workdir
	cd $portdir/$workdir
	foreach distfile [getval portextract::options extract_only] {
		puts -nonewline "$distfile: "
		flush stdout
		set cmd "[getval portextract::options extract_cmd] [getval portextract::options extract_before_args] $portpath/$distdir/$distfile [getval portextract::options extract_after_args]"
		if [catch {system $cmd} result] {
			puts $result
			return -1
		}
		puts "done"
	}
	return 0
}
