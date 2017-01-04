# filetypes.tcl --
#
#	Tcl based file type recognizer using the runtime core and
#	generated from /usr/share/misc/magic.mime. Limited output,
#	but only mime-types, i.e. standardized.
#
# Copyright (c) 2004-2005 Colin McCormack <coldstore@users.sourceforge.net>
# Copyright (c) 2005-2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: filetypes.tcl,v 1.6 2006/09/27 21:19:35 andreas_kupries Exp $

#####
#
# "mime type discriminator"
# http://wiki.tcl.tk/12537
#
# Tcl code harvested on:  10 Feb 2005, 04:16 GMT
# Wiki page last updated: ???
#
#####

# ### ### ### ######### ######### #########
## Requirements.

package require Tcl 8.4
package require fileutil::magic::rt    ; # We need the runtime core.

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::fileutil::magic {}

proc ::fileutil::magic::filetype {file} {
    if {![file exists $file]} {
        return -code error "file not found: \"$file\""
    }
    if {[file isdirectory $file]} {
	return directory
    }

    rt::open $file
    filetype::run
    rt::close
    set types [rt::resultv]

    if {[llength $types]} {
	# We postprocess the data if needed, as the low-level
	# recognizer can return duplicate information.

	array set _ {}
	set utypes  {}
	foreach t $types {
	    if {[info exists _($t)]} continue
	    lappend utypes $t
	    set _($t) .
	    set types $utypes
	}
    }
    return [join $types]
}

package provide fileutil::magic::filetype 1.0.2
# The actual recognizer is the command below.

##
## -- Do not edit after this line !
## -- ** BEGIN GENERATED CODE ** --

package require fileutil::magic::rt
namespace eval ::fileutil::magic::filetype {
    namespace import ::fileutil::magic::rt::*
}

proc ::fileutil::magic::filetype::run {} {
switch -- [Nv S 0] 518 {emit {ALAN game data}
if {[N c 2 < 0xa]} {emit {version 2.6%d}}
} -7408 {emit {Amiga Workbench}
if {[N S 2 == 0x1]} {switch -- [Nv c 48] 1 {emit {disk icon}} 2 {emit {drawer icon}} 3 {emit {tool icon}} 4 {emit {project icon}} 5 {emit {garbage icon}} 6 {emit {device icon}} 7 {emit {kickstart icon}} 8 {emit {workbench application icon}} 
}
if {[N S 2 > 0x1]} {emit {icon, vers. %d}}
} 3840 {emit {AmigaOS bitmap font}} 3843 {emit {AmigaOS outline font}} 19937 {emit {MPEG-4 LO-EP audio stream}} 3599 {emit {Atari MSA archive data}
if {[N S 2 x {}]} {emit {\b, %d sectors per track}}
switch -- [Nv S 4] 0 {emit {\b, 1 sided}} 1 {emit {\b, 2 sided}} 
if {[N S 6 x {}]} {emit {\b, starting track: %d}}
if {[N S 8 x {}]} {emit {\b, ending track: %d}}
} 368 {emit {WE32000 COFF}
if {[N S 18 ^ 0x10]} {emit object}
if {[N S 18 & 0x10]} {emit executable}
if {[N I 12 > 0x0]} {emit {not stripped}}
if {[N S 18 ^ 0x1000]} {emit {N/A on 3b2/300 w/paging}}
if {[N S 18 & 0x2000]} {emit {32100 required}}
if {[N S 18 & 0x4000]} {emit {and MAU hardware required}}
switch -- [Nv S 20] 263 {emit {\(impure\)}} 264 {emit {\(pure\)}} 267 {emit {\(demand paged\)}} 291 {emit {\(target shared library\)}} 
if {[N S 22 > 0x0]} {emit {- version %ld}}
} 369 {emit {WE32000 COFF executable \(TV\)}
if {[N I 12 > 0x0]} {emit {not stripped}}
} 14541 {emit {C64 PCLink Image}} 30463 {emit {squeezed data,}
if {[S 4 x {}]} {emit {original name %s}}
} 30462 {emit {crunched data,}
if {[S 2 x {}]} {emit {original name %s}}
} 30461 {emit {LZH compressed data,}
if {[S 2 x {}]} {emit {original name %s}}
} -32760 {emit {Lynx cartridge,}
if {[N S 2 x {}]} {emit {RAM start $%04x}}
if {[S 6 == BS93]} {emit 0 12 1}
if {[N I 16 == 0x3030 &0xfe00f0f0]} {emit {Infocom game data}}
if {[N c 0 == 0x0]} {emit {\(false match\)}}
if {[N c 0 > 0x0]} {emit {\(Z-machine %d,}
if {[N S 2 x {}]} {emit {Release %d /}}
if {[S 18 x {}]} {emit {Serial %.6s\)}}
}
} 2935 {emit {ATSC A/52 aka AC-3 aka Dolby Digital stream,}
switch -- [Nv c 4 &0xc0] 0 {emit {48 kHz,}} 64 {emit {44.1 kHz,}} -128 {emit {32 kHz,}} -64 {emit {reserved frequency,}} 
switch -- [Nv c 6 &0xe0] 0 {emit {1+1 front,}} 32 {emit {1 front/0 rear,}} 64 {emit {2 front/0 rear,}} 96 {emit {3 front/0 rear,}} -128 {emit {2 front/1 rear,}} -96 {emit {3 front/1 rear,}} -64 {emit {2 front/2 rear,}} -32 {emit {3 front/2 rear,}} 
switch -- [Nv c 7 &0x40] 0 {emit {LFE off,}} 64 {emit {LFE on,}} 
switch -- [Nv S 6 &0x0180] 0 {emit {Dolby Surround not indicated}} 128 {emit {not Dolby Surround encoded}} 256 {emit {Dolby Surround encoded}} 384 {emit {reserved Dolby Surround mode}} 
} 5493 {emit {fsav \(linux\) macro virus}
if {[N s 8 > 0x0]} {emit {\(%d-}}
if {[N c 11 > 0x0]} {emit {\b%02d-}}
if {[N c 10 > 0x0]} {emit {\b%02d\)}}
} -26367 {emit {GPG key public ring}} 1280 {emit {Hitachi SH big-endian COFF}
switch -- [Nv S 18 &0x0002] 0 {emit object} 2 {emit executable} 
switch -- [Nv S 18 &0x0008] 8 {emit {\b, stripped}} 0 {emit {\b, not stripped}} 
} 351 {emit {370 XA sysV executable}
if {[N I 12 > 0x0]} {emit {not stripped}}
if {[N S 22 > 0x0]} {emit {- version %d}}
if {[N I 30 > 0x0]} {emit {- 5.2 format}}
} 346 {emit {370 XA sysV pure executable}
if {[N I 12 > 0x0]} {emit {not stripped}}
if {[N S 22 > 0x0]} {emit {- version %d}}
if {[N I 30 > 0x0]} {emit {- 5.2 format}}
} 22529 {emit {370 sysV pure executable}
if {[N I 12 > 0x0]} {emit {not stripped}}
} 23041 {emit {370 XA sysV pure executable}
if {[N I 12 > 0x0]} {emit {not stripped}}
} 23809 {emit {370 sysV executable}
if {[N I 12 > 0x0]} {emit {not stripped}}
} 24321 {emit {370 XA sysV executable}
if {[N I 12 > 0x0]} {emit {not stripped}}
} 345 {emit {SVR2 executable \(Amdahl-UTS\)}
if {[N I 12 > 0x0]} {emit {not stripped}}
if {[N I 24 > 0x0]} {emit {- version %ld}}
} 348 {emit {SVR2 pure executable \(Amdahl-UTS\)}
if {[N I 12 > 0x0]} {emit {not stripped}}
if {[N I 24 > 0x0]} {emit {- version %ld}}
} 344 {emit {SVR2 pure executable \(USS/370\)}
if {[N I 12 > 0x0]} {emit {not stripped}}
if {[N I 24 > 0x0]} {emit {- version %ld}}
} 349 {emit {SVR2 executable \(USS/370\)}
if {[N I 12 > 0x0]} {emit {not stripped}}
if {[N I 24 > 0x0]} {emit {- version %ld}}
} 407 {emit {Apollo m68k COFF executable}
if {[N S 18 ^ 0x4000]} {emit {not stripped}}
if {[N S 22 > 0x0]} {emit {- version %ld}}
} 404 {emit {apollo a88k COFF executable}
if {[N S 18 ^ 0x4000]} {emit {not stripped}}
if {[N S 22 > 0x0]} {emit {- version %ld}}
} 200 {emit {hp200 \(68010\) BSD}
switch -- [Nv S 2] 263 {emit {impure binary}} 264 {emit {read-only binary}} 267 {emit {demand paged binary}} 
} 300 {emit {hp300 \(68020+68881\) BSD}
switch -- [Nv S 2] 263 {emit {impure binary}} 264 {emit {read-only binary}} 267 {emit {demand paged binary}} 
} 479 {emit {executable \(RISC System/6000 V3.1\) or obj module}
if {[N I 12 > 0x0]} {emit {not stripped}}
} 260 {emit {shared library}} 261 {emit {ctab data}} -508 {emit {structured file}} 12320 {emit {character Computer Graphics Metafile}} 474 {emit {SGI image data}
if {[N c 2 == 0x1]} {emit {\b, RLE}}
if {[N c 3 == 0x2]} {emit {\b, high precision}}
if {[N S 4 x {}]} {emit {\b, %d-D}}
if {[N S 6 x {}]} {emit {\b, %d x}}
if {[N S 8 x {}]} {emit %d}
if {[N S 10 x {}]} {emit {\b, %d channel}}
if {[N S 10 != 0x1]} {emit {\bs}}
if {[S 80 > 0]} {emit {\b, \"%s\"}}
} 4112 {emit {PEX Binary Archive}} 2560 {emit {PCX ver. 2.5 image data}} 2562 {emit {PCX ver. 2.8 image data, with palette}} 2563 {emit {PCX ver. 2.8 image data, without palette}} 2564 {emit {PCX for Windows image data}} 2565 {emit {PCX ver. 3.0 image data}
if {[N s 4 x {}]} {emit {bounding box [%hd,}}
if {[N s 6 x {}]} {emit {%hd] -}}
if {[N s 8 x {}]} {emit {[%hd,}}
if {[N s 10 x {}]} {emit %hd\],}
if {[N c 65 > 0x1]} {emit {%d planes each of}}
if {[N c 3 x {}]} {emit %hhd-bit}
switch -- [Nv c 68] 0 {emit image,} 1 {emit colour,} 2 {emit grayscale,} 
if {[N c 68 > 0x2]} {emit image,}
if {[N c 68 < 0x0]} {emit image,}
if {[N s 12 > 0x0]} {emit {%hd x}
if {[N s 14 x {}]} {emit {%hd dpi,}}
}
switch -- [Nv c 2] 0 {emit uncompressed} 1 {emit {RLE compressed}} 
} 12320 {emit {character Computer Graphics Metafile}} 21930 {emit {BIOS \(ia32\) ROM Ext.}
if {[S 5 == USB]} {emit USB}
if {[S 7 == LDR]} {emit {UNDI image}}
if {[S 30 == IBM]} {emit {IBM comp. Video}}
if {[S 26 == Adaptec]} {emit Adaptec}
if {[S 28 == Adaptec]} {emit Adaptec}
if {[S 42 == PROMISE]} {emit Promise}
if {[N c 2 x {}]} {emit {\(%d*512\)}}
} -21267 {emit {Java serialization data}
if {[N S 2 > 0x4]} {emit {\b, version %d}}
} -40 {emit {JPEG image data}
if {[S 6 == JFIF]} {emit {\b, JFIF standard}
if {[N c 11 x {}]} {emit {\b %d.}}
if {[N c 12 x {}]} {emit {\b%02d}}
if {[N c 18 != 0x0]} {emit {\b, thumbnail %dx}
if {[N c 19 x {}]} {emit {\b%d}}
}
}
if {[S 6 == Exif]} {emit {\b, EXIF standard}
if {[S 12 == II]} {if {[N s 70 == 0x8769]} {if {[N s [I 78 i 14] == 0x9000]} {if {[N c [I 78 i 23] x {}]} {emit %c}
if {[N c [I 78 i 24] x {}]} {emit {\b.%c}}
if {[N c [I 78 i 25] != 0x30]} {emit {\b%c}}
}
}
if {[N s 118 == 0x8769]} {if {[N s [I 126 i 38] == 0x9000]} {if {[N c [I 126 i 47] x {}]} {emit %c}
if {[N c [I 126 i 48] x {}]} {emit {\b.%c}}
if {[N c [I 126 i 49] != 0x30]} {emit {\b%c}}
}
}
if {[N s 130 == 0x8769]} {if {[N s [I 138 i 38] == 0x9000]} {if {[N c [I 138 i 47] x {}]} {emit %c}
if {[N c [I 138 i 48] x {}]} {emit {\b.%c}}
if {[N c [I 138 i 49] != 0x30]} {emit {\b%c}}
}
if {[N s [I 138 i 50] == 0x9000]} {if {[N c [I 138 i 59] x {}]} {emit %c}
if {[N c [I 138 i 60] x {}]} {emit {\b.%c}}
if {[N c [I 138 i 61] != 0x30]} {emit {\b%c}}
}
if {[N s [I 138 i 62] == 0x9000]} {if {[N c [I 138 i 71] x {}]} {emit %c}
if {[N c [I 138 i 72] x {}]} {emit {\b.%c}}
if {[N c [I 138 i 73] != 0x30]} {emit {\b%c}}
}
}
if {[N s 142 == 0x8769]} {if {[N s [I 150 i 38] == 0x9000]} {if {[N c [I 150 i 47] x {}]} {emit %c}
if {[N c [I 150 i 48] x {}]} {emit {\b.%c}}
if {[N c [I 150 i 49] != 0x30]} {emit {\b%c}}
}
if {[N s [I 150 i 50] == 0x9000]} {if {[N c [I 150 i 59] x {}]} {emit %c}
if {[N c [I 150 i 60] x {}]} {emit {\b.%c}}
if {[N c [I 150 i 61] != 0x30]} {emit {\b%c}}
}
if {[N s [I 150 i 62] == 0x9000]} {if {[N c [I 150 i 71] x {}]} {emit %c}
if {[N c [I 150 i 72] x {}]} {emit {\b.%c}}
if {[N c [I 150 i 73] != 0x30]} {emit {\b%c}}
}
}
}
if {[S 12 == MM]} {if {[N S 118 == 0x8769]} {if {[N S [I 126 I 14] == 0x9000]} {if {[N c [I 126 I 23] x {}]} {emit %c}
if {[N c [I 126 I 24] x {}]} {emit {\b.%c}}
if {[N c [I 126 I 25] != 0x30]} {emit {\b%c}}
}
if {[N S [I 126 I 38] == 0x9000]} {if {[N c [I 126 I 47] x {}]} {emit %c}
if {[N c [I 126 I 48] x {}]} {emit {\b.%c}}
if {[N c [I 126 I 49] != 0x30]} {emit {\b%c}}
}
}
if {[N S 130 == 0x8769]} {if {[N S [I 138 I 38] == 0x9000]} {if {[N c [I 138 I 47] x {}]} {emit %c}
if {[N c [I 138 I 48] x {}]} {emit {\b.%c}}
if {[N c [I 138 I 49] != 0x30]} {emit {\b%c}}
}
if {[N S [I 138 I 62] == 0x9000]} {if {[N c [I 138 I 71] x {}]} {emit %c}
if {[N c [I 138 I 72] x {}]} {emit {\b.%c}}
if {[N c [I 138 I 73] != 0x30]} {emit {\b%c}}
}
}
if {[N S 142 == 0x8769]} {if {[N S [I 150 I 50] == 0x9000]} {if {[N c [I 150 I 59] x {}]} {emit %c}
if {[N c [I 150 I 60] x {}]} {emit {\b.%c}}
if {[N c [I 150 I 61] != 0x30]} {emit {\b%c}}
}
}
}
}
switch -- [Nv c [I 4 S 5]] -2 {emit {}
if {[S [I 4 S 8] x {}]} {emit {\b, comment: \"%s\"}}
} -64 {emit {\b, baseline}
if {[N c [I 4 S 6] x {}]} {emit {\b, precision %d}}
if {[N S [I 4 S 7] x {}]} {emit {\b, %dx}}
if {[N S [I 4 S 9] x {}]} {emit {\b%d}}
} -63 {emit {\b, extended sequential}
if {[N c [I 4 S 6] x {}]} {emit {\b, precision %d}}
if {[N S [I 4 S 7] x {}]} {emit {\b, %dx}}
if {[N S [I 4 S 9] x {}]} {emit {\b%d}}
} -62 {emit {\b, progressive}
if {[N c [I 4 S 6] x {}]} {emit {\b, precision %d}}
if {[N S [I 4 S 7] x {}]} {emit {\b, %dx}}
if {[N S [I 4 S 9] x {}]} {emit {\b%d}}
} 
} -32768 {emit {lif file}} -30875 {emit {disk quotas file}} 1286 {emit {IRIS Showcase file}
if {[N c 2 == 0x49]} {emit -}
if {[N c 3 x {}]} {emit {- version %ld}}
} 550 {emit {IRIS Showcase template}
if {[N c 2 == 0x63]} {emit -}
if {[N c 3 x {}]} {emit {- version %ld}}
} 352 {emit {MIPSEB ECOFF executable}
switch -- [Nv S 20] 263 {emit {\(impure\)}} 264 {emit {\(swapped\)}} 267 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 22 x {}]} {emit {- version %ld}}
if {[N c 23 x {}]} {emit .%ld}
} 354 {emit {MIPSEL-BE ECOFF executable}
switch -- [Nv S 20] 263 {emit {\(impure\)}} 264 {emit {\(swapped\)}} 267 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 23 x {}]} {emit {- version %d}}
if {[N c 22 x {}]} {emit .%ld}
} 24577 {emit {MIPSEB-LE ECOFF executable}
switch -- [Nv S 20] 1793 {emit {\(impure\)}} 2049 {emit {\(swapped\)}} 2817 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 23 x {}]} {emit {- version %d}}
if {[N c 22 x {}]} {emit .%ld}
} 25089 {emit {MIPSEL ECOFF executable}
switch -- [Nv S 20] 1793 {emit {\(impure\)}} 2049 {emit {\(swapped\)}} 2817 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 23 x {}]} {emit {- version %ld}}
if {[N c 22 x {}]} {emit .%ld}
} 355 {emit {MIPSEB MIPS-II ECOFF executable}
switch -- [Nv S 20] 263 {emit {\(impure\)}} 264 {emit {\(swapped\)}} 267 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 22 x {}]} {emit {- version %ld}}
if {[N c 23 x {}]} {emit .%ld}
} 358 {emit {MIPSEL-BE MIPS-II ECOFF executable}
switch -- [Nv S 20] 263 {emit {\(impure\)}} 264 {emit {\(swapped\)}} 267 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 22 x {}]} {emit {- version %ld}}
if {[N c 23 x {}]} {emit .%ld}
} 25345 {emit {MIPSEB-LE MIPS-II ECOFF executable}
switch -- [Nv S 20] 1793 {emit {\(impure\)}} 2049 {emit {\(swapped\)}} 2817 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 23 x {}]} {emit {- version %ld}}
if {[N c 22 x {}]} {emit .%ld}
} 26113 {emit {MIPSEL MIPS-II ECOFF executable}
switch -- [Nv S 20] 1793 {emit {\(impure\)}} 2049 {emit {\(swapped\)}} 2817 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 23 x {}]} {emit {- version %ld}}
if {[N c 22 x {}]} {emit .%ld}
} 320 {emit {MIPSEB MIPS-III ECOFF executable}
switch -- [Nv S 20] 263 {emit {\(impure\)}} 264 {emit {\(swapped\)}} 267 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 22 x {}]} {emit {- version %ld}}
if {[N c 23 x {}]} {emit .%ld}
} 322 {emit {MIPSEL-BE MIPS-III ECOFF executable}
switch -- [Nv S 20] 263 {emit {\(impure\)}} 264 {emit {\(swapped\)}} 267 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 22 x {}]} {emit {- version %ld}}
if {[N c 23 x {}]} {emit .%ld}
} 16385 {emit {MIPSEB-LE MIPS-III ECOFF executable}
switch -- [Nv S 20] 1793 {emit {\(impure\)}} 2049 {emit {\(swapped\)}} 2817 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 23 x {}]} {emit {- version %ld}}
if {[N c 22 x {}]} {emit .%ld}
} 16897 {emit {MIPSEL MIPS-III ECOFF executable}
switch -- [Nv S 20] 1793 {emit {\(impure\)}} 2049 {emit {\(swapped\)}} 2817 {emit {\(paged\)}} 
if {[N I 8 > 0x0]} {emit {not stripped}}
if {[N I 8 == 0x0]} {emit stripped}
if {[N c 23 x {}]} {emit {- version %ld}}
if {[N c 22 x {}]} {emit .%ld}
} 384 {emit {MIPSEB Ucode}} 386 {emit {MIPSEL-BE Ucode}} 336 {emit {mc68k COFF}
if {[N S 18 ^ 0x10]} {emit object}
if {[N S 18 & 0x10]} {emit executable}
if {[N I 12 > 0x0]} {emit {not stripped}}
if {[S 168 == .lowmem]} {emit {Apple toolbox}}
switch -- [Nv S 20] 263 {emit {\(impure\)}} 264 {emit {\(pure\)}} 267 {emit {\(demand paged\)}} 273 {emit {\(standalone\)}} 
} 337 {emit {mc68k executable \(shared\)}
if {[N I 12 > 0x0]} {emit {not stripped}}
} 338 {emit {mc68k executable \(shared demand paged\)}
if {[N I 12 > 0x0]} {emit {not stripped}}
} 364 {emit {68K BCS executable}} 365 {emit {88K BCS executable}} 24602 {emit {Atari 68xxx executable,}
if {[N I 2 x {}]} {emit {text len %lu,}}
if {[N I 6 x {}]} {emit {data len %lu,}}
if {[N I 10 x {}]} {emit {BSS len %lu,}}
if {[N I 14 x {}]} {emit {symboltab len %lu,}}
if {[N I 18 == 0x0]} {emit 0 70 4}
if {[N I 22 & 0x1]} {emit {fastload flag,}}
if {[N I 22 & 0x2]} {emit {may be loaded to alternate RAM,}}
if {[N I 22 & 0x4]} {emit {malloc may be from alternate RAM,}}
if {[N I 22 x {}]} {emit {flags: 0x%lX,}}
if {[N S 26 == 0x0]} {emit {no relocation tab}}
if {[N S 26 != 0x0]} {emit {+ relocation tab}}
if {[S 30 == SFX]} {emit {[Self-Extracting LZH SFX archive]}}
if {[S 38 == SFX]} {emit {[Self-Extracting LZH SFX archive]}}
if {[S 44 == ZIP!]} {emit {[Self-Extracting ZIP SFX archive]}}
} 100 {emit {Atari 68xxx CPX file}
if {[N S 8 x {}]} {emit {\(version %04lx\)}}
} 392 {emit {Tower/XP rel 2 object}
if {[N I 12 > 0x0]} {emit {not stripped}}
switch -- [Nv S 20] 263 {emit executable} 264 {emit {pure executable}} 
if {[N S 22 > 0x0]} {emit {- version %ld}}
} 397 {emit {Tower/XP rel 2 object}
if {[N I 12 > 0x0]} {emit {not stripped}}
switch -- [Nv S 20] 263 {emit executable} 264 {emit {pure executable}} 
if {[N S 22 > 0x0]} {emit {- version %ld}}
} 400 {emit {Tower/XP rel 3 object}
if {[N I 12 > 0x0]} {emit {not stripped}}
switch -- [Nv S 20] 263 {emit executable} 264 {emit {pure executable}} 
if {[N S 22 > 0x0]} {emit {- version %ld}}
} 405 {emit {Tower/XP rel 3 object}
if {[N I 12 > 0x0]} {emit {not stripped}}
switch -- [Nv S 20] 263 {emit executable} 264 {emit {pure executable}} 
if {[N S 22 > 0x0]} {emit {- version %ld}}
} 408 {emit {Tower32/600/400 68020 object}
if {[N I 12 > 0x0]} {emit {not stripped}}
switch -- [Nv S 20] 263 {emit executable} 264 {emit {pure executable}} 
if {[N S 22 > 0x0]} {emit {- version %ld}}
} 416 {emit {Tower32/800 68020}
if {[N S 18 & 0x2000]} {emit {w/68881 object}}
if {[N S 18 & 0x4000]} {emit {compatible object}}
if {[N S 18 & 0xffff9fff]} {emit object}
switch -- [Nv S 20] 263 {emit executable} 267 {emit {pure executable}} 
if {[N I 12 > 0x0]} {emit {not stripped}}
if {[N S 22 > 0x0]} {emit {- version %ld}}
} 421 {emit {Tower32/800 68010}
if {[N S 18 & 0x4000]} {emit {compatible object}}
if {[N S 18 & 0xffff9fff]} {emit object}
switch -- [Nv S 20] 263 {emit executable} 267 {emit {pure executable}} 
if {[N I 12 > 0x0]} {emit {not stripped}}
if {[N S 22 > 0x0]} {emit {- version %ld}}
} -30771 {emit {OS9/6809 module:}
switch -- [Nv c 6 &0x0f] 0 {emit non-executable} 1 {emit {machine language}} 2 {emit {BASIC I-code}} 3 {emit {Pascal P-code}} 4 {emit {C I-code}} 5 {emit {COBOL I-code}} 6 {emit {Fortran I-code}} 
switch -- [Nv c 6 &0xf0] 16 {emit {program executable}} 32 {emit subroutine} 48 {emit multi-module} 64 {emit {data module}} -64 {emit {system module}} -48 {emit {file manager}} -32 {emit {device driver}} -16 {emit {device descriptor}} 
} 19196 {emit {OS9/68K module:}
if {[N c 20 == 0x80 &0x80]} {emit re-entrant}
if {[N c 20 == 0x40 &0x40]} {emit ghost}
if {[N c 20 == 0x20 &0x20]} {emit system-state}
switch -- [Nv c 19] 1 {emit {machine language}} 2 {emit {BASIC I-code}} 3 {emit {Pascal P-code}} 4 {emit {C I-code}} 5 {emit {COBOL I-code}} 6 {emit {Fortran I-code}} 
switch -- [Nv c 18] 1 {emit {program executable}} 2 {emit subroutine} 3 {emit multi-module} 4 {emit {data module}} 11 {emit {trap library}} 12 {emit {system module}} 13 {emit {file manager}} 14 {emit {device driver}} 15 {emit {device descriptor}} 
} -26368 {emit {PGP key public ring}} -27391 {emit {PGP key security ring}} -27392 {emit {PGP key security ring}} -23040 {emit {PGP encrypted data}} -4693 {emit {}
if {[N S 2 == 0xeedb]} {emit RPM
if {[N c 4 x {}]} {emit v%d}
switch -- [Nv S 6] 0 {emit bin} 1 {emit src} 
switch -- [Nv S 8] 1 {emit i386} 2 {emit Alpha} 3 {emit Sparc} 4 {emit MIPS} 5 {emit PowerPC} 6 {emit 68000} 7 {emit SGI} 8 {emit RS6000} 9 {emit IA64} 10 {emit Sparc64} 11 {emit MIPSel} 12 {emit ARM} 
if {[S 10 x {}]} {emit %s}
}
} -1279 {emit {QDOS object}
if {[S 2 x {} p]} {emit '%s'}
} -511 {emit {MySQL table definition file}
if {[N c 2 x {}]} {emit {Version %d}}
} 378 {emit {amd 29k coff noprebar executable}} 890 {emit {amd 29k coff prebar executable}} -8185 {emit {amd 29k coff archive}} 
if {[S 0 == {TADS2\ bin}]} {emit TADS
if {[N I 9 != 0xa0d1a00]} {emit {game data, CORRUPTED}}
if {[N I 9 == 0xa0d1a00]} {if {[S 13 x {}]} {emit {%s game data}}
}
}
if {[S 0 == {TADS2\ rsc}]} {emit TADS
if {[N I 9 != 0xa0d1a00]} {emit {resource data, CORRUPTED}}
if {[N I 9 == 0xa0d1a00]} {if {[S 13 x {}]} {emit {%s resource data}}
}
}
if {[S 0 == {TADS2\ save/g}]} {emit TADS
if {[N I 12 != 0xa0d1a00]} {emit {saved game data, CORRUPTED}}
if {[N I 12 == 0xa0d1a00]} {if {[S [I 16 s 32] x {}]} {emit {%s saved game data}}
}
}
if {[S 0 == {TADS2\ save}]} {emit TADS
if {[N I 10 != 0xa0d1a00]} {emit {saved game data, CORRUPTED}}
if {[N I 10 == 0xa0d1a00]} {if {[S 14 x {}]} {emit {%s saved game data}}
}
}
switch -- [Nv i 0] -1010055483 {emit {RISC OS Chunk data}
if {[S 12 == OBJ_]} {emit {\b, AOF object}}
if {[S 12 == LIB_]} {emit {\b, ALF library}}
} 65389 {emit {very old VAX archive}} 65381 {emit {old VAX archive}
if {[S 8 == __.SYMDEF]} {emit {random library}}
} 236525 {emit {PDP-11 old archive}} 236526 {emit {PDP-11 4.0 archive}} 6583086 {emit {DEC audio data:}
switch -- [Nv i 12] 1 {emit {8-bit ISDN mu-law,}} 2 {emit {8-bit linear PCM [REF-PCM],}} 3 {emit {16-bit linear PCM,}} 4 {emit {24-bit linear PCM,}} 5 {emit {32-bit linear PCM,}} 6 {emit {32-bit IEEE floating point,}} 7 {emit {64-bit IEEE floating point,}} 23 {emit {8-bit ISDN mu-law compressed \(CCITT G.721 ADPCM voice data encoding\),}} 
switch -- [Nv I 12] 8 {emit {Fragmented sample data,}} 10 {emit {DSP program,}} 11 {emit {8-bit fixed point,}} 12 {emit {16-bit fixed point,}} 13 {emit {24-bit fixed point,}} 14 {emit {32-bit fixed point,}} 18 {emit {16-bit linear with emphasis,}} 19 {emit {16-bit linear compressed,}} 20 {emit {16-bit linear with emphasis and compression,}} 21 {emit {Music kit DSP commands,}} 24 {emit {compressed \(8-bit CCITT G.722 ADPCM\)}} 25 {emit {compressed \(3-bit CCITT G.723.3 ADPCM\),}} 26 {emit {compressed \(5-bit CCITT G.723.5 ADPCM\),}} 27 {emit {8-bit A-law \(CCITT G.711\),}} 
switch -- [Nv i 20] 1 {emit mono,} 2 {emit stereo,} 4 {emit quad,} 
if {[N i 16 > 0x0]} {emit {%d Hz}}
} 204 {emit {386 compact demand paged pure executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N c 32 == 0x6a]} {emit {\(uses shared libs\)}}
} 263 {emit {386 executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N c 32 == 0x6a]} {emit {\(uses shared libs\)}}
} 264 {emit {386 pure executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N c 32 == 0x6a]} {emit {\(uses shared libs\)}}
} 267 {emit {386 demand paged pure executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N c 32 == 0x6a]} {emit {\(uses shared libs\)}}
} 324508366 {emit {GNU dbm 1.x or ndbm database, little endian}} 340322 {emit {Berkeley DB 1.85/1.86}
if {[N i 4 > 0x0]} {emit {\(Btree, version %d, little-endian\)}}
} -109248628 {emit {SE Linux policy}
if {[N i 16 x {}]} {emit v%d}
if {[N i 20 == 0x1]} {emit MLS}
if {[N i 24 x {}]} {emit {%d symbols}}
if {[N i 28 x {}]} {emit {%d ocons}}
} 453186358 {emit {Netboot image,}
if {[N i 4 == 0x0 &0xFFFFFF00]} {switch -- [Nv i 4 &0x100] 0 {emit {mode 2}} 256 {emit {mode 3}} 
}
if {[N i 4 != 0x0 &0xFFFFFF00]} {emit {unknown mode}}
} 684539205 {emit {Linux Compressed ROM File System data, little endian}
if {[N i 4 x {}]} {emit {size %d}}
if {[N i 8 & 0x1]} {emit {version \#2}}
if {[N i 8 & 0x2]} {emit sorted_dirs}
if {[N i 8 & 0x4]} {emit hole_support}
if {[N i 32 x {}]} {emit {CRC 0x%x,}}
if {[N i 36 x {}]} {emit {edition %d,}}
if {[N i 40 x {}]} {emit {%d blocks,}}
if {[N i 44 x {}]} {emit {%d files}}
} 876099889 {emit {Linux Journalled Flash File system, little endian}} -536798843 {emit {Linux jffs2 filesystem data little endian}} 4 {emit {X11 SNF font data, LSB first}} 1279543401 {emit {ld.so hints file \(Little Endian}
if {[N i 4 > 0x0]} {emit {\b, version %d\)}}
if {[N I 4 <= 0x0]} {emit {\b\)}}
} 1638399 {emit {GEM Metafile data}
if {[N s 4 x {}]} {emit {version %d}}
} 987654321 {emit {DCX multi-page PCX image data}} -681629056 {emit {Cineon image data}
if {[N I 200 > 0x0]} {emit {\b, %ld x}}
if {[N I 204 > 0x0]} {emit %ld}
} 20000630 {emit {OpenEXR image data}} 6553863 {emit {Linux/i386 impure executable \(OMAGIC\)}
if {[N i 16 == 0x0]} {emit {\b, stripped}}
} 6553864 {emit {Linux/i386 pure executable \(NMAGIC\)}
if {[N i 16 == 0x0]} {emit {\b, stripped}}
} 6553867 {emit {Linux/i386 demand-paged executable \(ZMAGIC\)}
if {[N i 16 == 0x0]} {emit {\b, stripped}}
} 6553804 {emit {Linux/i386 demand-paged executable \(QMAGIC\)}
if {[N i 16 == 0x0]} {emit {\b, stripped}}
} 336851773 {emit {SYSLINUX' LSS16 image data}
if {[N s 4 x {}]} {emit {\b, width %d}}
if {[N s 6 x {}]} {emit {\b, height %d}}
} -249691108 {emit {magic binary file for file\(1\) cmd}
if {[N i 4 x {}]} {emit {\(version %d\) \(little endian\)}}
} 574529400 {emit {Transport Neutral Encapsulation Format}} -21555 {emit {MLSSA datafile,}
if {[N s 4 x {}]} {emit {algorithm %d,}}
if {[N i 10 x {}]} {emit {%d samples}}
} 134769520 {emit {TurboC BGI file}} 134761296 {emit {TurboC Font file}} 76 {emit {}
if {[N i 4 == 0x21401]} {emit {Windows shortcut file}}
} 1313096225 {emit {Microsoft Outlook binary email folder}} 220991 {emit {Windows 3.x help file}} 263 {emit {a.out NetBSD little-endian object file}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 459141 {emit {ECOFF NetBSD/alpha binary}
switch -- [Nv s 10] 1 {emit {not stripped}} 0 {emit stripped} 
} 33645 {emit {PDP-11 single precision APL workspace}} 33644 {emit {PDP-11 double precision APL workspace}} 268435511 {emit {Psion Series 5}
switch -- [Nv i 4] 268435513 {emit {font file}} 268435514 {emit {printer driver}} 268435515 {emit clipboard} 268435522 {emit {multi-bitmap image}} 268435562 {emit {application infomation file}} 268435565 {emit {}
switch -- [Nv i 8] 268435581 {emit {sketch image}} 268435582 {emit {voice note}} 268435583 {emit {word file}} 268435589 {emit {OPL program}} 268435592 {emit {sheet file}} 268435908 {emit {EasyFax initialisation file}} 
} 268435571 {emit {OPO module}} 268435572 {emit {OPL application}} 268435594 {emit {exported multi-bitmap image}} 
} 268435521 {emit {Psion Series 5 ROM multi-bitmap image}} 268435536 {emit {Psion Series 5}
switch -- [Nv i 4] 268435565 {emit database} 268435684 {emit {ini file}} 
} 268435577 {emit {Psion Series 5 binary:}
switch -- [Nv i 4] 0 {emit DLL} 268435529 {emit {comms hardware library}} 268435530 {emit {comms protocol library}} 268435549 {emit OPX} 268435564 {emit application} 268435597 {emit DLL} 268435628 {emit {logical device driver}} 268435629 {emit {physical device driver}} 268435685 {emit {file transfer protocol}} 268435685 {emit {file transfer protocol}} 268435776 {emit {printer defintion}} 268435777 {emit {printer defintion}} 
} 268435578 {emit {Psion Series 5 executable}} 234 {emit {BALANCE NS32000 .o}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N i 124 > 0x0]} {emit {version %ld}}
} 4330 {emit {BALANCE NS32000 executable \(0 @ 0\)}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N i 124 > 0x0]} {emit {version %ld}}
} 8426 {emit {BALANCE NS32000 executable \(invalid @ 0\)}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N i 124 > 0x0]} {emit {version %ld}}
} 12522 {emit {BALANCE NS32000 standalone executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N i 124 > 0x0]} {emit {version %ld}}
} 320013059 {emit {SpeedShop data file}} 16922978 {emit {mdbm file, version 0 \(obsolete\)}} -1582119980 {emit {tcpdump capture file \(little-endian\)}
if {[N s 4 x {}]} {emit {- version %d}}
if {[N s 6 x {}]} {emit {\b.%d}}
switch -- [Nv i 20] 0 {emit {\(No link-layer encapsulation}} 1 {emit {\(Ethernet}} 2 {emit {\(3Mb Ethernet}} 3 {emit {\(AX.25}} 4 {emit {\(ProNET}} 5 {emit {\(CHAOS}} 6 {emit {\(Token Ring}} 7 {emit {\(ARCNET}} 8 {emit {\(SLIP}} 9 {emit {\(PPP}} 10 {emit {\(FDDI}} 11 {emit {\(RFC 1483 ATM}} 12 {emit {\(raw IP}} 13 {emit {\(BSD/OS SLIP}} 14 {emit {\(BSD/OS PPP}} 19 {emit {\(Linux ATM Classical IP}} 50 {emit {\(PPP or Cisco HDLC}} 51 {emit {\(PPP-over-Ethernet}} 99 {emit {\(Symantec Enterprise Firewall}} 100 {emit {\(RFC 1483 ATM}} 101 {emit {\(raw IP}} 102 {emit {\(BSD/OS SLIP}} 103 {emit {\(BSD/OS PPP}} 104 {emit {\(BSD/OS Cisco HDLC}} 105 {emit {\(802.11}} 106 {emit {\(Linux Classical IP over ATM}} 107 {emit {\(Frame Relay}} 108 {emit {\(OpenBSD loopback}} 109 {emit {\(OpenBSD IPsec encrypted}} 112 {emit {\(Cisco HDLC}} 113 {emit {\(Linux \"cooked\"}} 114 {emit {\(LocalTalk}} 117 {emit {\(OpenBSD PFLOG}} 119 {emit {\(802.11 with Prism header}} 122 {emit {\(RFC 2625 IP over Fibre Channel}} 123 {emit {\(SunATM}} 127 {emit {\(802.11 with radiotap header}} 129 {emit {\(Linux ARCNET}} 138 {emit {\(Apple IP over IEEE 1394}} 140 {emit {\(MTP2}} 141 {emit {\(MTP3}} 143 {emit {\(DOCSIS}} 144 {emit {\(IrDA}} 147 {emit {\(Private use 0}} 148 {emit {\(Private use 1}} 149 {emit {\(Private use 2}} 150 {emit {\(Private use 3}} 151 {emit {\(Private use 4}} 152 {emit {\(Private use 5}} 153 {emit {\(Private use 6}} 154 {emit {\(Private use 7}} 155 {emit {\(Private use 8}} 156 {emit {\(Private use 9}} 157 {emit {\(Private use 10}} 158 {emit {\(Private use 11}} 159 {emit {\(Private use 12}} 160 {emit {\(Private use 13}} 161 {emit {\(Private use 14}} 162 {emit {\(Private use 15}} 163 {emit {\(802.11 with AVS header}} 
if {[N i 16 x {}]} {emit {\b, capture length %d\)}}
} -1582117580 {emit {extended tcpdump capture file \(little-endian\)}
if {[N s 4 x {}]} {emit {- version %d}}
if {[N s 6 x {}]} {emit {\b.%d}}
switch -- [Nv i 20] 0 {emit {\(No link-layer encapsulation}} 1 {emit {\(Ethernet}} 2 {emit {\(3Mb Ethernet}} 3 {emit {\(AX.25}} 4 {emit {\(ProNET}} 5 {emit {\(CHAOS}} 6 {emit {\(Token Ring}} 7 {emit {\(ARCNET}} 8 {emit {\(SLIP}} 9 {emit {\(PPP}} 10 {emit {\(FDDI}} 11 {emit {\(RFC 1483 ATM}} 12 {emit {\(raw IP}} 13 {emit {\(BSD/OS SLIP}} 14 {emit {\(BSD/OS PPP}} 
if {[N i 16 x {}]} {emit {\b, capture length %d\)}}
} 33647 {emit {VAX single precision APL workspace}} 33646 {emit {VAX double precision APL workspace}} 263 {emit {VAX executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 264 {emit {VAX pure executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 267 {emit {VAX demand paged pure executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 272 {emit {VAX demand paged \(first page unmapped\) pure executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 518 {emit b.out
if {[N s 30 & 0x10]} {emit overlay}
if {[N s 30 & 0x2]} {emit separate}
if {[N s 30 & 0x4]} {emit pure}
if {[N s 30 & 0x800]} {emit segmented}
if {[N s 30 & 0x400]} {emit standalone}
if {[N s 30 & 0x1]} {emit executable}
if {[N s 30 ^ 0x1]} {emit {object file}}
if {[N s 30 & 0x4000]} {emit V2.3}
if {[N s 30 & 0x8000]} {emit V3.0}
if {[N c 28 & 0x4]} {emit 86}
if {[N c 28 & 0xb]} {emit 186}
if {[N c 28 & 0x9]} {emit 286}
if {[N c 28 & 0x29]} {emit 286}
if {[N c 28 & 0xa]} {emit 386}
if {[N s 30 & 0x4]} {emit {Large Text}}
if {[N s 30 & 0x2]} {emit {Large Data}}
if {[N s 30 & 0x102]} {emit {Huge Objects Enabled}}
} 
if {[N i 16 == 0xef000011]} {emit {RISC OS AIF executable}}
if {[S 0 == Draw]} {emit {RISC OS Draw file data}}
if {[S 0 == {FONT\0}]} {emit {RISC OS outline font data,}
if {[N c 5 x {}]} {emit {version %d}}
}
if {[S 0 == {FONT\1}]} {emit {RISC OS 1bpp font data,}
if {[N c 5 x {}]} {emit {version %d}}
}
if {[S 0 == {FONT\4}]} {emit {RISC OS 4bpp font data}
if {[N c 5 x {}]} {emit {version %d}}
}
if {[S 0 == {Maestro\r}]} {emit {RISC OS music file}
if {[N c 8 x {}]} {emit {version %d}}
}
switch -- [Nv s 0] 21020 {emit {COFF DSP21k}
if {[N i 18 & 0x2]} {emit executable,}
if {[N i 18 ^ 0x2]} {if {[N i 18 & 0x1]} {emit {static object,}}
if {[N i 18 ^ 0x1]} {emit {relocatable object,}}
}
if {[N i 18 & 0x8]} {emit stripped}
if {[N i 18 ^ 0x8]} {emit {not stripped}}
} 387 {emit {COFF format alpha}
if {[N s 22 != 0x2000 &030000]} {emit executable}
switch -- [Nv s 24] 264 {emit pure} 267 {emit paged} 263 {emit object} 
if {[N s 22 != 0x0 &020000]} {emit {dynamically linked}}
if {[N i 16 != 0x0]} {emit {not stripped}}
if {[N i 16 == 0x0]} {emit stripped}
if {[N s 22 == 0x2000 &030000]} {emit {shared library}}
if {[N c 27 x {}]} {emit {- version %d}}
if {[N c 26 x {}]} {emit .%d}
if {[N c 28 x {}]} {emit -%d}
} -147 {emit {very old PDP-11 archive}} -155 {emit {old PDP-11 archive}
if {[S 8 == __.SYMDEF]} {emit {random library}}
} -5536 {emit {ARJ archive data}
if {[N c 5 x {}]} {emit {\b, v%d,}}
if {[N c 8 & 0x4]} {emit multi-volume,}
if {[N c 8 & 0x10]} {emit slash-switched,}
if {[N c 8 & 0x20]} {emit backup,}
if {[S 34 x {}]} {emit {original name: %s,}}
switch -- [Nv c 7] 0 {emit {os: MS-DOS}} 1 {emit {os: PRIMOS}} 2 {emit {os: Unix}} 3 {emit {os: Amiga}} 4 {emit {os: Macintosh}} 5 {emit {os: OS/2}} 6 {emit {os: Apple ][ GS}} 7 {emit {os: Atari ST}} 8 {emit {os: NeXT}} 9 {emit {os: VAX/VMS}} 
if {[N c 3 > 0x0]} {emit %d\]}
} -5247 {emit {PRCS packaged project}} 387 {emit {COFF format alpha}
if {[N s 22 & 0x1000 &020000]} {emit {sharable library,}}
if {[N s 22 ^ 0x1000 &020000]} {emit {dynamically linked,}}
switch -- [Nv s 24] 264 {emit pure} 267 {emit {demand paged}} 
if {[N i 8 > 0x0]} {emit {executable or object module, not stripped}}
if {[N i 8 == 0x0]} {if {[N i 12 == 0x0]} {emit {executable or object module, stripped}}
if {[N i 12 > 0x0]} {emit {executable or object module, not stripped}}
}
if {[N c 27 > 0x0]} {emit {- version %d.}}
if {[N c 26 > 0x0]} {emit %d-}
if {[N s 28 > 0x0]} {emit %d}
} 392 {emit {Alpha compressed COFF}} 399 {emit {Alpha u-code object}} 6532 {emit {Linux old jffs2 filesystem data little endian}} 1360 {emit {Hitachi SH little-endian COFF}
switch -- [Nv s 18 &0x0002] 0 {emit object} 2 {emit executable} 
switch -- [Nv s 18 &0x0008] 8 {emit {\b, stripped}} 0 {emit {\b, not stripped}} 
} -13230 {emit {RLE image data,}
if {[N s 6 x {}]} {emit {%d x}}
if {[N s 8 x {}]} {emit %d}
if {[N s 2 > 0x0]} {emit {\b, lower left corner: %d}}
if {[N s 4 > 0x0]} {emit {\b, lower right corner: %d}}
if {[N c 10 == 0x1 &0x1]} {emit {\b, clear first}}
if {[N c 10 == 0x2 &0x2]} {emit {\b, no background}}
if {[N c 10 == 0x4 &0x4]} {emit {\b, alpha channel}}
if {[N c 10 == 0x8 &0x8]} {emit {\b, comment}}
if {[N c 11 > 0x0]} {emit {\b, %d color channels}}
if {[N c 12 > 0x0]} {emit {\b, %d bits per pixel}}
if {[N c 13 > 0x0]} {emit {\b, %d color map channels}}
} 322 {emit {basic-16 executable}
if {[N i 12 > 0x0]} {emit {not stripped}}
} 323 {emit {basic-16 executable \(TV\)}
if {[N i 12 > 0x0]} {emit {not stripped}}
} 328 {emit {x86 executable}
if {[N i 12 > 0x0]} {emit {not stripped}}
} 329 {emit {x86 executable \(TV\)}
if {[N i 12 > 0x0]} {emit {not stripped}}
} 330 {emit {iAPX 286 executable small model \(COFF\)}
if {[N i 12 > 0x0]} {emit {not stripped}}
} 338 {emit {iAPX 286 executable large model \(COFF\)}
if {[N i 12 > 0x0]} {emit {not stripped}}
} 332 {emit {80386 COFF executable}
if {[N i 12 > 0x0]} {emit {not stripped}}
if {[N s 22 > 0x0]} {emit {- version %ld}}
} 1078 {emit {Linux/i386 PC Screen Font data,}
switch -- [Nv c 2] 0 {emit {256 characters, no directory,}} 1 {emit {512 characters, no directory,}} 2 {emit {256 characters, Unicode directory,}} 3 {emit {512 characters, Unicode directory,}} 
if {[N c 3 > 0x0]} {emit 8x%d}
} 387 {emit {ECOFF alpha}
switch -- [Nv s 24] 263 {emit executable} 264 {emit pure} 267 {emit {demand paged}} 
if {[N Q 8 > 0x0]} {emit {not stripped}}
if {[N Q 8 == 0x0]} {emit stripped}
if {[N s 23 > 0x0]} {emit {- version %ld.}}
} 332 {emit {MS Windows COFF Intel 80386 object file}} 358 {emit {MS Windows COFF MIPS R4000 object file}} 388 {emit {MS Windows COFF Alpha object file}} 616 {emit {MS Windows COFF Motorola 68000 object file}} 496 {emit {MS Windows COFF PowerPC object file}} 656 {emit {MS Windows COFF PA-RISC object file}} 6 {emit {DBase 3 index file}} -24712 {emit TNEF} 263 {emit {PDP-11 executable}
if {[N s 8 > 0x0]} {emit {not stripped}}
if {[N c 15 > 0x0]} {emit {- version %ld}}
} 257 {emit {PDP-11 UNIX/RT ldp}} 261 {emit {PDP-11 old overlay}} 264 {emit {PDP-11 pure executable}
if {[N s 8 > 0x0]} {emit {not stripped}}
if {[N c 15 > 0x0]} {emit {- version %ld}}
} 265 {emit {PDP-11 separate I&D executable}
if {[N s 8 > 0x0]} {emit {not stripped}}
if {[N c 15 > 0x0]} {emit {- version %ld}}
} 287 {emit {PDP-11 kernel overlay}} 267 {emit {PDP-11 demand-paged pure executable}
if {[N s 8 > 0x0]} {emit {not stripped}}
} 280 {emit {PDP-11 overlaid pure executable}
if {[N s 8 > 0x0]} {emit {not stripped}}
} 281 {emit {PDP-11 overlaid separate executable}
if {[N s 8 > 0x0]} {emit {not stripped}}
} 4843 {emit {SYMMETRY i386 .o}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N i 124 > 0x0]} {emit {version %ld}}
} 8939 {emit {SYMMETRY i386 executable \(0 @ 0\)}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N i 124 > 0x0]} {emit {version %ld}}
} 13035 {emit {SYMMETRY i386 executable \(invalid @ 0\)}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N i 124 > 0x0]} {emit {version %ld}}
} 17131 {emit {SYMMETRY i386 standalone executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
if {[N i 124 > 0x0]} {emit {version %ld}}
} 21020 {emit {SHARC COFF binary}
if {[N s 2 > 0x1]} {emit {, %hd sections}
if {[N i 12 > 0x0]} {emit {, not stripped}}
}
} 4097 {emit {LANalyzer capture file}} 4103 {emit {LANalyzer capture file}} 376 {emit {VAX COFF executable}
if {[N i 12 > 0x0]} {emit {not stripped}}
if {[N s 22 > 0x0]} {emit {- version %ld}}
} 381 {emit {VAX COFF pure executable}
if {[N i 12 > 0x0]} {emit {not stripped}}
if {[N s 22 > 0x0]} {emit {- version %ld}}
} -155 {emit x.out
if {[S 2 == __.SYMDEF]} {emit randomized}
if {[N c 0 x {}]} {emit archive}
} 518 {emit {Microsoft a.out}
if {[N s 8 == 0x1]} {emit {Middle model}}
if {[N s 30 & 0x10]} {emit overlay}
if {[N s 30 & 0x2]} {emit separate}
if {[N s 30 & 0x4]} {emit pure}
if {[N s 30 & 0x800]} {emit segmented}
if {[N s 30 & 0x400]} {emit standalone}
if {[N s 30 & 0x8]} {emit fixed-stack}
if {[N c 28 & 0x80]} {emit byte-swapped}
if {[N c 28 & 0x40]} {emit word-swapped}
if {[N i 16 > 0x0]} {emit not-stripped}
if {[N s 30 ^ 0xc000]} {emit pre-SysV}
if {[N s 30 & 0x4000]} {emit V2.3}
if {[N s 30 & 0x8000]} {emit V3.0}
if {[N c 28 & 0x4]} {emit 86}
if {[N c 28 & 0xb]} {emit 186}
if {[N c 28 & 0x9]} {emit 286}
if {[N c 28 & 0xa]} {emit 386}
if {[N c 31 < 0x40]} {emit {small model}}
switch -- [Nv c 31] 72 {emit {large model	}} 73 {emit {huge model}} 
if {[N s 30 & 0x1]} {emit executable}
if {[N s 30 ^ 0x1]} {emit {object file}}
if {[N s 30 & 0x40]} {emit {Large Text}}
if {[N s 30 & 0x20]} {emit {Large Data}}
if {[N s 30 & 0x120]} {emit {Huge Objects Enabled}}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 320 {emit {old Microsoft 8086 x.out}
if {[N c 3 & 0x4]} {emit separate}
if {[N c 3 & 0x2]} {emit pure}
if {[N c 0 & 0x1]} {emit executable}
if {[N c 0 ^ 0x1]} {emit relocatable}
if {[N i 20 > 0x0]} {emit {not stripped}}
} 1408 {emit {XENIX 8086 relocatable or 80286 small model}} 
switch -- [Nv Y 0] 381 {emit {CLIPPER COFF executable \(VAX \#\)}
switch -- [Nv Y 20] 263 {emit {\(impure\)}} 264 {emit {\(5.2 compatible\)}} 265 {emit {\(pure\)}} 267 {emit {\(demand paged\)}} 291 {emit {\(target shared library\)}} 
if {[N Q 12 > 0x0]} {emit {not stripped}}
if {[N Y 22 > 0x0]} {emit {- version %ld}}
} 383 {emit {CLIPPER COFF executable}
switch -- [Nv Y 18 &074000] 0 {emit {C1 R1}} 2048 {emit {C2 R1}} 4096 {emit {C3 R1}} 30720 {emit TEST} 
switch -- [Nv Y 20] 263 {emit {\(impure\)}} 264 {emit {\(pure\)}} 265 {emit {\(separate I&D\)}} 267 {emit {\(paged\)}} 291 {emit {\(target shared library\)}} 
if {[N Q 12 > 0x0]} {emit {not stripped}}
if {[N Y 22 > 0x0]} {emit {- version %ld}}
if {[N Q 48 == 0x1 &01]} {emit {alignment trap enabled}}
switch -- [Nv c 52] 1 {emit -Ctnc} 2 {emit -Ctsw} 3 {emit -Ctpw} 4 {emit -Ctcb} 
switch -- [Nv c 53] 1 {emit -Cdnc} 2 {emit -Cdsw} 3 {emit -Cdpw} 4 {emit -Cdcb} 
switch -- [Nv c 54] 1 {emit -Csnc} 2 {emit -Cssw} 3 {emit -Cspw} 4 {emit -Cscb} 
} 272 {emit {0420 Alliant virtual executable}
if {[N Y 2 & 0x20]} {emit {common library}}
if {[N Q 16 > 0x0]} {emit {not stripped}}
} 273 {emit {0421 Alliant compact executable}
if {[N Y 2 & 0x20]} {emit {common library}}
if {[N Q 16 > 0x0]} {emit {not stripped}}
} 29127 {emit {cpio archive}} -14479 {emit {byte-swapped cpio archive}} -147 {emit {very old PDP-11 archive}} -155 {emit {old PDP-11 archive}} 1793 {emit {VAX-order 68K Blit \(standalone\) executable}} 262 {emit {VAX-order2 68k Blit mpx/mux executable}} 1537 {emit {VAX-order 68k Blit mpx/mux executable}} 7967 {emit {old packed data}} 8191 {emit {compacted data}} -13563 {emit {huf output}} 1281 {emit {locale data table}
switch -- [Nv Y 6] 36 {emit {for MIPS}} 64 {emit {for Alpha}} 
} 340 {emit Encore
switch -- [Nv Y 20] 263 {emit executable} 264 {emit {pure executable}} 267 {emit {demand-paged executable}} 271 {emit {unsupported executable}} 
if {[N Q 12 > 0x0]} {emit {not stripped}}
if {[N Y 22 > 0x0]} {emit {- version %ld}}
if {[N Y 22 == 0x0]} {emit -}
} 341 {emit {Encore unsupported executable}
if {[N Q 12 > 0x0]} {emit {not stripped}}
if {[N Y 22 > 0x0]} {emit {- version %ld}}
if {[N Y 22 == 0x0]} {emit -}
} 286 {emit {Berkeley vfont data}} 7681 {emit {byte-swapped Berkeley vfont data}} 256 {emit {raw G3 data, byte-padded}} 5120 {emit {raw G3 data}} 373 {emit {i386 COFF object}} 10775 {emit {\"compact bitmap\" format \(Poskanzer\)}} 601 {emit {mumps avl global}
if {[N c 2 > 0x0]} {emit {\(V%d\)}}
if {[N c 6 > 0x0]} {emit {with %d byte name}}
if {[N c 7 > 0x0]} {emit {and %d byte data cells}}
} 602 {emit {mumps blt global}
if {[N c 2 > 0x0]} {emit {\(V%d\)}}
if {[N Y 8 > 0x0]} {emit {- %d byte blocks}}
switch -- [Nv c 15] 0 {emit {- P/D format}} 1 {emit {- P/K/D format}} 2 {emit {- K/D format}} 
if {[N c 15 > 0x2]} {emit {- Bad Flags}}
} 10012 {emit {Sendmail frozen configuration}
if {[S 16 x {}]} {emit {- version %s}}
} -16162 {emit {Compiled PSI \(v1\) data}} -16166 {emit {Compiled PSI \(v2\) data}
if {[S 3 x {}]} {emit {\(%s\)}}
} -21846 {emit {SoftQuad DESC or font file binary}
if {[N Y 2 > 0x0]} {emit {- version %d}}
} 283 {emit {Curses screen image}} 284 {emit {Curses screen image}} 263 {emit {unknown machine executable}
if {[N Y 8 > 0x0]} {emit {not stripped}}
if {[N c 15 > 0x0]} {emit {- version %ld}}
} 264 {emit {unknown pure executable}
if {[N Y 8 > 0x0]} {emit {not stripped}}
if {[N c 15 > 0x0]} {emit {- version %ld}}
} 265 {emit {PDP-11 separate I&D}
if {[N Y 8 > 0x0]} {emit {not stripped}}
if {[N c 15 > 0x0]} {emit {- version %ld}}
} 267 {emit {unknown pure executable}
if {[N Y 8 > 0x0]} {emit {not stripped}}
if {[N c 15 > 0x0]} {emit {- version %ld}}
} 392 {emit {Perkin-Elmer executable}} 21845 {emit {VISX image file}
switch -- [Nv c 2] 0 {emit {\(zero\)}} 1 {emit {\(unsigned char\)}} 2 {emit {\(short integer\)}} 3 {emit {\(float 32\)}} 4 {emit {\(float 64\)}} 5 {emit {\(signed char\)}} 6 {emit {\(bit-plane\)}} 7 {emit {\(classes\)}} 8 {emit {\(statistics\)}} 10 {emit {\(ascii text\)}} 15 {emit {\(image segments\)}} 100 {emit {\(image set\)}} 101 {emit {\(unsigned char vector\)}} 102 {emit {\(short integer vector\)}} 103 {emit {\(float 32 vector\)}} 104 {emit {\(float 64 vector\)}} 105 {emit {\(signed char vector\)}} 106 {emit {\(bit plane vector\)}} 121 {emit {\(feature vector\)}} 122 {emit {\(feature vector library\)}} 124 {emit {\(chain code\)}} 126 {emit {\(bit vector\)}} -126 {emit {\(graph\)}} -125 {emit {\(adjacency graph\)}} -124 {emit {\(adjacency graph library\)}} 
if {[S 2 == .VISIX]} {emit {\(ascii text\)}}
} 
if {[S 4 == pipe]} {emit {CLIPPER instruction trace}}
if {[S 4 == prof]} {emit {CLIPPER instruction profile}}
switch -- [Nv I 0] 1936484385 {emit {Allegro datafile \(packed\)}} 1936484398 {emit {Allegro datafile \(not packed/autodetect\)}} 1936484395 {emit {Allegro datafile \(appended exe data\)}} 1018 {emit {AmigaOS shared library}} 1011 {emit {AmigaOS loadseg\(\)ble executable/binary}} 999 {emit {AmigaOS object/library data}} -2147479551 {emit {AmigaOS outline tag}} 1 {emit {JVT NAL sequence}
if {[N c 4 == 0x7 &0x1F]} {emit {\b, H.264 video}
switch -- [Nv c 5] 66 {emit {\b, baseline}} 77 {emit {\b, main}} 88 {emit {\b, extended}} 
if {[N c 7 x {}]} {emit {\b @ L %u}}
}
} 807842421 {emit {Microsoft ASF}} 333312 {emit {AppleSingle encoded Macintosh file}} 333319 {emit {AppleDouble encoded Macintosh file}} 1711210496 {emit {VAX 3.0 archive}} 1013019198 {emit {VAX 5.0 archive}} 1314148939 {emit {MultiTrack sound data}
if {[N I 4 x {}]} {emit {- version %ld}}
} 779248125 {emit {RealAudio sound file}} 1688404224 {emit {IRCAM file \(VAX\)}} 1688404480 {emit {IRCAM file \(Sun\)}} 1688404736 {emit {IRCAM file \(MIPS little-endian\)}} 1688404992 {emit {IRCAM file \(NeXT\)}} 1125466468 {emit {X64 Image}} -12432129 {emit {WRAptor packer \(c64\)}} 554074152 {emit {Sega Dreamcast VMU game image}} 931151890 {emit {V64 Nintendo 64 ROM dump}} 327 {emit {Convex old-style object}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 331 {emit {Convex old-style demand paged executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 333 {emit {Convex old-style pre-paged executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 335 {emit {Convex old-style pre-paged, non-swapped executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 70231 {emit {Core file}} 385 {emit {Convex SOFF}
if {[N I 88 == 0x0 &0x000f0000]} {emit c1}
if {[N I 88 & 0x10000]} {emit c2}
if {[N I 88 & 0x20000]} {emit c2mp}
if {[N I 88 & 0x40000]} {emit parallel}
if {[N I 88 & 0x80000]} {emit intrinsic}
if {[N I 88 & 0x1]} {emit {demand paged}}
if {[N I 88 & 0x2]} {emit pre-paged}
if {[N I 88 & 0x4]} {emit non-swapped}
if {[N I 88 & 0x8]} {emit POSIX}
if {[N I 84 & 0x80000000]} {emit executable}
if {[N I 84 & 0x40000000]} {emit object}
if {[N I 84 == 0x0 &0x20000000]} {emit {not stripped}}
switch -- [Nv I 84 &0x18000000] 0 {emit {native fpmode}} 268435456 {emit {ieee fpmode}} 402653184 {emit {undefined fpmode}} 
} 389 {emit {Convex SOFF core}} 391 {emit {Convex SOFF checkpoint}
if {[N I 88 == 0x0 &0x000f0000]} {emit c1}
if {[N I 88 & 0x10000]} {emit c2}
if {[N I 88 & 0x20000]} {emit c2mp}
if {[N I 88 & 0x40000]} {emit parallel}
if {[N I 88 & 0x80000]} {emit intrinsic}
if {[N I 88 & 0x8]} {emit POSIX}
switch -- [Nv I 84 &0x18000000] 0 {emit {native fpmode}} 268435456 {emit {ieee fpmode}} 402653184 {emit {undefined fpmode}} 
} 324508366 {emit {GNU dbm 1.x or ndbm database, big endian}} 398689 {emit {Berkeley DB}
switch -- [Nv I 8] 4321 {emit {}
if {[N I 4 > 0x2]} {emit 1.86}
if {[N I 4 < 0x3]} {emit 1.85}
if {[N I 4 > 0x0]} {emit {\(Hash, version %d, big-endian\)}}
} 1234 {emit {}
if {[N I 4 > 0x2]} {emit 1.86}
if {[N I 4 < 0x3]} {emit 1.85}
if {[N I 4 > 0x0]} {emit {\(Hash, version %d, native byte-order\)}}
} 
} 340322 {emit {Berkeley DB 1.85/1.86}
if {[N I 4 > 0x0]} {emit {\(Btree, version %d, big-endian\)}}
} 9994 {emit {ESRI Shapefile}
if {[N I 4 == 0x0]} {emit 16 34 0}
if {[N I 8 == 0x0]} {emit 16 34 1}
if {[N I 12 == 0x0]} {emit 16 34 2}
if {[N I 16 == 0x0]} {emit 16 34 3}
if {[N I 20 == 0x0]} {emit 16 34 4}
if {[N i 28 x {}]} {emit {version %d}}
if {[N I 24 x {}]} {emit {length %d}}
switch -- [Nv i 32] 0 {emit {type Null Shape}} 1 {emit {type Point}} 3 {emit {type PolyLine}} 5 {emit {type Polygon}} 8 {emit {type MultiPoint}} 11 {emit {type PointZ}} 13 {emit {type PolyLineZ}} 15 {emit {type PolygonZ}} 18 {emit {type MultiPointZ}} 21 {emit {type PointM}} 23 {emit {type PolyLineM}} 25 {emit {type PolygonM}} 28 {emit {type MultiPointM}} 31 {emit {type MultiPatch}} 
} 199600449 {emit {SGI disk label \(volume header\)}} 1481003842 {emit {SGI XFS filesystem data}
if {[N I 4 x {}]} {emit {\(blksz %d,}}
if {[N S 104 x {}]} {emit {inosz %d,}}
if {[N S 100 ^ 0x2004]} {emit {v1 dirs\)}}
if {[N S 100 & 0x2004]} {emit {v2 dirs\)}}
} 684539205 {emit {Linux Compressed ROM File System data, big endian}
if {[N I 4 x {}]} {emit {size %d}}
if {[N I 8 & 0x1]} {emit {version \#2}}
if {[N I 8 & 0x2]} {emit sorted_dirs}
if {[N I 8 & 0x4]} {emit hole_support}
if {[N I 32 x {}]} {emit {CRC 0x%x,}}
if {[N I 36 x {}]} {emit {edition %d,}}
if {[N I 40 x {}]} {emit {%d blocks,}}
if {[N I 44 x {}]} {emit {%d files}}
} 876099889 {emit {Linux Journalled Flash File system, big endian}} 654645590 {emit {PPCBoot image}
if {[S 4 == PPCBoot]} {if {[S 12 x {}]} {emit {version %s}}
}
} 4 {emit {X11 SNF font data, MSB first}} 335698201 {emit {libGrx font data,}
if {[N s 8 x {}]} {emit %dx}
if {[N s 10 x {}]} {emit {\b%d}}
if {[S 40 x {}]} {emit %s}
} -12169394 {emit {DOS code page font data collection}} 1279543401 {emit {ld.so hints file \(Big Endian}
if {[N I 4 > 0x0]} {emit {\b, version %d\)}}
if {[N I 4 <= 0x0]} {emit {\b\)}}
} -951729837 {emit GEOS
switch -- [Nv c 40] 1 {emit executable} 2 {emit VMFile} 3 {emit binary} 4 {emit {directory label}} 
if {[N c 40 < 0x1]} {emit unknown}
if {[N c 40 > 0x4]} {emit unknown}
if {[S 4 x {}]} {emit {\b, name \"%s\"}}
} 235082497 {emit {Hierarchical Data Format \(version 4\) data}} 34603270 {emit {PA-RISC1.1 relocatable object}} 34603271 {emit {PA-RISC1.1 executable}
if {[N I 168 & 0x4]} {emit {dynamically linked}}
if {[N I [I 144 Q 0] == 0x54ef630]} {emit {dynamically linked}}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34603272 {emit {PA-RISC1.1 shared executable}
if {[N I 168 == 0x4 &0x4]} {emit {dynamically linked}}
if {[N I [I 144 Q 0] == 0x54ef630]} {emit {dynamically linked}}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34603275 {emit {PA-RISC1.1 demand-load executable}
if {[N I 168 == 0x4 &0x4]} {emit {dynamically linked}}
if {[N I [I 144 Q 0] == 0x54ef630]} {emit {dynamically linked}}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34603278 {emit {PA-RISC1.1 shared library}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34603277 {emit {PA-RISC1.1 dynamic load library}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34865414 {emit {PA-RISC2.0 relocatable object}} 34865415 {emit {PA-RISC2.0 executable}
if {[N I 168 & 0x4]} {emit {dynamically linked}}
if {[N I [I 144 Q 0] == 0x54ef630]} {emit {dynamically linked}}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34865416 {emit {PA-RISC2.0 shared executable}
if {[N I 168 & 0x4]} {emit {dynamically linked}}
if {[N I [I 144 Q 0] == 0x54ef630]} {emit {dynamically linked}}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34865419 {emit {PA-RISC2.0 demand-load executable}
if {[N I 168 & 0x4]} {emit {dynamically linked}}
if {[N I [I 144 Q 0] == 0x54ef630]} {emit {dynamically linked}}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34865422 {emit {PA-RISC2.0 shared library}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34865421 {emit {PA-RISC2.0 dynamic load library}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34275590 {emit {PA-RISC1.0 relocatable object}} 34275591 {emit {PA-RISC1.0 executable}
if {[N I 168 == 0x4 &0x4]} {emit {dynamically linked}}
if {[N I [I 144 Q 0] == 0x54ef630]} {emit {dynamically linked}}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34275592 {emit {PA-RISC1.0 shared executable}
if {[N I 168 == 0x4 &0x4]} {emit {dynamically linked}}
if {[N I [I 144 Q 0] == 0x54ef630]} {emit {dynamically linked}}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34275595 {emit {PA-RISC1.0 demand-load executable}
if {[N I 168 == 0x4 &0x4]} {emit {dynamically linked}}
if {[N I [I 144 Q 0] == 0x54ef630]} {emit {dynamically linked}}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34275598 {emit {PA-RISC1.0 shared library}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 34275597 {emit {PA-RISC1.0 dynamic load library}
if {[N I 96 > 0x0]} {emit {- not stripped}}
} 557605234 {emit {archive file}
switch -- [Nv I 68] 34276889 {emit {- PA-RISC1.0 relocatable library}} 34604569 {emit {- PA-RISC1.1 relocatable library}} 34670105 {emit {- PA-RISC1.2 relocatable library}} 34866713 {emit {- PA-RISC2.0 relocatable library}} 
} 34341128 {emit {HP s200 pure executable}
if {[N S 4 > 0x0]} {emit {- version %ld}}
if {[N I 8 & 0x80000000]} {emit {save fp regs}}
if {[N I 8 & 0x40000000]} {emit {dynamically linked}}
if {[N I 8 & 0x20000000]} {emit debuggable}
if {[N I 36 > 0x0]} {emit {not stripped}}
} 34341127 {emit {HP s200 executable}
if {[N S 4 > 0x0]} {emit {- version %ld}}
if {[N I 8 & 0x80000000]} {emit {save fp regs}}
if {[N I 8 & 0x40000000]} {emit {dynamically linked}}
if {[N I 8 & 0x20000000]} {emit debuggable}
if {[N I 36 > 0x0]} {emit {not stripped}}
} 34341131 {emit {HP s200 demand-load executable}
if {[N S 4 > 0x0]} {emit {- version %ld}}
if {[N I 8 & 0x80000000]} {emit {save fp regs}}
if {[N I 8 & 0x40000000]} {emit {dynamically linked}}
if {[N I 8 & 0x20000000]} {emit debuggable}
if {[N I 36 > 0x0]} {emit {not stripped}}
} 34341126 {emit {HP s200 relocatable executable}
if {[N S 4 > 0x0]} {emit {- version %ld}}
if {[N S 6 > 0x0]} {emit {- highwater %d}}
if {[N I 8 & 0x80000000]} {emit {save fp regs}}
if {[N I 8 & 0x20000000]} {emit debuggable}
if {[N I 8 & 0x10000000]} {emit PIC}
} 34210056 {emit {HP s200 \(2.x release\) pure executable}
if {[N S 4 > 0x0]} {emit {- version %ld}}
if {[N I 36 > 0x0]} {emit {not stripped}}
} 34210055 {emit {HP s200 \(2.x release\) executable}
if {[N S 4 > 0x0]} {emit {- version %ld}}
if {[N I 36 > 0x0]} {emit {not stripped}}
} 34341134 {emit {HP s200 shared library}
if {[N S 4 > 0x0]} {emit {- version %ld}}
if {[N S 6 > 0x0]} {emit {- highwater %d}}
if {[N I 36 > 0x0]} {emit {not stripped}}
} 34341133 {emit {HP s200 dynamic load library}
if {[N S 4 > 0x0]} {emit {- version %ld}}
if {[N S 6 > 0x0]} {emit {- highwater %d}}
if {[N I 36 > 0x0]} {emit {not stripped}}
} 505 {emit {AIX compiled message catalog}} 1504078485 {emit {Sun raster image data}
if {[N I 4 > 0x0]} {emit {\b, %d x}}
if {[N I 8 > 0x0]} {emit %d,}
if {[N I 12 > 0x0]} {emit %d-bit,}
switch -- [Nv I 20] 0 {emit {old format,}} 2 {emit compressed,} 3 {emit RGB,} 4 {emit TIFF,} 5 {emit IFF,} 65535 {emit {reserved for testing,}} 
switch -- [Nv I 24] 0 {emit {no colormap}} 1 {emit {RGB colormap}} 2 {emit {raw colormap}} 
} 65544 {emit {GEM Image data}
if {[N S 12 x {}]} {emit {%d x}}
if {[N S 14 x {}]} {emit %d,}
if {[N S 4 x {}]} {emit {%d planes,}}
if {[N S 8 x {}]} {emit {%d x}}
if {[N S 10 x {}]} {emit {%d pixelsize}}
} 235082497 {emit {Hierarchical Data Format \(version 4\) data}} -889275714 {emit {compiled Java class data,}
if {[N S 6 x {}]} {emit {version %d.}}
if {[N S 4 x {}]} {emit {\b%d}}
} -1195374706 {emit {Linux kernel}
if {[S 483 == Loading]} {emit {version 1.3.79 or older}}
if {[S 489 == Loading]} {emit {from prehistoric times}}
} 1330597709 {emit {User-mode Linux COW file}
if {[N I 4 x {}]} {emit {\b, version %d}}
if {[S 8 x {}]} {emit {\b, backing file %s}}
} -1195374706 {emit Linux
if {[N I 486 == 0x454c4b53]} {emit {ELKS Kernel}}
if {[N I 486 != 0x454c4b53]} {emit {style boot sector}}
} -889275714 {emit {Mach-O fat file}
if {[N I 4 == 0x1]} {emit {with 1 architecture}}
if {[N I 4 > 0x1]} {if {[N I 4 x {}]} {emit {with %ld architectures		}}
}
} -17958194 {emit Mach-O
switch -- [Nv I 12] 1 {emit object} 2 {emit executable} 3 {emit {shared library}} 4 {emit core} 5 {emit {preload executable}} 6 {emit {dynamically linked shared library}} 7 {emit {dynamic linker}} 8 {emit bundle} 
if {[N I 12 > 0x8]} {if {[N I 12 x {}]} {emit filetype=%ld}
}
if {[N I 4 < 0x0]} {if {[N I 4 x {}]} {emit architecture=%ld}
}
switch -- [Nv I 4] 1 {emit vax} 2 {emit romp} 3 {emit architecture=3} 4 {emit ns32032} 5 {emit ns32332} 6 {emit {for m68k architecture}
switch -- [Nv I 8] 2 {emit {\(mc68040\)}} 3 {emit {\(mc68030 only\)}} 
} 7 {emit i386} 8 {emit mips} 9 {emit ns32532} 10 {emit architecture=10} 11 {emit {hp pa-risc}} 12 {emit acorn} 13 {emit m88k} 14 {emit sparc} 15 {emit i860-big} 16 {emit i860} 17 {emit rs6000} 18 {emit ppc} 
if {[N I 4 > 0x12]} {if {[N I 4 x {}]} {emit architecture=%ld}
}
} -249691108 {emit {magic binary file for file\(1\) cmd}
if {[N I 4 x {}]} {emit {\(version %d\) \(big endian\)}}
} 440786851 {emit {}
if {[N S 5 == 0x4282]} {if {[S 8 == matroska]} {emit {Matroska data}}
}
} 263 {emit {old SGI 68020 executable}} 264 {emit {old SGI 68020 pure executable}} 1396917837 {emit {IRIS Showcase file}
if {[N c 4 x {}]} {emit {- version %ld}}
} 1413695053 {emit {IRIS Showcase template}
if {[N c 4 x {}]} {emit {- version %ld}}
} -559039810 {emit {IRIX Parallel Arena}
if {[N I 8 > 0x0]} {emit {- version %ld}}
} -559043152 {emit {IRIX core dump}
if {[N I 4 == 0x1]} {emit of}
if {[S 16 x {}]} {emit '%s'}
} -559043264 {emit {IRIX 64-bit core dump}
if {[N I 4 == 0x1]} {emit of}
if {[S 16 x {}]} {emit '%s'}
} -1161903941 {emit {IRIX N32 core dump}
if {[N I 4 == 0x1]} {emit of}
if {[S 16 x {}]} {emit '%s'}
} 834535424 {emit {Microsoft Word Document}} 6656 {emit {Lotus 1-2-3}
switch -- [Nv I 4] 1049600 {emit {wk3 document data}} 34604032 {emit {wk4 document data}} 125829376 {emit {fm3 or fmb document data}} 125829120 {emit {fm3 or fmb document data}} 
} 512 {emit {Lotus 1-2-3}
switch -- [Nv I 4] 100926976 {emit {wk1 document data}} 109052416 {emit {fmt document data}} 
} -976170042 {emit {DOS EPS Binary File}
if {[N Q 4 > 0x0]} {emit {Postscript starts at byte %d}
if {[N Q 8 > 0x0]} {emit {length %d}
if {[N Q 12 > 0x0]} {emit {Metafile starts at byte %d}
if {[N Q 16 > 0x0]} {emit {length %d}}
}
if {[N Q 20 > 0x0]} {emit {TIFF starts at byte %d}
if {[N Q 24 > 0x0]} {emit {length %d}}
}
}
}
} 263 {emit {a.out NetBSD big-endian object file}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 326773060 {emit {NeWS bitmap font}} 326773063 {emit {NeWS font family}} 326773072 {emit {scalable OpenFont binary}} 326773073 {emit {encrypted scalable OpenFont binary}} 263 {emit {Plan 9 executable, Motorola 68k}} 491 {emit {Plan 9 executable, Intel 386}} 583 {emit {Plan 9 executable, Intel 960}} 683 {emit {Plan 9 executable, SPARC}} 1031 {emit {Plan 9 executable, MIPS R3000}} 1163 {emit {Plan 9 executable, AT&T DSP 3210}} 1303 {emit {Plan 9 executable, MIPS R4000 BE}} 1451 {emit {Plan 9 executable, AMD 29000}} 1607 {emit {Plan 9 executable, ARM 7-something}} 1771 {emit {Plan 9 executable, PowerPC}} 1943 {emit {Plan 9 executable, MIPS R4000 LE}} 2123 {emit {Plan 9 executable, DEC Alpha}} -976170042 {emit {DOS EPS Binary File}
if {[N Q 4 > 0x0]} {emit {Postscript starts at byte %d}
if {[N Q 8 > 0x0]} {emit {length %d}
if {[N Q 12 > 0x0]} {emit {Metafile starts at byte %d}
if {[N Q 16 > 0x0]} {emit {length %d}}
}
if {[N Q 20 > 0x0]} {emit {TIFF starts at byte %d}
if {[N Q 24 > 0x0]} {emit {length %d}}
}
}
}
} 518517022 {emit {Pulsar POP3 daemon mailbox cache file.}
if {[N I 4 x {}]} {emit {Version: %d.}}
if {[N I 8 x {}]} {emit {\b%d}}
} -1722938102 {emit {python 1.5/1.6 byte-compiled}} -2017063670 {emit {python 2.0 byte-compiled}} 720047370 {emit {python 2.1 byte-compiled}} 770510090 {emit {python 2.2 byte-compiled}} 1005718794 {emit {python 2.3 byte-compiled}} 1257963521 {emit {QL plugin-ROM data,}
if {[S 9 == {\0} p]} {emit un-named}
if {[S 9 x {} p]} {emit {named: %s}}
} -1582119980 {emit {tcpdump capture file \(big-endian\)}
if {[N S 4 x {}]} {emit {- version %d}}
if {[N S 6 x {}]} {emit {\b.%d}}
switch -- [Nv I 20] 0 {emit {\(No link-layer encapsulation}} 1 {emit {\(Ethernet}} 2 {emit {\(3Mb Ethernet}} 3 {emit {\(AX.25}} 4 {emit {\(ProNET}} 5 {emit {\(CHAOS}} 6 {emit {\(Token Ring}} 7 {emit {\(BSD ARCNET}} 8 {emit {\(SLIP}} 9 {emit {\(PPP}} 10 {emit {\(FDDI}} 11 {emit {\(RFC 1483 ATM}} 12 {emit {\(raw IP}} 13 {emit {\(BSD/OS SLIP}} 14 {emit {\(BSD/OS PPP}} 19 {emit {\(Linux ATM Classical IP}} 50 {emit {\(PPP or Cisco HDLC}} 51 {emit {\(PPP-over-Ethernet}} 99 {emit {\(Symantec Enterprise Firewall}} 100 {emit {\(RFC 1483 ATM}} 101 {emit {\(raw IP}} 102 {emit {\(BSD/OS SLIP}} 103 {emit {\(BSD/OS PPP}} 104 {emit {\(BSD/OS Cisco HDLC}} 105 {emit {\(802.11}} 106 {emit {\(Linux Classical IP over ATM}} 107 {emit {\(Frame Relay}} 108 {emit {\(OpenBSD loopback}} 109 {emit {\(OpenBSD IPsec encrypted}} 112 {emit {\(Cisco HDLC}} 113 {emit {\(Linux \"cooked\"}} 114 {emit {\(LocalTalk}} 117 {emit {\(OpenBSD PFLOG}} 119 {emit {\(802.11 with Prism header}} 122 {emit {\(RFC 2625 IP over Fibre Channel}} 123 {emit {\(SunATM}} 127 {emit {\(802.11 with radiotap header}} 129 {emit {\(Linux ARCNET}} 138 {emit {\(Apple IP over IEEE 1394}} 140 {emit {\(MTP2}} 141 {emit {\(MTP3}} 143 {emit {\(DOCSIS}} 144 {emit {\(IrDA}} 147 {emit {\(Private use 0}} 148 {emit {\(Private use 1}} 149 {emit {\(Private use 2}} 150 {emit {\(Private use 3}} 151 {emit {\(Private use 4}} 152 {emit {\(Private use 5}} 153 {emit {\(Private use 6}} 154 {emit {\(Private use 7}} 155 {emit {\(Private use 8}} 156 {emit {\(Private use 9}} 157 {emit {\(Private use 10}} 158 {emit {\(Private use 11}} 159 {emit {\(Private use 12}} 160 {emit {\(Private use 13}} 161 {emit {\(Private use 14}} 162 {emit {\(Private use 15}} 163 {emit {\(802.11 with AVS header}} 
if {[N I 16 x {}]} {emit {\b, capture length %d\)}}
} -1582117580 {emit {extended tcpdump capture file \(big-endian\)}
if {[N S 4 x {}]} {emit {- version %d}}
if {[N S 6 x {}]} {emit {\b.%d}}
switch -- [Nv I 20] 0 {emit {\(No link-layer encapsulation}} 1 {emit {\(Ethernet}} 2 {emit {\(3Mb Ethernet}} 3 {emit {\(AX.25}} 4 {emit {\(ProNET}} 5 {emit {\(CHAOS}} 6 {emit {\(Token Ring}} 7 {emit {\(ARCNET}} 8 {emit {\(SLIP}} 9 {emit {\(PPP}} 10 {emit {\(FDDI}} 11 {emit {\(RFC 1483 ATM}} 12 {emit {\(raw IP}} 13 {emit {\(BSD/OS SLIP}} 14 {emit {\(BSD/OS PPP}} 
if {[N I 16 x {}]} {emit {\b, capture length %d\)}}
} 263 {emit {old sun-2 executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 264 {emit {old sun-2 pure executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 267 {emit {old sun-2 demand paged executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 525398 {emit {SunOS core file}
switch -- [Nv I 4] 432 {emit {\(SPARC\)}
if {[S 132 x {}]} {emit {from '%s'}}
switch -- [Nv I 116] 3 {emit {\(quit\)}} 4 {emit {\(illegal instruction\)}} 5 {emit {\(trace trap\)}} 6 {emit {\(abort\)}} 7 {emit {\(emulator trap\)}} 8 {emit {\(arithmetic exception\)}} 9 {emit {\(kill\)}} 10 {emit {\(bus error\)}} 11 {emit {\(segmentation violation\)}} 12 {emit {\(bad argument to system call\)}} 29 {emit {\(resource lost\)}} 
if {[N I 120 x {}]} {emit {\(T=%dK,}}
if {[N I 124 x {}]} {emit D=%dK,}
if {[N I 128 x {}]} {emit {S=%dK\)}}
} 826 {emit {\(68K\)}
if {[S 128 x {}]} {emit {from '%s'}}
} 456 {emit {\(SPARC 4.x BCP\)}
if {[S 152 x {}]} {emit {from '%s'}}
} 
} 50331648 {emit {VMS Alpha executable}
if {[S 75264 == {PK\003\004}]} {emit {\b, Info-ZIP SFX archive v5.12 w/decryption}}
} 1297241678 {emit {VMware nvram}} 1129273156 {emit VMware
switch -- [Nv c 4] 3 {emit {virtual disk}
if {[N i 32 x {}]} {emit {\(%d/}}
if {[N i 36 x {}]} {emit {\b%d/}}
if {[N i 40 x {}]} {emit {\b%d\)}}
} 2 {emit {undoable disk}
if {[S 32 x {}]} {emit {\(%s\)}}
} 
} 
if {[S 0 == {Core\001}]} {emit {Alpha COFF format core dump \(Digital UNIX\)}
if {[S 24 x {}]} {emit {\b, from '%s'}}
}
if {[S 0 == {Core\002}]} {emit {Alpha COFF format core dump \(Digital UNIX\)}
if {[S 24 x {}]} {emit {\b, from '%s'}}
}
if {[S 0 == {AMANDA:\ }]} {emit AMANDA
if {[S 8 == {TAPESTART\ DATE}]} {emit {tape header file,}
if {[S 23 == X]} {if {[S 25 > {\ }]} {emit {Unused %s}}
}
if {[S 23 > {\ }]} {emit {DATE %s}}
}
if {[S 8 == {FILE\ }]} {emit {dump file,}
if {[S 13 > {\ }]} {emit {DATE %s}}
}
}
if {[S 0 == FC14]} {emit {Future Composer 1.4 Module sound file}}
if {[S 0 == SMOD]} {emit {Future Composer 1.3 Module sound file}}
if {[S 0 == AON4artofnoise]} {emit {Art Of Noise Module sound file}}
if {[S 1 == MUGICIAN/SOFTEYES]} {emit {Mugician Module sound file}}
if {[S 58 == {SIDMON\ II\ -\ THE}]} {emit {Sidmon 2.0 Module sound file}}
if {[S 0 == Synth4.0]} {emit {Synthesis Module sound file}}
if {[S 0 == ARP.]} {emit {The Holy Noise Module sound file}}
if {[S 0 == {BeEp\0}]} {emit {JamCracker Module sound file}}
if {[S 0 == {COSO\0}]} {emit {Hippel-COSO Module sound file}}
if {[S 0 == {\#\#\ version}]} {emit {catalog translation}}
if {[S 0 == RDSK]} {emit {Rigid Disk Block}
if {[S 160 x {}]} {emit {on %.24s}}
}
if {[S 0 == {DOS\0}]} {emit {Amiga DOS disk}}
if {[S 0 == {DOS\1}]} {emit {Amiga FFS disk}}
if {[S 0 == {DOS\2}]} {emit {Amiga Inter DOS disk}}
if {[S 0 == {DOS\3}]} {emit {Amiga Inter FFS disk}}
if {[S 0 == {DOS\4}]} {emit {Amiga Fastdir DOS disk}}
if {[S 0 == {DOS\5}]} {emit {Amiga Fastdir FFS disk}}
if {[S 0 == KICK]} {emit {Kickstart disk}}
if {[S 0 == MOVI]} {emit {Silicon Graphics movie file}}
if {[S 4 == moov]} {emit {Apple QuickTime}
if {[S 12 == mvhd]} {emit {\b movie \(fast start\)}}
if {[S 12 == mdra]} {emit {\b URL}}
if {[S 12 == cmov]} {emit {\b movie \(fast start, compressed header\)}}
if {[S 12 == rmra]} {emit {\b multiple URLs}}
}
if {[S 4 == mdat]} {emit {Apple QuickTime movie \(unoptimized\)}}
if {[S 4 == wide]} {emit {Apple QuickTime movie \(unoptimized\)}}
if {[S 4 == skip]} {emit {Apple QuickTime movie \(modified\)}}
if {[S 4 == free]} {emit {Apple QuickTime movie \(modified\)}}
if {[S 4 == idsc]} {emit {Apple QuickTime image \(fast start\)}}
if {[S 4 == idat]} {emit {Apple QuickTime image \(unoptimized\)}}
if {[S 4 == pckg]} {emit {Apple QuickTime compressed archive}}
if {[S 4 == jP B]} {emit {JPEG 2000 image}}
if {[S 4 == ftyp]} {emit {ISO Media}
if {[S 8 == isom]} {emit {\b, MPEG v4 system, version 1}}
if {[S 8 == iso2]} {emit {\b, MPEG v4 system, part 12 revision}}
if {[S 8 == mp41]} {emit {\b, MPEG v4 system, version 1}}
if {[S 8 == mp42]} {emit {\b, MPEG v4 system, version 2}}
if {[S 8 == mp7t]} {emit {\b, MPEG v4 system, MPEG v7 XML}}
if {[S 8 == mp7b]} {emit {\b, MPEG v4 system, MPEG v7 binary XML}}
if {[S 8 == jp2 B]} {emit {\b, JPEG 2000}}
if {[S 8 == 3gp]} {emit {\b, MPEG v4 system, 3GPP}
switch -- [Nv c 11] 4 {emit {\b v4 \(H.263/AMR GSM 6.10\)}} 5 {emit {\b v5 \(H.263/AMR GSM 6.10\)}} 6 {emit {\b v6 \(ITU H.264/AMR GSM 6.10\)}} 
}
if {[S 8 == mmp4]} {emit {\b, MPEG v4 system, 3GPP Mobile}}
if {[S 8 == avc1]} {emit {\b, MPEG v4 system, 3GPP JVT AVC}}
if {[S 8 == M4A B]} {emit {\b, MPEG v4 system, iTunes AAC-LC}}
if {[S 8 == M4P B]} {emit {\b, MPEG v4 system, iTunes AES encrypted}}
if {[S 8 == M4B B]} {emit {\b, MPEG v4 system, iTunes bookmarked}}
if {[S 8 == qt B]} {emit {\b, Apple QuickTime movie}}
}
if {[N I 0 == 0x100 &0xFFFFFF00]} {emit {MPEG sequence}
switch -- [Nv c 3] -70 {emit {}
if {[N c 4 & 0x40]} {emit {\b, v2, program multiplex}}
if {[N c 4 ^ 0x40]} {emit {\b, v1, system multiplex}}
} -69 {emit {\b, v1/2, multiplex \(missing pack header\)}} -80 {emit {\b, v4}
if {[N I 5 == 0x1b5]} {if {[N c 9 & 0x80]} {switch -- [Nv c 10 &0xF0] 16 {emit {\b, video}} 32 {emit {\b, still texture}} 48 {emit {\b, mesh}} 64 {emit {\b, face}} 
}
switch -- [Nv c 9 &0xF8] 8 {emit {\b, video}} 16 {emit {\b, still texture}} 24 {emit {\b, mesh}} 32 {emit {\b, face}} 
}
switch -- [Nv c 4] 1 {emit {\b, simple @ L1}} 2 {emit {\b, simple @ L2}} 3 {emit {\b, simple @ L3}} 4 {emit {\b, simple @ L0}} 17 {emit {\b, simple scalable @ L1}} 18 {emit {\b, simple scalable @ L2}} 33 {emit {\b, core @ L1}} 34 {emit {\b, core @ L2}} 50 {emit {\b, main @ L2}} 51 {emit {\b, main @ L3}} 53 {emit {\b, main @ L4}} 66 {emit {\b, n-bit @ L2}} 81 {emit {\b, scalable texture @ L1}} 97 {emit {\b, simple face animation @ L1}} 98 {emit {\b, simple face animation @ L2}} 99 {emit {\b, simple face basic animation @ L1}} 100 {emit {\b, simple face basic animation @ L2}} 113 {emit {\b, basic animation text @ L1}} 114 {emit {\b, basic animation text @ L2}} -127 {emit {\b, hybrid @ L1}} -126 {emit {\b, hybrid @ L2}} -111 {emit {\b, advanced RT simple @ L!}} -110 {emit {\b, advanced RT simple @ L2}} -109 {emit {\b, advanced RT simple @ L3}} -108 {emit {\b, advanced RT simple @ L4}} -95 {emit {\b, core scalable @ L1}} -94 {emit {\b, core scalable @ L2}} -93 {emit {\b, core scalable @ L3}} -79 {emit {\b, advanced coding efficiency @ L1}} -78 {emit {\b, advanced coding efficiency @ L2}} -77 {emit {\b, advanced coding efficiency @ L3}} -76 {emit {\b, advanced coding efficiency @ L4}} -63 {emit {\b, advanced core @ L1}} -62 {emit {\b, advanced core @ L2}} -47 {emit {\b, advanced scalable texture @ L1}} -46 {emit {\b, advanced scalable texture @ L2}} -45 {emit {\b, advanced scalable texture @ L3}} -31 {emit {\b, simple studio @ L1}} -30 {emit {\b, simple studio @ L2}} -29 {emit {\b, simple studio @ L3}} -28 {emit {\b, simple studio @ L4}} -27 {emit {\b, core studio @ L1}} -26 {emit {\b, core studio @ L2}} -25 {emit {\b, core studio @ L3}} -24 {emit {\b, core studio @ L4}} -16 {emit {\b, advanced simple @ L0}} -15 {emit {\b, advanced simple @ L1}} -14 {emit {\b, advanced simple @ L2}} -13 {emit {\b, advanced simple @ L3}} -12 {emit {\b, advanced simple @ L4}} -11 {emit {\b, advanced simple @ L5}} -9 {emit {\b, advanced simple @ L3b}} -8 {emit {\b, FGS @ L0}} -7 {emit {\b, FGS @ L1}} -6 {emit {\b, FGS @ L2}} -5 {emit {\b, FGS @ L3}} -4 {emit {\b, FGS @ L4}} -3 {emit {\b, FGS @ L5}} 
} -75 {emit {\b, v4}
if {[N c 4 & 0x80]} {switch -- [Nv c 5 &0xF0] 16 {emit {\b, video \(missing profile header\)}} 32 {emit {\b, still texture \(missing profile header\)}} 48 {emit {\b, mesh \(missing profile header\)}} 64 {emit {\b, face \(missing profile header\)}} 
}
switch -- [Nv c 4 &0xF8] 8 {emit {\b, video \(missing profile header\)}} 16 {emit {\b, still texture \(missing profile header\)}} 24 {emit {\b, mesh \(missing profile header\)}} 32 {emit {\b, face \(missing profile header\)}} 
} -77 {emit {}
switch -- [Nv I 12] 440 {emit {\b, v1, progressive Y'CbCr 4:2:0 video}} 434 {emit {\b, v1, progressive Y'CbCr 4:2:0 video}} 437 {emit {\b, v2,}
switch -- [Nv c 16 &0x0F] 1 {emit {\b HP}} 2 {emit {\b Spt}} 3 {emit {\b SNR}} 4 {emit {\b MP}} 5 {emit {\b SP}} 
switch -- [Nv c 17 &0xF0] 64 {emit {\b@HL}} 96 {emit {\b@H-14}} -128 {emit {\b@ML}} -96 {emit {\b@LL}} 
if {[N c 17 & 0x8]} {emit {\b progressive}}
if {[N c 17 ^ 0x8]} {emit {\b interlaced}}
switch -- [Nv c 17 &0x06] 2 {emit {\b Y'CbCr 4:2:0 video}} 4 {emit {\b Y'CbCr 4:2:2 video}} 6 {emit {\b Y'CbCr 4:4:4 video}} 
} 
if {[N c 11 & 0x2]} {if {[N c 75 & 0x1]} {switch -- [Nv I 140] 440 {emit {\b, v1, progressive Y'CbCr 4:2:0 video}} 434 {emit {\b, v1, progressive Y'CbCr 4:2:0 video}} 437 {emit {\b, v2,}
switch -- [Nv c 144 &0x0F] 1 {emit {\b HP}} 2 {emit {\b Spt}} 3 {emit {\b SNR}} 4 {emit {\b MP}} 5 {emit {\b SP}} 
switch -- [Nv c 145 &0xF0] 64 {emit {\b@HL}} 96 {emit {\b@H-14}} -128 {emit {\b@ML}} -96 {emit {\b@LL}} 
if {[N c 145 & 0x8]} {emit {\b progressive}}
if {[N c 145 ^ 0x8]} {emit {\b interlaced}}
switch -- [Nv c 145 &0x06] 2 {emit {\b Y'CbCr 4:2:0 video}} 4 {emit {\b Y'CbCr 4:2:2 video}} 6 {emit {\b Y'CbCr 4:4:4 video}} 
} 
}
}
switch -- [Nv I 76] 440 {emit {\b, v1, progressive Y'CbCr 4:2:0 video}} 434 {emit {\b, v1, progressive Y'CbCr 4:2:0 video}} 437 {emit {\b, v2,}
switch -- [Nv c 80 &0x0F] 1 {emit {\b HP}} 2 {emit {\b Spt}} 3 {emit {\b SNR}} 4 {emit {\b MP}} 5 {emit {\b SP}} 
switch -- [Nv c 81 &0xF0] 64 {emit {\b@HL}} 96 {emit {\b@H-14}} -128 {emit {\b@ML}} -96 {emit {\b@LL}} 
if {[N c 81 & 0x8]} {emit {\b progressive}}
if {[N c 81 ^ 0x8]} {emit {\b interlaced}}
switch -- [Nv c 81 &0x06] 2 {emit {\b Y'CbCr 4:2:0 video}} 4 {emit {\b Y'CbCr 4:2:2 video}} 6 {emit {\b Y'CbCr 4:4:4 video}} 
} 
switch -- [Nv I 4 &0xFFFFFF00] 2013542400 {emit {\b, HD-TV 1920P}
if {[N c 7 == 0x10 &0xF0]} {emit {\b, 16:9}}
} 1342188800 {emit {\b, SD-TV 1280I}
if {[N c 7 == 0x10 &0xF0]} {emit {\b, 16:9}}
} 805453824 {emit {\b, PAL Capture}
if {[N c 7 == 0x10 &0xF0]} {emit {\b, 4:3}}
} 671211520 {emit {\b, LD-TV 640P}
if {[N c 7 == 0x10 &0xF0]} {emit {\b, 4:3}}
} 335605760 {emit {\b, 320x240}
if {[N c 7 == 0x10 &0xF0]} {emit {\b, 4:3}}
} 251699200 {emit {\b, 240x160}
if {[N c 7 == 0x10 &0xF0]} {emit {\b, 4:3}}
} 167802880 {emit {\b, 160x120}
if {[N c 7 == 0x10 &0xF0]} {emit {\b, 4:3}}
} 
switch -- [Nv S 4 &0xFFF0] 11264 {emit {\b, 4CIF}
switch -- [Nv S 5 &0x0FFF] 480 {emit {\b NTSC}} 576 {emit {\b PAL}} 
switch -- [Nv c 7 &0xF0] 32 {emit {\b, 4:3}} 48 {emit {\b, 16:9}} 64 {emit {\b, 11:5}} -128 {emit {\b, PAL 4:3}} -64 {emit {\b, NTSC 4:3}} 
} 5632 {emit {\b, CIF}
switch -- [Nv S 5 &0x0FFF] 240 {emit {\b NTSC}} 288 {emit {\b PAL}} 576 {emit {\b PAL 625}
switch -- [Nv c 7 &0xF0] 32 {emit {\b, 4:3}} 48 {emit {\b, 16:9}} 64 {emit {\b, 11:5}} 
} 
switch -- [Nv c 7 &0xF0] 32 {emit {\b, 4:3}} 48 {emit {\b, 16:9}} 64 {emit {\b, 11:5}} -128 {emit {\b, PAL 4:3}} -64 {emit {\b, NTSC 4:3}} 
} 11520 {emit {\b, CCIR/ITU}
switch -- [Nv S 5 &0x0FFF] 480 {emit {\b NTSC 525}} 576 {emit {\b PAL 625}} 
switch -- [Nv c 7 &0xF0] 32 {emit {\b, 4:3}} 48 {emit {\b, 16:9}} 64 {emit {\b, 11:5}} 
} 7680 {emit {\b, SVCD}
switch -- [Nv S 5 &0x0FFF] 480 {emit {\b NTSC 525}} 576 {emit {\b PAL 625}} 
switch -- [Nv c 7 &0xF0] 32 {emit {\b, 4:3}} 48 {emit {\b, 16:9}} 64 {emit {\b, 11:5}} 
} 
switch -- [Nv c 7 &0x0F] 1 {emit {\b, 23.976 fps}} 2 {emit {\b, 24 fps}} 3 {emit {\b, 25 fps}} 4 {emit {\b, 29.97 fps}} 5 {emit {\b, 30 fps}} 6 {emit {\b, 50 fps}} 7 {emit {\b, 59.94 fps}} 8 {emit {\b, 60 fps}} 
if {[N c 11 & 0x4]} {emit {\b, Constrained}}
} 
if {[N c 3 == 0x7 &0x1F]} {emit {\b, H.264 video}
switch -- [Nv c 4] 66 {emit {\b, baseline}} 77 {emit {\b, main}} 88 {emit {\b, extended}} 
if {[N c 6 x {}]} {emit {\b @ L %u}}
}
}
switch -- [Nv S 0 &0xFFFE] -6 {emit {MPEG ADTS, layer III, v1}
switch -- [Nv c 2 &0xF0] 16 {emit {\b,  32 kBits}} 32 {emit {\b,  40 kBits}} 48 {emit {\b,  48 kBits}} 64 {emit {\b,  56 kBits}} 80 {emit {\b,  64 kBits}} 96 {emit {\b,  80 kBits}} 112 {emit {\b,  96 kBits}} -128 {emit {\b, 112 kBits}} -112 {emit {\b, 128 kBits}} -96 {emit {\b, 160 kBits}} -80 {emit {\b, 192 kBits}} -64 {emit {\b, 224 kBits}} -48 {emit {\b, 256 kBits}} -32 {emit {\b, 320 kBits}} 
switch -- [Nv c 2 &0x0C] 0 {emit {\b, 44.1 kHz}} 4 {emit {\b, 48 kHz}} 8 {emit {\b, 32 kHz}} 
switch -- [Nv c 3 &0xC0] 0 {emit {\b, Stereo}} 64 {emit {\b, JntStereo}} -128 {emit {\b, 2x Monaural}} -64 {emit {\b, Monaural}} 
} -4 {emit {MPEG ADTS, layer II, v1}
switch -- [Nv c 2 &0xF0] 16 {emit {\b,  32 kBits}} 32 {emit {\b,  48 kBits}} 48 {emit {\b,  56 kBits}} 64 {emit {\b,  64 kBits}} 80 {emit {\b,  80 kBits}} 96 {emit {\b,  96 kBits}} 112 {emit {\b, 112 kBits}} -128 {emit {\b, 128 kBits}} -112 {emit {\b, 160 kBits}} -96 {emit {\b, 192 kBits}} -80 {emit {\b, 224 kBits}} -64 {emit {\b, 256 kBits}} -48 {emit {\b, 320 kBits}} -32 {emit {\b, 384 kBits}} 
switch -- [Nv c 2 &0x0C] 0 {emit {\b, 44.1 kHz}} 4 {emit {\b, 48 kHz}} 8 {emit {\b, 32 kHz}} 
switch -- [Nv c 3 &0xC0] 0 {emit {\b, Stereo}} 64 {emit {\b, JntStereo}} -128 {emit {\b, 2x Monaural}} -64 {emit {\b, Monaural}} 
} -2 {emit {MPEG ADTS, layer I, v1}
switch -- [Nv c 2 &0xF0] 16 {emit {\b,  32 kBits}} 32 {emit {\b,  64 kBits}} 48 {emit {\b,  96 kBits}} 64 {emit {\b, 128 kBits}} 80 {emit {\b, 160 kBits}} 96 {emit {\b, 192 kBits}} 112 {emit {\b, 224 kBits}} -128 {emit {\b, 256 kBits}} -112 {emit {\b, 288 kBits}} -96 {emit {\b, 320 kBits}} -80 {emit {\b, 352 kBits}} -64 {emit {\b, 384 kBits}} -48 {emit {\b, 416 kBits}} -32 {emit {\b, 448 kBits}} 
switch -- [Nv c 2 &0x0C] 0 {emit {\b, 44.1 kHz}} 4 {emit {\b, 48 kHz}} 8 {emit {\b, 32 kHz}} 
switch -- [Nv c 3 &0xC0] 0 {emit {\b, Stereo}} 64 {emit {\b, JntStereo}} -128 {emit {\b, 2x Monaural}} -64 {emit {\b, Monaural}} 
} -14 {emit {MPEG ADTS, layer III, v2}
switch -- [Nv c 2 &0xF0] 16 {emit {\b,   8 kBits}} 32 {emit {\b,  16 kBits}} 48 {emit {\b,  24 kBits}} 64 {emit {\b,  32 kBits}} 80 {emit {\b,  40 kBits}} 96 {emit {\b,  48 kBits}} 112 {emit {\b,  56 kBits}} -128 {emit {\b,  64 kBits}} -112 {emit {\b,  80 kBits}} -96 {emit {\b,  96 kBits}} -80 {emit {\b, 112 kBits}} -64 {emit {\b, 128 kBits}} -48 {emit {\b, 144 kBits}} -32 {emit {\b, 160 kBits}} 
switch -- [Nv c 2 &0x0C] 0 {emit {\b, 22.05 kHz}} 4 {emit {\b, 24 kHz}} 8 {emit {\b, 16 kHz}} 
switch -- [Nv c 3 &0xC0] 0 {emit {\b, Stereo}} 64 {emit {\b, JntStereo}} -128 {emit {\b, 2x Monaural}} -64 {emit {\b, Monaural}} 
} -12 {emit {MPEG ADTS, layer II, v2}
switch -- [Nv c 2 &0xF0] 16 {emit {\b,   8 kBits}} 32 {emit {\b,  16 kBits}} 48 {emit {\b,  24 kBits}} 64 {emit {\b,  32 kBits}} 80 {emit {\b,  40 kBits}} 96 {emit {\b,  48 kBits}} 112 {emit {\b,  56 kBits}} -128 {emit {\b,  64 kBits}} -112 {emit {\b,  80 kBits}} -96 {emit {\b,  96 kBits}} -80 {emit {\b, 112 kBits}} -64 {emit {\b, 128 kBits}} -48 {emit {\b, 144 kBits}} -32 {emit {\b, 160 kBits}} 
switch -- [Nv c 2 &0x0C] 0 {emit {\b, 22.05 kHz}} 4 {emit {\b, 24 kHz}} 8 {emit {\b, 16 kHz}} 
switch -- [Nv c 3 &0xC0] 0 {emit {\b, Stereo}} 64 {emit {\b, JntStereo}} -128 {emit {\b, 2x Monaural}} -64 {emit {\b, Monaural}} 
} -10 {emit {MPEG ADTS, layer I, v2}
switch -- [Nv c 2 &0xF0] 16 {emit {\b,  32 kBits}} 32 {emit {\b,  48 kBits}} 48 {emit {\b,  56 kBits}} 64 {emit {\b,  64 kBits}} 80 {emit {\b,  80 kBits}} 96 {emit {\b,  96 kBits}} 112 {emit {\b, 112 kBits}} -128 {emit {\b, 128 kBits}} -112 {emit {\b, 144 kBits}} -96 {emit {\b, 160 kBits}} -80 {emit {\b, 176 kBits}} -64 {emit {\b, 192 kBits}} -48 {emit {\b, 224 kBits}} -32 {emit {\b, 256 kBits}} 
switch -- [Nv c 2 &0x0C] 0 {emit {\b, 22.05 kHz}} 4 {emit {\b, 24 kHz}} 8 {emit {\b, 16 kHz}} 
switch -- [Nv c 3 &0xC0] 0 {emit {\b, Stereo}} 64 {emit {\b, JntStereo}} -128 {emit {\b, 2x Monaural}} -64 {emit {\b, Monaural}} 
} -30 {emit {MPEG ADTS, layer III,  v2.5}
switch -- [Nv c 2 &0xF0] 16 {emit {\b,   8 kBits}} 32 {emit {\b,  16 kBits}} 48 {emit {\b,  24 kBits}} 64 {emit {\b,  32 kBits}} 80 {emit {\b,  40 kBits}} 96 {emit {\b,  48 kBits}} 112 {emit {\b,  56 kBits}} -128 {emit {\b,  64 kBits}} -112 {emit {\b,  80 kBits}} -96 {emit {\b,  96 kBits}} -80 {emit {\b, 112 kBits}} -64 {emit {\b, 128 kBits}} -48 {emit {\b, 144 kBits}} -32 {emit {\b, 160 kBits}} 
switch -- [Nv c 2 &0x0C] 0 {emit {\b, 11.025 kHz}} 4 {emit {\b, 12 kHz}} 8 {emit {\b, 8 kHz}} 
switch -- [Nv c 3 &0xC0] 0 {emit {\b, Stereo}} 64 {emit {\b, JntStereo}} -128 {emit {\b, 2x Monaural}} -64 {emit {\b, Monaural}} 
} 
if {[S 0 == ADIF]} {emit {MPEG ADIF, AAC}
if {[N c 4 & 0x80]} {if {[N c 13 & 0x10]} {emit {\b, VBR}}
if {[N c 13 ^ 0x10]} {emit {\b, CBR}}
switch -- [Nv c 16 &0x1E] 2 {emit {\b, single stream}} 4 {emit {\b, 2 streams}} 6 {emit {\b, 3 streams}} 
if {[N c 16 & 0x8]} {emit {\b, 4 or more streams}}
if {[N c 16 & 0x10]} {emit {\b, 8 or more streams}}
if {[N c 4 & 0x80]} {emit {\b, Copyrighted}}
if {[N c 13 & 0x40]} {emit {\b, Original Source}}
if {[N c 13 & 0x20]} {emit {\b, Home Flag}}
}
if {[N c 4 ^ 0x80]} {if {[N c 4 & 0x10]} {emit {\b, VBR}}
if {[N c 4 ^ 0x10]} {emit {\b, CBR}}
switch -- [Nv c 7 &0x1E] 2 {emit {\b, single stream}} 4 {emit {\b, 2 streams}} 6 {emit {\b, 3 streams}} 
if {[N c 7 & 0x8]} {emit {\b, 4 or more streams}}
if {[N c 7 & 0x10]} {emit {\b, 8 or more streams}}
if {[N c 4 & 0x40]} {emit {\b, Original Stream\(s\)}}
if {[N c 4 & 0x20]} {emit {\b, Home Source}}
}
}
if {[N S 0 == 0xfff0 &0xFFF6]} {emit {MPEG ADTS, AAC}
if {[N c 1 & 0x8]} {emit {\b, v2}}
if {[N c 1 ^ 0x8]} {emit {\b, v4}
if {[N c 2 & 0xc0]} {emit {\b LTP}}
}
switch -- [Nv c 2 &0xc0] 0 {emit {\b Main}} 64 {emit {\b LC}} -128 {emit {\b SSR}} 
switch -- [Nv c 2 &0x3c] 0 {emit {\b, 96 kHz}} 4 {emit {\b, 88.2 kHz}} 8 {emit {\b, 64 kHz}} 12 {emit {\b, 48 kHz}} 16 {emit {\b, 44.1 kHz}} 20 {emit {\b, 32 kHz}} 24 {emit {\b, 24 kHz}} 28 {emit {\b, 22.05 kHz}} 32 {emit {\b, 16 kHz}} 36 {emit {\b, 12 kHz}} 40 {emit {\b, 11.025 kHz}} 44 {emit {\b, 8 kHz}} 
switch -- [Nv S 2 &0x01c0] 64 {emit {\b, monaural}} 128 {emit {\b, stereo}} 192 {emit {\b, stereo + center}} 256 {emit {\b, stereo+center+LFE}} 320 {emit {\b, surround}} 384 {emit {\b, surround + LFE}} 
if {[N S 2 & 0x1c0]} {emit {\b, surround + side}}
}
if {[N S 0 == 0x56e0 &0xFFE0]} {emit {MPEG-4 LOAS}
if {[N c 3 == 0x40 &0xE0]} {switch -- [Nv c 4 &0x3C] 4 {emit {\b, single stream}} 8 {emit {\b, 2 streams}} 12 {emit {\b, 3 streams}} 
if {[N c 4 & 0x8]} {emit {\b, 4 or more streams}}
if {[N c 4 & 0x20]} {emit {\b, 8 or more streams}}
}
if {[N c 3 == 0x0 &0xC0]} {switch -- [Nv c 4 &0x78] 8 {emit {\b, single stream}} 16 {emit {\b, 2 streams}} 24 {emit {\b, 3 streams}} 
if {[N c 4 & 0x20]} {emit {\b, 4 or more streams}}
if {[N c 4 & 0x40]} {emit {\b, 8 or more streams}}
}
}
switch -- [Nv s 4] -20719 {emit {FLI file}
if {[N s 6 x {}]} {emit {- %d frames,}}
if {[N s 8 x {}]} {emit {width=%d pixels,}}
if {[N s 10 x {}]} {emit {height=%d pixels,}}
if {[N s 12 x {}]} {emit depth=%d,}
if {[N s 16 x {}]} {emit ticks/frame=%d}
} -20718 {emit {FLC file}
if {[N s 6 x {}]} {emit {- %d frames}}
if {[N s 8 x {}]} {emit {width=%d pixels,}}
if {[N s 10 x {}]} {emit {height=%d pixels,}}
if {[N s 12 x {}]} {emit depth=%d,}
if {[N s 16 x {}]} {emit ticks/frame=%d}
} 
if {[N I 0 == 0x47400010 &0xFF5FFF1F]} {emit {MPEG transport stream data}
if {[N c 188 != 0x47]} {emit CORRUPTED}
}
switch -- [Nv I 0 &0xffffff00] 520552448 {emit DIF
if {[N c 4 & 0x1]} {emit {\(DVCPRO\) movie file}}
if {[N c 4 ^ 0x1]} {emit {\(DV\) movie file}}
if {[N c 3 & 0x80]} {emit {\(PAL\)}}
if {[N c 3 ^ 0x80]} {emit {\(NTSC\)}}
} -2063526912 {emit {cisco IOS microcode}
if {[S 7 x {}]} {emit {for '%s'}}
} -2063480064 {emit {cisco IOS experimental microcode}
if {[S 7 x {}]} {emit {for '%s'}}
} -16907520 {emit {MySQL MISAM index file}
if {[N c 3 x {}]} {emit {Version %d}}
} -16906496 {emit {MySQL MISAM compressed data file}
if {[N c 3 x {}]} {emit {Version %d}}
} -16907008 {emit {MySQL ISAM index file}
if {[N c 3 x {}]} {emit {Version %d}}
} -16906752 {emit {MySQL ISAM compressed data file}
if {[N c 3 x {}]} {emit {Version %d}}
} 
if {[S 0 == {\x8aMNG}]} {emit {MNG video data,}
if {[N I 4 != 0xd0a1a0a]} {emit CORRUPTED,}
if {[N I 4 == 0xd0a1a0a]} {if {[N I 16 x {}]} {emit {%ld x}}
if {[N I 20 x {}]} {emit %ld}
}
}
if {[S 0 == {\x8bJNG}]} {emit {JNG video data,}
if {[N I 4 != 0xd0a1a0a]} {emit CORRUPTED,}
if {[N I 4 == 0xd0a1a0a]} {if {[N I 16 x {}]} {emit {%ld x}}
if {[N I 20 x {}]} {emit %ld}
}
}
if {[S 3 == {\x0D\x0AVersion:Vivo}]} {emit {Vivo video data}}
if {[S 0 == {\#VRML\ V1.0\ ascii} b]} {emit {VRML 1 file}}
if {[S 0 == {\#VRML\ V2.0\ utf8} b]} {emit {ISO/IEC 14772 VRML 97 file}}
if {[S 0 == HVQM4]} {emit %s
if {[S 6 x {}]} {emit v%s}
if {[N c 0 x {}]} {emit {GameCube movie,}}
if {[N S 52 x {}]} {emit {%d x}}
if {[N S 54 x {}]} {emit %d,}
if {[N S 38 x {}]} {emit %dµs,}
if {[N S 66 == 0x0]} {emit {no audio}}
if {[N S 66 > 0x0]} {emit {%dHz audio}}
}
if {[S 0 == DVDVIDEO-VTS]} {emit {Video title set,}
if {[N c 33 x {}]} {emit v%x}
}
if {[S 0 == DVDVIDEO-VMG]} {emit {Video manager,}
if {[N c 33 x {}]} {emit v%x}
}
switch -- [Nv Q 0] 33132 {emit {APL workspace \(Ken's original?\)}} 65389 {emit {very old archive}} 65381 {emit {old archive}} 33132 {emit {apl workspace}} 557605234 {emit {archive file}} 262 {emit {68k Blit mpx/mux executable}} 269 {emit {i960 b.out relocatable object}
if {[N Q 16 > 0x0]} {emit {not stripped}}
} 1145263299 {emit {DACT compressed data}
if {[N c 4 > 0xffffffff]} {emit {\(version %i.}}
if {[N c 5 > 0xffffffff]} {emit {$BS%i.}}
if {[N c 6 > 0xffffffff]} {emit {$BS%i\)}}
if {[N Q 7 > 0x0]} {emit {$BS, original size: %i bytes}}
if {[N Q 15 > 0x1e]} {emit {$BS, block size: %i bytes}}
} 398689 {emit {Berkeley DB}
switch -- [Nv I 8] 4321 {emit {}
if {[N I 4 > 0x2]} {emit 1.86}
if {[N I 4 < 0x3]} {emit 1.85}
if {[N I 4 > 0x0]} {emit {\(Hash, version %d, native byte-order\)}}
} 1234 {emit {}
if {[N I 4 > 0x2]} {emit 1.86}
if {[N I 4 < 0x3]} {emit 1.85}
if {[N I 4 > 0x0]} {emit {\(Hash, version %d, little-endian\)}}
} 
} 340322 {emit {Berkeley DB 1.85/1.86}
if {[N Q 4 > 0x0]} {emit {\(Btree, version %d, native byte-order\)}}
} 1234567 {emit {X image}} 168757262 {emit {TML 0123 byte-order format}} 252317192 {emit {TML 1032 byte-order format}} 135137807 {emit {TML 2301 byte-order format}} 235409162 {emit {TML 3210 byte-order format}} 34078982 {emit {HP s500 relocatable executable}
if {[N Q 16 > 0x0]} {emit {- version %ld}}
} 34078983 {emit {HP s500 executable}
if {[N Q 16 > 0x0]} {emit {- version %ld}}
} 34078984 {emit {HP s500 pure executable}
if {[N Q 16 > 0x0]} {emit {- version %ld}}
} 65381 {emit {HP old archive}} 34275173 {emit {HP s200 old archive}} 34406245 {emit {HP s200 old archive}} 34144101 {emit {HP s500 old archive}} 22552998 {emit {HP core file}} 1302851304 {emit {HP-WINDOWS font}
if {[N c 8 > 0x0]} {emit {- version %ld}}
} 34341132 {emit {compiled Lisp}} 1123028772 {emit {Artisan image data}
switch -- [Nv Q 4] 1 {emit {\b, rectangular 24-bit}} 2 {emit {\b, rectangular 8-bit with colormap}} 3 {emit {\b, rectangular 32-bit \(24-bit with matte\)}} 
} 1886817234 {emit {CLISP memory image data}} -762612112 {emit {CLISP memory image data, other endian}} -569244523 {emit {GNU-format message catalog data}} -1794895138 {emit {GNU-format message catalog data}} -1042103351 {emit {SPSS Portable File}
if {[S 40 x {}]} {emit %s}
} 31415 {emit {Mirage Assembler m.out executable}} 61374 {emit {OSF/Rose object}} 1351614727 {emit {Pyramid 90x family executable}} 1351614728 {emit {Pyramid 90x family pure executable}
if {[N Q 16 > 0x0]} {emit {not stripped}}
} 1351614731 {emit {Pyramid 90x family demand paged pure executable}
if {[N Q 16 > 0x0]} {emit {not stripped}}
} -97271666 {emit {SunPC 4.0 Hard Disk}} 268 {emit {unknown demand paged pure executable}
if {[N Q 16 > 0x0]} {emit {not stripped}}
} 270 {emit {unknown readable demand paged pure executable}} 395726 {emit {Jaleo XFS file}
if {[N Q 4 x {}]} {emit {- version %ld}}
if {[N Q 8 x {}]} {emit {- [%ld -}}
if {[N Q 20 x {}]} {emit %ldx}
if {[N Q 24 x {}]} {emit %ldx}
switch -- [Nv Q 28] 1008 {emit YUV422\]} 1000 {emit RGB24\]} 
} 59399 {emit {object file \(z8000 a.out\)}} 59400 {emit {pure object file \(z8000 a.out\)}} 59401 {emit {separate object file \(z8000 a.out\)}} 59397 {emit {overlay object file \(z8000 a.out\)}} 
if {[S 0 == FiLeStArTfIlEsTaRt]} {emit {binscii \(apple ][\) text}}
if {[S 0 == {\x0aGL}]} {emit {Binary II \(apple ][\) data}}
if {[S 0 == {\x76\xff}]} {emit {Squeezed \(apple ][\) data}}
if {[S 0 == NuFile]} {emit {NuFile archive \(apple ][\) data}}
if {[S 0 == {N\xf5F\xe9l\xe5}]} {emit {NuFile archive \(apple ][\) data}}
if {[S 0 == package0]} {emit {Newton package, NOS 1.x,}
if {[N I 12 & 0x80000000]} {emit AutoRemove,}
if {[N I 12 & 0x40000000]} {emit CopyProtect,}
if {[N I 12 & 0x10000000]} {emit NoCompression,}
if {[N I 12 & 0x4000000]} {emit Relocation,}
if {[N I 12 & 0x2000000]} {emit UseFasterCompression,}
if {[N I 16 x {}]} {emit {version %d}}
}
if {[S 0 == package1]} {emit {Newton package, NOS 2.x,}
if {[N I 12 & 0x80000000]} {emit AutoRemove,}
if {[N I 12 & 0x40000000]} {emit CopyProtect,}
if {[N I 12 & 0x10000000]} {emit NoCompression,}
if {[N I 12 & 0x4000000]} {emit Relocation,}
if {[N I 12 & 0x2000000]} {emit UseFasterCompression,}
if {[N I 16 x {}]} {emit {version %d}}
}
if {[S 0 == package4]} {emit {Newton package,}
switch -- [Nv c 8] 8 {emit {NOS 1.x,}} 9 {emit {NOS 2.x,}} 
if {[N I 12 & 0x80000000]} {emit AutoRemove,}
if {[N I 12 & 0x40000000]} {emit CopyProtect,}
if {[N I 12 & 0x10000000]} {emit NoCompression,}
}
if {[S 4 == O====]} {emit {AppleWorks word processor data}
if {[N c 85 > 0x0 &0x01]} {emit {\b, zoomed}}
if {[N c 90 > 0x0 &0x01]} {emit {\b, paginated}}
if {[N c 92 > 0x0 &0x01]} {emit {\b, with mail merge}}
}
if {[N I 0 == 0x80000 &0xff00ff]} {emit {Applesoft BASIC program data}}
if {[S 8144 == {\x7F\x7F\x7F\x7F\x7F\x7F\x7F\x7F}]} {emit {Apple II image with white background}}
if {[S 8144 == {\x55\x2A\x55\x2A\x55\x2A\x55\x2A}]} {emit {Apple II image with purple background}}
if {[S 8144 == {\x2A\x55\x2A\x55\x2A\x55\x2A\x55}]} {emit {Apple II image with green background}}
if {[S 8144 == {\xD5\xAA\xD5\xAA\xD5\xAA\xD5\xAA}]} {emit {Apple II image with blue background}}
if {[S 8144 == {\xAA\xD5\xAA\xD5\xAA\xD5\xAA\xD5}]} {emit {Apple II image with orange background}}
if {[N I 0 == 0x6400d000 &0xFF00FFFF]} {emit {Apple Mechanic font}}
if {[S 0 == *BEGIN]} {emit Applixware
if {[S 7 == WORDS]} {emit {Words Document}}
if {[S 7 == GRAPHICS]} {emit Graphic}
if {[S 7 == RASTER]} {emit Bitmap}
if {[S 7 == SPREADSHEETS]} {emit Spreadsheet}
if {[S 7 == MACRO]} {emit Macro}
if {[S 7 == BUILDER]} {emit {Builder Object}}
}
if {[S 257 == {ustar\0}]} {emit {POSIX tar archive}}
if {[S 257 == {ustar\040\040\0}]} {emit {GNU tar archive}}
if {[S 0 == 070707]} {emit {ASCII cpio archive \(pre-SVR4 or odc\)}}
if {[S 0 == 070701]} {emit {ASCII cpio archive \(SVR4 with no CRC\)}}
if {[S 0 == 070702]} {emit {ASCII cpio archive \(SVR4 with CRC\)}}
if {[S 0 == {!<arch>\ndebian}]} {if {[S 8 == debian-split]} {emit {part of multipart Debian package}}
if {[S 8 == debian-binary]} {emit {Debian binary package}}
if {[S 68 x {}]} {emit {\(format %s\)}}
if {[S 81 == bz2]} {emit {\b, uses bzip2 compression}}
if {[S 84 == gz]} {emit {\b, uses gzip compression}}
}
if {[S 0 == <ar>]} {emit archive}
if {[S 0 == {!<arch>\n__________E}]} {emit {MIPS archive}
if {[S 20 == U]} {emit {with MIPS Ucode members}}
if {[S 21 == L]} {emit {with MIPSEL members}}
if {[S 21 == B]} {emit {with MIPSEB members}}
if {[S 19 == L]} {emit {and an EL hash table}}
if {[S 19 == B]} {emit {and an EB hash table}}
if {[S 22 == X]} {emit {-- out of date}}
}
if {[S 0 == -h-]} {emit {Software Tools format archive text}}
if {[S 0 == !<arch>]} {emit {current ar archive}
if {[S 8 == __.SYMDEF]} {emit {random library}}
switch -- [Nv I 0] 65538 {emit {- pre SR9.5}} 65539 {emit {- post SR9.5}} 
switch -- [Nv S 0] 2 {emit {- object archive}} 3 {emit {- shared library module}} 4 {emit {- debug break-pointed module}} 5 {emit {- absolute code program module}} 
}
if {[S 0 == <ar>]} {emit {System V Release 1 ar archive}}
if {[S 0 == <ar>]} {emit archive}
switch -- [Nv i 0 &0x8080ffff] 2074 {emit {ARC archive data, dynamic LZW}} 2330 {emit {ARC archive data, squashed}} 538 {emit {ARC archive data, uncompressed}} 794 {emit {ARC archive data, packed}} 1050 {emit {ARC archive data, squeezed}} 1562 {emit {ARC archive data, crunched}} 
if {[S 0 == {\032}]} {emit {RISC OS archive \(spark format\)}}
if {[S 0 == {Archive\000}]} {emit {RISC OS archive \(ArcFS format\)}}
if {[S 0 == HPAK]} {emit {HPACK archive data}}
if {[S 0 == {\351,\001JAM\	}]} {emit {JAM archive,}
if {[S 7 x {}]} {emit {version %.4s}}
if {[N c 38 == 0x27]} {emit -
if {[S 43 x {}]} {emit {label %.11s,}}
if {[N i 39 x {}]} {emit {serial %08x,}}
if {[S 54 x {}]} {emit {fstype %.8s}}
}
}
if {[S 2 == -lh0-]} {emit {LHarc 1.x archive data [lh0]}}
if {[S 2 == -lh1-]} {emit {LHarc 1.x archive data [lh1]}}
if {[S 2 == -lz4-]} {emit {LHarc 1.x archive data [lz4]}}
if {[S 2 == -lz5-]} {emit {LHarc 1.x archive data [lz5]}}
if {[S 2 == -lzs-]} {emit {LHa 2.x? archive data [lzs]}}
if {[S 2 == {-lh\40-}]} {emit {LHa 2.x? archive data [lh ]}}
if {[S 2 == -lhd-]} {emit {LHa 2.x? archive data [lhd]}}
if {[S 2 == -lh2-]} {emit {LHa 2.x? archive data [lh2]}}
if {[S 2 == -lh3-]} {emit {LHa 2.x? archive data [lh3]}}
if {[S 2 == -lh4-]} {emit {LHa \(2.x\) archive data [lh4]}}
if {[S 2 == -lh5-]} {emit {LHa \(2.x\) archive data [lh5]}}
if {[S 2 == -lh6-]} {emit {LHa \(2.x\) archive data [lh6]}}
if {[S 2 == -lh7-]} {emit {LHa \(2.x\) archive data [lh7]}
if {[N c 20 x {}]} {emit {- header level %d}}
}
if {[S 0 == Rar!]} {emit {RAR archive data,}
if {[N c 44 x {}]} {emit v%0x,}
switch -- [Nv c 35] 0 {emit {os: MS-DOS}} 1 {emit {os: OS/2}} 2 {emit {os: Win32}} 3 {emit {os: Unix}} 
}
if {[S 0 == SQSH]} {emit {squished archive data \(Acorn RISCOS\)}}
if {[S 0 == {UC2\x1a}]} {emit {UC2 archive data}}
if {[S 0 == {PK\003\004}]} {emit {Zip archive data}
switch -- [Nv c 4] 9 {emit {\b, at least v0.9 to extract}} 10 {emit {\b, at least v1.0 to extract}} 11 {emit {\b, at least v1.1 to extract}} 20 {emit {\b, at least v2.0 to extract}} 
}
if {[N i 20 == 0xfdc4a7dc]} {emit {Zoo archive data}
if {[N c 4 > 0x30]} {emit {\b, v%c.}
if {[N c 6 > 0x2f]} {emit {\b%c}
if {[N c 7 > 0x2f]} {emit {\b%c}}
}
}
if {[N c 32 > 0x0]} {emit {\b, modify: v%d}
if {[N c 33 x {}]} {emit {\b.%d+}}
}
if {[N i 42 == 0xfdc4a7dc]} {emit {\b,}
if {[N c 70 > 0x0]} {emit {extract: v%d}
if {[N c 71 x {}]} {emit {\b.%d+}}
}
}
}
if {[S 10 == {\#\ This\ is\ a\ shell\ archive}]} {emit {shell archive text}}
if {[S 0 == {\0\ \ \ \ \ \ \ \ \ \ \ \0\0}]} {emit {LBR archive data}}
if {[S 2 == -pm0-]} {emit {PMarc archive data [pm0]}}
if {[S 2 == -pm1-]} {emit {PMarc archive data [pm1]}}
if {[S 2 == -pm2-]} {emit {PMarc archive data [pm2]}}
if {[S 2 == -pms-]} {emit {PMarc SFX archive \(CP/M, DOS\)}}
if {[S 5 == -pc1-]} {emit {PopCom compressed executable \(CP/M\)}}
if {[S 4 == {gtktalog\ }]} {emit {GTKtalog catalog data,}
if {[S 13 == 3]} {emit {version 3}
if {[N S 14 == 0x677a]} {emit {\(gzipped\)}}
if {[N S 14 != 0x677a]} {emit {\(not gzipped\)}}
}
if {[S 13 > 3]} {emit {version %s}}
}
if {[S 0 == {PAR\0}]} {emit {PARity archive data}
if {[N s 48 == 0x0]} {emit {- Index file}}
if {[N s 48 > 0x0]} {emit {- file number %d}}
}
if {[S 0 == d8:announce]} {emit {BitTorrent file}}
if {[S 0 == {PK00PK\003\004}]} {emit {Zip archive data}}
if {[S 7 == **ACE**]} {emit {ACE compressed archive}
if {[N c 15 > 0x0]} {emit {version %d}}
switch -- [Nv c 16] 0 {emit {\b, from MS-DOS}} 1 {emit {\b, from OS/2}} 2 {emit {\b, from Win/32}} 3 {emit {\b, from Unix}} 4 {emit {\b, from MacOS}} 5 {emit {\b, from WinNT}} 6 {emit {\b, from Primos}} 7 {emit {\b, from AppleGS}} 8 {emit {\b, from Atari}} 9 {emit {\b, from Vax/VMS}} 10 {emit {\b, from Amiga}} 11 {emit {\b, from Next}} 
if {[N c 14 x {}]} {emit {\b, version %d to extract}}
if {[N s 5 & 0x80]} {emit {\b, multiple volumes,}
if {[N c 17 x {}]} {emit {\b \(part %d\),}}
}
if {[N s 5 & 0x2]} {emit {\b, contains comment}}
if {[N s 5 & 0x200]} {emit {\b, sfx}}
if {[N s 5 & 0x400]} {emit {\b, small dictionary}}
if {[N s 5 & 0x800]} {emit {\b, multi-volume}}
if {[N s 5 & 0x1000]} {emit {\b, contains AV-String}}
if {[N s 5 & 0x2000]} {emit {\b, with recovery record}}
if {[N s 5 & 0x4000]} {emit {\b, locked}}
if {[N s 5 & 0x8000]} {emit {\b, solid}}
}
if {[S 26 == sfArk]} {emit {sfArk compressed Soundfont}
if {[S 21 == 2]} {if {[S 1 x {}]} {emit {Version %s}}
if {[S 42 x {}]} {emit {: %s}}
}
}
if {[S 0 == {Packed\ File\ }]} {emit {Personal		NetWare Packed File}
if {[S 12 x {}]} {emit {\b, was \"%.12s\"}}
}
if {[S 0 == *STA]} {emit Aster*x
if {[S 7 == WORD]} {emit {Words Document}}
if {[S 7 == GRAP]} {emit Graphic}
if {[S 7 == SPRE]} {emit Spreadsheet}
if {[S 7 == MACR]} {emit Macro}
}
if {[S 0 == 2278]} {emit {Aster*x Version 2}
switch -- [Nv c 29] 54 {emit {Words Document}} 53 {emit Graphic} 50 {emit Spreadsheet} 56 {emit Macro} 
}
if {[S 0 == {\000\004\036\212\200}]} {emit {3b2 core file}
if {[S 364 x {}]} {emit {of '%s'}}
}
if {[S 0 == .snd]} {emit {Sun/NeXT audio data:}
switch -- [Nv I 12] 1 {emit {8-bit ISDN mu-law,}} 2 {emit {8-bit linear PCM [REF-PCM],}} 3 {emit {16-bit linear PCM,}} 4 {emit {24-bit linear PCM,}} 5 {emit {32-bit linear PCM,}} 6 {emit {32-bit IEEE floating point,}} 7 {emit {64-bit IEEE floating point,}} 8 {emit {Fragmented sample data,}} 10 {emit {DSP program,}} 11 {emit {8-bit fixed point,}} 12 {emit {16-bit fixed point,}} 13 {emit {24-bit fixed point,}} 14 {emit {32-bit fixed point,}} 18 {emit {16-bit linear with emphasis,}} 19 {emit {16-bit linear compressed,}} 20 {emit {16-bit linear with emphasis and compression,}} 21 {emit {Music kit DSP commands,}} 23 {emit {8-bit ISDN mu-law compressed \(CCITT G.721 ADPCM voice data encoding\),}} 24 {emit {compressed \(8-bit CCITT G.722 ADPCM\)}} 25 {emit {compressed \(3-bit CCITT G.723.3 ADPCM\),}} 26 {emit {compressed \(5-bit CCITT G.723.5 ADPCM\),}} 27 {emit {8-bit A-law \(CCITT G.711\),}} 
switch -- [Nv I 20] 1 {emit mono,} 2 {emit stereo,} 4 {emit quad,} 
if {[N I 16 > 0x0]} {emit {%d Hz}}
}
if {[S 0 == MThd]} {emit {Standard MIDI data}
if {[N S 8 x {}]} {emit {\(format %d\)}}
if {[N S 10 x {}]} {emit {using %d track}}
if {[N S 10 > 0x1]} {emit {\bs}}
if {[N S 12 x {} &0x7fff]} {emit {at 1/%d}}
if {[N S 12 > 0x0 &0x8000]} {emit SMPTE}
}
if {[S 0 == CTMF]} {emit {Creative Music \(CMF\) data}}
if {[S 0 == SBI]} {emit {SoundBlaster instrument data}}
if {[S 0 == {Creative\ Voice\ File}]} {emit {Creative Labs voice data}
if {[N c 19 == 0x1a]} {emit 139 0}
if {[N c 23 > 0x0]} {emit {- version %d}}
if {[N c 22 > 0x0]} {emit {\b.%d}}
}
if {[S 0 == EMOD]} {emit {Extended MOD sound data,}
if {[N c 4 x {} &0xf0]} {emit {version %d}}
if {[N c 4 x {} &0x0f]} {emit {\b.%d,}}
if {[N c 45 x {}]} {emit {%d instruments}}
switch -- [Nv c 83] 0 {emit {\(module\)}} 1 {emit {\(song\)}} 
}
if {[S 0 == .RMF]} {emit {RealMedia file}}
if {[S 0 == MAS_U]} {emit {ULT\(imate\) Module sound data}}
if {[S 44 == SCRM]} {emit {ScreamTracker III Module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 0 == {GF1PATCH110\0ID\#000002\0}]} {emit {GUS patch}}
if {[S 0 == {GF1PATCH100\0ID\#000002\0}]} {emit {Old GUS	patch}}
if {[S 0 == MAS_UTrack_V00]} {if {[S 14 > /0]} {emit {ultratracker V1.%.1s module sound data}}
}
if {[S 0 == UN05]} {emit {MikMod UNI format module sound data}}
if {[S 0 == {Extended\ Module:}]} {emit {Fasttracker II module sound data}
if {[S 17 x {}]} {emit {Title: \"%s\"}}
}
if {[S 21 == !SCREAM! c]} {emit {Screamtracker 2 module sound data}}
if {[S 21 == BMOD2STM]} {emit {Screamtracker 2 module sound data}}
if {[S 1080 == M.K.]} {emit {4-channel Protracker module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 1080 == M!K!]} {emit {4-channel Protracker module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 1080 == FLT4]} {emit {4-channel Startracker module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 1080 == FLT8]} {emit {8-channel Startracker module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 1080 == 4CHN]} {emit {4-channel Fasttracker module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 1080 == 6CHN]} {emit {6-channel Fasttracker module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 1080 == 8CHN]} {emit {8-channel Fasttracker module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 1080 == CD81]} {emit {8-channel Octalyser module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 1080 == OKTA]} {emit {8-channel Oktalyzer module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 1080 == 16CN]} {emit {16-channel Taketracker module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 1080 == 32CN]} {emit {32-channel Taketracker module sound data}
if {[S 0 x {}]} {emit {Title: \"%s\"}}
}
if {[S 0 == TOC]} {emit {TOC sound file}}
if {[S 0 == {SIDPLAY\ INFOFILE}]} {emit {Sidplay info file}}
if {[S 0 == PSID]} {emit {PlaySID v2.2+ \(AMIGA\) sidtune}
if {[N S 4 > 0x0]} {emit {w/ header v%d,}}
if {[N S 14 == 0x1]} {emit {single song,}}
if {[N S 14 > 0x1]} {emit {%d songs,}}
if {[N S 16 > 0x0]} {emit {default song: %d}}
if {[S 22 x {}]} {emit {name: \"%s\"}}
if {[S 54 x {}]} {emit {author: \"%s\"}}
if {[S 86 x {}]} {emit {copyright: \"%s\"}}
}
if {[S 0 == RSID]} {emit {RSID sidtune PlaySID compatible}
if {[N S 4 > 0x0]} {emit {w/ header v%d,}}
if {[N S 14 == 0x1]} {emit {single song,}}
if {[N S 14 > 0x1]} {emit {%d songs,}}
if {[N S 16 > 0x0]} {emit {default song: %d}}
if {[S 22 x {}]} {emit {name: \"%s\"}}
if {[S 54 x {}]} {emit {author: \"%s\"}}
if {[S 86 x {}]} {emit {copyright: \"%s\"}}
}
if {[S 0 == {NIST_1A\n\ \ \ 1024\n}]} {emit {NIST SPHERE file}}
if {[S 0 == {SOUND\ SAMPLE\ DATA\ }]} {emit {Sample Vision file}}
if {[S 0 == 2BIT]} {emit {Audio Visual Research file,}
switch -- [Nv S 12] 0 {emit mono,} -1 {emit stereo,} 
if {[N S 14 x {}]} {emit {%d bits}}
switch -- [Nv S 16] 0 {emit unsigned,} -1 {emit signed,} 
if {[N I 22 x {} &0x00ffffff]} {emit {%d Hz,}}
switch -- [Nv S 18] 0 {emit {no loop,}} -1 {emit loop,} 
if {[N c 21 <= 0x7f]} {emit {note %d,}}
switch -- [Nv c 22] 0 {emit {replay 5.485 KHz}} 1 {emit {replay 8.084 KHz}} 2 {emit {replay 10.971 Khz}} 3 {emit {replay 16.168 Khz}} 4 {emit {replay 21.942 KHz}} 5 {emit {replay 32.336 KHz}} 6 {emit {replay 43.885 KHz}} 7 {emit {replay 47.261 KHz}} 
}
if {[S 0 == _SGI_SoundTrack]} {emit {SGI SoundTrack project file}}
if {[S 0 == ID3]} {emit {MP3 file with ID3 version 2.}
if {[N c 3 < 0xff]} {emit {\b%d.}}
if {[N c 4 < 0xff]} {emit {\b%d tag}}
}
if {[S 0 == {NESM\x1a}]} {emit {NES Sound File}
if {[S 14 x {}]} {emit {\(\"%s\" by}}
if {[S 46 x {}]} {emit {%s, copyright}}
if {[S 78 x {}]} {emit {%s\),}}
if {[N c 5 x {}]} {emit {version %d,}}
if {[N c 6 x {}]} {emit {%d tracks,}}
if {[N c 122 == 0x1 &0x2]} {emit {dual PAL/NTSC}}
switch -- [Nv c 122 &0x1] 1 {emit PAL} 0 {emit NTSC} 
}
if {[S 0 == IMPM]} {emit {Impulse Tracker module sound data -}
if {[S 4 x {}]} {emit {\"%s\"}}
if {[N s 40 != 0x0]} {emit {compatible w/ITv%x}}
if {[N s 42 != 0x0]} {emit {created w/ITv%x}}
}
if {[S 60 == IM10]} {emit {Imago Orpheus module sound data -}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 0 == IMPS]} {emit {Impulse Tracker Sample}
if {[N c 18 & 0x2]} {emit {16 bit}}
if {[N c 18 ^ 0x2]} {emit {8 bit}}
if {[N c 18 & 0x4]} {emit stereo}
if {[N c 18 ^ 0x4]} {emit mono}
}
if {[S 0 == IMPI]} {emit {Impulse Tracker Instrument}
if {[N s 28 != 0x0]} {emit ITv%x}
if {[N c 30 != 0x0]} {emit {%d samples}}
}
if {[S 0 == LM8953]} {emit {Yamaha TX Wave}
switch -- [Nv c 22] 73 {emit looped} -55 {emit non-looped} 
switch -- [Nv c 23] 1 {emit 33kHz} 2 {emit 50kHz} 3 {emit 16kHz} 
}
if {[S 76 == SCRS]} {emit {Scream Tracker Sample}
switch -- [Nv c 0] 1 {emit sample} 2 {emit {adlib melody}} 
if {[N c 0 > 0x2]} {emit {adlib drum}}
if {[N c 31 & 0x2]} {emit stereo}
if {[N c 31 ^ 0x2]} {emit mono}
if {[N c 31 & 0x4]} {emit {16bit little endian}}
if {[N c 31 ^ 0x4]} {emit 8bit}
switch -- [Nv c 30] 0 {emit unpacked} 1 {emit packed} 
}
if {[S 0 == MMD0]} {emit {MED music file, version 0}}
if {[S 0 == MMD1]} {emit {OctaMED Pro music file, version 1}}
if {[S 0 == MMD3]} {emit {OctaMED Soundstudio music file, version 3}}
if {[S 0 == OctaMEDCmpr]} {emit {OctaMED Soundstudio compressed file}}
if {[S 0 == MED]} {emit MED_Song}
if {[S 0 == SymM]} {emit {Symphonie SymMOD music file}}
if {[S 0 == THX]} {emit {AHX version}
switch -- [Nv c 3] 0 {emit {1 module data}} 1 {emit {2 module data}} 
}
if {[S 0 == OKTASONG]} {emit {Oktalyzer module data}}
if {[S 0 == {DIGI\ Booster\ module\0}]} {emit %s
if {[N c 20 > 0x0]} {emit %c
if {[N c 21 > 0x0]} {emit {\b%c}
if {[N c 22 > 0x0]} {emit {\b%c}
if {[N c 23 > 0x0]} {emit {\b%c}}
}
}
}
if {[S 610 x {}]} {emit {\b, \"%s\"}}
}
if {[S 0 == DBM0]} {emit {DIGI Booster Pro Module}
if {[N c 4 > 0x0]} {emit V%X.
if {[N c 5 x {}]} {emit {\b%02X}}
}
if {[S 16 x {}]} {emit {\b, \"%s\"}}
}
if {[S 0 == FTMN]} {emit {FaceTheMusic module}
if {[S 16 > {\0d}]} {emit {\b, \"%s\"}}
}
if {[S 0 == {AMShdr\32}]} {emit {Velvet Studio AMS Module v2.2}}
if {[S 0 == Extreme]} {emit {Extreme Tracker AMS Module v1.3}}
if {[S 0 == DDMF]} {emit {Xtracker DMF Module}
if {[N c 4 x {}]} {emit v%i}
if {[S 13 x {}]} {emit {Title: \"%s\"}}
if {[S 43 x {}]} {emit {Composer: \"%s\"}}
}
if {[S 0 == {DSM\32}]} {emit {Dynamic Studio Module DSM}}
if {[S 0 == SONG]} {emit {DigiTrekker DTM Module}}
if {[S 0 == DMDL]} {emit {DigiTrakker MDL Module}}
if {[S 0 == {PSM\32}]} {emit {Protracker Studio PSM Module}}
if {[S 44 == PTMF]} {emit {Poly Tracker PTM Module}
if {[S 0 > {\32}]} {emit {Title: \"%s\"}}
}
if {[S 0 == MT20]} {emit {MadTracker 2.0 Module MT2}}
if {[S 0 == {RAD\40by\40REALiTY!!}]} {emit {RAD Adlib Tracker Module RAD}}
if {[S 0 == RTMM]} {emit {RTM Module}}
if {[S 1062 == MaDoKaN96]} {emit {XMS Adlib Module}
if {[S 0 x {}]} {emit {Composer: \"%s\"}}
}
if {[S 0 == AMF]} {emit {AMF Module}
if {[S 4 x {}]} {emit {Title: \"%s\"}}
}
if {[S 0 == MODINFO1]} {emit {Open Cubic Player Module Inforation MDZ}}
if {[S 0 == {Extended\40Instrument:}]} {emit {Fast Tracker II Instrument}}
if {[S 0 == {\210NOA\015\012\032}]} {emit {NOA Nancy Codec Movie file}}
if {[S 0 == MMMD]} {emit {Yamaha SMAF file}}
if {[S 0 == {\001Sharp\040JisakuMelody}]} {emit {SHARP Cell-Phone ringing Melody}
if {[S 20 == Ver01.00]} {emit {Ver. 1.00}
if {[N c 32 x {}]} {emit {, %d tracks}}
}
}
if {[S 0 == fLaC]} {emit {FLAC audio bitstream data}
if {[N c 4 > 0x0 &0x7f]} {emit {\b, unknown version}}
if {[N c 4 == 0x0 &0x7f]} {emit {\b}
switch -- [Nv S 20 &0x1f0] 48 {emit {\b, 4 bit}} 80 {emit {\b, 6 bit}} 112 {emit {\b, 8 bit}} 176 {emit {\b, 12 bit}} 240 {emit {\b, 16 bit}} 368 {emit {\b, 24 bit}} 
switch -- [Nv c 20 &0xe] 0 {emit {\b, mono}} 2 {emit {\b, stereo}} 4 {emit {\b, 3 channels}} 6 {emit {\b, 4 channels}} 8 {emit {\b, 5 channels}} 10 {emit {\b, 6 channels}} 12 {emit {\b, 7 channels}} 14 {emit {\b, 8 channels}} 
switch -- [Nv I 17 &0xfffff0] 705600 {emit {\b, 44.1 kHz}} 768000 {emit {\b, 48 kHz}} 512000 {emit {\b, 32 kHz}} 352800 {emit {\b, 22.05 kHz}} 384000 {emit {\b, 24 kHz}} 256000 {emit {\b, 16 kHz}} 176400 {emit {\b, 11.025 kHz}} 192000 {emit {\b, 12 kHz}} 128000 {emit {\b, 8 kHz}} 1536000 {emit {\b, 96 kHz}} 1024000 {emit {\b, 64 kHz}} 
if {[N c 21 > 0x0 &0xf]} {emit {\b, >4G samples}}
if {[N c 21 == 0x0 &0xf]} {emit {\b}
if {[N I 22 > 0x0]} {emit {\b, %u samples}}
if {[N I 22 == 0x0]} {emit {\b, length unknown}}
}
}
}
if {[S 0 == VBOX]} {emit {VBOX voice message data}}
if {[S 8 == RB40]} {emit {RBS Song file}
if {[S 29 == ReBorn]} {emit {created by ReBorn}}
if {[S 37 == Propellerhead]} {emit {created by ReBirth}}
}
if {[S 0 == {A\#S\#C\#S\#S\#L\#V\#3}]} {emit {Synthesizer Generator or Kimwitu data}}
if {[S 0 == {A\#S\#C\#S\#S\#L\#HUB}]} {emit {Kimwitu++ data}}
if {[S 0 == TFMX-SONG]} {emit {TFMX module sound data}}
if {[S 0 == {MAC\	X/Monkey}]} {emit audio,
if {[N s 4 > 0x0]} {emit {version %d,}}
if {[N s 6 > 0x0]} {emit {compression level %d,}}
if {[N s 8 > 0x0]} {emit {flags %x,}}
if {[N s 10 > 0x0]} {emit {channels %d,}}
if {[N i 12 > 0x0]} {emit {samplerate %d,}}
if {[N i 24 > 0x0]} {emit {frames %d}}
}
if {[S 0 == bFLT]} {emit {BFLT executable}
if {[N I 4 x {}]} {emit {- version %ld}}
if {[N I 4 == 0x4]} {if {[N I 36 == 0x1 &0x1]} {emit ram}
if {[N I 36 == 0x2 &0x2]} {emit gotpic}
if {[N I 36 == 0x4 &0x4]} {emit gzip}
if {[N I 36 == 0x8 &0x8]} {emit gzdata}
}
}
if {[S 0 == BLENDER]} {emit Blender3D,
if {[S 7 == _]} {emit {saved as 32-bits}}
if {[S 7 == -]} {emit {saved as 64-bits}}
if {[S 8 == v]} {emit {little endian}}
if {[S 8 == V]} {emit {big endian}}
if {[N c 9 x {}]} {emit {with version %c.}}
if {[N c 10 x {}]} {emit {\b%c}}
if {[N c 11 x {}]} {emit {\b%c}}
}
if {[S 0 == !<bout>]} {emit {b.out archive}
if {[S 8 == __.SYMDEF]} {emit {random library}}
}
switch -- [Nv I 0 &077777777] 196875 {emit {sparc demand paged}
if {[N c 0 & 0x80]} {if {[N I 20 < 0x1000]} {emit {shared library}}
if {[N I 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N I 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
if {[N I 36 == 0xb4100001]} {emit {\(uses shared libs\)}}
} 196872 {emit {sparc pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
if {[N I 36 == 0xb4100001]} {emit {\(uses shared libs\)}}
} 196871 {emit sparc
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
if {[N I 36 == 0xb4100001]} {emit {\(uses shared libs\)}}
} 196875 {emit {sparc demand paged}
if {[N c 0 & 0x80]} {if {[N I 20 < 0x1000]} {emit {shared library}}
if {[N I 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N I 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 196872 {emit {sparc pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 196871 {emit sparc
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 131339 {emit {mc68020 demand paged}
if {[N c 0 & 0x80]} {if {[N I 20 < 0x1000]} {emit {shared library}}
if {[N I 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N I 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 131336 {emit {mc68020 pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 131335 {emit mc68020
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 65803 {emit {mc68010 demand paged}
if {[N c 0 & 0x80]} {if {[N I 20 < 0x1000]} {emit {shared library}}
if {[N I 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N I 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 65800 {emit {mc68010 pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 65799 {emit mc68010
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 
if {[S 0 == cscope]} {emit {cscope reference data}
if {[S 7 x {}]} {emit {version %.2s}}
if {[S 7 > 14]} {emit 218 1}
}
switch -- [Nv I 91392] 302072064 {emit {D64 Image}} 302072192 {emit {D71 Image}} 
if {[N I 399360 == 0x28034400]} {emit {D81 Image}}
if {[S 0 == {C64\40CARTRIDGE}]} {emit {CCS C64 Emultar Cartridge Image}}
if {[S 0 == GCR-1541]} {emit {GCR Image}
if {[N c 8 x {}]} {emit {version: $i}}
if {[N c 9 x {}]} {emit {tracks: %i}}
}
if {[S 9 == PSUR]} {emit {ARC archive \(c64\)}}
if {[S 2 == -LH1-]} {emit {LHA archive \(c64\)}}
if {[S 0 == C64File]} {emit {PC64 Emulator file}
if {[S 8 x {}]} {emit {\"%s\"}}
}
if {[S 0 == C64Image]} {emit {PC64 Freezer Image}}
if {[S 0 == {CBM\144\0\0}]} {emit {Power 64 C64 Emulator Snapshot}}
if {[S 0 == {\101\103\061\060\061}]} {emit AutoCAD
if {[S 5 == {\062\000\000\000\000}]} {emit {DWG ver. R13}}
if {[S 5 == {\064\000\000\000\000}]} {emit {DWG ver. R14}}
}
if {[S 0 == {\010\011\376}]} {emit Microstation
if {[S 3 == {\002}]} {if {[S 30 == {\372\104}]} {emit {DGN File}}
if {[S 30 == {\172\104}]} {emit {DGN File}}
if {[S 30 == {\026\105}]} {emit {DGN File}}
}
if {[S 4 == {\030\000\000}]} {emit {CIT File}}
}
if {[S 0 == AC1012]} {emit {AutoCad \(release 12\)}}
if {[S 0 == AC1014]} {emit {AutoCad \(release 14\)}}
if {[S 0 == {\#\040xmcd} b]} {emit {CDDB\(tm\) format CD text data}}
if {[S 0 == {\\1cw\ }]} {emit {ChiWriter file}
if {[S 5 x {}]} {emit {version %s}}
}
if {[S 0 == {\\1cw}]} {emit {ChiWriter file}}
if {[S 0 == {\{title}]} {emit {Chord text file}}
if {[S 0 == RuneCT]} {emit {Citrus locale declaration for LC_CTYPE}}
if {[S 514 == {\377\377\377\377\000}]} {emit {Claris clip art?}
if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0}]} {emit yes.}
}
if {[S 514 == {\377\377\377\377\001}]} {emit {Claris clip art?}
if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0}]} {emit yes.}
}
if {[S 0 == {\002\000\210\003\102\117\102\117\000\001\206}]} {emit {Claris works document}}
if {[S 0 == {\020\341\000\000\010\010}]} {emit {Claris Works pallete files .plt}}
if {[S 0 == {\002\271\262\000\040\002\000\164}]} {emit {Claris works dictionary}}
if {[S 0 == GRG]} {emit {Gringotts data file}
if {[S 3 == 1]} {emit {v.1, MCRYPT S2K, SERPENT crypt, SHA-256 hash, ZLib lvl.9}}
if {[S 3 == 2]} {emit {v.2, MCRYPT S2K,}
switch -- [Nv c 8 &0x70] 0 {emit {RIJNDAEL-128 crypt,}} 16 {emit {SERPENT crypt,}} 32 {emit {TWOFISH crypt,}} 48 {emit {CAST-256 crypt,}} 64 {emit {SAFER+ crypt,}} 80 {emit {LOKI97 crypt,}} 96 {emit {3DES crypt,}} 112 {emit {RIJNDAEL-256 crypt,}} 
switch -- [Nv c 8 &0x08] 0 {emit {SHA1 hash,}} 8 {emit {RIPEMD-160 hash,}} 
switch -- [Nv c 8 &0x04] 0 {emit ZLib} 4 {emit BZip2} 
switch -- [Nv c 8 &0x03] 0 {emit lvl.0} 1 {emit lvl.3} 2 {emit lvl.6} 3 {emit lvl.9} 
}
if {[S 3 == 3]} {emit {v.3, OpenPGP S2K,}
switch -- [Nv c 8 &0x70] 0 {emit {RIJNDAEL-128 crypt,}} 16 {emit {SERPENT crypt,}} 32 {emit {TWOFISH crypt,}} 48 {emit {CAST-256 crypt,}} 64 {emit {SAFER+ crypt,}} 80 {emit {LOKI97 crypt,}} 96 {emit {3DES crypt,}} 112 {emit {RIJNDAEL-256 crypt,}} 
switch -- [Nv c 8 &0x08] 0 {emit {SHA1 hash,}} 8 {emit {RIPEMD-160 hash,}} 
switch -- [Nv c 8 &0x04] 0 {emit ZLib} 4 {emit BZip2} 
switch -- [Nv c 8 &0x03] 0 {emit lvl.0} 1 {emit lvl.3} 2 {emit lvl.6} 3 {emit lvl.9} 
}
if {[S 3 > 3]} {emit {v.%.1s \(unknown details\)}}
}
if {[S 0 == :]} {emit {shell archive or script for antique kernel text}}
if {[S 0 == {\#!\ /bin/sh} b]} {emit {Bourne shell script text executable}}
if {[S 0 == {\#!\ /bin/csh} b]} {emit {C shell script text executable}}
if {[S 0 == {\#!\ /bin/ksh} b]} {emit {Korn shell script text executable}}
if {[S 0 == {\#!\ /bin/tcsh} b]} {emit {Tenex C shell script text executable}}
if {[S 0 == {\#!\ /usr/local/tcsh} b]} {emit {Tenex C shell script text executable}}
if {[S 0 == {\#!\ /usr/local/bin/tcsh} b]} {emit {Tenex C shell script text executable}}
if {[S 0 == {\#!\ /bin/zsh} b]} {emit {Paul Falstad's zsh script text executable}}
if {[S 0 == {\#!\ /usr/bin/zsh} b]} {emit {Paul Falstad's zsh script text executable}}
if {[S 0 == {\#!\ /usr/local/bin/zsh} b]} {emit {Paul Falstad's zsh script text executable}}
if {[S 0 == {\#!\ /usr/local/bin/ash} b]} {emit {Neil Brown's ash script text executable}}
if {[S 0 == {\#!\ /usr/local/bin/ae} b]} {emit {Neil Brown's ae script text executable}}
if {[S 0 == {\#!\ /bin/nawk} b]} {emit {new awk script text executable}}
if {[S 0 == {\#!\ /usr/bin/nawk} b]} {emit {new awk script text executable}}
if {[S 0 == {\#!\ /usr/local/bin/nawk} b]} {emit {new awk script text executable}}
if {[S 0 == {\#!\ /bin/gawk} b]} {emit {GNU awk script text executable}}
if {[S 0 == {\#!\ /usr/bin/gawk} b]} {emit {GNU awk script text executable}}
if {[S 0 == {\#!\ /usr/local/bin/gawk} b]} {emit {GNU awk script text executable}}
if {[S 0 == {\#!\ /bin/awk} b]} {emit {awk script text executable}}
if {[S 0 == {\#!\ /usr/bin/awk} b]} {emit {awk script text executable}}
if {[S 0 == BEGIN]} {emit {awk script text}}
if {[S 0 == {\#!\ /bin/rc} b]} {emit {Plan 9 rc shell script text executable}}
if {[S 0 == {\#!\ /bin/bash} b]} {emit {Bourne-Again shell script text executable}}
if {[S 0 == {\#!\ /usr/local/bin/bash} b]} {emit {Bourne-Again shell script text executable}}
if {[S 0 == {\#!/usr/bin/env}]} {emit a
if {[S 15 x {}]} {emit {%s script text executable}}
}
if {[S 0 == {\#!\ /usr/bin/env}]} {emit a
if {[S 16 x {}]} {emit {%s script text executable}}
}
if {[S 0 == <?php c]} {emit {PHP script text}}
if {[S 0 == {<?\n}]} {emit {PHP script text}}
if {[S 0 == {<?\r}]} {emit {PHP script text}}
if {[S 0 == {\#!\ /usr/local/bin/php} b]} {emit {PHP script text executable}}
if {[S 0 == {\#!\ /usr/bin/php} b]} {emit {PHP script text executable}}
if {[S 0 == {Zend\x00}]} {emit {PHP script Zend Optimizer data}}
if {[Sx 1 0 == {$Suite}]} {emit {TTCN Abstract Test Suite}
if {[Sx 2 [R 1] == {$SuiteId}]} {if {[S [R 1] > {\n}]} {emit %s}
}
L 1;if {[Sx 2 [R 2] == {$SuiteId}]} {if {[S [R 1] > {\n}]} {emit %s}
}
L 1;if {[Sx 2 [R 3] == {$SuiteId}]} {if {[S [R 1] > {\n}]} {emit %s}
}
}
if {[S 0 == mscdocument]} {emit {Message Sequence Chart \(document\)}}
if {[S 0 == msc]} {emit {Message Sequence Chart \(chart\)}}
if {[S 0 == submsc]} {emit {Message Sequence Chart \(subchart\)}}
if {[S 0 == {\037\235}]} {emit {compress'd data}
if {[N c 2 > 0x0 &0x80]} {emit {block compressed}}
if {[N c 2 x {} &0x1f]} {emit {%d bits}}
}
if {[S 0 == {\037\213}]} {emit {gzip compressed data}
if {[N c 2 < 0x8]} {emit {\b, reserved method}}
if {[N c 2 > 0x8]} {emit {\b, unknown method}}
if {[N c 3 & 0x1]} {emit {\b, ASCII}}
if {[N c 3 & 0x2]} {emit {\b, continuation}}
if {[N c 3 & 0x4]} {emit {\b, extra field}}
if {[N c 3 == 0x8 &0xC]} {if {[S 10 x {}]} {emit {\b, was \"%s\"}}
}
switch -- [Nv c 9] 0 {emit {\b, from MS-DOS}} 1 {emit {\b, from Amiga}} 2 {emit {\b, from VMS}} 3 {emit {\b, from Unix}} 5 {emit {\b, from Atari}} 6 {emit {\b, from OS/2}} 7 {emit {\b, from MacOS}} 10 {emit {\b, from Tops/20}} 11 {emit {\b, from Win/32}} 
if {[N c 3 & 0x10]} {emit {\b, comment}}
if {[N c 3 & 0x20]} {emit {\b, encrypted}}
switch -- [Nv c 8] 2 {emit {\b, max compression}} 4 {emit {\b, max speed}} 
}
if {[S 0 == {\037\036}]} {emit {packed data}
if {[N I 2 > 0x1]} {emit {\b, %d characters originally}}
if {[N I 2 == 0x1]} {emit {\b, %d character originally}}
}
if {[S 0 == {\377\037}]} {emit {compacted data}}
if {[S 0 == BZh]} {emit {bzip2 compressed data}
if {[N c 3 > 0x2f]} {emit {\b, block size = %c00k}}
}
if {[S 0 == {\037\237}]} {emit {frozen file 2.1}}
if {[S 0 == {\037\236}]} {emit {frozen file 1.0 \(or gzip 0.5\)}}
if {[S 0 == {\037\240}]} {emit {SCO compress -H \(LZH\) data}}
if {[S 0 == BZ]} {emit {bzip compressed data}
if {[N c 2 x {}]} {emit {\b, version: %c}}
if {[S 3 == 1]} {emit {\b, compression block size 100k}}
if {[S 3 == 2]} {emit {\b, compression block size 200k}}
if {[S 3 == 3]} {emit {\b, compression block size 300k}}
if {[S 3 == 4]} {emit {\b, compression block size 400k}}
if {[S 3 == 5]} {emit {\b, compression block size 500k}}
if {[S 3 == 6]} {emit {\b, compression block size 600k}}
if {[S 3 == 7]} {emit {\b, compression block size 700k}}
if {[S 3 == 8]} {emit {\b, compression block size 800k}}
if {[S 3 == 9]} {emit {\b, compression block size 900k}}
}
if {[S 0 == {\x89\x4c\x5a\x4f\x00\x0d\x0a\x1a\x0a}]} {emit {lzop compressed data}
if {[N S 9 < 0x940]} {if {[N c 9 == 0x0 &0xf0]} {emit {- version 0.}}
if {[N S 9 x {} &0x0fff]} {emit {\b%03x,}}
switch -- [Nv c 13] 1 {emit LZO1X-1,} 2 {emit {LZO1X-1\(15\),}} 3 {emit LZO1X-999,} 
switch -- [Nv c 14] 0 {emit {os: MS-DOS}} 1 {emit {os: Amiga}} 2 {emit {os: VMS}} 3 {emit {os: Unix}} 5 {emit {os: Atari}} 6 {emit {os: OS/2}} 7 {emit {os: MacOS}} 10 {emit {os: Tops/20}} 11 {emit {os: WinNT}} 14 {emit {os: Win32}} 
}
if {[N S 9 > 0x939]} {switch -- [Nv c 9 &0xf0] 0 {emit {- version 0.}} 16 {emit {- version 1.}} 32 {emit {- version 2.}} 
if {[N S 9 x {} &0x0fff]} {emit {\b%03x,}}
switch -- [Nv c 15] 1 {emit LZO1X-1,} 2 {emit {LZO1X-1\(15\),}} 3 {emit LZO1X-999,} 
switch -- [Nv c 17] 0 {emit {os: MS-DOS}} 1 {emit {os: Amiga}} 2 {emit {os: VMS}} 3 {emit {os: Unix}} 5 {emit {os: Atari}} 6 {emit {os: OS/2}} 7 {emit {os: MacOS}} 10 {emit {os: Tops/20}} 11 {emit {os: WinNT}} 14 {emit {os: Win32}} 
}
}
if {[S 0 == {\037\241}]} {emit {Quasijarus strong compressed data}}
if {[S 0 == XPKF]} {emit {Amiga xpkf.library compressed data}}
if {[S 0 == PP11]} {emit {Power Packer 1.1 compressed data}}
if {[S 0 == PP20]} {emit {Power Packer 2.0 compressed data,}
switch -- [Nv I 4] 151587081 {emit {fast compression}} 151652874 {emit {mediocre compression}} 151653131 {emit {good compression}} 151653388 {emit {very good compression}} 151653389 {emit {best compression}} 
}
if {[S 0 == {7z\274\257\047\034}]} {emit {7z archive data,}
if {[N c 6 x {}]} {emit {version %d}}
if {[N c 7 x {}]} {emit {\b.%d}}
}
if {[S 2 == -afx-]} {emit {AFX compressed file data}}
if {[S 0 == {NES\032}]} {emit {iNES ROM dump,}
if {[N c 4 x {}]} {emit {%dx16k PRG}}
if {[N c 5 x {}]} {emit {\b, %dx8k CHR}}
switch -- [Nv c 6 &0x01] 1 {emit {\b, [Vert.]}} 0 {emit {\b, [Horiz.]}} 
if {[N c 6 == 0x2 &0x02]} {emit {\b, [SRAM]}}
switch -- [Nv c 6 &0x04] 4 {emit {\b, [Trainer]}} 8 {emit {\b, [4-Scr]}} 
}
if {[N I 260 == 0xceed6666]} {emit {Gameboy ROM:}
if {[S 308 x {}]} {emit {\"%.16s\"}}
if {[N c 326 == 0x3]} {emit {\b,[SGB]}}
switch -- [Nv c 327] 0 {emit {\b, [ROM ONLY]}} 1 {emit {\b, [ROM+MBC1]}} 2 {emit {\b, [ROM+MBC1+RAM]}} 3 {emit {\b, [ROM+MBC1+RAM+BATT]}} 5 {emit {\b, [ROM+MBC2]}} 6 {emit {\b, [ROM+MBC2+BATTERY]}} 8 {emit {\b, [ROM+RAM]}} 9 {emit {\b, [ROM+RAM+BATTERY]}} 11 {emit {\b, [ROM+MMM01]}} 12 {emit {\b, [ROM+MMM01+SRAM]}} 13 {emit {\b, [ROM+MMM01+SRAM+BATT]}} 15 {emit {\b, [ROM+MBC3+TIMER+BATT]}} 16 {emit {\b, [ROM+MBC3+TIMER+RAM+BATT]}} 17 {emit {\b, [ROM+MBC3]}} 18 {emit {\b, [ROM+MBC3+RAM]}} 19 {emit {\b, [ROM+MBC3+RAM+BATT]}} 25 {emit {\b, [ROM+MBC5]}} 26 {emit {\b, [ROM+MBC5+RAM]}} 27 {emit {\b, [ROM+MBC5+RAM+BATT]}} 28 {emit {\b, [ROM+MBC5+RUMBLE]}} 29 {emit {\b, [ROM+MBC5+RUMBLE+SRAM]}} 30 {emit {\b, [ROM+MBC5+RUMBLE+SRAM+BATT]}} 31 {emit {\b, [Pocket Camera]}} -3 {emit {\b, [Bandai TAMA5]}} -2 {emit {\b, [Hudson HuC-3]}} -1 {emit {\b, [Hudson HuC-1]}} 
switch -- [Nv c 328] 0 {emit {\b, ROM: 256Kbit}} 1 {emit {\b, ROM: 512Kbit}} 2 {emit {\b, ROM: 1Mbit}} 3 {emit {\b, ROM: 2Mbit}} 4 {emit {\b, ROM: 4Mbit}} 5 {emit {\b, ROM: 8Mbit}} 6 {emit {\b, ROM: 16Mbit}} 82 {emit {\b, ROM: 9Mbit}} 83 {emit {\b, ROM: 10Mbit}} 84 {emit {\b, ROM: 12Mbit}} 
switch -- [Nv c 329] 1 {emit {\b, RAM: 16Kbit}} 2 {emit {\b, RAM: 64Kbit}} 3 {emit {\b, RAM: 128Kbit}} 4 {emit {\b, RAM: 1Mbit}} 
}
if {[S 256 == SEGA]} {emit {Sega MegaDrive/Genesis raw ROM dump}
if {[S 288 x {}]} {emit {Name: \"%.16s\"}}
if {[S 272 x {}]} {emit %.16s}
if {[S 432 == RA]} {emit {with SRAM}}
}
if {[S 640 == EAGN]} {emit {Super MagicDrive ROM dump}
if {[N c 0 x {}]} {emit {%dx16k blocks}}
if {[N c 2 == 0x0]} {emit {\b, last in series or standalone}}
if {[N c 2 > 0x0]} {emit {\b, split ROM}}
if {[N c 8 == 0xaa]} {emit 298 3}
if {[N c 9 == 0xbb]} {emit 298 4}
}
if {[S 640 == EAMG]} {emit {Super MagicDrive ROM dump}
if {[N c 0 x {}]} {emit {%dx16k blocks}}
if {[N c 2 x {}]} {emit {\b, last in series or standalone}}
if {[N c 8 == 0xaa]} {emit 299 2}
if {[N c 9 == 0xbb]} {emit 299 3}
}
if {[S 0 == LCDi]} {emit {Dream Animator file}}
if {[S 0 == {PS-X\ EXE}]} {emit {Sony Playstation executable}
if {[S 113 x {}]} {emit {\(%s\)}}
}
if {[S 0 == XBEH]} {emit {XBE, Microsoft Xbox executable}
if {[Nx 2 i 4 == 0x0]} {if {[Nx 3 i [R 2] == 0x0]} {if {[N i [R 2] == 0x0]} {emit {\b, not signed}}
}
}
if {[Nx 2 i 4 > 0x0]} {if {[Nx 3 i [R 2] > 0x0]} {if {[N i [R 2] > 0x0]} {emit {\b, signed}}
}
}
if {[N i 260 == 0x10000]} {if {[N i [I 280 Q -65376] == 0x80000007 &0x80000007]} {emit {\b, all regions}}
if {[N i [I 280 Q -65376] != 0x80000007 &0x80000007]} {if {[N i [I 280 Q -65376] > 0x0]} {emit {\(regions:}
if {[N i [I 280 Q -65376] & 0x1]} {emit NA}
if {[N i [I 280 Q -65376] & 0x2]} {emit Japan}
if {[N i [I 280 Q -65376] & 0x4]} {emit Rest_of_World}
if {[N i [I 280 Q -65376] & 0x80000000]} {emit Manufacturer}
}
if {[N i [I 280 Q -65376] > 0x0]} {emit {\b\)}}
}
}
}
if {[S 0 == XIP0]} {emit {XIP, Microsoft Xbox data}}
if {[S 0 == XTF0]} {emit {XTF, Microsoft Xbox data}}
if {[S 0 == Glul]} {emit {Glulx game data}
if {[S 8 == IFRS]} {emit {\b, Blorb Interactive Fiction}
if {[S 24 == Exec]} {emit {with executable chunk}}
}
if {[S 8 == IFZS]} {emit {\b, Z-machine or Glulx saved game file \(Quetzal\)}}
}
switch -- [Nv I 24] 60011 {emit {dump format, 4.1 BSD or earlier}} 60012 {emit {dump format, 4.2 or 4.3 BSD without IDC}} 60013 {emit {dump format, 4.2 or 4.3 BSD \(IDC compatible\)}} 60014 {emit {dump format, Convex Storage Manager by-reference dump}} 60012 {emit {new-fs dump file \(big endian\),}
if {[N S 4 x {}]} {emit {Previous dump %s,}}
if {[N S 8 x {}]} {emit {This dump %s,}}
if {[N I 12 > 0x0]} {emit {Volume %ld,}}
if {[N I 692 == 0x0]} {emit {Level zero, type:}}
if {[N I 692 > 0x0]} {emit {Level %d, type:}}
switch -- [Nv I 0] 1 {emit {tape header,}} 2 {emit {beginning of file record,}} 3 {emit {map of inodes on tape,}} 4 {emit {continuation of file record,}} 5 {emit {end of volume,}} 6 {emit {map of inodes deleted,}} 7 {emit {end of medium \(for floppy\),}} 
if {[S 676 x {}]} {emit {Label %s,}}
if {[S 696 x {}]} {emit {Filesystem %s,}}
if {[S 760 x {}]} {emit {Device %s,}}
if {[S 824 x {}]} {emit {Host %s,}}
if {[N I 888 > 0x0]} {emit {Flags %x}}
} 60011 {emit {old-fs dump file \(big endian\),}
if {[N I 12 > 0x0]} {emit {Volume %ld,}}
if {[N I 692 == 0x0]} {emit {Level zero, type:}}
if {[N I 692 > 0x0]} {emit {Level %d, type:}}
switch -- [Nv I 0] 1 {emit {tape header,}} 2 {emit {beginning of file record,}} 3 {emit {map of inodes on tape,}} 4 {emit {continuation of file record,}} 5 {emit {end of volume,}} 6 {emit {map of inodes deleted,}} 7 {emit {end of medium \(for floppy\),}} 
if {[S 676 x {}]} {emit {Label %s,}}
if {[S 696 x {}]} {emit {Filesystem %s,}}
if {[S 760 x {}]} {emit {Device %s,}}
if {[S 824 x {}]} {emit {Host %s,}}
if {[N I 888 > 0x0]} {emit {Flags %x}}
} 
if {[S 0 == !_TAG]} {emit {Exuberant Ctags tag file text}}
if {[S 0 == GDBM]} {emit {GNU dbm 2.x database}}
switch -- [Nv Q 12] 398689 {emit {Berkeley DB}
if {[N Q 16 > 0x0]} {emit {\(Hash, version %d, native byte-order\)}}
} 340322 {emit {Berkeley DB}
if {[N Q 16 > 0x0]} {emit {\(Btree, version %d, native byte-order\)}}
} 270931 {emit {Berkeley DB}
if {[N Q 16 > 0x0]} {emit {\(Queue, version %d, native byte-order\)}}
} 264584 {emit {Berkeley DB}
if {[N Q 16 > 0x0]} {emit {\(Log, version %d, native byte-order\)}}
} 
switch -- [Nv I 12] 398689 {emit {Berkeley DB}
if {[N I 16 > 0x0]} {emit {\(Hash, version %d, big-endian\)}}
} 340322 {emit {Berkeley DB}
if {[N I 16 > 0x0]} {emit {\(Btree, version %d, big-endian\)}}
} 270931 {emit {Berkeley DB}
if {[N I 16 > 0x0]} {emit {\(Queue, version %d, big-endian\)}}
} 264584 {emit {Berkeley DB}
if {[N I 16 > 0x0]} {emit {\(Log, version %d, big-endian\)}}
} 
switch -- [Nv i 12] 398689 {emit {Berkeley DB}
if {[N i 16 > 0x0]} {emit {\(Hash, version %d, little-endian\)}}
} 340322 {emit {Berkeley DB}
if {[N i 16 > 0x0]} {emit {\(Btree, version %d, little-endian\)}}
} 270931 {emit {Berkeley DB}
if {[N i 16 > 0x0]} {emit {\(Queue, version %d, little-endian\)}}
} 264584 {emit {Berkeley DB}
if {[N i 16 > 0x0]} {emit {\(Log, version %d, little-endian\)}}
} 
if {[S 0 == RRD]} {emit {RRDTool DB}
if {[S 4 x {}]} {emit {version %s}}
}
if {[S 0 == {root\0}]} {emit {ROOT file}
if {[N I 4 x {}]} {emit {Version %d}}
if {[N I 33 x {}]} {emit {\(Compression: %d\)}}
}
if {[S 4 == {Standard\ Jet\ DB}]} {emit {Microsoft Access Database}}
if {[S 0 == {TDB\ file}]} {emit {TDB database}
if {[N i 32 == 0x2601196d]} {emit {version 6, little-endian}
if {[N i 36 x {}]} {emit {hash size %d bytes}}
}
}
if {[S 2 == ICE]} {emit {ICE authority data}}
if {[S 10 == MIT-MAGIC-COOKIE-1]} {emit {X11 Xauthority data}}
if {[S 11 == MIT-MAGIC-COOKIE-1]} {emit {X11 Xauthority data}}
if {[S 12 == MIT-MAGIC-COOKIE-1]} {emit {X11 Xauthority data}}
if {[S 13 == MIT-MAGIC-COOKIE-1]} {emit {X11 Xauthority data}}
if {[S 14 == MIT-MAGIC-COOKIE-1]} {emit {X11 Xauthority data}}
if {[S 15 == MIT-MAGIC-COOKIE-1]} {emit {X11 Xauthority data}}
if {[S 16 == MIT-MAGIC-COOKIE-1]} {emit {X11 Xauthority data}}
if {[S 17 == MIT-MAGIC-COOKIE-1]} {emit {X11 Xauthority data}}
if {[S 18 == MIT-MAGIC-COOKIE-1]} {emit {X11 Xauthority data}}
if {[S 0 == {<list>\n<protocol\ bbn-m}]} {emit {Diamond Multimedia Document}}
if {[S 0 == {diff\ }]} {emit {'diff' output text}}
if {[S 0 == {***\ }]} {emit {'diff' output text}}
if {[S 0 == {Only\ in\ }]} {emit {'diff' output text}}
if {[S 0 == {Common\ subdirectories:\ }]} {emit {'diff' output text}}
if {[S 0 == {!<arch>\n________64E}]} {emit {Alpha archive}
if {[S 22 == X]} {emit {-- out of date}}
}
if {[S 0 == {\377\377\177}]} {emit ddis/ddif}
if {[S 0 == {\377\377\174}]} {emit {ddis/dots archive}}
if {[S 0 == {\377\377\176}]} {emit {ddis/dtif table data}}
if {[S 0 == {\033c\033}]} {emit {LN03 output}}
if {[S 0 == {!<PDF>!\n}]} {emit {profiling data file}}
switch -- [Nv i 24] 60012 {emit {new-fs dump file \(little endian\),}
if {[N s 4 x {}]} {emit {This dump %s,}}
if {[N s 8 x {}]} {emit {Previous dump %s,}}
if {[N i 12 > 0x0]} {emit {Volume %ld,}}
if {[N i 692 == 0x0]} {emit {Level zero, type:}}
if {[N i 692 > 0x0]} {emit {Level %d, type:}}
switch -- [Nv i 0] 1 {emit {tape header,}} 2 {emit {beginning of file record,}} 3 {emit {map of inodes on tape,}} 4 {emit {continuation of file record,}} 5 {emit {end of volume,}} 6 {emit {map of inodes deleted,}} 7 {emit {end of medium \(for floppy\),}} 
if {[S 676 x {}]} {emit {Label %s,}}
if {[S 696 x {}]} {emit {Filesystem %s,}}
if {[S 760 x {}]} {emit {Device %s,}}
if {[S 824 x {}]} {emit {Host %s,}}
if {[N i 888 > 0x0]} {emit {Flags %x}}
} 60011 {emit {old-fs dump file \(little endian\),}
if {[N i 12 > 0x0]} {emit {Volume %ld,}}
if {[N i 692 == 0x0]} {emit {Level zero, type:}}
if {[N i 692 > 0x0]} {emit {Level %d, type:}}
switch -- [Nv i 0] 1 {emit {tape header,}} 2 {emit {beginning of file record,}} 3 {emit {map of inodes on tape,}} 4 {emit {continuation of file record,}} 5 {emit {end of volume,}} 6 {emit {map of inodes deleted,}} 7 {emit {end of medium \(for floppy\),}} 
if {[S 676 x {}]} {emit {Label %s,}}
if {[S 696 x {}]} {emit {Filesystem %s,}}
if {[S 760 x {}]} {emit {Device %s,}}
if {[S 824 x {}]} {emit {Host %s,}}
if {[N i 888 > 0x0]} {emit {Flags %x}}
} 
switch -- [Nv c 0] -86 {emit {}
if {[N c 1 < 0x4]} {emit {Dyalog APL}
switch -- [Nv c 1] 0 {emit {incomplete workspace}} 1 {emit {component file}} 2 {emit {external variable}} 3 {emit workspace} 
if {[N c 2 x {}]} {emit {version %d}}
if {[N c 3 x {}]} {emit .%d}
}
} 3 {emit {DBase 3 data file}
if {[N i 4 == 0x0]} {emit {\(no records\)}}
if {[N i 4 > 0x0]} {emit {\(%ld records\)}}
} -125 {emit {DBase 3 data file with memo\(s\)}
if {[N i 4 == 0x0]} {emit {\(no records\)}}
if {[N i 4 > 0x0]} {emit {\(%ld records\)}}
} 38 {emit {Sendmail frozen configuration}
if {[S 16 x {}]} {emit {- version %s}}
} -16 {emit {SysEx File -}
switch -- [Nv c 1] 1 {emit Sequential} 2 {emit IDP} 3 {emit OctavePlateau} 4 {emit Moog} 5 {emit Passport} 6 {emit Lexicon} 7 {emit Kurzweil} 8 {emit Fender} 9 {emit Gulbransen} 10 {emit AKG} 11 {emit Voyce} 12 {emit Waveframe} 13 {emit ADA} 14 {emit Garfield} 15 {emit Ensoniq} 16 {emit Oberheim} 17 {emit Apple} 18 {emit GreyMatter} 20 {emit PalmTree} 21 {emit JLCooper} 22 {emit Lowrey} 23 {emit AdamsSmith} 24 {emit E-mu} 25 {emit Harmony} 26 {emit ART} 27 {emit Baldwin} 28 {emit Eventide} 29 {emit Inventronics} 31 {emit Clarity} 33 {emit SIEL} 34 {emit Synthaxe} 36 {emit Hohner} 37 {emit Twister} 38 {emit Solton} 39 {emit Jellinghaus} 40 {emit Southworth} 41 {emit PPG} 42 {emit JEN} 43 {emit SSL} 44 {emit AudioVertrieb} 47 {emit ELKA
if {[N c 3 == 0x9]} {emit EK-44}
} 48 {emit Dynacord} 51 {emit Clavia} 57 {emit Soundcraft} 62 {emit Waldorf
if {[N c 3 == 0x7f]} {emit {Microwave I}}
} 64 {emit Kawai
switch -- [Nv c 3] 32 {emit K1} 34 {emit K4} 
} 65 {emit Roland
switch -- [Nv c 3] 20 {emit D-50} 43 {emit U-220} 2 {emit TR-707} 
} 66 {emit Korg
if {[N c 3 == 0x19]} {emit M1}
} 67 {emit Yamaha} 68 {emit Casio} 70 {emit Kamiya} 71 {emit Akai} 72 {emit Victor} 73 {emit Mesosha} 75 {emit Fujitsu} 76 {emit Sony} 78 {emit Teac} 80 {emit Matsushita} 81 {emit Fostex} 82 {emit Zoom} 84 {emit Matsushita} 87 {emit {Acoustic tech. lab.}} 
switch -- [Nv I 1 &0xffffff00] 29696 {emit {Ta Horng}} 29952 {emit e-Tek} 30208 {emit E-Voice} 30464 {emit Midisoft} 30720 {emit Q-Sound} 30976 {emit Westrex} 31232 {emit Nvidia*} 31488 {emit ESS} 31744 {emit Mediatrix} 32000 {emit Brooktree} 32256 {emit Otari} 32512 {emit {Key Electronics}} 65536 {emit Shure} 65792 {emit AuraSound} 66048 {emit Crystal} 66304 {emit Rockwell} 66560 {emit {Silicon Graphics}} 66816 {emit Midiman} 67072 {emit PreSonus} 67584 {emit Topaz} 67840 {emit {Cast Lightning}} 68096 {emit Microsoft} 68352 {emit {Sonic Foundry}} 68608 {emit {Line 6}} 68864 {emit {Beatnik Inc.}} 69120 {emit {Van Koerving}} 69376 {emit {Altech Systems}} 69632 {emit {S & S Research}} 69888 {emit {VLSI Technology}} 70144 {emit Chromatic} 70400 {emit Sapphire} 70656 {emit IDRC} 70912 {emit {Justonic Tuning}} 71168 {emit TorComp} 71424 {emit {Newtek Inc.}} 71680 {emit {Sound Sculpture}} 71936 {emit {Walker Technical}} 72192 {emit {Digital Harmony}} 72448 {emit InVision} 72704 {emit T-Square} 72960 {emit Nemesys} 73216 {emit DBX} 73472 {emit Syndyne} 73728 {emit {Bitheadz	}} 73984 {emit Cakewalk} 74240 {emit Staccato} 74496 {emit {National Semicon.}} 74752 {emit {Boom Theory}} 75008 {emit {Virtual DSP Corp}} 75264 {emit Antares} 75520 {emit {Angel Software}} 75776 {emit {St Louis Music}} 76032 {emit {Lyrrus dba G-VOX}} 76288 {emit {Ashley Audio}} 76544 {emit Vari-Lite} 76800 {emit {Summit Audio}} 77056 {emit {Aureal Semicon.}} 77312 {emit SeaSound} 77568 {emit {U.S. Robotics}} 77824 {emit Aurisis} 78080 {emit {Nearfield Multimedia}} 78336 {emit {FM7 Inc.}} 78592 {emit {Swivel Systems}} 78848 {emit Hyperactive} 79104 {emit MidiLite} 79360 {emit Radical} 79616 {emit {Roger Linn}} 79872 {emit Helicon} 80128 {emit Event} 80384 {emit {Sonic Network}} 80640 {emit {Realtime Music}} 80896 {emit {Apogee Digital}} 2108160 {emit {Medeli Electronics}} 2108416 {emit {Charlie Lab}} 2108672 {emit {Blue Chip Music}} 2108928 {emit {BEE OH Corp}} 2109184 {emit {LG Semicon America}} 2109440 {emit TESI} 2109696 {emit EMAGIC} 2109952 {emit Behringer} 2110208 {emit {Access Music}} 2110464 {emit Synoptic} 2110720 {emit {Hanmesoft Corp}} 2110976 {emit Terratec} 2111232 {emit {Proel SpA}} 2111488 {emit {IBK MIDI}} 2111744 {emit IRCAM} 2112000 {emit {Propellerhead Software}} 2112256 {emit {Red Sound Systems}} 2112512 {emit {Electron ESI AB}} 2112768 {emit {Sintefex Audio}} 2113024 {emit {Music and More}} 2113280 {emit Amsaro} 2113536 {emit {CDS Advanced Technology}} 2113792 {emit {Touched by Sound}} 2114048 {emit {DSP Arts}} 2114304 {emit {Phil Rees Music}} 2114560 {emit {Stamer Musikanlagen GmbH}} 2114816 {emit Soundart} 2115072 {emit {C-Mexx Software}} 2115328 {emit {Klavis Tech.}} 2115584 {emit {Noteheads AB}} 
} -128 {emit {8086 relocatable \(Microsoft\)}} 
if {[S 0 == {@CT\ }]} {emit {T602 document data,}
if {[S 4 == 0]} {emit Kamenicky}
if {[S 4 == 1]} {emit {CP 852}}
if {[S 4 == 2]} {emit KOI8-CS}
if {[S 4 > 2]} {emit {unknown encoding}}
}
if {[S 0 == VimCrypt~]} {emit {Vim encrypted file data}}
if {[S 0 == {\177ELF}]} {emit ELF
switch -- [Nv c 4] 0 {emit {invalid class}} 1 {emit 32-bit
switch -- [Nv s 18] 8 {emit {}
if {[N i 36 & 0x20]} {emit N32}
} 10 {emit {}
if {[N i 36 & 0x20]} {emit N32}
} 
switch -- [Nv S 18] 8 {emit {}
if {[N I 36 & 0x20]} {emit N32}
} 10 {emit {}
if {[N I 36 & 0x20]} {emit N32}
} 
} 2 {emit 64-bit} 
switch -- [Nv c 5] 0 {emit {invalid byte order}} 1 {emit LSB
switch -- [Nv s 18] 8 {emit {}
switch -- [Nv c 4] 1 {emit {}
switch -- [Nv i 36 &0xf0000000] 0 {emit MIPS-I} 268435456 {emit MIPS-II} 536870912 {emit MIPS-III} 805306368 {emit MIPS-IV} 1073741824 {emit MIPS-V} 1610612736 {emit MIPS32} 1879048192 {emit MIPS64} -2147483648 {emit {MIPS32 rel2}} -1879048192 {emit {MIPS64 rel2}} 
} 2 {emit {}
switch -- [Nv i 48 &0xf0000000] 0 {emit MIPS-I} 268435456 {emit MIPS-II} 536870912 {emit MIPS-III} 805306368 {emit MIPS-IV} 1073741824 {emit MIPS-V} 1610612736 {emit MIPS32} 1879048192 {emit MIPS64} -2147483648 {emit {MIPS32 rel2}} -1879048192 {emit {MIPS64 rel2}} 
} 
} 0 {emit {no machine,}} 1 {emit {AT&T WE32100 - invalid byte order,}} 2 {emit {SPARC - invalid byte order,}} 3 {emit {Intel 80386,}} 4 {emit Motorola
if {[N i 36 & 0x1000000]} {emit {68000 - invalid byte order,}}
if {[N i 36 & 0x810000]} {emit {CPU32 - invalid byte order,}}
if {[N i 36 == 0x0]} {emit {68020 - invalid byte order,}}
} 5 {emit {Motorola 88000 - invalid byte order,}} 6 {emit {Intel 80486,}} 7 {emit {Intel 80860,}} 8 {emit MIPS,} 9 {emit {Amdahl - invalid byte order,}} 10 {emit {MIPS \(deprecated\),}} 11 {emit {RS6000 - invalid byte order,}} 15 {emit {PA-RISC - invalid byte order,}
if {[N s 50 == 0x214]} {emit 2.0}
if {[N s 48 & 0x8]} {emit {\(LP64\),}}
} 16 {emit nCUBE,} 17 {emit {Fujitsu VPP500,}} 18 {emit SPARC32PLUS,} 20 {emit PowerPC,} 22 {emit {IBM S/390,}} 36 {emit {NEC V800,}} 37 {emit {Fujitsu FR20,}} 38 {emit {TRW RH-32,}} 39 {emit {Motorola RCE,}} 40 {emit ARM,} 41 {emit Alpha,} -23664 {emit {IBM S/390 \(obsolete\),}} 42 {emit {Hitachi SH,}} 43 {emit {SPARC V9 - invalid byte order,}} 44 {emit {Siemens Tricore Embedded Processor,}} 45 {emit {Argonaut RISC Core, Argonaut Technologies Inc.,}} 46 {emit {Hitachi H8/300,}} 47 {emit {Hitachi H8/300H,}} 48 {emit {Hitachi H8S,}} 49 {emit {Hitachi H8/500,}} 50 {emit {IA-64 \(Intel 64 bit architecture\)}} 51 {emit {Stanford MIPS-X,}} 52 {emit {Motorola Coldfire,}} 53 {emit {Motorola M68HC12,}} 62 {emit {AMD x86-64,}} 75 {emit {Digital VAX,}} 88 {emit {Renesas M32R,}} 97 {emit {NatSemi 32k,}} -28634 {emit {Alpha \(unofficial\),}} 
switch -- [Nv s 16] 0 {emit {no file type,}} 1 {emit relocatable,} 2 {emit executable,} 3 {emit {shared object,}} 4 {emit {core file}} 
if {[N s 16 & 0xff00]} {emit processor-specific,}
switch -- [Nv i 20] 0 {emit {invalid version}} 1 {emit {version 1}} 
if {[N i 36 == 0x1]} {emit {MathCoPro/FPU/MAU Required}}
} 2 {emit MSB
switch -- [Nv S 18] 8 {emit {}
switch -- [Nv c 4] 1 {emit {}
switch -- [Nv I 36 &0xf0000000] 0 {emit MIPS-I} 268435456 {emit MIPS-II} 536870912 {emit MIPS-III} 805306368 {emit MIPS-IV} 1073741824 {emit MIPS-V} 1610612736 {emit MIPS32} 1879048192 {emit MIPS64} -2147483648 {emit {MIPS32 rel2}} -1879048192 {emit {MIPS64 rel2}} 
} 2 {emit {}
switch -- [Nv I 48 &0xf0000000] 0 {emit MIPS-I} 268435456 {emit MIPS-II} 536870912 {emit MIPS-III} 805306368 {emit MIPS-IV} 1073741824 {emit MIPS-V} 1610612736 {emit MIPS32} 1879048192 {emit MIPS64} -2147483648 {emit {MIPS32 rel2}} -1879048192 {emit {MIPS64 rel2}} 
} 
} 0 {emit {no machine,}} 1 {emit {AT&T WE32100,}} 2 {emit SPARC,} 3 {emit {Intel 80386 - invalid byte order,}} 4 {emit Motorola
if {[N I 36 & 0x1000000]} {emit 68000,}
if {[N I 36 & 0x810000]} {emit CPU32,}
if {[N I 36 == 0x0]} {emit 68020,}
} 5 {emit {Motorola 88000,}} 6 {emit {Intel 80486 - invalid byte order,}} 7 {emit {Intel 80860,}} 8 {emit MIPS,} 9 {emit Amdahl,} 10 {emit {MIPS \(deprecated\),}} 11 {emit RS6000,} 15 {emit PA-RISC
if {[N S 50 == 0x214]} {emit 2.0}
if {[N S 48 & 0x8]} {emit {\(LP64\)}}
} 16 {emit nCUBE,} 17 {emit {Fujitsu VPP500,}} 18 {emit SPARC32PLUS,
if {[N I 36 & 0x100 &0xffff00]} {emit {V8+ Required,}}
if {[N I 36 & 0x200 &0xffff00]} {emit {Sun UltraSPARC1 Extensions Required,}}
if {[N I 36 & 0x400 &0xffff00]} {emit {HaL R1 Extensions Required,}}
if {[N I 36 & 0x800 &0xffff00]} {emit {Sun UltraSPARC3 Extensions Required,}}
} 20 {emit {PowerPC or cisco 4500,}} 21 {emit {cisco 7500,}} 22 {emit {IBM S/390,}} 24 {emit {cisco SVIP,}} 25 {emit {cisco 7200,}} 36 {emit {NEC V800 or cisco 12000,}} 37 {emit {Fujitsu FR20,}} 38 {emit {TRW RH-32,}} 39 {emit {Motorola RCE,}} 40 {emit ARM,} 41 {emit Alpha,} 42 {emit {Hitachi SH,}} 43 {emit {SPARC V9,}} 44 {emit {Siemens Tricore Embedded Processor,}} 45 {emit {Argonaut RISC Core, Argonaut Technologies Inc.,}} 46 {emit {Hitachi H8/300,}} 47 {emit {Hitachi H8/300H,}} 48 {emit {Hitachi H8S,}} 49 {emit {Hitachi H8/500,}} 50 {emit {Intel Merced Processor,}} 51 {emit {Stanford MIPS-X,}} 52 {emit {Motorola Coldfire,}} 53 {emit {Motorola M68HC12,}} 73 {emit {Cray NV1,}} 75 {emit {Digital VAX,}} 88 {emit {Renesas M32R,}} 97 {emit {NatSemi 32k,}} -28634 {emit {Alpha \(unofficial\),}} -23664 {emit {IBM S/390 \(obsolete\),}} 
switch -- [Nv S 16] 0 {emit {no file type,}} 1 {emit relocatable,} 2 {emit executable,} 3 {emit {shared object,}} 4 {emit {core file,}} 
if {[N S 16 & 0xff00]} {emit processor-specific,}
switch -- [Nv I 20] 0 {emit {invalid version}} 1 {emit {version 1}} 
if {[N I 36 == 0x1]} {emit {MathCoPro/FPU/MAU Required}}
} 
if {[N c 4 < 0x80]} {if {[S 8 x {}]} {emit {\(%s\)}}
}
if {[S 8 == {\0}]} {switch -- [Nv c 7] 0 {emit {\(SYSV\)}} 1 {emit {\(HP-UX\)}} 2 {emit {\(NetBSD\)}} 3 {emit {\(GNU/Linux\)}} 4 {emit {\(GNU/Hurd\)}} 5 {emit {\(86Open\)}} 6 {emit {\(Solaris\)}} 7 {emit {\(Monterey\)}} 8 {emit {\(IRIX\)}} 9 {emit {\(FreeBSD\)}} 10 {emit {\(Tru64\)}} 11 {emit {\(Novell Modesto\)}} 12 {emit {\(OpenBSD\)}} 97 {emit {\(ARM\)}} -1 {emit {\(embedded\)}} 
}
}
if {[N i 4 == 0x1000006d]} {emit {{7 lelong {} == 8 0x1000007f Word} {8 lelong {} == 8 0x10000088 Sheet} {9 lelong {} == 8 0x1000007d Sketch} {10 lelong {} == 8 0x10000085 TextEd}}}
if {[S 0 == FCS1.0]} {emit {Flow Cytometry Standard \(FCS\) data, version 1.0}}
if {[S 0 == FCS2.0]} {emit {Flow Cytometry Standard \(FCS\) data, version 2.0}}
if {[S 0 == FCS3.0]} {emit {Flow Cytometry Standard \(FCS\) data, version 3.0}}
if {[S 0 == {\366\366\366\366}]} {emit {PC formatted floppy with no filesystem}}
if {[N S 508 == 0xdabe]} {emit {Sun disk label}
if {[S 0 x {}]} {emit '%s
if {[S 31 x {}]} {emit {\b%s}
if {[S 63 x {}]} {emit {\b%s}
if {[S 95 x {}]} {emit {\b%s}}
}
}
}
if {[S 0 x {}]} {emit {\b'}}
if {[N Y 476 > 0x0]} {emit {%d rpm,}}
if {[N Y 478 > 0x0]} {emit {%d phys cys,}}
if {[N Y 480 > 0x0]} {emit {%d alts/cyl,}}
if {[N Y 486 > 0x0]} {emit {%d interleave,}}
if {[N Y 488 > 0x0]} {emit {%d data cyls,}}
if {[N Y 490 > 0x0]} {emit {%d alt cyls,}}
if {[N Y 492 > 0x0]} {emit {%d heads/partition,}}
if {[N Y 494 > 0x0]} {emit {%d sectors/track,}}
if {[N Q 500 > 0x0]} {emit {start cyl %ld,}}
if {[N Q 504 x {}]} {emit {%ld blocks}}
if {[N I 512 == 0x30107 &077777777]} {emit {\b, boot block present}}
}
if {[S 0 == {DOSEMU\0}]} {if {[N s 638 == 0xaa55]} {emit {DOS Emulator image}}
}
if {[N s 510 == 0xaa55]} {emit {x86 boot sector}
if {[S 2 == OSBS]} {emit {\b, OS/BS MBR}}
if {[S 140 == {Invalid\ partition\ table}]} {emit {\b, MS-DOS MBR}}
if {[S 157 == {Invalid\ partition\ table$}]} {if {[S 181 == {No\ Operating\ System$}]} {if {[S 201 == {Operating\ System\ load\ error$}]} {emit {\b, DR-DOS MBR, Version 7.01 to 7.03}}
}
}
if {[S 157 == {Invalid\ partition\ table$}]} {if {[S 181 == {No\ operating\ system$}]} {if {[S 201 == {Operating\ system\ load\ error$}]} {emit {\b, DR-DOS MBR, Version 7.01 to 7.03}}
}
}
if {[S 342 == {Invalid\ partition\ table$}]} {if {[S 366 == {No\ operating\ system$}]} {if {[S 386 == {Operating\ system\ load\ error$}]} {emit {\b, DR-DOS MBR, version 7.01 to 7.03}}
}
}
if {[S 295 == {NEWLDR\0}]} {if {[S 302 == {Bad\ PT\ $}]} {if {[S 310 == {No\ OS\ $}]} {if {[S 317 == {OS\ load\ err$}]} {if {[S 329 == {Moved\ or\ missing\ IBMBIO.LDR\n\r}]} {if {[S 358 == {Press\ any\ key\ to\ continue.\n\r$}]} {if {[S 387 == {Copyright\ (c)\ 1984,1998}]} {if {[S 411 == {Caldera\ Inc.\0}]} {emit {\b, DR-DOS MBR \(IBMBIO.LDR\)}}
}
}
}
}
}
}
}
if {[S 271 == {Ung\201ltige\ Partitionstabelle}]} {emit {\b, MS-DOS MBR, german version 4.10.1998, 4.10.2222}}
if {[S 139 == {Ung\201ltige\ Partitionstabelle}]} {emit {\b, MS-DOS MBR, german version 5.00 to 4.00.950}}
if {[S 300 == {Invalid\ partition\ table\0}]} {if {[S 324 == {Error\ loading\ operating\ system\0}]} {if {[S 355 == {Missing\ operating\ system\0}]} {emit {\b, Microsoft Windows XP MBR}}
}
}
if {[S 300 == {Ung\201ltige\ Partitionstabelle}]} {if {[S 328 == {Fehler\ beim\ Laden\ }]} {if {[S 346 == {des\ Betriebssystems}]} {if {[S 366 == {Betriebssystem\ nicht\ vorhanden}]} {emit {\b, Microsoft Windows XP MBR \(german\)}}
}
}
}
if {[S 325 == {Default:\ F}]} {emit {\b, FREE-DOS MBR}}
if {[S 64 == {no\ active\ partition\ found}]} {if {[S 96 == {read\ error\ while\ reading\ drive}]} {emit {\b, FREE-DOS Beta9 MBR}}
}
if {[S 43 == {SMART\ BTMGRFAT12\ \ \ }]} {if {[S 430 == {SBMK\ Bad!\r}]} {if {[S 3 == SBM]} {emit {\b, Smart Boot Manager}
if {[S 6 x {}]} {emit {\b, version %s}}
}
}
}
if {[S 382 == XOSLLOADXCF]} {emit {\b, EXtended Operating System Loader}}
if {[S 6 == LILO]} {emit {\b, LInux i386 boot LOader}
if {[S 120 == LILO]} {emit {\b, version 22.3.4 SuSe}}
if {[S 172 == LILO]} {emit {\b, version 22.5.8 Debian}}
}
if {[S 402 == {Geom\0Hard\ Disk\0Read\0\ Error\0}]} {if {[S 394 == stage1]} {emit {\b, GRand Unified Bootloader \(0.5.95\)}}
}
if {[S 380 == {Geom\0Hard\ Disk\0Read\0\ Error\0}]} {if {[S 374 == {GRUB\ \0}]} {emit {\b, GRand Unified Bootloader}}
}
if {[S 382 == {Geom\0Hard\ Disk\0Read\0\ Error\0}]} {if {[S 376 == {GRUB\ \0}]} {emit {\b, GRand Unified Bootloader \(0.93\)}}
}
if {[S 383 == {Geom\0Hard\ Disk\0Read\0\ Error\0}]} {if {[S 377 == {GRUB\ \0}]} {emit {\b, GRand Unified Bootloader \(0.94\)}}
}
if {[S 480 == {Boot\ failed\r}]} {if {[S 495 == {LDLINUX\ SYS}]} {emit {\b, SYSLINUX bootloader \(2.06\)}}
}
if {[S 395 == {chksum\0\ ERROR!\0}]} {emit {\b, Gujin bootloader}}
if {[S 185 == {FDBOOT\ Version\ }]} {if {[S 204 == {\rNo\ Systemdisk.\ }]} {if {[S 220 == {Booting\ from\ harddisk.\n\r}]} {emit 349 21 0 0}
if {[S 245 == {Cannot\ load\ from\ harddisk.\n\r}]} {if {[S 273 == {Insert\ Systemdisk\ }]} {if {[S 291 == {and\ press\ any\ key.\n\r}]} {emit {\b, FDBOOT harddisk Bootloader}
if {[S 200 x {}]} {emit {\b, version %-3s}}
}
}
}
}
}
if {[S 242 == {Bootsector\ from\ C.H.\ Hochst\204}]} {if {[S 278 == {No\ Systemdisk.\ }]} {if {[S 293 == {Booting\ from\ harddisk.\n\r}]} {emit 349 22 0 0}
if {[S 441 == {Cannot\ load\ from\ harddisk.\n\r}]} {if {[S 469 == {Insert\ Systemdisk\ }]} {if {[S 487 == {and\ press\ any\ key.\n\r}]} {emit {\b, WinImage harddisk Bootloader}
if {[S 209 x {}]} {emit {\b, version %-4.4s}}
}
}
}
}
}
if {[N c [I 1 c 2] == 0xe]} {if {[N c [I 1 c 3] == 0x1f]} {if {[N c [I 1 c 4] == 0xbe]} {if {[N c [I 1 c 5] == 0x77]} {emit 349 23 0 0 0}
if {[N c [I 1 c 6] == 0x7c]} {if {[N c [I 1 c 7] == 0xac]} {if {[N c [I 1 c 8] == 0x22]} {if {[N c [I 1 c 9] == 0xc0]} {if {[N c [I 1 c 10] == 0x74]} {if {[N c [I 1 c 11] == 0xb]} {if {[N c [I 1 c 12] == 0x56]} {emit 349 23 0 0 1 0 0 0 0 0 0}
if {[N c [I 1 c 13] == 0xb4]} {emit {\b, mkdosfs boot message display}}
}
}
}
}
}
}
}
}
}
if {[S 430 == {NTLDR\ is\ missing\xFF\r\n}]} {if {[S 449 == {Disk\ error\xFF\r\n}]} {if {[S 462 == {Press\ any\ key\ to\ restart\r}]} {emit {\b, Microsoft Windows XP Bootloader}
if {[N c 417 < 0x7e]} {if {[S 417 > {\ }]} {emit %-.5s
if {[N c 422 < 0x7e]} {if {[S 422 > {\ }]} {emit {\b%-.3s}}
}
if {[S 425 > {\ }]} {emit {\b.%-.3s}}
}
}
if {[N c 368 < 0x7e]} {if {[S 368 > {\ }]} {emit %-.5s
if {[N c 373 < 0x7e]} {if {[S 373 > {\ }]} {emit {\b%-.3s}}
}
if {[S 376 > {\ }]} {emit {\b.%-.3s}}
}
}
}
}
}
if {[S 430 == {NTLDR\ nicht\ gefunden\xFF\r\n}]} {if {[S 453 == {Datentr\204gerfehler\xFF\r\n}]} {if {[S 473 == {Neustart\ mit\ beliebiger\ Taste\r}]} {emit {\b, Microsoft Windows XP Bootloader \(german\)}
if {[N c 417 < 0x7e]} {if {[S 417 > {\ }]} {emit %-.5s
if {[N c 422 < 0x7e]} {if {[S 422 > {\ }]} {emit {\b%-.3s}}
}
if {[S 425 > {\ }]} {emit {\b.%-.3s}}
}
}
if {[N c 368 < 0x7e]} {if {[S 368 > {\ }]} {emit %-.5s
if {[N c 373 < 0x7e]} {if {[S 373 > {\ }]} {emit {\b%-.3s}}
}
if {[S 376 > {\ }]} {emit {\b.%-.3s}}
}
}
}
}
}
if {[S 430 == {NTLDR\ fehlt\xFF\r\n}]} {if {[S 444 == {Datentr\204gerfehler\xFF\r\n}]} {if {[S 464 == {Neustart\ mit\ beliebiger\ Taste\r}]} {emit {\b, Microsoft Windows XP Bootloader \(2.german\)}
if {[N c 417 < 0x7e]} {if {[S 417 > {\ }]} {emit %-.5s
if {[N c 422 < 0x7e]} {if {[S 422 > {\ }]} {emit {\b%-.3s}}
}
if {[S 425 > {\ }]} {emit {\b.%-.3s}}
}
}
}
}
}
if {[S 430 == {NTLDR\ fehlt\xFF\r\n}]} {if {[S 444 == {Medienfehler\xFF\r\n}]} {if {[S 459 == {Neustart:\ Taste\ dr\201cken\r}]} {emit {\b, Microsoft Windows XP Bootloader \(3.german\)}
if {[N c 368 < 0x7e]} {if {[S 368 > {\ }]} {emit %-.5s
if {[N c 373 < 0x7e]} {if {[S 373 > {\ }]} {emit {\b%-.3s}}
}
if {[S 376 > {\ }]} {emit {\b.%-.3s}}
}
}
if {[N c 417 < 0x7e]} {if {[S 417 > {\ }]} {emit %-.5s
if {[N c 422 < 0x7e]} {if {[S 422 > {\ }]} {emit {\b%-.3s}}
}
if {[S 425 > {\ }]} {emit {\b.%-.3s}}
}
}
}
}
}
if {[S 430 == {Datentr\204ger\ entfernen\xFF\r\n}]} {if {[S 454 == {Medienfehler\xFF\r\n}]} {if {[S 469 == {Neustart:\ Taste\ dr\201cken\r}]} {emit {\b, Microsoft Windows XP Bootloader \(4.german\)}
if {[N c 368 < 0x7e]} {if {[S 368 > {\ }]} {emit %-.5s
if {[N c 373 < 0x7e]} {if {[S 373 > {\ }]} {emit {\b%-.3s}}
}
if {[S 376 > {\ }]} {emit {\b.%-.3s}}
}
}
}
}
}
if {[S 389 == {Fehler\ beim\ Lesen\ }]} {if {[S 407 == {des\ Datentr\204gers}]} {if {[S 426 == {NTLDR\ fehlt}]} {if {[S 440 == {NTLDR\ ist\ komprimiert}]} {if {[S 464 == {Neustart\ mit\ Strg+Alt+Entf\r}]} {emit {\b, Microsoft Windows XP Bootloader NTFS \(german\)}}
}
}
}
}
if {[S 313 == {A\ disk\ read\ error\ occurred.\r}]} {if {[S 345 == {A\ kernel\ file\ is\ missing\ }]} {if {[S 370 == {from\ the\ disk.\r}]} {if {[S 484 == {NTLDR\ is\ compressed}]} {if {[S 429 == {Insert\ a\ system\ diskette\ }]} {if {[S 454 == {and\ restart\r\nthe\ system.\r}]} {emit {\b, Microsoft Windows XP Bootloader NTFS}}
}
}
}
}
}
if {[S 472 == {IO\ \ \ \ \ \ SYSMSDOS\ \ \ SYS}]} {if {[S 497 == {WINBOOT\ SYS}]} {emit 349 31 0}
if {[S 389 == {Invalid\ system\ disk\xFF\r\n}]} {if {[S 411 == {Disk\ I/O\ error}]} {if {[S 428 == {Replace\ the\ disk,\ and\ }]} {if {[S 455 == {press\ any\ key}]} {emit {\b, Microsoft Windows 98 Bootloader}}
}
}
}
if {[S 390 == {Invalid\ system\ disk\xFF\r\n}]} {if {[S 412 == {Disk\ I/O\ error\xFF\r\n}]} {if {[S 429 == {Replace\ the\ disk,\ and\ }]} {if {[S 451 == {then\ press\ any\ key\r}]} {emit {\b, Microsoft Windows 98 Bootloader}}
}
}
}
if {[S 388 == {Ungueltiges\ System\ \xFF\r\n}]} {if {[S 410 == {E/A-Fehler\ \ \ \ \xFF\r\n}]} {if {[S 427 == {Datentraeger\ wechseln\ und\ }]} {if {[S 453 == {Taste\ druecken\r}]} {emit {\b, Microsoft Windows 95/98/ME Bootloader \(german\)}}
}
}
}
if {[S 390 == {Ungueltiges\ System\ \xFF\r\n}]} {if {[S 412 == {E/A-Fehler\ \ \ \ \xFF\r\n}]} {if {[S 429 == {Datentraeger\ wechseln\ und\ }]} {if {[S 455 == {Taste\ druecken\r}]} {emit {\b, Microsoft Windows 95/98/ME Bootloader \(German\)}}
}
}
}
if {[S 389 == {Ungueltiges\ System\ \xFF\r\n}]} {if {[S 411 == {E/A-Fehler\ \ \ \ \xFF\r\n}]} {if {[S 428 == {Datentraeger\ wechseln\ und\ }]} {if {[S 454 == {Taste\ druecken\r}]} {emit {\b, Microsoft Windows 95/98/ME Bootloader \(GERMAN\)}}
}
}
}
}
if {[S 479 == {IO\ \ \ \ \ \ SYSMSDOS\ \ \ SYS}]} {if {[S 416 == {Kein\ System\ oder\ }]} {if {[S 433 == Laufwerksfehler]} {if {[S 450 == {Wechseln\ und\ Taste\ dr\201cken}]} {emit {\b, Microsoft DOS Bootloader \(german\)}}
}
}
}
if {[S 486 == {IO\ \ \ \ \ \ SYSMSDOS\ \ \ SYS}]} {if {[S 416 == {Non-System\ disk\ or\ }]} {if {[S 435 == {disk\ error\r}]} {if {[S 447 == {Replace\ and\ press\ any\ key\ }]} {if {[S 473 == {when\ ready\r}]} {emit {\b, Microsoft DOS Bootloader}}
}
}
}
}
if {[S 480 == {IO\ \ \ \ \ \ SYSMSDOS\ \ \ SYS}]} {if {[S 393 == {Non-System\ disk\ or\ }]} {if {[S 412 == {disk\ error\r}]} {if {[S 424 == {Replace\ and\ press\ any\ key\ }]} {if {[S 450 == {when\ ready\r}]} {emit {\b, Microsoft DOS bootloader}}
}
}
}
}
if {[S 54 == SYS]} {if {[S 324 == VASKK]} {if {[S 495 == {NEWLDR\0}]} {emit {\b, DR-DOS Bootloader \(LOADER.SYS\)}}
}
}
if {[S 70 == {IBMBIO\ \ COM}]} {if {[S 472 == {Cannot\ load\ DOS!\ }]} {if {[S 489 == {Any\ key\ to\ retry}]} {emit {\b, DR-DOS Bootloader}}
}
if {[S 471 == {Cannot\ load\ DOS\ }]} {emit 349 36 1}
if {[S 487 == {press\ key\ to\ retry}]} {emit {\b, Open-DOS Bootloader}}
}
if {[S 444 == {KERNEL\ \ SYS}]} {if {[S 314 == {BOOT\ error!}]} {emit {\b, FREE-DOS Bootloader}}
}
if {[S 499 == {KERNEL\ \ SYS}]} {if {[S 305 == {BOOT\ err!\0}]} {emit {\b, Free-DOS Bootloader}}
}
if {[S 449 == {KERNEL\ \ SYS}]} {if {[S 319 == {BOOT\ error!}]} {emit {\b, FREE-DOS 5.0 Bootloader}}
}
if {[S 124 == {FreeDOS\0}]} {if {[S 331 == {\ err\0}]} {emit {\b, FREE-DOS BETa 9 Bootloader}
if {[S 497 > {\ }]} {emit %-.6s
if {[S 503 > {\ }]} {emit {\b%-.1s}}
if {[S 504 > {\ }]} {emit {\b%-.1s}}
}
if {[S 505 > {\ }]} {emit {\b.%-.3s}}
}
if {[S 333 == {\ err\0}]} {emit {\b, FREE-DOS BEta 9 Bootloader}
if {[S 497 > {\ }]} {emit %-.6s
if {[S 503 > {\ }]} {emit {\b%-.1s}}
if {[S 504 > {\ }]} {emit {\b%-.1s}}
}
if {[S 505 > {\ }]} {emit {\b.%-.3s}}
}
if {[S 334 == {\ err\0}]} {emit {\b, FREE-DOS Beta 9 Bootloader}
if {[S 497 > {\ }]} {emit %-.6s
if {[S 503 > {\ }]} {emit {\b%-.1s}}
if {[S 504 > {\ }]} {emit {\b%-.1s}}
}
if {[S 505 > {\ }]} {emit {\b.%-.3s}}
}
}
if {[S 0 == {\0\0\0\0}]} {emit {\b, extended partition table}}
if {[N i 0 == 0x9000eb &0x009000EB]} {emit 349 42}
if {[N i 0 == 0xe9 &0x000000E9]} {if {[N c 1 > 0x25]} {emit {\b, code offset 0x%x}
if {[N s 11 < 0x801]} {if {[N s 11 > 0x1f]} {if {[S 3 x {}]} {emit {\b, OEM-ID \"%8.8s\"}}
if {[N s 11 > 0x200]} {emit {\b, Bytes/sector %u}}
if {[N s 11 < 0x200]} {emit {\b, Bytes/sector %u}}
if {[N c 13 > 0x1]} {emit {\b, sectors/cluster %u}}
if {[N s 14 > 0x20]} {emit {\b, reserved sectors %u}}
if {[N s 14 < 0x1]} {emit {\b, reserved sectors %u}}
if {[N c 16 > 0x2]} {emit {\b, FATs %u}}
if {[N c 16 == 0x1]} {emit {\b, FAT  %u}}
if {[N c 16 > 0x0]} {emit 349 43 0 0 0 8}
if {[N s 17 > 0x0]} {emit {\b, root entries %u}}
if {[N s 19 > 0x0]} {emit {\b, sectors %u \(volumes <=32 MB\)}}
if {[N c 21 > 0xf0]} {emit {\b, Media descriptor 0x%x}}
if {[N c 21 < 0xf0]} {emit {\b, Media descriptor 0x%x}}
if {[N s 22 > 0x0]} {emit {\b, sectors/FAT %u}}
if {[N c 26 > 0x2]} {emit {\b, heads %u}}
if {[N c 26 == 0x1]} {emit {\b, heads %u}}
if {[N i 28 > 0x0]} {emit {\b, hidden sectors %u}}
if {[N i 32 > 0x0]} {emit {\b, sectors %u \(volumes > 32 MB\)}}
if {[N i 82 > 0x0 &0xCCABBEB9]} {if {[N c 36 > 0x80]} {emit {\b, physical drive 0x%x}}
if {[N c 36 > 0x0 &0x7F]} {emit {\b, physical drive 0x%x}}
if {[N c 37 > 0x0]} {emit {\b, reserved 0x%x}}
if {[N c 38 > 0x29]} {emit {\b, dos < 4.0 BootSector \(0x%x\)}}
if {[N c 38 < 0x29]} {emit {\b, dos < 4.0 BootSector \(0x%x\)}}
if {[N c 38 == 0x29]} {if {[N i 39 x {}]} {emit {\b, serial number 0x%x}}
if {[S 43 < {NO\ NAME}]} {emit {\b, label: \"%11.11s\"}}
if {[S 43 > {NO\ NAME}]} {emit {\b, label: \"%11.11s\"}}
if {[S 43 == {NO\ NAME}]} {emit {\b, unlabeled}}
}
if {[S 54 == FAT1]} {emit {\b, FAT}
if {[S 54 == FAT12]} {emit {\b \(12 bit\)}}
if {[S 54 == FAT16]} {emit {\b \(16 bit\)}}
}
}
if {[S 82 == FAT32]} {emit {\b, FAT \(32 bit\)}
if {[N i 36 x {}]} {emit {\b, sectors/FAT %u}}
if {[N s 40 > 0x0]} {emit {\b, extension flags %u}}
if {[N s 42 > 0x0]} {emit {\b, fsVersion %u}}
if {[N i 44 > 0x2]} {emit {\b, rootdir cluster %u}}
if {[N s 48 > 0x1]} {emit {\b, infoSector %u}}
if {[N s 48 < 0x1]} {emit {\b, infoSector %u}}
if {[N s 50 > 0x6]} {emit {\b, Backup boot sector %u}}
if {[N s 50 < 0x6]} {emit {\b, Backup boot sector %u}}
if {[N i 54 > 0x0]} {emit {\b, reserved1 0x%x}}
if {[N i 58 > 0x0]} {emit {\b, reserved2 0x%x}}
if {[N i 62 > 0x0]} {emit {\b, reserved3 0x%x}}
if {[N c 64 > 0x80]} {emit {\b, physical drive 0x%x}}
if {[N c 64 > 0x0 &0x7F]} {emit {\b, physical drive 0x%x}}
if {[N c 65 > 0x0]} {emit {\b, reserved 0x%x}}
if {[N c 66 > 0x29]} {emit {\b, dos < 4.0 BootSector \(0x%x\)}}
if {[N c 66 < 0x29]} {emit {\b, dos < 4.0 BootSector \(0x%x\)}}
if {[N c 66 == 0x29]} {if {[N i 67 x {}]} {emit {\b, serial number 0x%x}}
if {[S 71 < {NO\ NAME}]} {emit {\b, label: \"%11.11s\"}}
}
if {[S 71 > {NO\ NAME}]} {emit {\b, label: \"%11.11s\"}}
if {[S 71 == {NO\ NAME}]} {emit {\b, unlabeled}}
}
}
}
}
}
if {[N i 512 == 0x82564557]} {emit {\b, BSD disklabel}}
}
if {[S 0 == FATX]} {emit {FATX filesystem data}}
switch -- [Nv s 1040] 4991 {emit {Minix filesystem}} 5007 {emit {Minix filesystem, 30 char names}} 9320 {emit {Minix filesystem, version 2}} 9336 {emit {Minix filesystem, version 2, 30 char names}} 
if {[N S 1040 == 0x137f]} {emit {Minix filesystem \(big endian\),}
if {[N S 1026 != 0x0]} {emit {\b, %d zones}}
if {[S 30 == minix]} {emit {\b, bootable}}
}
if {[S 0 == {-rom1fs-\0}]} {emit {romfs filesystem, version 1}
if {[N I 8 x {}]} {emit {%d bytes,}}
if {[S 16 x {}]} {emit {named %s.}}
}
if {[S 395 == OS/2]} {emit {OS/2 Boot Manager}}
if {[N i 9564 == 0x11954]} {emit {Unix Fast File system \(little-endian\),}
if {[S 8404 x {}]} {emit {last mounted on %s,}}
if {[N s 8224 x {}]} {emit {last written at %s,}}
if {[N c 8401 x {}]} {emit {clean flag %d,}}
if {[N i 8228 x {}]} {emit {number of blocks %d,}}
if {[N i 8232 x {}]} {emit {number of data blocks %d,}}
if {[N i 8236 x {}]} {emit {number of cylinder groups %d,}}
if {[N i 8240 x {}]} {emit {block size %d,}}
if {[N i 8244 x {}]} {emit {fragment size %d,}}
if {[N i 8252 x {}]} {emit {minimum percentage of free blocks %d,}}
if {[N i 8256 x {}]} {emit {rotational delay %dms,}}
if {[N i 8260 x {}]} {emit {disk rotational speed %drps,}}
switch -- [Nv i 8320] 0 {emit {TIME optimization}} 1 {emit {SPACE optimization}} 
}
if {[N I 9564 == 0x11954]} {emit {Unix Fast File system \(big-endian\),}
if {[N Q 7168 == 0x4c41424c]} {emit {Apple UFS Volume}
if {[S 7186 x {}]} {emit {named %s,}}
if {[N I 7176 x {}]} {emit {volume label version %d,}}
if {[N S 7180 x {}]} {emit {created on %s,}}
}
if {[S 8404 x {}]} {emit {last mounted on %s,}}
if {[N S 8224 x {}]} {emit {last written at %s,}}
if {[N c 8401 x {}]} {emit {clean flag %d,}}
if {[N I 8228 x {}]} {emit {number of blocks %d,}}
if {[N I 8232 x {}]} {emit {number of data blocks %d,}}
if {[N I 8236 x {}]} {emit {number of cylinder groups %d,}}
if {[N I 8240 x {}]} {emit {block size %d,}}
if {[N I 8244 x {}]} {emit {fragment size %d,}}
if {[N I 8252 x {}]} {emit {minimum percentage of free blocks %d,}}
if {[N I 8256 x {}]} {emit {rotational delay %dms,}}
if {[N I 8260 x {}]} {emit {disk rotational speed %drps,}}
switch -- [Nv I 8320] 0 {emit {TIME optimization}} 1 {emit {SPACE optimization}} 
}
if {[N s 1080 == 0xef53]} {emit Linux
if {[N i 1100 x {}]} {emit {rev %d}}
if {[N s 1086 x {}]} {emit {\b.%d}}
if {[N i 1116 ^ 0x4]} {emit {ext2 filesystem data}
if {[N s 1082 ^ 0x1]} {emit {\(mounted or unclean\)}}
}
if {[N i 1116 & 0x4]} {emit {ext3 filesystem data}
if {[N i 1120 & 0x4]} {emit {\(needs journal recovery\)}}
}
if {[N s 1082 & 0x2]} {emit {\(errors\)}}
if {[N i 1120 & 0x1]} {emit {\(compressed\)}}
if {[N i 1124 & 0x2]} {emit {\(large files\)}}
}
if {[N I 2048 == 0x46fc2700]} {emit {Atari-ST Minix kernel image}
if {[S 19 == {\240\5\371\5\0\011\0\2\0}]} {emit {\b, 720k floppy}}
if {[S 19 == {\320\2\370\5\0\011\0\1\0}]} {emit {\b, 360k floppy}}
}
if {[S 19 == {\320\2\360\3\0\011\0\1\0}]} {emit {DOS floppy 360k}
if {[N s 510 == 0xaa55]} {emit {\b, x86 hard disk boot sector}}
}
if {[S 19 == {\240\5\371\3\0\011\0\2\0}]} {emit {DOS floppy 720k}
if {[N s 510 == 0xaa55]} {emit {\b, x86 hard disk boot sector}}
}
if {[S 19 == {\100\013\360\011\0\022\0\2\0}]} {emit {DOS floppy 1440k}
if {[N s 510 == 0xaa55]} {emit {\b, x86 hard disk boot sector}}
}
if {[S 19 == {\240\5\371\5\0\011\0\2\0}]} {emit {DOS floppy 720k, IBM}
if {[N s 510 == 0xaa55]} {emit {\b, x86 hard disk boot sector}}
}
if {[S 19 == {\100\013\371\5\0\011\0\2\0}]} {emit {DOS floppy 1440k, mkdosfs}
if {[N s 510 == 0xaa55]} {emit {\b, x86 hard disk boot sector}}
}
if {[S 19 == {\320\2\370\5\0\011\0\1\0}]} {emit {Atari-ST floppy 360k}}
if {[S 19 == {\240\5\371\5\0\011\0\2\0}]} {emit {Atari-ST floppy 720k}}
if {[S 32769 == CD001]} {emit {ISO 9660 CD-ROM filesystem data}
if {[S 32808 x {}]} {emit '%s'}
if {[S 34816 == {\000CD001\001EL\ TORITO\ SPECIFICATION}]} {emit {\(bootable\)}}
}
if {[S 37633 == CD001]} {emit {ISO 9660 CD-ROM filesystem data \(raw 2352 byte sectors\)}}
if {[S 32776 == CDROM]} {emit {High Sierra CD-ROM filesystem data}}
if {[S 65588 == ReIsErFs]} {emit {ReiserFS V3.5}}
if {[S 65588 == ReIsEr2Fs]} {emit {ReiserFS V3.6}
if {[N s 65580 x {}]} {emit {block size %d}}
if {[N s 65586 & 0x2]} {emit {\(mounted or unclean\)}}
if {[N i 65536 x {}]} {emit {num blocks %d}}
switch -- [Nv i 65600] 1 {emit {tea hash}} 2 {emit {yura hash}} 3 {emit {r5 hash}} 
}
if {[S 0 == ESTFBINR]} {emit {EST flat binary}}
if {[S 0 == {VoIP\ Startup\ and}]} {emit {Aculab VoIP firmware}
if {[S 35 x {}]} {emit {format %s}}
}
if {[S 0 == sqsh]} {emit {Squashfs filesystem, big endian,}
if {[N S 28 x {}]} {emit {version %d.}}
if {[N S 30 x {}]} {emit {\b%d,}}
if {[N I 8 x {}]} {emit {%d bytes,}}
if {[N I 4 x {}]} {emit {%d inodes,}}
if {[N S 28 < 0x2]} {if {[N S 32 x {}]} {emit {blocksize: %d bytes,}}
}
if {[N S 28 > 0x1]} {if {[N I 51 x {}]} {emit {blocksize: %d bytes,}}
}
if {[N S 39 x {}]} {emit {created: %s}}
}
if {[S 0 == hsqs]} {emit {Squashfs filesystem, little endian,}
if {[N s 28 x {}]} {emit {version %d.}}
if {[N s 30 x {}]} {emit {\b%d,}}
if {[N i 8 x {}]} {emit {%d bytes,}}
if {[N i 4 x {}]} {emit {%d inodes,}}
if {[N s 28 < 0x2]} {if {[N s 32 x {}]} {emit {blocksize: %d bytes,}}
}
if {[N s 28 > 0x1]} {if {[N i 51 x {}]} {emit {blocksize: %d bytes,}}
}
if {[N s 39 x {}]} {emit {created: %s}}
}
if {[S 0 == FWS]} {emit {Macromedia Flash data,}
if {[N c 3 x {}]} {emit {version %d}}
}
if {[S 0 == CWS]} {emit {Macromedia Flash data \(compressed\),}
if {[N c 3 x {}]} {emit {version %d}}
}
if {[S 0 == {AGD4\xbe\xb8\xbb\xcb\x00}]} {emit {Macromedia Freehand 9 Document}}
if {[S 0 == FONT]} {emit {ASCII vfont text}}
if {[S 0 == %!PS-AdobeFont-1.]} {emit {PostScript Type 1 font text}
if {[S 20 x {}]} {emit {\(%s\)}}
}
if {[S 6 == %!PS-AdobeFont-1.]} {emit {PostScript Type 1 font program data}}
if {[S 0 == {STARTFONT\040}]} {emit {X11 BDF font text}}
if {[S 0 == {\001fcp}]} {emit {X11 Portable Compiled Font data}
switch -- [Nv c 12] 2 {emit {\b, LSB first}} 10 {emit {\b, MSB first}} 
}
if {[S 0 == {D1.0\015}]} {emit {X11 Speedo font data}}
if {[S 0 == flf]} {emit {FIGlet font}
if {[S 3 > 2a]} {emit {version %-2.2s}}
}
if {[S 0 == flc]} {emit {FIGlet controlfile}
if {[S 3 > 2a]} {emit {version %-2.2s}}
}
switch -- [Nv I 7] 4540225 {emit {DOS code page font data}} 5654852 {emit {DOS code page font data \(from Linux?\)}} 
if {[S 4098 == DOSFONT]} {emit {DOSFONT2 encrypted font data}}
if {[S 0 == PFR1]} {emit {PFR1 font}
if {[S 102 > 0]} {emit {\b: %s}}
}
if {[S 0 == {\000\001\000\000\000}]} {emit {TrueType font data}}
if {[S 0 == {\007\001\001\000Copyright\ (c)\ 199}]} {emit {Adobe Multiple Master font}}
if {[S 0 == {\012\001\001\000Copyright\ (c)\ 199}]} {emit {Adobe Multiple Master font}}
if {[S 0 == OTTO]} {emit {OpenType font data}}
if {[S 0 == <MakerFile]} {emit {FrameMaker document}
if {[S 11 == 5.5]} {emit {\(5.5}}
if {[S 11 == 5.0]} {emit {\(5.0}}
if {[S 11 == 4.0]} {emit {\(4.0}}
if {[S 11 == 3.0]} {emit {\(3.0}}
if {[S 11 == 2.0]} {emit {\(2.0}}
if {[S 11 == 1.0]} {emit {\(1.0}}
if {[N c 14 x {}]} {emit {%c\)}}
}
if {[S 0 == <MIFFile]} {emit {FrameMaker MIF \(ASCII\) file}
if {[S 9 == 4.0]} {emit {\(4.0\)}}
if {[S 9 == 3.0]} {emit {\(3.0\)}}
if {[S 9 == 2.0]} {emit {\(2.0\)}}
if {[S 9 == 1.0]} {emit {\(1.x\)}}
}
if {[S 0 == <MakerDictionary]} {emit {FrameMaker Dictionary text}
if {[S 17 == 3.0]} {emit {\(3.0\)}}
if {[S 17 == 2.0]} {emit {\(2.0\)}}
if {[S 17 == 1.0]} {emit {\(1.x\)}}
}
if {[S 0 == <MakerScreenFont]} {emit {FrameMaker Font file}
if {[S 17 == 1.01]} {emit {\(%s\)}}
}
if {[S 0 == <MML]} {emit {FrameMaker MML file}}
if {[S 0 == <BookFile]} {emit {FrameMaker Book file}
if {[S 10 == 3.0]} {emit {\(3.0}}
if {[S 10 == 2.0]} {emit {\(2.0}}
if {[S 10 == 1.0]} {emit {\(1.0}}
if {[N c 13 x {}]} {emit {%c\)}}
}
if {[S 0 == <Maker]} {emit {Intermediate Print File	FrameMaker IPL file}}
switch -- [Nv i 0 &0377777777] 8782087 {emit FreeBSD/i386
if {[N i 20 < 0x1000]} {if {[N c 3 & 0x80 &0xC0]} {emit {shared library}}
switch -- [Nv c 3 &0xC0] 64 {emit {PIC object}} 0 {emit object} 
}
if {[N i 20 > 0xfff]} {switch -- [Nv c 3 &0x80] -128 {emit {dynamically linked executable}} 0 {emit executable} 
}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 8782088 {emit {FreeBSD/i386 pure}
if {[N i 20 < 0x1000]} {if {[N c 3 & 0x80 &0xC0]} {emit {shared library}}
switch -- [Nv c 3 &0xC0] 64 {emit {PIC object}} 0 {emit object} 
}
if {[N i 20 > 0xfff]} {switch -- [Nv c 3 &0x80] -128 {emit {dynamically linked executable}} 0 {emit executable} 
}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 8782091 {emit {FreeBSD/i386 demand paged}
if {[N i 20 < 0x1000]} {if {[N c 3 & 0x80 &0xC0]} {emit {shared library}}
switch -- [Nv c 3 &0xC0] 64 {emit {PIC object}} 0 {emit object} 
}
if {[N i 20 > 0xfff]} {switch -- [Nv c 3 &0x80] -128 {emit {dynamically linked executable}} 0 {emit executable} 
}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 8782028 {emit {FreeBSD/i386 compact demand paged}
if {[N i 20 < 0x1000]} {if {[N c 3 & 0x80 &0xC0]} {emit {shared library}}
switch -- [Nv c 3 &0xC0] 64 {emit {PIC object}} 0 {emit object} 
}
if {[N i 20 > 0xfff]} {switch -- [Nv c 3 &0x80] -128 {emit {dynamically linked executable}} 0 {emit executable} 
}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 
if {[S 7 == {\357\020\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0}]} {emit {FreeBSD/i386 a.out core file}
if {[S 1039 x {}]} {emit {from '%s'}}
}
if {[S 0 == SCRSHOT_]} {emit {scrshot\(1\) screenshot,}
if {[N c 8 x {}]} {emit {version %d,}}
if {[N c 9 == 0x2]} {emit {%d bytes in header,}
if {[N c 10 x {}]} {emit {%d chars wide by}}
if {[N c 11 x {}]} {emit {%d chars high}}
}
}
if {[S 1 == WAD]} {emit {DOOM data,}
if {[S 0 == I]} {emit {main wad}}
if {[S 0 == P]} {emit {patch wad}}
if {[N c 0 x {}]} {emit {unknown junk}}
}
if {[S 0 == IDP2]} {emit {Quake II 3D Model file,}
if {[N Q 20 x {}]} {emit {%lu skin\(s\),}}
if {[N Q 8 x {}]} {emit {\(%lu x}}
if {[N Q 12 x {}]} {emit {%lu\),}}
if {[N Q 40 x {}]} {emit {%lu frame\(s\),}}
if {[N Q 16 x {}]} {emit {Frame size %lu bytes,}}
if {[N Q 24 x {}]} {emit {%lu vertices/frame,}}
if {[N Q 28 x {}]} {emit {%lu texture coordinates,}}
if {[N Q 32 x {}]} {emit {%lu triangles/frame}}
}
if {[S 0 == IBSP]} {emit Quake
switch -- [Nv Q 4] 38 {emit {II Map file \(BSP\)}} 46 {emit {III Map file \(BSP\)}} 
}
if {[S 0 == IDS2]} {emit {Quake II SP2 sprite file}}
if {[S 0 == IWAD]} {emit {DOOM or DOOM ][ world}}
if {[S 0 == PWAD]} {emit {DOOM or DOOM ][ extension world}}
if {[S 0 == {\xcb\x1dBoom\xe6\xff\x03\x01}]} {emit {Boom or linuxdoom demo}}
if {[S 24 == {LxD\ 203}]} {emit {Linuxdoom save}
if {[S 0 x {}]} {emit {, name=%s}}
if {[S 44 x {}]} {emit {, world=%s}}
}
if {[S 0 == PACK]} {emit {Quake I or II world or extension}}
if {[S 0 == {5\x0aIntroduction}]} {emit {Quake I save: start Introduction}}
if {[S 0 == {5\x0athe_Slipgate_Complex}]} {emit {Quake I save: e1m1 The slipgate complex}}
if {[S 0 == {5\x0aCastle_of_the_Damned}]} {emit {Quake I save: e1m2 Castle of the damned}}
if {[S 0 == {5\x0athe_Necropolis}]} {emit {Quake I save: e1m3 The necropolis}}
if {[S 0 == {5\x0athe_Grisly_Grotto}]} {emit {Quake I save: e1m4 The grisly grotto}}
if {[S 0 == {5\x0aZiggurat_Vertigo}]} {emit {Quake I save: e1m8 Ziggurat vertigo \(secret\)}}
if {[S 0 == {5\x0aGloom_Keep}]} {emit {Quake I save: e1m5 Gloom keep}}
if {[S 0 == {5\x0aThe_Door_To_Chthon}]} {emit {Quake I save: e1m6 The door to Chthon}}
if {[S 0 == {5\x0aThe_House_of_Chthon}]} {emit {Quake I save: e1m7 The house of Chthon}}
if {[S 0 == {5\x0athe_Installation}]} {emit {Quake I save: e2m1 The installation}}
if {[S 0 == {5\x0athe_Ogre_Citadel}]} {emit {Quake I save: e2m2 The ogre citadel}}
if {[S 0 == {5\x0athe_Crypt_of_Decay}]} {emit {Quake I save: e2m3 The crypt of decay \(dopefish lives!\)}}
if {[S 0 == {5\x0aUnderearth}]} {emit {Quake I save: e2m7 Underearth \(secret\)}}
if {[S 0 == {5\x0athe_Ebon_Fortress}]} {emit {Quake I save: e2m4 The ebon fortress}}
if {[S 0 == {5\x0athe_Wizard's_Manse}]} {emit {Quake I save: e2m5 The wizard's manse}}
if {[S 0 == {5\x0athe_Dismal_Oubliette}]} {emit {Quake I save: e2m6 The dismal oubliette}}
if {[S 0 == {5\x0aTermination_Central}]} {emit {Quake I save: e3m1 Termination central}}
if {[S 0 == {5\x0aVaults_of_Zin}]} {emit {Quake I save: e3m2 Vaults of Zin}}
if {[S 0 == {5\x0athe_Tomb_of_Terror}]} {emit {Quake I save: e3m3 The tomb of terror}}
if {[S 0 == {5\x0aSatan's_Dark_Delight}]} {emit {Quake I save: e3m4 Satan's dark delight}}
if {[S 0 == {5\x0athe_Haunted_Halls}]} {emit {Quake I save: e3m7 The haunted halls \(secret\)}}
if {[S 0 == {5\x0aWind_Tunnels}]} {emit {Quake I save: e3m5 Wind tunnels}}
if {[S 0 == {5\x0aChambers_of_Torment}]} {emit {Quake I save: e3m6 Chambers of torment}}
if {[S 0 == {5\x0athe_Sewage_System}]} {emit {Quake I save: e4m1 The sewage system}}
if {[S 0 == {5\x0aThe_Tower_of_Despair}]} {emit {Quake I save: e4m2 The tower of despair}}
if {[S 0 == {5\x0aThe_Elder_God_Shrine}]} {emit {Quake I save: e4m3 The elder god shrine}}
if {[S 0 == {5\x0athe_Palace_of_Hate}]} {emit {Quake I save: e4m4 The palace of hate}}
if {[S 0 == {5\x0aHell's_Atrium}]} {emit {Quake I save: e4m5 Hell's atrium}}
if {[S 0 == {5\x0athe_Nameless_City}]} {emit {Quake I save: e4m8 The nameless city \(secret\)}}
if {[S 0 == {5\x0aThe_Pain_Maze}]} {emit {Quake I save: e4m6 The pain maze}}
if {[S 0 == {5\x0aAzure_Agony}]} {emit {Quake I save: e4m7 Azure agony}}
if {[S 0 == {5\x0aShub-Niggurath's_Pit}]} {emit {Quake I save: end Shub-Niggurath's pit}}
if {[S 0 == {5\x0aPlace_of_Two_Deaths}]} {emit {Quake I save: dm1 Place of two deaths}}
if {[S 0 == {5\x0aClaustrophobopolis}]} {emit {Quake I save: dm2 Claustrophobopolis}}
if {[S 0 == {5\x0aThe_Abandoned_Base}]} {emit {Quake I save: dm3 The abandoned base}}
if {[S 0 == {5\x0aThe_Bad_Place}]} {emit {Quake I save: dm4 The bad place}}
if {[S 0 == {5\x0aThe_Cistern}]} {emit {Quake I save: dm5 The cistern}}
if {[S 0 == {5\x0aThe_Dark_Zone}]} {emit {Quake I save: dm6 The dark zone}}
if {[S 0 == {5\x0aCommand_HQ}]} {emit {Quake I save: start Command HQ}}
if {[S 0 == {5\x0aThe_Pumping_Station}]} {emit {Quake I save: hip1m1 The pumping station}}
if {[S 0 == {5\x0aStorage_Facility}]} {emit {Quake I save: hip1m2 Storage facility}}
if {[S 0 == {5\x0aMilitary_Complex}]} {emit {Quake I save: hip1m5 Military complex \(secret\)}}
if {[S 0 == {5\x0athe_Lost_Mine}]} {emit {Quake I save: hip1m3 The lost mine}}
if {[S 0 == {5\x0aResearch_Facility}]} {emit {Quake I save: hip1m4 Research facility}}
if {[S 0 == {5\x0aAncient_Realms}]} {emit {Quake I save: hip2m1 Ancient realms}}
if {[S 0 == {5\x0aThe_Gremlin's_Domain}]} {emit {Quake I save: hip2m6 The gremlin's domain \(secret\)}}
if {[S 0 == {5\x0aThe_Black_Cathedral}]} {emit {Quake I save: hip2m2 The black cathedral}}
if {[S 0 == {5\x0aThe_Catacombs}]} {emit {Quake I save: hip2m3 The catacombs}}
if {[S 0 == {5\x0athe_Crypt__}]} {emit {Quake I save: hip2m4 The crypt}}
if {[S 0 == {5\x0aMortum's_Keep}]} {emit {Quake I save: hip2m5 Mortum's keep}}
if {[S 0 == {5\x0aTur_Torment}]} {emit {Quake I save: hip3m1 Tur torment}}
if {[S 0 == {5\x0aPandemonium}]} {emit {Quake I save: hip3m2 Pandemonium}}
if {[S 0 == {5\x0aLimbo}]} {emit {Quake I save: hip3m3 Limbo}}
if {[S 0 == {5\x0athe_Edge_of_Oblivion}]} {emit {Quake I save: hipdm1 The edge of oblivion \(secret\)}}
if {[S 0 == {5\x0aThe_Gauntlet}]} {emit {Quake I save: hip3m4 The gauntlet}}
if {[S 0 == {5\x0aArmagon's_Lair}]} {emit {Quake I save: hipend Armagon's lair}}
if {[S 0 == {5\x0aThe_Academy}]} {emit {Quake I save: start The academy}}
if {[S 0 == {5\x0aThe_Lab}]} {emit {Quake I save: d1 The lab}}
if {[S 0 == {5\x0aArea_33}]} {emit {Quake I save: d1b Area 33}}
if {[S 0 == {5\x0aSECRET_MISSIONS}]} {emit {Quake I save: d3b Secret missions}}
if {[S 0 == {5\x0aThe_Hospital}]} {emit {Quake I save: d10 The hospital \(secret\)}}
if {[S 0 == {5\x0aThe_Genetics_Lab}]} {emit {Quake I save: d11 The genetics lab \(secret\)}}
if {[S 0 == {5\x0aBACK_2_MALICE}]} {emit {Quake I save: d4b Back to Malice}}
if {[S 0 == {5\x0aArea44}]} {emit {Quake I save: d1c Area 44}}
if {[S 0 == {5\x0aTakahiro_Towers}]} {emit {Quake I save: d2 Takahiro towers}}
if {[S 0 == {5\x0aA_Rat's_Life}]} {emit {Quake I save: d3 A rat's life}}
if {[S 0 == {5\x0aInto_The_Flood}]} {emit {Quake I save: d4 Into the flood}}
if {[S 0 == {5\x0aThe_Flood}]} {emit {Quake I save: d5 The flood}}
if {[S 0 == {5\x0aNuclear_Plant}]} {emit {Quake I save: d6 Nuclear plant}}
if {[S 0 == {5\x0aThe_Incinerator_Plant}]} {emit {Quake I save: d7 The incinerator plant}}
if {[S 0 == {5\x0aThe_Foundry}]} {emit {Quake I save: d7b The foundry}}
if {[S 0 == {5\x0aThe_Underwater_Base}]} {emit {Quake I save: d8 The underwater base}}
if {[S 0 == {5\x0aTakahiro_Base}]} {emit {Quake I save: d9 Takahiro base}}
if {[S 0 == {5\x0aTakahiro_Laboratories}]} {emit {Quake I save: d12 Takahiro laboratories}}
if {[S 0 == {5\x0aStayin'_Alive}]} {emit {Quake I save: d13 Stayin' alive}}
if {[S 0 == {5\x0aB.O.S.S._HQ}]} {emit {Quake I save: d14 B.O.S.S. HQ}}
if {[S 0 == {5\x0aSHOWDOWN!}]} {emit {Quake I save: d15 Showdown!}}
if {[S 0 == {5\x0aThe_Seventh_Precinct}]} {emit {Quake I save: ddm1 The seventh precinct}}
if {[S 0 == {5\x0aSub_Station}]} {emit {Quake I save: ddm2 Sub station}}
if {[S 0 == {5\x0aCrazy_Eights!}]} {emit {Quake I save: ddm3 Crazy eights!}}
if {[S 0 == {5\x0aEast_Side_Invertationa}]} {emit {Quake I save: ddm4 East side invertationa}}
if {[S 0 == {5\x0aSlaughterhouse}]} {emit {Quake I save: ddm5 Slaughterhouse}}
if {[S 0 == {5\x0aDOMINO}]} {emit {Quake I save: ddm6 Domino}}
if {[S 0 == {5\x0aSANDRA'S_LADDER}]} {emit {Quake I save: ddm7 Sandra's ladder}}
if {[S 0 == MComprHD]} {emit {MAME CHD compressed hard disk image,}
if {[N I 12 x {}]} {emit {version %lu}}
}
if {[S 0 == gpch]} {emit {GCC precompiled header}
if {[N c 5 x {}]} {emit {\(version %c}}
if {[N c 6 x {}]} {emit {\b%c}}
if {[N c 7 x {}]} {emit {\b%c\)}}
switch -- [Nv c 4] 67 {emit {for C}} 111 {emit {for Objective C}} 43 {emit {for C++}} 79 {emit {for Objective C++}} 
}
if {[S 0 == {GIMP\ Gradient}]} {emit {GIMP gradient data}}
if {[S 0 == {gimp\ xcf}]} {emit {GIMP XCF image data,}
if {[S 9 == file]} {emit {version 0,}}
if {[S 9 == v]} {emit version
if {[S 10 x {}]} {emit %s,}
}
if {[N I 14 x {}]} {emit {%lu x}}
if {[N I 18 x {}]} {emit %lu,}
switch -- [Nv I 22] 0 {emit {RGB Color}} 1 {emit Greyscale} 2 {emit {Indexed Color}} 
if {[N I 22 > 0x2]} {emit {Unknown Image Type.}}
}
if {[S 20 == GPAT]} {emit {GIMP pattern data,}
if {[S 24 x {}]} {emit %s}
}
if {[S 20 == GIMP]} {emit {GIMP brush data}}
if {[S 0 == {\336\22\4\225}]} {emit {GNU message catalog \(little endian\),}
if {[N i 4 x {}]} {emit {revision %d,}}
if {[N i 8 x {}]} {emit {%d messages}}
}
if {[S 0 == {\225\4\22\336}]} {emit {GNU message catalog \(big endian\),}
if {[N I 4 x {}]} {emit {revision %d,}}
if {[N I 8 x {}]} {emit {%d messages}}
}
if {[S 0 == *nazgul*]} {emit {Nazgul style compiled message catalog}
if {[N i 8 > 0x0]} {emit {\b, version %ld}}
}
if {[S 0 == {\001gpg}]} {emit {GPG key trust database}
if {[N c 4 x {}]} {emit {version %d}}
}
if {[S 39 == <gmr:Workbook]} {emit {Gnumeric spreadsheet}}
if {[S 0 == {\0LOCATE}]} {emit {GNU findutils locate database data}
if {[S 7 x {}]} {emit {\b, format %s}}
if {[S 7 == 02]} {emit {\b \(frcode\)}}
}
if {[S 0 == {\000\000\0001\000\000\0000\000\000\0000\000\000\0002\000\000\0000\000\000\0000\000\000\0003}]} {emit {old ACE/gr binary file}
if {[N c 39 > 0x0]} {emit {- version %c}}
}
if {[S 0 == {\#\ xvgr\ parameter\ file}]} {emit {ACE/gr ascii file}}
if {[S 0 == {\#\ xmgr\ parameter\ file}]} {emit {ACE/gr ascii file}}
if {[S 0 == {\#\ ACE/gr\ parameter\ file}]} {emit {ACE/gr ascii file}}
if {[S 0 == {\#\ Grace\ project\ file}]} {emit {Grace project file}
if {[S 23 == {@version\ }]} {emit {\(version}
if {[N c 32 > 0x0]} {emit %c}
if {[S 33 x {}]} {emit {\b.%.2s}}
if {[S 35 x {}]} {emit {\b.%.2s\)}}
}
}
if {[S 0 == {\#\ ACE/gr\ fit\ description\ }]} {emit {ACE/gr fit description file}}
if {[S 0 == {\211HDF\r\n\032}]} {emit {Hierarchical Data Format \(version 5\) data}}
if {[S 0 == Bitmapfile]} {emit {HP Bitmapfile}}
if {[S 0 == IMGfile]} {emit {CIS 	compimg HP Bitmapfile}}
if {[S 0 == msgcat01]} {emit {HP NLS message catalog,}
if {[N Q 8 > 0x0]} {emit {%d messages}}
}
if {[S 0 == HPHP48-]} {emit {HP48 binary}
if {[N c 7 > 0x0]} {emit {- Rev %c}}
switch -- [Nv S 8] 4393 {emit {\(ADR\)}} 13097 {emit {\(REAL\)}} 21801 {emit {\(LREAL\)}} 30505 {emit {\(COMPLX\)}} -25303 {emit {\(LCOMPLX\)}} -16599 {emit {\(CHAR\)}} -6103 {emit {\(ARRAY\)}} 2602 {emit {\(LNKARRAY\)}} 11306 {emit {\(STRING\)}} 20010 {emit {\(HXS\)}} 29738 {emit {\(LIST\)}} -27094 {emit {\(DIR\)}} -18390 {emit {\(ALG\)}} -9686 {emit {\(UNIT\)}} -982 {emit {\(TAGGED\)}} 7723 {emit {\(GROB\)}} 16427 {emit {\(LIB\)}} 25131 {emit {\(BACKUP\)}} -30677 {emit {\(LIBDATA\)}} -25299 {emit {\(PROG\)}} -13267 {emit {\(CODE\)}} 18478 {emit {\(GNAME\)}} 27950 {emit {\(LNAME\)}} -28114 {emit {\(XLIB\)}} 
}
if {[S 0 == %%HP:]} {emit {HP48 text}
if {[S 6 == T(0)]} {emit {- T\(0\)}}
if {[S 6 == T(1)]} {emit {- T\(1\)}}
if {[S 6 == T(2)]} {emit {- T\(2\)}}
if {[S 6 == T(3)]} {emit {- T\(3\)}}
if {[S 10 == A(D)]} {emit {A\(D\)}}
if {[S 10 == A(R)]} {emit {A\(R\)}}
if {[S 10 == A(G)]} {emit {A\(G\)}}
if {[S 14 == F(.)]} {emit {F\(.\);}}
if {[S 14 == F(,)]} {emit {F\(,\);}}
}
if {[S 16 == HP-UX]} {if {[N I 0 == 0x2]} {if {[N I 12 == 0x3c]} {switch -- [Nv I 76] 256 {emit {}
if {[N I 88 == 0x44]} {if {[N I 160 == 0x1]} {if {[N I 172 == 0x4]} {if {[N I 176 == 0x1]} {if {[N I 180 == 0x4]} {emit {core file}
if {[S 144 x {}]} {emit {from '%s'}}
switch -- [Nv I 196] 3 {emit {- received SIGQUIT}} 4 {emit {- received SIGILL}} 5 {emit {- received SIGTRAP}} 6 {emit {- received SIGABRT}} 7 {emit {- received SIGEMT}} 8 {emit {- received SIGFPE}} 10 {emit {- received SIGBUS}} 11 {emit {- received SIGSEGV}} 12 {emit {- received SIGSYS}} 33 {emit {- received SIGXCPU}} 34 {emit {- received SIGXFSZ}} 
}
}
}
}
}
} 1 {emit {}
if {[N I 88 == 0x4]} {if {[N I 92 == 0x1]} {if {[N I 96 == 0x100]} {if {[N I 108 == 0x44]} {if {[N I 180 == 0x4]} {emit {core file}
if {[S 164 x {}]} {emit {from '%s'}}
switch -- [Nv I 196] 3 {emit {- received SIGQUIT}} 4 {emit {- received SIGILL}} 5 {emit {- received SIGTRAP}} 6 {emit {- received SIGABRT}} 7 {emit {- received SIGEMT}} 8 {emit {- received SIGFPE}} 10 {emit {- received SIGBUS}} 11 {emit {- received SIGSEGV}} 12 {emit {- received SIGSYS}} 33 {emit {- received SIGXCPU}} 34 {emit {- received SIGXFSZ}} 
}
}
}
}
}
} 
}
}
}
if {[S 36 == HP-UX]} {if {[N I 0 == 0x1]} {if {[N I 12 == 0x4]} {if {[N I 16 == 0x1]} {if {[N I 20 == 0x2]} {if {[N I 32 == 0x3c]} {if {[N I 96 == 0x100]} {if {[N I 108 == 0x44]} {if {[N I 180 == 0x4]} {emit {core file}
if {[S 164 x {}]} {emit {from '%s'}}
switch -- [Nv I 196] 3 {emit {- received SIGQUIT}} 4 {emit {- received SIGILL}} 5 {emit {- received SIGTRAP}} 6 {emit {- received SIGABRT}} 7 {emit {- received SIGEMT}} 8 {emit {- received SIGFPE}} 10 {emit {- received SIGBUS}} 11 {emit {- received SIGSEGV}} 12 {emit {- received SIGSYS}} 33 {emit {- received SIGXCPU}} 34 {emit {- received SIGXFSZ}} 
}
}
}
}
}
}
}
}
}
if {[S 100 == HP-UX]} {if {[N I 0 == 0x100]} {if {[N I 12 == 0x44]} {if {[N I 84 == 0x2]} {if {[N I 96 == 0x3c]} {if {[N I 160 == 0x1]} {if {[N I 172 == 0x4]} {if {[N I 176 == 0x1]} {if {[N I 180 == 0x4]} {emit {core file}
if {[S 68 x {}]} {emit {from '%s'}}
switch -- [Nv I 196] 3 {emit {- received SIGQUIT}} 4 {emit {- received SIGILL}} 5 {emit {- received SIGTRAP}} 6 {emit {- received SIGABRT}} 7 {emit {- received SIGEMT}} 8 {emit {- received SIGFPE}} 10 {emit {- received SIGBUS}} 11 {emit {- received SIGSEGV}} 12 {emit {- received SIGSYS}} 33 {emit {- received SIGXCPU}} 34 {emit {- received SIGXFSZ}} 
}
}
}
}
}
}
}
}
}
if {[S 120 == HP-UX]} {switch -- [Nv I 0] 1 {emit {}
if {[N I 12 == 0x4]} {if {[N I 16 == 0x1]} {if {[N I 20 == 0x100]} {if {[N I 32 == 0x44]} {if {[N I 104 == 0x2]} {if {[N I 116 == 0x3c]} {if {[N I 180 == 0x4]} {emit {core file}
if {[S 88 x {}]} {emit {from '%s'}}
switch -- [Nv I 196] 3 {emit {- received SIGQUIT}} 4 {emit {- received SIGILL}} 5 {emit {- received SIGTRAP}} 6 {emit {- received SIGABRT}} 7 {emit {- received SIGEMT}} 8 {emit {- received SIGFPE}} 10 {emit {- received SIGBUS}} 11 {emit {- received SIGSEGV}} 12 {emit {- received SIGSYS}} 33 {emit {- received SIGXCPU}} 34 {emit {- received SIGXFSZ}} 
}
}
}
}
}
}
}
} 256 {emit {}
if {[N I 12 == 0x44]} {if {[N I 84 == 0x1]} {if {[N I 96 == 0x4]} {if {[N I 100 == 0x1]} {if {[N I 104 == 0x2]} {if {[N I 116 == 0x2c]} {if {[N I 180 == 0x4]} {emit {core file}
if {[S 68 x {}]} {emit {from '%s'}}
switch -- [Nv I 196] 3 {emit {- received SIGQUIT}} 4 {emit {- received SIGILL}} 5 {emit {- received SIGTRAP}} 6 {emit {- received SIGABRT}} 7 {emit {- received SIGEMT}} 8 {emit {- received SIGFPE}} 10 {emit {- received SIGBUS}} 11 {emit {- received SIGSEGV}} 12 {emit {- received SIGSYS}} 33 {emit {- received SIGXCPU}} 34 {emit {- received SIGXFSZ}} 
}
}
}
}
}
}
}
} 
}
if {[S 0 == HPHP49-]} {emit {HP49 binary}}
if {[S 0 == 0xabcdef]} {emit {AIX message catalog}}
if {[S 0 == <aiaff>]} {emit archive}
if {[S 0 == <bigaf>]} {emit {archive \(big format\)}}
if {[S 0 == FORM]} {emit {IFF data}
if {[S 8 == AIFF]} {emit {\b, AIFF audio}}
if {[S 8 == AIFC]} {emit {\b, AIFF-C compressed audio}}
if {[S 8 == 8SVX]} {emit {\b, 8SVX 8-bit sampled sound voice}}
if {[S 8 == SAMP]} {emit {\b, SAMP sampled audio}}
if {[S 8 == DTYP]} {emit {\b, DTYP datatype description}}
if {[S 8 == PTCH]} {emit {\b, PTCH binary patch}}
if {[S 8 == ILBMBMHD]} {emit {\b, ILBM interleaved image}
if {[N S 20 x {}]} {emit {\b, %d x}}
if {[N S 22 x {}]} {emit %d}
}
if {[S 8 == RGBN]} {emit {\b, RGBN 12-bit RGB image}}
if {[S 8 == RGB8]} {emit {\b, RGB8 24-bit RGB image}}
if {[S 8 == DR2D]} {emit {\b, DR2D 2-D object}}
if {[S 8 == TDDD]} {emit {\b, TDDD 3-D rendering}}
if {[S 8 == FTXT]} {emit {\b, FTXT formatted text}}
if {[S 8 == CTLG]} {emit {\b, CTLG message catalog}}
if {[S 8 == PREF]} {emit {\b, PREF preferences}}
}
switch -- [Nv I 1 &0xfff7ffff] 16842752 {emit {Targa image data - Map}
if {[N c 2 == 0x8 &8]} {emit {- RLE}}
if {[N s 12 > 0x0]} {emit {%hd x}}
if {[N s 14 > 0x0]} {emit %hd}
} 131072 {emit {Targa image data - RGB}
if {[N c 2 == 0x8 &8]} {emit {- RLE}}
if {[N s 12 > 0x0]} {emit {%hd x}}
if {[N s 14 > 0x0]} {emit %hd}
} 196608 {emit {Targa image data - Mono}
if {[N c 2 == 0x8 &8]} {emit {- RLE}}
if {[N s 12 > 0x0]} {emit {%hd x}}
if {[N s 14 > 0x0]} {emit %hd}
} 
if {[S 0 == P1]} {emit {Netpbm PBM image text}}
if {[S 0 == P2]} {emit {Netpbm PGM image text}}
if {[S 0 == P3]} {emit {Netpbm PPM image text}}
if {[S 0 == P4]} {emit {Netpbm PBM \"rawbits\" image data}}
if {[S 0 == P5]} {emit {Netpbm PGM \"rawbits\" image data}}
if {[S 0 == P6]} {emit {Netpbm PPM \"rawbits\" image data}}
if {[S 0 == P7]} {emit {Netpbm PAM image file}}
if {[S 0 == {\117\072}]} {emit {Solitaire Image Recorder format}
if {[S 4 == {\013}]} {emit {MGI Type 11}}
if {[S 4 == {\021}]} {emit {MGI Type 17}}
}
if {[S 0 == .MDA]} {emit {MicroDesign data}
switch -- [Nv c 21] 48 {emit {version 2}} 51 {emit {version 3}} 
}
if {[S 0 == .MDP]} {emit {MicroDesign page data}
switch -- [Nv c 21] 48 {emit {version 2}} 51 {emit {version 3}} 
}
if {[S 0 == IIN1]} {emit {NIFF image data}}
if {[S 0 == {MM\x00\x2a}]} {emit {TIFF image data, big-endian}}
if {[S 0 == {II\x2a\x00}]} {emit {TIFF image data, little-endian}}
if {[S 0 == {\x89PNG}]} {emit {PNG image data,}
if {[N I 4 != 0xd0a1a0a]} {emit CORRUPTED,}
if {[N I 4 == 0xd0a1a0a]} {if {[N I 16 x {}]} {emit {%ld x}}
if {[N I 20 x {}]} {emit %ld,}
if {[N c 24 x {}]} {emit %d-bit}
switch -- [Nv c 25] 0 {emit grayscale,} 2 {emit {\b/color RGB,}} 3 {emit colormap,} 4 {emit gray+alpha,} 6 {emit {\b/color RGBA,}} 
switch -- [Nv c 28] 0 {emit non-interlaced} 1 {emit interlaced} 
}
}
if {[S 1 == PNG]} {emit {PNG image data, CORRUPTED}}
if {[S 0 == GIF8]} {emit {GIF image data}
if {[S 4 == 7a]} {emit {\b, version 8%s,}}
if {[S 4 == 9a]} {emit {\b, version 8%s,}}
if {[N s 6 > 0x0]} {emit {%hd x}}
if {[N s 8 > 0x0]} {emit %hd}
}
if {[S 0 == {\361\0\100\273}]} {emit {CMU window manager raster image data}
if {[N i 4 > 0x0]} {emit {%d x}}
if {[N i 8 > 0x0]} {emit %d,}
if {[N i 12 > 0x0]} {emit %d-bit}
}
if {[S 0 == id=ImageMagick]} {emit {MIFF image data}}
if {[S 0 == {\#FIG}]} {emit {FIG image text}
if {[S 5 x {}]} {emit {\b, version %.3s}}
}
if {[S 0 == ARF_BEGARF]} {emit {PHIGS clear text archive}}
if {[S 0 == {@(\#)SunPHIGS}]} {emit SunPHIGS
if {[S 40 == SunBin]} {emit binary}
if {[S 32 == archive]} {emit archive}
}
if {[S 0 == GKSM]} {emit {GKS Metafile}
if {[S 24 == SunGKS]} {emit {\b, SunGKS}}
}
if {[S 0 == BEGMF]} {emit {clear text Computer Graphics Metafile}}
if {[N S 0 == 0x20 &0xffe0]} {emit {binary Computer Graphics Metafile}}
if {[S 0 == yz]} {emit {MGR bitmap, modern format, 8-bit aligned}}
if {[S 0 == zz]} {emit {MGR bitmap, old format, 1-bit deep, 16-bit aligned}}
if {[S 0 == xz]} {emit {MGR bitmap, old format, 1-bit deep, 32-bit aligned}}
if {[S 0 == yx]} {emit {MGR bitmap, modern format, squeezed}}
if {[S 0 == {%bitmap\0}]} {emit {FBM image data}
switch -- [Nv Q 30] 49 {emit {\b, mono}} 51 {emit {\b, color}} 
}
if {[S 1 == {PC\ Research,\ Inc}]} {emit {group 3 fax data}
switch -- [Nv c 29] 0 {emit {\b, normal resolution \(204x98 DPI\)}} 1 {emit {\b, fine resolution \(204x196 DPI\)}} 
}
if {[S 0 == Sfff]} {emit {structured fax file}}
if {[S 0 == BM]} {emit {PC bitmap data}
switch -- [Nv s 14] 12 {emit {\b, OS/2 1.x format}
if {[N s 18 x {}]} {emit {\b, %d x}}
if {[N s 20 x {}]} {emit %d}
} 64 {emit {\b, OS/2 2.x format}
if {[N s 18 x {}]} {emit {\b, %d x}}
if {[N s 20 x {}]} {emit %d}
} 40 {emit {\b, Windows 3.x format}
if {[N i 18 x {}]} {emit {\b, %d x}}
if {[N i 22 x {}]} {emit {%d x}}
if {[N s 28 x {}]} {emit %d}
} 
}
if {[S 0 == {/*\ XPM\ */}]} {emit {X pixmap image text}}
if {[S 0 == {Imagefile\ version-}]} {emit {iff image data}
if {[S 10 x {}]} {emit %s}
}
if {[S 0 == IT01]} {emit {FIT image data}
if {[N I 4 x {}]} {emit {\b, %d x}}
if {[N I 8 x {}]} {emit {%d x}}
if {[N I 12 x {}]} {emit %d}
}
if {[S 0 == IT02]} {emit {FIT image data}
if {[N I 4 x {}]} {emit {\b, %d x}}
if {[N I 8 x {}]} {emit {%d x}}
if {[N I 12 x {}]} {emit %d}
}
if {[S 2048 == PCD_IPI]} {emit {Kodak Photo CD image pack file}
switch -- [Nv c 3586 &0x03] 0 {emit {, landscape mode}} 1 {emit {, portrait mode}} 2 {emit {, landscape mode}} 3 {emit {, portrait mode}} 
}
if {[S 0 == PCD_OPA]} {emit {Kodak Photo CD overview pack file}}
if {[S 0 == {SIMPLE\ \ =}]} {emit {FITS image data}
if {[S 109 == 8]} {emit {\b, 8-bit, character or unsigned binary integer}}
if {[S 108 == 16]} {emit {\b, 16-bit, two's complement binary integer}}
if {[S 107 == {\ 32}]} {emit {\b, 32-bit, two's complement binary integer}}
if {[S 107 == -32]} {emit {\b, 32-bit, floating point, single precision}}
if {[S 107 == -64]} {emit {\b, 64-bit, floating point, double precision}}
}
if {[S 0 == {This\ is\ a\ BitMap\ file}]} {emit {Lisp Machine bit-array-file}}
if {[S 0 == !!]} {emit {Bennet Yee's \"face\" format}}
if {[S 1536 == {Visio\ (TM)\ Drawing}]} {emit %s}
if {[S 0 == {\%TGIF\ x}]} {emit {Tgif file version %s}}
if {[S 128 == DICM]} {emit {DICOM medical imaging data}}
switch -- [Nv I 4] 7 {emit {XWD X Window Dump image data}
if {[S 100 x {}]} {emit {\b, \"%s\"}}
if {[N I 16 x {}]} {emit {\b, %dx}}
if {[N I 20 x {}]} {emit {\b%dx}}
if {[N I 12 x {}]} {emit {\b%d}}
} 2097152000 {emit GLF_BINARY_LSB_FIRST} 125 {emit GLF_BINARY_MSB_FIRST} 268435456 {emit GLS_BINARY_LSB_FIRST} 16 {emit GLS_BINARY_MSB_FIRST} 19195 {emit {QDOS executable}
if {[S 9 x {} p]} {emit '%s'}
} 
if {[S 0 == NJPL1I00]} {emit {PDS \(JPL\) image data}}
if {[S 2 == NJPL1I]} {emit {PDS \(JPL\) image data}}
if {[S 0 == CCSD3ZF]} {emit {PDS \(CCSD\) image data}}
if {[S 2 == CCSD3Z]} {emit {PDS \(CCSD\) image data}}
if {[S 0 == PDS_]} {emit {PDS image data}}
if {[S 0 == LBLSIZE=]} {emit {PDS \(VICAR\) image data}}
if {[S 0 == pM85]} {emit {Atari ST STAD bitmap image data \(hor\)}
switch -- [Nv c 5] 0 {emit {\(white background\)}} -1 {emit {\(black background\)}} 
}
if {[S 0 == pM86]} {emit {Atari ST STAD bitmap image data \(vert\)}
switch -- [Nv c 5] 0 {emit {\(white background\)}} -1 {emit {\(black background\)}} 
}
if {[S 0 == {\x37\x00\x00\x10\x42\x00\x00\x10\x00\x00\x00\x00\x39\x64\x39\x47}]} {emit {EPOC MBM image file}}
if {[S 0 == 8BPS]} {emit {Adobe Photoshop Image}}
if {[S 0 == {P7\ 332}]} {emit {XV thumbnail image data}}
if {[S 0 == NITF]} {emit {National Imagery Transmission Format}
if {[S 25 x {}]} {emit {dated %.14s}}
}
if {[S 0 == {\0\nSMJPEG}]} {emit SMJPEG
if {[N I 8 x {}]} {emit {%d.x data}}
if {[S 16 == _SND]} {emit {\b,}
if {[N S 24 > 0x0]} {emit {%d Hz}}
switch -- [Nv c 26] 8 {emit 8-bit} 16 {emit 16-bit} 
if {[S 28 == NONE]} {emit uncompressed}
if {[N c 27 == 0x1]} {emit mono}
if {[N c 28 == 0x2]} {emit stereo}
if {[S 32 == _VID]} {emit {\b,}
if {[N I 40 > 0x0]} {emit {%d frames}}
if {[N S 44 > 0x0]} {emit {\(%d x}}
if {[N S 46 > 0x0]} {emit {%d\)}}
}
}
if {[S 16 == _VID]} {emit {\b,}
if {[N I 24 > 0x0]} {emit {%d frames}}
if {[N S 28 > 0x0]} {emit {\(%d x}}
if {[N S 30 > 0x0]} {emit {%d\)}}
}
}
if {[S 0 == {Paint\ Shop\ Pro\ Image\ File}]} {emit {Paint Shop Pro Image File}}
if {[S 0 == {P7\ 332}]} {emit {XV \"thumbnail file\" \(icon\) data}}
if {[S 0 == KiSS]} {emit KISS/GS
switch -- [Nv c 4] 16 {emit color
if {[N c 5 x {}]} {emit {%d bit}}
if {[N s 8 x {}]} {emit {%d colors}}
if {[N s 10 x {}]} {emit {%d groups}}
} 32 {emit cell
if {[N c 5 x {}]} {emit {%d bit}}
if {[N s 8 x {}]} {emit {%d x}}
if {[N s 10 x {}]} {emit %d}
if {[N s 12 x {}]} {emit +%d}
if {[N s 14 x {}]} {emit +%d}
} 
}
if {[S 0 == {C\253\221g\230\0\0\0}]} {emit {Webshots Desktop .wbz file}}
if {[S 0 == CKD_P370]} {emit {Hercules CKD DASD image file}
if {[N Q 8 x {}]} {emit {\b, %d heads per cylinder}}
if {[N Q 12 x {}]} {emit {\b, track size %d bytes}}
if {[N c 16 x {}]} {emit {\b, device type 33%2.2X}}
}
if {[S 0 == CKD_C370]} {emit {Hercules compressed CKD DASD image file}
if {[N Q 8 x {}]} {emit {\b, %d heads per cylinder}}
if {[N Q 12 x {}]} {emit {\b, track size %d bytes}}
if {[N c 16 x {}]} {emit {\b, device type 33%2.2X}}
}
if {[S 0 == CKD_S370]} {emit {Hercules CKD DASD shadow file}
if {[N Q 8 x {}]} {emit {\b, %d heads per cylinder}}
if {[N Q 12 x {}]} {emit {\b, track size %d bytes}}
if {[N c 16 x {}]} {emit {\b, device type 33%2.2X}}
}
if {[S 0 == {\146\031\0\0}]} {emit {Squeak image data}}
if {[S 0 == {'From\040Squeak}]} {emit {Squeak program text}}
if {[S 0 == PaRtImAgE-VoLuMe]} {emit PartImage
if {[S 32 == 0.6.1]} {emit {file version %s}
if {[N i 96 > 0xffffffff]} {emit {volume %ld}}
if {[S 512 x {}]} {emit {type %s}}
if {[S 5120 x {}]} {emit {device %s,}}
if {[S 5632 x {}]} {emit {original filename %s,}}
switch -- [Nv i 10052] 0 {emit {not compressed}} 1 {emit {gzip compressed}} 2 {emit {bzip2 compressed}} 
if {[N i 10052 > 0x2]} {emit {compressed with unknown algorithm}}
}
if {[S 32 > 0.6.1]} {emit {file version %s}}
if {[S 32 < 0.6.1]} {emit {file version %s}}
}
if {[N s 54 == 0x3039]} {emit {Bio-Rad .PIC Image File}
if {[N s 0 > 0x0]} {emit {%hd x}}
if {[N s 2 > 0x0]} {emit %hd,}
if {[N s 4 == 0x1]} {emit {1 image in file}}
if {[N s 4 > 0x1]} {emit {%hd images in file}}
}
if {[S 0 == {\000MRM}]} {emit {Minolta Dimage camera raw image data}}
if {[S 0 == AT&TFORM]} {emit {DjVu Image file}}
if {[S 0 == {CDF\001}]} {emit {NetCDF Data Format data}}
if {[S 0 == {\211HDF\r\n\032}]} {emit {Hierarchical Data Format \(version 5\) data}}
if {[S 0 == {\210OPS}]} {emit {Interleaf saved data}}
if {[S 0 == <!OPS]} {emit {Interleaf document text}
if {[S 5 == {,\ Version\ =}]} {emit {\b, version}
if {[S 17 x {}]} {emit %.3s}
}
}
if {[S 4 == pgscriptver]} {emit {IslandWrite document}}
if {[S 13 == DrawFile]} {emit {IslandDraw document}}
if {[N s 0 == 0x9600 &0xFFFC]} {emit {little endian ispell}
switch -- [Nv c 0] 0 {emit {hash file \(?\),}} 1 {emit {3.0 hash file,}} 2 {emit {3.1 hash file,}} 3 {emit {hash file \(?\),}} 
switch -- [Nv s 2] 0 {emit {8-bit, no capitalization, 26 flags}} 1 {emit {7-bit, no capitalization, 26 flags}} 2 {emit {8-bit, capitalization, 26 flags}} 3 {emit {7-bit, capitalization, 26 flags}} 4 {emit {8-bit, no capitalization, 52 flags}} 5 {emit {7-bit, no capitalization, 52 flags}} 6 {emit {8-bit, capitalization, 52 flags}} 7 {emit {7-bit, capitalization, 52 flags}} 8 {emit {8-bit, no capitalization, 128 flags}} 9 {emit {7-bit, no capitalization, 128 flags}} 10 {emit {8-bit, capitalization, 128 flags}} 11 {emit {7-bit, capitalization, 128 flags}} 12 {emit {8-bit, no capitalization, 256 flags}} 13 {emit {7-bit, no capitalization, 256 flags}} 14 {emit {8-bit, capitalization, 256 flags}} 15 {emit {7-bit, capitalization, 256 flags}} 
if {[N s 4 > 0x0]} {emit {and %d string characters}}
}
if {[N S 0 == 0x9600 &0xFFFC]} {emit {big endian ispell}
switch -- [Nv c 1] 0 {emit {hash file \(?\),}} 1 {emit {3.0 hash file,}} 2 {emit {3.1 hash file,}} 3 {emit {hash file \(?\),}} 
switch -- [Nv S 2] 0 {emit {8-bit, no capitalization, 26 flags}} 1 {emit {7-bit, no capitalization, 26 flags}} 2 {emit {8-bit, capitalization, 26 flags}} 3 {emit {7-bit, capitalization, 26 flags}} 4 {emit {8-bit, no capitalization, 52 flags}} 5 {emit {7-bit, no capitalization, 52 flags}} 6 {emit {8-bit, capitalization, 52 flags}} 7 {emit {7-bit, capitalization, 52 flags}} 8 {emit {8-bit, no capitalization, 128 flags}} 9 {emit {7-bit, no capitalization, 128 flags}} 10 {emit {8-bit, capitalization, 128 flags}} 11 {emit {7-bit, capitalization, 128 flags}} 12 {emit {8-bit, no capitalization, 256 flags}} 13 {emit {7-bit, no capitalization, 256 flags}} 14 {emit {8-bit, capitalization, 256 flags}} 15 {emit {7-bit, capitalization, 256 flags}} 
if {[N S 4 > 0x0]} {emit {and %d string characters}}
}
if {[S 0 == ISPL]} {emit ispell
if {[N Q 4 x {}]} {emit {hash file version %d,}}
if {[N Q 8 x {}]} {emit {lexletters %d,}}
if {[N Q 12 x {}]} {emit {lexsize %d,}}
if {[N Q 16 x {}]} {emit {hashsize %d,}}
if {[N Q 20 x {}]} {emit {stblsize %d}}
}
if {[S 0 == hsi1]} {emit {JPEG image data, HSI proprietary}}
if {[S 0 == {\x00\x00\x00\x0C\x6A\x50\x20\x20\x0D\x0A\x87\x0A}]} {emit {JPEG 2000 image data}}
if {[S 0 == KarmaRHD]} {emit {Version	Karma Data Structure Version}
if {[N I 16 x {}]} {emit %lu}
}
if {[S 0 == lect]} {emit {DEC SRC Virtual Paper Lectern file}}
if {[S 53 == yyprevious]} {emit {C program text \(from lex\)}
if {[S 3 x {}]} {emit {for %s}}
}
if {[S 21 == {generated\ by\ flex}]} {emit {C program text \(from flex\)}}
if {[S 0 == {%\{}]} {emit {lex description text}}
if {[S 0 == {\007\001\000}]} {emit {Linux/i386 object file}
if {[N i 20 > 0x1020]} {emit {\b, DLL library}}
}
if {[S 0 == {\01\03\020\04}]} {emit {Linux-8086 impure executable}
if {[N Q 28 != 0x0]} {emit {not stripped}}
}
if {[S 0 == {\01\03\040\04}]} {emit {Linux-8086 executable}
if {[N Q 28 != 0x0]} {emit {not stripped}}
}
if {[S 0 == {\243\206\001\0}]} {emit {Linux-8086 object file}}
if {[S 0 == {\01\03\020\20}]} {emit {Minix-386 impure executable}
if {[N Q 28 != 0x0]} {emit {not stripped}}
}
if {[S 0 == {\01\03\040\20}]} {emit {Minix-386 executable}
if {[N Q 28 != 0x0]} {emit {not stripped}}
}
if {[N i 216 == 0x111]} {emit {Linux/i386 core file}
if {[S 220 x {}]} {emit {of '%s'}}
if {[N i 200 > 0x0]} {emit {\(signal %d\)}}
}
if {[S 2 == LILO]} {emit {Linux/i386 LILO boot/chain loader}}
if {[S 4086 == SWAP-SPACE]} {emit {Linux/i386 swap file}}
if {[S 4086 == SWAPSPACE2]} {emit {Linux/i386 swap file \(new style\)}
if {[N Q 1024 x {}]} {emit {%d \(4K pages\)}}
if {[N Q 1028 x {}]} {emit {size %d pages}}
}
if {[S 514 == HdrS]} {emit {Linux kernel}
if {[N s 510 == 0xaa55]} {emit {x86 boot executable}
if {[N c 529 == 0x0]} {emit zImage,
if {[N c 529 == 0x1]} {emit bzImage,}
if {[S [I 526 s 512] x {}]} {emit {version %s,}}
}
switch -- [Nv s 498] 1 {emit RO-rootFS,} 0 {emit RW-rootFS,} 
if {[N s 508 > 0x0]} {emit {root_dev 0x%X,}}
if {[N s 502 > 0x0]} {emit {swap_dev 0x%X,}}
if {[N s 504 > 0x0]} {emit {RAMdisksize %u KB,}}
switch -- [Nv s 506] -1 {emit {Normal VGA}} -2 {emit {Extended VGA}} -3 {emit {Prompt for Videomode}} 
if {[N s 506 > 0x0]} {emit {Video mode %d}}
}
}
if {[S 8 == {\ A\ _text}]} {emit {Linux kernel symbol map text}}
if {[S 0 == Begin3]} {emit {Linux Software Map entry text}}
if {[S 0 == Begin4]} {emit {Linux Software Map entry text \(new format\)}}
if {[S 0 == {\xb8\xc0\x07\x8e\xd8\xb8\x00\x90}]} {emit Linux
if {[N s 497 == 0x0]} {emit {x86 boot sector}
switch -- [Nv I 514] 142 {emit {of a kernel from the dawn of time!}} -1869686604 {emit {version 0.99-1.1.42}} -1869686600 {emit {for memtest86}} 
}
if {[N s 497 != 0x0]} {emit {x86 kernel}
if {[N s 504 > 0x0]} {emit {RAMdisksize=%u KB}}
if {[N s 502 > 0x0]} {emit swap=0x%X}
if {[N s 508 > 0x0]} {emit root=0x%X
switch -- [Nv s 498] 1 {emit {\b-ro}} 0 {emit {\b-rw}} 
}
switch -- [Nv s 506] -1 {emit vga=normal} -2 {emit vga=extended} -3 {emit vga=ask} 
if {[N s 506 > 0x0]} {emit vga=%d}
switch -- [Nv I 514] -1869686655 {emit {version 1.1.43-1.1.45}} 364020173 {emit {}
if {[N I 2702 == 0x55aa5a5a]} {emit {version 1.1.46-1.2.13,1.3.0}}
if {[N I 2713 == 0x55aa5a5a]} {emit {version 1.3.1,2}}
if {[N I 2723 == 0x55aa5a5a]} {emit {version 1.3.3-1.3.30}}
if {[N I 2726 == 0x55aa5a5a]} {emit {version 1.3.31-1.3.41}}
if {[N I 2859 == 0x55aa5a5a]} {emit {version 1.3.42-1.3.45}}
if {[N I 2807 == 0x55aa5a5a]} {emit {version 1.3.46-1.3.72}}
} 
if {[S 514 == HdrS]} {if {[N s 518 > 0x1ff]} {switch -- [Nv c 529] 0 {emit {\b, zImage}} 1 {emit {\b, bzImage}} 
if {[S [I 526 s 512] x {}]} {emit {\b, version %s}}
}
}
}
}
if {[N i 0 == 0xc30000e9 &0xFF0000FF]} {emit {Linux-Dev86 executable, headerless}
if {[S 5 == .]} {if {[S 4 x {}]} {emit {\b, libc version %s}}
}
}
if {[N i 0 == 0x4000301 &0xFF00FFFF]} {emit {Linux-8086 executable}
if {[N c 2 != 0x0 &0x01]} {emit {\b, unmapped zero page}}
if {[N c 2 == 0x0 &0x20]} {emit {\b, impure}}
if {[N c 2 != 0x0 &0x20]} {if {[N c 2 != 0x0 &0x10]} {emit {\b, A_EXEC}}
}
if {[N c 2 != 0x0 &0x02]} {emit {\b, A_PAL}}
if {[N c 2 != 0x0 &0x04]} {emit {\b, A_NSYM}}
if {[N c 2 != 0x0 &0x08]} {emit {\b, A_STAND}}
if {[N c 2 != 0x0 &0x40]} {emit {\b, A_PURE}}
if {[N c 2 != 0x0 &0x80]} {emit {\b, A_TOVLY}}
if {[N Q 28 != 0x0]} {emit {\b, not stripped}}
if {[S 37 == .]} {if {[S 36 x {}]} {emit {\b, libc version %s}}
}
}
if {[S 0 == {;;}]} {emit {Lisp/Scheme program text}}
if {[S 0 == {\012(}]} {emit {Emacs v18 byte-compiled Lisp data}}
if {[S 0 == {;ELC}]} {if {[N c 4 > 0x13]} {emit 636 0}
if {[N c 4 < 0x20]} {emit {Emacs/XEmacs v%d byte-compiled Lisp data}}
}
if {[S 0 == {(SYSTEM::VERSION\040'}]} {emit {CLISP byte-compiled Lisp program text}}
if {[S 0 == {\372\372\372\372}]} {emit {MIT scheme \(library?\)}}
if {[S 0 == <TeXmacs|]} {emit {TeXmacs document text}}
if {[S 11 == {must\ be\ converted\ with\ BinHex}]} {emit {BinHex binary text}
if {[S 41 x {}]} {emit {\b, version %.3s}}
}
if {[S 0 == SIT!]} {emit {StuffIt Archive \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == SITD]} {emit {StuffIt Deluxe \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == Seg]} {emit {StuffIt Deluxe Segment \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == StuffIt]} {emit {StuffIt Archive}}
if {[S 0 == APPL]} {emit {Macintosh Application \(data\)}
if {[S 2 x {}]} {emit {\b: %s}}
}
if {[S 0 == zsys]} {emit {Macintosh System File \(data\)}}
if {[S 0 == FNDR]} {emit {Macintosh Finder \(data\)}}
if {[S 0 == libr]} {emit {Macintosh Library \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == shlb]} {emit {Macintosh Shared Library \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == cdev]} {emit {Macintosh Control Panel \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == INIT]} {emit {Macintosh Extension \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == FFIL]} {emit {Macintosh Truetype Font \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == LWFN]} {emit {Macintosh Postscript Font \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == PACT]} {emit {Macintosh Compact Pro Archive \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == ttro]} {emit {Macintosh TeachText File \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == TEXT]} {emit {Macintosh TeachText File \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 0 == PDF]} {emit {Macintosh PDF File \(data\)}
if {[S 2 x {}]} {emit {: %s}}
}
if {[S 102 == mBIN]} {emit {MacBinary III data with surprising version number}}
if {[S 0 == SAS]} {emit SAS
if {[S 24 == DATA]} {emit {data file}}
if {[S 24 == CATALOG]} {emit catalog}
if {[S 24 == INDEX]} {emit {data file index}}
if {[S 24 == VIEW]} {emit {data view}}
}
if {[S 84 == SAS]} {emit {SAS 7+}
if {[S 156 == DATA]} {emit {data file}}
if {[S 156 == CATALOG]} {emit catalog}
if {[S 156 == INDEX]} {emit {data file index}}
if {[S 156 == VIEW]} {emit {data view}}
}
if {[S 0 == {$FL2}]} {emit {SPSS System File}
if {[S 24 x {}]} {emit %s}
}
switch -- [Nvx 1 S 1024] -11561 {emit {Macintosh MFS data}
if {[N S 0 == 0x4c4b]} {emit {\(bootable\)}}
if {[N S 1034 & 0x8000]} {emit {\(locked\)}}
if {[N I 1026 x {} -0x7C25B080]} {emit {created: %s,}}
if {[N I 1030 > 0x0 -0x7C25B080]} {emit {last backup: %s,}}
if {[N I 1044 x {}]} {emit {block size: %d,}}
if {[N S 1042 x {}]} {emit {number of blocks: %d,}}
if {[S 1060 x {} p]} {emit {volume name: %s}}
} 18475 {emit {Macintosh HFS Extended}
if {[N S [R 0] x {}]} {emit {version %d data}}
if {[N S 0 == 0x4c4b]} {emit {\(bootable\)}}
if {[N I 1028 ^ 0x100]} {emit {\(mounted\)}}
if {[N I [R 2] & 0x200]} {emit {\(spared blocks\)}}
if {[N I [R 2] & 0x800]} {emit {\(unclean\)}}
if {[N I [R 2] & 0x8000]} {emit {\(locked\)}}
if {[S [R 6] x {}]} {emit {last mounted by: '%.4s',}}
if {[N I [R 14] x {} -0x7C25B080]} {emit {created: %s,}}
if {[N S [R 18] x {} -0x7C25B080]} {emit {last modified: %s,}}
if {[N S [R 22] > 0x0 -0x7C25B080]} {emit {last backup: %s,}}
if {[N S [R 26] > 0x0 -0x7C25B080]} {emit {last checked: %s,}}
if {[N I [R 38] x {}]} {emit {block size: %d,}}
if {[N I [R 42] x {}]} {emit {number of blocks: %d,}}
if {[N I [R 46] x {}]} {emit {free blocks: %d}}
} 
switch -- [Nv S 512] 20557 {emit {Apple Partition data}
if {[N S 2 x {}]} {emit {block size: %d,}}
if {[S 560 x {}]} {emit {first type: %s,}}
if {[S 528 x {}]} {emit {name: %s,}}
if {[N I 596 x {}]} {emit {number of blocks: %d,}}
if {[N S 1024 == 0x504d]} {if {[S 1072 x {}]} {emit {second type: %s,}}
if {[S 1040 x {}]} {emit {name: %s,}}
if {[N I 1108 x {}]} {emit {number of blocks: %d,}}
if {[N S 2048 == 0x504d]} {if {[S 2096 x {}]} {emit {third type: %s,}}
if {[S 2064 x {}]} {emit {name: %s,}}
if {[N I 2132 x {}]} {emit {number of blocks: %d,}}
if {[N S 2560 == 0x504d]} {if {[S 2608 x {}]} {emit {fourth type: %s,}}
if {[S 2576 x {}]} {emit {name: %s,}}
if {[N I 2644 x {}]} {emit {number of blocks: %d}}
}
}
}
} 21587 {emit {Apple Old Partition data}
if {[N S 2 x {}]} {emit {block size: %d,}}
if {[S 560 x {}]} {emit {first type: %s,}}
if {[S 528 x {}]} {emit {name: %s,}}
if {[N I 596 x {}]} {emit {number of blocks: %d,}}
if {[N S 1024 == 0x504d]} {if {[S 1072 x {}]} {emit {second type: %s,}}
if {[S 1040 x {}]} {emit {name: %s,}}
if {[N I 1108 x {}]} {emit {number of blocks: %d,}}
if {[N S 2048 == 0x504d]} {if {[S 2096 x {}]} {emit {third type: %s,}}
if {[S 2064 x {}]} {emit {name: %s,}}
if {[N I 2132 x {}]} {emit {number of blocks: %d,}}
if {[N S 2560 == 0x504d]} {if {[S 2608 x {}]} {emit {fourth type: %s,}}
if {[S 2576 x {}]} {emit {name: %s,}}
if {[N I 2644 x {}]} {emit {number of blocks: %d}}
}
}
}
} 
if {[S 0 == BOMStore]} {emit {Mac OS X bill of materials \(BOM\) fil}}
if {[S 0 == {\#\ Magic}]} {emit {magic text file for file\(1\) cmd}}
if {[S 0 == Relay-Version:]} {emit {old news text}}
if {[S 0 == {\#!\ rnews}]} {emit {batched news text}}
if {[S 0 == {N\#!\ rnews}]} {emit {mailed, batched news text}}
if {[S 0 == {Forward\ to}]} {emit {mail forwarding text}}
if {[S 0 == {Pipe\ to}]} {emit {mail piping text}}
if {[S 0 == Return-Path:]} {emit {smtp mail text}}
if {[S 0 == Path:]} {emit {news text}}
if {[S 0 == Xref:]} {emit {news text}}
if {[S 0 == From:]} {emit {news or mail text}}
if {[S 0 == Article]} {emit {saved news text}}
if {[S 0 == BABYL]} {emit {Emacs RMAIL text}}
if {[S 0 == Received:]} {emit {RFC 822 mail text}}
if {[S 0 == MIME-Version:]} {emit {MIME entity text}}
if {[S 0 == *mbx*]} {emit {MBX mail folder}}
if {[S 0 == {\241\002\213\015skiplist\ file\0\0\0}]} {emit {Cyrus skiplist DB}}
if {[S 0 == {JAM\0}]} {emit {JAM message area header file}
if {[N s 12 > 0x0]} {emit {\(%d messages\)}}
}
if {[S 0 == {\000MVR4\nI}]} {emit {MapleVr4 library}}
if {[S 0 == {\000\004\000\000}]} {emit {Maple help database}}
if {[S 0 == <PACKAGE=]} {emit {Maple help file}}
if {[S 0 == {<HELP\ NAME=}]} {emit {Maple help file}}
if {[S 0 == {\n\<HELP\ NAME=}]} {emit {Maple help file with extra carriage return at start \(yuck\)}}
if {[S 0 == {\#\ daub}]} {emit {Maple help file, old style}}
if {[S 0 == {\000\000\001\044\000\221}]} {emit {Maple worksheet}}
if {[S 0 == {WriteNow\000\002\000\001\000\000\000\000\100\000\000\000\000\000}]} {emit {Maple worksheet, but weird}}
if {[S 0 == {\{VERSION\ }]} {emit {Maple worksheet}
if {[S 9 x {}]} {emit {version %.1s. {36 string {} x 11 {} %.1s}}}
}
if {[S 0 == {\0\0\001$}]} {emit {Maple something}
if {[S 4 == {\000\105}]} {emit {An old revision}}
if {[S 4 == {\001\122}]} {emit {The latest save}}
}
if {[S 0 == {\#\n\#\#\ <SHAREFILE=}]} {emit {Maple something}}
if {[S 0 == {\n\#\n\#\#\ <SHAREFILE=}]} {emit {Maple something}}
if {[S 0 == {\#\#\ <SHAREFILE=}]} {emit {Maple something}}
if {[S 0 == {\#\r\#\#\ <SHAREFILE=}]} {emit {Maple something}}
if {[S 0 == {\r\#\r\#\#\ <SHAREFILE=}]} {emit {Maple something}}
if {[S 0 == {\#\ \r\#\#\ <DESCRIBE>}]} {emit {Maple something anomalous.}}
if {[S 0 == {\064\024\012\000\035\000\000\000}]} {emit {Mathematica version 2 notebook}}
if {[S 0 == {\064\024\011\000\035\000\000\000}]} {emit {Mathematica version 2 notebook}}
if {[S 0 == {(*^\n\n::[\011frontEndVersion\ =\ }]} {emit {Mathematica notebook}}
if {[S 0 == {(*^\r\r::[\011}]} {emit {Mathematica notebook version 2.x}}
if {[S 0 == {\(\*\^\r\n\r\n\:\:\[\011}]} {emit {Mathematica notebook version 2.x}}
if {[S 0 == {(*^\015}]} {emit {Mathematica notebook version 2.x}}
if {[S 0 == {(*^\n\r\n\r::[\011}]} {emit {Mathematica notebook version 2.x}}
if {[S 0 == {(*^\r::[\011}]} {emit {Mathematica notebook version 2.x}}
if {[S 0 == {(*^\r\n::[\011}]} {emit {Mathematica notebook version 2.x}}
if {[S 0 == {(*^\n\n::[\011}]} {emit {Mathematica notebook version 2.x}}
if {[S 0 == {(*^\n::[\011}]} {emit {Mathematica notebook version 2.x}}
if {[S 0 == {(*This\ is\ a\ Mathematica\ binary\ }]} {emit {Mathematica binary file}
if {[S 88 x {}]} {emit {from %s}}
}
if {[S 0 == {MMAPBF\000\001\000\000\000\203\000\001\000}]} {emit {Mathematica PBF \(fonts I think\)}}
if {[S 4 == {\ A~}]} {emit {MAthematica .ml file}}
if {[S 0 == (***********************]} {emit {Mathematica 3.0 notebook}}
if {[S 0 == (*]} {emit {Mathematica, or Pascal,  Modula-2 or 3 code text}}
if {[S 0 == MATLAB]} {emit {Matlab v5 mat-file}
switch -- [Nv Y 126] 18765 {emit {\(big endian\)}
if {[N S 124 x {}]} {emit {version 0x%04x}}
} 19785 {emit {\(little endian\)}
if {[N s 124 x {}]} {emit {version 0x%04x}}
} 
}
if {[S 0 == {\0m\3}]} {emit {mcrypt 2.5 encrypted data,}
if {[Sx 2 4 x {}]} {emit {algorithm: %s,}
if {[Nx 3 s [R 1] > 0x0]} {emit {keysize: %d bytes,}
if {[S [R 0] x {}]} {emit {mode: %s,}}
}
}
}
if {[S 0 == {\0m\2}]} {emit {mcrypt 2.2 encrypted data,}
switch -- [Nv c 3] 0 {emit {algorithm: blowfish-448,}} 1 {emit {algorithm: DES,}} 2 {emit {algorithm: 3DES,}} 3 {emit {algorithm: 3-WAY,}} 4 {emit {algorithm: GOST,}} 6 {emit {algorithm: SAFER-SK64,}} 7 {emit {algorithm: SAFER-SK128,}} 8 {emit {algorithm: CAST-128,}} 9 {emit {algorithm: xTEA,}} 10 {emit {algorithm: TWOFISH-128,}} 11 {emit {algorithm: RC2,}} 12 {emit {algorithm: TWOFISH-192,}} 13 {emit {algorithm: TWOFISH-256,}} 14 {emit {algorithm: blowfish-128,}} 15 {emit {algorithm: blowfish-192,}} 16 {emit {algorithm: blowfish-256,}} 100 {emit {algorithm: RC6,}} 101 {emit {algorithm: IDEA,}} 
switch -- [Nv c 4] 0 {emit {mode: CBC,}} 1 {emit {mode: ECB,}} 2 {emit {mode: CFB,}} 3 {emit {mode: OFB,}} 4 {emit {mode: nOFB,}} 
switch -- [Nv c 5] 0 {emit {keymode: 8bit}} 1 {emit {keymode: 4bit}} 2 {emit {keymode: SHA-1 hash}} 3 {emit {keymode: MD5 hash}} 
}
if {[S 0 == {Content-Type:\ }]} {if {[S 14 x {}]} {emit %s}
}
if {[S 0 == Content-Type:]} {if {[S 13 x {}]} {emit %s}
}
if {[S 0 == kbd!map]} {emit {kbd map file}
if {[N c 8 > 0x0]} {emit {Ver %d:}}
if {[N Y 10 > 0x0]} {emit {with %d table\(s\)}}
}
if {[S 0 == {\x43\x72\x73\x68\x44\x75\x6d\x70}]} {emit {IRIX vmcore dump of}
if {[S 36 x {}]} {emit '%s'}
}
if {[S 0 == SGIAUDIT]} {emit {SGI Audit file}
if {[N c 8 x {}]} {emit {- version %d}}
if {[N c 9 x {}]} {emit .%ld}
}
if {[S 0 == WNGZWZSC]} {emit {Wingz compiled script}}
if {[S 0 == WNGZWZSS]} {emit {Wingz spreadsheet}}
if {[S 0 == WNGZWZHP]} {emit {Wingz help file}}
if {[S 0 == {\\#Inventor}]} {emit {V	IRIS Inventor 1.0 file}}
if {[S 0 == {\\#Inventor}]} {emit {V2	Open Inventor 2.0 file}}
if {[S 0 == {glfHeadMagic();}]} {emit GLF_TEXT}
if {[S 0 == glsBeginGLS(]} {emit GLS_TEXT}
if {[S 0 == %%!!]} {emit {X-Post-It-Note text}}
if {[S 0 == BEGIN:VCALENDAR]} {emit {vCalendar calendar file}}
if {[S 0 == {\311\304}]} {emit {ID tags data}
if {[N Y 2 > 0x0]} {emit {version %d}}
}
if {[S 0 == {\001\001\001\001}]} {emit {MMDF mailbox}}
if {[S 4 == Research,]} {emit Digifax-G3-File
switch -- [Nv c 29] 1 {emit {, fine resolution}} 0 {emit {, normal resolution}} 
}
if {[S 0 == RMD1]} {emit {raw modem data}
if {[S 4 x {}]} {emit {\(%s /}}
if {[N Y 20 > 0x0]} {emit {compression type 0x%04x\)}}
}
if {[S 0 == {PVF1\n}]} {emit {portable voice format}
if {[S 5 x {}]} {emit {\(binary %s\)}}
}
if {[S 0 == {PVF2\n}]} {emit {portable voice format}
if {[S 5 x {}]} {emit {\(ascii %s\)}}
}
if {[S 0 == S0]} {emit {Motorola S-Record; binary data in text format}}
switch -- [Nv I 0 &0xFFFFFFF0] 1612316672 {emit {Atari ST M68K contiguous executable}
if {[N I 2 x {}]} {emit {\(txt=%ld,}}
if {[N I 6 x {}]} {emit dat=%ld,}
if {[N I 10 x {}]} {emit bss=%ld,}
if {[N I 14 x {}]} {emit {sym=%ld\)}}
} 1612382208 {emit {Atari ST M68K non-contig executable}
if {[N I 2 x {}]} {emit {\(txt=%ld,}}
if {[N I 6 x {}]} {emit dat=%ld,}
if {[N I 10 x {}]} {emit bss=%ld,}
if {[N I 14 x {}]} {emit {sym=%ld\)}}
} 
if {[S 0 == {@echo\ off} c]} {emit {MS-DOS batch file text}}
if {[S 128 == {PE\0\0}]} {emit {MS Windows PE}
if {[N s 150 > 0x0 &0x0100]} {emit 32-bit}
switch -- [Nv s 132] 0 {emit {unknown processor}} 332 {emit {Intel 80386}} 358 {emit {MIPS R4000}} 388 {emit Alpha} 616 {emit {Motorola 68000}} 496 {emit PowerPC} 656 {emit PA-RISC} 
if {[N s 148 > 0x1b]} {switch -- [Nv s 220] 0 {emit {unknown subsystem}} 1 {emit native} 2 {emit GUI} 3 {emit console} 7 {emit POSIX} 
}
if {[N s 150 == 0x0 &0x2000]} {emit executable
if {[N s 150 > 0x0 &0x0001]} {emit {not relocatable}}
if {[N s 150 > 0x0 &0x1000]} {emit {system file}}
}
if {[N s 150 > 0x0 &0x2000]} {emit DLL
if {[N s 150 > 0x0 &0x0001]} {emit {not relocatable}}
if {[N s 150 > 0x0 &0x1000]} {emit {system file}}
}
}
if {[S 0 == MZ]} {emit {MS-DOS executable \(EXE\)}
if {[S 24 == @]} {emit {\b, OS/2 or MS Windows}
if {[S 231 == {LH/2\ Self-Extract}]} {emit {\b, %s}}
if {[S 233 == PKSFX2]} {emit {\b, %s}}
if {[S 122 == {Windows\ self-extracting\ ZIP}]} {emit {\b, %s}}
}
if {[S 28 == {RJSX\xff\xff}]} {emit {\b, ARJ SFX}}
if {[S 28 == {diet\xf9\x9c}]} {emit {\b, diet compressed}}
if {[S 28 == LZ09]} {emit {\b, LZEXE v0.90 compressed}}
if {[S 28 == LZ91]} {emit {\b, LZEXE v0.91 compressed}}
if {[S 30 == {Copyright\ 1989-1990\ PKWARE\ Inc.}]} {emit {\b, PKSFX}}
if {[S 30 == {PKLITE\ Copr.}]} {emit {\b, %.6s compressed}}
if {[S 36 == {LHa's\ SFX}]} {emit {\b, %.15s}}
if {[S 36 == {LHA's\ SFX}]} {emit {\b, %.15s}}
if {[S 1638 == -lh5-]} {emit {\b, LHa SFX archive v2.13S}}
if {[S 7195 == Rar!]} {emit {\b, RAR self-extracting archive}}
if {[S 11696 == {PK\003\004}]} {emit {\b, PKZIP SFX archive v1.1}}
if {[S 13297 == {PK\003\004}]} {emit {\b, PKZIP SFX archive v1.93a}}
if {[S 15588 == {PK\003\004}]} {emit {\b, PKZIP2 SFX archive v1.09}}
if {[S 15770 == {PK\003\004}]} {emit {\b, PKZIP SFX archive v2.04g}}
if {[S 28374 == {PK\003\004}]} {emit {\b, PKZIP2 SFX archive v1.02}}
if {[S 25115 == {PK\003\004}]} {emit {\b, Info-ZIP SFX archive v5.12}}
if {[S 26331 == {PK\003\004}]} {emit {\b, Info-ZIP SFX archive v5.12 w/decryption}}
if {[S 47031 == {PK\003\004}]} {emit {\b, Info-ZIP SFX archive v5.12}}
if {[S 49845 == {PK\003\004}]} {emit {\b, Info-ZIP SFX archive v5.12 w/decryption}}
if {[S 69120 == {PK\003\004}]} {emit {\b, Info-ZIP NT SFX archive v5.12 w/decryption}}
if {[S 49801 == {\x79\xff\x80\xff\x76\xff}]} {emit {\b, CODEC archive v3.21}
if {[N s 49824 == 0x1]} {emit {\b, 1 file}}
if {[N s 49824 > 0x1]} {emit {\b, %u files}}
}
}
if {[S 0 == LZ]} {emit {MS-DOS executable \(built-in\)}}
if {[S 0 == regf]} {emit {Windows NT registry file}}
if {[S 0 == CREG]} {emit {Windows 95 registry file}}
if {[S 0 == {\320\317\021\340\241\261\032\341AAFB\015\000OM\006\016\053\064\001\001\001\377}]} {emit {AAF legacy file using MS Structured Storage}
switch -- [Nv c 30] 9 {emit {\(512B sectors\)}} 12 {emit {\(4kB sectors\)}} 
}
if {[S 0 == {\320\317\021\340\241\261\032\341\001\002\001\015\000\002\000\000\006\016\053\064\003\002\001\001}]} {emit {AAF file using MS Structured Storage}
switch -- [Nv c 30] 9 {emit {\(512B sectors\)}} 12 {emit {\(4kB sectors\)}} 
}
if {[S 2080 == {Microsoft\ Word\ 6.0\ Document}]} {emit %s}
if {[S 2080 == {Documento\ Microsoft\ Word\ 6}]} {emit {Spanish Microsoft Word 6 document data}}
if {[S 2112 == MSWordDoc]} {emit {Microsoft Word document data}}
if {[S 0 == PO^Q`]} {emit {Microsoft Word 6.0 Document}}
if {[S 0 == {\376\067\0\043}]} {emit {Microsoft Office Document}}
if {[S 0 == {\320\317\021\340\241\261\032\341}]} {emit {Microsoft Office Document}}
if {[S 0 == {\333\245-\0\0\0}]} {emit {Microsoft Office Document}}
if {[S 2080 == {Microsoft\ Excel\ 5.0\ Worksheet}]} {emit %s}
if {[S 2080 == {Foglio\ di\ lavoro\ Microsoft\ Exce}]} {emit %s}
if {[S 2114 == Biff5]} {emit {Microsoft Excel 5.0 Worksheet}}
if {[S 2121 == Biff5]} {emit {Microsoft Excel 5.0 Worksheet}}
if {[S 0 == {\x09\x04\x06\x00\x00\x00\x10\x00}]} {emit {Microsoft Excel Worksheet}}
if {[S 0 == {?_\3\0}]} {emit {MS Windows Help Data}}
if {[S 0 == {\161\250\000\000\001\002}]} {emit {DeIsL1.isu whatever that is}}
if {[S 0 == {Nullsoft\ AVS\ Preset\ }]} {emit {Winamp plug in}}
if {[S 0 == {HyperTerminal\ }]} {emit hyperterm
if {[S 15 == {1.0\ --\ HyperTerminal\ data\ file}]} {emit {MS-windows Hyperterminal}}
}
if {[S 0 == {\327\315\306\232\000\000\000\000\000\000}]} {emit {ms-windows metafont .wmf}}
if {[S 0 == {\003\001\001\004\070\001\000\000}]} {emit {tz3 ms-works file}}
if {[S 0 == {\003\002\001\004\070\001\000\000}]} {emit {tz3 ms-works file}}
if {[S 0 == {\003\003\001\004\070\001\000\000}]} {emit {tz3 ms-works file}}
if {[S 0 == {\211\000\077\003\005\000\063\237\127\065\027\266\151\064\005\045\101\233\021\002}]} {emit {PGP sig}}
if {[S 0 == {\211\000\077\003\005\000\063\237\127\066\027\266\151\064\005\045\101\233\021\002}]} {emit {PGP sig}}
if {[S 0 == {\211\000\077\003\005\000\063\237\127\067\027\266\151\064\005\045\101\233\021\002}]} {emit {PGP sig}}
if {[S 0 == {\211\000\077\003\005\000\063\237\127\070\027\266\151\064\005\045\101\233\021\002}]} {emit {PGP sig}}
if {[S 0 == {\211\000\077\003\005\000\063\237\127\071\027\266\151\064\005\045\101\233\021\002}]} {emit {PGP sig}}
if {[S 0 == {\211\000\225\003\005\000\062\122\207\304\100\345\042}]} {emit {PGP sig}}
if {[S 0 == {MDIF\032\000\010\000\000\000\372\046\100\175\001\000\001\036\001\000}]} {emit {Ms-windows special zipped file}}
if {[S 0 == {\164\146\115\122\012\000\000\000\001\000\000\000}]} {emit {ms-windows help cache}}
if {[S 0 == {\120\115\103\103}]} {emit {Ms-windows 3.1 group files}}
if {[S 0 == {\114\000\000\000\001\024\002\000\000\000\000\000\300\000\000\000\000\000\000\106}]} {emit {ms-Windows shortcut}}
if {[S 0 == {\102\101\050\000\000\000\056\000\000\000\000\000\000\000}]} {emit {Icon for ms-windows}}
if {[S 0 == {\000\000\001\000}]} {emit {ms-windows icon resource}
if {[N c 4 == 0x1]} {emit {- 1 icon}}
if {[N c 4 > 0x1]} {emit {- %d icons}
if {[N c 6 > 0x0]} {emit {\b, %dx}
if {[N c 7 > 0x0]} {emit {\b%d}}
}
if {[N c 8 == 0x0]} {emit {\b, 256-colors}}
if {[N c 8 > 0x0]} {emit {\b, %d-colors}}
}
}
if {[S 0 == {PK\010\010BGI}]} {emit {Borland font}
if {[S 4 x {}]} {emit %s}
}
if {[S 0 == {pk\010\010BGI}]} {emit {Borland device}
if {[S 4 x {}]} {emit %s}
}
if {[S 9 == {\000\000\000\030\001\000\000\000}]} {emit {ms-windows recycled bin info}}
if {[S 9 == GERBILDOC]} {emit {First Choice document}}
if {[S 9 == GERBILDB]} {emit {First Choice database}}
if {[S 9 == GERBILCLIP]} {emit {First Choice database}}
if {[S 0 == GERBIL]} {emit {First Choice device file}}
if {[S 9 == RABBITGRAPH]} {emit {RabbitGraph file}}
if {[S 0 == DCU1]} {emit {Borland Delphi .DCU file}}
if {[S 0 == !<spell>]} {emit {MKS Spell hash list \(old format\)}}
if {[S 0 == !<spell2>]} {emit {MKS Spell hash list}}
if {[S 0 == PMCC]} {emit {Windows 3.x .GRP file}}
if {[S 1 == RDC-meg]} {emit MegaDots
if {[N c 8 > 0x2f]} {emit {version %c}}
if {[N c 9 > 0x2f]} {emit {\b.%c file}}
}
if {[S 0 == {ITSF\003\000\000\000\x60\000\000\000\001\000\000\000}]} {emit {MS Windows HtmlHelp Data}}
if {[S 2 == GFA-BASIC3]} {emit {GFA-BASIC 3 data}}
if {[S 512 == go32stub]} {emit {DOS-executable compiled w/DJGPP}
if {[S 524 > 0]} {emit {\(stub v%.4s\)}
if {[Sx 3 2226 == djp]} {emit {[compressed w/%s}
if {[S [R 1] x {}]} {emit %.4s\]}
}
if {[Sx 3 2221 == UPX]} {emit {[compressed w/%s}
if {[S [R 1] x {}]} {emit %.4s\]}
}
if {[S 28 == pmodedj]} {emit {stubbed with %s}}
}
}
if {[S 0 == {MSCF\0\0\0\0}]} {emit {Microsoft Cabinet file}
if {[N i 8 x {}]} {emit {\b, %u bytes}}
if {[N s 28 == 0x1]} {emit {\b, 1 file}}
if {[N s 28 > 0x1]} {emit {\b, %u files}}
}
if {[S 0 == ISc(]} {emit {InstallShield Cabinet file}
if {[N c 5 == 0x60 &0xf0]} {emit {version 6,}}
if {[N c 5 != 0x60 &0xf0]} {emit {version 4/5,}}
if {[N i [I 12 i 40] x {}]} {emit {%u files}}
}
if {[S 0 == {MSCE\0\0\0\0}]} {emit {Microsoft WinCE install header}
switch -- [Nv i 20] 0 {emit {\b, architecture-independent}} 103 {emit {\b, Hitachi SH3}} 104 {emit {\b, Hitachi SH4}} 2577 {emit {\b, StrongARM}} 4000 {emit {\b, MIPS R4000}} 10003 {emit {\b, Hitachi SH3}} 10004 {emit {\b, Hitachi SH3E}} 10005 {emit {\b, Hitachi SH4}} 70001 {emit {\b, ARM 7TDMI}} 
if {[N s 52 == 0x1]} {emit {\b, 1 file}}
if {[N s 52 > 0x1]} {emit {\b, %u files}}
if {[N s 56 == 0x1]} {emit {\b, 1 registry entry}}
if {[N s 56 > 0x1]} {emit {\b, %u registry entries}}
}
if {[S 0 == {Client\ UrlCache\ MMF}]} {emit {Microsoft Internet Explorer Cache File}
if {[S 20 x {}]} {emit {Version %s}}
}
if {[S 0 == {\xCF\xAD\x12\xFE}]} {emit {Microsoft Outlook Express DBX File}
switch -- [Nv c 4] -59 {emit {Message database}} -58 {emit {Folder database}} -57 {emit {Accounts informations}} 48 {emit {Offline database}} 
}
if {[N i 40 == 0x464d4520]} {emit {Windows Enhanced Metafile \(EMF\) image data}
if {[N i 44 x {}]} {emit {version 0x%x.}}
if {[N i 64 > 0x0]} {emit {Description available at offset 0x%x}
if {[N i 60 > 0x0]} {emit {\(length 0x%x\)}}
}
}
if {[S 0 == {HWB\000\377\001\000\000\000}]} {emit {Microsoft Visual C .APS file}}
if {[S 0 == {\102\157\162\154\141\156\144\040\103\053\053\040\120\162\157}]} {emit {MSVC .ide}}
if {[S 0 == {\000\000\000\000\040\000\000\000\377}]} {emit {MSVC .res}}
if {[S 0 == {\377\003\000\377\001\000\020\020\350}]} {emit {MSVC .res}}
if {[S 0 == {\377\003\000\377\001\000\060\020\350}]} {emit {MSVC .res}}
if {[S 0 == {\360\015\000\000}]} {emit {Microsoft Visual C library}}
if {[S 0 == {\360\075\000\000}]} {emit {Microsoft Visual C library}}
if {[S 0 == {\360\175\000\000}]} {emit {Microsoft Visual C library}}
if {[S 0 == {DTJPCH0\000\022\103\006\200}]} {emit {Microsoft Visual C .pch}}
if {[S 0 == {Microsoft\ C/C++\ }]} {emit {MSVC program database}
if {[S 18 == {program\ database\ }]} {emit 810 0}
if {[S 33 x {}]} {emit {ver %s}}
}
if {[S 0 == {\000\002\000\007\000}]} {emit {MSVC .sbr}
if {[S 5 x {}]} {emit %s}
}
if {[S 0 == {\002\000\002\001}]} {emit {MSVC .bsc}}
if {[S 0 == {1.00\ .0000.0000\000\003}]} {emit {MSVC .wsp version 1.0000.0000}}
if {[S 0 == RSRC]} {emit {National Instruments,}
if {[S 8 == LV]} {emit {LabVIEW File,}
if {[S 10 == SB]} {emit {Code Resource File, data}}
if {[S 10 == IN]} {emit {Virtual Instrument Program, data}}
if {[S 10 == AR]} {emit {VI Library, data}}
}
if {[S 8 == LMNULBVW]} {emit {Portable File Names, data}}
if {[S 8 == rsc]} {emit {Resources File, data}}
}
if {[S 0 == VMAP]} {emit {National Instruments, VXI File, data}}
switch -- [Nv I 0 &0377777777] 8782091 {emit {a.out NetBSD/i386 demand paged}
if {[N c 0 & 0x80]} {if {[N i 20 < 0x1000]} {emit {shared library}}
if {[N i 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N i 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 8782088 {emit {a.out NetBSD/i386 pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 8782087 {emit {a.out NetBSD/i386}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {if {[N c 0 & 0x40]} {emit {position independent}}
if {[N i 20 != 0x0]} {emit executable}
if {[N i 20 == 0x0]} {emit {object file}}
}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 8782151 {emit {a.out NetBSD/i386 core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N i 32 != 0x0]} {emit {\(signal %d\)}}
} 8847627 {emit {a.out NetBSD/m68k demand paged}
if {[N c 0 & 0x80]} {if {[N I 20 < 0x2000]} {emit {shared library}}
if {[N I 20 == 0x2000]} {emit {dynamically linked executable}}
if {[N I 20 > 0x2000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 8847624 {emit {a.out NetBSD/m68k pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 8847623 {emit {a.out NetBSD/m68k}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {if {[N c 0 & 0x40]} {emit {position independent}}
if {[N I 20 != 0x0]} {emit executable}
if {[N I 20 == 0x0]} {emit {object file}}
}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 8847687 {emit {a.out NetBSD/m68k core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N I 32 != 0x0]} {emit {\(signal %d\)}}
} 8913163 {emit {a.out NetBSD/m68k4k demand paged}
if {[N c 0 & 0x80]} {if {[N I 20 < 0x1000]} {emit {shared library}}
if {[N I 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N I 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 8913160 {emit {a.out NetBSD/m68k4k pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 8913159 {emit {a.out NetBSD/m68k4k}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {if {[N c 0 & 0x40]} {emit {position independent}}
if {[N I 20 != 0x0]} {emit executable}
if {[N I 20 == 0x0]} {emit {object file}}
}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 8913223 {emit {a.out NetBSD/m68k4k core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N I 32 != 0x0]} {emit {\(signal %d\)}}
} 8978699 {emit {a.out NetBSD/ns32532 demand paged}
if {[N c 0 & 0x80]} {if {[N i 20 < 0x1000]} {emit {shared library}}
if {[N i 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N i 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 8978696 {emit {a.out NetBSD/ns32532 pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 8978695 {emit {a.out NetBSD/ns32532}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {if {[N c 0 & 0x40]} {emit {position independent}}
if {[N i 20 != 0x0]} {emit executable}
if {[N i 20 == 0x0]} {emit {object file}}
}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 8978759 {emit {a.out NetBSD/ns32532 core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N i 32 != 0x0]} {emit {\(signal %d\)}}
} 9765191 {emit {a.out NetBSD/powerpc core}
if {[S 12 x {}]} {emit {from '%s'}}
} 9044235 {emit {a.out NetBSD/sparc demand paged}
if {[N c 0 & 0x80]} {if {[N I 20 < 0x2000]} {emit {shared library}}
if {[N I 20 == 0x2000]} {emit {dynamically linked executable}}
if {[N I 20 > 0x2000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 9044232 {emit {a.out NetBSD/sparc pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 9044231 {emit {a.out NetBSD/sparc}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {if {[N c 0 & 0x40]} {emit {position independent}}
if {[N I 20 != 0x0]} {emit executable}
if {[N I 20 == 0x0]} {emit {object file}}
}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 9044295 {emit {a.out NetBSD/sparc core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N I 32 != 0x0]} {emit {\(signal %d\)}}
} 9109771 {emit {a.out NetBSD/pmax demand paged}
if {[N c 0 & 0x80]} {if {[N i 20 < 0x1000]} {emit {shared library}}
if {[N i 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N i 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9109768 {emit {a.out NetBSD/pmax pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9109767 {emit {a.out NetBSD/pmax}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {if {[N c 0 & 0x40]} {emit {position independent}}
if {[N i 20 != 0x0]} {emit executable}
if {[N i 20 == 0x0]} {emit {object file}}
}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9109831 {emit {a.out NetBSD/pmax core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N i 32 != 0x0]} {emit {\(signal %d\)}}
} 9175307 {emit {a.out NetBSD/vax 1k demand paged}
if {[N c 0 & 0x80]} {if {[N i 20 < 0x1000]} {emit {shared library}}
if {[N i 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N i 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9175304 {emit {a.out NetBSD/vax 1k pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9175303 {emit {a.out NetBSD/vax 1k}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {if {[N c 0 & 0x40]} {emit {position independent}}
if {[N i 20 != 0x0]} {emit executable}
if {[N i 20 == 0x0]} {emit {object file}}
}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9175367 {emit {a.out NetBSD/vax 1k core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N i 32 != 0x0]} {emit {\(signal %d\)}}
} 9830667 {emit {a.out NetBSD/vax 4k demand paged}
if {[N c 0 & 0x80]} {if {[N i 20 < 0x1000]} {emit {shared library}}
if {[N i 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N i 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9830664 {emit {a.out NetBSD/vax 4k pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9830663 {emit {a.out NetBSD/vax 4k}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {if {[N c 0 & 0x40]} {emit {position independent}}
if {[N i 20 != 0x0]} {emit executable}
if {[N i 20 == 0x0]} {emit {object file}}
}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9830727 {emit {a.out NetBSD/vax 4k core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N i 32 != 0x0]} {emit {\(signal %d\)}}
} 9240903 {emit {a.out NetBSD/alpha core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N i 32 != 0x0]} {emit {\(signal %d\)}}
} 9306379 {emit {a.out NetBSD/mips demand paged}
if {[N c 0 & 0x80]} {if {[N I 20 < 0x2000]} {emit {shared library}}
if {[N I 20 == 0x2000]} {emit {dynamically linked executable}}
if {[N I 20 > 0x2000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 9306376 {emit {a.out NetBSD/mips pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 9306375 {emit {a.out NetBSD/mips}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {if {[N c 0 & 0x40]} {emit {position independent}}
if {[N I 20 != 0x0]} {emit executable}
if {[N I 20 == 0x0]} {emit {object file}}
}
if {[N I 16 > 0x0]} {emit {not stripped}}
} 9306439 {emit {a.out NetBSD/mips core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N I 32 != 0x0]} {emit {\(signal %d\)}}
} 9371915 {emit {a.out NetBSD/arm32 demand paged}
if {[N c 0 & 0x80]} {if {[N i 20 < 0x1000]} {emit {shared library}}
if {[N i 20 == 0x1000]} {emit {dynamically linked executable}}
if {[N i 20 > 0x1000]} {emit {dynamically linked executable}}
}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9371912 {emit {a.out NetBSD/arm32 pure}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {emit executable}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9371911 {emit {a.out NetBSD/arm32}
if {[N c 0 & 0x80]} {emit {dynamically linked executable}}
if {[N c 0 ^ 0x80]} {if {[N c 0 & 0x40]} {emit {position independent}}
if {[N i 20 != 0x0]} {emit executable}
if {[N i 20 == 0x0]} {emit {object file}}
}
if {[N i 16 > 0x0]} {emit {not stripped}}
} 9371975 {emit {a.out NetBSD/arm core}
if {[S 12 x {}]} {emit {from '%s'}}
if {[N i 32 != 0x0]} {emit {\(signal %d\)}}
} 
if {[S 0 == {\000\017\102\104\000\000\000\000\000\000\001\000\000\000\000\002\000\000\000\002\000\000\004\000}]} {emit {Netscape Address book}}
if {[S 0 == {\000\017\102\111}]} {emit {Netscape Communicator address book}}
if {[S 0 == {\#\ Netscape\ folder\ cache}]} {emit {Netscape folder cache}}
if {[S 0 == {\000\036\204\220\000}]} {emit {Netscape folder cache}}
if {[S 0 == SX961999]} {emit Net2phone}
if {[S 0 == {JG\004\016\0\0\0\0}]} {emit ART}
if {[S 0 == StartFontMetrics]} {emit {ASCII font metrics}}
if {[S 0 == StartFont]} {emit {ASCII font bits}}
switch -- [Nv I 8] 326773573 {emit {X11/NeWS bitmap font}} 326773576 {emit {X11/NeWS font family}} 
if {[S 0 == NPFF]} {emit {NItpicker Flow File}
if {[N c 4 x {}]} {emit V%d.}
if {[N c 5 x {}]} {emit %d}
if {[N S 6 x {}]} {emit {started: %s}}
if {[N S 10 x {}]} {emit {stopped: %s}}
if {[N I 14 x {}]} {emit {Bytes: %u}}
if {[N I 18 x {}]} {emit {Bytes1: %u}}
if {[N I 22 x {}]} {emit {Flows: %u}}
if {[N I 26 x {}]} {emit {Pkts: %u}}
}
if {[S 0 == Caml1999]} {emit {Objective caml}
if {[S 8 == X]} {emit {exec file}}
if {[S 8 == I]} {emit {interface file \(.cmi\)}}
if {[S 8 == O]} {emit {object file \(.cmo\)}}
if {[S 8 == A]} {emit {library file \(.cma\)}}
if {[S 8 == Y]} {emit {native object file \(.cmx\)}}
if {[S 8 == Z]} {emit {native library file \(.cmxa\)}}
if {[S 8 == M]} {emit {abstract syntax tree implementation file}}
if {[S 8 == N]} {emit {abstract syntax tree interface file}}
if {[S 9 x {}]} {emit {\(Version %3.3s\).}}
}
if {[S 0 == Octave-1-L]} {emit {Octave binary data \(little endian\)}}
if {[S 0 == Octave-1-B]} {emit {Octave binary data \(big endian\)}}
if {[S 0 == {\177OLF}]} {emit OLF
switch -- [Nv c 4] 0 {emit {invalid class}} 1 {emit 32-bit} 2 {emit 64-bit} 
switch -- [Nv c 7] 0 {emit {invalid os}} 1 {emit OpenBSD} 2 {emit NetBSD} 3 {emit FreeBSD} 4 {emit 4.4BSD} 5 {emit Linux} 6 {emit SVR4} 7 {emit esix} 8 {emit Solaris} 9 {emit Irix} 10 {emit SCO} 11 {emit Dell} 12 {emit NCR} 
switch -- [Nv c 5] 0 {emit {invalid byte order}} 1 {emit LSB
switch -- [Nv s 16] 0 {emit {no file type,}} 1 {emit relocatable,} 2 {emit executable,} 3 {emit {shared object,}} 4 {emit {core file}
if {[S [I 56 Q 204] x {}]} {emit {of '%s'}}
if {[N i [I 56 Q 16] > 0x0]} {emit {\(signal %d\),}}
} 
if {[N s 16 & 0xff00]} {emit processor-specific,}
switch -- [Nv s 18] 0 {emit {no machine,}} 1 {emit {AT&T WE32100 - invalid byte order,}} 2 {emit {SPARC - invalid byte order,}} 3 {emit {Intel 80386,}} 4 {emit {Motorola 68000 - invalid byte order,}} 5 {emit {Motorola 88000 - invalid byte order,}} 6 {emit {Intel 80486,}} 7 {emit {Intel 80860,}} 8 {emit {MIPS R3000_BE - invalid byte order,}} 9 {emit {Amdahl - invalid byte order,}} 10 {emit {MIPS R3000_LE,}} 11 {emit {RS6000 - invalid byte order,}} 15 {emit {PA-RISC - invalid byte order,}} 16 {emit nCUBE,} 17 {emit VPP500,} 18 {emit SPARC32PLUS,} 20 {emit PowerPC,} -28634 {emit Alpha,} 
switch -- [Nv i 20] 0 {emit {invalid version}} 1 {emit {version 1}} 
if {[N i 36 == 0x1]} {emit {MathCoPro/FPU/MAU Required}}
} 2 {emit MSB
switch -- [Nv S 16] 0 {emit {no file type,}} 1 {emit relocatable,} 2 {emit executable,} 3 {emit {shared object,}} 4 {emit {core file,}
if {[S [I 56 Q 204] x {}]} {emit {of '%s'}}
if {[N I [I 56 Q 16] > 0x0]} {emit {\(signal %d\),}}
} 
if {[N S 16 & 0xff00]} {emit processor-specific,}
switch -- [Nv S 18] 0 {emit {no machine,}} 1 {emit {AT&T WE32100,}} 2 {emit SPARC,} 3 {emit {Intel 80386 - invalid byte order,}} 4 {emit {Motorola 68000,}} 5 {emit {Motorola 88000,}} 6 {emit {Intel 80486 - invalid byte order,}} 7 {emit {Intel 80860,}} 8 {emit {MIPS R3000_BE,}} 9 {emit Amdahl,} 10 {emit {MIPS R3000_LE - invalid byte order,}} 11 {emit RS6000,} 15 {emit PA-RISC,} 16 {emit nCUBE,} 17 {emit VPP500,} 18 {emit SPARC32PLUS,} 20 {emit {PowerPC or cisco 4500,}} 21 {emit {cisco 7500,}} 24 {emit {cisco SVIP,}} 25 {emit {cisco 7200,}} 36 {emit {cisco 12000,}} -28634 {emit Alpha,} 
switch -- [Nv I 20] 0 {emit {invalid version}} 1 {emit {version 1}} 
if {[N I 36 == 0x1]} {emit {MathCoPro/FPU/MAU Required}}
} 
if {[S 8 x {}]} {emit {\(%s\)}}
}
if {[S 1 == InternetShortcut]} {emit {MS Windows 95 Internet shortcut text}
if {[S 24 > {\	}]} {emit {\(URL=<%s>\)}}
}
if {[S 0 == {HSP\x01\x9b\x00}]} {emit {OS/2 INF}
if {[S 107 > 0]} {emit {\(%s\)}}
}
if {[S 0 == {HSP\x10\x9b\x00}]} {emit {OS/2 HLP}
if {[S 107 > 0]} {emit {\(%s\)}}
}
if {[S 0 == {\xff\xff\xff\xff\x14\0\0\0}]} {emit {OS/2 INI}}
switch -- [Nv I 60] 1634758764 {emit {PalmOS application}
if {[S 0 x {}]} {emit {\"%s\"}}
} 1413830772 {emit {AportisDoc file}
if {[S 0 x {}]} {emit {\"%s\"}}
} 1212236619 {emit {HackMaster hack}
if {[S 0 x {}]} {emit {\"%s\"}}
} 
if {[S 60 == BVokBDIC]} {emit {BDicty PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == DB99DBOS]} {emit {DB PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == vIMGView]} {emit {FireViewer/ImageViewer PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == PmDBPmDB]} {emit {HanDBase PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == InfoINDB]} {emit {InfoView PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == ToGoToGo]} {emit {iSilo PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == JfDbJBas]} {emit {JFile PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == JfDbJFil]} {emit {JFile Pro PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == DATALSdb]} {emit {List PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == Mdb1Mdb1]} {emit {MobileDB PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == PNRdPPrs]} {emit {PeanutPress PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == DataPlkr]} {emit {Plucker PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == DataSprd]} {emit {QuickSheet PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == SM01SMem]} {emit {SuperMemo PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == DataTlPt]} {emit {TealDoc PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == InfoTlIf]} {emit {TealInfo PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == DataTlMl]} {emit {TealMeal PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == DataTlPt]} {emit {TealPaint PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == dataTDBP]} {emit {ThinkDB PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == TdatTide]} {emit {Tides PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == ToRaTRPW]} {emit {TomeRaider PalmOS document}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == zTXT]} {emit {A GutenPalm zTXT e-book}
if {[S 0 x {}]} {emit {\"%s\"}}
switch -- [Nv c [I 78 I 0]] 0 {emit {}
if {[N c [I 78 I 1] x {}]} {emit {\(v0.%02d\)}}
} 1 {emit {}
if {[N c [I 78 I 1] x {}]} {emit {\(v1.%02d\)}
if {[N S [I 78 I 10] > 0x0]} {if {[N S [I 78 I 10] < 0x2]} {emit {- 1 bookmark}}
if {[N S [I 78 I 10] > 0x1]} {emit {- %d bookmarks}}
}
if {[N S [I 78 I 14] > 0x0]} {if {[N S [I 78 I 14] < 0x2]} {emit {- 1 annotation}}
if {[N S [I 78 I 14] > 0x1]} {emit {- %d annotations}}
}
}
} 
if {[N c [I 78 I 0] > 0x1]} {emit {\(v%d.}
if {[N c [I 78 I 1] x {}]} {emit {%02d\)}}
}
}
if {[S 60 == libr]} {emit {Palm OS dynamic library data}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == ptch]} {emit {Palm OS operating system patch data}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[S 60 == BOOKMOBI]} {emit {Mobipocket E-book}
if {[S 0 x {}]} {emit {\"%s\"}}
}
if {[N S 0 == 0xace &0xfff]} {emit PARIX
switch -- [Nv c 0 &0xf0] -128 {emit T800} -112 {emit T9000} 
switch -- [Nv c 19 &0x02] 2 {emit executable} 0 {emit object} 
if {[N c 19 == 0x0 &0x0c]} {emit {not stripped}}
}
if {[S 0 == %PDF-]} {emit {PDF document}
if {[N c 5 x {}]} {emit {\b, version %c}}
if {[N c 7 x {}]} {emit {\b.%c}}
}
if {[S 0 == {\#!\ /bin/perl} b]} {emit {perl script text executable}}
if {[S 0 == {eval\ \"exec\ /bin/perl}]} {emit {perl script text}}
if {[S 0 == {\#!\ /usr/bin/perl} b]} {emit {perl script text executable}}
if {[S 0 == {eval\ \"exec\ /usr/bin/perl}]} {emit {perl script text}}
if {[S 0 == {\#!\ /usr/local/bin/perl} b]} {emit {perl script text}}
if {[S 0 == {eval\ \"exec\ /usr/local/bin/perl}]} {emit {perl script text executable}}
if {[S 0 == {eval\ '(exit\ $?0)'\ &&\ eval\ 'exec}]} {emit {perl script text}}
if {[S 0 == package]} {emit {Perl5 module source text}}
if {[S 0 == perl-store]} {emit {perl Storable\(v0.6\) data}
if {[N c 4 > 0x0]} {emit {\(net-order %d\)}
if {[N c 4 & 0x1]} {emit {\(network-ordered\)}}
switch -- [Nv c 4] 3 {emit {\(major 1\)}} 2 {emit {\(major 1\)}} 
}
}
if {[S 0 == pst0]} {emit {perl Storable\(v0.7\) data}
if {[N c 4 > 0x0]} {if {[N c 4 & 0x1]} {emit {\(network-ordered\)}}
switch -- [Nv c 4] 5 {emit {\(major 2\)}} 4 {emit {\(major 2\)}} 
if {[N c 5 > 0x0]} {emit {\(minor %d\)}}
}
}
if {[S 0 == {-----BEGIN\040PGP}]} {emit {PGP armored data}
if {[S 15 == {PUBLIC\040KEY\040BLOCK-}]} {emit {public key block}}
if {[S 15 == MESSAGE-]} {emit message}
if {[S 15 == {SIGNED\040MESSAGE-}]} {emit {signed message}}
if {[S 15 == {PGP\040SIGNATURE-}]} {emit signature}
}
if {[S 0 == {\#\ PaCkAgE\ DaTaStReAm}]} {emit {pkg Datastream \(SVR4\)}}
if {[S 0 == %!]} {emit {PostScript document text}
if {[S 2 == PS-Adobe-]} {emit conforming
if {[S 11 x {}]} {emit {at level %.3s}
if {[S 15 == EPS]} {emit {- type %s}}
if {[S 15 == Query]} {emit {- type %s}}
if {[S 15 == ExitServer]} {emit {- type %s}}
}
}
}
if {[S 0 == {\004%!}]} {emit {PostScript document text}
if {[S 3 == PS-Adobe-]} {emit conforming
if {[S 12 x {}]} {emit {at level %.3s}
if {[S 16 == EPS]} {emit {- type %s}}
if {[S 16 == Query]} {emit {- type %s}}
if {[S 16 == ExitServer]} {emit {- type %s}}
}
}
}
if {[S 0 == {\033%-12345X%!PS}]} {emit {PostScript document}}
if {[S 0 == *PPD-Adobe:]} {emit {PPD file}
if {[S 13 x {}]} {emit {\b, ve}}
}
if {[S 0 == {\033%-12345X@PJL}]} {emit {HP Printer Job Language data}}
if {[Sx 1 0 == {\033%-12345X@PJL}]} {emit {HP Printer Job Language data}
if {[Sx 2 [R 0] x {}]} {emit {%s			}
if {[Sx 3 [R 0] x {}]} {emit {%s			}
if {[Sx 4 [R 0] x {}]} {emit {%s		}
if {[S [R 0] x {}]} {emit {%s		}}
}
}
}
}
if {[S 0 == {\033E\033}]} {emit {HP PCL printer data}
if {[S 3 == {\&l0A}]} {emit {- default page size}}
if {[S 3 == {\&l1A}]} {emit {- US executive page size}}
if {[S 3 == {\&l2A}]} {emit {- US letter page size}}
if {[S 3 == {\&l3A}]} {emit {- US legal page size}}
if {[S 3 == {\&l26A}]} {emit {- A4 page size}}
if {[S 3 == {\&l80A}]} {emit {- Monarch envelope size}}
if {[S 3 == {\&l81A}]} {emit {- No. 10 envelope size}}
if {[S 3 == {\&l90A}]} {emit {- Intl. DL envelope size}}
if {[S 3 == {\&l91A}]} {emit {- Intl. C5 envelope size}}
if {[S 3 == {\&l100A}]} {emit {- Intl. B5 envelope size}}
if {[S 3 == {\&l-81A}]} {emit {- No. 10 envelope size \(landscape\)}}
if {[S 3 == {\&l-90A}]} {emit {- Intl. DL envelope size \(landscape\)}}
}
if {[S 0 == @document(]} {emit {Imagen printer}
if {[S 10 == {language\ impress}]} {emit {\(imPRESS data\)}}
if {[S 10 == {language\ daisy}]} {emit {\(daisywheel text\)}}
if {[S 10 == {language\ diablo}]} {emit {\(daisywheel text\)}}
if {[S 10 == {language\ printer}]} {emit {\(line printer emulation\)}}
if {[S 10 == {language\ tektronix}]} {emit {\(Tektronix 4014 emulation\)}}
}
if {[S 0 == Rast]} {emit {RST-format raster font data}
if {[S 45 > 0]} {emit {face %s}}
}
if {[S 0 == {\033[K\002\0\0\017\033(a\001\0\001\033(g}]} {emit {Canon Bubble Jet BJC formatted data}}
if {[S 0 == {\x1B\x40\x1B\x28\x52\x08\x00\x00REMOTE1P}]} {emit {Epson Stylus Color 460 data}}
if {[S 0 == JZJZ]} {if {[S 18 == ZZ]} {emit {Zenographics ZjStream printer data \(big-endian\)}}
}
if {[S 0 == ZJZJ]} {if {[S 18 == ZZ]} {emit {Zenographics ZjStream printer data \(little-endian\)}}
}
if {[S 0 == OAK]} {if {[N c 7 == 0x0]} {emit 888 0}
if {[N c 11 == 0x0]} {emit {Oak Technologies printer stream}}
}
if {[S 0 == %!VMF]} {emit {SunClock's Vector Map Format data}}
if {[S 0 == {\xbe\xefABCDEFGH}]} {emit {HP LaserJet 1000 series downloadable firmware}}
if {[S 0 == {\x1b\x01@EJL}]} {emit {Epson ESC/Page language printer data}}
if {[S 0 == {FTNCHEK_\ P}]} {emit {project file for ftnchek}
if {[S 10 == 1]} {emit {version 2.7}}
if {[S 10 == 2]} {emit {version 2.8 to 2.10}}
if {[S 10 == 3]} {emit {version 2.11 or later}}
}
if {[N I 0 == 0x56000000 &0xff00ffff]} {emit {ps database}
if {[S 1 x {}]} {emit {version %s}}
if {[S 4 x {}]} {emit {from kernel %s}}
}
if {[S 0 == {\"\"\"}]} {emit {a python script text executable}}
if {[S 0 == {/1\ :pserver:}]} {emit {cvs password text file}}
if {[S 0 == RIFF]} {emit {RIFF \(little-endian\) data}
if {[S 8 == PAL]} {emit {\b, palette}
if {[N s 16 x {}]} {emit {\b, version %d}}
if {[N s 18 x {}]} {emit {\b, %d entries}}
}
if {[S 8 == RDIB]} {emit {\b, device-independent bitmap}
if {[S 16 == BM]} {switch -- [Nv s 30] 12 {emit {\b, OS/2 1.x format}
if {[N s 34 x {}]} {emit {\b, %d x}}
if {[N s 36 x {}]} {emit %d}
} 64 {emit {\b, OS/2 2.x format}
if {[N s 34 x {}]} {emit {\b, %d x}}
if {[N s 36 x {}]} {emit %d}
} 40 {emit {\b, Windows 3.x format}
if {[N i 34 x {}]} {emit {\b, %d x}}
if {[N i 38 x {}]} {emit {%d x}}
if {[N s 44 x {}]} {emit %d}
} 
}
}
if {[S 8 == RMID]} {emit {\b, MIDI}}
if {[S 8 == RMMP]} {emit {\b, multimedia movie}}
if {[S 8 == WAVE]} {emit {\b, WAVE audio}
switch -- [Nv s 20] 1 {emit {\b, Microsoft PCM}
if {[N s 34 > 0x0]} {emit {\b, %d bit}}
} 2 {emit {\b, Microsoft ADPCM}} 6 {emit {\b, ITU G.711 A-law}} 7 {emit {\b, ITU G.711 mu-law}} 17 {emit {\b, IMA ADPCM}} 20 {emit {\b, ITU G.723 ADPCM \(Yamaha\)}} 49 {emit {\b, GSM 6.10}} 64 {emit {\b, ITU G.721 ADPCM}} 80 {emit {\b, MPEG}} 85 {emit {\b, MPEG Layer 3}} 
switch -- [Nv s 22] 1 {emit {\b, mono}} 2 {emit {\b, stereo}} 
if {[N s 22 > 0x2]} {emit {\b, %d channels}}
if {[N i 24 > 0x0]} {emit {%d Hz}}
}
if {[S 8 == CDRA]} {emit {\b, Corel Draw Picture}}
if {[S 8 == {AVI\040}]} {emit {\b, AVI}
if {[S 12 == LIST]} {if {[Sx 4 20 == hdrlavih]} {if {[N i [R 36] x {}]} {emit {\b, %lu x}}
if {[N i [R 40] x {}]} {emit %lu,}
if {[N i [R 4] > 0xf4240]} {emit {<1 fps,}}
switch -- [Nvx 5 i [R 4]] 1000000 {emit {1.00 fps,}} 500000 {emit {2.00 fps,}} 333333 {emit {3.00 fps,}} 250000 {emit {4.00 fps,}} 200000 {emit {5.00 fps,}} 166667 {emit {6.00 fps,}} 142857 {emit {7.00 fps,}} 125000 {emit {8.00 fps,}} 111111 {emit {9.00 fps,}} 100000 {emit {10.00 fps,}} 83333 {emit {12.00 fps,}} 66667 {emit {15.00 fps,}} 50000 {emit {20.00 fps,}} 41708 {emit {23.98 fps,}} 41667 {emit {24.00 fps,}} 40000 {emit {25.00 fps,}} 33367 {emit {29.97 fps,}} 33333 {emit {30.00 fps,}} 
L 4;if {[Nx 5 i [R 4] < 0x18a92]} {if {[Nx 6 i [R -4] > 0x182c2]} {if {[N i [R -4] != 0x186a0]} {emit {~10 fps,}}
}
}
L 4;if {[Nx 5 i [R 4] < 0x14842]} {if {[Nx 6 i [R -4] > 0x142d5]} {if {[N i [R -4] != 0x14585]} {emit {~12 fps,}}
}
}
L 4;if {[Nx 5 i [R 4] < 0x1062a]} {if {[Nx 6 i [R -4] > 0x102b1]} {if {[N i [R -4] != 0x1046b]} {emit {~15 fps,}}
}
}
L 4;if {[Nx 5 i [R 4] < 0xa371]} {if {[Nx 6 i [R -4] > 0xa216]} {if {[Nx 7 i [R -4] != 0xa2ec]} {if {[N i [R -4] != 0xa2c3]} {emit {~24 fps,}}
}
}
}
L 4;if {[Nx 5 i [R 4] < 0x9ce1]} {if {[Nx 6 i [R -4] > 0x9ba1]} {if {[N i [R -4] != 0x9c40]} {emit {~25 fps,}}
}
}
L 4;if {[Nx 5 i [R 4] < 0x82a5]} {if {[Nx 6 i [R -4] > 0x81c7]} {if {[Nx 7 i [R -4] != 0x8257]} {if {[N i [R -4] != 0x8235]} {emit {~30 fps,}}
}
}
}
L 4;if {[N i [R 4] < 0x7de0]} {emit {>30 fps,}}
}
if {[S 88 == LIST]} {if {[S 96 == strlstrh]} {if {[Sx 6 108 == vids]} {emit video:
if {[N i [R 0] == 0x0]} {emit uncompressed}
if {[S [I 104 i 108] == strf]} {switch -- [Nv i [I 104 i 132]] 1 {emit {RLE 8bpp}} 0 {emit {}} 
if {[S [I 104 i 132] == cvid c]} {emit Cinepak}
if {[S [I 104 i 132] == i263 c]} {emit {Intel I.263}}
if {[S [I 104 i 132] == iv32 c]} {emit {Indeo 3.2}}
if {[S [I 104 i 132] == iv41 c]} {emit {Indeo 4.1}}
if {[S [I 104 i 132] == iv50 c]} {emit {Indeo 5.0}}
if {[S [I 104 i 132] == mp42 c]} {emit {Microsoft MPEG-4 v2}}
if {[S [I 104 i 132] == mp43 c]} {emit {Microsoft MPEG-4 v3}}
if {[S [I 104 i 132] == mjpg c]} {emit {Motion JPEG}}
if {[S [I 104 i 132] == div3 c]} {emit {DivX 3}
if {[S 112 == div3 c]} {emit Low-Motion}
if {[S 112 == div4 c]} {emit Fast-Motion}
}
if {[S [I 104 i 132] == divx c]} {emit {DivX 4}}
if {[S [I 104 i 132] == dx50 c]} {emit {DivX 5}}
if {[S [I 104 i 132] == xvid c]} {emit XviD}
}
}
}
if {[S [I 92 i 96] == LIST]} {if {[S [I 92 i 104] == strlstrh]} {if {[S [I 92 i 116] == auds]} {emit {\b, audio:}
if {[S [I 92 i 172] == strf]} {switch -- [Nv s [I 92 i 180]] 1 {emit {uncompressed PCM}} 2 {emit ADPCM} 85 {emit {MPEG-1 Layer 3}} 8192 {emit {Dolby AC3}} 353 {emit DivX} 
switch -- [Nv s [I 92 i 182]] 1 {emit {\(mono,}} 2 {emit {\(stereo,}} 
if {[N s [I 92 i 182] > 0x2]} {emit {\(%d channels,}}
if {[N i [I 92 i 184] x {}]} {emit {%d Hz\)}}
}
if {[S [I 92 i 180] == strf]} {switch -- [Nv s [I 92 i 188]] 1 {emit {uncompressed PCM}} 2 {emit ADPCM} 85 {emit {MPEG-1 Layer 3}} 8192 {emit {Dolby AC3}} 353 {emit DivX} 
switch -- [Nv s [I 92 i 190]] 1 {emit {\(mono,}} 2 {emit {\(stereo,}} 
if {[N s [I 92 i 190] > 0x2]} {emit {\(%d channels,}}
if {[N i [I 92 i 192] x {}]} {emit {%d Hz\)}}
}
}
}
}
}
}
}
if {[S 8 == ACON]} {emit {\b, animated cursor}}
if {[S 8 == sfbk]} {emit SoundFont/Bank}
if {[S 8 == CDXA]} {emit {\b, wrapped MPEG-1 \(CDXA\)}}
if {[S 8 == 4XMV]} {emit {\b, 4X Movie file}}
}
if {[S 0 == RIFX]} {emit {RIFF \(big-endian\) data}
if {[S 8 == PAL]} {emit {\b, palette}
if {[N S 16 x {}]} {emit {\b, version %d}}
if {[N S 18 x {}]} {emit {\b, %d entries}}
}
if {[S 8 == RDIB]} {emit {\b, device-independent bitmap}
if {[S 16 == BM]} {switch -- [Nv S 30] 12 {emit {\b, OS/2 1.x format}
if {[N S 34 x {}]} {emit {\b, %d x}}
if {[N S 36 x {}]} {emit %d}
} 64 {emit {\b, OS/2 2.x format}
if {[N S 34 x {}]} {emit {\b, %d x}}
if {[N S 36 x {}]} {emit %d}
} 40 {emit {\b, Windows 3.x format}
if {[N I 34 x {}]} {emit {\b, %d x}}
if {[N I 38 x {}]} {emit {%d x}}
if {[N S 44 x {}]} {emit %d}
} 
}
}
if {[S 8 == RMID]} {emit {\b, MIDI}}
if {[S 8 == RMMP]} {emit {\b, multimedia movie}}
if {[S 8 == WAVE]} {emit {\b, WAVE audio}
if {[N s 20 == 0x1]} {emit {\b, Microsoft PCM}
if {[N s 34 > 0x0]} {emit {\b, %d bit}}
}
switch -- [Nv S 22] 1 {emit {\b, mono}} 2 {emit {\b, stereo}} 
if {[N S 22 > 0x2]} {emit {\b, %d channels}}
if {[N I 24 > 0x0]} {emit {%d Hz}}
}
if {[S 8 == CDRA]} {emit {\b, Corel Draw Picture}}
if {[S 8 == {AVI\040}]} {emit {\b, AVI}}
if {[S 8 == ACON]} {emit {\b, animated cursor}}
if {[S 8 == NIFF]} {emit {\b, Notation Interchange File Format}}
if {[S 8 == sfbk]} {emit SoundFont/Bank}
}
if {[S 0 == {\{\\rtf}]} {emit {Rich Text Format data,}
if {[N c 5 x {}]} {emit {version %c,}}
if {[S 6 == {\\ansi}]} {emit ANSI}
if {[S 6 == {\\mac}]} {emit {Apple Macintosh}}
if {[S 6 == {\\pc}]} {emit {IBM PC, code page 437}}
if {[S 6 == {\\pca}]} {emit {IBM PS/2, code page 850}}
}
if {[S 38 == Spreadsheet]} {emit {sc spreadsheet file}}
if {[S 8 == {\001s\ }]} {emit {SCCS archive data}}
if {[S 0 == {divert(-1)\n}]} {emit {sendmail m4 text file}}
if {[S 0 == PmNs]} {emit {PCP compiled namespace \(V.0\)}}
if {[S 0 == PmN]} {emit {PCP compiled namespace}
if {[S 3 x {}]} {emit {\(V.%1.1s\)}}
}
if {[N i 3 == 0x84500526]} {emit {PCP archive}
if {[N c 7 x {}]} {emit {\(V.%d\)}}
switch -- [Nv i 20] -2 {emit {temporal index}} -1 {emit metadata} 0 {emit {log volume \#0}} 
if {[N i 20 > 0x0]} {emit {log volume \#%ld}}
if {[S 24 x {}]} {emit {host: %s}}
}
if {[S 0 == PCPFolio]} {emit PCP
if {[S 9 == Version:]} {emit {Archive Folio}}
if {[S 18 x {}]} {emit {\(V.%s\)}}
}
if {[S 0 == {\#pmchart}]} {emit {PCP pmchart view}
if {[S 9 == Version]} {emit 906 0}
if {[S 17 x {}]} {emit {\(V%-3.3s\)}}
}
if {[S 0 == pmview]} {emit {PCP pmview config}
if {[S 7 == Version]} {emit 907 0}
if {[S 15 x {}]} {emit {\(V%-3.3s\)}}
}
if {[S 0 == {\#pmlogger}]} {emit {PCP pmlogger config}
if {[S 10 == Version]} {emit 908 0}
if {[S 18 x {}]} {emit {\(V%1.1s\)}}
}
if {[S 0 == PcPh]} {emit {PCP Help}
if {[S 4 == 1]} {emit Index}
if {[S 4 == 2]} {emit Text}
if {[S 5 x {}]} {emit {\(V.%1.1s\)}}
}
if {[S 0 == {\#pmieconf-rules}]} {emit {PCP pmieconf rules}
if {[S 16 x {}]} {emit {\(V.%1.1s\)}}
}
if {[S 3 == pmieconf-pmie]} {emit {PCP pmie config}
if {[S 17 x {}]} {emit {\(V.%1.1s\)}}
}
if {[S 0 == mdbm]} {emit {mdbm file,}
if {[N c 5 x {}]} {emit {version %d,}}
if {[N c 6 x {}]} {emit {2^%d pages,}}
if {[N c 7 x {}]} {emit {pagesize 2^%d,}}
if {[N c 17 x {}]} {emit {hash %d,}}
if {[N c 11 x {}]} {emit {dataformat %d}}
}
if {[S 0 == //Maya]} {emit {ASCII	Alias|Wavefront Maya Ascii File,}
if {[S 13 x {}]} {emit {version %s}}
}
if {[S 8 == MAYAFOR4]} {emit {Alias|Wavefront Maya Binary File,}
if {[S 32 x {}]} {emit {version %s scene}}
}
if {[S 8 == MayaFOR4]} {emit {Alias|Wavefront Maya Binary File,}
if {[S 32 x {}]} {emit {version %s scene}}
}
if {[S 8 == CIMG]} {emit {Alias|Wavefront Maya Image File}}
if {[S 8 == DEEP]} {emit {Alias|Wavefront Maya Image File}}
if {[S 0 == {<!DOCTYPE\ html} cB]} {emit {HTML document text}}
if {[S 0 == <head cb]} {emit {HTML document text}}
if {[S 0 == <title cb]} {emit {HTML document text}}
if {[S 0 == <html cb]} {emit {HTML document text}}
if {[S 0 == <?xml cb]} {emit {XML document text}}
if {[S 0 == {<?xml\ version}]} {emit {\"	XML}}
if {[S 0 == {<?xml\ version=\"}]} {emit XML
if {[S 15 x {}]} {emit {%.3s document text}
if {[S 23 == <xsl:stylesheet]} {emit {\(XSL stylesheet\)}}
if {[S 24 == <xsl:stylesheet]} {emit {\(XSL stylesheet\)}}
}
}
if {[S 0 == <?xml b]} {emit {XML document text}}
if {[S 0 == <?xml cb]} {emit {broken XML document text}}
if {[S 0 == <!doctype cb]} {emit {exported SGML document text}}
if {[S 0 == <!subdoc cb]} {emit {exported SGML subdocument text}}
if {[S 0 == <!-- cb]} {emit {exported SGML document text}}
if {[S 0 == {\#\ HTTP\ Cookie\ File}]} {emit {Web browser cookie text}}
if {[S 0 == {\#\ Netscape\ HTTP\ Cookie\ File}]} {emit {Netscape cookie text}}
if {[S 0 == {\#\ KDE\ Cookie\ File}]} {emit {Konqueror cookie text}}
if {[S 0 == Draw]} {emit {RiscOS Drawfile}}
if {[S 0 == PACK]} {emit {RiscOS PackdDir archive}}
if {[S 0 == !]} {emit {Assembler source}}
if {[S 0 == Analog]} {emit {ADi asm listing file}}
if {[S 0 == .SYSTEM]} {emit {SHARC architecture file}}
if {[S 0 == .system]} {emit {SHARC architecture file}}
if {[S 0 == QL5]} {emit {QL disk dump data,}
if {[S 3 == A]} {emit {720 KB,}}
if {[S 3 == B]} {emit {1.44 MB,}}
if {[S 3 == C]} {emit {3.2 MB,}}
if {[S 4 x {}]} {emit label:%.10s}
}
if {[S 0 == {NqNqNq`\004}]} {emit {QL firmware executable \(BCPL\)}}
if {[S 0 == {\#\#Sketch}]} {emit {Sketch document text}}
if {[S 0 == {GSTIm\0\0}]} {emit {GNU SmallTalk}
switch -- [Nv c 7 &1] 0 {emit {LE image version}
if {[N c 10 x {}]} {emit %d.}
if {[N c 9 x {}]} {emit {\b%d.}}
if {[N c 8 x {}]} {emit {\b%d}}
} 1 {emit {BE image version}
if {[N c 8 x {}]} {emit %d.}
if {[N c 9 x {}]} {emit {\b%d.}}
if {[N c 10 x {}]} {emit {\b%d}}
} 
}
if {[S 0 == RTSS]} {emit {NetMon capture file}
if {[N c 5 x {}]} {emit {- version %d}}
if {[N c 4 x {}]} {emit {\b.%d}}
switch -- [Nv s 6] 0 {emit {\(Unknown\)}} 1 {emit {\(Ethernet\)}} 2 {emit {\(Token Ring\)}} 3 {emit {\(FDDI\)}} 4 {emit {\(ATM\)}} 
}
if {[S 0 == GMBU]} {emit {NetMon capture file}
if {[N c 5 x {}]} {emit {- version %d}}
if {[N c 4 x {}]} {emit {\b.%d}}
switch -- [Nv s 6] 0 {emit {\(Unknown\)}} 1 {emit {\(Ethernet\)}} 2 {emit {\(Token Ring\)}} 3 {emit {\(FDDI\)}} 4 {emit {\(ATM\)}} 
}
if {[S 0 == {TRSNIFF\ data\ \ \ \ \032}]} {emit {Sniffer capture file}
if {[N c 33 == 0x2]} {emit {\(compressed\)}}
if {[N s 23 x {}]} {emit {- version %d}}
if {[N s 25 x {}]} {emit {\b.%d}}
switch -- [Nv c 32] 0 {emit {\(Token Ring\)}} 1 {emit {\(Ethernet\)}} 2 {emit {\(ARCNET\)}} 3 {emit {\(StarLAN\)}} 4 {emit {\(PC Network broadband\)}} 5 {emit {\(LocalTalk\)}} 6 {emit {\(Znet\)}} 7 {emit {\(Internetwork Analyzer\)}} 9 {emit {\(FDDI\)}} 10 {emit {\(ATM\)}} 
}
if {[S 0 == {XCP\0}]} {emit {NetXRay capture file}
if {[S 4 x {}]} {emit {- version %s}}
switch -- [Nv s 44] 0 {emit {\(Ethernet\)}} 1 {emit {\(Token Ring\)}} 2 {emit {\(FDDI\)}} 3 {emit {\(WAN\)}} 8 {emit {\(ATM\)}} 9 {emit {\(802.11\)}} 
}
if {[S 0 == {iptrace\ 1.0}]} {emit {\"iptrace\" capture file}}
if {[S 0 == {iptrace\ 2.0}]} {emit {\"iptrace\" capture file}}
if {[S 0 == {\x54\x52\x00\x64\x00}]} {emit {\"nettl\" capture file}}
if {[S 0 == {\x42\xd2\x00\x34\x12\x66\x22\x88}]} {emit {RADCOM WAN/LAN Analyzer capture file}}
if {[S 0 == NetS]} {emit {NetStumbler log file}
if {[N i 8 x {}]} {emit {\b, %d stations found}}
}
if {[S 0 == {\177ver}]} {emit {EtherPeek/AiroPeek capture file}}
if {[S 0 == {\x05VNF}]} {emit {Visual Networks traffic capture file}}
if {[S 0 == ObserverPktBuffe]} {emit {Network Instruments Observer capture file}}
if {[S 0 == {\xaa\xaa\xaa\xaa}]} {emit {5View capture file}}
if {[S 0 == {<!SQ\ DTD>}]} {emit {Compiled SGML rules file}
if {[S 9 x {}]} {emit {Type %s}}
}
if {[S 0 == {<!SQ\ A/E>}]} {emit {A/E SGML Document binary}
if {[S 9 x {}]} {emit {Type %s}}
}
if {[S 0 == {<!SQ\ STS>}]} {emit {A/E SGML binary styles file}
if {[S 9 x {}]} {emit {Type %s}}
}
if {[S 0 == {SQ\ BITMAP1}]} {emit {SoftQuad Raster Format text}}
if {[S 0 == {X\ }]} {emit {SoftQuad troff Context intermediate}
if {[S 2 == 495]} {emit {for AT&T 495 laser printer}}
if {[S 2 == hp]} {emit {for Hewlett-Packard LaserJet}}
if {[S 2 == impr]} {emit {for IMAGEN imPRESS}}
if {[S 2 == ps]} {emit {for PostScript}}
}
if {[S 0 == spec]} {emit SPEC
if {[S 4 == .cpu]} {emit CPU
if {[S 8 < :]} {emit {\b%.4s}}
if {[S 12 == .]} {emit {raw result text}}
}
}
if {[S 17 == version=SPECjbb]} {emit SPECjbb
if {[S 32 < :]} {emit {\b%.4s}
if {[S 37 < :]} {emit {v%.4s raw result text}}
}
}
if {[S 0 == {BEGIN\040SPECWEB}]} {emit SPECweb
if {[S 13 < :]} {emit {\b%.2s}
if {[S 15 == _SSL]} {emit {\b_SSL}
if {[S 20 < :]} {emit {v%.4s raw result text}}
}
if {[S 16 < :]} {emit {v%.4s raw result text}}
}
}
if {[S 0 == {PLUS3DOS\032}]} {emit {Spectrum +3 data}
switch -- [Nv c 15] 0 {emit {- BASIC program}} 1 {emit {- number array}} 2 {emit {- character array}} 3 {emit {- memory block}
if {[N I 16 == 0x1b0040]} {emit {\(screen\)}}
} 4 {emit {- Tasword document}} 
if {[S 15 == TAPEFILE]} {emit {- ZXT tapefile}}
}
if {[S 0 == {\023\000\000}]} {emit {Spectrum .TAP data}
if {[S 4 x {}]} {emit {\"%-10.10s\"}}
switch -- [Nv c 3] 0 {emit {- BASIC program}} 1 {emit {- number array}} 2 {emit {- character array}} 3 {emit {- memory block}
if {[N I 14 == 0x1b0040]} {emit {\(screen\)}}
} 
}
if {[S 0 == {ZXTape!\x1a}]} {emit {Spectrum .TZX data}
if {[N c 8 x {}]} {emit {version %d}}
if {[N c 9 x {}]} {emit .%d}
}
if {[S 0 == RZX!]} {emit {Spectrum .RZX data}
if {[N c 4 x {}]} {emit {version %d}}
if {[N c 5 x {}]} {emit .%d}
}
if {[S 0 == {MV\ -\ CPCEMU\ Disk-Fil}]} {emit {Amstrad/Spectrum .DSK data}}
if {[S 0 == {MV\ -\ CPC\ format\ Dis}]} {emit {Amstrad/Spectrum DU54 .DSK data}}
if {[S 0 == {EXTENDED\ CPC\ DSK\ Fil}]} {emit {Amstrad/Spectrum Extended .DSK data}}
if {[S 0 == {\376bin}]} {emit {MySQL replication log}}
if {[S 0 == {\#SUNPC_CONFIG}]} {emit {SunPC 4.0 Properties Values}}
if {[S 0 == snoop]} {emit {Snoop capture file}
if {[N I 8 > 0x0]} {emit {- version %ld}}
switch -- [Nv I 12] 0 {emit {\(IEEE 802.3\)}} 1 {emit {\(IEEE 802.4\)}} 2 {emit {\(IEEE 802.5\)}} 3 {emit {\(IEEE 802.6\)}} 4 {emit {\(Ethernet\)}} 5 {emit {\(HDLC\)}} 6 {emit {\(Character synchronous\)}} 7 {emit {\(IBM channel-to-channel adapter\)}} 8 {emit {\(FDDI\)}} 9 {emit {\(Unknown\)}} 
}
if {[S 36 == acspMSFT]} {emit {Microsoft ICM Color Profile}}
if {[S 36 == acsp]} {emit {Kodak Color Management System, ICC Profile}}
if {[S 0 == {Cobalt\ Networks\ Inc.\nFirmware\ v}]} {emit {Paged COBALT boot rom}
if {[S 38 x {}]} {emit V%.4s}
}
if {[S 0 == CRfs]} {emit {COBALT boot rom data \(Flat boot rom or file system\)}}
if {[S 0 == T707]} {emit {Roland TR-707 Data}}
if {[S 0 == {\#!teapot\012xdr}]} {emit {teapot work sheet \(XDR format\)}}
if {[S 0 == {\032\001}]} {emit {Compiled terminfo entry}}
if {[S 0 == {\367\002}]} {emit {TeX DVI file}
if {[S 16 x {}]} {emit {\(%s\)}}
}
if {[S 0 == {\367\203}]} {emit {TeX generic font data}}
if {[S 0 == {\367\131}]} {emit {TeX packed font data}
if {[S 3 x {}]} {emit {\(%s\)}}
}
if {[S 0 == {\367\312}]} {emit {TeX virtual font data}}
if {[S 0 == {This\ is\ TeX,}]} {emit {TeX transcript text}}
if {[S 0 == {This\ is\ METAFONT,}]} {emit {METAFONT transcript text}}
if {[S 2 == {\000\021}]} {emit {TeX font metric data}
if {[S 33 x {}]} {emit {\(%s\)}}
}
if {[S 2 == {\000\022}]} {emit {TeX font metric data}
if {[S 33 x {}]} {emit {\(%s\)}}
}
if {[S 0 == {\\input\ texinfo}]} {emit {Texinfo source text}}
if {[S 0 == {This\ is\ Info\ file}]} {emit {GNU Info text}}
if {[S 0 == {\\input}]} {emit {TeX document text}}
if {[S 0 == {\\section}]} {emit {LaTeX document text}}
if {[S 0 == {\\setlength}]} {emit {LaTeX document text}}
if {[S 0 == {\\documentstyle}]} {emit {LaTeX document text}}
if {[S 0 == {\\chapter}]} {emit {LaTeX document text}}
if {[S 0 == {\\documentclass}]} {emit {LaTeX 2e document text}}
if {[S 0 == {\\relax}]} {emit {LaTeX auxiliary file}}
if {[S 0 == {\\contentsline}]} {emit {LaTeX  table of contents}}
if {[S 0 == {%\ -*-latex-*-}]} {emit {LaTeX document text}}
if {[S 0 == {\\ifx}]} {emit {TeX document text}}
if {[S 0 == {\\indexentry}]} {emit {LaTeX raw index file}}
if {[S 0 == {\\begin\{theindex\}}]} {emit {LaTeX sorted index}}
if {[S 0 == {\\glossaryentry}]} {emit {LaTeX raw glossary}}
if {[S 0 == {\\begin\{theglossary\}}]} {emit {LaTeX sorted glossary}}
if {[S 0 == {This\ is\ makeindex}]} {emit {Makeindex log file}}
if {[S 0 == {@article\{} c]} {emit {BibTeX text file}}
if {[S 0 == {@book\{} c]} {emit {BibTeX text file}}
if {[S 0 == {@inbook\{} c]} {emit {BibTeX text file}}
if {[S 0 == {@incollection\{} c]} {emit {BibTeX text file}}
if {[S 0 == {@inproceedings\{} c]} {emit {BibTeX text file}}
if {[S 0 == {@manual\{} c]} {emit {BibTeX text file}}
if {[S 0 == {@misc\{} c]} {emit {BibTeX text file}}
if {[S 0 == {@preamble\{} c]} {emit {BibTeX text file}}
if {[S 0 == {@phdthesis\{} c]} {emit {BibTeX text file}}
if {[S 0 == {@techreport\{} c]} {emit {BibTeX text file}}
if {[S 0 == {@unpublished\{} c]} {emit {BibTeX text file}}
if {[S 73 == {%%%\ \ BibTeX-file\{}]} {emit {BibTex text file \(with full header\)}}
if {[S 73 == {%%%\ \ @BibTeX-style-file\{}]} {emit {BibTeX style text file \(with full header\)}}
if {[S 0 == {%\ BibTeX\ standard\ bibliography\ }]} {emit {BibTeX standard bibliography style text file}}
if {[S 0 == {%\ BibTeX\ `}]} {emit {BibTeX custom bibliography style text file}}
if {[S 0 == {@c\ @mapfile\{}]} {emit {TeX font aliases text file}}
if {[S 0 == {%TGIF\ 4}]} {emit {tgif version 4 object file}}
if {[S 0 == **TI80**]} {emit {TI-80 Graphing Calculator File.}}
if {[S 0 == **TI81**]} {emit {TI-81 Graphing Calculator File.}}
if {[S 0 == **TI73**]} {emit {TI-73 Graphing Calculator}
switch -- [Nv c 59] 0 {emit {\(real number\)}} 1 {emit {\(list\)}} 2 {emit {\(matrix\)}} 3 {emit {\(equation\)}} 4 {emit {\(string\)}} 5 {emit {\(program\)}} 6 {emit {\(assembly program\)}} 7 {emit {\(picture\)}} 8 {emit {\(gdb\)}} 12 {emit {\(complex number\)}} 15 {emit {\(window settings\)}} 16 {emit {\(zoom\)}} 17 {emit {\(table setup\)}} 19 {emit {\(backup\)}} 
}
if {[S 0 == **TI82**]} {emit {TI-82 Graphing Calculator}
switch -- [Nv c 59] 0 {emit {\(real\)}} 1 {emit {\(list\)}} 2 {emit {\(matrix\)}} 3 {emit {\(Y-variable\)}} 5 {emit {\(program\)}} 6 {emit {\(protected prgm\)}} 7 {emit {\(picture\)}} 8 {emit {\(gdb\)}} 11 {emit {\(window settings\)}} 12 {emit {\(window settings\)}} 13 {emit {\(table setup\)}} 14 {emit {\(screenshot\)}} 15 {emit {\(backup\)}} 
}
if {[S 0 == **TI83**]} {emit {TI-83 Graphing Calculator}
switch -- [Nv c 59] 0 {emit {\(real\)}} 1 {emit {\(list\)}} 2 {emit {\(matrix\)}} 3 {emit {\(Y-variable\)}} 4 {emit {\(string\)}} 5 {emit {\(program\)}} 6 {emit {\(protected prgm\)}} 7 {emit {\(picture\)}} 8 {emit {\(gdb\)}} 11 {emit {\(window settings\)}} 12 {emit {\(window settings\)}} 13 {emit {\(table setup\)}} 14 {emit {\(screenshot\)}} 19 {emit {\(backup\)}} 
}
if {[S 0 == **TI83F*]} {emit {TI-83+ Graphing Calculator}
switch -- [Nv c 59] 0 {emit {\(real number\)}} 1 {emit {\(list\)}} 2 {emit {\(matrix\)}} 3 {emit {\(equation\)}} 4 {emit {\(string\)}} 5 {emit {\(program\)}} 6 {emit {\(assembly program\)}} 7 {emit {\(picture\)}} 8 {emit {\(gdb\)}} 12 {emit {\(complex number\)}} 15 {emit {\(window settings\)}} 16 {emit {\(zoom\)}} 17 {emit {\(table setup\)}} 19 {emit {\(backup\)}} 21 {emit {\(application variable\)}} 23 {emit {\(group of variable\)}} 
}
if {[S 0 == **TI85**]} {emit {TI-85 Graphing Calculator}
switch -- [Nv c 59] 0 {emit {\(real number\)}} 1 {emit {\(complex number\)}} 2 {emit {\(real vector\)}} 3 {emit {\(complex vector\)}} 4 {emit {\(real list\)}} 5 {emit {\(complex list\)}} 6 {emit {\(real matrix\)}} 7 {emit {\(complex matrix\)}} 8 {emit {\(real constant\)}} 9 {emit {\(complex constant\)}} 10 {emit {\(equation\)}} 12 {emit {\(string\)}} 13 {emit {\(function GDB\)}} 14 {emit {\(polar GDB\)}} 15 {emit {\(parametric GDB\)}} 16 {emit {\(diffeq GDB\)}} 17 {emit {\(picture\)}} 18 {emit {\(program\)}} 19 {emit {\(range\)}} 23 {emit {\(window settings\)}} 24 {emit {\(window settings\)}} 25 {emit {\(window settings\)}} 26 {emit {\(window settings\)}} 27 {emit {\(zoom\)}} 29 {emit {\(backup\)}} 30 {emit {\(unknown\)}} 42 {emit {\(equation\)}} 
if {[S 50 == ZS4]} {emit {- ZShell Version 4 File.}}
if {[S 50 == ZS3]} {emit {- ZShell Version 3 File.}}
}
if {[S 0 == **TI86**]} {emit {TI-86 Graphing Calculator}
switch -- [Nv c 59] 0 {emit {\(real number\)}} 1 {emit {\(complex number\)}} 2 {emit {\(real vector\)}} 3 {emit {\(complex vector\)}} 4 {emit {\(real list\)}} 5 {emit {\(complex list\)}} 6 {emit {\(real matrix\)}} 7 {emit {\(complex matrix\)}} 8 {emit {\(real constant\)}} 9 {emit {\(complex constant\)}} 10 {emit {\(equation\)}} 12 {emit {\(string\)}} 13 {emit {\(function GDB\)}} 14 {emit {\(polar GDB\)}} 15 {emit {\(parametric GDB\)}} 16 {emit {\(diffeq GDB\)}} 17 {emit {\(picture\)}} 18 {emit {\(program\)}} 19 {emit {\(range\)}} 23 {emit {\(window settings\)}} 24 {emit {\(window settings\)}} 25 {emit {\(window settings\)}} 26 {emit {\(window settings\)}} 27 {emit {\(zoom\)}} 29 {emit {\(backup\)}} 30 {emit {\(unknown\)}} 42 {emit {\(equation\)}} 
}
if {[S 0 == **TI89**]} {emit {TI-89 Graphing Calculator}
switch -- [Nv c 72] 0 {emit {\(expression\)}} 4 {emit {\(list\)}} 6 {emit {\(matrix\)}} 10 {emit {\(data\)}} 11 {emit {\(text\)}} 12 {emit {\(string\)}} 13 {emit {\(graphic data base\)}} 14 {emit {\(figure\)}} 16 {emit {\(picture\)}} 18 {emit {\(program\)}} 19 {emit {\(function\)}} 20 {emit {\(macro\)}} 28 {emit {\(zipped\)}} 33 {emit {\(assembler\)}} 
}
if {[S 0 == **TI92**]} {emit {TI-92 Graphing Calculator}
switch -- [Nv c 72] 0 {emit {\(expression\)}} 4 {emit {\(list\)}} 6 {emit {\(matrix\)}} 10 {emit {\(data\)}} 11 {emit {\(text\)}} 12 {emit {\(string\)}} 13 {emit {\(graphic data base\)}} 14 {emit {\(figure\)}} 16 {emit {\(picture\)}} 18 {emit {\(program\)}} 19 {emit {\(function\)}} 20 {emit {\(macro\)}} 29 {emit {\(backup\)}} 
}
if {[S 0 == **TI92P*]} {emit {TI-92+/V200 Graphing Calculator}
switch -- [Nv c 72] 0 {emit {\(expression\)}} 4 {emit {\(list\)}} 6 {emit {\(matrix\)}} 10 {emit {\(data\)}} 11 {emit {\(text\)}} 12 {emit {\(string\)}} 13 {emit {\(graphic data base\)}} 14 {emit {\(figure\)}} 16 {emit {\(picture\)}} 18 {emit {\(program\)}} 19 {emit {\(function\)}} 20 {emit {\(macro\)}} 28 {emit {\(zipped\)}} 33 {emit {\(assembler\)}} 
}
if {[S 22 == Advanced]} {emit {TI-XX Graphing Calculator \(FLASH\)}}
if {[S 0 == **TIFL**]} {emit {TI-XX Graphing Calculator \(FLASH\)}
if {[N c 8 > 0x0]} {emit {- Revision %d}
if {[N c 9 x {}]} {emit {\b.%d,}}
}
if {[N c 12 > 0x0]} {emit {Revision date %02x}
if {[N c 13 x {}]} {emit {\b/%02x}}
if {[N S 14 x {}]} {emit {\b/%04x,}}
}
if {[S 17 > /0]} {emit {name: '%s',}}
switch -- [Nv c 48] 116 {emit {device: TI-73,}} 115 {emit {device: TI-83+,}} -104 {emit {device: TI-89,}} -120 {emit {device: TI-92+,}} 
switch -- [Nv c 49] 35 {emit {type: OS upgrade,}} 36 {emit {type: application,}} 37 {emit {type: certificate,}} 62 {emit {type: license,}} 
if {[N i 74 > 0x0]} {emit {size: %ld bytes}}
}
if {[S 0 == VTI]} {emit {Virtual TI skin}
if {[S 3 == v]} {emit {- Version}
if {[N c 4 > 0x0]} {emit {\b %c}}
if {[N c 6 x {}]} {emit {\b.%c}}
}
}
if {[S 0 == TiEmu]} {emit {TiEmu skin}
if {[S 6 == v]} {emit {- Version}
if {[N c 7 > 0x0]} {emit {\b %c}}
if {[N c 9 x {}]} {emit {\b.%c}}
if {[N c 10 x {}]} {emit {\b%c}}
}
}
if {[S 0 == TZif]} {emit {timezone data}}
if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\0}]} {emit {old timezone data}}
if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\2\0}]} {emit {old timezone data}}
if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\3\0}]} {emit {old timezone data}}
if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\4\0}]} {emit {old timezone data}}
if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\5\0}]} {emit {old timezone data}}
if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\6\0}]} {emit {old timezone data}}
if {[S 0 == {.\\\"}]} {emit {troff or preprocessor input text}}
if {[S 0 == {'\\\"}]} {emit {troff or preprocessor input text}}
if {[S 0 == {'.\\\"}]} {emit {troff or preprocessor input text}}
if {[S 0 == {\\\"}]} {emit {troff or preprocessor input text}}
if {[S 0 == ''']} {emit {troff or preprocessor input text}}
if {[S 0 == {x\ T}]} {emit {ditroff output text}
if {[S 4 == cat]} {emit {for the C/A/T phototypesetter}}
if {[S 4 == ps]} {emit {for PostScript}}
if {[S 4 == dvi]} {emit {for DVI}}
if {[S 4 == ascii]} {emit {for ASCII}}
if {[S 4 == lj4]} {emit {for LaserJet 4}}
if {[S 4 == latin1]} {emit {for ISO 8859-1 \(Latin 1\)}}
if {[S 4 == X75]} {emit {for xditview at 75dpi}
if {[S 7 == -12]} {emit {\(12pt\)}}
}
if {[S 4 == X100]} {emit {for xditview at 100dpi}
if {[S 8 == -12]} {emit {\(12pt\)}}
}
}
if {[S 0 == {\100\357}]} {emit {very old \(C/A/T\) troff output data}}
if {[S 0 == {\0\0\1\236\0\0\0\0\0\0\0\0\0\0\0\0}]} {emit {BEA TUXEDO DES mask data}}
if {[S 0 == Interpress/Xerox]} {emit {Xerox InterPress data}
if {[S 16 == /]} {emit {\(version}
if {[S 17 x {}]} {emit {%s\)}}
}
}
if {[S 0 == {begin\040}]} {emit {uuencoded or xxencoded text}}
if {[S 0 == {xbtoa\ Begin}]} {emit {btoa'd text}}
if {[S 0 == {$\012ship}]} {emit {ship'd binary text}}
if {[S 0 == {Decode\ the\ following\ with\ bdeco}]} {emit {bencoded News text}}
if {[S 11 == {must\ be\ converted\ with\ BinHex}]} {emit {BinHex binary text}
if {[S 41 x {}]} {emit {\b, version %.3s}}
}
if {[N S 6 == 0x107]} {emit {unicos \(cray\) executable}}
if {[S 596 == {\130\337\377\377}]} {emit {Ultrix core file}
if {[S 600 x {}]} {emit {from '%s'}}
}
if {[S 0 == Joy!peffpwpc]} {emit {header for PowerPC PEF executable}}
if {[S 0 == avaobj]} {emit {AVR assembler object code}
if {[S 7 x {}]} {emit {version '%s'}}
}
if {[S 0 == gmon]} {emit {GNU prof performance data}
if {[N Q 4 x {}]} {emit {- version %ld}}
}
if {[S 0 == {\xc0HRB}]} {emit {Harbour HRB file}
if {[N Y 4 x {}]} {emit {version %d}}
}
if {[S 0 == {\#!\ /}]} {emit a
if {[S 3 x {}]} {emit {%s script text executable}}
}
if {[S 0 == {\#!\	/}]} {emit a
if {[S 3 x {}]} {emit {%s script text executable}}
}
if {[S 0 == {\#!/}]} {emit a
if {[S 2 x {}]} {emit {%s script text executable}}
}
if {[S 0 == {\#!\ }]} {emit {script text executable}
if {[S 3 x {}]} {emit {for %s}}
}
if {[S 0 == LBLSIZE=]} {emit {VICAR image data}
if {[S 32 == BYTE]} {emit {\b, 8 bits  = VAX byte}}
if {[S 32 == HALF]} {emit {\b, 16 bits = VAX word     = Fortran INTEGER*2}}
if {[S 32 == FULL]} {emit {\b, 32 bits = VAX longword = Fortran INTEGER*4}}
if {[S 32 == REAL]} {emit {\b, 32 bits = VAX longword = Fortran REAL*4}}
if {[S 32 == DOUB]} {emit {\b, 64 bits = VAX quadword = Fortran REAL*8}}
if {[S 32 == COMPLEX]} {emit {\b, 64 bits = VAX quadword = Fortran COMPLEX*8}}
}
if {[S 43 == SFDU_LABEL]} {emit {VICAR label file}}
if {[S 0 == {\211\277\036\203}]} {emit {Virtutech CRAFF}
if {[N I 4 x {}]} {emit v%d}
switch -- [Nv I 20] 0 {emit uncompressed} 1 {emit bzipp2ed} 2 {emit gzipped} 
if {[N I 24 == 0x0]} {emit {not clean}}
}
if {[S 0 == {\xb0\0\x30\0}]} {emit {VMS VAX executable}
if {[S 44032 == {PK\003\004}]} {emit {\b, Info-ZIP SFX archive v5.12 w/decryption}}
}
if {[S 0 == OggS]} {emit {Ogg data}
if {[N c 4 != 0x0]} {emit {UNKNOWN REVISION %u}}
if {[N c 4 == 0x0]} {if {[S 28 == fLaC]} {emit {\b, FLAC audio}}
if {[S 28 == {\x80theora}]} {emit {\b, Theora video}}
if {[S 28 == {Speex\ \ \ }]} {emit {\b, Speex audio}}
if {[S 28 == {\x01video\0\0\0}]} {emit {\b, OGM video}
if {[S 37 == div3 c]} {emit {\(DivX 3\)}}
if {[S 37 == divx c]} {emit {\(DivX 4\)}}
if {[S 37 == dx50 c]} {emit {\(DivX 5\)}}
if {[S 37 == xvid c]} {emit {\(XviD\)}}
}
if {[S 28 == {\x01vorbis}]} {emit {\b, Vorbis audio,}
if {[N i 35 != 0x0]} {emit {UNKNOWN VERSION %lu,}}
if {[N i 35 == 0x0]} {switch -- [Nv c 39] 1 {emit mono,} 2 {emit stereo,} 
if {[N c 39 > 0x2]} {emit {%u channels,}}
if {[N i 40 x {}]} {emit {%lu Hz}}
if {[S 48 < {\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff}]} {emit {\b,}
if {[N i 52 != 0xffffffff]} {if {[N i 52 != 0x0]} {if {[N i 52 != 0xfffffc18]} {if {[N i 52 x {}]} {emit <%lu}
}
}
}
if {[N i 48 != 0xffffffff]} {if {[N i 48 x {}]} {emit ~%lu}
}
if {[N i 44 != 0xffffffff]} {if {[N i 44 != 0xfffffc18]} {if {[N i 44 != 0x0]} {if {[N i 44 x {}]} {emit >%lu}
}
}
}
if {[S 48 < {\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff}]} {emit bps}
}
}
if {[S [I 84 c 85] == {\x03vorbis}]} {if {[S [I 84 c 96] == {Xiphophorus\ libVorbis\ I} c]} {emit {\b, created by: Xiphophorus libVorbis I}
if {[S [I 84 c 120] > 00000000]} {if {[S [I 84 c 120] < 20000508]} {emit {\(<beta1, prepublic\)}}
if {[S [I 84 c 120] == 20000508]} {emit {\(1.0 beta 1 or beta 2\)}}
if {[S [I 84 c 120] > 20000508]} {if {[S [I 84 c 120] < 20001031]} {emit {\(beta2-3\)}}
}
if {[S [I 84 c 120] == 20001031]} {emit {\(1.0 beta 3\)}}
if {[S [I 84 c 120] > 20001031]} {if {[S [I 84 c 120] < 20010225]} {emit {\(beta3-4\)}}
}
if {[S [I 84 c 120] == 20010225]} {emit {\(1.0 beta 4\)}}
if {[S [I 84 c 120] > 20010225]} {if {[S [I 84 c 120] < 20010615]} {emit {\(beta4-RC1\)}}
}
if {[S [I 84 c 120] == 20010615]} {emit {\(1.0 RC1\)}}
if {[S [I 84 c 120] == 20010813]} {emit {\(1.0 RC2\)}}
if {[S [I 84 c 120] == 20010816]} {emit {\(RC2 - Garf tuned v1\)}}
if {[S [I 84 c 120] == 20011014]} {emit {\(RC2 - Garf tuned v2\)}}
if {[S [I 84 c 120] == 20011217]} {emit {\(1.0 RC3\)}}
if {[S [I 84 c 120] == 20011231]} {emit {\(1.0 RC3\)}}
if {[S [I 84 c 120] > 20011231]} {emit {\(pre-1.0 CVS\)}}
}
}
if {[S [I 84 c 96] == {Xiph.Org\ libVorbis\ I} c]} {emit {\b, created by: Xiph.Org libVorbis I}
if {[S [I 84 c 117] > 00000000]} {if {[S [I 84 c 117] < 20020717]} {emit {\(pre-1.0 CVS\)}}
if {[S [I 84 c 117] == 20020717]} {emit {\(1.0\)}}
if {[S [I 84 c 117] == 20030909]} {emit {\(1.0.1\)}}
if {[S [I 84 c 117] == 20040629]} {emit {\(1.1.0 RC1\)}}
}
}
}
}
}
}
if {[N i 2 == 0x472b2c4e]} {emit {VXL data file,}
if {[N s 0 > 0x0]} {emit {schema version no %d}}
}
if {[S 2 == {\040\040\040\040\040\040\040\040\040\040\040ML4D\040\'92}]} {emit {Smith Corona PWP}
switch -- [Nv c 24] 2 {emit {\b, single spaced}} 3 {emit {\b, 1.5 spaced}} 4 {emit {\b, double spaced}} 
switch -- [Nv c 25] 66 {emit {\b, letter}} 84 {emit {\b, legal}} 
if {[N c 26 == 0x46]} {emit {\b, A4}}
}
if {[S 0 == {\377WPC\020\000\000\000\022\012\001\001\000\000\000\000}]} {emit {\(WP\) loadable text}
switch -- [Nv c 15] 0 {emit {Optimized for Intel}} 1 {emit {Optimized for Non-Intel}} 
}
if {[S 1 == WPC]} {emit {\(Corel/WP\)}
switch -- [Nv Y 8] 257 {emit {WordPerfect macro}} 258 {emit {WordPerfect help file}} 259 {emit {WordPerfect keyboard file}} 266 {emit {WordPerfect document}} 267 {emit {WordPerfect dictionary}} 268 {emit {WordPerfect thesaurus}} 269 {emit {WordPerfect block}} 270 {emit {WordPerfect rectangular block}} 271 {emit {WordPerfect column block}} 272 {emit {WordPerfect printer data}} 275 {emit {WordPerfect printer data}} 276 {emit {WordPerfect driver resource data}} 279 {emit {WordPerfect hyphenation code}} 280 {emit {WordPerfect hyphenation data}} 281 {emit {WordPerfect macro resource data}} 283 {emit {WordPerfect hyphenation lex}} 285 {emit {WordPerfect wordlist}} 286 {emit {WordPerfect equation resource data}} 289 {emit {WordPerfect spell rules}} 290 {emit {WordPerfect dictionary rules}} 295 {emit {WordPerfect spell rules \(Microlytics\)}} 299 {emit {WordPerfect settings file}} 301 {emit {WordPerfect 4.2 document}} 325 {emit {WordPerfect dialog file}} 332 {emit {WordPerfect button bar}} 513 {emit {Shell macro}} 522 {emit {Shell definition}} 769 {emit {Notebook macro}} 770 {emit {Notebook help file}} 771 {emit {Notebook keyboard file}} 778 {emit {Notebook definition}} 1026 {emit {Calculator help file}} 1538 {emit {Calendar help file}} 1546 {emit {Calendar data file}} 1793 {emit {Editor macro}} 1794 {emit {Editor help file}} 1795 {emit {Editor keyboard file}} 1817 {emit {Editor macro resource file}} 2049 {emit {Macro editor macro}} 2050 {emit {Macro editor help file}} 2051 {emit {Macro editor keyboard file}} 2305 {emit {PlanPerfect macro}} 2306 {emit {PlanPerfect help file}} 2307 {emit {PlanPerfect keyboard file}} 2314 {emit {PlanPerfect worksheet}} 2319 {emit {PlanPerfect printer definition}} 2322 {emit {PlanPerfect graphic definition}} 2323 {emit {PlanPerfect data}} 2324 {emit {PlanPerfect temporary printer}} 2329 {emit {PlanPerfect macro resource data}} 2818 {emit {help file}} 2821 {emit {distribution list}} 2826 {emit {out box}} 2827 {emit {in box}} 2836 {emit {users archived mailbox}} 2837 {emit {archived message database}} 2838 {emit {archived attachments}} 3083 {emit {Printer temporary file}} 3330 {emit {Scheduler help file}} 3338 {emit {Scheduler in file}} 3339 {emit {Scheduler out file}} 3594 {emit {GroupWise settings file}} 3601 {emit {GroupWise directory services}} 3627 {emit {GroupWise settings file}} 4362 {emit {Terminal resource data}} 4363 {emit {Terminal resource data}} 4395 {emit {Terminal resource data}} 4619 {emit {GUI loadable text}} 4620 {emit {graphics resource data}} 4621 {emit {printer settings file}} 4622 {emit {port definition file}} 4623 {emit {print queue parameters}} 4624 {emit {compressed file}} 5130 {emit {Network service msg file}} 5131 {emit {Network service msg file}} 5132 {emit {Async gateway login msg}} 5134 {emit {GroupWise message file}} 7956 {emit {GroupWise admin domain database}} 7957 {emit {GroupWise admin host database}} 7959 {emit {GroupWise admin remote host database}} 7960 {emit {GroupWise admin ADS deferment data file}} 8458 {emit {IntelliTAG \(SGML\) compiled DTD}} 
if {[N c 8 == 0xb]} {emit Mail}
switch -- [Nv Q 8] 18219264 {emit {WordPerfect graphic image \(1.0\)}} 18219520 {emit {WordPerfect graphic image \(2.0\)}} 
}
if {[S 0 == {HWP\ Document\ File}]} {emit {Hangul \(Korean\) Word Processor File}}
if {[S 0 == CSBK]} {emit {Ted Neslson's CosmicBook hypertext file}}
if {[S 0 == %XDELTA%]} {emit {XDelta binary patch file 0.14}}
if {[S 0 == %XDZ000%]} {emit {XDelta binary patch file 0.18}}
if {[S 0 == %XDZ001%]} {emit {XDelta binary patch file 0.20}}
if {[S 0 == %XDZ002%]} {emit {XDelta binary patch file 1.0}}
if {[S 0 == %XDZ003%]} {emit {XDelta binary patch file 1.0.4}}
if {[S 0 == %XDZ004%]} {emit {XDelta binary patch file 1.1}}
if {[S 0 == core]} {emit {core file \(Xenix\)}}
if {[S 0 == {\x55\x7A\x6E\x61}]} {emit {xo65 object,}
if {[N s 4 x {}]} {emit {version %d,}}
switch -- [Nv s 6 &0x0001] 1 {emit {with debug info}} 0 {emit {no debug info}} 
}
if {[S 0 == {\x6E\x61\x55\x7A}]} {emit {xo65 library,}
if {[N s 4 x {}]} {emit {version %d}}
}
if {[S 0 == {\x01\x00\x6F\x36\x35}]} {emit o65
switch -- [Nv s 6 &0x1000] 0 {emit executable,} 4096 {emit object,} 
if {[N c 5 x {}]} {emit {version %d,}}
switch -- [Nv s 6 &0x8000] -32768 {emit 65816,} 0 {emit 6502,} 
switch -- [Nv s 6 &0x2000] 8192 {emit {32 bit,}} 0 {emit {16 bit,}} 
switch -- [Nv s 6 &0x4000] 16384 {emit {page reloc,}} 0 {emit {byte reloc,}} 
switch -- [Nv s 6 &0x0003] 0 {emit {alignment 1}} 1 {emit {alignment 2}} 2 {emit {alignment 4}} 3 {emit {alignment 256}} 
}
if {[S 1 == mkx]} {emit {Compiled XKB Keymap: lsb,}
if {[N c 0 > 0x0]} {emit {version %d}}
if {[N c 0 == 0x0]} {emit obsolete}
}
if {[S 0 == xkm]} {emit {Compiled XKB Keymap: msb,}
if {[N c 3 > 0x0]} {emit {version %d}}
if {[N c 0 == 0x0]} {emit obsolete}
}
if {[S 0 == xFSdump0]} {emit {xfsdump archive}
if {[N Q 8 x {}]} {emit {\(version %d\)}}
}
if {[S 0 == {ZyXEL\002}]} {emit {ZyXEL voice data}
if {[N c 10 == 0x0]} {emit {- CELP encoding}}
switch -- [Nv c 10 &0x0B] 1 {emit {- ADPCM2 encoding}} 2 {emit {- ADPCM3 encoding}} 3 {emit {- ADPCM4 encoding}} 8 {emit {- New ADPCM3 encoding}} 
if {[N c 10 == 0x4 &0x04]} {emit {with resync}}
}

result

return {}
}

## -- ** END GENERATED CODE ** --
## -- Do not edit before this line !
##

# ### ### ### ######### ######### #########
## Ready for use.
# EOF
