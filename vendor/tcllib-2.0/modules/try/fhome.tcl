# # ## ### ##### ######## ############# ####################
## -*- tcl -*-
## (C) 2024 Andreas Kupries

# The code here is a forward-compatibility implementation of Tcl 9's
# `file home`, for Tcl 8.x.

# # ## ### ##### ######## ############# ####################

package provide file::home 1
package require Tcl 8 9

# Do nothing if the "tcl::file::home" command exists already (9 and higher).
if {[llength [info commands ::tcl::file::home]]} return

# Tcl 8 forward compatibility implementations
#
# It is not fully compatible.
#
# `file home` does not throw an error when trying
# to get the home directory of an unknown user as
# the Tcl 9 implementation does.

namespace eval ::tcl       {}
namespace eval ::tcl::file {}

proc ::tcl::file::home {{user {}}} {
    if {$user eq {}} {
	return ~
    } else {
	# This should check if the user exists
	return ~$user
    }
}

proc ::tcl::file::tildeexpand {path} {
    # 8.x does not have to actually expand anything here
    # This should check if the user exists
    return $path
}

if {[namespace ensemble exists ::file]} {
    apply {{} {
	set fec [namespace ensemble configure ::file -map]
	dict set fec home        ::tcl::file::home
	dict set fec tildeexpand ::tcl::file::tildeexpand
	namespace ensemble configure ::file -map $fec
	unset fec
    }}
} else {
    rename ::file ::orig_file
    proc ::file {m args} {
	if {$m eq "home"} {
	    eval [linsert $args 0 ::tcl::file::home]
	} elseif {$m eq "tildeexpand"} {
	    eval [linsert $args 0 ::tcl::file::tildeexpand]
	} else {
	    eval [linsert $args 0 ::orig_file $m]
	}
    }
}

return
