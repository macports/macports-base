# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Backend - Dump (A)ST for inspection.

# ### ### ### ######### ######### #########
## Requisites

package require page::util::quote

namespace eval ::page::gen::tree::text {
    # Get the peg char de/encoder commands.
    # (unquote, quote'tcl)

    namespace import ::page::util::quote::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::gen::tree::text {t chan} {
    set indent ""
    set bystr  "  "
    set bysiz  [string length $bystr]
    set byoff  end-$bysiz

    $t walk root -order both -type dfs {a n} {
	if {$a eq "enter"} {
	    text::WriteNode $indent $chan $t $n
	    append indent $bystr
	} else {
	    set indent [string range $indent 0 $byoff]
	}
    }
    return
}

# ### ### ### ######### ######### #########
## Internal. Helpers

proc ::page::gen::tree::text::WriteNode {indent chan t n} {
    array set attr [$t getall $n]

    if {[array size attr] == 0} {
	puts $chan "$indent$n <>"
    } else {
	puts -nonewline $chan "$indent$n < "

	set max -1
	set d {}
	foreach k [array names attr] {
	    set l [string length $k]
	    if {$l > $max} {set max $l}
	    lappend d [list $k [Quote $attr($k)] $l]
	}

	if {[llength $d] == 1} {
	    puts $chan "$k = $attr($k) >"
	    return
	}

	set first 1
	set space $indent[string repeat " " [string length "$n < "]]

	foreach e [lsort -dict -index 0 $d] {
	    foreach {k v l} $e break
	    set off [string repeat " " [expr {$max-$l}]]

	    if {$first} {
		puts -nonewline $chan "$k$off = $v"
		set first 0
	    } else {
		puts -nonewline $chan "\n$space$k$off = $v"
	    }
	}

	puts $chan " >"
    }
}

proc ::page::gen::tree::text::Quote {str} {
    return $str

    set res ""
    foreach c [split $str {}] {
	append res [quote'tcl $c]
    }
    return $res
}

# ### ### ### ######### ######### #########
## Ready

package provide page::gen::tree::text 0.1
