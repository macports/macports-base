#-*- mode: Fundamental; tab-width: 4; -*-
# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portchecksum 1.0
package require portutil 1.0

register com.apple.checksum target build checksum_main
register com.apple.checksum provides checksum
register com.apple.checksum requires main fetch

# define options
options checksums

proc md5 {file} {
    global distpath

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

proc dmd5 {file} {
    global checksums

    foreach {name type sum} $checksums {
	if {$name == $file} {
	    return $sum
	}
    }
    return -1
}

proc checksum_main {args} {
    global checksums distpath portpath all_dist_files

    # If no files have been downloaded there is nothing to checksum
    if ![info exists all_dist_files] {
	return 0
    }

    if ![info exists checksums] {
	puts "No MD5 checksums."
	return -1
    }

    foreach distfile $all_dist_files {
	set checksum [md5 $distpath/$distfile]
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
