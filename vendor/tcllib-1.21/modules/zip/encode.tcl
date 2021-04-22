# -*- tcl -*-
# ### ### ### ######### ######### #########
## Copyright (c) 2008-2009 ActiveState Software Inc.
##                         Andreas Kupries
## BSD License
##
# Package providing commands for the generation of a zip archive.

# FUTURE: Write convenience command to zip up a whole directory.

package require Tcl 8.4
package require logger   ; # Tracing
package require Trf      ; # Wrapper to zlib
package require crc32    ; # Tcllib, crc calculation
package require snit     ; # Tcllib, OO core
package require zlibtcl  ; # Zlib usage. No commands, access through Trf
package require fileutil ; # zipdir convenience method

# ### ### ### ######### ######### #########
##

logger::initNamespace ::zipfile::encode
snit::type            ::zipfile::encode {

    constructor {} {}
    destructor {}

    # ### ### ### ######### ######### #########
    ##

    method comment: {text} {
	set comment $text
	return
    }

    method file: {dst owned src {noCompress 0}} {
	if {[info exists files($dst)]} {
	    return -code error -errorcode {ZIP ENCODE DUPLICATE PATH} \
		"Duplicate destination path \"$dst\""
	}
	if {![string is boolean -strict $owned]} {
	    return -code error -errorcode {ZIP ENCODE OWNED VALUE BOOLEAN} \
		"Expected boolean, got \"$owned\""
	}

	if {[catch {
	    file stat $src s
	} msg]} {
	    # Unreadable file or directory, or broken link. Ignore.
	    # TODO: Make handling configurable.
	    return
	}

	if {$::tcl_platform(platform) ne "windows"} {
	    file stat $src x
	    set attr $x(mode)
	    unset x
	} else {
	    set attr 33279 ; # 0o777 = rwxrwxrwx
	}

	if {[file isdirectory $src]} {
	    set files($dst/) [list 0 {} 0 $s(ctime) $attr $noCompress]
	} else {
	    set files($dst) [list $owned $src [file size $src] $s(ctime) $attr $noCompress]
	    log::debug "file: files($dst) = \{$files($dst)\}"
	}
	lappend files_ordering $dst
	return
    }

    method write {archive} {
	set ch [setbinary [open $archive w]]

	set dstsorted $files_ordering

	# Archive = <
	#  afile ...
	#  centralfileheader ...
	#  endofcentraldir
	# >

	foreach dst $dstsorted {
	    $self writeAFile $ch $dst
	}

	set cfh [tell $ch]

	foreach dst $dstsorted {
	    $self writeCentralFileHeader $ch $dst
	}

	set cfhsize [expr {[tell $ch] - $cfh}]

	$self writeEndOfCentralDir $ch $cfh $cfhsize
	close $ch
	return
    }

    # ### ### ### ######### ######### #########
    ##

    variable comment        {}
    variable files -array   {}
    variable files_ordering {}

    # ### ### ### ######### ######### #########
    ##

    method writeAFile {ch dst} {
	# AFile = <
	#  localfileheader
	#  file data
	# >

	foreach {owned src size ctime attr noCompress} $files($dst) break
	log::debug "write-a-file: $dst = $owned $size $src noCompress = $noCompress"

	# Determine if compression of the file to store will save us
	# some space. Also compute the crc checksum of the file to put
	# into the archive.

	if {$src ne ""} {
	    set c   [setbinary [open $src r]]
	    set crc [crc::crc32 -chan $c]
	    close $c
	} else {
	    set crc 0
	}

	if {($size == 0) || $noCompress} {
	    set csize $size ; # compressed size is uncompressed
	    set cm    0     ; # uncompressed
	    set gpbf  0     ; # No flags
	} else {
	    set temp [fileutil::tempfile]
	    set in   [setbinary [open $src r]]
	    set out  [setbinary [open $temp w]]

	    # Go for maximum compression

	    zip -mode compress -nowrap 1 -level 9 -attach $out
	    fcopy $in $out
	    close $in
	    close $out

	    set csize [file size $temp]
	    if {$csize < $size} {
		# Compression is good. Throw away the incoming file,
		# should we own it, then switch the upcoming copy
		# operation over to the compressed file. Which we do
		# own.

		if {$owned} {
		    file delete -force $src
		}
		set src   $temp ; # Copy the compressed temp file.
		set owned 1     ; # We own the source file now.
		set cm    8     ; # deflated
		set gpbf  2     ; # flags - deflated maximum
	    } else {
		# No space savings through compression. Throw away the
		# temp file and keep working with the original.

		file delete -force $temp

		set cm   0       ; # uncompressed
		set gpbf 0       ; # No flags
		set csize $size
	    }
	}

	# Write the local file header

	set fnlen  [string bytelength $dst]
	set offset [tell $ch] ; # location local header, needed for central header

	tag      $ch 4 3
	byte     $ch 20     ; # vnte/lsb/version = 2.0 (deflate needed)
	byte     $ch 3      ; # vnte/msb/host    = UNIX (file attributes = mode).
	short-le $ch $gpbf  ; # gpbf /deflate info
	short-le $ch $cm    ; # cm
	short-le $ch [Time $ctime] ; # lmft
	short-le $ch [Date $ctime] ; # lmfd
	long-le  $ch $crc   ; # crc32 of uncompressed file
	long-le  $ch $csize ; # compressed file size
	long-le  $ch $size  ; # uncompressed file size
	short-le $ch $fnlen ; # file name length
	short-le $ch 0      ; # extra field length, none
	str      $ch $dst   ; # file name
	# No extra field.

	if {$csize > 0} {
	    # Copy file data over. Maybe a compressed temp. file.

	    set    in [setbinary [open $src r]]
	    fcopy $in $ch
	    close $in
	}

	# Write a data descriptor repeating crc & size info, if
	# necessary.

	if {$crc == 0} {
	    tag     $ch 8 7
	    long-le $ch $crc   ; # crc32
	    long-le $ch $csize ; # compressed file size
	    long-le $ch $size  ; # uncompressed file size
	}

	# Done ... We are left with admin work ...
	#
	# Throwing away a source file we own, and recording much of
	# the data computed here for a file, for use when writing the
	# central file header.

	if {$owned} {
	    file delete -force $src
	}

	lappend files($dst) $cm $gpbf $csize $offset $crc
	return
    }

    method writeCentralFileHeader {ch dst} {
	foreach {owned src size ctime attr noCompress cm gpbf csize offset crc} $files($dst) break

	set fnlen [string bytelength $dst]

	tag      $ch 2 1
	byte     $ch 20      ; # vmb/lsb/version  = 2.0
	byte     $ch 3       ; # vmb/msb/host     = UNIX (file attributes = mode).
	byte     $ch 20      ; # vnte/lsb/version = 2.0
	byte     $ch 3       ; # vnte/msb/host    = UNIX (file attributes = mode).
	short-le $ch $gpbf   ; # gpbf /deflate info
	short-le $ch $cm     ; # cm
	short-le $ch [Time $ctime] ; # lmft
	short-le $ch [Date $ctime] ; # lmfd
	long-le  $ch $crc    ; # crc32 checksum of uncompressed file.
	long-le  $ch $csize  ; # compressed file size
	long-le  $ch $size   ; # uncompressed file size
	short-le $ch $fnlen  ; # file name length
	short-le $ch 0       ; # extra field length, none
	short-le $ch 0       ; # file comment length, none
	short-le $ch 0       ; # disk number start
	short-le $ch 0       ; # int. file attr., claim all as binary

	long-le  $ch [encode_permissions $attr] ; # ext. file attr: unix permissions.

	long-le  $ch $offset ; # relative offset of local file header
	str      $ch $dst    ; # file name
	# no extra field

	return
    }

    method writeEndOfCentralDir {ch cfhoffset cfhsize} {

	set clen   [string bytelength $comment]
	set nfiles [array size files]

	tag      $ch 6 5
	short-le $ch 0          ; # number of this disk
	short-le $ch 0          ; # number of disk with central directory
	short-le $ch $nfiles    ; # number of files in archive
	short-le $ch $nfiles    ; # number of files in archive
	long-le  $ch $cfhsize   ; # size central directory
	long-le  $ch $cfhoffset ; # offset central dir
	short-le $ch $clen      ; # archive comment length
	if {$clen} {
	    str  $ch $comment
	}
	return
    }

    proc tag {ch x y} {
	byte $ch 80 ; # 'P'
	byte $ch 75 ; # 'K'
	byte $ch $y ; # \ swapped! intentional!
	byte $ch $x ; # / little-endian number.
	return
    }

    proc byte {ch x} {
	puts -nonewline $ch [binary format c $x]
    }

    proc short-le {ch x} {
	puts -nonewline $ch [binary format s $x]
    }

    proc long-le {ch x} {
	puts -nonewline $ch [binary format i $x]
    }

    proc str {ch text} {
	fconfigure $ch -encoding utf-8
	# write the string as utf-8 to keep its bytes, exactly.
	puts -nonewline $ch $text
	fconfigure $ch -encoding binary
	return
    }

    proc setbinary {ch} {
	fconfigure $ch \
	    -encoding    binary \
	    -translation binary \
	    -eofchar     {}
	return $ch
    }

    # time = fedcba9876543210
    #        HHHHHmmmmmmSSSSS (sec/2 actually)

    proc Time {ctime} {
	foreach {h m s} [clock format $ctime -format {%H %M %S}] break
	# Remove leading zeros, i.e. prevent octal interpretation.
	deoctal h
	deoctal m
	deoctal s
	return [expr {(($h & 0x1f) << 11)|
		      (($m & 0x3f) << 5)|
		      (($s/2) & 0x1f)}]
    }

    # data = fedcba9876543210
    #        yyyyyyyMMMMddddd

    proc Date {ctime} {
	foreach {y m d} [clock format $ctime -format {%Y %m %d}] break
	deoctal y
	deoctal m
	deoctal d
	incr y -1980
	return [expr {(($y & 0xff) << 9)|
		      (($m & 0xf) << 5)|
		      ($d & 0x1f)}]
    }

    proc deoctal {nv} {
	upvar 1 $nv n
	set n [string trimleft $n 0]
	if {$n eq ""} {set n 0}
	return
    }

    proc encode_permissions {attr} {
	return [expr {$attr << 16}]
    }


    typemethod zipdir {path dst} {
	set z [$type create %AUTO%]

	set path [file dirname [file normalize [file join $path ___]]]

	foreach f [fileutil::find $path] {
	    set fx [fileutil::stripPath $path $f]
	    $z file: $fx 0 $f
	}

	file mkdir [file dirname $dst]
	$z write $dst
	$z destroy
	return
    }
}

# ### ### ### ######### ######### #########
## Ready
package provide zipfile::encode 0.4
return
