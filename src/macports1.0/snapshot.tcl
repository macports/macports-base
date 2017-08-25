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
        #           opts - The options passed in.
        # Returns:
        #           registry::snapshot
        #
        # TODO:
        # 1. use registry::write wrapper here itself


        puts "here 1-1"

        puts "Still being developed"

        array set options $opts

        # An option used by user while creating snapshot manually
        # to identify a snapshot, usually followed by `port restore`
        if {[info exists options(ports_snapshot_note)]} {
            set note ports_snapshot_note
        } else {
            set note "snapshot created for migration"
        }

        set snapshot [registry::snapshot create $note]

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