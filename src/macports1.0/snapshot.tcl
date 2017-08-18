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
        #           registry::snapshot
        #
        # TODO:
        # use registry::write wrapper here itself
        # make it return some value

        puts "here 1-1"

        puts "Still being developed"

        set snapshot [registry::snapshot create "test snapshot"]

        return $snapshot
    }

    proc all_snapshots {opts} {
        # List the snapshots
        puts "listing"

    }

    proc latest_snapshot {opts} {
        # Get the latest snapshot
        return [registry::entry get_snapshot]
    }
}