# global port routines
package provide portchecksum 1.0
package require portutil 1.0

register target checksum portchecksum::main
register requires checksum main fetch

namespace eval portchecksum {
	variable options
}

# define globals
globals portchecksum::options md5file

# define options
options portchecksum::options md5file

proc portchecksum::md5 {file} {
	global distdir
	set md5regex "^(MD5)\[ \]\\(($file)\\)\[ \]=\[ \](\[A-Za-z0-9\]+)\n$"
	set pipe [open "|md5 ${file}" r]
	set line [read $pipe]
	if {[regexp $md5regex $line match type filename sum] == 1} {
		return $sum
	} else {
		# XXX Handle this error beter
		puts $line
		puts "md5sum failed!"
		return -1
	}
}

proc portchecksum::dmd5 {file} {
	set fd [open [getval portchecksum::options md5file] r]
	set md5regex "^(MD5)\[ \]\\(($file)\\)\[ \]=\[ \](\[A-Za-z0-9\]+$)"
	while {[gets $fd line] >= 0} {
		if {[regexp $md5regex $line match type filename sum] == 1} {
			if {$filename == $file} {
				close $fd
				return $sum
			}
		}
	}
	close $fd
	return -1
}

proc portchecksum::main {args} {
	global distdir portpath portdir all_dist_files

	# If no files have been downloaded there is nothing to checksum
	if ![info exists all_dist_files] {
		return 0
	}

	default portchecksum::options md5file $portdir/distinfo

	if ![file isfile [getval portchecksum::options md5file]] {
		puts "No MD5 checksum file."
		return -1
	}

	foreach distfile $all_dist_files {
		set checksum [md5 $portpath/$distdir/$distfile]
		set dchecksum [dmd5 $distfile]
		if {$dchecksum == -1} {
			puts "No checksum recorded for $distfile"
			return -1
		}
		if {$checksum == $dchecksum} {
			puts "Checksum OK for $distfile"
		} else {
			puts "Checksum mismatch for $distfile"
			return -1
		}
	}
	return 0
}
