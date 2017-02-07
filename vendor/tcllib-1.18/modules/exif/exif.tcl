# EXIF parser in Tcl
# Author: Darren New <dnew@san.rr.com>
# Translated directly from the Perl version
# by Chris Breeze <chris@breezesys.com>
# http://www.breezesys.com
# See the original comment block, reproduced
# at the bottom.
# Most of the inline comments about the meanings of fields
# are copied verbatim and without understanding from the
# original, unless "DNew" is there.
# Much of the structure is preserved, except in
# makerNote, where I got tired of typing as verbosely
# as the original Perl. But thanks for making it so
# readable that even someone who doesn't know Perl
# could translate it, Chris! ;-)
# PLEASE read and understand exif::fieldnames
# BEFORE making any changes here! Thanks!

# Usage of this version:
#     exif::analyze $stream ?$thumbnail?
# Stream should be an open file handle
# rewound to the start. It gets set to
# binary mode and is left at EOF or 
# possibly pointing at image data.
# You have to open and close the
# stream yourself.
# The return is a serialized array
# (a la [array get]) with informative
# english text about what was found.
# Errors in parsing or I/O or whatever
# throw errors.
#     exif::allfields
# returns a list of all possible field names.
# Added by DNew. Funky implementation.
#
# New
#     exif::analyzeFile $filename ?$thumbnail?
#
# If you find any mistakes here, feel free to correct them
# and/or send them to me. I just cribbed this - I don't even
# have a camera that puts this kind of info into the file.

# LICENSE: Standard BSD License.

# There's probably something here I'm using without knowing it.
package require Tcl 8.3

package provide exif 1.1.2 ; # first release

namespace eval ::exif {
    namespace export analyze analyzeFile fieldnames
    variable debug 0 ; # set to 1 for puts of debug trace
    variable cameraModel ; # used internally to understand options
    variable jpeg_markers ; # so we only have to do it once
    variable intel ; # byte order - so we don't have to pass to every read
    variable cached_fieldnames ; # just what it says
    array set jpeg_markers {
        SOF0  \xC0
        DHT   \xC4
        SOI   \xD8
        EOI   \xD9
        SOS   \xDA
        DQT   \xDB
        DRI   \xDD
        APP1  \xE1
    }
}

proc ::exif::debug {str} {
    variable debug
    if {$debug} {puts $str}
}

proc ::exif::streq {s1 s2} {
    return [string equal $s1 $s2]
}

proc ::exif::analyzeFile {file {thumbnail {}}} {
    set stream [open $file]
    set res [analyze $stream $thumbnail]
    close $stream
    return $res
}

proc ::exif::analyze {stream {thumbnail {}}} {
    variable jpeg_markers
    array set result {}
    fconfigure $stream -translation binary -encoding binary
    while {![eof $stream]} {
        set ch [read $stream 1]
        if {1 != [string length $ch]} {error "End of file reached @1"}
        if {![streq "\xFF" $ch]} {break} ; # skip image data
        set marker [read $stream 1]
        if {1 != [string length $marker]} {error "End of file reached @2"}
        if {[streq $marker $jpeg_markers(SOI)]} {
            debug "SOI"
        } elseif {[streq $marker $jpeg_markers(EOI)]} {
            debug "EOI"
        } else {
            set msb [read $stream 1]
            set lsb [read $stream 1]
            if {1 != [string length $msb] || 1 != [string length $lsb]} {
                error "File truncated @1"
            }
            scan $msb %c msb ; scan $lsb %c lsb
            set size [expr {256 * $msb + $lsb}]
            set data [read $stream [expr {$size-2}]]
	    debug "read [expr {$size - 2}] bytes of data"
            if {[expr {$size-2}] != [string length $data]} {
                error "File truncated @2"
            }
            if {[streq $marker $jpeg_markers(APP1)]} {
                debug "APP1\t$size"
                array set result [app1 $data $thumbnail]
            } elseif {[streq $marker $jpeg_markers(DQT)]} {
                debug "DQT\t$size"
            } elseif {[streq $marker $jpeg_markers(SOF0)]} {
                debug "SOF0\t$size"
            } elseif {[streq $marker $jpeg_markers(DHT)]} {
                debug "DHT\t$size"
            } elseif {[streq $marker $jpeg_markers(SOS)]} {
                debug "SOS\t$size"
            } else {
                binary scan $marker H* x
                debug "UNKNOWN MARKER $x"
            }
        }
    }
    return [array get result]
}

proc ::exif::app1 {data thumbnail} {
    variable intel
    variable cameraModel
    array set result {}
    if {![string equal [string range $data 0 5] "Exif\0\0"]} {
        error "APP1 does not contain EXIF"
    }
    debug "Reading EXIF data"
    set data [string range $data 6 end]
    set t [string range $data 0 1]
    if {[streq $t "II"]} {
        set intel 1
        debug "Intel byte alignment"
    } elseif {[streq $t "MM"]} {
        set intel 0
        debug "Motorola byte alignment"
    } else {
        error "Invalid byte alignment: $t"
    }
    if {[readShort $data 2]!=0x002A} {error "Invalid tag mark"}
    set curoffset [readLong $data 4] ; # just called "offset" in the Perl - DNew
    debug "Offset to first IFD: $curoffset"
    set numEntries [readShort $data $curoffset]
    incr curoffset 2
    debug "Number of directory entries: $numEntries"
    for {set i 0} {$i < $numEntries} {incr i} {
        set head [expr {$curoffset + 12 * $i}]
        set entry [string range $data $head [expr {$head+11}]]
        set tag [readShort $entry 0]
        set format [readShort $entry 2]
        set components [readLong $entry 4]
        set offset [readLong $entry 8]
        set value [readIFDEntry $data $format $components $offset]
        if {$tag==0x010e} {
            set result(ImageDescription) $value
        } elseif {$tag==0x010f} {
            set result(CameraMake) $value
        } elseif {$tag==0x0110} {
            set result(CameraModel) $value
            set cameraModel $value
        } elseif {$tag==0x0112} {
            set result(Orientation) $value
        } elseif {$tag == 0x011A} {
            set result(XResolution) $value
        } elseif {$tag == 0x011B} {
            set result(YResolution) $value
        } elseif {$tag == 0x0128} {
            set result(ResolutionUnit) "unknown"
            if {$value==2} {set result(ResolutionUnit) "inch"}
            if {$value==3} {set result(ResolutionUnit) "centimeter"}
        } elseif {$tag==0x0131} {
            set result(Software) $value
        } elseif {$tag==0x0132} {
            set result(DateTime) $value
        } elseif {$tag==0x0213} {
            set result(YCbCrPositioning) "unknown"
            if {$value==1} {set result(YCbCrPositioning) "Center of pixel array"}
            if {$value==2} {set result(YCbCrPositioning) "Datum point"}
        } elseif {$tag==0x8769} {
            # EXIF sub IFD
	    debug "==CALLING exifSubIFD=="
            array set result [exifSubIFD $data $offset]
        } else {
            debug "Unrecognized entry: Tag=$tag, value=$value"
        }
    }
    set offset [readLong $data [expr {$curoffset + 12 * $numEntries}]]
    debug "Offset to next IFD: $offset"
    array set thumb_result [exifSubIFD $data $offset]

    if {$thumbnail != {}} {
	set jpg [string range $data \
		$thumb_result(JpegIFOffset) \
		[expr {$thumb_result(JpegIFOffset) + $thumb_result(JpegIFByteCount) - 1}]]

        set         to [open $thumbnail w]
        fconfigure $to -translation binary -encoding binary
	puts       $to $jpg
        close      $to

        #can be used (with a JPG-aware TK) to add the image to the result array
	#set result(THUMB) [image create photo -file $thumbnail]
    }

    return [array get result]
}

# Extract EXIF sub IFD info
proc ::exif::exifSubIFD {data curoffset} {
    debug "EXIF: offset=$curoffset"
    set numEntries [readShort $data $curoffset]
    incr curoffset 2
    debug "Number of directory entries: $numEntries"
    for {set i 0} {$i < $numEntries} {incr i} {
        set head [expr {$curoffset + 12 * $i}]
        set entry [string range $data $head [expr {$head+11}]]
        set tag [readShort $entry 0]
        set format [readShort $entry 2]
        set components [readLong $entry 4]
        set offset [readLong $entry 8]
        if {$tag==0x9000} {
            set result(ExifVersion) [string range $entry 8 11]
        } elseif {$tag==0x9101} {
            set result(ComponentsConfigured) [format 0x%08x $offset]
        } elseif {$tag == 0x927C} {
            array set result [makerNote $data $offset]
        } elseif {$tag == 0x9286} {
            # Apparently, this doesn't usually work.
            set result(UserComment) "$offset - [string range $data $offset [expr {$offset+8}]]"
            set result(UserComment) [string trim $result(UserComment) "\0"]
        } elseif {$tag==0xA000} {
            set result(FlashPixVersion) [string range $entry 8 11]
        } elseif {$tag==0xA300} {
            # 3 means digital camera
            if {$offset == 3} {
                set result(FileSource) "3 - Digital camera"
            } else {
                set result(FileSource) $offset
            }
        } else {
            set value [readIFDEntry $data $format $components $offset]
            if {$tag==0x829A} {
                if {0.3 <= $value} {
                    # In seconds...
                    set result(ExposureTime) "$value seconds"
                } else {
                    set result(ExposureTime) "1/[expr {1.0/$value}] seconds"
                }
            } elseif {$tag == 0x829D} {
                set result(FNumber) $value
            } elseif {$tag == 0x8827} {
                # D30 stores ISO here, G1 uses MakerNote Tag 1 field 16
                set result(ISOSpeedRatings) $value
            } elseif {$tag == 0x9003} {
                set result(DateTimeOriginal) $value
            } elseif {$tag == 0x9004} {
                set result(DateTimeDigitized) $value
            } elseif {$tag == 0x9102} {
                if {$value == 5} {
                    set result(ImageQuality) "super fine"
                } elseif {$value == 3} {
                    set result(ImageQuality) "fine"
                } elseif {$value == 2} {
                    set result(ImageQuality) "normal"
                } else {
                    set result(CompressedBitsPerPixel) $value
                }
            } elseif {$tag == 0x9201} {
                # Not very accurate, use Exposure time instead.
                #  (That's Chris' comment. I don't know what it means.)
                set value [expr {pow(2,$value)}]
                if {$value < 4} {
                    set value [expr {1.0 / $value}]
                    set value [expr {int($value * 10 + 0.5) / 10.0}]
                } else {
                    set value [expr {int($value + 0.49)}]
                }
                set result(ShutterSpeedValue) "$value Hz"
            } elseif {$tag == 0x9202} {
                set value [expr {int(pow(sqrt(2.0), $value) * 10 + 0.5) / 10.0}]
                set result(AperatureValue) $value
            } elseif {$tag == 0x9204} {
                set value [compensationFraction $value]
                set result(ExposureBiasValue) $value
            } elseif {$tag == 0x9205} {
                set value [expr {int(pow(sqrt(2.0), $value) * 10 + 0.5) / 10.0}]
            } elseif {$tag == 0x9206} {
                # May need calibration
                set result(SubjectDistance) "$value m"
            } elseif {$tag == 0x9207} {
                set result(MeteringMode) "other"
                if {$value == 0} {set result(MeteringMode) "unknown"} 
                if {$value == 1} {set result(MeteringMode) "average"} 
                if {$value == 2} {set result(MeteringMode) "center weighted average"} 
                if {$value == 3} {set result(MeteringMode) "spot"} 
                if {$value == 4} {set result(MeteringMode) "multi-spot"} 
                if {$value == 5} {set result(MeteringMode) "multi-segment"} 
                if {$value == 6} {set result(MeteringMode) "partial"} 
            } elseif {$tag == 0x9209} {
                if {$value == 0} {
                    set result(Flash) no
                } elseif {$value == 1} {
                    set result(Flash) yes
                } else {
                    set result(Flash) "unknown: $value"
                }
            } elseif {$tag == 0x920a} {
                set result(FocalLength) "$value mm"
            } elseif {$tag == 0xA001} {
                set result(ColorSpace) $value
            } elseif {$tag == 0xA002} {
                set result(ExifImageWidth) $value
            } elseif {$tag == 0xA003} {
                set result(ExifImageHeight) $value
            } elseif {$tag == 0xA005} {
                set result(ExifInteroperabilityOffset) $value
            } elseif {$tag == 0xA20E} {
                set result(FocalPlaneXResolution) $value
            } elseif {$tag == 0xA20F} {
                set result(FocalPlaneYResolution) $value
            } elseif {$tag == 0xA210} {
                set result(FocalPlaneResolutionUnit) "none"
                if {$value == 2} {set result(FocalPlaneResolutionUnit) "inch"}
                if {$value == 3} {set result(FocalPlaneResolutionUnit) "centimeter"} 
            } elseif {$tag == 0xA217} {
                # 2 = 1 chip color area sensor
                set result(SensingMethod) $value
            } elseif {$tag == 0xA401} {
		#TJE
		set result(SensingMethod) "normal"
                if {$value == 1} {set result(SensingMethod) "custom"}
            } elseif {$tag == 0xA402} {
		#TJE
                set result(ExposureMode) "auto"
                if {$value == 1} {set result(ExposureMode) "manual"}
                if {$value == 2} {set result(ExposureMode) "auto bracket"}
            } elseif {$tag == 0xA403} {
		#TJE
                set result(WhiteBalance) "auto"
                if {$value == 1} {set result(WhiteBalance) "manual"}
            } elseif {$tag == 0xA404} {
                # digital zoom not used if number is zero
		set result(DigitalZoomRatio) "not used"
                if {$value != 0} {set result(DigitalZoomRatio) $value}
            } elseif {$tag == 0xA405} {
		set result(FocalLengthIn35mmFilm) "unknown"
                if {$value != 0} {set result(FocalLengthIn35mmFilm) $value}
            } elseif {$tag == 0xA406} {
                set result(SceneCaptureType) "Standard"
                if {$value == 1} {set result(SceneCaptureType) "Landscape"} 
                if {$value == 2} {set result(SceneCaptureType) "Portrait"}
                if {$value == 3} {set result(SceneCaptureType) "Night scene"}
            } elseif {$tag == 0xA407} {
                set result(GainControl) "none"
                if {$value == 1} {set result(GainControl) "Low gain up"} 
                if {$value == 2} {set result(GainControl) "High gain up"}
                if {$value == 3} {set result(GainControl) "Low gain down"}
                if {$value == 4} {set result(GainControl) "High gain down"}
            } elseif {$tag == 0x0103} {
		#TJE
		set result(Compression) "unknown"
		if {$value == 1} {set result(Compression) "none"}
		if {$value == 6} {set result(Compression) "JPEG"}
            } elseif {$tag == 0x011A} {
		#TJE
		set result(XResolution) $value
            } elseif {$tag == 0x011B} {
		#TJE
		set result(YResolution) $value
            } elseif {$tag == 0x0128} {
		#TJE
		set result(ResolutionUnit) "unknown"
		if {$value == 1} {set result(ResolutionUnit) "inch"}
		if {$value == 6} {set result(ResolutionUnit) "cm"}
            } elseif {$tag == 0x0201} {
		#TJE
		set result(JpegIFOffset) $value
		debug "offset = $value"
            } elseif {$tag == 0x0202} {
		#TJE
		set result(JpegIFByteCount) $value
		debug "bytecount = $value"
            } else {
                error "Unrecognized EXIF Tag: $tag (0x[string toupper [format %x $tag]])"
            }
        }
    }
    return [array get result]
}

# Canon proprietary data that I didn't feel like translating to Tcl yet.
proc ::exif::makerNote {data curoffset} {
    variable cameraModel
    debug "MakerNote: offset=$curoffset"

    array set result {}
    set numEntries [readShort $data $curoffset]
    incr curoffset 2
    debug "Number of directory entries: $numEntries"
    for {set i 0} {$i < $numEntries} {incr i} {
        set head [expr {$curoffset + 12 * $i}]
        set entry [string range $data $head [expr {$head+11}]]
        set tag [readShort $entry 0]
        set format [readShort $entry 2]
        set components [readLong $entry 4]
        set offset [readLong $entry 8]
        debug "$i)\tTag: $tag, format: $format, components: $components"

        if {$tag==6} {
            set value [readIFDEntry $data $format $components $offset]
            set result(ImageFormat) $value
        } elseif {$tag==7} {
            set value [readIFDEntry $data $format $components $offset]
            set result(FirmwareVersion) $value
        } elseif {$tag==8} {
            set value [string range $offset 0 2]-[string range $offset 3 end]
            set result(ImageNumber) $value
        } elseif {$tag==9} {
            set value [readIFDEntry $data $format $components $offset]
            set result(Owner) $value
        } elseif {$tag==0x0C} {
            # camera serial number
            set msw [expr {($offset >> 16) & 0xFFFF}]
            set lsw [expr {$offset & 0xFFFF}]
            set result(CameraSerialNumber) [format %04X%05d $msw $lsw]
        } elseif {$tag==0x10} {
            set result(UnknownTag-0x10) $offset
        } else {
            if {$format == 3 && 1 < $components} {
                debug "MakerNote $i: TAG=$tag"
                catch {unset field}
                array set field {}
                for {set j 0} {$j < $components} {incr j} {
                    set field($j) [readShort $data [expr {$offset+2*$j}]]
                    debug "$j : $field($j)"
                }
                if {$tag == 1} {
                    if {![string match -nocase "*Pro90*" $cameraModel]} {
                        if {$field(1)==1} {
                            set result(MacroMode) macro
                        } else {
                            set result(MacroMode) normal
                        }
                    }
                    if {0 < $field(2)} {
                        set result(SelfTimer) "[expr {$field(2)/10.0}] seconds"
                    }
                    set result(ImageQuality) [switch $field(3) {
                        2 {format Normal}
                        3 {format Fine}
                        4 {format "CCD Raw"}
                        5 {format "Super fine"}
                        default {format ""}
                    }]
                    set result(FlashMode) [switch $field(4) {
                        0 {format off}
                        1 {format auto}
                        2 {format on}
                        3 {format "red eye reduction"}
                        4 {format "slow synchro"}
                        5 {format "auto + red eye reduction"}
                        6 {format "on + red eye reduction"}
                        default {format ""}
                    }]
                    if {$field(5)} {
                        set result(ShootingMode) "Continuous"
                    } else {
                        set result(ShootingMode) "Single frame"
                    }
                    # Field 6 - don't know what it is.
                    set result(AutoFocusMode) [switch $field(7) {
                        0 {format "One-shot"}
                        1 {format "AI servo"}
                        2 {format "AI focus"}
                        3 - 6 {format "MF"}
                        5 {format "Continuous"}
                        4 {
                            # G1: uses field 32 to store single/continuous,
                            # and always sets 7 to 4.
                            if {[info exists field(32)] && $field(32)} {
                                format "Continuous"
                            } else {
                                format "Single"
                            }
                        }
                        default {format unknown}
                    }]
                    # Field 8 and 9 are unknown
                    set result(ImageSize) [switch $field(10) {
                        0 {format "large"}
                        1 {format "medium"}
                        2 {format "small"}
                        default {format "unknown"}
                    }]
                    # Field 11 - easy shooting - see field 20
                    # Field 12 - unknown
                    set NHL {
                        0 {format "Normal"}
                        1 {format "High"}
                        65536 {format "Low"}
                        default {format "Unknown"}
                    }
                    set result(Contrast) [switch $field(13) $NHL]
                    set result(Saturation) [switch $field(14) $NHL]
		    set result(Sharpness) [switch $field(15) $NHL]
                    set result(ISO) [switch $field(16) {
                        15 {format Auto}
                        16 {format 50}
                        17 {format 100}
                        18 {format 200}
                        19 {format 400}
                        default {format "unknown"}
                    }]
                    set result(MeteringMode) [switch $field(17) {
                        3 {format evaluative}
                        4 {format partial}
                        5 {format center-weighted}
                        default {format unknown}
                    }]
                    # Field 18 - unknown
		    if {[info exists field(19)]} {
			set result(AFPoint) [switch -- [expr {$field(19)-0x3000}] {
			    0 {format none}
			    1 {format auto-selected}
			    2 {format right}
			    3 {format center}
			    4 {format left}
			    default {format unknown}
			}] ; # {}
		    }
		    if {[info exists field(20)]} {
			if {$field(20) == 0} {
			    set result(ExposureMode) [switch $field(11) {
				0 {format auto}
				1 {format manual}
				2 {format landscape}
				3 {format "fast shutter"}
				4 {format "slow shutter"}
				5 {format "night scene"}
				6 {format "black and white"}
				7 {format sepia}
				8 {format portrait}
				9 {format sports}
				10 {format close-up}
				11 {format "pan focus"}
				default {format unknown}
			    }] ; # {}
			} elseif {$field(20) == 1} {
			    set result(ExposureMode) program
			} elseif {$field(20) == 2} {
			    set result(ExposureMode) Tv
			} elseif {$field(20) == 3} {
			    set result(ExposureMode) Av
			} elseif {$field(20) == 4} {
			    set result(ExposureMode) manual
			} elseif {$field(20) == 5} {
			    set result(ExposureMode) A-DEP
			} else {
			    set result(ExposureMode) unknown
			}
		    }
                    # Field 21 and 22 are unknown
                    # Field 23: max focal len, 24 min focal len, 25 units per mm
		    if {[info exists field(23)] && [info exists field(25)]} {
			set result(MaxFocalLength) \
				"[expr {1.0 * $field(23) / $field(25)}] mm"
		    }
                    if {[info exists field(24)] && [info exists field(25)]} {
			set result(MinFocalLength) \
				"[expr {1.0 * $field(24) / $field(25)}] mm"
		    }
                    # Field 26-28 are unknown.
		    if {[info exists field(29)]} {
			if {$field(29) & 0x0010} {
			    lappend result(FlashMode) "FP_sync_enabled"
			}
			if {$field(29) & 0x0800} {
			    lappend result(FlashMode) "FP_sync_used"
			}
			if {$field(29) & 0x2000} {
			    lappend result(FlashMode) "internal_flash"
			}
			if {$field(29) & 0x4000} {
			    lappend result(FlashMode) "external_E-TTL"
			}
		    }
                    if {[info exists field(34)] && \
			    [string match -nocase "*pro90*" $cameraModel]} {
                        if {$field(34)} {
                            set result(ImageStabilisation) on
                        } else {
                            set result(ImageStabilisation) off
                        }
                    }
                } elseif {$tag == 4} {
                    set result(WhiteBalance) [switch $field(7) {
                        0 {format Auto}
                        1 {format Daylight}
                        2 {format Cloudy}
                        3 {format Tungsten}
                        4 {format Fluorescent}
                        5 {format Flash}
                        6 {format Custom}
                        default {format Unknown}
                    }]
                    if {$field(14) & 0x07} {
                        set result(AFPointsUsed) \
                            [expr {($field(14)>>12) & 0x0F}]
                        if {$field(14)&0x04} {
                            append result(AFPointsUsed) " left"
                        }
                        if {$field(14)&0x02} {
                            append result(AFPointsUsed) " center"
                        }
                        if {$field(14)&0x01} {
                            append result(AFPointsUsed) " right"
                        }
                    }
		    if {[info exists field(15)]} {
			set v $field(15)
			if {32768 < $v} {incr v -65536}
			set v [compensationFraction [expr {$v / 32.0}]]
			set result(FlashExposureCompensation) $v
		    }
		    if {[info exists field(19)]} {
			set result(SubjectDistance) "$field(19) m"
		    }
                } elseif {$tag == 15} {
                    foreach k [array names field] {
                        set func [expr {($field($k) >> 8) & 0xFF}]
                        set v [expr {$field($k) & 0xFF}]
                        if {$func==1 && $v} {
                            set result(LongExposureNoiseReduction) on
                        } elseif {$func==1 && !$v} {
                            set result(LongExposureNoiseReduction) off
                        } elseif {$func==2} {
                            set result(Shutter/AE-Lock) [switch $v {
                                0 {format "AF/AE lock"}
                                1 {format "AE lock/AF"}
                                2 {format "AF/AF lock"}
                                3 {format "AE+release/AE+AF"}
                                default {format "Unknown"}
                            }]
                        } elseif {$func==3} {
                            if {$v} {
                                set result(MirrorLockup) enable
                            } else {
                                set result(MirrorLockup) disable
                            }
                        } elseif {$func==4} {
                            if {$v} {
                                set result(Tv/AvExposureLevel) "1/3 stop"
                            } else {
                                set result(Tv/AvExposureLevel) "1/2 stop"
                            }
                        } elseif {$func==5} {
                            if {$v} {
                                set result(AFAssistLight) off
                            } else {
                                set result(AFAssistLight) on
                            }
                        } elseif {$func==6} {
                            if {$v} {
                                set result(ShutterSpeedInAVMode) "Fixed 1/200"
                            } else {
                                set result(ShutterSpeedInAVMode) "Auto"
                            }
                        } elseif {$func==7} {
                            set result(AEBSeq/AutoCancel) [switch $v {
                                0 {format "0, -, + enabled"}
                                1 {format "0, -, + disabled"}
                                2 {format "-, 0, + enabled"}
                                3 {format "-, 0, + disabled"}
                                default {format unknown}
                            }]
                        } elseif {$func==8} {
                            if {$v} {
                                set result(ShutterCurtainSync) "2nd curtain sync"
                            } else {
                                set result(ShutterCurtainSync) "1st curtain sync"
                            }
                        } elseif {$func==9} {
                            set result(LensAFStopButtonFnSwitch) [switch $v {
                                0 {format "AF stop"}
                                1 {format "operate AF"}
                                2 {format "lock AE and start timer"}
                                default {format unknown}
                            }]
                        } elseif {$func==10} {
                            if {$v} {
                                set result(AutoReductionOfFillFlash) disable
                            } else {
                                set result(AutoReductionOfFillFlash) enable
                            }
                        } elseif {$func==11} {
                            if {$v} {
                                set result(MenuButtonReturnPosition) previous
                            } else {
                                set result(MenuButtonReturnPosition) top
                            }
                        } elseif {$func==12} {
                            set result(SetButtonFuncWhenShooting) [switch $v {
                                0 {format "not assigned"}
                                1 {format "change quality"}
                                2 {format "change ISO speed"}
                                3 {format "select parameters"}
                                default {format unknown}
                            }]
                        } elseif {$func==13} {
                            if {$v} {
                                set result(SensorCleaning) enable
                            } else {
                                set result(SensorCleaning) disable
                            }
                        } elseif {$func==0} {
                            # Discovered by DNew?
                            set result(CameraOwner) $v
                        } else {
                            append result(UnknownCustomFunc) "$func=$v "
                        }
                    }
                }
            } else {
                debug [format "makerNote: Unrecognized TAG: 0x%x" $tag]
            }
        }
    }
    return [array get result]
}

proc ::exif::readShort {data offset} {
    variable intel
    if {[string length $data] < [expr {$offset+2}]} {
        error "readShort: end of string reached"
    }
    set ch1 [string index $data $offset]
    set ch2 [string index $data [expr {$offset+1}]]
    scan $ch1 %c ch1 ; scan $ch2 %c ch2
    if {$intel} {
        return [expr {$ch1 + 256 * $ch2}]
    } else {
        return [expr {$ch2 + 256 * $ch1}]
    }
}

proc ::exif::readLong {data offset} {
    variable intel
    if {[string length $data] < [expr {$offset+4}]} {
        error "readLong: end of string reached"
    }
    set ch1 [string index $data $offset]
    set ch2 [string index $data [expr {$offset+1}]]
    set ch3 [string index $data [expr {$offset+2}]]
    set ch4 [string index $data [expr {$offset+3}]]
    scan $ch1 %c ch1 ; scan $ch2 %c ch2
    scan $ch3 %c ch3 ; scan $ch4 %c ch4
    if {$intel} {
        return [expr {(((($ch4 * 256) + $ch3) * 256) + $ch2) * 256 + $ch1}]
    } else {
        return [expr {(((($ch1 * 256) + $ch2) * 256) + $ch3) * 256 + $ch4}]
    }
}

proc ::exif::readIFDEntry {data format components offset} {
    variable intel
    if {$format == 2} {
        # ASCII string
        set value [string range $data $offset [expr {$offset+$components-1}]]
        return [string trimright $value "\0"]
    } elseif {$format == 3} {
        # unsigned short
        if {!$intel} {
            set offset [expr {0xFFFF & ($offset >> 16)}]
        }
        return $offset
    } elseif {$format == 4} {
        # unsigned long
        return $offset
    } elseif {$format == 5} {
        # unsigned rational
        # This could be messy, if either is >2**31
        set numerator [readLong $data $offset]
        set denominator [readLong $data [expr {$offset + 4}]]
        return [expr {(1.0*$numerator)/$denominator}]
    } elseif {$format == 10} {
        # signed rational
        # Should work normally, since everything in Tcl is signed
        set numerator [readLong $data $offset]
        set denominator [readLong $data [expr {$offset + 4}]]
        return [expr {(1.0*$numerator)/$denominator}]
    } else {
        set x [format %08x $format]
        error "Invalid IFD entry format: $x"
    }
}

proc ::exif::compensationFraction {value} {
    if {$value==0} {return 0}
    if {$value < 0} {
        set result "-"
        set value [expr {0-$value}]
    } else {
        set result "+"
    }
    set value [expr {int(0.5 + $value * 6)}]
    set integer [expr {int($value / 6)}]
    set sixths [expr {$value % 6}]
    if {$integer != 0} {
        append result $integer
        if {$sixths != 0} {
            append result " "
        }
    }
    if {$sixths == 2} {
        append result "1/3"
    } elseif {$sixths == 3} {
        append result "1/2" 
    } elseif {$sixths == 4} {
        append result "2/3"
    } else {
        # Added by DNew
        append result "$sixths/6"
    }
    return $result
}

# This returns the list of all possible fieldnames
# that analyze might return.
proc ::exif::fieldnames {} {
    variable cached_fieldnames 
    if {[info exists cached_fieldnames]} {
        return $cached_fieldnames
    }
    # Otherwise, parse the source to find the fieldnames.
    # Cool, huh? Don'tcha just love Tcl?
    # Because of this, "result(...)" should only appear
    # in these functions when "..." is the literal name
    # of a field to be returned.
    array set namelist {}
    foreach proc {analyze app1 exifSubIFD makerNote} {
        set body [info body ::exif::$proc]
        foreach line [split $body \n] {
            if {[regexp {result\(([^)]+)\)} $line junk name]} {
                set namelist($name) {}
            }
        }
    }
    set cached_fieldnames [lsort -dictionary [array names namelist]]
    return $cached_fieldnames
}



# # # # # # # # # # # # # #
# What follows is the original header comments
# from the Perl code from which this is 
# translated. Any changes I made directly
# are marked by "DNew".

# PERL script to extract EXIF information from JPEGs generated by Canon
# digital cameras.
# This software is free and you may do anything like with it except sell it.
#
# Current version: 1.3
# Author: Chris Breeze
# email: chris@breezesys.com
# Web: http://www.breezesys.com
#
# Based on experimenting with my G1 and information from:
# http://www.ba.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#
# Also Canon MakerNote from David Burren's page:
# http://www.burren.cx/david/canon.html
#
# More EXIF info and specs:
# http://exif.org
#
# Warnings: 
# 1) The Subject distance is unreliable. It seems reasonably accurate
# for the G1 but on the D30 it is highly dependent on the lens fitted.
#
# Perl for Windows is available for free from:
# http://www.activestate.com
#
# History
# 11 Jan 2001
# v0.1: Initial version
#
# 14 Jan 2001
# v0.2: Updated with data from David Burren's page
#
# 15 Jan 2001
# v0.3: Added more info for D30 (supplied by David Burren)
# 1) D30 stores ISO in EXIF tag 0x8827, G1 uses MakerNote 0x1/16
# 2) MakerNote 0x1/10, ImageSize appears to be large, medium, small
# 3) D30 allows 1/2 or 1/3 stop exposure compensation
# 4) Added D30 custom function details, but can't test them
#
# 17 Jan 2001
# v1.0 Tidied up AutoFocusMode for G1 vs D30 + added manual auto focus point (D30)
#
# 18 Jan 2001
# v1.1 Removed some debug code left in by mistake
#
# 29 Jan 2001
# v1.2 Added flash mode (MakerNote Tag 1, field 4)
#
# 7 Mar 2001
# v1.3 Added ImageQuality (MakerNote Tag 1, field 3)
#
# 21 Apr 2001
# v1.4 added ImageStabilisation for Pro90 IS
#
# 17 Sep 2001
# v1.5 Incorporated D30 improvements from Jim Leonard

if {0} {
    # Trivial usage example
    set x [exif::fieldnames]
    puts "fieldnames = $x"
    set f [open [lindex $argv 0]]
    array set v [exif::analyze $f]
    close $f
    parray v
}

