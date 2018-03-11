# -*- tcl -*-
# sak::doc::auto - Documentation facilities, support for automatic
# list of manpages, keyword index, and table of contents.

package require sak::util

namespace eval ::sak::doc::auto {
    set here [file dirname [file normalize [info script]]]
}

getpackage fileutil         fileutil/fileutil.tcl
getpackage doctools         doctools/doctools.tcl
getpackage textutil::repeat textutil/repeat.tcl

# ###
# API commands

proc ::sak::doc::auto::manpages {} {
    variable here
    return [file join $here manpages.txt]
}

proc ::sak::doc::auto::kwic {} {
    variable here
    return [file join $here kwic.txt]
}

proc ::sak::doc::auto::toc {{name toc.txt}} {
    variable here
    return [file join $here $name]
}

## ### ### ### ######### ######### #########

proc ::sak::doc::auto::findManpages {base} {
    set top [file normalize $base]
    set manpages {}
    foreach page [concat \
		      [glob -nocomplain -directory $top/modules */*.man] \
		      [glob -nocomplain -directory $top/apps      *.man]] {
	lappend manpages [fileutil::stripPath $top $page]
    }
    return [lsort -dict $manpages]
}

proc ::sak::doc::auto::saveManpages {manpages} {
    fileutil::writeFile [manpages] [join [lsort -dict $manpages] \n]\n
    return
}

proc ::sak::doc::auto::loadManpages {} {
    return [lsort -dict [split [fileutil::cat [manpages]] \n]]
}

## ### ### ### ######### ######### #########

proc ::sak::doc::auto::scanManpages {manpages} {
    ::doctools::new dt -format list
    set data {}
    puts Scanning...
    foreach page $manpages {
	puts ...$page
	if {![file size $page]} { puts "\tEMPTY, IGNORED" ; continue }
	dt configure -ibase $page
	lappend data $page [lindex [dt format [fileutil::cat $page]] 1]
    }

    dt destroy
    return $data
}

## ### ### ### ######### ######### #########

proc ::sak::doc::auto::saveKeywordIndex {kv nv} {
    upvar 1 $kv kwic $nv name
    # kwic: keyword -> list (files)
    # name: file    -> label

    TagsBegin
    Tag+ index_begin [list {Keyword Index} {}]

    # Handle the keywords in dictionary order for nice display.
    foreach kw [lsort -dict [array names kwic]] {
	set tmp [Sortable $kwic($kw) name max _]

	Tag+ key [list $kw]
	foreach item [lsort -dict -index 0 $tmp] {
	    foreach {label file} $item break
	    Tag+ manpage [FmtR max $file] [list $label]
	}
    }

    Tag+ index_end

    fileutil::writeFile [kwic] [join $lines \n]
    return
}

## ### ### ### ######### ######### #########

proc ::sak::doc::auto::saveTableOfContents {tv nv cv av mv} {
    upvar 1 $tv title $nv name $cv cat $av apps $mv mods
    # title: file     -> description
    # name:  file     -> label
    # cat:   category -> list (file...)

    TagsBegin
    Tag+ toc_begin [list {Table Of Contents} {}]

    # The man pages are sorted in several ways for the toc.
    # 1. First section by category. Subsections are categories.
    #    Sorted by category name, in dictionary order.
    #    Inside the subsections the files, sorted by label and
    #    description.
    # 2. Second section for types. Subsections are modules and apps.
    #    Apps first, then modules. For apps items directly, sorted
    #    by name and description. For modules one sub-subsection
    #    per module, elements the packages, sorted by label and
    #    description.

    Tag+ division_start [list {By Categories}]
    foreach c [lsort -dict [array names cat]] {
	Tag+ division_start [list $c]
	foreach item [lsort -dict -index 0 [Sortable $cat($c) name maxf maxl]] {
	    foreach {label file} $item break
	    Tag+ item \
		[FmtR maxf $file] \
		[FmtR maxl $label] \
		[list $title($file)]
	}
	Tag+ division_end
    }
    Tag+ division_end

    Tag+ division_start [list {By Type}]
    # Not handled: 'no applications'
    Tag+ division_start [list {Applications}]
    foreach item [lsort -dict -index 0 [Sortable $apps name maxf maxl]] {
	foreach {label file} $item break
	Tag+ item \
	    [FmtR maxf $file] \
	    [FmtR maxl $label] \
	    [list $title($file)]
    }
    Tag+ division_end
    # Not handled: 'no modules'
    Tag+ division_start [list {Modules}]
    foreach m [lsort -dict [array names mods]] {
	Tag+ division_start [list $m]
	foreach item [lsort -dict -index 0 [Sortable $mods($m) name maxf maxl]] {
	    foreach {label file} $item break
	    Tag+ item \
		[FmtR maxf $file] \
		[FmtR maxl $label] \
		[list $title($file)]
	}
	Tag+ division_end
    }
    Tag+ division_end
    Tag+ division_end
    Tag+ toc_end

    fileutil::writeFile [toc] [join $lines \n]
    return
}

proc ::sak::doc::auto::saveSimpleTableOfContents1 {tv nv dv fname} {
    upvar 1 $tv title $nv name $dv data
    # title: file     -> description
    # name:  file     -> label
    # data:  list(file...)

    TagsBegin
    Tag+ toc_begin [list {Table Of Contents} {}]

    # The man pages are sorted in several ways for the toc.
    # Subsections are the modules or apps, whatever is in data.

    # Not handled: 'no applications'
    Tag+ division_start [list {Applications}]
    foreach item [lsort -dict -index 0 [Sortable $data name maxf maxl]] {
	foreach {label file} $item break
	Tag+ item \
	    [FmtR maxf $file] \
	    [FmtR maxl $label] \
	    [list $title($file)]
    }
    Tag+ division_end
    Tag+ toc_end

    fileutil::writeFile [toc $fname] [join $lines \n]
    return
}

proc ::sak::doc::auto::saveSimpleTableOfContents2 {tv nv dv fname} {
    upvar 1 $tv title $nv name $dv data
    # title: file     -> description
    # name:  file     -> label
    # data:  module -> list (file...)

    TagsBegin
    Tag+ toc_begin [list {Table Of Contents} {}]

    # The man pages are sorted in several ways for the toc.
    # Subsections are the modules or apps, whatever is in data.

    # Not handled: 'no modules'
    Tag+ division_start [list {Modules}]
    foreach m [lsort -dict [array names data]] {
	Tag+ division_start [list $m]
	foreach item [lsort -dict -index 0 [Sortable $data($m) name maxf maxl]] {
	    foreach {label file} $item break
	    Tag+ item \
		[FmtR maxf $file] \
		[FmtR maxl $label] \
		[list $title($file)]
	}
	Tag+ division_end
    }
    Tag+ division_end
    Tag+ toc_end

    fileutil::writeFile [toc $fname] [join $lines \n]
    return
}

proc ::sak::doc::auto::saveSimpleTableOfContents3 {tv nv cv fname} {
    upvar 1 $tv title $nv name $cv cat
    # title: file     -> description
    # name:  file     -> label
    # cat:   category -> list (file...)

    TagsBegin
    Tag+ toc_begin [list {Table Of Contents} {}]

    Tag+ division_start [list {By Categories}]
    foreach c [lsort -dict [array names cat]] {
	Tag+ division_start [list $c]
	foreach item [lsort -dict -index 0 [Sortable $cat($c) name maxf maxl]] {
	    foreach {label file} $item break
	    Tag+ item \
		[FmtR maxf $file] \
		[FmtR maxl $label] \
		[list $title($file)]
	}
	Tag+ division_end
    }
    Tag+ division_end
    Tag+ toc_end

    fileutil::writeFile [toc $fname] [join $lines \n]
    return
}

proc ::sak::doc::auto::Sortable {files nv mfv mnv} {
    upvar 1 $nv name $mfv maxf $mnv maxn
    # Generate a list of files sortable by name, and also find the
    # max length of all relevant names.
    set maxf 0
    set maxn 0
    set tmp {}
    foreach file $files {
	lappend tmp [list $name($file) $file]
	Max maxf $file
	Max maxn $name($file)
    }
    return $tmp
}

## ### ### ### ######### ######### #########

proc ::sak::doc::auto::Max {v str} {
    upvar 1 $v max
    set x [string length $str]
    if {$x <= $max} return
    set max $x
    return
}

proc ::sak::doc::auto::FmtR {v str} {
    upvar 1 $v max
    return [list $str][textutil::repeat::blank \
	    [expr {$max - [string length [list $str]]}]]
}

## ### ### ### ######### ######### #########

proc ::sak::doc::auto::Tag {n args} {
    if {[llength $args]} {
	return "\[$n [join $args]\]"
    } else {
	return "\[$n\]"
    }
    #return \[[linsert $args 0 $n]\]
}

proc ::sak::doc::auto::Tag+ {n args} {
    upvar 1 lines lines
    lappend lines [eval [linsert $args 0 ::sak::doc::auto::Tag $n]]
    return
}

proc ::sak::doc::auto::TagsBegin {} {
    upvar 1 lines lines
    set lines {}
    return
}

## ### ### ### ######### ######### #########

package provide sak::doc::auto 1.0
