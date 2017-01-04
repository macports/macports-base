# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / (Un)quoting characters.

# ### ### ### ######### ######### #########
## Requisites

namespace eval ::page::util::quote {
    namespace export unquote \
	    quote'tcl quote'tclstr quote'tclcom
}

# ### ### ### ######### ######### #########
## API

proc ::page::util::quote::unquote {ch} {
    # A character, as stored in the grammar tree
    # by the frontend is transformed into a proper
    # Tcl character (internal representation).

    switch -exact -- $ch {
	"\\n"  {return \n}
	"\\t"  {return \t}
	"\\r"  {return \r}
	"\\["  {return \[}
	"\\]"  {return \]}
	"\\'"  {return '}
	"\\\"" {return "\""}
	"\\\\" {return \\}
    }

    if {[regexp {^\\([0-2][0-7][0-7])$} $ch -> ocode]} {
	return [format %c $ocode]
    } elseif {[regexp {^\\([0-7][0-7]?)$} $ch -> ocode]} {
	return [format %c 0$ocode]
    } elseif {[regexp {^\\u([0-9a-fA-F][0-9a-fA-F]?[0-9a-fA-F]?[0-9a-fA-F]?)$} $ch -> hcode]} {
	return [format %c 0x$hcode]
    }

    return $ch
}

proc ::page::util::quote::quote'tcl {ch} {
    # Converts a Tcl character (internal representation)
    # into a string which is accepted by the Tcl parser,
    # will regenerate the character in question and is
    # 7bit ASCII. 'quoted' is a boolean flag and set if
    # the returned representation is a \-quoted form.
    # Because they have to be treated specially when
    # creating a list containing the reperesentation.

    # Special characters

    switch -exact -- $ch {
	"\n" {return "\\n"}
	"\r" {return "\\r"}
	"\t" {return "\\t"}
	"\\" - "\;" -
	" "  - "\"" -
	"("  - ")"  -
	"\{" - "\}" -
	"\[" - "\]" {
	    # Quote space and all the brackets as well, using octal,
	    # for easy impure list-ness.

	    scan $ch %c chcode
	    return \\[format %o $chcode]
	}
    }

    scan $ch %c chcode

    # Control characters: Octal
    if {[string is control -strict $ch]} {
	return \\[format %o $chcode]
    }

    # Beyond 7-bit ASCII: Unicode

    if {$chcode > 127} {
	return \\u[format %04x $chcode]
    }

    # Regular character: Is its own representation.

    return $ch
}

proc ::page::util::quote::quote'tclstr {ch} {
    # Converts a Tcl character (internal representation)
    # into a string which is accepted by the Tcl parser and will
    # generate a human readable representation of the character in
    # question, one which when puts to a channel describes the
    # character without using any unprintable characters. It may use
    # \-quoting. High utf characters are quoted to avoid problem with
    # the still prevalent ascii terminals. It is assumed that the
    # string will be used in a ""-quoted environment.

    # Special characters

    switch -exact -- $ch {
	" "  {return "<blank>"}
	"\n" {return "\\\\n"}
	"\r" {return "\\\\r"}
	"\t" {return "\\\\t"}
	"\"" - "\\" - "\;" -
	"("  - ")"  -
	"\{" - "\}" -
	"\[" - "\]" {
	    return \\$ch
	}
    }

    scan $ch %c chcode

    # Control characters: Octal
    if {[string is control -strict $ch]} {
	return \\\\[format %o $chcode]
    }

    # Beyond 7-bit ASCII: Unicode

    if {$chcode > 127} {
	return \\\\u[format %04x $chcode]
    }

    # Regular character: Is its own representation.

    return $ch
}

proc ::page::util::quote::quote'tclcom {ch} {
    # Converts a Tcl character (internal representation)
    # into a string which is accepted by the Tcl parser when used
    # within a Tcl comment.

    # Special characters

    switch -exact -- $ch {
	" "  {return "<blank>"}
	"\n" {return "\\n"}
	"\r" {return "\\r"}
	"\t" {return "\\t"}
	"\"" -
	"\{" - "\}" -
	"("  - ")"  {
	    return \\$ch
	}
    }

    scan $ch %c chcode

    # Control characters: Octal
    if {[string is control -strict $ch]} {
	return \\[format %o $chcode]
    }

    # Beyond 7-bit ASCII: Unicode

    if {$chcode > 127} {
	return \\u[format %04x $chcode]
    }

    # Regular character: Is its own representation.

    return $ch
}

# ### ### ### ######### ######### #########
## Ready

package provide page::util::quote 0.1
