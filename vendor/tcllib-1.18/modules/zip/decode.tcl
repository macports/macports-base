# -*- tcl -*-
# ### ### ### ######### ######### #########
## Copyright (c) 2008-2012 ActiveState Software Inc.
##                         Andreas Kupries
## BSD License
##
# Package providing commands for the decoding of basic zip-file
# structures.

package require Tcl 8.4
package require fileutil::magic::mimetype ; # Tcllib. File type determination via magic constants
package require fileutil::decode 0.2      ; # Framework for easy decoding of files.
namespace eval ::zipfile::decode {}
if {[package vcompare $tcl_patchLevel "8.6"] < 0} {
  # Only needed pre-8.6
  package require Trf                       ; # Wrapper to zlib
  package require zlibtcl                   ; # Zlib usage. No commands, access through Trf
  set ::zipfile::decode::native_zip_functs 0
} else {
  set ::zipfile::decode::native_zip_functs 1
}
namespace eval ::zipfile::decode {
    namespace import ::fileutil::decode::*
}

# ### ### ### ######### ######### #########
## Convenience command, decode and copy to dir

proc ::zipfile::decode::unzipfile {in out} {
    zipfile::decode::open  $in
    set                     zd [zipfile::decode::archive]
    zipfile::decode::unzip $zd $out
    zipfile::decode::close
    return
}

## Convenience command, decode and return list of contained paths.
proc ::zipfile::decode::content {in} {
    zipfile::decode::open $in
    set zd [zipfile::decode::archive]
    set f [files $zd]
    zipfile::decode::close
    return $f
}

# ### ### ### ######### ######### #########
##

proc ::zipfile::decode::iszip {fname} {
    if {[catch {
	LocateEnd $fname
    } msg]} {
	return 0
    }
    return 1
}

proc ::zipfile::decode::open {fname} {
    variable eoa
    if {[catch {
	set eoa [LocateEnd $fname]
    } msg]} {
	return -code error -errorcode {ZIP DECODE BAD ARCHIVE} \
	    "\"$fname\" is not a zip file"
    }
    fileutil::decode::open $fname
    return
}

proc ::zipfile::decode::close {} {
    variable eoa
    unset eoa
    fileutil::decode::close
    return
}

# ### ### ### ######### ######### #########
##

proc ::zipfile::decode::comment {zdict} {
    array set _ $zdict
    return $_(comment)
}

proc ::zipfile::decode::files {zdict} {
    array set _ $zdict
    array set f $_(files)
    return [array names f]
}

proc ::zipfile::decode::hasfile {zdict fname} {
    array set _ $zdict
    array set f $_(files)
    return [info exists f($fname)]
}

proc ::zipfile::decode::copyfile {zdict src dst} {
    array set _ $zdict
    array set f $_(files)

    if {![info exists f($src)]} {
	return -code error -errorcode {ZIP DECODE BAD PATH} \
	    "File \"$src\" not known"
    }

    array set     fd $f($src)
    CopyFile $src fd $dst
    return
}

proc ::zipfile::decode::getfile {zdict src} {
    array set _ $zdict
    array set f $_(files)

    if {![info exists f($src)]} {
	return -code error -errorcode {ZIP DECODE BAD PATH} \
	    "File \"$src\" not known"
    }

    array set fd $f($src)
    return [GetFile $src fd]
}

proc ::zipfile::decode::unzip {zdict dst} {
    array set _ $zdict
    array set f $_(files)

    foreach src [array names f] {
	array set     fd $f($src)
	CopyFile $src fd [file join $dst $src]

	unset fd
    }
    return
}

proc ::zipfile::decode::CopyFile {src fdv dst} {
    upvar 1 $fdv fd

    file mkdir [file dirname $dst]

    if {[string match */ $src]} {
	# Entry is a directory. Just create.
	file mkdir $dst
	return
    }

    # Create files. Empty files are a special case, we have
    # nothing to decompress.

    if {$fd(ucsize) == 0} {
	::close [::open $dst w] ; # touch
	return
    }

    # non-empty files, work depends on type of compression.

    switch -exact -- $fd(cm) {
	uncompressed {
	    go     $fd(fileloc)
	    nbytes $fd(csize)

	    set out [::open $dst w]
	    fconfigure $out -translation binary -encoding binary -eofchar {}
	    puts -nonewline $out [getval]
	    ::close $out
	}
	deflate {
	    go     $fd(fileloc)
	    nbytes $fd(csize)

	    set out [::open $dst w]
	    fconfigure $out -translation binary -encoding binary -eofchar {}
            if {$::zipfile::decode::native_zip_functs} {
              puts -nonewline $out \
		[zlib inflate [getval]]              
            } else {
              puts -nonewline $out \
		[zip -mode decompress -nowrap 1 -- \
		     [getval]]
            }
	    ::close $out
	}
	default {
	    return -code error -errorcode {ZIP DECODE BAD COMPRESSION} \
		"Unable to handle file \"$src\" compressed with method \"$fd(cm)\""
	}
    }

    if {
	($::tcl_platform(platform) ne "windows") &&
	($fd(efattr) != 0)
    } {
	# On unix take the permissions encoded in the external
	# attributes and apply them to the new file. If there are
	# permission. A value of 0 indicates an older teabag where
	# the encoder did not yet support permissions. These we do not
	# change from the sustem defaults. Permissions are in the
	# lower 9 bits of the MSW.

	file attributes $dst -permissions \
	    [string map {0 --- 1 --x 2 -w- 3 -wx 4 r-- 5 r-x 6 rw- 7 rwx} \
		 [format %03o [expr {($fd(efattr) >> 16) & 0x1ff}]]]
    }

    # FUTURE: Run crc checksum on created file and compare to the
    # ......: stored information.

    return
}

proc ::zipfile::decode::GetFile {src fdv} {
    upvar 1 $fdv fd

    # Entry is a directory.
    if {[string match */ $src]} {return {}}

    # Empty files are a special case, we have
    # nothing to decompress.

    if {$fd(ucsize) == 0} {return {}}

    # non-empty files, work depends on type of compression.

    switch -exact -- $fd(cm) {
	uncompressed {
	    go     $fd(fileloc)
	    nbytes $fd(csize)
	    return [getval]
	}
	deflate {
	    go     $fd(fileloc)
	    nbytes $fd(csize)
	    return [zip -mode decompress -nowrap 1 -- [getval]]
	}
	default {
	    return -code error -errorcode {ZIP DECODE BAD COMPRESSION} \
		"Unable to handle file \"$src\" compressed with method \"$fd(cm)\""
	}
    }

    # FUTURE: Run crc checksum on created file and compare to the
    # ......: stored information.

    return {}
}

# ### ### ### ######### ######### #########
##

proc ::zipfile::decode::tag {etag} {
    mark
    long-le
    return [match 0x${etag}4b50] ; # 'PK x y', little-endian integer.
}

proc ::zipfile::decode::localfileheader {} {
    clear
    putloc @
    if {![tag 0403]} {clear ; return 0}

    short-le ; unsigned ; recode VER ; put vnte      ; # version needed to extract				       
    short-le ; unsigned ;              put gpbf      ; # general purpose bitflag				       
    short-le ; unsigned ; recode CM  ; put cm        ; # compression method					       
    short-le ; unsigned ;              put lmft      ; # last mod file time					       
    short-le ; unsigned ;              put lmfd      ; # last mod file date					       
    long-le  ; unsigned ;              put crc       ; # crc32                  | zero's here imply non-seekable,     
    long-le  ; unsigned ;              put csize     ; # compressed file size   | data is in a DDS behind the stored  
    long-le  ; unsigned ;              put ucsize    ; # uncompressed file size | file.			       
    short-le ; unsigned ;              put fnamelen  ; # file name length					       
    short-le ; unsigned ;              put efieldlen ; # extra field length                      

    array set hdr [get]
    clear

    nbytes $hdr(fnamelen) ; put fname
    putloc                      efieldloc
    skip $hdr(efieldlen)
    putloc                      fileloc

    array set hdr [get]
    clear

    set hdr(gpbf) [GPBF $hdr(gpbf) $hdr(cm)]
    setbuf [array get hdr]
    return 1
}

proc ::zipfile::decode::centralfileheader {} {
    clear
    putloc @
    if {![tag 0201]} {clear ; return 0}

    # The items marked with ++ do not exist in the local file
    # header. Everything else exists in the local file header as well,
    # and has to match that information.

    clear
    short-le ; unsigned ; recode VER ; put vmb         ; # ++ version made by
    short-le ; unsigned ; recode VER ; put vnte        ; #    version needed to extract				       
    short-le ; unsigned ;              put gpbf        ; #    general purpose bitflag				       
    short-le ; unsigned ; recode CM  ; put cm          ; #    compression method					       
    short-le ; unsigned ;              put lmft        ; #    last mod file time					       
    short-le ; unsigned ;              put lmfd        ; #    last mod file date					       
    long-le  ; unsigned ;              put crc         ; #    crc32                  | zero's here imply non-seekable,     
    long-le  ; unsigned ;              put csize       ; #    compressed file size   | data is in a DDS behind the stored  
    long-le  ; unsigned ;              put ucsize      ; #    uncompressed file size | file.			       
    short-le ; unsigned ;              put fnamelen    ; #    file name length					       
    short-le ; unsigned ;              put efieldlen2  ; #    extra field length                      
    short-le ; unsigned ;              put fcommentlen ; # ++ file comment length		  
    short-le ; unsigned ;              put dns         ; # ++ disk number start		     
    short-le ; unsigned ; recode IFA ; put ifattr      ; # ++ internal file attributes	     
    long-le  ; unsigned ;              put efattr      ; # ++ external file attributes	  
    long-le  ; unsigned ;              put localloc    ; # ++ relative offset of local file header

    array set hdr [get]
    clear

    nbytes $hdr(fnamelen)    ; put fname
    putloc                         efieldloc2
    skip $hdr(efieldlen2)
    nbytes $hdr(fcommentlen) ; put comment

    array set hdr [get]
    clear

    set hdr(gpbf) [GPBF $hdr(gpbf) $hdr(cm)]
    setbuf [array get hdr]
    return 1
}

## NOT USED
proc ::zipfile::decode::datadescriptor {} {
    if {![tag 0807]} {return 0}

    clear
    long-le  ; unsigned ; put crc    ; # crc32                 
    long-le  ; unsigned ; put csize  ; # compressed file size  
    long-le  ; unsigned ; put ucsize ; # uncompressed file size   

    return 1
}

proc ::zipfile::decode::endcentralfiledir {} {
    clear
    putloc ecdloc
    if {![tag 0605]} {clear ; return 0}

    short-le ; unsigned ; put nd         ; #
    short-le ; unsigned ; put ndscd      ; #
    short-le ; unsigned ; put tnecdd     ; #
    short-le ; unsigned ; put tnecd      ; #
    long-le  ; unsigned ; put sizecd     ; #
    long-le  ; unsigned ; put ocd        ; #
    short-le ; unsigned ; put commentlen ; # archive comment length

    array set hdr [get] ; clear

    nbytes $hdr(commentlen) ; put comment

    array set hdr [get] ; clear

    setbuf [array get hdr]
    return 1
}

## NOT USED
proc ::zipfile::decode::afile {} {
    if {![localfileheader]} {return 0}

    array set hdr [get]
    if {($hdr(ucsize) == 0) || ($hdr(csize) > 0)} {
	# The header entry specifies either
	# 1. A zero-length file (possibly a directory entry), or
	# 2. a non-empty file (compressed size > 0).
	# In both cases we can skip the file contents directly.
	# In both cases there should be no data descriptor behind
	# we contents, but we check nevertheless. If there is its
	# data overrides the current size and crc info.

	skip $hdr(csize)

	if {[datadescriptor]} {
	    array set hdr [get]
	    set hdr(ddpresent) 1
	    setbuf [array get hdr]
	}
    } else {
	return -code error -errorcode {ZIP DECODE INCOMPLETE} \
	    "Search data descriptor. Not Yet Implementyed"
    }
    return 1
}

proc ::zipfile::decode::archive {} {
    variable eoa
    array set cb $eoa

    # Position us at the beginning of CFH, using the data provided to
    # us by 'LocateEnd', called during 'open'.

    go [expr {$cb(base) + $cb(coff)}]

    array set fn {}

    set nentries 0
    while {[centralfileheader]} {
	array set _ [set data [get]] ; clear

	#parray _

	# Use the information found in the CFH entry to locate and
	# read the associated LFH. We explicitly remember where we are
	# in the file because mark/rewind is only one level and the
	# LFH command already used that up.

	set here [at]
	go [expr {$cb(base) + $_(localloc)}]
	if {![localfileheader]} {
	    return -code error -errorcode {ZIP DECODE BAD ARCHIVE} \
		"Bad zip file. Directory entry without file."
	}

	array set lh [get] ; clear
	go $here

	# Compare the information in the CFH entry and associated
	# LFH. Should match.

	if {![hdrmatch lh _]} {
	    return -code error -errorcode {ZIP DECODE BAD ARCHIVE} \
		"Bad zip file. File/Dir Header mismatch."
	}

	# Merge local and central data.
	array set lh $data

	set fn($_(fname)) [array get lh]
	unset lh _
	incr nentries
    }

    if {![endcentralfiledir]} {
	return -code error "Bad zip file. Bad closure."
    }

    array set _ [get] ; clear

    #parray _
    #puts \#$nentries

    if {$nentries != $_(tnecd)} {
	return -code error "Bad zip file. \#Files does match \#Actual files"
    }

    set _(files) [array get fn]
    return [array get _]
}

proc ::zipfile::decode::hdrmatch {lhv chv} {
    upvar 1 $lhv lh $chv ch

    #puts ______________________________________________
    #parray lh
    #parray ch

    foreach key {
	vnte gpbf cm lmft lmfd fnamelen fname
    } {
	if {$lh($key) != $ch($key)} {return 0}
    }

    if {[lsearch -exact $lh(gpbf) dd] < 0} {
	# Compare the central and local size information only if the
	# latter is not provided by a DDS. Which we haven't read.
	# Because in that case the LFH information is uniformly 0, not
	# known at the time of writing.

	foreach key {
	    crc csize ucsize
	} {
	    if {$lh($key) != $ch($key)} {return 0}
	}
    }

    return 1
}


# ### ### ### ######### ######### #########
##

proc ::zipfile::decode::IFA {v} {
    if {$v & 0x1} {
	return text
    } else {
	return binary
    }
}

# ### ### ### ######### ######### #########
##

namespace eval ::zipfile::decode {
    variable  vhost
    array set vhost {
	0  FAT		1  Amiga
	2  VMS		3  Unix
	4  VM/CMS	5  Atari
	6  HPFS		7  Macintosh
	8  Z-System	9  CP/M
	10 TOPS-20	11 NTFS
	12 SMS/QDOS	13 {Acorn RISC OS}
	14 VFAT		15 MVS
	16 BeOS		17 Tandem
    }
}

proc ::zipfile::decode::VER {v} {
    variable vhost
    set u [expr {($v & 0xff00) >> 16}]
    set l [expr {($v & 0x00ff)}]

    set major [expr {$l / 10}]
    set minor [expr {$l % 10}]

    return [list $vhost($u) ${major}.$minor]
}

# ### ### ### ######### ######### #########
##

namespace eval ::zipfile::decode {
    variable  cm
    array set cm {
	0  uncompressed	1  shrink
	2  {reduce 1}	3  {reduce 2}
	4  {reduce 3}	5  {reduce 4}
	6  implode	7  reserved
	8  deflate	9  reserved
	10 implode-pkware-dcl
    }
}

proc ::zipfile::decode::CM {v} {
    variable cm
    return $cm($v)
}

# ### ### ### ######### ######### #########
##

namespace eval ::zipfile::decode {
    variable  gbits
    array set gbits {
	0,1         encrypted
	1,0,implode 4k-window
	1,1,implode 8k-window
	2,0,implode 2fano
	2,1,implode 3fano
	3,1         dd
	5,1         patched
 
	deflate,0 normal
	deflate,1 maximum
	deflate,2 fast
	deflate,3 superfast
   }
}

proc ::zipfile::decode::GPBF {v cm} {
    variable gbits
    set res {}

    if {$cm eq "deflate"} {
	# bit 1, 2 are treated together for deflate

	lappend res $gbits($cm,[expr {($v >> 1) & 0x3}])
    }

    set bit 0
    while {$v > 0} {
	set odd [expr {$v % 2 == 1}]
	if {[info exists gbits($bit,$odd,$cm)]} {
	    lappend res $gbits($bit,$odd,$cm)
	} elseif {[info exists gbits($bit,$odd)]} {
	    lappend res $gbits($bit,$odd)
	}
	set v [expr {$v >> 1}]
	incr bit
    }

    return $res
}

# ### ### ### ######### ######### #########

## Decode the zip file by locating its end (of the central file
## header). The higher levels will then use the information
## inside to locate and read the CFH. No scanning from the beginning
## This piece of code lifted from tclvs/library/zipvfs (v 1.0.3).

proc ::zipfile::decode::LocateEnd {path} {
    set fd [::open $path r]
    fconfigure $fd -translation binary ;#-buffering none

    array set cb {}

    # [SF Tclvfs Bug 1003574]. Do not seek over beginning of file.
    seek $fd 0 end

    # Just looking in the last 512 bytes may be enough to handle zip
    # archives without comments, however for archives which have
    # comments the chunk may start at an arbitrary distance from the
    # end of the file. So if we do not find the header immediately we
    # have to extend the range of our search, possibly until we have a
    # large part of the archive in memory. We can fail only after the
    # whole file has been searched.

    set sz  [tell $fd]
    set len 512
    set at  512
    while {1} {
	if {$sz < $at} {set n -$sz} else {set n -$at}

	seek $fd $n end
	set hdr [read $fd $len]

	# We are using 'string last' as we are searching the first
	# from the end, which is the last from the beginning. See [SF
	# Bug 2256740]. A zip archive stored in a zip archive can
	# confuse the unmodified code, triggering on the magic
	# sequence for the inner, uncompressed archive.

	set pos [string last "PK\05\06" $hdr]
	if {$pos == -1} {
	    if {$at >= $sz} {
		return -code error "no header found"
	    }

	    # after the 1st iteration we force an overlap with last
	    # buffer to ensure that the pattern we look for is not
	    # split at a buffer boundary, nor the header itself

	    set len 540
	    incr at 512
	} else {
	    break
	}
    }

    set hdrlen [string length $hdr]
    set hdr    [string range $hdr [expr {$pos + 4}] [expr {$pos + 21}]]
    set pos    [expr {wide([tell $fd]) + $pos - $hdrlen}]
 
    if {$pos < 0} {
	set pos 0
    }

    binary scan $hdr ssssiis _ _ _ _ cb(csize) cb(coff) _

    # Compute base for situations where ZIP file has been appended to
    # another media (e.g. EXE). We can do this because
    # (a) The expected location is stored in ECFH.   (-> cb(coff))
    # (b) We know the actual location of EFCH.       (-> pos)
    # (c) We know the size of CFH                    (-> cb(csize))
    # (d) The CFH comes directly before the EFCH.
    # (e) Items b...d provide us with the actual location of CFH, as (b)-(c).
    # Thus the difference between (e) and (d) is the base in question.

    set base [expr { $pos - $cb(csize) - $cb(coff) }]
    if {$base < 0} {
        set base 0
    }
    set cb(base) $base

    if {$cb(coff) < 0} {
	set cb(base) [expr {wide($cb(base)) - 4294967296}]
	set cb(coff) [expr {wide($cb(coff)) + 4294967296}]
    }

    #--------------
    ::close $fd
    return [array get cb]
}

# ### ### ### ######### ######### #########
## Ready
package provide zipfile::decode 0.7
return
