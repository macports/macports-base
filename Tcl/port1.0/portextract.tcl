# global port routines
package provide portextract 1.0
package require portutil 1.0

register com.apple.extract target build portextract::main 
register com.apple.extract provides extract
register com.apple.extract requires fetch checksum

namespace eval portextract {
	variable options
}

# define options
options portextract::options extract.only extract.cmd extract.before_args extract.after_args

proc portextract::main {args} {
	global portname portpath portpath workdir distname distpath distfiles use_bzip2

	# Set up defaults
	default portextract::options extract.only $distfiles
	default portextract::options extract.cmd gzip
	default portextract::options extract.before_args -dc
	default portextract::options extract.after_args "| tar -xf -"

	if [info exists use_bzip2] {
		set portextract::options(extract.cmd) bzip2
	} elseif [info exists use_zip] {
		set portextract::options(extract.cmd) unzip
		set portextract::options(extract.before_args) -q
		set portextract::options(extract.after_args) "-d $portpath/$workdir"
	}

	puts "Extracting for $distname"
	if [file exists $workdir] {
		file delete -force $portpath/$workdir
	}

	file mkdir $portpath/$workdir
	cd $portpath/$workdir
	foreach distfile $portextract::options(extract.only) {
		puts -nonewline "$distfile: "
		flush stdout
		set cmd "$portextract::options(extract.cmd) $portextract::options(extract.before_args) $distpath/$distfile $portextract::options(extract.after_args)"
		if [catch {system $cmd} result] {
			puts $result
			return -1
		}
		puts "done"
	}
	return 0
}
