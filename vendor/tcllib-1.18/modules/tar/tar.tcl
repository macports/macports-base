# tar.tcl --
#
#       Creating, extracting, and listing posix tar archives
#
# Copyright (c) 2004    Aaron Faupell <afaupell@users.sourceforge.net>
# Copyright (c) 2013    Andreas Kupries <andreas_kupries@users.sourceforge.net>
#                       (GNU tar @LongLink support).
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: tar.tcl,v 1.17 2012/09/11 17:22:24 andreas_kupries Exp $

package require Tcl 8.4
package provide tar 0.10

namespace eval ::tar {}

proc ::tar::parseOpts {acc opts} {
    array set flags $acc
    foreach {x y} $acc {upvar $x $x}
    
    set len [llength $opts]
    set i 0
    while {$i < $len} {
        set name [string trimleft [lindex $opts $i] -]
        if {![info exists flags($name)]} {return -code error "unknown option \"$name\""}
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
	if {$wh!="current"} {
	    error "WHENCE=$wh not supported on non-seekable channel $ch"
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

    if {$magic == "ustar "} {
        # gnu tar
        # not fully supported
        foreach x {uname gname prefix} {
            set $x [string trim [set $x] "\x00"]
        }
        foreach x {devmajor devminor} {
            set $x [format %d 0[string trim [set $x] " \x00"]]
        }
    } elseif {$magic == "ustar\x00"} {
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
        if {$type == ""} {
            if {[string match */ $name]} {
                set type 5
            } else {
                set type 0
            }
        }
    }

    return [list name $name mode $mode uid $uid gid $gid size $size mtime $mtime \
                 cksum $cksum type $type linkname $linkname magic $magic \
                 version $version uname $uname gname $gname devmajor $devmajor \
                 devminor $devminor prefix $prefix]
}

proc ::tar::contents {file args} {
    set chan 0
    parseOpts {chan 0} $args
    if {$chan} {
	set fh $file
    } else {
	set fh [::open $file]
	fconfigure $fh -encoding binary -translation lf -eofchar {}
    }
    set ret {}
    while {![eof $fh]} {
        array set header [readHeader [read $fh 512]]
	HandleLongLink $fh header
        if {$header(name) == ""} break
	if {$header(prefix) != ""} {append header(prefix) /}
        lappend ret $header(prefix)$header(name)
        seekorskip $fh [expr {$header(size) + [pad $header(size)]}] current
    }
    if {!$chan} {
	close $fh
    }
    return $ret
}

proc ::tar::stat {tar {file {}} args} {
    set chan 0
    parseOpts {chan 0} $args
    if {$chan} {
	set fh $tar
    } else {
	set fh [::open $tar]
	fconfigure $fh -encoding binary -translation lf -eofchar {}
    }
    set ret {}
    while {![eof $fh]} {
        array set header [readHeader [read $fh 512]]
	HandleLongLink $fh header
        if {$header(name) == ""} break
	if {$header(prefix) != ""} {append header(prefix) /}
        seekorskip $fh [expr {$header(size) + [pad $header(size)]}] current
        if {$file != "" && "$header(prefix)$header(name)" != $file} {continue}
        set header(type) [string map {0 file 5 directory 3 characterSpecial 4 blockSpecial 6 fifo 2 link} $header(type)]
        set header(mode) [string range $header(mode) 2 end]
        lappend ret $header(prefix)$header(name) [list mode $header(mode) uid $header(uid) gid $header(gid) \
                    size $header(size) mtime $header(mtime) type $header(type) linkname $header(linkname) \
                    uname $header(uname) gname $header(gname) devmajor $header(devmajor) devminor $header(devminor)]
    }
    if {!$chan} {
	close $fh
    }
    return $ret
}

proc ::tar::get {tar file args} {
    set chan 0
    parseOpts {chan 0} $args
    if {$chan} {
	set fh $tar
    } else {
	set fh [::open $tar]
	fconfigure $fh -encoding binary -translation lf -eofchar {}
    }
    while {![eof $fh]} {
	set data [read $fh 512]
        array set header [readHeader $data]
	HandleLongLink $fh header
        if {$header(name) == ""} break
	if {$header(prefix) != ""} {append header(prefix) /}
        set name [string trimleft $header(prefix)$header(name) /]
        if {$name == $file} {
            set file [read $fh $header(size)]
            if {!$chan} {
		close $fh
	    }
            return $file
        }
        seekorskip $fh [expr {$header(size) + [pad $header(size)]}] current
    }
    if {!$chan} {
	close $fh
    }
    return {}
}

proc ::tar::untar {tar args} {
    set nooverwrite 0
    set data 0
    set nomtime 0
    set noperms 0
    set chan 0
    parseOpts {dir 1 file 1 glob 1 nooverwrite 0 nomtime 0 noperms 0 chan 0} $args
    if {![info exists dir]} {set dir [pwd]}
    set pattern *
    if {[info exists file]} {
        set pattern [string map {* \\* ? \\? \\ \\\\ \[ \\\[ \] \\\]} $file]
    } elseif {[info exists glob]} {
        set pattern $glob
    }

    set ret {}
    if {$chan} {
	set fh $tar
    } else {
	set fh [::open $tar]
	fconfigure $fh -encoding binary -translation lf -eofchar {}
    }
    while {![eof $fh]} {
        array set header [readHeader [read $fh 512]]
	HandleLongLink $fh header
        if {$header(name) == ""} break
	if {$header(prefix) != ""} {append header(prefix) /}
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
            if {[catch {::open $name w+} new]} {
                # sometimes if we dont have write permission we can still delete
                catch {file delete -force $name}
                set new [::open $name w+]
            }
            fconfigure $new -encoding binary -translation lf -eofchar {}
            fcopy $fh $new -size $header(size)
            close $new
            lappend ret $name $header(size)
        } elseif {$header(type) == 5} {
            file mkdir $name
            lappend ret $name {}
        } elseif {[string match {[12]} $header(type)] && $::tcl_platform(platform) == "unix"} {
            catch {file delete $name}
            if {![catch {file link [string map {1 -hard 2 -symbolic} $header(type)] $name $header(linkname)}]} {
                lappend ret $name {}
            }
        }
        seekorskip $fh [pad $header(size)] current
        if {![file exists $name]} continue

        if {$::tcl_platform(platform) == "unix"} {
            if {!$noperms} {
                catch {file attributes $name -permissions 0[string range $header(mode) 2 end]}
            }
            catch {file attributes $name -owner $header(uid) -group $header(gid)}
            catch {file attributes $name -owner $header(uname) -group $header(gname)}
        }
        if {!$nomtime} {
            file mtime $name $header(mtime)
        }
    }
    if {!$chan} {
	close $fh
    }
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
    
    if {$::tcl_platform(platform) == "unix"} {
        lappend ret mode 1[file attributes $name -permissions]
        lappend ret uname [file attributes $name -owner]
        lappend ret gname [file attributes $name -group]
        if {$stat(type) == "link"} {
            lappend ret linkname [file link $name]
        }
    } else {
        lappend ret mode [lindex {100644 100755} [expr {$stat(type) == "directory"}]]
    }
    
    lappend ret  uid $stat(uid)  gid $stat(gid)  mtime $stat(mtime) \
      type $stat(type)
    
    if {$stat(type) == "file"} {lappend ret size $stat(size)}
    
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

    set type [string map {file 0 directory 5 characterSpecial 3 \
      blockSpecial 4 fifo 6 link 2 socket A} $A(type)]
    
    set osize  [format %o $A(size)]
    set ogid   [format %o $A(gid)]
    set ouid   [format %o $A(uid)]
    set omtime [format %o $A(mtime)]
    
    set name [string trimleft $name /]
    if {[string length $name] > 255} {
        return -code error "path name over 255 chars"
    } elseif {[string length $name] > 100} {
	set common [string range $name end-99 154]
	if {[set splitpoint [string first / $common]] == -1} {
	    return -code error "path name cannot be split into prefix and name"
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
        if {[file isdirectory $x] && ([file type $x] != "link" || $followlinks)} {
            if {[set more [glob -dir $x -nocomplain *]] != ""} {
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
     if {[file type $in] == "file" || ($followlinks && [file type $in] == "link")} {
         set in [::open $in]
         fconfigure $in -encoding binary -translation lf -eofchar {}
         set size [fcopy $in $out]
         close $in
     }
     puts -nonewline $out [string repeat \x00 [pad $size]]
}

proc ::tar::create {tar files args} {
    set dereference 0
    set chan 0
    parseOpts {dereference 0 chan 0} $args

    if {$chan} {
	set fh $tar
    } else {
	set fh [::open $tar w+]
	fconfigure $fh -encoding binary -translation lf -eofchar {}
    }
    foreach x [recurseDirs $files $dereference] {
        writefile $x $fh $dereference $x
    }
    puts -nonewline $fh [string repeat \x00 1024]

    if {!$chan} {
	close $fh
    }
    return $tar
}

proc ::tar::add {tar files args} {
    set dereference 0
    set prefix ""
    set quick 0
    parseOpts {dereference 0 prefix 1 quick 0} $args
    
    set fh [::open $tar r+]
    fconfigure $fh -encoding binary -translation lf -eofchar {}
    
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
    set n 0
    while {[file exists $tar$n.tmp]} {incr n}
    set tfh [::open $tar$n.tmp w]
    set fh [::open $tar r]

    fconfigure $fh  -encoding binary -translation lf -eofchar {}
    fconfigure $tfh -encoding binary -translation lf -eofchar {}

    while {![eof $fh]} {
        array set header [readHeader [read $fh 512]]
        if {$header(name) == ""} {
            puts -nonewline $tfh [string repeat \x00 1024]
            break
        }
	if {$header(prefix) != ""} {append header(prefix) /}
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

proc ::tar::HandleLongLink {fh hv} {
    upvar 1 $hv header thelongname thelongname

    # @LongName Part I.
    if {$header(type) == "L"} {
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
