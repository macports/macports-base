# -*- tcl -*-
# sak::doc - Documentation facilities

package require sak::util
package require sak::doc::auto

namespace eval ::sak::doc {}

# ###
# API commands

## ### ### ### ######### ######### #########

proc ::sak::doc::index {modules} {
    # The argument (= set of modules) is irrelevant to this command.
    global base

    # First locate all manpages in the CVS workspace.
    set manpages [auto::findManpages $base]
    auto::saveManpages $manpages

    # Then scan the found pages and extract the information needed for
    # keyword index and table of contents.
    array set meta [auto::scanManpages $manpages]

    # Sort through the extracted data.
    array set kwic  {} ; # map: keyword  -> list (file...)
    array set title {} ; # map: file     -> description
    array set cat   {} ; # map: category -> list (file...)
    array set name  {} ; # map: file     -> label
    set       apps  {} ; # list (file...) 
    array set mods  {} ; # map: module   -> list(file...)

    foreach page [array names meta] {
	unset -nocomplain m
	array set m $meta($page)

	# Collect keywords and file mapping for index.
	foreach kw $m(keywords) {
	    lappend kwic($kw) $page
	}
	# Get page title, relevant for display order
	if {$m(desc) eq ""} {
	    set m(desc) $m(shortdesc)
	}
	set title($page) $m(desc)
	# Get page name/title, relevant for display order.
	set name($page) $m(title)
	# Get page category, for sectioning and display order in the
	# table of contents
	if {$m(category) ne ""} {
	    set c $m(category)
	} else {
	    set c Unfiled
	}
	lappend cat($c) $page
	
	# Type of documented entity
	set type [lindex [file split $page] 0]
	if {$type eq "apps"} {
	    lappend apps $page
	} else {
	    lappend mods([lindex [file split $page] 1]) $page
	}
    }

    #parray meta
    #parray kwic
    #parray title
    #parray name
    #parray cat
    #puts "apps = $apps"
    #parray mods

    auto::saveKeywordIndex           kwic  name
    auto::saveTableOfContents        title name cat apps mods
    auto::saveSimpleTableOfContents1 title name apps toc_apps.txt
    auto::saveSimpleTableOfContents2 title name mods toc_mods.txt
    auto::saveSimpleTableOfContents3 title name cat  toc_cats.txt
    return
}

proc ::sak::doc::imake {modules} {
    global base
    # The argument (= set of modules) is irrelevant to this command.
    auto::saveManpages [auto::findManpages $base]
    return
}

proc ::sak::doc::ishow {modules} {
    if {[catch {
	set manpages [auto::loadManpages]
    } msg]} {
	puts stderr "Unable to use manpage listing '[auto::manpages]'\n$msg"
    } else {
	puts [join $manpages \n]
    }
    return
}

## ### ### ### ######### ######### #########

proc ::sak::doc::validate {modules} {Gen null  null $modules}
proc ::sak::doc::html     {modules} {Gen html  html $modules}
proc ::sak::doc::nroff    {modules} {Gen nroff n    $modules}
proc ::sak::doc::tmml     {modules} {Gen tmml  tmml $modules}
proc ::sak::doc::text     {modules} {Gen text  txt  $modules}
proc ::sak::doc::wiki     {modules} {Gen wiki  wiki $modules}
proc ::sak::doc::latex    {modules} {Gen latex tex  $modules}

proc ::sak::doc::dvi {modules} {
    latex $modules
    file mkdir [file join doc dvi]
    cd         [file join doc dvi]

    foreach f [lsort -dict [glob -nocomplain ../latex/*.tex]] {

	set target [file rootname [file tail $f]].dvi
	if {[file exists $target] 
	    && [file mtime $target] > [file mtime $f]} {
	    continue
	}

	puts "Gen (dvi): $f"
	exec latex $f 1>@ stdout 2>@ stderr
    }
    cd ../..
    return
}

proc ::sak::doc::ps {modules} {
    dvi $modules
    file mkdir [file join doc ps]
    cd         [file join doc ps]
    foreach f [lsort -dict [glob -nocomplain ../dvi/*.dvi]] {

	set target [file rootname [file tail $f]].ps
	if {[file exists $target] 
	    && [file mtime $target] > [file mtime $f]} {
	    continue
	}

	puts "Gen (ps): $f"
	exec dvips -o $target $f >@ stdout 2>@ stderr
    }
    cd ../..
    return
}

proc ::sak::doc::pdf {modules} {
    dvi $modules
    file mkdir [file join doc pdf]
    cd         [file join doc pdf]
    foreach f [lsort -dict [glob -nocomplain ../ps/*.ps]] {

	set target [file rootname [file tail $f]].pdf
	if {[file exists $target] 
	    && [file mtime $target] > [file mtime $f]} {
	    continue
	}

	puts "Gen (pdf): $f"
	exec ps2pdf $f $target >@ stdout 2>@ stderr
    }
    cd ../..
    return
}

proc ::sak::doc::list {modules} {
    Gen list l $modules
    
    set FILES [glob -nocomplain doc/list/*.l]
    set LIST  [open [file join doc list manpages.tcl] w]

    foreach file $FILES {
        set f [open $file r]
        puts $LIST [read $f]
        close $f
    }
    close $LIST

    eval file delete -force $FILES
    return
}

# ### ### ### ######### ######### #########
## Implementation

proc ::sak::doc::Gen {fmt ext modules} {
    global distribution
    global tcl_platform

    getpackage doctools doctools/doctools.tcl

    set null   0 ; if {![string compare $fmt null]} {set null   1}
    set hidden 0 ; if {![string compare $fmt desc]} {set hidden 1}

    if {!$null} {
	file mkdir [file join doc $fmt]
	set prefix "Gen ($fmt)"
    } else {
	set prefix "Validate  "
    }

    foreach m $modules {
	set mpath [sak::util::module2path $m]

	::doctools::new dt \
		-format $fmt \
		-module $m

	set fl [glob -nocomplain [file join $mpath *.man]]

	if {[llength $fl] == 0} {
	    dt destroy
	    continue
	}

	foreach f $fl {
	    if {!$null} {
                set target [file join doc $fmt \
                                [file rootname [file tail $f]].$ext]
                if {[file exists $target] 
                    && [file mtime $target] > [file mtime $f]} {
                    continue
                }
	    }
	    if {!$hidden} {puts "$prefix: $f"}

	    dt configure -file $f
	    if {$null} {
		dt configure -deprecated 1
	    }

	    set fail [catch {
		set data [dt format [get_input $f]]
	    } msg]

	    set warnings [dt warnings]
	    if {[llength $warnings] > 0} {
		puts stderr [join $warnings \n]
	    }

	    if {$fail} {
		puts stderr $msg
		continue
	    }

	    if {!$null} {
		write_out $target $data
	    }
	}
	dt destroy
    }
}

# ### ### ### ######### ######### #########

package provide sak::doc 1.0

##
# ###
