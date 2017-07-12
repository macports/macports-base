# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# restore.tcl
#
# TODO: include MacPorts copyright
#


package provide restore 1.0

package require macports 1.0
package require registry 1.0

namespace eval restore {
	
	proc main {opts} {
		# The main function. Calls each individual function that needs to be run.
        #
        # Args:
        #           opts - options array.
        # Returns:
        #           None
        #
        # TODO: 
        # make it return some value

        array set options $opts

        if ([info exists options(ports_restore_snapshot-id)]) {
        	# use that snapshot
        } else {
        	# TODO: ask if the user is fine with the latest snapshot, if 'yes'
        	# use latest snapshot
        }

	}
}