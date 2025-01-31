# -*- tcl -*-
# Engine to convert a docidx document into markdown text.
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.
#
######################################################################

dt_source _idx_common.tcl
dt_source _text.tcl
dt_source _markdown.tcl

proc c_copyrightsymbol {} {return "(c)"}

######################################################################
# Conversion specification.
# One-pass processing.

rename idx_postprocess {}
rename text_postprocess idx_postprocess
proc   fmt_plain_text {text} {return {}}

################################################################
## Backend for plain text markup

proc fmt_index_begin {label title} {
    MDCInit
    if {($label != {}) && ($title != {})} {
	set title "$label -- $title"
    } elseif {$label != {}} {
	set title $label
    } elseif {$title != {}} {
	 # title is set
    }

    TextInitialize

    MDComment "Index [Provenance]"
    MDCDone

    SectTitle hdr $title
    Text [Compose hdr]
    CloseParagraph [Verbatim]
    return
}

proc fmt_index_end {} {
    LoadKwid
    NavBar
    Keys
    return
    
    set rmargin [RMargin $max]

    incr max
    set blank [Blank $max] ;# indent

    foreach key [lsort [array names map]] {
	set keys [join $map($key) ", "]
	Text [InFlow $keys $rmargin [ReHead $blank $key] $blank]
	CloseParagraph [Verbatim]
    }
    return
}

proc fmt_key {text} {
    global key lk ch
    set lk $text
    set key($lk) {}
    set ch([F $lk]) .
    return
}

proc fmt_manpage {f l} {Ref [dt_fmap $f] $l}
proc fmt_url     {u l} {Ref $u           $l}
proc fmt_comment {text}       {return}

# ### ### ### ######### ######### #########

proc NavBar {} {
    global ch dot
    if {![array size ch]} return
    
    set nav {}
    foreach c [lsort -dict [array names ch]] {
	set ref c[F $c]
	set ch($c) $ref
	lappend nav [ALink [Hash]$ref $c]
    }

    Separator
    
    Text [join $nav $dot]
    CloseParagraph [Verbatim]

    Separator
    return
}

proc Keys {} {
    global key
    set lc {}
    set kwlist {}

    # For a good display we sort keywords in dictionary order.
    # We ignore their leading non-alphanumeric characters.
    set kwlist {}
    foreach kw [array names key] {
       set kwx [string trim [regsub -all {^[^a-zA-Z0-9]+} $kw {}]]
       lappend kwlist [list $kwx $kw]
    }
    foreach item [lsort -index 0 -dict $kwlist] {
       foreach {_ k} $item break
	set c [F $k]
	if {$lc != $c} {
	    CloseParagraph [Verbatim]
	    Section $c ; set lc $c
	}
	BeginKey   $k
	References $k
	EndKey
    }

    CloseParagraph [Verbatim]
    return

}

proc Section {c} {
    global ch
    Text "[Hash][Hash][Hash][Hash] [SetAnchor "Keywords: $c" $ch($c)]"
    CloseParagraph [Verbatim]

    Text "[VBar][VBar][VBar]\n"
    Text "[VBar][Dash][Dash][Dash][VBar][Dash][Dash][Dash][VBar]\n"
    return
}

proc BeginKey {k} {
    Text "[VBar][SetAnchor $k][VBar]"
}

proc References {k} {
    global key dot
    set refs {}
    foreach {ref label} $key($k) {
	lappend refs [ALink $ref $label]
    }
    Text [join $refs $dot]
    return
}

proc EndKey {} {
    Text "[VBar]\n"
}

proc Separator {} {
    Text [Dash][Dash][Dash][Dash]
    CloseParagraph [Verbatim]
}

# ### ### ### ######### ######### #########
## Engine state

proc LoadKwid {} {
    global kwid
    # Engine parameter - load predefined keyword anchors.
    set             ki [Get kwid]
    if {![llength  $ki]} return
    array set kwid $ki
    return
}

proc Ref {r l} {
    global  key  lk
    lappend key($lk) $r $l
    return
}

proc F {text} {
    # Keep only alphanumeric, take first, uppercase
    # Returns nothing if input has no alphanumeric characters.
    return [string toupper [string index [regsub -all {[^a-zA-Z0-9]} $text {}] 0]]
}

# key  : string -> dict(ref -> label) "key formatting"
# ch   : string -> '.'                "key starting characters"
# lk   : string                       "last key"
# kwid : string -> ...
# even : bool

global key  ; array set key  {}
global ch   ; array set ch   {}
global lk   ; set       lk   {}
global la   ; set       la   {}
global ti   ; set       ti   {}
global kwid ; array set kwid {}
global dot  ; set dot   " &[Hash]183; "

# ### ### ### ######### ######### #########
## Engine parameters

global    __var
array set __var {
    kwid {}
}
proc Get               {varname}      {global __var ; return $__var($varname)}
proc idx_listvariables {}             {global __var ; return [array names __var]}
proc idx_varset        {varname text} {
    global __var
    if {![info exists __var($varname)]} {
	return -code error "Unknown engine variable \"$varname\""
    }
    set __var($varname) $text
    return
}

##
# ### ### ### ######### ######### #########
