# -*- tcl -*-
# (C) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

namespace eval ::sak::help {}

# ###

proc ::sak::help::print {text} {
    global critcldefault
    puts stdout [string map \
	    [list @@ $critcldefault] $text]
    return
}

proc ::sak::help::on {topic} {
    variable base

    # Look for static text and dynamic, i.e. generated help.
    # Static is prefered.

    set ht [file join $base $topic help.txt]
    if {[file exists $ht]} {
	return [get_input $ht]
    }

    set ht [file join $base $topic help.tcl]
    if {[file exists $ht]} {
	source $ht
	return [sak::help::on::$topic]
    }

    set    help ""
    append help \n
    append help "    The topic \"$topic\" is not known." \n
    append help "    The known topics are:" \n\n

    append help [topics]

    return $help
}

proc ::sak::help::alltopics {} {
    # Locate the quick-help for all topics and combine it with a
    # general header.

    set    help "\n"
    append help "    SAK - Swiss Army Knife\n\n"
    append help "    sak is a tool to ease the work"
    append help " of developers and release managers. Try:\n\n"
    append help [topics]

    return $help
}

proc ::sak::help::topics {} {
    variable base
    set help ""
    foreach f [lsort [glob -nocomplain -directory $base */topic.txt]] {
	append help \tsak\ help\ [get_input $f]
    }
    return $help
}

# ###

namespace eval ::sak::help {
    variable base [file join $::distribution support devel sak]
}

##
# ###

package provide sak::help 1.0
