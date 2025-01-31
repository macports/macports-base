# tar.tcl --
#
#       Creating, extracting, and listing posix tar archives
#
# Copyright (c) 2004    Aaron Faupell <afaupell@users.sourceforge.net>
# Copyright (c) 2013    Andreas Kupries <andreas_kupries@users.sourceforge.net>
#                       (GNU tar @LongLink support).
# Copyright (c) 2024    Christian Werner <chw@ch-werner.de>
#                       (zlib support).
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.5 9
package provide tar 0.13

# # ## ### ##### ######## ############# #####################
##
# Gzip support
#
# |Id  |Question            |Check                |Notes|
# |---:|:---                |:---                 |:---|
# |1   |system supports gzip|`info command ::zlib`|check on package load|
# |2   |user requests gzip  |`-gzip`              |check per command    |
# |3   |file is gzipped     |file inspection      |check per command    |
#
# All questions are boolean, resulting in 8 different combinations:
#
# Tar reading
#
# |Id  |Sys |Usr |File|Good?|Notes|
# |---:|---:|---:|---:|:---|:---|
# |R1  |0   |0   |0   |OK  | read regular |
# |R2  |0   |0   |1   |FAIL| unsupported input |
# |R3  |0   |1   |0   |FAIL| unsupported user request, sys |
# |R4  |0   |1   |1   |FAIL| unsupported user request, sys |
# |    |    |    |    |    ||
# |R5  |1   |0   |0   |OK  | read regular |
# |R6  |1   |0   |1   |OK  | auto-adapt, read gzip |
# |R7  |1   |1   |0   |FAIL| unsupported user request, file |
# |R8  |1   |1   |1   |OK  | read gzip |
#
# Tar creation
#
# |Id  |Sys |Usr |Good?|Notes|
# |---:|---:|---:|:---|:---|
# |C1  |0   |0   |OK  | write regular |
# |C2  |0   |1   |FAIL| unsupported user request, sys |
# |    |    |    |    ||
# |C3  |1   |0   |OK  | write regular |
# |C4  |1   |1   |OK  | write gzip |

# # ## ### ##### ######## ############# #####################

namespace eval ::tar {
    # (1)
    variable hasgzip [llength [info command ::zlib]]
    # (2) IsGzFile, see internal helpers at the end
}

# # ## ### ##### ######## ############# #####################

proc ::tar::parseOpts {acc opts} {
    array set flags $acc
    foreach {x y} $acc {upvar $x $x}

    set len [llength $opts]
    set i 0
    while {$i < $len} {
        set name [string trimleft [lindex $opts $i] -]
        if {![info exists flags($name)]} {
	    Err "unknown option \"$name\"" INVALID OPTION
	}
        if {$flags($name) == 1} {
            set $name [lindex $opts [expr {$i + 1}]]
            incr i $flags($name)
        } elseif {$flags($name) > 1} {
            set $name [lrange $opts [expr {$i + 1}] [expr {$i + $flags($name)}]]
            incr i $flags($name)
        } else {
            set $name 1
        }
        incr i
    }
}

proc ::tar::pad {size} {
    set pad [expr {512 - ($size % 512)}]
    if {$pad == 512} {return 0}
    return $pad
}

proc ::tar::seekorskip {ch off wh} {
    if {[tell $ch] < 0} {
	if {$wh ne "current"} {
	    Err "WHENCE=$wh not supported on non-seekable channel $ch" INVALID WHENCE $wh
	}
	skip $ch $off
	return
    }
    seek $ch $off $wh
    return
}

proc ::tar::skip {ch skipover} {
    while {$skipover > 0} {
        set requested $skipover

        # Limit individual skips to 64K, as a compromise between speed
        # of skipping (Number of read requests), and memory usage
        # (Note how skipped block is read into memory!). While the
        # read data is immediately discarded it still generates memory
        # allocation traffic, gets copied, etc. Trying to skip the
        # block in one go without the limit may cause us to run out of
        # (virtual) memory, or just induce swapping, for nothing.

        if {$requested > 65536} {
            set requested 65536
        }

        set skipped [string length [read $ch $requested]]

        # Stop in short read into the end of the file.
        if {!$skipped && [eof $ch]} break

        # Keep track of how much is (not) skipped yet.
        incr skipover -$skipped
    }
    return
}

proc ::tar::readHeader {data} {
    binary scan $data a100a8a8a8a12a12a8a1a100a6a2a32a32a8a8a155 \
	name mode uid gid size mtime cksum type \
	linkname magic version uname gname devmajor devminor prefix

    foreach x {name type linkname} {
        set $x [string trim [set $x] "\x00"]
    }
    foreach x {uid gid size mtime cksum} {
        set $x [format %d 0[string trim [set $x] " \x00"]]
    }
    set mode [string trim $mode " \x00"]

    if {$magic eq "ustar "} {
        # gnu tar
        # not fully supported
        foreach x {uname gname prefix} {
            set $x [string trim [set $x] "\x00"]
        }
        foreach x {devmajor devminor} {
            set $x [format %d 0[string trim [set $x] " \x00"]]
        }
    } elseif {$magic eq "ustar\x00"} {
        # posix tar
        foreach x {uname gname prefix} {
            set $x [string trim [set $x] "\x00"]
        }
        foreach x {devmajor devminor} {
            set $x [format %d 0[string trim [set $x] " \x00"]]
        }
    } else {
        # old style tar
        foreach x {uname gname devmajor devminor prefix} { set $x {} }
        if {$type eq ""} {
            if {[string match */ $name]} {
                set type 5
            } else {
                set type 0
            }
        }
    }

    return [list name $name mode $mode uid $uid gid $gid size $size \
		mtime $mtime cksum $cksum type $type linkname $linkname \
		magic $magic version $version uname $uname gname $gname \
		devmajor $devmajor devminor $devminor prefix $prefix]
}

proc ::tar::contents {file args} {
    set chan 0
    set gzip 0
    parseOpts {chan 0 gzip 0} $args
    lassign [SetupReading $chan $gzip $file] fh pos gzip    
    set ret {}
    while {![eof $fh]} {
        array set header [readHeader [read $fh 512]]
	HandleLongLink $fh header
        if {$header(name)   eq ""} break
	if {$header(prefix) ne ""} {append header(prefix) /}
        lappend ret $header(prefix)$header(name)
        seekorskip $fh [expr {$header(size) + [pad $header(size)]}] current
    }
    Close $fh $pos $chan $gzip
    return $ret
}

proc ::tar::stat {tar {file {}} args} {
    set chan 0
    set gzip 0
    parseOpts {chan 0 gzip 0} $args
    lassign [SetupReading $chan $gzip $tar] fh pos gzip
    set ret {}
    while {![eof $fh]} {
        array set header [readHeader [read $fh 512]]
	HandleLongLink $fh header
        if {$header(name)   eq ""} break
	if {$header(prefix) ne ""} {append header(prefix) /}
        seekorskip $fh [expr {$header(size) + [pad $header(size)]}] current
        if {$file ne "" && "$header(prefix)$header(name)" ne $file} {continue}
        set header(type) [string map {
	    0 file 5 directory 3 characterSpecial 4 blockSpecial
	    6 fifo 2 link
	} $header(type)]
        set header(mode) [string range $header(mode) 2 end]
        lappend ret $header(prefix)$header(name) \
	    [list mode $header(mode) uid $header(uid) gid $header(gid) \
		 size $header(size) mtime $header(mtime) type $header(type) \
		 linkname $header(linkname) uname $header(uname) \
		 gname $header(gname) devmajor $header(devmajor) \
		 devminor $header(devminor)]
    }
    Close $fh $pos $chan $gzip
    return $ret
}

proc ::tar::get {tar file args} {
    set chan 0
    set gzip 0
    parseOpts {chan 0 gzip 0} $args
    lassign [SetupReading $chan $gzip $tar] fh pos gzip
    while {![eof $fh]} {
	set data [read $fh 512]
        array set header [readHeader $data]
	HandleLongLink $fh header
        if {$header(name)   eq ""} break
	if {$header(prefix) ne ""} {append header(prefix) /}
        set name [string trimleft $header(prefix)$header(name) /]
        if {$name eq $file} {
            set file [read $fh $header(size)]
	    Close $fh $pos $chan $gzip
            return $file
        }
        seekorskip $fh [expr {$header(size) + [pad $header(size)]}] current
    }
    Close $fh $pos $chan $gzip
    Err "Tar \"$tar\": File \"$file\" not found" MISSING FILE
}

proc ::tar::untar {tar args} {
    set nooverwrite 0
    set data 0
    set nomtime 0
    set noperms 0
    set chan 0
    set gzip 0
    parseOpts {
	dir 1 file 1 glob 1 nooverwrite 0 nomtime 0 noperms 0 chan 0 gzip 0
    } $args
    if {![info exists dir]} {set dir [pwd]}
    set pattern *
    if {[info exists file]} {
        set pattern [string map {* \\* ? \\? \\ \\\\ \[ \\\[ \] \\\]} $file]
    } elseif {[info exists glob]} {
        set pattern $glob
    }

    set ret {}
    lassign [SetupReading $chan $gzip $tar] fh pos gzip
    while {![eof $fh]} {
        array set header [readHeader [read $fh 512]]
	HandleLongLink $fh header
        if {$header(name)   eq ""} break
	if {$header(prefix) ne ""} {append header(prefix) /}
        set name [string trimleft $header(prefix)$header(name) /]
        if {![string match $pattern $name] || ($nooverwrite && [file exists $name])} {
            seekorskip $fh [expr {$header(size) + [pad $header(size)]}] current
            continue
        }

        set name [file join $dir $name]
        if {![file isdirectory [file dirname $name]]} {
            file mkdir [file dirname $name]
            lappend ret [file dirname $name] {}
        }
        if {[string match {[0346]} $header(type)]} {
            if {[catch {::open $name wb+} new]} {
                # sometimes if we dont have write permission we can still delete
                catch {file delete -force $name}
                set new [::open $name wb+]
            }
            fcopy $fh $new -size $header(size)
            close $new
            lappend ret $name $header(size)
        } elseif {$header(type) == 5} {
            file mkdir $name
            lappend ret $name {}
        } elseif {[string match {[12]} $header(type)] &&
		  $::tcl_platform(platform) eq "unix"} {
            catch {file delete $name}
            if {![catch {
		file link [string map {1 -hard 2 -symbolic} $header(type)] \
		    $name $header(linkname)
	    }]} {
                lappend ret $name {}
            }
        }
        seekorskip $fh [pad $header(size)] current
        if {![file exists $name]} continue

        if {$::tcl_platform(platform) eq "unix"} {
            if {!$noperms} {
                catch {
		    file attributes $name -permissions 0o[string range $header(mode) 2 end]
		}
            }
            catch {
		file attributes $name -owner $header(uid) -group $header(gid)
	    }
            catch {
		file attributes $name -owner $header(uname) -group $header(gname)
	    }
        }
        if {!$nomtime} {
            file mtime $name $header(mtime)
        }
    }
    Close $fh $pos $chan $gzip
    return $ret
}

##
 # ::tar::statFile
 #
 # Returns stat info about a filesystem object, in the form of an info
 # dictionary like that returned by ::tar::readHeader.
 #
 # The mode, uid, gid, mtime, and type entries are always present.
 # The size and linkname entries are present if relevant for this type
 # of object. The uname and gname entries are present if the OS supports
 # them. No devmajor or devminor entry is present.
 ##

proc ::tar::statFile {name followlinks} {
    if {$followlinks} {
        file stat $name stat
    } else {
        file lstat $name stat
    }

    set ret {}

    if {$::tcl_platform(platform) eq "unix"} {
        # Tcl 9 returns the permission as 0o octal number. Since this
        # is written to the tar file and the file format expects "00"
        # we have to rewrite.
        lappend ret mode 1[string map {o 0} [file attributes $name -permissions]]
        lappend ret uname [file attributes $name -owner]
        lappend ret gname [file attributes $name -group]
        if {$stat(type) eq "link"} {
            lappend ret linkname [file link $name]
        }
    } else {
        lappend ret mode [lindex {100644 100755} [expr {$stat(type) eq "directory"}]]
    }

    lappend ret uid $stat(uid) gid $stat(gid) mtime $stat(mtime) \
	type $stat(type)

    if {$stat(type) eq "file"} {lappend ret size $stat(size)}

    return $ret
}

##
 # ::tar::formatHeader
 #
 # Opposite operation to ::tar::readHeader; takes a file name and info
 # dictionary as arguments, returns a corresponding (POSIX-tar) header.
 #
 # The following dictionary entries must be present:
 #   mode
 #   type
 #
 # The following dictionary entries are used if present, otherwise
 # the indicated default is used:
 #   uid       0
 #   gid       0
 #   size      0
 #   mtime     [clock seconds]
 #   linkname  {}
 #   uname     {}
 #   gname     {}
 #
 # All other dictionary entries, including devmajor and devminor, are
 # presently ignored.
 ##

proc ::tar::formatHeader {name info} {
    array set A {
        linkname ""
        uname ""
        gname ""
        size 0
        gid  0
        uid  0
    }
    set A(mtime) [clock seconds]
    array set A $info
    array set A {devmajor "" devminor ""}

    set type [string map {
	file 0 directory 5 characterSpecial 3
	blockSpecial 4 fifo 6 link 2 socket A
    } $A(type)]

    set osize  [format %o $A(size)]
    set ogid   [format %o $A(gid)]
    set ouid   [format %o $A(uid)]
    set omtime [format %o $A(mtime)]

    set name [string trimleft $name /]
    if {[string length $name] > 255} {
	Err "path name over 255 chars" BAD PATH LENGTH
    } elseif {[string length $name] > 100} {
	set common [string range $name end-99 154]
	if {[set splitpoint [string first / $common]] == -1} {
	    Err "path name cannot be split into prefix and name" BAD PATH UNSPLITTABLE
	}
	set prefix [string range $name 0 end-100][string range $common 0 $splitpoint-1]
	set name   [string range $common $splitpoint+1 end][string range $name 155 end]
    } else {
        set prefix ""
    }

    set header [binary format a100A8A8A8A12A12A8a1a100A6a2a32a32a8a8a155a12 \
		    $name $A(mode)\x00 $ouid\x00 $ogid\x00\
		    $osize\x00 $omtime\x00 {} $type \
		    $A(linkname) ustar\x00 00 $A(uname) $A(gname)\
		    $A(devmajor) $A(devminor) $prefix {}]

    binary scan $header c* tmp
    set cksum 0
    foreach x $tmp {incr cksum $x}

    return [string replace $header 148 155 [binary format A8 [format %o $cksum]\x00]]
}

proc ::tar::recurseDirs {files followlinks} {
    foreach x $files {
        if {[file isdirectory $x] && ([file type $x] ne "link" || $followlinks)} {
            if {[set more [glob -dir $x -nocomplain *]] ne ""} {
                eval lappend files [recurseDirs $more $followlinks]
            } else {
                lappend files $x
            }
        }
    }
    return $files
}

proc ::tar::writefile {in out followlinks name} {
     puts -nonewline $out [formatHeader $name [statFile $in $followlinks]]
     set size 0
     if {[file type $in] eq "file" || ($followlinks && [file type $in] eq "link")} {
         set in [::open $in rb]
         set size [fcopy $in $out]
         close $in
     }
     puts -nonewline $out [string repeat \x00 [pad $size]]
}

proc ::tar::create {tar files args} {
    set dereference 0
    set chan 0
    set gzip 0
    parseOpts {dereference 0 chan 0 gzip 0} $args

    lassign [SetupCreation $chan $gzip $tar] fh pos
    
    foreach x [recurseDirs $files $dereference] {
        writefile $x $fh $dereference $x
        if {$gzip} {
            chan configure $fh -flush sync
        }
    }
    puts -nonewline $fh [string repeat \x00 1024]

    Close $fh $pos $chan $gzip
    return $tar
}

proc ::tar::add {tar files args} {
    set dereference 0
    set prefix ""
    set quick 0
    parseOpts {dereference 0 prefix 1 quick 0} $args
    set fh [SetupWriting $tar {add to}]
    if {$quick} then {
        seek $fh -1024 end
    } else {
        set data [read $fh 512]
        while {[regexp {[^\0]} $data]} {
            array set header [readHeader $data]
            seek $fh [expr {$header(size) + [pad $header(size)]}] current
            set data [read $fh 512]
        }
        seek $fh -512 current
    }

    foreach x [recurseDirs $files $dereference] {
        writefile $x $fh $dereference $prefix$x
    }
    puts -nonewline $fh [string repeat \x00 1024]

    close $fh
    return $tar
}

proc ::tar::remove {tar files} {
    set fh [SetupWriting $tar {remove from} rb]
    # mode is `rb` because removal is done as a read/copy/filter/write and
    # `fh` is the read side.
    set n 0
    while {[file exists $tar$n.tmp]} {incr n}
    set tfh [::open $tar$n.tmp wb]
    while {![eof $fh]} {
        array set header [readHeader [read $fh 512]]
        if {$header(name) eq ""} {
            puts -nonewline $tfh [string repeat \x00 1024]
            break
        }
	if {$header(prefix) ne ""} {append header(prefix) /}
        set name $header(prefix)$header(name)
        set len [expr {$header(size) + [pad $header(size)]}]
        if {[lsearch $files $name] > -1} {
            seek $fh $len current
        } else {
            seek $fh -512 current
            fcopy $fh $tfh -size [expr {$len + 512}]
        }
    }

    close $fh
    close $tfh

    file rename -force $tar$n.tmp $tar
}

# # ## ### ##### ######## ############# #####################
## internal helpers

proc ::tar::HandleLongLink {fh hv} {
    upvar 1 $hv header thelongname thelongname

    # @LongName Part I.
    if {$header(type) eq "L"} {
	# Size == Length of name. Read it, and pad to full 512
	# size.  After that is a regular header for the actual
	# file, where we have to insert the name. This is handled
	# by the next iteration and the part II below.
	set thelongname [string trimright [read $fh $header(size)] \000]
	seekorskip $fh [pad $header(size)] current
	return -code continue
    }
    # Not supported yet: type 'K' for LongLink (long symbolic links).

    # @LongName, part II, get data from previous entry, if defined.
    if {[info exists thelongname]} {
	set header(name) $thelongname
	# Prevent leakage to further entries.
	unset thelongname
    }

    return
}

proc ::tar::SetupWriting {file do {mode rb+}} {
    set fh [::open $tar $mode]
    if {[IsGzFile $fh]} {
	close $fh
	Err "cannot $do gzip compressed tar" ZLIB UNSUPPORTED WRITE
    }
    return $fh
}

proc ::tar::SetupCreation {chan gzip file} {
    variable hasgzip
    if {!$hasgzip && $gzip} {
	# C2
	Err "unsupported user request, no zlib support available" \
	    ZLIB UNSUPPORTED USER
    }

    # C1, C3, C4
    if {$chan} {
	set fh $file
        set pos [tell $fh]
    } else {
	set fh [::open $file wb+]
	set pos ""
    }

    if {$gzip} {
	# C4
        zlib push gzip $fh
	fconfigure $fh -translation binary
    }

    list $fh $pos
}
    
proc ::tar::SetupReading {chan gzip file} {
    variable hasgzip
    if {!$hasgzip && $gzip} {
	# R3, R4
	Err "unsupported user request, no zlib support available" \
	    ZLIB UNSUPPORTED USER
    }

    # inspect file or channel
    if {$chan} {
	set fh $file
	set pos [tell $fh]
    } else {
	set fh [::open $file rb]
	set pos ""
    }
    set gz [IsGzFile $fh]

    if {!$hasgzip && $gz} {
	# R2
	close $fh
	Err "unsupported input, no zlib support available" \
	    ZLIB UNSUPPORTED FILE
    }

    if {$hasgzip && $gzip && !$gz} {
	# R7
	Err "input mismatch, zlib requested, not present" \
	    ZLIB MISMATCH
    }

    if {$gz} {
	# R6, R8
	zlib push gunzip $fh
	fconfigure $fh -translation binary
    } ;# else R1, R5
    
    list $fh $pos $gz
}

proc ::tar::Close {fh pos chan gz} {
    if {!$chan} {
	close $fh
    } elseif {$gz} {
        chan pop $fh
        catch {seek $fh $pos}
    }
    return
}

proc ::tar::IsGzFile {fh} {
    set hdr [read $fh 2]
    seek $fh 0
    return [expr {$hdr eq "\x1f\x8b"}]
}

proc ::tar::Err {msg args} {
    return -code error -errorcode [list TAR {*}$args] $msg
}

# # ## ### ##### ######## ############# #####################
return
