# -*- tcl -*-
# (C) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

namespace eval ::sak::test {}

# ###

proc ::sak::test::usage {args} {
    package require sak::help
    puts stdout [join $args { }]\n[sak::help::on test]
    exit 1
}

##
# ###

package provide sak::test 1.0
