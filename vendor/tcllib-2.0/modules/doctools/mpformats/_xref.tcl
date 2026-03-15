# -*- tcl -*-
##
# Shared code for the management of cross-references between
# documents. Origin in HTML. Other user: Markdown.
#
# Copyright (c) 2001,2019 Andreas Kupries <andreas_kupries@sourceforge.net>

# Hook:
# - MakeLink {label target} - Format specific
# - GetXref                 - Engine parameter access

# # ## ### ##### ######## ############# #####################
## API

proc XrefInit {} {
    global xref
    foreach item [GetXref] {
	foreach {pattern fname fragment} $item break
	set fname_ref [dt_fmap $fname]
	if {$fragment != {}} {append fname_ref #$fragment}
	set xref($pattern) $fname_ref
    }
    proc XrefInit {} {}
    return
}

proc XrefMatch {word args} {
    global xref

    foreach ext $args {
	if {$ext != {}} {
	    if {[info exists xref($ext,$word)]} {
		return [XrefLink $xref($ext,$word) $word]
	    }
	}
    }
    if {[info exists xref($word)]} {
	return [XrefLink $xref($word) $word]
    }

    # Convert the word to all-lower case and then try again.

    set lword [string tolower $word]

    foreach ext $args {
	if {$ext != {}} {
	    if {[info exists xref($ext,$lword)]} {
		return [XrefLink $xref($ext,$lword) $word]
	    }
	}
    }
    if {[info exists xref($lword)]} {
	return [XrefLink $xref($lword) $word]
    }

    return $word
}

proc XrefList {list {ext {}}} {
    set res [list]
    foreach w $list {lappend res [XrefMatch $w $ext]}
    return $res
}

proc XrefLink {dest label} {
    # Ensure that the link is properly done relative to this file!

    set here [LinkHere]
    set dest [LinkTo $dest $here]

    if {[string equal $dest [lindex [file split $here] end]]} {
	# Suppress self-referential links, i.e. links made from the
	# current file to itself. Note that links to specific parts of
	# the current file are not suppressed, only exact links.
	return $label
    }
    return [MakeLink $label $dest]
}

# # ## ### ##### ######## ############# #####################
## Internals

proc LinkHere {} {
    return [dt_fmap [dt_mainfile]]
}

proc LinkTo {dest here} {
    # Ensure that the link is properly done relative to this file!

    set save $dest

    #puts_stderr "XrefLink $dest $label"

    set here [file split $here]
    set dest [file split $dest]

    #puts_stderr "XrefLink < $here"
    #puts_stderr "XrefLink > $dest"

    while {[string equal [lindex $dest 0] [lindex $here 0]]} {
	set dest [lrange $dest 1 end]
	set here [lrange $here 1 end]
	if {[llength $dest] == 0} {break}
    }
    set ul [llength $dest]
    set hl [llength $here]

    if {$ul == 0} {
	set dest [lindex [file split $save] end]
    } else {
	while {$hl > 1} {
	    set dest [linsert $dest 0 ..]
	    incr hl -1
	}
	set dest [eval file join $dest]
    }

    #puts_stderr "XrefLink --> $dest"
    return $dest
}

# # ## ### ##### ######## ############# #####################
## State

global xref ; array set xref {}

##
# # ## ### ##### ######## ############# #####################
return
