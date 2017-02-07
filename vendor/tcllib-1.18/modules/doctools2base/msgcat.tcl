# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# L10N, I18N

# Support package. Handling of message catalogs within the various
# doctools document processing packages. Contrary to the regular
# msgcat package here message catalogs are equated with packages. This
# makes their use easier, as the user does not have to know the
# location of the message catalogs. Locating a desired catalog is
# handled through Tcl's regular package management.

# To this end this package provides a command analogous to
# 'msgcat::load', just replacing direct file access with package
# loading. This is 'doctools::msgcat::init'.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.4 ; # Required Core
package require msgcat  ; # Fondation catalog database

namespace eval ::doctools::msgcat {}

# # ## ### ##### ######## ############# #####################
## Overide catalog unknown handler to report missing strings
## as fatal problem. DEBUG only.

if 0 {
    proc ::msgcat::mcunknown {locale code} {
	return "unknown error code \"$code\" (for locale $locale)"
    }
}

# # ## ### ##### ######## ############# #####################
## Public API

proc ::doctools::msgcat::init {prefix} {
    set matches 0
    foreach p [msgcat::mcpreferences] {
	set pkg doctools::msgcat::${prefix}::${p}
	if {![catch {
	    package require $pkg
	}]} {
	    incr matches
	}
    }
    return $matches
}

# # ## ### ##### ######## ############# #####################
## Ready

namespace eval ::doctools::msgcat {
    namespace export init
}

package provide doctools::msgcat 0.1
return
