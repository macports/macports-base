# -*- tcl -*- $Id: config_peg.tcl,v 1.2 2005/09/28 06:16:38 andreas_kupries Exp $

package provide page::config::peg 0.1

proc page_cdefinition {} {
    return {
	--reset
	--append
	--reader    peg
	--transform reachable
	--transform realizable
	--writer    me
    }
}
