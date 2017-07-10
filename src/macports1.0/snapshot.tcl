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
        #
        # TODO: use registry::write wrapper here itself
        #

        puts "Still being developed"
        #registry::entry addsnapshot
        foreach port [registry::entry imaged] {
            puts [$port name]
        }
        puts
        set ilist [registry::installed]

        # set vimlist [registry::installed vim]

        # foreach port $vimlist {
        #     puts $port
        # }

        foreach port $ilist {
            puts $port
        }
        puts
        set a [registry::entry snapshot "test snapshot"]
        puts $a
        puts done

	}

    proc list {opts} {
        # List the snapshots
        puts "listing"

    }

    proc latest {opts} {
        # Get the latest snapshot
        puts "latest"
    }
}