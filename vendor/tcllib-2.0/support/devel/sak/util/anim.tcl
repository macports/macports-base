# -*- tcl -*-
# (C) 2006-2013 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

namespace eval ::sak::animate {
    # EL (Erase Line)
    #    Sequence: ESC [ n K
    # ** Effect: if n is 0 or missing, clear from cursor to end of line
    #    Effect: if n is 1, clear from beginning of line to cursor
    #    Effect: if n is 2, clear entire line

    variable eeol \033\[K
}

# ###

proc ::sak::animate::init {} {
    variable prefix
    variable n      0
    variable max    [llength $prefix]
}

proc ::sak::animate::next {string} {
    variable prefix
    variable n
    variable max
    variable eeol

    puts -nonewline stdout \r\[[lindex $prefix $n]\]\ $string$eeol
    flush           stdout

    incr n ; if {$n >= $max} {set n 0}
    return
}

proc ::sak::animate::last {string} {
    variable clear

    puts  stdout \r\[$clear\]\ $string
    flush stdout
    return
}

# ###

namespace eval ::sak::animate {
    namespace export init next last

    variable  prefix {
	{*   }	{*   }	{*   }	{*   }	{*   }
	{ *  }	{ *  }	{ *  }	{ *  }	{ *  }
	{  * }	{  * }	{  * }	{  * }	{  * }
	{   *}	{   *}	{   *}	{   *}	{   *}
	{  * }	{  * }	{  * }	{  * }	{  * }
	{ *  }	{ *  }	{ *  }	{ *  }	{ *  }
    }
    variable clear {    }
}

##
# ###

package provide sak::animate 1.0
