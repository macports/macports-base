# -*- tcl -*-
# Engine to convert a doctoc document into markdown formatted text
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.
#
######################################################################

dt_source _toc_common.tcl
dt_source _text.tcl
dt_source _markdown.tcl

######################################################################
# Conversion specification.
# One-pass processing.

rename toc_postprocess {}
rename text_postprocess toc_postprocess

proc fmt_plain_text {text} {return {}}

################################################################
## Backend for Markdown markup

proc fmt_toc_begin {label title} {
    MDCInit
    set title "$label -- $title"
    
    TextInitialize

    MDComment "Table of contents [Provenance]"
    MDCDone

    SectTitle hdr $title
    Text [Compose hdr]    
    CloseParagraph [Verbatim]

    ListOpen
    return
}

proc fmt_toc_end {} { return }

proc fmt_division_start {title symfile} {

    Text [ALink $symfile $title]
    CloseParagraph [Verbatim]

    ListOpen
}

proc fmt_division_end  {} {
    ContextPop ;# Ref (a)
    return
}

proc fmt_item {file label desc} {
    Text "[ALink $file $label] $desc"
    CloseParagraph [Verbatim]
    return
}

proc fmt_comment {text} { return }

proc ListOpen {} {
    ContextPush ;# Ref (a)
    ContextNew Division {
	# Indenting is done by replicating the outer ws-prefix.
	set bullet "[WPrefix?]  [IBullet]"
	List! bullet $bullet "[BlankM $bullet] "
    }
    return
}

################################################################
