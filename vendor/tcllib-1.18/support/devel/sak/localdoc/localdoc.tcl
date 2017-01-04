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
    global excluded modules apps guide
    source support/installation/modules.tcl

    lappend baseconfig -module tcllib
    foreach e $excluded {
	puts "Excluding $e ..."
	lappend baseconfig -exclude */modules/$e/*
    }

    set nav ../../../../home

    puts "Reindex the documentation..."
    sak::doc::imake __dummy__
    sak::doc::index __dummy__

    puts "Removing old documentation..."
    # but keep the main index around, manually created, edited, not to be touched
    # TODO: catch errors and restore automatically
    file rename embedded/index.html e_index.html
    
    file delete -force embedded
    file mkdir embedded/www

    # Put the saved main page back into place, early.
    file rename e_index.html embedded/index.html

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

    puts "Generating HTML (online)... Pass 1, draft..."
    set     config $baseconfig
    lappend config -exclude  {*/doctools/tests/*} 
    lappend config -exclude  {*/support/*} 
    lappend config -toc      $toc
    lappend config -post+toc Categories    $cats 
    lappend config -post+toc Modules       $mods 
    lappend config -post+toc Applications  $apps 
    lappend config -merge 
    lappend config -raw 
    lappend config -o embedded/www
    lappend config -header support/fossil-nav-integration.html
    lappend config html .

    dtplite::do $config

    puts "Generating HTML (online)... Pass 2, resolving cross-references..."
    dtplite::do $config
    return
}

# ### ### ### ######### ######### #########

package provide sak::localdoc 1.0

##
# ###
