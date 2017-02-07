# tiff.tcl --
#
#       Querying and modifying TIFF image files.
#
# Copyright (c) 2004    Aaron Faupell <afaupell@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: tiff.tcl,v 1.5 2008/03/24 03:48:59 andreas_kupries Exp $

package provide tiff 0.2.1

namespace eval ::tiff {}

proc ::tiff::openTIFF {file {mode r}} {
    variable byteOrder
    set fh [open $file $mode]
    fconfigure $fh -encoding binary -translation binary -eofchar {}
    binary scan [read $fh 2] H4 byteOrder
    if {$byteOrder == "4949"} {
        set byteOrder little
    } elseif {$byteOrder == "4d4d"} {
        set byteOrder big
    } else {
        close $fh
        return -code error "not a tiff file"
    }
    _scan $byteOrder [read $fh 6] si version offset
    if {$version != "42"} {
        close $fh
        return -code error "not a tiff file"
    }
    seek $fh $offset start
    return $fh
}

proc ::tiff::isTIFF {file} {
    set is [catch {openTIFF $file} fh]
    catch {close $fh}
    return [expr {!$is}]
}

proc ::tiff::byteOrder {file} {
    variable byteOrder
    set fh [openTIFF $file]
    close $fh
    return $byteOrder
}

proc ::tiff::nametotag {names} {
    variable tiff_sgat
    set out {}
    foreach x $names {
        set y [lindex $x 0]
        if {[info exists tiff_sgat($y)]} {
            set y $tiff_sgat($y)
        } elseif {![string match {[0-9a-f][0-9a-f][0-9a-f][0-9a-f]} $x]} {
            error "unknown tag $y"
        }
        lappend out [lreplace $x 0 0 $y]
    }
    return $out
}

proc ::tiff::tagtoname {tags} {
    variable tiff_tags
    set out {}
    foreach x $tags {
        set y [lindex $x 0]
        if {[info exists tiff_tags($y)]} { set y $tiff_tags($y) }
        lappend out [lreplace $x 0 0 $y]
    }
    return $out
}

proc ::tiff::numImages {file} {
    variable byteOrder
    set fh [openTIFF $file]
    set images [llength [_ifds $fh]]
    close $fh
    return $images
}

proc ::tiff::dimensions {file {image 0}} {
    array set tmp [getEntry $file {0100 0101} $image]
    return [list $tmp(0100) $tmp(0101)]
}

proc ::tiff::imageInfo {file {image 0}} {
    return [getEntry $file {ImageWidth ImageLength BitsPerSample Compression \
          PhotometricInterpretation ImageDescription Orientation XResolution \
          YResolution ResolutionUnit DateTime Artist HostComputer} $image]
}

proc ::tiff::entries {file {image 0}} {
    variable byteOrder
    set fh [openTIFF $file]
    set ret {}
    if {[set ifd [lindex [_ifds $fh] $image]] != ""} {
        seek $fh $ifd
        foreach e [tagtoname [_entries $fh]] {
            lappend ret [lindex $e 0]
        }
    }
    close $fh
    return $ret
}

proc ::tiff::getEntry {file entry {image 0}} {
    variable byteOrder
    set fh [openTIFF $file]
    set ret {}
    if {[set ifd [lindex [_ifds $fh] $image]] != ""} {
        seek $fh $ifd 
        set ent [_entries $fh]
        foreach e $entry {
            if {[set x [lsearch -inline $ent "[nametotag $e] *"]] != ""} {
                seek $fh [lindex $x 1]
                lappend ret $e [lindex [_getEntry $fh] 1]
            } else {
                lappend ret $e {}
            }
        }
    }
    close $fh
    return $ret
}

proc ::tiff::addEntry {file entry {image 0}} {
    variable byteOrder
    set fh [openTIFF $file]
    set new [_new $file.tmp $byteOrder]
    set ifds [_ifds $fh]
    for {set i 0} {$i < [llength $ifds]} {incr i} {
        seek $fh [lindex $ifds $i]
        _readifd $fh ifd
        if {$i == $image || $image == "all"} {
            foreach e [nametotag $entry] {
                set ifd($e) [eval [linsert $e 0 _unformat $byteOrder]]
            }
        }
        _copyData $fh $new ifd
    }
    close $fh
    close $new
    file rename -force $file.tmp $file
}

proc ::tiff::deleteEntry {file entry {image 0}} {
    variable byteOrder
    set fh [openTIFF $file]
    set new [_new $file.tmp $byteOrder]
    set ifds [_ifds $fh]
    for {set i 0} {$i < [llength $ifds]} {incr i} {
        seek $fh [lindex $ifds $i]
        _readifd $fh ifd
        if {$i == $image || $image == "all"} {
            foreach e [nametotag $entry] { unset -nocomplain ifd($e) }
        }
        _copyData $fh $new ifd
    }
    close $fh
    close $new
    file rename -force $file.tmp $file
}

proc ::tiff::writeImage {image file {entry {}}} {
    variable byteOrder
    set byteOrder big
    set fh [_new $file $byteOrder]
    set w [$image cget -width]
    set h [$image cget -height]
    set ifd(0100) [_unformat $byteOrder 0100 4 $w]      ;# width
    set ifd(0101) [_unformat $byteOrder 0101 4 $h]      ;# height
    set ifd(0102) [_unformat $byteOrder 0102 3 {8 8 8}] ;# color depth
    set ifd(0103) [_unformat $byteOrder 0103 3 1]       ;# compression = none
    set ifd(0106) [_unformat $byteOrder 0106 3 2]       ;# photometric interpretation = rgb
    set ifd(0115) [_unformat $byteOrder 0115 3 3]       ;# 3 samples per pixel r, g, and b
    set ifd(011c) [_unformat $byteOrder 011c 3 1]       ;# planar configuration = rgb
    foreach {tag format value} $entry {
        set ifd($tag) [_unformat $byteOrder $tag $format $value]
    }

    set rowsPerStrip 2
    while {$w * 3 * $rowsPerStrip < 8000} { incr rowsPerStrip }
    incr rowsPerStrip -1
    set strips [expr {int(ceil($h / double($rowsPerStrip)))}]
    set stripSize [expr {$w * $rowsPerStrip * 3}]
    set lastStripSize [expr {3 * $w * ($h - (($strips - 1) * $rowsPerStrip))}]
    
    for {set i $strips} {$i > 1} {incr i -1} { lappend sizes $stripSize }
    lappend sizes $lastStripSize
    
    set ifd(0116) [_unformat $byteOrder 0116 4 $rowsPerStrip]
    set ifd(0111) [_unformat $byteOrder 0111 4 $sizes]
    # dummy data, to get ifd size, real value inserted later
    set ifd(0117) [_unformat $byteOrder 0117 4 $sizes]
    
    # add 8 bytes for file header
    set start [expr {[_ifdsize ifd] + 8}]
    for {set i $strips} {$i > 0} {incr i -1} {
        lappend offsets $start
        incr start $stripSize
    }
    set ifd(0111) [_unformat $byteOrder 0111 4 $offsets]
    
    _writeifd $fh ifd

    for {set y 0} {$y < $h} {incr y} {
        for {set x 0} {$x < $w} {incr x} {
            foreach {r g b} [$image get $x $y] {
                puts -nonewline $fh [_unscan $byteOrder ccc [expr {$r & 0xFF}] [expr {$g & 0xFF}] [expr {$b & 0xFF}]]
            }
        }
    }
    
    close $fh
}

proc ::tiff::getImage {file {image 0}} {
    array set tags [getEntry $file {0100 0101 0102 0103 0106 011c 0115 0111 0117 0140} $image]
    if {$tags(0102) == "8 8 8" && $tags(0103) == 1 && $tags(0106) == 2 && $tags(0115) == 3 && $tags(011c) == 1} {
        set w $tags(0100)
        set h $tags(0101)
        set i [image create photo -height $h -width $w]
        set fh [open $file]
        fconfigure $fh -translation binary -encoding binary -eofchar {}

        set y 0
        set x 0
        set row {}
        set block {}
        foreach offset $tags(0111) len $tags(0117) {
            seek $fh $offset start
            binary scan [read $fh $len] c* buf
            foreach {r g b} $buf {
                lappend row [format "#%02X%02X%02X" [expr {$r & 0xFF}] [expr {$g & 0xFF}] [expr {$b & 0xFF}]]
                incr x
                if {$x == $w} { lappend block $row; set row {}; set x 0 }
            }
            $i put $block -to 0 $y
            incr y [llength $block]
            set block {}
        }
        close $fh
    } elseif {$tags(0102) == 8 && $tags(0103) == 1 && $tags(0106) == 3 && $tags(0115) == 1 && $tags(011c) == 1} {
        set w $tags(0100)
        set h $tags(0101)
        set i [image create photo -height $h -width $w]
        set fh [open $file]
        fconfigure $fh -translation binary -encoding binary -eofchar {}

        set map {}
        set third [expr {[llength $tags(0140)] / 3}]
        set rs [lrange $tags(0140) 0 [expr {$third - 1}]]
        set gs [lrange $tags(0140) $third [expr {($third * 2) - 1}]]
        set bs [lrange $tags(0140) [expr {$third * 2}] end]
        foreach r $rs g $gs b $bs {
            set r [expr {int($r / 256) & 0xFF}]
            set g [expr {int($g / 256) & 0xFF}]
            set b [expr {int($b / 256) & 0xFF}]
            lappend map [format "#%02X%02X%02X" $r $g $b]
        }
        
        set y 0
        set x 0
        set row {}
        set block {}
        
        foreach offset $tags(0111) len $tags(0117) {
            seek $fh $offset start
            binary scan [read $fh $len] c* buf
            foreach index $buf {
                lappend row [lindex $map [expr {$index & 0xFF}]]
                incr x
                if {$x == $w} { lappend block $row; set row {}; set x 0 }
            }
            $i put $block -to 0 $y
            incr y [llength $block]
            set block {}
        }
        close $fh
    } else {
        error "I cant read that image format"
    }
    return $i
}

proc ::tiff::_copyData {fh new var} {
    variable byteOrder
    upvar $var ifd

    set fix {}
    #       strips, free bytes, tiles,   and their sizes     
    foreach f_off {0111 0120 0143} f_len {0117 0121 0144} {
        if {![info exists ifd($f_len)] || ![info exists ifd($f_off)]} { continue }
        set n 0
        # put everything into a list
        foreach x [_value $ifd($f_len)] y [_value $ifd($f_off)] {
            lappend fix [list $n $f_len $x $f_off $y]
            incr n
        }
    }
    set offset [expr {[tell $new] + [_ifdsize ifd]}]
    set new_fix {}
    # sort the list by offset
    foreach x [lsort -integer -index 4 $fix] {
        lappend new_fix [lreplace $x 4 4 $offset]
        incr offset [lindex $x 2]
    }
    foreach x [lsort -integer -index 0 $new_fix] {
        lappend blah([lindex $x 3]) [lindex $x 4]
    }
    foreach x [array names blah] {
        _scan $byteOrder [lindex $ifd($x) 0] x2s format
        set ifd($x) [_unformat $byteOrder $x $format $blah($x)]
    }
    if {[info exists ifd(8769)]} {
        seek $fh [_value $ifd(8769)]
        _readifd $fh exif
        _scan $byteOrder [lindex $ifd($x) 0] x2s format
        set ifd(8769) [_unformat $byteOrder 8769 $format $offset]
    }
    _writeifd $new ifd
        
    foreach x $fix {
        seek $fh [lindex $x 4] start
        fcopy $fh $new -size [lindex $x 2]
    }
    if {[info exists ifd(8769)]} {
        _writeifd $new exif
    }
}

# returns a list of offsets of all the IFDs
proc ::tiff::_ifds {fh} {
    variable byteOrder

    # number of entries in this ifd
    _scan $byteOrder [read $fh 2] s num
    # subract 2 to account for reading the number
    set ret [list [expr {[tell $fh] - 2}]]
    # skip the entries, 12 bytes each
    seek $fh [expr {$num * 12}] current
    # 4 byte offset to next ifd after entries
    _scan $byteOrder [read $fh 4] i next

    while {$next > 0} {
        seek $fh $next start
        _scan $byteOrder [read $fh 2] s num
        lappend ret [expr {[tell $fh] - 2}]
        seek $fh [expr {$num * 12}] current
        _scan $byteOrder [read $fh 4] i next
    }
    return $ret
}

# takes fh at start of IFD and returns entries, offset, and size
proc ::tiff::_entries {fh} {
    variable byteOrder
    variable formats
    set ret {}
    _scan $byteOrder [read $fh 2] s num
    for {} {$num > 0} {incr num -1} {
        set offset [tell $fh]
        binary scan [read $fh 2] H2H2 t1 t2
        _scan $byteOrder [read $fh 6] si format components
        seek $fh 4 current
        if {$byteOrder == "big"} {
            set tag $t1$t2
        } else {
            set tag $t2$t1
        }
        #puts "$tag $format $components"
        set size [expr {$formats($format) * $components}]
        lappend ret [list $tag $offset $size]
    }
    return $ret
}

# takes fh at start of dir entry and returns tag and value(s)
proc ::tiff::_getEntry {fh} {
    variable byteOrder
    variable formats
    binary scan [read $fh 2] H2H2 t1 t2
    _scan $byteOrder [read $fh 6] si format components
    if {$byteOrder == "big"} {
        set tag $t1$t2
    } else {
        set tag $t2$t1
    }
    set value [read $fh 4]
    set size [expr {$formats($format) * $components}]
    #puts "entry $tag $format $components $size"
    # if the data is over 4 bytes, its stored later in the file
    if {$size > 4} {
        set pos [tell $fh]
        _scan $byteOrder $value i value
        seek $fh $value start
        set value [read $fh $size]
        seek $fh $pos start
    }
    return [list $tag [_format $byteOrder $value $format $components]]
}

proc ::tiff::_value {data} {
    variable byteOrder
    _scan $byteOrder [lindex $data 0] x2si format components
    return [_format $byteOrder [lindex $data 1] $format $components]
}

proc ::tiff::_new {file byteOrder} {
    set fh [open $file w]
    fconfigure $fh -encoding binary -translation binary -eofchar {}
    if {$byteOrder == "big"} {
        puts -nonewline $fh [binary format H4 4d4d]
    } else {
        puts -nonewline $fh [binary format H4 4949]
    }
    puts -nonewline $fh [_unscan $byteOrder si 42 8]
    return $fh
}

proc ::tiff::_readifd {fh var} {
    variable byteOrder
    variable formats
    upvar $var ifd
    array set ifd {}
    _scan $byteOrder [read $fh 2] s num
    for {} {$num > 0} {incr num -1} {
        set one [read $fh 8]
        binary scan $one H2H2 t1 t2
        _scan $byteOrder $one x2si format components
        if {$byteOrder == "big"} {
            set tag $t1$t2
        } else {
            set tag $t2$t1
        }
        set ifd($tag) [list $one]
        set value [read $fh 4]
        set size [expr {$formats($format) * $components}]
        if {$size > 4} {
            set pos [tell $fh]
            _scan $byteOrder $value i value
            seek $fh $value start
            lappend ifd($tag) [read $fh $size]
            seek $fh $pos start
        } else {
            lappend ifd($tag) $value
        }
    }
}

proc ::tiff::_writeifd {new var} {
    variable byteOrder
    upvar $var ifd
    set num [llength [array names ifd]]
    puts -nonewline $new [_unscan $byteOrder s $num]
    set dataOffset [expr {[tell $new] + ($num * 12) + 4}]
    set data {}
    foreach tag [lsort [array names ifd]] {
        set entry $ifd($tag)
        puts -nonewline $new [lindex $entry 0]
        if {[string length [lindex $entry 1]] > 4} {
            puts -nonewline $new [_unscan $byteOrder i $dataOffset]
            append data [lindex $entry 1]
            incr dataOffset [string length [lindex $entry 1]]
        } else {
            puts -nonewline $new [lindex $entry 1]
        }
    }
    set next [tell $new]
    puts -nonewline $new [binary format i 0]
    puts -nonewline $new $data
    return $next
}

proc ::tiff::_ifdsize {var} {
    upvar $var ifd
    # 2 bytes for number of entries and 4 bytes for pointer to next ifd
    set size 6
    foreach x [array names ifd] {
        incr size 12
        # include data that doesnt fit in entry
        if {[string length [lindex $ifd($x) 1]] > 4} {
            incr size [string length [lindex $ifd($x) 1]]
        }
    }
    return $size
}

proc ::tiff::debug {file} {
    variable byteOrder
    variable tiff_tags
    set fh [openTIFF $file]
    set n 0
    foreach ifd [_ifds $fh] {
        seek $fh $ifd start
        set entries [_entries $fh]
        puts "IFD $n ([llength $entries] entries)"
        foreach ent $entries {
            if {[info exists tiff_tags([lindex $ent 0])]} {
                puts -nonewline "  $tiff_tags([lindex $ent 0])"
            } else {
                puts -nonewline "  [lindex $ent 0]"
            }
            if {[lindex $ent 2] < 200} {
                seek $fh [lindex $ent 1] start
                puts ": [lindex [_getEntry $fh] 1]"
            } else {
                puts " offset [lindex $ent 1] size [lindex $ent 2] bytes"
            }
            if {[lindex $ent 0] == "8769"} {
                seek $fh [lindex $ent 1] start
                seek $fh [lindex [_getEntry $fh] 1]
                foreach x [_entries $fh] {
                    seek $fh [lindex $x 1]
                    puts "    [_getEntry $fh]"
                }
            }
        }
        incr n
    }
}

array set ::tiff::tiff_tags {
    00fe NewSubfileType
    00ff SubfileType 
    0100 ImageWidth 
    0101 ImageLength
    0102 BitsPerSample 
    0103 Compression
    0106 PhotometricInterpretation
    0107 Threshholding 
    0108 CellWidth  
    0109 CellLength 
    010a FillOrder
    010e ImageDescription
    010f Make
    0110 Model
    0111 StripOffsets
    0112 Orientation   
    0115 SamplesPerPixel
    0116 RowsPerStrip
    0117 StripByteCounts
    0118 MinSampleValue
    0119 MaxSampleValue
    011a XResolution 
    011b YResolution
    011c PlanarConfiguration
    0120 FreeOffsets
    0121 FreeByteCounts
    0122 GrayResponseUnit
    0123 GrayResponseCurve
    0128 ResolutionUnit
    0131 Software
    0132 DateTime
    013b Artist
    013c HostComputer
    0140 ColorMap
    0152 ExtraSamples
    8298 Copyright

    010d DocumentName 
    011d PageName   
    011e XPosition  
    011f YPosition   
    0124 T4Options
    0125 T6Options
    0129 PageNumber
    012d TransferFunction
    013d Predictor
    013e WhitePoint
    013f PrimaryChromaticities
    0141 HalftoneHints
    0142 TileWidth   
    0143 TileLength  
    0144 TileOffsets
    0145 TileByteCounts  
    0146 BadFaxLines
    0147 CleanFaxData
    0148 ConsecutiveBadFaxLines
    014a SubIFDs
    014c InkSet
    014d InkNames
    014e NumberOfInks
    0150 DotRange
    0151 TargetPrinter
    0153 SampleFormat
    0154 SMinSampleValue
    0155 SMaxSampleValue
    0156 TransferRange
    0157 ClipPath
    0158 XClipPathUnits
    0159 YClipPathUnits
    015a Indexed
    015b JPEGTables
    015f OPIProxy
    0190 GlobalParametersIFD
    0191 ProfileType
    0192 FaxProfile
    0193 CodingMethods
    0194 VersionYear
    0195 ModeNumber
    01b1 Decode
    01b2 DefaultImageColor
    0200 JPEGProc
    0201 JPEGInterchangeFormat
    0202 JPEGInterchangeFormatLength
    0203 JPEGRestartInterval
    0205 JPEGLosslessPredictors
    0206 JPEGPointTransforms
    0207 JPEGQTables
    0208 JPEGDCTables
    0209 JPEGACTables
    0211 YCbCrCoefficients
    0212 YCbCrSubSampling
    0213 YCbCrPositioning
    0214 ReferenceBlackWhite
    022f StripRowCounts
    02bc XMP
    800d ImageID
    87ac ImageLayer

    8649 Photoshop
    8769 ExifIFD
    8773 ICCProfile
}

if {![info exists ::tiff::tiff_sgat]} {
    foreach {x y} [array get ::tiff::tiff_tags] {
        set ::tiff::tiff_sgat($y) $x
    }
}

array set ::tiff::data_types {
    1 BYTE
    2 ASCII
    3 SHORT
    4 LONG
    5 RATIONAL
    6 SBYTE
    7 UNDEFINED
    8 SSHORT
    9 SLONG
    10 SRATIONAL
    11 FLOAT
    12 DOUBLE
    BYTE 1
    ASCII 2
    SHORT 3
    LONG 4
    RATIONAL 5
    SBYTE 6 
    UNDEFINED 7
    SSHORT 8
    SLONG 9
    SRATIONAL 10
    FLOAT 11
    DOUBLE 12
}

# for mapping the format types to byte lengths
array set ::tiff::formats [list 1 1 2 1 3 2 4 4 5 8 6 1 7 1 8 2 9 4 10 8 11 4 12 8]

proc ::tiff::_seek {chan offset {origin start}} {
    if {$origin == "start"} {
        variable start
        seek $chan [expr {$offset + $start}] start
    } else {
        seek $chan $offset $origin
    }
}

# [binary scan], in the byte order indicated by $e
proc ::tiff::_scan {e v f args} {
     foreach x $args { upvar 1 $x $x }
     if {$e == "big"} {
          eval [list binary scan $v [string map {b B h H s S i I} $f]] $args
     } else {
         eval [list binary scan $v $f] $args
     }
}

# [binary format], in the byte order indicated by $e
proc ::tiff::_unscan {e f args} {
     if {$e == "big"} {
         return [eval [list binary format [string map {b B h H s S i I} $f]] $args]
     } else {
         return [eval [list binary format $f] $args]
     }
}

# formats values, the numbers correspond to data types
# values may be either byte order, as indicated by $end
# see the tiff spec for more info
proc ::tiff::_format {end value type num} {
    if {$num > 1 && $type != 2 && $type != 7} {
        variable formats
        set r {}
        for {set i 0} {$i < $num} {incr i} {
            set len $formats($type)
            lappend r [_format $end [string range $value [expr {$len * $i}] [expr {($len * $i) + $len - 1}]] $type 1]
        }
        #return [join $r ,]
        return $r
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

proc ::tiff::_unformat {end tag type value} {
    set packed_val {}
    set count [llength $value]
    if {$type == 2 || $type == 7} { set value [list $value] }
    foreach val $value {
        switch -exact -- $type {
            1 { set val [_unscan $end c $val] }
            2 {
                append val \x00
                set count [string length $val]
            }
            3 { set val [_unscan $end s $val] }
            4 { set val [_unscan $end i $val] }
            5 {
                set val [split $val /]
                set val [_unscan $end i [lindex $val 0]][_unscan $end i [lindex $val 1]]
            }
            6 { set val [_unscan $end c $val] }
            7 { set count [string length $val] }
            8 { set val [_unscan $end s $val] }
            9 { set val [_unscan $end i $val] }
            10 {
                set val [split $val /]
                set val [_unscan $end i [lindex $val 0]][_unscan $end i [lindex $val 1]]
            }
            11 { set val [_unscan $end $value i value] }
            12 { set val [_unscan $end $value w value] }
            default { error "unknown data type $type" }
        }
        append packed_val $val
    }
    if {$tag != ""} {
        if {$end == "big"} {
            set tag [binary format H2H2 [string range $tag 0 1] [string range $tag 2 3]]
        } else {
            set tag [binary format H2H2 [string range $tag 2 3] [string range $tag 0 1]]
        }
    }
    if {[string length $packed_val] < 4} { set packed_val [binary format a4 $packed_val] }
    return [list $tag[_unscan $end si $type $count] $packed_val]
}
        

