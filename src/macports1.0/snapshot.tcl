# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# snapshot.tcl
#
# TODO: include MacPorts copyright
#


package provide snapshot 1.0

package require macports 1.0
package require registry 1.0

namespace eval snapshot {

	proc main {opts} {
		# The main function. Handles all the calls to the correct functions.
        #
        # Args:
        #           opts - The options passed in. Currently, there is no option available.
        # Returns:
        #           None
        puts "Still being developed"
        #registry::entry addsnapshot
        foreach port [registry::entry imaged] {
            puts [$port name]
        }

        registry::entry testcall
        set a [registry::entry snapshot "testsnapshot"]
        puts $a
        puts done

	}
}