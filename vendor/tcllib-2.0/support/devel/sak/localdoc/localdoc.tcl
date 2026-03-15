# -*- tcl -*-
# sak::doc - Documentation facilities

package require sak::util
package require sak::doc

namespace eval ::sak::localdoc {}

# ###
# API commands

## ### ### ### ######### ######### #########

proc ::sak::localdoc::usage {} {
    package require sak::help
    puts stdout \n[sak::help::on localdoc]
    exit 1
}

proc ::sak::localdoc::run {} {
    getpackage cmdline          cmdline/cmdline.tcl
    getpackage fileutil         fileutil/fileutil.tcl
    getpackage textutil::repeat textutil/repeat.tcl
    getpackage doctools         doctools/doctools.tcl
    getpackage doctools::toc    doctools/doctoc.tcl
    getpackage doctools::idx    doctools/docidx.tcl
    getpackage dtplite          dtplite/dtplite.tcl

    # Read installation information. Need the list of excluded
    # modules to suppress them here in the doc generation as well.
    global excluded modules apps guide distribution
    set distribution [pwd]
    source support/installation/modules.tcl

    lappend baseconfig -module tcllib
    foreach e $excluded {
	puts "Excluding $e ..."
	lappend baseconfig -exclude */modules/$e/*
    }

    set nav ../../../../home

    puts "Reindex the documentation..."
    sak::doc::imake __dummy__ $excluded
    sak::doc::index __dummy__ $excluded

    puts "Removing old documentation..."
    # Keep the manually created pages around, not to be touched
    # TODO: catch errors and restore automatically
    file rename embedded/index.md e_index.md
    file rename embedded/head.md  e_head.md

    file delete -force embedded
    file mkdir         embedded/md

    # Put the saved pages back into place, early.
    file rename e_index.md embedded/index.md
    file rename e_head.md  embedded/head.md

    run-idoc-man $baseconfig

    # Note: Might be better to run them separately.
    # Note @: Or we shuffle the results a bit more in the post processing stage.

    set map  {
	.man     .html
	modules/ tcllib/files/modules/
	apps/    tcllib/files/apps/
    }

    set toc  [string map $map [fileutil::cat support/devel/sak/doc/toc.txt]]
    set apps [string map $map [fileutil::cat support/devel/sak/doc/toc_apps.txt]]
    set mods [string map $map [fileutil::cat support/devel/sak/doc/toc_mods.txt]]
    set cats [string map $map [fileutil::cat support/devel/sak/doc/toc_cats.txt]]

    run-idoc-www $baseconfig $toc $nav $cats $mods $apps

    set map  {
	.man     .md
	modules/ tcllib/files/modules/
	apps/    tcllib/files/apps/
    }

    set toc  [string map $map [fileutil::cat support/devel/sak/doc/toc.txt]]
    set apps [string map $map [fileutil::cat support/devel/sak/doc/toc_apps.txt]]
    set mods [string map $map [fileutil::cat support/devel/sak/doc/toc_mods.txt]]
    set cats [string map $map [fileutil::cat support/devel/sak/doc/toc_cats.txt]]

    run-embedded $baseconfig $toc $cats $mods $apps
    return
}

proc ::sak::localdoc::run-idoc-man {baseconfig} {
    file delete -force idoc
    file mkdir idoc/man
    file mkdir idoc/www

    puts "Generating manpages (installation)..."
    set     config $baseconfig
    lappend config -exclude {*/doctools/tests/*}
    lappend config -exclude {*/support/*}
    lappend config -ext n
    lappend config -o idoc/man
    lappend config nroff .

    dtplite::do $config
    return
}

proc ::sak::localdoc::run-idoc-www {baseconfig toc nav cats mods apps} {
    puts "Generating HTML (installation)... Pass 1, draft..."
    set     config $baseconfig
    lappend config -exclude  {*/doctools/tests/*}
    lappend config -exclude  {*/support/*}
    lappend config -toc      $toc
    lappend config -nav      {Tcllib Home} $nav
    lappend config -post+toc Categories    $cats
    lappend config -post+toc Modules       $mods
    lappend config -post+toc Applications  $apps
    lappend config -merge
    lappend config -o idoc/www
    lappend config html .

    dtplite::do $config

    puts "Generating HTML (installation)... Pass 2, resolving cross-references..."
    dtplite::do $config
    return
}

proc ::sak::localdoc::run-embedded {baseconfig toc cats mods apps} {
    puts "Generating Markdown (online)... Pass 1, draft..."
    set     config $baseconfig
    lappend config -exclude  {*/doctools/tests/*}
    lappend config -exclude  {*/support/*}
    lappend config -ext md ;# must be known before nav options
    lappend config -toc      $toc
    lappend config -post+toc Categories    $cats
    lappend config -post+toc Modules       $mods
    lappend config -post+toc Applications  $apps
    lappend config -merge
    lappend config -o embedded/md
    lappend config markdown .

    dtplite::do $config

    puts "Generating Markdown (online)... Pass 2, resolving cross-references..."
    dtplite::do $config
    return
}

# ### ### ### ######### ######### #########

package provide sak::localdoc 1.0

##
# ###
