# -*- tcl -*-
# (C) 2008 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

namespace eval ::sak::validate {}

# ###

proc ::sak::validate::usage {args} {
    package require sak::help
    puts stdout [join $args { }]\n[sak::help::on validate]
    exit 1
}

proc ::sak::validate::all {modules mode stem tclv} {
    package require sak::validate::versions
    package require sak::validate::manpages
    package require sak::validate::testsuites
    package require sak::validate::syntax

    sak::validate::versions::run   $modules $mode $stem $tclv
    sak::validate::manpages::run   $modules $mode $stem $tclv
    sak::validate::testsuites::run $modules $mode $stem $tclv
    sak::validate::syntax::run     $modules $mode $stem $tclv

    sak::validate::versions::summary
    sak::validate::manpages::summary
    sak::validate::testsuites::summary
    sak::validate::syntax::summary
    return
}

##
# ###

package provide sak::validate 1.0
