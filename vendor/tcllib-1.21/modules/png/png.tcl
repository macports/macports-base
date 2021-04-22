# png.tcl --
#
#       Querying and modifying PNG image files.
#
# Copyright (c) 2004-2012 Aaron Faupell <afaupell@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: png.tcl,v 1.11 2012/07/09 16:35:04 afaupell Exp $

package provide png 0.3

namespace eval ::png {}

proc ::png::_openPNG {file {mode r}} {
    set fh [open $file $mode]
    fconfigure $fh -encoding binary -translation binary -eofchar {}
    if {[read $fh 8] != "\x89PNG\r\n\x1a\n"} { close $fh; return -code error "not a png file" }
    return $fh
}

proc ::png::_chunks {fh} {
    set out [list]
    while {[set r [read $fh 8]] != ""} {
        binary scan $r Ia4 len type
        lappend out [list $type [tell $fh] $len]
        seek $fh [expr {$len + 4}] current
    }
    return $out
}

proc ::png::isPNG {file} {
    if {[catch {_openPNG $file} fh]} { return 0 }
    close $fh
    return 1
}

proc ::png::validate {file} {
    package require crc32
    if {[catch {_openPNG $file} fh]} { return SIG }
    set num 0
    set idat 0
    set last {}

    while {[set r [read $fh 8]] != ""} {
        binary scan $r Ia4 len type
        if {$len < 0} { close $fh; return BADLEN }
        set r [read $fh $len]
        binary scan [read $fh 4] I crc
	if {$crc < 0} {set crc [format %u [expr {$crc & 0xffffffff}]]}
        if {[eof $fh]} { close $fh; return EOF }
        if {($num == 0) && ($type != "IHDR")} { close $fh; return NOHDR }
        if {$type == "IDAT"} { set idat 1 }
        if {[::crc::crc32 $type$r] != $crc} { close $fh; return CKSUM }
        set last $type
        incr num
    }
    close $fh
    if {!$idat} { return NODATA }
    if {$last != "IEND"} { return NOEND }
    return OK
}

proc ::png::imageInfo {file} {
    set fh [_openPNG $file]
    binary scan [read $fh 8] Ia4 len type
    set r [read $fh $len]
    if {![eof $fh] && $type == "IHDR"} {
        binary scan $r IIccccc width height depth color compression filter interlace
	binary scan [read $fh 4] I check
	if {$check < 0} {set check [format %u [expr {$check & 0xffffffff}]]}
	if {![catch {package present crc32}] && [::crc::crc32 IHDR$r] != $check} {
	    return -code error "header checksum failed"
	}
        close $fh
        return [list width $width height $height depth $depth color $color \
		compression $compression filter $filter interlace $interlace]
    }
    close $fh
    return
}

proc ::png::getTimestamp {file} {
    set fh [_openPNG $file]

    while {[set r [read $fh 8]] != ""} {
        binary scan $r Ia4 len type
        if {$type == "tIME"} {
            set r [read $fh [expr {$len + 4}]]
            binary scan $r Sccccc year month day hour minute second
            close $fh
            return [clock scan "$month/$day/$year $hour:$minute:$second" -gmt 1]
        }
        seek $fh [expr {$len + 4}] current
    }
    close $fh
    return
}

proc ::png::setTimestamp {file time} {
    set fh [_openPNG $file r+]
    
    set time [eval binary format Sccccc [string map {" 0" " "} [clock format $time -format "%Y %m %d %H %M %S" -gmt 1]]]
    if {![catch {package present crc32}]} {
        append time [binary format I [::crc::crc32 tIME$time]]
    } else {
        append time [binary format I 0]
    }

    while {[set r [read $fh 8]] != ""} {
        binary scan $r Ia4 len type
        if {[eof $fh]} { close $fh; return }
        if {$type == "tIME"} {
            seek $fh 0 current
            puts -nonewline $fh $time
            close $fh
            return
        }
        if {$type == "IDAT" && ![info exists idat]} { set idat [expr {[tell $fh] - 8}] }
        seek $fh [expr {$len + 4}] current
    }
    if {![info exists idat]} { close $fh; return -code error "no timestamp or data chunk found" }
    seek $fh $idat start
    set data [read $fh]
    seek $fh $idat start
    puts -nonewline $fh [binary format I 7]tIME$time$data
    close $fh
    return
}

proc ::png::getComments {file} {
    set fh [_openPNG $file]
    set text {}

    while {[set r [read $fh 8]] != ""} {
        binary scan $r Ia4 len type
        set pos [tell $fh]
        if {$type == "tEXt"} {
            set r [read $fh $len]
            lappend text [split $r \x00]
        } elseif {$type == "iTXt"} {
            set r [read $fh $len]
            set keyword [lindex [split $r \x00] 0]
            set r [string range $r [expr {[string length $keyword] + 1}] end]
            binary scan $r cc comp method
            if {$comp == 0} {
                lappend text [linsert [split [string range $r 2 end] \x00] 0 $keyword]
            }
        }
        seek $fh [expr {$pos + $len + 4}] start
    }
    close $fh
    return $text
}

proc ::png::removeComments {file} {
    set fh [_openPNG $file r+]
    set data "\x89PNG\r\n\x1a\n"
    while {[set r [read $fh 8]] != ""} {
        binary scan $r Ia4 len type
        if {$type == "zTXt" || $type == "iTXt" || $type == "tEXt"} {
            seek $fh [expr {$len + 4}] current
        } else {
            seek $fh -8 current
            append data [read $fh [expr {$len + 12}]]
        }
    }
    close $fh
    set fh [open $file w]
    fconfigure $fh -encoding binary -translation binary -eofchar {}
    puts -nonewline $fh $data
    close $fh
}

proc ::png::addComment {file keyword arg1 args} {
    if {[llength $args] > 0 && [llength $args] != 2} { close $fh; return -code error "wrong number of arguments" }
    set fh [_openPNG $file r+]

    if {[llength $args] > 0} {
        set comment "iTXt$keyword\x00\x00\x00$arg1\x00[encoding convertto utf-8 [lindex $args 0]]\x00[encoding convertto utf-8 [lindex $args 1]]"
    } else {
        set comment "tEXt$keyword\x00$arg1"
    }
    
    if {![catch {package present crc32}]} {
        append comment [binary format I [::crc::crc32 $comment]]
    } else {
        append comment [binary format I 0]
    }

    while {[set r [read $fh 8]] != ""} {
        binary scan $r Ia4 len type
        if {$type ==  "IDAT"} {
            seek $fh -8 current
            set pos [tell $fh]
            set data [read $fh]
            seek $fh $pos start
            set 1 [tell $fh]
            puts -nonewline $fh $comment
            set clen [binary format I [expr {[tell $fh] - $1 - 8}]]
            seek $fh $pos start
            puts -nonewline $fh $clen$comment$data
            close $fh
            return
        }
        seek $fh [expr {$len + 4}] current
    }
    close $fh
    return -code error "no data chunk found"
}

proc ::png::getPixelDimension {file} {
    set fh [_openPNG $file]

    while {[set r [read $fh 8]] != ""} {
        binary scan $r Ia4 len type
        if {$type == "pHYs"} {
            set r [read $fh [expr {$len + 4}]]
            binary scan $r IIc ppux ppuy unit
            close $fh
            # mask out sign bit, from tcl 8.5, one may use u specifier
            set res [list ppux [expr {$ppux & 0xFFFFFFFF}]\
                     ppuy [expr {$ppuy & 0xFFFFFFFF}]\
                    unit]
            if {$unit == 1} {lappend res meter} else {lappend res unknown}
            return $res
        }
        seek $fh [expr {$len + 4}] current
    }
    close $fh
    return
}

proc ::png::image {file} {
    set fh [_openPNG $file]
    set chunks [_chunks $fh]
    set cdata {}

    set h [lsearch -exact -index 0 -inline $chunks IHDR]
    seek $fh [lindex $h 1] start
    binary scan [read $fh [lindex $h 2]] IIccccc width height depth color compression filter interlace

    if {$color != 2 || $compression != 0 || $depth != 8} {
        return -code error "unsupported image format"
    }

    foreach c [lsearch -exact -index 0 -all -inline $chunks IDAT] {
        seek $fh [lindex $c 1] start
        append cdata [read $fh [lindex $c 2]]
    }
    set data [zlib decompress $cdata]

    set len [string length $data]
    set col 1
    set offset 1
    set row [list]
    set out [list]
    while {$offset < $len} {
        binary scan $data @${offset}H2H2H2 r g b
        lappend row "#$r$g$b"
        incr offset 3
        if {$col == $width} {
            set col 1
            incr offset
            lappend out $row
            set row [list]
            continue
        }
        incr col
    }
    return $out
}

proc ::png::write {file in} {
    set blocksize 65524
    set chunks [list]
    set data ""
    lappend chunks [list IHDR [binary format IIccccc [llength [lindex $in 0]] [llength $in] 8 2 0 0 0]]

    foreach row $in {
        append data \x00
        foreach pixel $row {
            set pixel [string trimleft $pixel "#"]
            append data [binary format H2H2H2 [string range $pixel 0 1] [string range $pixel 2 3] [string range $pixel 4 5]]
        }
    }
    set cdata [zlib compress $data]
    set offset 0
    while {$offset < ([string length $cdata] + $blocksize)} {
        lappend chunks [list IDAT [string range $cdata $offset [expr {$offset+$blocksize-1}]]]
        incr offset $blocksize
    }
    #lappend chunks [list tIME [eval binary format Sccccc [clock format [clock seconds] -format "%Y %m %d %H %M %S"]]]
    lappend chunks [list IEND ""]
    _write $file $chunks
}

proc ::png::_write {file chunks} {
    package require crc32
    set fh [open $file w+]
    fconfigure $fh -encoding binary -translation binary
    puts -nonewline $fh "\x89PNG\r\n\x1a\n"
    foreach chunk $chunks {
        puts -nonewline $fh [binary format Ia4 [string length [lindex $chunk 1]] [lindex $chunk 0]]
        puts -nonewline $fh [lindex $chunk 1]
        puts -nonewline $fh [binary format I [::crc::crc32 [join $chunk ""]]]
    }
    close $fh
    return $file
}
