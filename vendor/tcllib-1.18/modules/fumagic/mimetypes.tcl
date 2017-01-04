# mimetypes.tcl --
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
# RCS: @(#) $Id: mimetypes.tcl,v 1.8 2006/09/27 21:19:35 andreas_kupries Exp $

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

proc ::fileutil::magic::mimetype {file} {
    if {![file exists $file]} {
        return -code error "file not found: \"$file\""
    }
    if {[file isdirectory $file]} {
	return application/x-directory
    }

    rt::open $file
    mimetype::run
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
    return $types
}

package provide fileutil::magic::mimetype 1.0.2
# The actual recognizer is the command below.

##
## -- Do not edit after this line !
## -- ** BEGIN GENERATED CODE ** --

package require fileutil::magic::rt
namespace eval ::fileutil::magic::mimetype {
    namespace import ::fileutil::magic::rt::*
}

proc ::fileutil::magic::mimetype::run {} {
    switch -- [Nv s 0 ] 1538 {emit application/x-alan-adventure-game} 387 {emit application/x-executable-file} -147 {emit application/data} -155 {emit application/data} -5536 {emit application/x-arj} -138 {emit application/data} -394 {emit application/data} -650 {emit application/x-lzh} 387 {emit application/x-executable-file} 392 {emit application/x-executable-file} 399 {emit application/x-object-file} -13230 {emit {RLE image data,}} 322 {emit {basic-16 executable}} 323 {emit {basic-16 executable \(TV\)}} 328 {emit application/x-executable-file} 329 {emit application/x-executable-file} 330 {emit application/x-executable-file} 338 {emit application/x-executable-file} 332 {emit application/x-executable-file} 1078 {emit font/linux-psf} 387 {emit {ECOFF alpha}} 332 {emit {MS Windows COFF Intel 80386 object file}} 358 {emit {MS Windows COFF MIPS R4000 object file}} 388 {emit {MS Windows COFF Alpha object file}} 616 {emit {MS Windows COFF Motorola 68000 object file}} 496 {emit {MS Windows COFF PowerPC object file}} 656 {emit {MS Windows COFF PA-RISC object file}} 263 {emit {PDP-11 executable}} 257 {emit {PDP-11 UNIX/RT ldp}} 261 {emit {PDP-11 old overlay}} 264 {emit {PDP-11 pure executable}} 265 {emit {PDP-11 separate I&D executable}} 287 {emit {PDP-11 kernel overlay}} 4843 {emit {SYMMETRY i386 .o}} 8939 {emit {SYMMETRY i386 executable \(0 @ 0\)}} 13035 {emit {SYMMETRY i386 executable \(invalid @ 0\)}} 17131 {emit {SYMMETRY i386 standalone executable}} 376 {emit {VAX COFF executable}} 381 {emit {VAX COFF pure executable}} -155 {emit x.out} 518 {emit {Microsoft a.out}} 320 {emit {old Microsoft 8086 x.out}} 1408 {emit {XENIX 8086 relocatable or 80286 small model}}
    if {[S 0 == TADS ]} {emit application/x-tads-game}
    switch -- [Nv S 0 ] 272 {emit application/x-executable-file} 273 {emit application/x-executable-file} 29127 {emit application/x-cpio} -14479 {emit application/x-bcpio} -147 {emit application/data} -155 {emit application/data} 368 {emit application/x-executable-file} 369 {emit application/x-executable-file} 1793 {emit application/x-executable-file} 262 {emit application/x-executable-file} 1537 {emit application/x-executable-file} 381 {emit application/x-executable-file} 383 {emit application/x-executable-file} 7967 {emit application/data} 8191 {emit application/data} -13563 {emit application/data} 1281 {emit application/x-locale} 340 {emit application/data} 341 {emit application/x-executable-file} 286 {emit font/x-vfont} 7681 {emit font/x-vfont} 407 {emit application/x-executable-file} 404 {emit application/x-executable-file} 200 {emit {hp200 \(68010\) BSD}} 300 {emit {hp300 \(68020+68881\) BSD}} 351 {emit {370 XA sysV executable}} 346 {emit {370 XA sysV pure executable}} 22529 {emit {370 sysV pure executable}} 23041 {emit {370 XA sysV pure executable}} 23809 {emit {370 sysV executable}} 24321 {emit {370 XA sysV executable}} 345 {emit {SVR2 executable \(Amdahl-UTS\)}} 348 {emit {SVR2 pure executable \(Amdahl-UTS\)}} 344 {emit {SVR2 pure executable \(USS/370\)}} 349 {emit {SVR2 executable \(USS/370\)}} 479 {emit {executable \(RISC System/6000 V3.1\) or obj module}} 260 {emit {shared library}} 261 {emit {ctab data}} -508 {emit {structured file}} 12320 {emit {character Computer Graphics Metafile}} -40 {emit image/jpeg} 474 {emit x/x-image-sgi} 4112 {emit {PEX Binary Archive}} -21267 {emit {Java serialization data}} -32768 {emit {lif file}} 256 {emit {raw G3 data, byte-padded}} 5120 {emit {raw G3 data}} 336 {emit {mc68k COFF}} 337 {emit {mc68k executable \(shared\)}} 338 {emit {mc68k executable \(shared demand paged\)}} 364 {emit {68K BCS executable}} 365 {emit {88K BCS executable}} 392 {emit {Tower/XP rel 2 object}} 397 {emit {Tower/XP rel 2 object}} 400 {emit {Tower/XP rel 3 object}} 405 {emit {Tower/XP rel 3 object}} 408 {emit {Tower32/600/400 68020 object}} 416 {emit {Tower32/800 68020}} 421 {emit {Tower32/800 68010}} -30771 {emit {OS9/6809 module:}} 19196 {emit {OS9/68K module:}} 373 {emit {i386 COFF object}} 10775 {emit {\"compact bitmap\" format \(Poskanzer\)}} -26368 {emit {PGP key public ring}} -27391 {emit {PGP key security ring}} -27392 {emit {PGP key security ring}} -23040 {emit {PGP encrypted data}} 601 {emit {mumps avl global}} 602 {emit {mumps blt global}} -4693 {emit {}} 10012 {emit {Sendmail frozen configuration}} -30875 {emit {disk quotas file}} 1286 {emit {IRIS Showcase file}} 550 {emit {IRIS Showcase template}} 352 {emit {MIPSEB COFF executable}} 354 {emit {MIPSEL COFF executable}} 24577 {emit {MIPSEB-LE COFF executable}} 25089 {emit {MIPSEL-LE COFF executable}} 355 {emit {MIPSEB MIPS-II COFF executable}} 358 {emit {MIPSEL MIPS-II COFF executable}} 25345 {emit {MIPSEB-LE MIPS-II COFF executable}} 26113 {emit {MIPSEL-LE MIPS-II COFF executable}} 320 {emit {MIPSEB MIPS-III COFF executable}} 322 {emit {MIPSEL MIPS-III COFF executable}} 16385 {emit {MIPSEB-LE MIPS-III COFF executable}} 16897 {emit {MIPSEL-LE MIPS-III COFF executable}} 384 {emit {MIPSEB Ucode}} 386 {emit {MIPSEL Ucode}} -16162 {emit {Compiled PSI \(v1\) data}} -16166 {emit {Compiled PSI \(v2\) data}} -21846 {emit {SoftQuad DESC or font file binary}} 283 {emit {Curses screen image}} 284 {emit {Curses screen image}} 263 {emit {unknown machine executable}} 264 {emit {unknown pure executable}} 265 {emit {PDP-11 separate I&D}} 267 {emit {unknown pure executable}} 392 {emit {Perkin-Elmer executable}} 378 {emit {amd 29k coff noprebar executable}} 890 {emit {amd 29k coff prebar executable}} -8185 {emit {amd 29k coff archive}} 21845 {emit {VISX image file}}
    if {[S 0 == {Core\001} ]} {emit application/x-executable-file}
    if {[S 0 == {AMANDA:\ TAPESTART\ DATE} ]} {emit application/x-amanda-header}
    switch -- [Nv I 0 ] 1011 {emit application/x-executable-file} 999 {emit application/x-library-file} 435 {emit video/mpeg} 442 {emit video/mpeg} 33132 {emit application/x-apl-workspace} 333312 {emit application/data} 333319 {emit application/data} 65389 {emit application/x-ar} 65381 {emit application/data} 33132 {emit application/x-apl-workspace} 1711210496 {emit application/x-ar} 1013019198 {emit application/x-ar} 557605234 {emit application/x-ar} 1314148939 {emit audio/x-multitrack} 779248125 {emit audio/x-pn-realaudio} 262 {emit application/x-executable-file} 327 {emit application/x-object-file} 331 {emit application/x-executable-file} 333 {emit application/x-executable-file} 335 {emit application/x-executable-file} 70231 {emit application/core} 385 {emit application/x-object-file} 391 {emit application/data} 324508366 {emit application/x-gdbm} 398689 {emit application/x-db} 340322 {emit application/x-db} 1234567 {emit image/x11} 4 {emit font/x-snf} 335698201 {emit font/x-libgrx} -12169394 {emit font/x-dos} 168757262 {emit application/data} 252317192 {emit application/data} 135137807 {emit application/data} 235409162 {emit application/data} 34603270 {emit application/x-object-file} 34603271 {emit application/x-executable-file} 34603272 {emit application/x-executable-file} 34603275 {emit application/x-executable-file} 34603278 {emit application/x-library-file} 34603277 {emit application/x-library-file} 34865414 {emit application/x-object-file} 34865415 {emit application/x-executable-file} 34865416 {emit application/x-executable-file} 34865419 {emit application/x-executable-file} 34865422 {emit application/x-library-file} 34865421 {emit application/x-object-file} 34275590 {emit application/x-object-file} 34275591 {emit application/x-executable-file} 34275592 {emit application/x-executable-file} 34275595 {emit application/x-executable-file} 34275598 {emit application/x-library-file} 34275597 {emit application/x-library-file} 557605234 {emit application/x-ar} 34078982 {emit application/x-executable-file} 34078983 {emit application/x-executable-file} 34078984 {emit application/x-executable-file} 34341128 {emit application/x-executable-file} 34341127 {emit application/x-executable-file} 34341131 {emit application/x-executable-file} 34341126 {emit application/x-executable-file} 34210056 {emit application/x-executable-file} 34210055 {emit application/x-executable-file} 34341134 {emit application/x-library-file} 34341133 {emit application/x-library-file} 65381 {emit application/x-library-file} 34275173 {emit application/x-library-file} 34406245 {emit application/x-library-file} 34144101 {emit application/x-library-file} 22552998 {emit application/core} 1302851304 {emit font/x-hp-windows} 34341132 {emit application/x-lisp} 505 {emit {AIX compiled message catalog}} 1123028772 {emit {Artisan image data}} 1504078485 {emit x/x-image-sun-raster} -889275714 {emit {compiled Java class data,}} -1195374706 {emit {Linux kernel}} 1886817234 {emit {CLISP memory image data}} -762612112 {emit {CLISP memory image data, other endian}} -569244523 {emit {GNU-format message catalog data}} -1794895138 {emit {GNU-format message catalog data}} -889275714 {emit {mach-o fat file}} -17958194 {emit mach-o} 31415 {emit {Mirage Assembler m.out executable}} 834535424 {emit text/vnd.ms-word} 6656 {emit {Lotus 1-2-3}} 512 {emit {Lotus 1-2-3}} 263 {emit {NetBSD big-endian object file}} 326773060 {emit font/x-sunos-news} 326773063 {emit font/x-sunos-news} 326773072 {emit font/x-sunos-news} 326773073 {emit font/x-sunos-news} 61374 {emit {OSF/Rose object}} -976170042 {emit {DOS EPS Binary File}} 1351614727 {emit {Pyramid 90x family executable}} 1351614728 {emit {Pyramid 90x family pure executable}} 1351614731 {emit {Pyramid 90x family demand paged pure executable}} 263 {emit {old SGI 68020 executable}} 264 {emit {old SGI 68020 pure executable}} 1396917837 {emit {IRIS Showcase file}} 1413695053 {emit {IRIS Showcase template}} -559039810 {emit {IRIX Parallel Arena}} -559043152 {emit {IRIX core dump}} -559043264 {emit {IRIX 64-bit core dump}} -1161903941 {emit {IRIX N32 core dump}} -1582119980 {emit {tcpdump capture file \(big-endian\)}} 263 {emit {old sun-2 executable}} 264 {emit {old sun-2 pure executable}} 267 {emit {old sun-2 demand paged executable}} 525398 {emit {SunOS core file}} -97271666 {emit {SunPC 4.0 Hard Disk}} 268 {emit {unknown demand paged pure executable}} 269 {emit {unknown demand paged pure executable}} 270 {emit {unknown readable demand paged pure executable}} 50331648 {emit {VMS Alpha executable}} 59399 {emit {object file \(z8000 a.out\)}} 59400 {emit {pure object file \(z8000 a.out\)}} 59401 {emit {separate object file \(z8000 a.out\)}} 59397 {emit {overlay object file \(z8000 a.out\)}}
    if {[N S 0 == 0xfff0 &0xfff0]} {emit audio/mpeg}
    switch -- [Nv s 4 ] -20719 {emit video/fli} -20718 {emit video/flc}
    if {[S 8 == {AVI\	} ]} {emit video/x-msvideo}
    if {[S 0 == MOVI ]} {emit video/x-sgi-movie}
    if {[S 4 == moov ]} {emit video/quicktime}
    if {[S 4 == mdat ]} {emit video/quicktime}
    if {[S 0 == FiLeStArTfIlEsTaRt ]} {emit text/x-apple-binscii}
    if {[S 0 == {\x0aGL} ]} {emit application/data}
    if {[S 0 == {\x76\xff} ]} {emit application/data}
    if {[S 0 == NuFile ]} {emit application/data}
    if {[S 0 == {N\xf5F\xe9l\xe5} ]} {emit application/data}
    if {[S 257 == {ustar\0} ]} {emit application/x-tar}
    if {[S 257 == {ustar\040\040\0} ]} {emit application/x-gtar}
    if {[S 0 == 070707 ]} {emit application/x-cpio}
    if {[S 0 == 070701 ]} {emit application/x-cpio}
    if {[S 0 == 070702 ]} {emit application/x-cpio}
    if {[S 0 == {!<arch>\ndebian} ]} {emit application/x-dpkg}
    if {[S 0 == <ar> ]} {emit application/x-ar}
    if {[S 0 == {!<arch>\n__________E} ]} {emit application/x-ar}
    if {[S 0 == -h- ]} {emit application/data}
    if {[S 0 == !<arch> ]} {emit application/x-ar}
    if {[S 0 == <ar> ]} {emit application/x-ar}
    if {[S 0 == <ar> ]} {emit application/x-ar}
    switch -- [Nv i 0 ] 65389 {emit application/data} 65381 {emit application/data} 236525 {emit application/data} 236526 {emit application/data} 6583086 {emit audio/basic} 204 {emit application/x-executable-file} 324508366 {emit application/x-gdbm} 453186358 {emit application/x-bootable} 4 {emit font/x-snf} 1279543401 {emit application/data} 6553863 {emit {Linux/i386 impure executable \(OMAGIC\)}} 6553864 {emit {Linux/i386 pure executable \(NMAGIC\)}} 6553867 {emit {Linux/i386 demand-paged executable \(ZMAGIC\)}} 6553804 {emit {Linux/i386 demand-paged executable \(QMAGIC\)}} 263 {emit {NetBSD little-endian object file}} 459141 {emit {ECOFF NetBSD/alpha binary}} 33645 {emit {PDP-11 single precision APL workspace}} 33644 {emit {PDP-11 double precision APL workspace}} 234 {emit {BALANCE NS32000 .o}} 4330 {emit {BALANCE NS32000 executable \(0 @ 0\)}} 8426 {emit {BALANCE NS32000 executable \(invalid @ 0\)}} 12522 {emit {BALANCE NS32000 standalone executable}} -1582119980 {emit {tcpdump capture file \(little-endian\)}} 33647 {emit {VAX single precision APL workspace}} 33646 {emit {VAX double precision APL workspace}} 263 {emit {VAX executable}} 264 {emit {VAX pure executable}} 267 {emit {VAX demand paged pure executable}} 518 {emit b.out}
    switch -- [Nv i 0 &0x8080ffff] 2074 {emit application/x-arc} 2330 {emit application/x-arc} 538 {emit application/x-arc} 794 {emit application/x-arc} 1050 {emit application/x-arc} 1562 {emit application/x-arc}
    if {[S 0 == {\032archive} ]} {emit application/data}
    if {[S 0 == HPAK ]} {emit application/data}
    if {[S 0 == {\351,\001JAM\	} ]} {emit application/data}
    if {[S 2 == -lh0- ]} {emit application/x-lha}
    if {[S 2 == -lh1- ]} {emit application/x-lha}
    if {[S 2 == -lz4- ]} {emit application/x-lha}
    if {[S 2 == -lz5- ]} {emit application/x-lha}
    if {[S 2 == -lzs- ]} {emit application/x-lha}
    if {[S 2 == {-lh\40-} ]} {emit application/x-lha}
    if {[S 2 == -lhd- ]} {emit application/x-lha}
    if {[S 2 == -lh2- ]} {emit application/x-lha}
    if {[S 2 == -lh3- ]} {emit application/x-lha}
    if {[S 2 == -lh4- ]} {emit application/x-lha}
    if {[S 2 == -lh5- ]} {emit application/x-lha}
    if {[S 0 == Rar! ]} {emit application/x-rar}
    if {[S 0 == SQSH ]} {emit application/data}
    if {[S 0 == {UC2\x1a} ]} {emit application/data}
    if {[S 0 == {PK\003\004} ]} {emit application/zip}
    if {[N i 20 == 0xfdc4a7dc ]} {emit application/x-zoo}
    if {[S 10 == {\#\ This\ is\ a\ shell\ archive} ]} {emit application/x-shar}
    if {[S 0 == *STA ]} {emit application/data}
    if {[S 0 == 2278 ]} {emit application/data}
    if {[S 0 == {\000\004\036\212\200} ]} {emit application/core}
    if {[S 0 == .snd ]} {emit audio/basic}
    if {[S 0 == MThd ]} {emit audio/midi}
    if {[S 0 == CTMF ]} {emit audio/x-cmf}
    if {[S 0 == SBI ]} {emit audio/x-sbi}
    if {[S 0 == {Creative\ Voice\ File} ]} {emit audio/x-voc}
    if {[S 0 == RIFF ]} {emit audio/x-wav}
    if {[S 8 == AIFC ]} {emit audio/x-aifc}
    if {[S 8 == AIFF ]} {emit audio/x-aiff}
    if {[S 0 == {.ra\375} ]} {emit audio/x-real-audio}
    if {[S 8 == WAVE ]} {emit audio/x-wav}
    if {[S 8 == {WAV\	} ]} {emit audio/x-wav}
    if {[S 0 == RIFF ]} {emit audio/x-riff}
    if {[S 0 == EMOD ]} {emit audio/x-emod}
    if {[S 0 == MTM ]} {emit audio/x-multitrack}
    if {[S 0 == if ]} {emit audio/x-669-mod}
    if {[S 0 == FAR ]} {emit audio/mod}
    if {[S 0 == MAS_U ]} {emit audio/x-multimate-mod}
    if {[S 44 == SCRM ]} {emit audio/x-st3-mod}
    if {[S 0 == {GF1PATCH110\0ID\#000002\0} ]} {emit audio/x-gus-patch}
    if {[S 0 == {GF1PATCH100\0ID\#000002\0} ]} {emit audio/x-gus-patch}
    if {[S 0 == JN ]} {emit audio/x-669-mod}
    if {[S 0 == UN05 ]} {emit audio/x-mikmod-uni}
    if {[S 0 == {Extended\ Module:} ]} {emit audio/x-ft2-mod}
    if {[S 21 == !SCREAM! ]} {emit audio/x-st2-mod}
    if {[S 1080 == M.K. ]} {emit audio/x-protracker-mod}
    if {[S 1080 == M!K! ]} {emit audio/x-protracker-mod}
    if {[S 1080 == FLT4 ]} {emit audio/x-startracker-mod}
    if {[S 1080 == 4CHN ]} {emit audio/x-fasttracker-mod}
    if {[S 1080 == 6CHN ]} {emit audio/x-fasttracker-mod}
    if {[S 1080 == 8CHN ]} {emit audio/x-fasttracker-mod}
    if {[S 1080 == CD81 ]} {emit audio/x-oktalyzer-mod}
    if {[S 1080 == OKTA ]} {emit audio/x-oktalyzer-mod}
    if {[S 1080 == 16CN ]} {emit audio/x-taketracker-mod}
    if {[S 1080 == 32CN ]} {emit audio/x-taketracker-mod}
    if {[S 0 == TOC ]} {emit audio/x-toc}
    if {[S 0 == // ]} {emit text/cpp}
    if {[S 0 == {\\1cw\ } ]} {emit application/data}
    if {[S 0 == {\\1cw} ]} {emit application/data}
    switch -- [Nv I 0 &0xffffff00] -2063526912 {emit application/data} -2063480064 {emit application/data}
    if {[S 4 == pipe ]} {emit application/data}
    if {[S 4 == prof ]} {emit application/data}
    if {[S 0 == {:\ shell} ]} {emit application/data}
    if {[S 0 == {\#!/bin/sh} ]} {emit application/x-sh}
    if {[S 0 == {\#!\ /bin/sh} ]} {emit application/x-sh}
    if {[S 0 == {\#!\	/bin/sh} ]} {emit application/x-sh}
    if {[S 0 == {\#!/bin/csh} ]} {emit application/x-csh}
    if {[S 0 == {\#!\ /bin/csh} ]} {emit application/x-csh}
    if {[S 0 == {\#!\	/bin/csh} ]} {emit application/x-csh}
    if {[S 0 == {\#!/bin/ksh} ]} {emit application/x-ksh}
    if {[S 0 == {\#!\ /bin/ksh} ]} {emit application/x-ksh}
    if {[S 0 == {\#!\	/bin/ksh} ]} {emit application/x-ksh}
    if {[S 0 == {\#!/bin/tcsh} ]} {emit application/x-csh}
    if {[S 0 == {\#!\ /bin/tcsh} ]} {emit application/x-csh}
    if {[S 0 == {\#!\	/bin/tcsh} ]} {emit application/x-csh}
    if {[S 0 == {\#!/usr/local/tcsh} ]} {emit application/x-csh}
    if {[S 0 == {\#!\ /usr/local/tcsh} ]} {emit application/x-csh}
    if {[S 0 == {\#!/usr/local/bin/tcsh} ]} {emit application/x-csh}
    if {[S 0 == {\#!\ /usr/local/bin/tcsh} ]} {emit application/x-csh}
    if {[S 0 == {\#!\	/usr/local/bin/tcsh} ]} {emit application/x-csh}
    if {[S 0 == {\#!/usr/local/bin/zsh} ]} {emit application/x-zsh}
    if {[S 0 == {\#!\ /usr/local/bin/zsh} ]} {emit application/x-zsh}
    if {[S 0 == {\#!\	/usr/local/bin/zsh} ]} {emit application/x-zsh}
    if {[S 0 == {\#!/usr/local/bin/ash} ]} {emit application/x-sh}
    if {[S 0 == {\#!\ /usr/local/bin/ash} ]} {emit application/x-zsh}
    if {[S 0 == {\#!\	/usr/local/bin/ash} ]} {emit application/x-zsh}
    if {[S 0 == {\#!/usr/local/bin/ae} ]} {emit text/script}
    if {[S 0 == {\#!\ /usr/local/bin/ae} ]} {emit text/script}
    if {[S 0 == {\#!\	/usr/local/bin/ae} ]} {emit text/script}
    if {[S 0 == {\#!/bin/nawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\ /bin/nawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\	/bin/nawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!/usr/bin/nawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\ /usr/bin/nawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\	/usr/bin/nawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!/usr/local/bin/nawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\ /usr/local/bin/nawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\	/usr/local/bin/nawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!/bin/gawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\ /bin/gawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\	/bin/gawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!/usr/bin/gawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\ /usr/bin/gawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\	/usr/bin/gawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!/usr/local/bin/gawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\ /usr/local/bin/gawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\	/usr/local/bin/gawk} ]} {emit application/x-awk}
    if {[S 0 == {\#!/bin/awk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\ /bin/awk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\	/bin/awk} ]} {emit application/x-awk}
    if {[S 0 == {\#!/usr/bin/awk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\ /usr/bin/awk} ]} {emit application/x-awk}
    if {[S 0 == {\#!\	/usr/bin/awk} ]} {emit application/x-awk}
    if {[S 0 == BEGIN ]} {emit application/x-awk}
    if {[S 0 == {\#!/bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {\#!\ /bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {\#!\	/bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {eval\ \"exec\ /bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {\#!/usr/bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {\#!\ /usr/bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {\#!\	/usr/bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {eval\ \"exec\ /usr/bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {\#!/usr/local/bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {\#!\ /usr/local/bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {\#!\	/usr/local/bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {eval\ \"exec\ /usr/local/bin/perl} ]} {emit application/x-perl}
    if {[S 0 == {\#!/bin/rc} ]} {emit text/script}
    if {[S 0 == {\#!\ /bin/rc} ]} {emit text/script}
    if {[S 0 == {\#!\	/bin/rc} ]} {emit text/script}
    if {[S 0 == {\#!/bin/bash} ]} {emit application/x-sh}
    if {[S 0 == {\#!\ /bin/bash} ]} {emit application/x-sh}
    if {[S 0 == {\#!\	/bin/bash} ]} {emit application/x-sh}
    if {[S 0 == {\#!/usr/local/bin/bash} ]} {emit application/x-sh}
    if {[S 0 == {\#!\ /usr/local/bin/bash} ]} {emit application/x-sh}
    if {[S 0 == {\#!\	/usr/local/bin/bash} ]} {emit application/x-sh}
    if {[S 0 == {\#!\ /} ]} {emit text/script}
    if {[S 0 == {\#!\	/} ]} {emit text/script}
    if {[S 0 == {\#!/} ]} {emit text/script}
    if {[S 0 == {\#!\ } ]} {emit text/script}
    if {[S 0 == {\037\235} ]} {emit application/compress}
    if {[S 0 == {\037\213} ]} {emit application/x-gzip}
    if {[S 0 == {\037\036} ]} {emit application/data}
    if {[S 0 == {\377\037} ]} {emit application/data}
    if {[S 0 == BZh ]} {emit application/x-bzip2}
    if {[S 0 == {\037\237} ]} {emit application/data}
    if {[S 0 == {\037\236} ]} {emit application/data}
    if {[S 0 == {\037\240} ]} {emit application/data}
    if {[S 0 == BZ ]} {emit application/x-bzip}
    if {[S 0 == {\x89\x4c\x5a\x4f\x00\x0d\x0a\x1a\x0a} ]} {emit application/data}
    switch -- [Nv I 24 ] 60011 {emit application/data} 60012 {emit application/data} 60013 {emit application/data} 60014 {emit application/data} 60012 {emit application/x-dump} 60011 {emit application/x-dump}
    if {[S 0 == GDBM ]} {emit application/x-gdbm}
    if {[S 0 == {<list>\n<protocol\ bbn-m} ]} {emit application/data}
    if {[S 0 == {diff\ } ]} {emit text/x-patch}
    if {[S 0 == {***\ } ]} {emit text/x-patch}
    if {[S 0 == {Only\ in\ } ]} {emit text/x-patch}
    if {[S 0 == {Common\ subdirectories:\ } ]} {emit text/x-patch}
    if {[S 0 == {!<arch>\n________64E} ]} {emit application/data}
    if {[S 0 == {\377\377\177} ]} {emit application/data}
    if {[S 0 == {\377\377\174} ]} {emit application/data}
    if {[S 0 == {\377\377\176} ]} {emit application/data}
    if {[S 0 == {\033c\033} ]} {emit application/data}
    if {[S 0 == {!<PDF>!\n} ]} {emit application/x-prof}
    switch -- [Nv i 24 ] 60012 {emit application/x-dump} 60011 {emit application/x-dump}
    if {[S 0 == {\177ELF} ]} {emit application/x-executable-file}
    if {[N s 1080 == 0xef53 ]} {emit application/x-linux-ext2fs}
    if {[S 0 == {\366\366\366\366} ]} {emit application/x-pc-floppy}
    if {[N S 508 == 0xdabe ]} {emit application/data}
    if {[N s 510 == 0xaa55 ]} {emit application/data}
    switch -- [Nv s 1040 ] 4991 {emit application/x-filesystem} 5007 {emit application/x-filesystem} 9320 {emit application/x-filesystem} 9336 {emit application/x-filesystem}
    if {[S 0 == {-rom1fs-\0} ]} {emit application/x-filesystem}
    if {[S 395 == OS/2 ]} {emit application/x-bootable}
    if {[S 0 == FONT ]} {emit font/x-vfont}
    if {[S 0 == %!PS-AdobeFont-1.0 ]} {emit font/type1}
    if {[S 6 == %!PS-AdobeFont-1.0 ]} {emit font/type1}
    if {[S 0 == {STARTFONT\040} ]} {emit font/x-bdf}
    if {[S 0 == {\001fcp} ]} {emit font/x-pcf}
    if {[S 0 == {D1.0\015} ]} {emit font/x-speedo}
    if {[S 0 == flf ]} {emit font/x-figlet}
    if {[S 0 == flc ]} {emit application/x-font}
    switch -- [Nv I 7 ] 4540225 {emit font/x-dos} 5654852 {emit font/x-dos}
    if {[S 4098 == DOSFONT ]} {emit font/x-dos}
    if {[S 0 == <MakerFile ]} {emit application/x-framemaker}
    if {[S 0 == <MIFFile ]} {emit application/x-framemaker}
    if {[S 0 == <MakerDictionary ]} {emit application/x-framemaker}
    if {[S 0 == <MakerScreenFont ]} {emit font/x-framemaker}
    if {[S 0 == <MML ]} {emit application/x-framemaker}
    if {[S 0 == <BookFile ]} {emit application/x-framemaker}
    if {[S 0 == <Maker ]} {emit application/x-framemaker}
    switch -- [Nv i 0 &0377777777] 8782087 {emit application/x-executable-file} 8782088 {emit application/x-executable-file} 8782091 {emit application/x-executable-file} 8782028 {emit application/x-executable-file}
    if {[S 7 == {\357\020\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0} ]} {emit application/core}
    if {[S 0 == {GIMP\ Gradient} ]} {emit application/x-gimp-gradient}
    if {[S 0 == {gimp\ xcf} ]} {emit application/x-gimp-image}
    if {[S 20 == GPAT ]} {emit application/x-gimp-pattern}
    if {[S 20 == GIMP ]} {emit application/x-gimp-brush}
    if {[S 0 == {\336\22\4\225} ]} {emit application/x-locale}
    if {[S 0 == {\225\4\22\336} ]} {emit application/x-locale}
    if {[S 0 == {\000\001\000\000\000} ]} {emit font/ttf}
    if {[S 0 == Bitmapfile ]} {emit image/unknown}
    if {[S 0 == IMGfile ]} {emit {CIS 	image/unknown}}
    if {[S 0 == msgcat01 ]} {emit application/x-locale}
    if {[S 0 == HPHP48- ]} {emit {HP48 binary}}
    if {[S 0 == %%HP: ]} {emit {HP48 text}}
    if {[S 0 == 0xabcdef ]} {emit {AIX message catalog}}
    if {[S 0 == <aiaff> ]} {emit archive}
    if {[S 0 == FORM ]} {emit {IFF data}}
    if {[S 0 == P1 ]} {emit image/x-portable-bitmap}
    if {[S 0 == P2 ]} {emit image/x-portable-graymap}
    if {[S 0 == P3 ]} {emit image/x-portable-pixmap}
    if {[S 0 == P4 ]} {emit image/x-portable-bitmap}
    if {[S 0 == P5 ]} {emit image/x-portable-graymap}
    if {[S 0 == P6 ]} {emit image/x-portable-pixmap}
    if {[S 0 == IIN1 ]} {emit image/tiff}
    if {[S 0 == {MM\x00\x2a} ]} {emit image/tiff}
    if {[S 0 == {II\x2a\x00} ]} {emit image/tiff}
    if {[S 0 == {\x89PNG} ]} {emit image/x-png}
    if {[S 1 == PNG ]} {emit image/x-png}
    if {[S 0 == GIF8 ]} {emit image/gif}
    if {[S 0 == {\361\0\100\273} ]} {emit image/x-cmu-raster}
    if {[S 0 == id=ImageMagick ]} {emit {MIFF image data}}
    if {[S 0 == {\#FIG} ]} {emit {FIG image text}}
    if {[S 0 == ARF_BEGARF ]} {emit {PHIGS clear text archive}}
    if {[S 0 == {@(\#)SunPHIGS} ]} {emit SunPHIGS}
    if {[S 0 == GKSM ]} {emit {GKS Metafile}}
    if {[S 0 == BEGMF ]} {emit {clear text Computer Graphics Metafile}}
    if {[N S 0 == 0x20 &0xffe0]} {emit {binary Computer Graphics Metafile}}
    if {[S 0 == yz ]} {emit {MGR bitmap, modern format, 8-bit aligned}}
    if {[S 0 == zz ]} {emit {MGR bitmap, old format, 1-bit deep, 16-bit aligned}}
    if {[S 0 == xz ]} {emit {MGR bitmap, old format, 1-bit deep, 32-bit aligned}}
    if {[S 0 == yx ]} {emit {MGR bitmap, modern format, squeezed}}
    if {[S 0 == {%bitmap\0} ]} {emit {FBM image data}}
    if {[S 1 == {PC\ Research,\ Inc} ]} {emit {group 3 fax data}}
    if {[S 0 == hsi1 ]} {emit image/x-jpeg-proprietary}
    if {[S 0 == BM ]} {emit image/x-bmp}
    if {[S 0 == IC ]} {emit image/x-ico}
    if {[S 0 == PI ]} {emit {PC pointer image data}}
    if {[S 0 == CI ]} {emit {PC color icon data}}
    if {[S 0 == CP ]} {emit {PC color pointer image data}}
    if {[S 0 == {/*\ XPM\ */} ]} {emit {X pixmap image text}}
    if {[S 0 == {Imagefile\ version-} ]} {emit {iff image data}}
    if {[S 0 == IT01 ]} {emit {FIT image data}}
    if {[S 0 == IT02 ]} {emit {FIT image data}}
    if {[S 2048 == PCD_IPI ]} {emit x/x-photo-cd-pack-file}
    if {[S 0 == PCD_OPA ]} {emit x/x-photo-cd-overfiew-file}
    if {[S 0 == {SIMPLE\ \ =} ]} {emit {FITS image data}}
    if {[S 0 == {This\ is\ a\ BitMap\ file} ]} {emit {Lisp Machine bit-array-file}}
    if {[S 0 == !! ]} {emit {Bennet Yee's \"face\" format}}
    if {[S 1536 == {Visio\ (TM)\ Drawing} ]} {emit %s}
    if {[S 0 == {\210OPS} ]} {emit {Interleaf saved data}}
    if {[S 0 == <!OPS ]} {emit {Interleaf document text}}
    if {[S 4 == pgscriptver ]} {emit {IslandWrite document}}
    if {[S 13 == DrawFile ]} {emit {IslandDraw document}}
    if {[N s 0 == 0x9600 &0xFFFC]} {emit {little endian ispell}}
    if {[N S 0 == 0x9600 &0xFFFC]} {emit {big endian ispell}}
    if {[S 0 == KarmaRHD ]} {emit {Version	Karma Data Structure Version}}
    if {[S 0 == lect ]} {emit {DEC SRC Virtual Paper Lectern file}}
    if {[S 53 == yyprevious ]} {emit {C program text \(from lex\)}}
    if {[S 21 == {generated\ by\ flex} ]} {emit {C program text \(from flex\)}}
    if {[S 0 == {%\{} ]} {emit {lex description text}}
    if {[S 0 == {\007\001\000} ]} {emit {Linux/i386 object file}}
    if {[S 0 == {\01\03\020\04} ]} {emit {Linux-8086 impure executable}}
    if {[S 0 == {\01\03\040\04} ]} {emit {Linux-8086 executable}}
    if {[S 0 == {\243\206\001\0} ]} {emit {Linux-8086 object file}}
    if {[S 0 == {\01\03\020\20} ]} {emit {Minix-386 impure executable}}
    if {[S 0 == {\01\03\040\20} ]} {emit {Minix-386 executable}}
    if {[S 0 == *nazgul* ]} {emit {Linux compiled message catalog}}
    if {[N i 216 == 0x111 ]} {emit {Linux/i386 core file}}
    if {[S 2 == LILO ]} {emit {Linux/i386 LILO boot/chain loader}}
    if {[S 0 == 0.9 ]} {emit 300}
    if {[S 4086 == SWAP-SPACE ]} {emit {Linux/i386 swap file}}
    if {[S 514 == HdrS ]} {emit {Linux kernel}}
    if {[S 0 == Begin3 ]} {emit {Linux Software Map entry text}}
    if {[S 0 == {;;} ]} {emit {Lisp/Scheme program text}}
    if {[S 0 == {\012(} ]} {emit {byte-compiled Emacs-Lisp program data}}
    if {[S 0 == {;ELC\023\000\000\000} ]} {emit {byte-compiled Emacs-Lisp program data}}
    if {[S 0 == {(SYSTEM::VERSION\040'} ]} {emit {CLISP byte-compiled Lisp program text}}
    if {[S 11 == {must\ be\ converted\ with\ BinHex} ]} {emit {BinHex binary text}}
    if {[S 0 == SIT! ]} {emit {StuffIt Archive \(data\)}}
    if {[S 65 == SIT! ]} {emit {StuffIt Archive \(rsrc + data\)}}
    if {[S 0 == SITD ]} {emit {StuffIt Deluxe \(data\)}}
    if {[S 65 == SITD ]} {emit {StuffIt Deluxe \(rsrc + data\)}}
    if {[S 0 == Seg ]} {emit {StuffIt Deluxe Segment \(data\)}}
    if {[S 65 == Seg ]} {emit {StuffIt Deluxe Segment \(rsrc + data\)}}
    if {[S 0 == APPL ]} {emit {Macintosh Application \(data\)}}
    if {[S 65 == APPL ]} {emit {Macintosh Application \(rsrc + data\)}}
    if {[S 0 == zsys ]} {emit {Macintosh System File \(data\)}}
    if {[S 65 == zsys ]} {emit {Macintosh System File\(rsrc + data\)}}
    if {[S 0 == FNDR ]} {emit {Macintosh Finder \(data\)}}
    if {[S 65 == FNDR ]} {emit {Macintosh Finder\(rsrc + data\)}}
    if {[S 0 == libr ]} {emit {Macintosh Library \(data\)}}
    if {[S 65 == libr ]} {emit {Macintosh Library\(rsrc + data\)}}
    if {[S 0 == shlb ]} {emit {Macintosh Shared Library \(data\)}}
    if {[S 65 == shlb ]} {emit {Macintosh Shared Library\(rsrc + data\)}}
    if {[S 0 == cdev ]} {emit {Macintosh Control Panel \(data\)}}
    if {[S 65 == cdev ]} {emit {Macintosh Control Panel\(rsrc + data\)}}
    if {[S 0 == INIT ]} {emit {Macintosh Extension \(data\)}}
    if {[S 65 == INIT ]} {emit {Macintosh Extension\(rsrc + data\)}}
    if {[S 0 == FFIL ]} {emit font/ttf}
    if {[S 65 == FFIL ]} {emit font/ttf}
    if {[S 0 == LWFN ]} {emit font/type1}
    if {[S 65 == LWFN ]} {emit font/type1}
    if {[S 0 == PACT ]} {emit {Macintosh Compact Pro Archive \(data\)}}
    if {[S 65 == PACT ]} {emit {Macintosh Compact Pro Archive\(rsrc + data\)}}
    if {[S 0 == ttro ]} {emit {Macintosh TeachText File \(data\)}}
    if {[S 65 == ttro ]} {emit {Macintosh TeachText File\(rsrc + data\)}}
    if {[S 0 == TEXT ]} {emit {Macintosh TeachText File \(data\)}}
    if {[S 65 == TEXT ]} {emit {Macintosh TeachText File\(rsrc + data\)}}
    if {[S 0 == PDF ]} {emit {Macintosh PDF File \(data\)}}
    if {[S 65 == PDF ]} {emit {Macintosh PDF File\(rsrc + data\)}}
    if {[S 0 == {\#\ Magic} ]} {emit {magic text file for file\(1\) cmd}}
    if {[S 0 == Relay-Version: ]} {emit {old news text}}
    if {[S 0 == {\#!\ rnews} ]} {emit {batched news text}}
    if {[S 0 == {N\#!\ rnews} ]} {emit {mailed, batched news text}}
    if {[S 0 == {Forward\ to} ]} {emit {mail forwarding text}}
    if {[S 0 == {Pipe\ to} ]} {emit {mail piping text}}
    if {[S 0 == Return-Path: ]} {emit message/rfc822}
    if {[S 0 == Path: ]} {emit message/news}
    if {[S 0 == Xref: ]} {emit message/news}
    if {[S 0 == From: ]} {emit message/rfc822}
    if {[S 0 == Article ]} {emit message/news}
    if {[S 0 == BABYL ]} {emit message/x-gnu-rmail}
    if {[S 0 == Received: ]} {emit message/rfc822}
    if {[S 0 == MIME-Version: ]} {emit {MIME entity text}}
    if {[S 0 == {Content-Type:\ } ]} {emit 355}
    if {[S 0 == Content-Type: ]} {emit 356}
    if {[S 0 == {\311\304} ]} {emit {ID tags data}}
    if {[S 0 == {\001\001\001\001} ]} {emit {MMDF mailbox}}
    if {[S 4 == Research, ]} {emit Digifax-G3-File}
    if {[S 0 == RMD1 ]} {emit {raw modem data}}
    if {[S 0 == {PVF1\n} ]} {emit {portable voice format}}
    if {[S 0 == {PVF2\n} ]} {emit {portable voice format}}
    if {[S 0 == S0 ]} {emit {Motorola S-Record; binary data in text format}}
    if {[S 0 == {@echo\ off} ]} {emit {MS-DOS batch file text}}
    if {[S 128 == {PE\0\0} ]} {emit {MS Windows PE}}
    if {[S 0 == MZ ]} {emit application/x-ms-dos-executable}
    if {[S 0 == LZ ]} {emit {MS-DOS executable \(built-in\)}}
    if {[S 0 == regf ]} {emit {Windows NT Registry file}}
    if {[S 2080 == {Microsoft\ Word\ 6.0\ Document} ]} {emit text/vnd.ms-word}
    if {[S 2080 == {Documento\ Microsoft\ Word\ 6} ]} {emit text/vnd.ms-word}
    if {[S 2112 == MSWordDoc ]} {emit text/vnd.ms-word}
    if {[S 0 == PO^Q` ]} {emit text/vnd.ms-word}
    if {[S 2080 == {Microsoft\ Excel\ 5.0\ Worksheet} ]} {emit application/vnd.ms-excel}
    if {[S 2114 == Biff5 ]} {emit application/vnd.ms-excel}
    if {[S 1 == WPC ]} {emit text/vnd.wordperfect}
    switch -- [Nv I 0 &0377777777] 8782091 {emit {NetBSD/i386 demand paged}} 8782088 {emit {NetBSD/i386 pure}} 8782087 {emit NetBSD/i386} 8782151 {emit {NetBSD/i386 core}} 8847627 {emit {NetBSD/m68k demand paged}} 8847624 {emit {NetBSD/m68k pure}} 8847623 {emit NetBSD/m68k} 8847687 {emit {NetBSD/m68k core}} 8913163 {emit {NetBSD/m68k4k demand paged}} 8913160 {emit {NetBSD/m68k4k pure}} 8913159 {emit NetBSD/m68k4k} 8913223 {emit {NetBSD/m68k4k core}} 8978699 {emit {NetBSD/ns32532 demand paged}} 8978696 {emit {NetBSD/ns32532 pure}} 8978695 {emit NetBSD/ns32532} 8978759 {emit {NetBSD/ns32532 core}} 9044235 {emit {NetBSD/sparc demand paged}} 9044232 {emit {NetBSD/sparc pure}} 9044231 {emit NetBSD/sparc} 9044295 {emit {NetBSD/sparc core}} 9109771 {emit {NetBSD/pmax demand paged}} 9109768 {emit {NetBSD/pmax pure}} 9109767 {emit NetBSD/pmax} 9109831 {emit {NetBSD/pmax core}} 9175307 {emit {NetBSD/vax demand paged}} 9175304 {emit {NetBSD/vax pure}} 9175303 {emit NetBSD/vax} 9175367 {emit {NetBSD/vax core}} 9240903 {emit {NetBSD/alpha core}} 9306379 {emit {NetBSD/mips demand paged}} 9306376 {emit {NetBSD/mips pure}} 9306375 {emit NetBSD/mips} 9306439 {emit {NetBSD/mips core}} 9371915 {emit {NetBSD/arm32 demand paged}} 9371912 {emit {NetBSD/arm32 pure}} 9371911 {emit NetBSD/arm32} 9371975 {emit {NetBSD/arm32 core}}
    if {[S 0 == StartFontMetrics ]} {emit font/x-sunos-news}
    if {[S 0 == StartFont ]} {emit font/x-sunos-news}
    switch -- [Nv I 8 ] 326773573 {emit font/x-sunos-news} 326773576 {emit font/x-sunos-news}
    if {[S 0 == Octave-1-L ]} {emit {Octave binary data \(little endian\)}}
    if {[S 0 == Octave-1-B ]} {emit {Octave binary data \(big endian\)}}
    if {[S 0 == {\177OLF} ]} {emit OLF}
    if {[S 0 == %PDF- ]} {emit {PDF document}}
    if {[S 0 == {-----BEGIN\040PGP} ]} {emit {PGP armored data}}
    if {[S 0 == {\#\ PaCkAgE\ DaTaStReAm} ]} {emit {pkg Datastream \(SVR4\)}}
    if {[S 0 == %! ]} {emit application/postscript}
    if {[S 0 == {\004%!} ]} {emit application/postscript}
    if {[S 0 == *PPD-Adobe: ]} {emit {PPD file}}
    if {[S 0 == {\033%-12345X@PJL} ]} {emit {HP Printer Job Language data}}
    if {[S 0 == {\033%-12345X@PJL} ]} {emit {HP Printer Job Language data}}
    if {[S 0 == {\033E\033} ]} {emit image/x-pcl-hp}
    if {[S 0 == @document( ]} {emit {Imagen printer}}
    if {[S 0 == Rast ]} {emit {RST-format raster font data}}
    if {[N I 0 == 0x56000000 &0xff00ffff]} {emit {ps database}}
    if {[S 0 == {\{\\rtf} ]} {emit {Rich Text Format data,}}
    if {[S 38 == Spreadsheet ]} {emit {sc spreadsheet file}}
    if {[S 8 == {\001s\ } ]} {emit {SCCS archive data}}
    switch -- [Nv c 0 ] 38 {emit {Sendmail frozen configuration}} -128 {emit {8086 relocatable \(Microsoft\)}}
    if {[S 0 == kbd!map ]} {emit {kbd map file}}
    if {[S 0 == {\x43\x72\x73\x68\x44\x75\x6d\x70} ]} {emit {IRIX vmcore dump of}}
    if {[S 0 == SGIAUDIT ]} {emit {SGI Audit file}}
    if {[S 0 == WNGZWZSC ]} {emit {Wingz compiled script}}
    if {[S 0 == WNGZWZSS ]} {emit {Wingz spreadsheet}}
    if {[S 0 == WNGZWZHP ]} {emit {Wingz help file}}
    if {[S 0 == {\\#Inventor} ]} {emit {V	IRIS Inventor 1.0 file}}
    if {[S 0 == {\\#Inventor} ]} {emit {V2	Open Inventor 2.0 file}}
    if {[S 0 == {glfHeadMagic();} ]} {emit GLF_TEXT}
    switch -- [Nv I 4 ] 1090584576 {emit GLF_BINARY_LSB_FIRST} 321 {emit GLF_BINARY_MSB_FIRST}
    if {[S 0 == {<!DOCTYPE\ HTML} ]} {emit text/html}
    if {[S 0 == {<!doctype\ html} ]} {emit text/html}
    if {[S 0 == <HEAD ]} {emit text/html}
    if {[S 0 == <head ]} {emit text/html}
    if {[S 0 == <TITLE ]} {emit text/html}
    if {[S 0 == <title ]} {emit text/html}
    if {[S 0 == <html ]} {emit text/html}
    if {[S 0 == <HTML ]} {emit text/html}
    if {[S 0 == <!DOCTYPE ]} {emit {exported SGML document text}}
    if {[S 0 == <!doctype ]} {emit {exported SGML document text}}
    if {[S 0 == <!SUBDOC ]} {emit {exported SGML subdocument text}}
    if {[S 0 == <!subdoc ]} {emit {exported SGML subdocument text}}
    if {[S 0 == <!-- ]} {emit {exported SGML document text}}
    if {[S 0 == RTSS ]} {emit {NetMon capture file}}
    if {[S 0 == {TRSNIFF\ data\ \ \ \ \032} ]} {emit {Sniffer capture file}}
    if {[S 0 == {XCP\0} ]} {emit {NetXRay capture file}}
    if {[S 0 == {<!SQ\ DTD>} ]} {emit {Compiled SGML rules file}}
    if {[S 0 == {<!SQ\ A/E>} ]} {emit {A/E SGML Document binary}}
    if {[S 0 == {<!SQ\ STS>} ]} {emit {A/E SGML binary styles file}}
    if {[S 0 == {SQ\ BITMAP1} ]} {emit {SoftQuad Raster Format text}}
    if {[S 0 == {X\ } ]} {emit {SoftQuad troff Context intermediate}}
    switch -- [Nv I 0 &077777777] 196875 {emit {sparc demand paged}} 196872 {emit {sparc pure}} 196871 {emit sparc} 131339 {emit {mc68020 demand paged}} 131336 {emit {mc68020 pure}} 131335 {emit mc68020} 65803 {emit {mc68010 demand paged}} 65800 {emit {mc68010 pure}} 65799 {emit mc68010}
    if {[S 0 == {\#SUNPC_CONFIG} ]} {emit {SunPC 4.0 Properties Values}}
    if {[S 0 == snoop ]} {emit {Snoop capture file}}
    if {[S 36 == acsp ]} {emit {Kodak Color Management System, ICC Profile}}
    if {[S 0 == {\#!teapot\012xdr} ]} {emit {teapot work sheet \(XDR format\)}}
    if {[S 0 == {\032\001} ]} {emit {Compiled terminfo entry}}
    if {[S 0 == {\367\002} ]} {emit {TeX DVI file}}
    if {[S 0 == {\367\203} ]} {emit font/x-tex}
    if {[S 0 == {\367\131} ]} {emit font/x-tex}
    if {[S 0 == {\367\312} ]} {emit font/x-tex}
    if {[S 0 == {This\ is\ TeX,} ]} {emit {TeX transcript text}}
    if {[S 0 == {This\ is\ METAFONT,} ]} {emit {METAFONT transcript text}}
    if {[S 2 == {\000\021} ]} {emit font/x-tex-tfm}
    if {[S 2 == {\000\022} ]} {emit font/x-tex-tfm}
    if {[S 0 == {\\input\ texinfo} ]} {emit {Texinfo source text}}
    if {[S 0 == {This\ is\ Info\ file} ]} {emit {GNU Info text}}
    if {[S 0 == {\\input} ]} {emit {TeX document text}}
    if {[S 0 == {\\section} ]} {emit {LaTeX document text}}
    if {[S 0 == {\\setlength} ]} {emit {LaTeX document text}}
    if {[S 0 == {\\documentstyle} ]} {emit {LaTeX document text}}
    if {[S 0 == {\\chapter} ]} {emit {LaTeX document text}}
    if {[S 0 == {\\documentclass} ]} {emit {LaTeX 2e document text}}
    if {[S 0 == {\\relax} ]} {emit {LaTeX auxiliary file}}
    if {[S 0 == {\\contentsline} ]} {emit {LaTeX  table of contents}}
    if {[S 0 == {\\indexentry} ]} {emit {LaTeX raw index file}}
    if {[S 0 == {\\begin\{theindex\}} ]} {emit {LaTeX sorted index}}
    if {[S 0 == {\\glossaryentry} ]} {emit {LaTeX raw glossary}}
    if {[S 0 == {\\begin\{theglossary\}} ]} {emit {LaTeX sorted glossary}}
    if {[S 0 == {This\ is\ makeindex} ]} {emit {Makeindex log file}}
    if {[S 0 == **TI82** ]} {emit {TI-82 Graphing Calculator}}
    if {[S 0 == **TI83** ]} {emit {TI-83 Graphing Calculator}}
    if {[S 0 == **TI85** ]} {emit {TI-85 Graphing Calculator}}
    if {[S 0 == **TI92** ]} {emit {TI-92 Graphing Calculator}}
    if {[S 0 == **TI80** ]} {emit {TI-80 Graphing Calculator File.}}
    if {[S 0 == **TI81** ]} {emit {TI-81 Graphing Calculator File.}}
    if {[S 0 == TZif ]} {emit {timezone data}}
    if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\0} ]} {emit {old timezone data}}
    if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\2\0} ]} {emit {old timezone data}}
    if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\3\0} ]} {emit {old timezone data}}
    if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\4\0} ]} {emit {old timezone data}}
    if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\5\0} ]} {emit {old timezone data}}
    if {[S 0 == {\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\6\0} ]} {emit {old timezone data}}
    if {[S 0 == {.\\\"} ]} {emit {troff or preprocessor input text}}
    if {[S 0 == {'\\\"} ]} {emit {troff or preprocessor input text}}
    if {[S 0 == {'.\\\"} ]} {emit {troff or preprocessor input text}}
    if {[S 0 == {\\\"} ]} {emit {troff or preprocessor input text}}
    if {[S 0 == {x\ T} ]} {emit {ditroff text}}
    if {[S 0 == {\100\357} ]} {emit {very old \(C/A/T\) troff output data}}
    if {[S 0 == Interpress/Xerox ]} {emit {Xerox InterPress data}}
    if {[S 0 == {begin\040} ]} {emit {uuencoded or xxencoded text}}
    if {[S 0 == {xbtoa\ Begin} ]} {emit {btoa'd text}}
    if {[S 0 == {$\012ship} ]} {emit {ship'd binary text}}
    if {[S 0 == {Decode\ the\ following\ with\ bdeco} ]} {emit {bencoded News text}}
    if {[S 11 == {must\ be\ converted\ with\ BinHex} ]} {emit {BinHex binary text}}
    if {[N S 6 == 0x107 ]} {emit {unicos \(cray\) executable}}
    if {[S 596 == {\130\337\377\377} ]} {emit {Ultrix core file}}
    if {[S 0 == Joy!peffpwpc ]} {emit {header for PowerPC PEF executable}}
    if {[S 0 == LBLSIZE= ]} {emit {VICAR image data}}
    if {[S 43 == SFDU_LABEL ]} {emit {VICAR label file}}
    if {[S 0 == {\xb0\0\x30\0} ]} {emit {VMS VAX executable}}
    if {[S 1 == WPC ]} {emit {\(Corel/WP\)}}
    if {[S 0 == core ]} {emit {core file \(Xenix\)}}
    if {[S 0 == {ZyXEL\002} ]} {emit {ZyXEL voice data}}

    result

    return {}
}

## -- ** END GENERATED CODE ** --
## -- Do not edit before this line !
##

# ### ### ### ######### ######### #########
## Ready for use.
# EOF
