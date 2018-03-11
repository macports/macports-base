# pkgIndex.tcl                                                -*- tcl -*-
# Copyright (C) 2005 Pat Thoyts <patthoyts@users.sourceforge.net>
# $Id: pkgIndex.tcl,v 1.11 2008/01/29 00:51:39 patthoyts Exp $
if {![package vsatisfies [package provide Tcl] 8.2]} {
    # PRAGMA: returnok
    return
}
package ifneeded SASL               1.3.3 [list source [file join $dir sasl.tcl]]
package ifneeded SASL::NTLM         1.1.2 [list source [file join $dir ntlm.tcl]]
package ifneeded SASL::XGoogleToken 1.0.1 [list source [file join $dir gtoken.tcl]]
package ifneeded SASL::SCRAM        0.1   [list source [file join $dir scram.tcl]]
