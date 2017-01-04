# jpeg.tcl --
#
#       Querying and modifying JPEG image files.
#
# Copyright (c) 2004    Aaron Faupell <afaupell@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: jpeg.tcl,v 1.19 2011/05/06 13:39:27 patthoyts Exp $

# ### ### ### ######### ######### #########
## Requisites

namespace eval ::jpeg {}

# ### ### ### ######### ######### #########
## Notes :: Structure of jpeg files.

# Base types
#
# BYTE    = 1 byte
# SHORT   = 2 bytes, endianess determined by context.
# BESHORT = 2 bytes, big endian
# INT     = 4 bytes, endianess determined by context.

# JPEG types
#
# JPEG = <
#   BYTE     [2] == 0xFF 0xD8 (SOI (Start Of Image))
#   JSEGMENT [.] 1 or more jpeg segments, variadic size
#   BYTE     [2] == 0xFF 0xD9 (EOI (End Of Image))
# >
#
# JSEGMENT = <
#   BYTE    [1]   == 0xFF
#   BYTE    [1]   Segment Tag, type marker
#   BESHORT [1]   Segment Length N
#   BYTE    [N-2] Segment Data, interpreted dependent on tag.
# >
#
# Notable segments, and their structure.
#
# Comment = JSEGMENT (Tag = 0xFE, Data = <
#
# >)


# Type 0xFE (Comment)
# Data BYTE [ ]
# Note: Multiple comment segments are allowed.

# Type 0xC0/0xC1/0xC2/0xC3 (Start of Frame)
# Data BYTE    [1] Precision
#      BESHORT [1] Height
#      BESHORT [1] Width
#      BYTE    [1] Number of color components
#      ...

# Type 0xEx (x=0-9A-F) (App0 - App15)
# Data It is expected that the data starts with a checkable marker, as
#      the app segments can be used by multiple applications for
#      different purposes. I.e. a sub-type is needed before the
#      segment data can be processed.

# App0/JFIF image info
# Type 0xE0
# Data BYTE    [5] 'JFIF\0'	JFIF sub-type marker
#      BYTE    [1] Version1 (major)
#      BYTE    [1] Version2 (minor)
#      BYTE    [1] Units
#      BESHORT [1] X-density (dots per inch ?)
#      BESHORT [1] Y-density
#      BYTE    [1] X-thumb   (Width  of thumbnail, if any, or zero)
#      BYTE    [1] Y-thumb   (Height of thumbnail, if any, or zero)

# App0/JFXX extended image information
# Type 0xE0
# Data BYTE    [5] 'JFXX\0'	JFXX sub-type marker
#      BYTE    [1] Extension code 10 -> JPEG thumbnail
#                                 11 -> Palletized thumbnail
#                                 13 -> RGB thumbnail
#      BYTE    [ ] Data per the extension code.

# App1/EXIF
# Type 0xE1
# Data BYTE  [6] 'Exif\0\0' EXIF sub-type marker. (1)
#      BYTE  [2] Byte Order  0x4d 0x4d = big endian
#                         or 0x49 0x49 = small endian
#      SHORT [1] Magic == 42 under the specified byteorder.
#      INT   [1] Next  == Offset to the first actual EXIF data block.
#
# EXIF data block structure (IFD = Image File Directory)
#
# 1. SHORT [1] Number N of exif entries
# 2. ENTRY [N] Array of exif entries
# 3. INT   [1] Offset to the next EXIF data block, or <0 for the last block.
#

# exif ENTRY structure
#
# 1. SHORT [1] num
# 2. SHORT [1] tag    = exif key
# 3. SHORT [1] format
# 4. INT   [1] component
# 5. INT   [1] value

# The 'value is interpreted dependent on the values of tag, format,
# and component.
#
# A.  Tag in ( 0x8769, 0xA005 )
#     Value is offset to a subordinate exif data block, process recursively.
# B.  Size = components * sizeof(format)
# B1. Size > 4
#     Value is offset to the actual value.
# B2. Size <= 4
#     Value is the actual value.

# Usually a jpeg with exif information has two exif data blocks. The
# first is the main block, the second the thumbnail block.
#
# Note that all the exif data structures are within the app1/exif
# segment.
#
# (1) The offset of the first byte after the exif marker is what all
#     the offsets in exif are relative to.

# Type 0xDA (SOS, Start of Stream/Scan)
# Followed by the JPEG data. Last segment before EOI

# ### ### ### ######### ######### #########

# open a file, check jpeg signature, and a return a file handle
# at the start of the first marker
proc ::jpeg::openJFIF {file {mode r}} {
    set fh [open $file $mode]
    fconfigure $fh -encoding binary -translation binary -eofchar {}
    # jpeg sig is FFD8, FF is start of first marker
    if {[read $fh 3] != "\xFF\xD8\xFF"} { close $fh; return -code error "not a jpg file" }
    # rewind to first marker
    seek $fh -1 current
    return $fh
}

# return a boolean indicating if a file starts with the jpeg sig
proc ::jpeg::isJPEG {file} {
    set is [catch {openJFIF $file} fh]
    catch {close $fh}
    return [expr {!$is}]
}

# takes an open filehandle at the start of a jpeg marker, and returns a list
# containing information about the file markers in the jpeg file. each list
# element itself a list of the marker type, offset of the start of its data,
# and the length of its data.
proc ::jpeg::markers {fh} {
    set chunks [list]
    while {[read $fh 1] == "\xFF"} {
        binary scan [read $fh 3] H2S type len
        # convert to unsigned
        set len [expr {$len & 0x0000FFFF}]
        # decrement len to account for marker bytes
        incr len -2
        lappend chunks [list $type [tell $fh] $len]
        seek $fh $len current
    }
    # chunks = list (list (type offset length) ...)
    return $chunks
}

proc ::jpeg::imageInfo {file} {
    set fh [openJFIF $file r]
    set data {}
    if {[set app0 [lsearch -inline [markers $fh] "e0 *"]] != ""} {
        seek $fh [lindex $app0 1] start
        set id [read $fh 5]
        if {$id == "JFIF\x00"} {
            binary scan [read $fh 9] cccSScc ver1 ver2 units xr yr xt yt
            set data [list version $ver1.$ver2 units $units xdensity $xr ydensity $yr xthumb $xt ythumb $yt]
        }
    }
    close $fh
    return $data
}

# return an images dimensions by reading the Start Of Frame marker
proc ::jpeg::dimensions {file} {
    set fh [openJFIF $file]
    set sof [lsearch -inline [markers $fh] {c[0-3] *}]
    seek $fh [lindex $sof 1] start
    binary scan [read $fh 5] cSS precision height width
    close $fh
    return [list $width $height]
}

# returns a list of all comments (FE segments) in the file
proc ::jpeg::getComments {file} {
    set fh [openJFIF $file]
    set comments {}
    foreach x [lsearch -all -inline [markers $fh] "fe *"] {
        seek $fh [lindex $x 1] start
        lappend comments [read $fh [lindex $x 2]]
    }
    close $fh
    return $comments
}

# add a new comment to the file
proc ::jpeg::addComment {file comment args} {
    set fh [openJFIF $file r+]
    # find the SoF and save all data after it
    set sof [lsearch -inline [markers $fh] {c[0-3] *}]
    seek $fh [expr {[lindex $sof 1] - 4}] start
    set data2 [read $fh]
    # seek back to the SoF and write comment(s) segment
    seek $fh [expr {[lindex $sof 1] - 4}] start
    foreach x [linsert $args 0 $comment] {
        if {$x == ""} continue
        puts -nonewline $fh [binary format a2Sa* "\xFF\xFE" [expr {[string length $x] + 2}] $x]
    }
    # write the saved data bac
    puts -nonewline $fh $data2
    close $fh
}

proc ::jpeg::replaceComment {file comment} {
    set com [getComments $file]
    removeComments $file
    eval [list addComment $file] [lreplace $com 0 0 $comment]
}

# removes all comment segments from the file
proc ::jpeg::removeComments {file} {
    set fh [openJFIF $file]
    set data "\xFF\xD8"
    foreach marker [markers $fh] {
        if {[lindex $marker 0] != "fe"} {
            # seek back 4 bytes to include the marker and length bytes
            seek $fh [expr {[lindex $marker 1] - 4}] start
            append data [read $fh [expr {[lindex $marker 2] + 4}]]
        }
    }
    append data [read $fh]
    close $fh
    set fh [open $file w]
    fconfigure $fh -encoding binary -translation binary -eofchar {}
    puts -nonewline $fh $data
    close $fh
}

# rewrites a jpeg file and removes all metadata (comments, exif, photoshop)
proc ::jpeg::stripJPEG {file} {
    set fh [openJFIF $file]
    set data {}
    
    set markers [markers $fh]
    # look for a jfif header segment and save it
    if {[lindex $markers 0 0] == "e0"} {
        seek $fh [lindex $markers 0 1] start
        if {[read $fh 5] == "JFIF\x00"} {
            seek $fh -9 current
            set jfif [read $fh [expr {[lindex $markers 0 2] + 4}]]
        }
    }
    # if we dont have a jfif header (exif files), create a fake one
    if {![info exists jfif]} {
        set jfif [binary format a2Sa5cccSScc "\xFF\xE0" 16 "JFIF\x00" 1 2 1 72 72 0 0]
    }

    # remove all the e* and f* markers (metadata)
    foreach marker $markers {
        if {![string match {[ef]*} [lindex $marker 0]]} {
            seek $fh [expr {[lindex $marker 1] - 4}] start
            append data [read $fh [expr {[lindex $marker 2] + 4}]]
        }
    }
    append data [read $fh]

    close $fh
    set fh [open $file w+]
    fconfigure $fh -encoding binary -translation binary -eofchar {}
    # write a jpeg file sig, a jfif header, and all the remaining data
    puts -nonewline $fh \xFF\xD8$jfif$data
    close $fh
}

# if file contains a jpeg thumbnail return it. the returned data is the actual
# jpeg data, it can be written directly to a file
proc ::jpeg::getThumbnail {file} {
    # check if the exif information contains a thumbnail
    array set exif [getExif $file thumbnail]
    if {[info exists exif(Compression)] && \
             $exif(Compression) == 6 && \
             [info exists exif(JPEGInterchangeFormat)] && \
             [info exists exif(JPEGInterchangeFormatLength)]} {
        set fh [openJFIF $file]
        seek $fh [expr {$exif(ExifOffset) + $exif(JPEGInterchangeFormat)}] start
        set thumb [read $fh $exif(JPEGInterchangeFormatLength)]
        close $fh
        return $thumb
    }
    # check for a JFXX segment which contains a thumbnail
    set fh [openJFIF $file]
    foreach x [lsearch -inline -all [markers $fh] "e0 *"] {
        seek $fh [lindex $x 1] start
        binary scan [read $fh 6] a5H2 id excode
        # excode 10 is jpeg encoding, we cant interpret the other types
        if {$id == "JFXX\x00" && $excode == "10"} {
            set thumb [read $fh [expr {[lindex $x 2] - 6}]]
            close $fh
            return $thumb
        }
    }
    close $fh
}


# takes key-value pairs returned by getExif and converts their values into
# human readable format
proc ::jpeg::formatExif {exif} {
    variable exif_values
    set out {}
    foreach {tag val} $exif {
        if {[info exists exif_values($tag,$val)]} {
            set val $exif_values($tag,$val)
        } elseif {[info exists exif_values($tag,)]} {
            set val $exif_values($tag,)
        } else {
            switch -exact -- $tag {
                UserComment {set val [string trim [string range $val 8 end] \x00]}
                ComponentsConfiguration {binary scan $val cccc a b c d; set val $a,$b,$c,$d}
                ExifVersion {set val [expr [string range $val 0 1].[string range $val 2 3]]}
                FNumber {set val [format %2.1f $val]}
                MaxApertureValue -
                ApertureValue {
                    if {$val > 0} {
                        set val [format %2.1f [expr {2 * (log($val) / log(2))}]]
                    }
                }
                ShutterSpeedValue {
                    set val [expr {pow(2, $val)}]
                    if {abs(round($val) - $val) < 0.2} {set val [expr {round($val)}]}
                    set val 1/[string trimright [string trimright [format %.2f $val] 0] .]
                }
                ExposureTime {
                    set val 1/[string trimright [string trimright [format %.4f [expr {1 / $val}]] 0] .]
                }
            }
        }
        lappend out $tag $val
    }
    return $out
}

# returns a list of all known exif keys
proc ::jpeg::exifKeys {} {
    variable exif_tags
    set ret {}
    foreach {x y} [array get exif_tags] {lappend ret $y}
    return $ret
}

proc ::jpeg::getExif {file {type main}} {
    set fh [openJFIF $file]
    set r [catch {getExifFromChannel $fh $type} err]
    close $fh
    return -code $r $err
}

proc ::jpeg::getExifFromChannel {chan {type main}} {
    # foreach because file may have multiple e1 markers
    foreach app1 [lsearch -inline -all [markers $chan] "e1 *"] {
        seek $chan [lindex $app1 1] start
        # check that this e1 is really an Exif segment
        if {[read $chan 6] != "Exif\x00\x00"} continue
        # save offset because exif offsets are relative to this
        set start [tell $chan]
        # next 2 bytes determine byte order
        binary scan [read $chan 2] H4 byteOrder
        if {$byteOrder == "4d4d"} {
            set byteOrder big
        } elseif {$byteOrder == "4949"} {
            set byteOrder little
        } else {
            return -code error "invalid byte order magic"
        }
        # the answer is 42, if we have our byte order correct
        _scan $byteOrder [read $chan 6] si magic next
        if {$magic != 42} { return -code error "invalid byte order"}

        seek $chan [expr {$start + $next}] start
        if {$type != "thumbnail"} {
	    if {$type != "main"} {
		return -code error "Bad type \"$type\", expected one of \"main\", or \"thumbnail\""
	    }
            set data [_exif $chan $byteOrder $start]
        } else {
            # number of entries in this exif block
            _scan $byteOrder [read $chan 2] s num
            # each entry is 12 bytes
            seek $chan [expr {$num * 12}] current
            # offset of next exif block (for thumbnail)
            _scan $byteOrder [read $chan 4] i next
            if {$next <= 0} { return }
            # but its relative to start
            seek $chan [expr {$start + $next}] start
            set data [_exif $chan $byteOrder $start]
        }
        lappend data ExifOffset $start ExifByteOrder $byteOrder
        return $data
    }
    return
}

proc ::jpeg::removeExif {file} {
    set fh [openJFIF $file]
    set data {}
    set markers [markers $fh]
    if {[lsearch $markers "e1 *"] < 0} { close $fh; return }
    foreach marker $markers {
        if {[lindex $marker 0] != "e1"} {
            seek $fh [expr {[lindex $marker 1] - 4}] start
            append data [read $fh [expr {[lindex $marker 2] + 4}]]
        } else {
            seek $fh [lindex $marker 1] start
            if {[read $fh 6] == "Exif\x00\x00"} continue
            seek $fh -10 current
            append data [read $fh [expr {[lindex $marker 2] + 4}]]
        }
    }
    append data [read $fh]
    close $fh
    set fh [open $file w]
    fconfigure $fh -encoding binary -translation binary -eofchar {}
    puts -nonewline $fh "\xFF\xD8"
    if {[lindex $markers 0 0] != "e0"} {
        puts -nonewline $fh [binary format a2Sa5cccSScc "\xFF\xE0" 16 "JFIF\x00" 1 2 1 72 72 0 0]
    }
    puts -nonewline $fh $data
    close $fh
}

proc ::jpeg::_exif2 {data} {
    variable exif_tags
    set byteOrder little
    set start 0
    set i 2
    for {_scan $byteOrder $data @0s num} {$num > 0} {incr num -1} {
        binary scan $data @${i}H2H2 t1 t2
        if {$byteOrder == "big"} {
            set tag $t1$t2
        } else {
            set tag $t2$t1
        }
        incr i 2
        _scan $byteOrder $data @${i}si format components
        incr i 6
        set value [string range $data $i [expr {$i + 3}]]
        if {$tag == "8769" || $tag == "a005"} {
            _scan $byteOrder $value i next
            #set pos [tell $fh]
            #seek $fh [expr {$offset + $next}] start
            #eval lappend return [_exif $fh $byteOrder $offset]
            #seek $fh $pos start
            continue
        }
        if {![info exists exif_formats($format)]} continue
        if {[info exists exif_tags($tag)]} { set tag $exif_tags($tag) }
        set size [expr {$exif_formats($format) * $components}]
        if {$size > 4} {
            _scan $byteOrder $value i value
            #puts "$value"
            #set value [string range $data [expr {$i + $offset + $value}] [expr {$size - 1}]]
        }
        lappend ret $tag [_format $byteOrder $value $format $components]
    }
}

# reads an exif block and returns key-value pairs
proc ::jpeg::_exif {fh byteOrder offset {tag_info exif_tags}} {
    variable exif_formats
    variable exif_tags
    variable gps_tags
    set return {}
    for {_scan $byteOrder [read $fh 2] s num} {$num > 0} {incr num -1} {
        binary scan [read $fh 2] H2H2 t1 t2
        _scan $byteOrder [read $fh 6] si format components
        if {$byteOrder == "big"} {
            set tag $t1$t2
        } else {
            set tag $t2$t1
        }
        set value [read $fh 4]
        # special tags, they point to more exif blocks
        if {$tag == "8769" || $tag == "a005"} {
            _scan $byteOrder $value i next
            set pos [tell $fh]
            seek $fh [expr {$offset + $next}] start
            eval lappend return [_exif $fh $byteOrder $offset]
            seek $fh $pos start
            continue
        }
	# special tag, another exif block holding GPS/location information.
	if {$tag == "8825"} {
            _scan $byteOrder $value i next
            set pos [tell $fh]
            seek $fh [expr {$offset + $next}] start
            eval lappend return [_exif $fh $byteOrder $offset gps_tags]
            seek $fh $pos start
            continue
	}
        if {![info exists exif_formats($format)]} continue
	upvar 0 $tag_info thetags
        if {[info exists thetags($tag)]} { set tag $thetags($tag) }
        set size [expr {$exif_formats($format) * $components}]
        # if the data is over 4 bytes, its stored later in the file, with the
        # data being the offset relative to the exif header
        if {$size > 4} {
            set pos [tell $fh]
            _scan $byteOrder $value i value
            seek $fh [expr {$offset + $value}] start
            set value [read $fh $size]
            seek $fh $pos start
        }
        lappend return $tag [_format $byteOrder $value $format $components]
    }
    return $return
}

proc ::jpeg::MakerNote {offset byteOrder Make data} {
    if {$Make == "Canon"} {
        set data [MakerNoteCanon $offset $byteOrder $data]
    } elseif {[string match Nikon* $data] || $Make == "NIKON"} {
        set data [MakerNoteNikon $offset $byteOrder $data]
    } elseif {[string match FUJIFILM* $data]} {
        set data [MakerNoteFuji $offset $byteOrder $data]
    } elseif {[string match OLYMP* $data]} {
        set data [MakerNoteOlympus $offset $byteOrder $data]
    }
    return $data
}

proc ::jpeg::MakerNoteNikon {offset byteOrder data} {
    variable exif_formats
    set return {}
    if {[string match Nikon* $data]} {
        set i 8
    } else {
        set i 0
    }
    binary scan $data @8s num
    incr i 2
    puts [expr {($num * 12) + $i}]
    puts [string range $data 142 150]
    #exit
    for {} {$num > 0} {incr num -1} {
        binary scan $data @${i}H2H2 t1 t2
        if {$byteOrder == "big"} {
            set tag $t1$t2
        } else {
            set tag $t2$t1
        }
        incr i 2
        _scan $byteOrder $data @${i}si format components
        incr i 6
        set value [string range $data $i [expr {$i + 3}]]
        if {![info exists exif_formats($format)]} continue
        #if {[info exists exif_tags($tag)]} { set tag $exif_tags($tag) }
        set size [expr {$exif_formats($format) * $components}]
        if {$size > 4} {
            _scan $byteOrder $value i value
            puts "$value"
            set value 1
            #set value [string range $data [expr {$i + $offset + $value}] [expr {$size - 1}]]
        } else {
        
        lappend ret $tag [_format $byteOrder $value $format $components]
        }
        puts "$tag $format $components $value"
    }
    return $return
}

proc ::jpeg::debug {file} {
    set fh [openJFIF $file]

    puts "marker: d8 length: 0"
    puts "  SOI (Start Of Image)"

    foreach marker [markers $fh] {
        seek $fh [lindex $marker 1] 
        puts "marker: [lindex $marker 0] length: [lindex $marker 2]"
        switch -glob -- [lindex $marker 0] {
            c[0-3] {
                binary scan [read $fh 6] cSSc precision height width color
                puts "  SOF (Start Of Frame) [string map {c0 "Baseline" c1 "Non-baseline" c2 "Progressive" c3 "Lossless"} [lindex $marker 0]]"
                puts "    Image dimensions: $width $height"
                puts "    Precision: $precision"
                puts "    Color Components: $color"
            }
            c4 {
                puts "  DHT (Define Huffman Table)"
                binary scan [read $fh 17] cS bits symbols
                puts "    $symbols symbols"
            }
            da {
                puts "  SOS (Start Of Scan)"
                binary scan [read $fh 2] c num
                puts "    Components: $num"
            }
            db {
                puts "  DQT (Define Quantization Table)"
            }
            dd {
                puts "  DRI (Define Restart Interval)"
                binary scan [read $fh 2] S num
                puts "    Interval: $num blocks"
            }
            e0 {
                set id [read $fh 5]
                if {$id == "JFIF\x00"} {
                    puts "  JFIF"
                    binary scan [read $fh 9] cccSScc ver1 ver2 units xr vr xt yt
                    puts "    Header: $ver1.$ver2 $units $xr $vr $xt $yt"
                } elseif {$id == "JFXX\x00"} {
                    puts "  JFXX (JFIF Extension)"
                    binary scan [read $fh 1] H2 excode
                    if {$excode == "10"} { set excode "10 (JPEG thumbnail)" }
                    if {$excode == "11"} { set excode "11 (Palletized thumbnail)" }
                    if {$excode == "13"} { set excode "13 (RGB thumbnail)" }
                    puts "    Extension code: 0x$excode"
                } else {
                    puts "  Unknown APP0 segment: $id"
                }
            }
            e1 {
                if {[read $fh 6] == "Exif\x00\x00"} {
                    puts "  EXIF data"
                    puts "    MAIN EXIF"
                    foreach {x y} [getExif $file] {
                        puts "    $x $y"
                    }
                    puts "    THUMBNAIL EXIF"
                    foreach {x y} [getExif $file thumbnail] {
                        puts "    $x $y"
                    }
                } else {
                    puts "  APP1 (unknown)"
                }
            }
            e2 {
                if {[read $fh 12] == "ICC_PROFILE\x00"} {
                    puts "  ICC profile"
                } else {
                    puts "  APP2 (unknown)"
                }
            }
            ed {
                if {[read $fh 18] == "Photoshop 3.0\0008BIM"} {
                    puts "  Photoshop 8BIM data"
                } else {
                    puts "  APP13 (unknown)"
                }
            }
            ee {
                if {[read $fh 5] == "Adobe"} {
                    puts "  Adobe metadata"
                } else {
                    puts "  APP14 (unknown)"
                }
            }
            e[3456789abcf] {
                puts [format "  %s%d %s" APP 0x[string index [lindex $marker 0] 1] (unknown)]
            }
            fe {
                puts "  Comment: [read $fh [lindex $marker 2]]"
            }
            default {
                puts "  Unknown"
            }
        }
    }
}

# for mapping the exif format types to byte lengths
array set ::jpeg::exif_formats [list 1 1 2 1 3 2 4 4 5 8 6 1 7 1 8 2 9 4 10 8 11 4 12 8]

# list of recognized exif tags. if a tag is not listed here it will show up as its raw hex value
array set ::jpeg::exif_tags {
    0100 ImageWidth
    0101 ImageLength
    0102 BitsPerSample
    0103 Compression
    0106 PhotometricInterpretation
    0112 Orientation
    0115 SamplesPerPixel
    011c PlanarConfiguration
    0212 YCbCrSubSampling
    0213 YCbCrPositioning
    011a XResolution
    011b YResolution
    0128 ResolutionUnit

    0111 StripOffsets
    0116 RowsPerStrip
    0117 StripByteCounts
    0201 JPEGInterchangeFormat
    0202 JPEGInterchangeFormatLength

    012d TransferFunction
    013e WhitePoint
    013f PrimaryChromaticities
    0211 YCbCrCoefficients
    0213 YCbCrPositioning
    0214 ReferenceBlackWhite

    0132 DateTime
    010e ImageDescription
    010f Make
    0110 Model
    0131 Software  
    013b Artist
    8298 Copyright
    
    9000 ExifVersion  
    a000 FlashpixVersion

    a001 ColorSpace

    9101 ComponentsConfiguration
    9102 CompressedBitsPerPixel
    a002 ExifImageWidth
    a003 ExifImageHeight

    927c MakerNote
    9286 UserComment

    a004 RelatedSoundFile

    9003 DateTimeOriginal
    9004 DateTimeDigitized
    9290 SubsecTime
    9291 SubsecTimeOriginal
    9292 SubsecTimeDigitized

    829a ExposureTime
    829d FNumber
    8822 ExposureProgram
    8824 SpectralSensitivity
    8827 ISOSpeedRatings
    8828 OECF
    9201 ShutterSpeedValue
    9202 ApertureValue
    9203 BrightnessValue
    9204 ExposureBiasValue
    9205 MaxApertureValue
    9206 SubjectDistance
    9207 MeteringMode
    9208 LightSource
    9209 Flash
    920a FocalLength
    9214 SubjectArea
    a20b FlashEnergy
    a20c SpatialFrequencyResponse
    a20e FocalPlaneXResolution
    a20f FocalPlaneYResolution
    a210 FocalPlaneResolutionUnit
    a214 SubjectLocation
    a215 ExposureIndex
    a217 SensingMethod
    a300 FileSource
    a301 SceneType
    a302 CFAPattern
    a401 CustomRendered
    a402 ExposureMode
    a403 WhiteBalance
    a404 DigitalZoomRatio
    a405 FocalLengthIn35mmFilm
    a406 SceneCaptureType
    a407 GainControl
    a408 Contrast
    a409 Saturation
    a40a Sharpness
    a40b DeviceSettingDescription
    a40c SubjectDistanceRange
    a420 ImageUniqueID

    
    0001 InteroperabilityIndex
    0002 InteroperabilityVersion
    1000 RelatedImageFileFormat
    1001 RelatedImageWidth
    1002 RelatedImageLength
    
    00fe NewSubfileType
    00ff SubfileType
    013d Predictor
    0142 TileWidth
    0143 TileLength
    0144 TileOffsets
    0145 TileByteCounts
    014a SubIFDs
    015b JPEGTables
    828d CFARepeatPatternDim
    828e CFAPattern
    828f BatteryLevel
    83bb IPTC/NAA
    8773 InterColorProfile
    8825 GPSInfo
    8829 Interlace
    882a TimeZoneOffset
    882b SelfTimerMode
    920c SpatialFrequencyResponse
    920d Noise
    9211 ImageNumber
    9212 SecurityClassification
    9213 ImageHistory
    9215 ExposureIndex
    9216 TIFF/EPStandardID
}

# list of recognized exif tags for the GPSInfo section--added by mdp 6/5/2009
array set ::jpeg::gps_tags {
    0000 GPSVersionID
    0001 GPSLatitudeRef
    0002 GPSLatitude
    0003 GPSLongitudeRef
    0004 GPSLongitude
    0005 GPSAltitudeRef
    0006 GPSAltitude
    0007 GPSTimeStamp
    0008 GPSSatellites
    0009 GPSStatus
    000a GPSMeasureMode
    000b GPSDOP
    000c GPSSpeedRef
    000d GPSSpeed
    000e GPSTrackRef
    000f GPSTrack
    0010 GPSImgDirectionRef
    0011 GPSImgDirection
    0012 GPSMapDatum
    0013 GPSDestLatitudeRef
    0014 GPSDestLatitude
    0015 GPSDestLongitudeRef
    0016 GPSDestLongitude
    0017 GPSDestBearingRef
    0018 GPSDestBearing
    0019 GPSDestDistanceRef
    001a GPSDestDistance
    001b GPSProcessingMethod
    001c GPSAreaInformation
    001d GPSDateStamp
    001e GPSDifferential
}

# for mapping exif values to plain english by [formatExif]
array set ::jpeg::exif_values {
    Compression,1 none
    Compression,6 JPEG
    Compression,  unknown

    PhotometricInterpretation,2 RGB
    PhotometricInterpretation,6 YCbCr
    PhotometricInterpretation,  unknown

    Orientation,1 normal
    Orientation,2 mirrored
    Orientation,3 "180 degrees"
    Orientation,4 "180 degrees, mirrored"
    Orientation,5 "90 degrees ccw, mirrored"
    Orientation,6 "90 degrees cw"
    Orientation,7 "90 degrees cw, mirrored"
    Orientation,8 "90 degrees ccw"
    Orientation,  unknown

    PlanarConfiguration,1 chunky
    PlanarConfiguration,2 planar
    PlanarConfiguration,  unknown

    YCbCrSubSampling,2,1 YCbCr4:2:2
    YCbCrSubSampling,2,2 YCbCr4:2:0
    YCbCrSubSampling,    unknown

    YCbCrPositioning,1 centered
    YCbCrPositioning,2 co-sited
    YCbCrPositioning,  unknown

    FlashpixVersion,0100 "Flashpix Format Version 1.0"
    FlashpixVersion,     unknown

    ColorSpace,1     sRGB
    ColorSpace,32768 uncalibrated
    ColorSpace,      unknown

    ExposureProgram,0 undefined
    ExposureProgram,1 manual
    ExposureProgram,2 normal
    ExposureProgram,3 "aperture priority"
    ExposureProgram,4 "shutter priority"
    ExposureProgram,5 creative
    ExposureProgram,6 action
    ExposureProgram,7 portrait
    ExposureProgram,8 landscape
    ExposureProgram,  unknown

    LightSource,0   unknown
    LightSource,1   daylight
    LightSource,2   flourescent
    LightSource,3   tungsten
    LightSource,4   flash
    LightSource,9   "fine weather"
    LightSource,10  "cloudy weather"
    LightSource,11  shade
    LightSource,12  "daylight flourescent"
    LightSource,13  "day white flourescent"
    LightSource,14  "cool white flourescent"
    LightSource,15  "white flourescent"
    LightSource,17  "standard light A"
    LightSource,18  "standard light B"
    LightSource,19  "standard light C"
    LightSource,20  D55
    LightSource,21  D65
    LightSource,22  D75
    LightSource,23  D50
    LightSource,24  "ISO studio tungsten"
    LightSource,255 other
    LightSource,    unknown

    Flash,0  "no flash"
    Flash,1  "flash fired"
    Flash,5  "strobe return light not detected"
    Flash,7  "strobe return light detected"
    Flash,9  "flash fired, compulsory flash mode"
    Flash,13 "flash fired, compulsory flash mode, return light not detected"
    Flash,15 "flash fired, compulsory flash mode, return light detected"
    Flash,16 "flash did not fire, compulsory flash mode"
    Flash,24 "flash did not fire, auto mode"
    Flash,25 "flash fired, auto mode"
    Flash,29 "flash fired, auto mode, return light not detected"
    Flash,31 "flash fired, auto mode, return light detected"
    Flash,32 "no flash function"
    Flash,65 "flash fired, red-eye reduction mode"
    Flash,69 "flash fired, red-eye reduction mode, return light not detected"
    Flash,71 "flash fired, red-eye reduction mode, return light detected"
    Flash,73 "flash fired, compulsory mode, red-eye reduction mode"
    Flash,77 "flash fired, compulsory mode, red-eye reduction mode, return light not detected"
    Flash,79 "flash fired, compulsory mode, red-eye reduction mode, return light detected"
    Flash,89 "flash fired, auto mode, red-eye reduction mode"
    Flash,93 "flash fired, auto mode, return light not detected, red-eye reduction mode"
    Flash,95 "flash fired, auto mode, return light detected, red-eye reduction mode"
    Flash,   unknown

    ResolutionUnit,2 inch
    ResolutionUnit,3 centimeter
    ResolutionUnit,  unknown

    SensingMethod,1 undefined
    SensingMethod,2 "one chip color area sensor"
    SensingMethod,3 "two chip color area sensor"
    SensingMethod,4 "three chip color area sensor"
    SensingMethod,5 "color sequential area sensor"
    SensingMethod,7 "trilinear sensor"
    SensingMethod,8 "color sequential linear sensor"
    SensingMethod,  unknown

    SceneType,\x01\x00\x00\x00 "directly photographed image"
    SceneType,                 unknown

    CustomRendered,0 normal
    CustomRendered,1 custom

    ExposureMode,0 auto
    ExposureMode,1 manual
    ExposureMode,2 "auto bracket"
    ExposureMode,  unknown

    WhiteBalance,0 auto
    WhiteBlanace,1 manual
    WhiteBlanace,  unknown

    SceneCaptureType,0 standard
    SceneCaptureType,1 landscape
    SceneCaptureType,2 portrait
    SceneCaptureType,3 night
    SceneCaptureType,  unknown

    GainControl,0 none
    GainControl,1 "low gain up"
    GainControl,2 "high gain up"
    GainControl,3 "low gain down"
    GainControl,4 "high gain down"
    GainControl,  unknown

    Contrast,0 normal
    Contrast,1 soft
    Contrast,2 hard
    Contrast,  unknown

    Saturation,0 normal
    Saturation,1 low
    Saturation,2 high
    Saturation,  unknown

    Sharpness,0 normal
    Sharpness,1 soft
    Sharpness,2 hard
    Sharpness,  unknown

    SubjectDistanceRange,0 unknown
    SubjectDistanceRange,1 macro
    SubjectDistanceRange,2 close
    SubjectDistanceRange,3 distant
    SubjectDistanceRange,  unknown
    
    MeteringMode,0   unknown
    MeteringMode,1   average
    MeteringMode,2   "center weighted average"
    MeteringMode,3   spot
    MeteringMode,4   multi-spot
    MeteringMode,5   multi-segment
    MeteringMode,6   partial
    MeteringMode,255 other
    MeteringMode,    unknown
    
    FocalPlaneResolutionUnit,2 inch
    FocalPlaneResolutionUnit,3 centimeter
    FocalPlaneResolutionUnit,  none
    
    DigitalZoomRatio,0 "not used"
    
    FileSource,\x03\x00\x00\x00 "digital still camera"
    FileSource,                 unknown
}

# [binary scan], in the byte order indicated by $e
proc ::jpeg::_scan {e v f args} {
     foreach x $args { upvar 1 $x $x }
     if {$e == "big"} {
         eval [list binary scan $v [string map {b B h H s S i I} $f]] $args
     } else {
         eval [list binary scan $v $f] $args
     }
}


# formats exif values, the numbers correspond to data types
# values may be either byte order, as indicated by $end
# see the exif spec for more info
proc ::jpeg::_format {end value type num} {
    if {$num > 1 && $type != 2 && $type != 7} {
        variable exif_formats
        set r {}
        for {set i 0} {$i < $num} {incr i} {
            set len $exif_formats($type)
            lappend r [_format $end [string range $value [expr {$len * $i}] [expr {($len * $i) + $len - 1}]] $type 1]
        }
        return [join $r ,]
    }
    switch -exact -- $type {
        1 { _scan $end $value c value }
        2 { set value [string trimright $value \x00] }
        3 {
            _scan $end $value s value
            set value [format %u $value]
        }
        4 {
            _scan $end $value i value
            set value [format %u $value]
        }
        5 {
            _scan $end $value ii n d
            set n [format %u $n]
            set d [format %u $d]
            if {$d == 0} {set d 1}
            #set value [string trimright [string trimright [format %5.4f [expr {double($n) / $d}]] 0] .]
            set value [string trimright [string trimright [expr {double($n) / $d}] 0] .]
            #set value "$n/$d"
        }
        6 { _scan $end $value c value }
        8 { _scan $end $value s value }
        9 { _scan $end $value i value }
        10 {
            _scan $end $value ii n d
            if {$d == 0} {set d 1}
            #set value [string trimright [string trimright [format %5.4f [expr {double($n) / $d}]] 0] .]
            set value [string trimright [string trimright [expr {double($n) / $d}] 0] .]
            #set value "$n/$d"
        }
        11 { _scan $end $value i value }
        12 { _scan $end $value w value }
    }
    return $value
}

# Do a compatibility version of [lassign] for versions of Tcl without
# that command. Not using a version check as special builds may have
# the command even if they are a version which nominally would not.

if {![llength [info commands lassign]]} {
    proc ::jpeg::lassign {sequence v args} {
	set args [linsert $args 0 $v]
	set a [::llength $args]

	# Nothing to assign.
	#if {$a == 0} {return $sequence}

	# Perform assignments
	set i 0
	foreach v $args {
	    upvar 1 $v var
	    set        var [::lindex $sequence $i]
	    incr i
	}

	# Return remainder, if there is any.
	return [::lrange $sequence $a end]
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide jpeg 0.5

