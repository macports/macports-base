# -*- tcl -*-
# # ## ### ##### ######## ############# ##################### 
# (C) 2013 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

package require linenoise
package require sak::color

getpackage fileutil                 fileutil/fileutil.tcl
getpackage doctools::changelog      doctools/changelog.tcl
getpackage struct::set              struct/sets.tcl
getpackage term::ansi::send         term/ansi/send.tcl

namespace eval ::sak::review {
    namespace import ::sak::color::*
}

# ###

proc ::sak::review::usage {} {
    package require sak::help
    puts stdout \n[sak::help::on review]
    exit 1
}

proc ::sak::review::run {} {
    Scan ; Review
    return
}

# # ## ### ##### ######## ############# ##################### 
## Phase I. Determine which modules require a review.
## A derivative of the code in ::sak::readme.

proc ::sak::review::Scan {} {
    global distribution
    variable review
    variable rm

    Banner "Scan for modules and packages to review..."

    # Future: Consolidate with ... readme ...
    # Determine which packages are potentially changed and therefore
    # in need of review, from the set of modules touched since the
    # last release, as per the fossil repository's commit log.

    # list of modified modules.
    set modifiedm {}

    # database of commit messages per changed module.
    # cm: module -> list(string)
    array set cm {}

    # pt: database of files per changed module.
    # module -> list(path)

    # rm: module -> list (revs); rev = uuid+desc+files (string)
    array set rm {}

    foreach {trunk   tuid} [Leaf          trunk]   break ;# rid + uuid
    foreach {release ruid} [YoungestOfTag release] break ;# datetime + uuid
    AllParentsAfter $trunk $tuid $release $ruid -> rid uuid {
	Next ; Progress " $rid"

	set d [Description $rid]
	Progress " D"

	# Determine file set, split by modules, then generate a package of
	# uuid, description and filtered files per modules touched.

	array set fs {}

	FileSet $rid -> path action {
	    Progress .

	    set px [file split $path]
	    set themodule [lindex $px 1]
	    lappend modifiedm $themodule
	    lappend cm($themodule) $d

	    # ignore files in modules/
	    if {[llength $px] < 3} continue

	    #puts $themodule||$rid||$action|$px|

	    lappend fs($themodule) [file join {*}[lrange $px 2 end]]
	    lappend pt($themodule) [file join {*}[lrange $px 2 end]]
	}

	foreach {m files} [array get fs] {
	    set str \[$uuid\]\n$d\n\n[join [lsort -dict $files] \n]
	    lappend rm($m) $str
	}
	unset fs
    }

    Next

    # cleanup module list, may have duplicates
    set modifiedm [lsort -unique $modifiedm]

    array set review {}

    # package -> list(version)
    set old_version    [loadoldv [location_PACKAGES]]
    array set releasep [loadpkglist [location_PACKAGES]]
    array set currentp [ipackages]

    array set changed {}
    foreach p [array names currentp] {
	foreach {vlist module} $currentp($p) break
	set currentp($p) $vlist
	set changed($p) [struct::set contains $modifiedm $module]
    }

    LoadNotes

    set np 0
    # Process all packages in all modules ...
    foreach m [lsort -dict [modules]] {
	Next ; Progress " $m"
	foreach name [lsort -dict [Provided $m]] {
	    #Next ; Progress "... $m/$name"
	    # Define list of versions, if undefined so far.
	    if {![info exists currentp($name)]} {
		set currentp($name) {}
	    }

	    # Detect new packages. Ignore them.

	    if {![info exists releasep($name)]} {
		#Progress " /new"
		continue
	    }

	    # The package is not new, but possibly changed. And even
	    # if the version has not changed it may have been, this is
	    # indicated by changed(), which is based on the ChangeLog.

	    set vequal [struct::set equal $releasep($name) $currentp($name)]
	    set note   [Note $m $name]

	    # Detect packages whose versions are unchanged, and whose
	    # changelog also indicates no change. Ignore these too.

	    if {!$changed($name) && $vequal} {
		#Progress " /not changed"
		continue
	    }

	    # Now look for packages where both changelog and version
	    # number indicate a change. These we have to review.

	    if {$changed($name) && !$vequal} {
		lappend review($m) [list $name classify $note]
		#Progress " [=cya classify]"
		incr np
		continue
	    }

	    # What remains are packages which are changed according to
	    # their changelog, but their version disagrees. Or the
	    # reverse. These need a big review to see who is right.
	    # We may have to bump their version information, not just
	    # classify changes. Of course, in modules with multiple
	    # packages it is quite possible to be unchanged and the
	    # changelog refers to the siblings.

	    lappend review($m) [list $name mismatch $note]
	    #Progress " [=cya mismatch]"
	    incr np
	}
    }

    Close

    # Postprocessing phase, pull in all relevant commit messages of the module.

    foreach m [array names review] {
	# commit messages
	if {[info exists cm($m)]} {
	    set entries [lsort -unique $cm($m)]
	} else {
	    set entries {}
	}
	# and affected files
	if {[info exists pt($m)]} {
	    lappend entries [join [lsort -dict [lsort -unique $pt($m)]] \n]
	}

	set review($m) [list $review($m) [join $entries \n\n]]
    }

    # review: module -> list (notes, desc+files)
    set review() $np
    return
}

# see also readme
proc ::sak::review::Provided {m} {
    set result {}
    foreach {p ___} [ppackages $m] {
	lappend result $p
    }
    return $result
}

# see also readme
proc ::sak::review::loadoldv {fname} {
    set f [open $fname r]
    foreach line [split [read $f] \n] {
	set line [string trim $line]
	if {[string match @* $line]} {
	    foreach {__ __ v} $line break
	    close $f
	    return $v
	}
    }
    close $f
    return -code error {Version not found}
}

proc ::sak::review::Progress {text} {
    puts -nonewline stdout $text
    flush stdout
    return
}

proc ::sak::review::Next {} {
    # erase to end of line, then move back to start of line.
    term::ansi::send::eeol
    puts -nonewline stdout \r
    flush stdout
    return
}

proc ::sak::review::Close {} {
    puts stdout ""
    return
}

proc ::sak::review::Clear {} {
    term::ansi::send::clear
    return
}

proc ::sak::review::Banner {text} {
    Clear
    puts stdout "\n <<SAK Tcllib: $text>>\n"
    return
}

proc ::sak::review::Note {m p} {
    # Look for a note, and present to caller, if any.
    variable notes
    #parray notes
    set k [list $m $p]
    #puts <$k>
    if {[info exists notes($k)]} {
	return $notes($k)
    }
    return ""
}

proc ::sak::review::SaveNote {at t} {
    global distribution
    set    f [open [file join $distribution .NOTE] a]
    puts  $f [list $at $t]
    close $f
    return
}

proc ::sak::review::LoadNotes {} {
    global distribution
    variable  notes
    array set notes {}

    catch {
	set f [file join $distribution .NOTE]
	set f [open $f r]
	while {![eof $f]} {
	    if {[gets $f line] < 0} continue
	    set line [string trim $line]
	    if {$line == {}} continue
	    foreach {k t} $line break
	    set notes($k) $t
	}
	close $f
    }

    return
}

proc ::sak::review::FileSet {rid _ pv av script} {
    upvar 1 $pv thepath $av theaction

    lappend map @rid@ $rid
    foreach line [split [string trim [F [string map $map {
	SELECT filename.name,
	       CASE WHEN nullif(mlink.pid,0) is null THEN 'added'
                    WHEN nullif(mlink.fid,0) is null THEN 'deleted'
                    ELSE                                  'edited'
	       END
	FROM  mlink, filename
	WHERE mlink.mid  = @rid@
	AND   mlink.fnid = filename.fnid
	ORDER BY filename.name;
    }]]] \n] {
	foreach {thepath theaction} [split $line |] break
	# ignore all changes not in modules
	if {![string match modules* $thepath]} continue
	uplevel 1 $script
    }
    return
}

proc ::sak::review::Description {rid} {
    lappend map @rid@ $rid
    string trim [F [string map $map {
	SELECT coalesce(event.ecomment,event.comment)
	FROM   event
	WHERE  event.objid = @rid@
	;
    }]]
}

proc ::sak::review::AllParentsAfter {rid ruid cut cutuid _ rv uv script} {
    upvar 1 $rv therev $uv theuid

    array set rev {}
    set rev($rid) .
    lappend front $rid

    # Initial run, for the starting revision.
    set therev $rid
    set theuid $ruid
    uplevel 1 $script

    # Standard iterative incremental transitive-closure. We have a
    # front of revisions whose parents we take, which become the new
    # front to follow, until no parents are delivered anymore due to
    # the cutoff condition (timestamp, only the revisions coming after
    # are accepted).

    while {1} {
	set new {}
	foreach cid $front {
	    foreach pid [Parents $cid $cut] {
		foreach {pid uuid mtraw mtime} [split [string trim $pid |] |] break
		if {$uuid eq $cutuid} continue

		lappend new $pid $mtime $uuid
		if {$mtraw <= $cut} {
		    puts "Overshot: $rid $mtime $uuid"
		}
	    }
	}
	if {![llength $new]} break

	# record new parents, and make them the new starting points
	set front {}
	foreach {pid mtime uuid} $new {
	    if {[info exists rev($pid)]} continue
	    set rev($pid) .
	    lappend front $pid

	    set therev $pid
	    set theuid $uuid
	    uplevel 1 $script
	}
    }
}

proc ::sak::review::Parents {rid cut} {
    lappend map @rid@    $rid
    lappend map @cutoff@ $cut
    split [F [string map $map {
	SELECT pid, blob.uuid, event.mtime, datetime(event.mtime)
	FROM  plink, blob, event
	WHERE plink.cid   = @rid@
	AND   plink.pid = blob.rid
	AND   plink.pid = event.objid
	AND   event.mtime > @cutoff@
	;
    }]] \n
}

proc ::sak::review::YoungestOfTag {tag} {
    lappend map @tag@ $tag
    puts stderr "last $tag = [F [string map $map {
	SELECT datetime (event.mtime)
	FROM   tag, tagxref, event
	WHERE tag.tagname     = 'sym-' || '@tag@'
	AND   tagxref.tagid   = tag.tagid
	AND   tagxref.tagtype > 0
	AND   tagxref.rid     = event.objid
	AND   event.type      = 'ci'
	ORDER BY event.mtime DESC
	LIMIT 1
	;
    }]]"
    split [F [string map $map {
	SELECT event.mtime, blob.uuid
	FROM   tag, tagxref, event, blob
	WHERE tag.tagname     = 'sym-' || '@tag@'
	AND   tagxref.tagid   = tag.tagid
	AND   tagxref.tagtype > 0
	AND   tagxref.rid     = event.objid
	AND   event.type      = 'ci'
        AND   blob.rid        = event.objid
	ORDER BY event.mtime DESC
	LIMIT 1
	;
    }]] |
}

proc ::sak::review::Leaf {branch} {
    lappend map @branch@ $branch
    split [F [string map $map {
	SELECT blob.rid, blob.uuid
	FROM   leaf, blob, tag, tagxref
	WHERE blob.rid        = leaf.rid
	AND   tag.tagname     = 'sym-' || '@branch@'
	AND   tagxref.tagid   = tag.tagid
	AND   tagxref.tagtype > 0
	AND   tagxref.rid     = leaf.rid
	;
    }]] |
}

proc ::sak::review::F {script} {
    #puts |$script|
    set r [exec fossil sqlite3 << $script]
    #puts ($r)
    return $r
}



# # ## ### ##### ######## ############# ##################### 
## Phase II. Interactively review the changes packages.

# Namespace variables
#
# review      : array, database of all modules, keyed by name
# nm          : number of modules
# modules     : list of module names, keys to --> review
# current     : index in -> modules, current module
# np          : number of packages in current module
# packages    : list of packages in current module
# currentp    : index in --> packages
# im          : 1+current  | indices for display
# ip          : 1+currentp |
# ir          : 1+currentr |
# end         : array : module (name) --> index of last package
# stop        : repl exit flag
# map         : array : text -> module/package index
# commands    : proper commands
# allcommands : commands + namesof(map)
# 

proc ::sak::review::Review {} {
    variable review    ;# table of everything to review
    variable rm        ;# Alt structure, rev (desc, files) by module.
    variable nm        ;# number of modules
    variable modules   ;# list of module names, sorted
    variable stop 0    ;# repl exit flag
    variable end       ;# last module/package index.
    variable smode rev ;# standard display per revision.

    variable navcommands
    variable allcommands ;# list of all commands, sorted
    variable commands    ;# list of proper commands, sorted
    variable map         ;# map from package names to module/package indices.
    variable prefix

    Banner "Packages to review: $review()"
    unset   review()

    set nm [array size review]
    if {!$nm} return

    set modules [lsort -dict [array names review]]

    # Map package name --> module/package index.
    set im 0
    foreach m $modules {
	foreach {packages clog} $review($m) break
	set ip 0
	foreach p $packages {
	    set end($im) $ip
	    set end($m) $ip
	    set end() [list $im $ip]
	    foreach {name what tags} $p break
	    lappend map(@$name)    [list $im $ip]
	    lappend map(@$name/$m) [list $im $ip]
	    incr ip
	}
	incr im
    }

    # Drop amibigous mappings, and fill the list of commands.
    foreach k [array names map] {
	# Skip already dropped keys (extended forms).
	if {![info exists map($k)]} continue
	if {[llength $map($k)] < 2} {
	    set map($k) [lindex $map($k) 0]
	    # Drop extended form, not needed.
	    array unset map $k/*
	} else {
	    unset map($k)
	}
    }

    # Map module name --> module/package index
    # If not preempted by package mapping.
    set im -1
    foreach m $modules {
	incr im
	if {[info exists map(@$m)]} continue
	set map(@$m) [list $im 0]
    }

    # Map command prefix -> full command.

    array set prefix {}
    foreach c [info commands ::sak::review::C_*] {
	set c [string range [namespace tail $c] 2 end]
	lappend commands    $c
	lappend allcommands $c
	set buf {}
	foreach ch [split $c {}] {
	    append buf $ch
	    lappend prefix($buf) $c
	}
    }

    foreach c [array names map] {
	lappend allcommands $c
	set buf {}
	foreach ch [split $c {}] {
	    append buf $ch
	    lappend prefix($buf) $c
	}
    }

    set commands    [lsort -dict $commands]
    set allcommands [lsort -dict $allcommands]
    set navcommands [lsort -dict [array names map]]

    # Enter the REPL
    Goto {0 0} 1
    linenoise::cmdloop \
	-history   1 \
	-exit      ::sak::review::Exit \
	-continued ::sak::review::Continued \
	-prompt1   ::sak::review::Prompt \
	-complete  ::sak::review::Complete \
	-dispatch  ::sak::review::Dispatch
    return
}

# # ## ### ##### ######## ############# ##################### 

proc ::sak::review::RefreshDisplay {} {
    variable m
    variable im
    variable ir
    variable nm
    variable nr
    variable clog
    variable rlog
    variable what
    variable smode

    if {$smode eq "rev"} {
	set text $rlog
    } else {
	set text $clog
    }

    if {$smode eq "rev"} {
	Banner "($ir/$nr) \[$im/$nm\] [=cya [string totitle $what]] [=green $m]"
    } else {
	Banner "\[$im/$nm\] [=cya [string totitle $what]] [=green $m]"
    }
    puts "| [join [split $text \n] "\n| "]\n"
    return
}

proc ::sak::review::Exit {} {
    variable stop
    return  $stop
}

proc ::sak::review::Continued {buffer} {
    return 0
}

proc ::sak::review::Prompt {} {
    variable ip
    variable np
    variable name
    variable tags
    variable smode
    variable im
    variable ir
    variable nm
    variable nr
    variable what
    variable m

    if {$smode eq "rev"} {
	append p "($ir/$nr) "
    }

    append p "\[$im/$nm\] [=green $m] [=cya [string totitle $what]] "
    append p "\[$ip/$np\] [=whi $name] ($tags): "
    return $p
}

proc ::sak::review::Complete {line} {
    variable allcommands
    if {$line eq {}} {
	return $allcommands
    } elseif {[llength $line] == 1} {
	set r {}
	foreach c $allcommands {
	    if {![string match ${line}* $c]} continue
	    lappend r $c
	}
	return $r
    } else {
	return {}
    }
}

proc ::sak::review::Dispatch {line} {
    variable prefix
    variable map

    if {$line == ""} { set line next }

    set cmd [lindex $line 0]

    if {![info exists prefix($cmd)]} {
	return -code error "Unknown command $cmd, use help or ? to list them"
    } elseif {[llength $prefix($cmd)] > 1} {
	return -code error "Ambigous prefix \"$cmd\", expected [join $prefix($cmd) {, }]"
    }

    # Map prefix to actual command
    set line [lreplace $line 0 0 $prefix($cmd)]

    # Run command.
    if {[info exists map($cmd)]} {
	Goto $map($cmd)
	return
    }
    eval C_$line
}

proc ::sak::review::Goto {loc {skip 0}} {
    variable review
    variable rm
    variable modules
    variable packages
    variable clog
    variable rlog
    variable rloga
    variable current
    variable currentp
    variable currentr
    variable nm
    variable np
    variable nr
    variable at
    variable tags
    variable what
    variable name

    variable m
    variable p
    variable ip
    variable im
    variable ir

    foreach {current currentp} $loc break
    set currentr 0

    puts "Goto ($current/$currentp)"

    set m [lindex $modules $current]
    foreach {packages clog} $review($m) break
    if {[catch {
	set nr   [llength $rm($m)]
	set rloga $rm($m)
	set rlog [lindex $rloga $currentr]
    }]} {
	set nr 0
	set currentr 0
	set rloga {}
	set rlog {}
    }

    set np [llength $packages]
    set p  [lindex  $packages $currentp]

    foreach {name what tags} $p break
    set at [list $m $name]

    set im [expr {1+$current}]
    set ip [expr {1+$currentp}]
    set ir [expr {1+$currentr}]

    if {$skip && ([llength $tags] ||
		  ($tags == "---"))} {
	C_next
    } else {
	RefreshDisplay
    }
    return
}

proc ::sak::review::C_* {} {
    variable smode
    variable currentr
    if {$smode eq "all"} {
	set smode rev
	set currentr 0
    } else {
	set smode all
    }
    RefreshDisplay
    return
}
proc ::sak::review::C_, {} {
    # next revision
    variable smode
    variable rlog
    variable rloga
    variable currentr
    if {$smode eq "all"} {
	set smode rev
	set currentr 0
    } else {
	variable nr
	incr currentr
	if {$currentr >= $nr} { set currentr 0 }
    }
    variable ir [expr {1+$currentr}]
    set rlog [lindex $rloga $currentr]
    RefreshDisplay
    return
}
proc ::sak::review::C_' {} {
    # previous revision
    variable smode
    variable rlog
    variable rloga
    variable nr
    variable currentr
    if {$smode eq "all"} {
	set smode rev
	set currentr $nr
    }
    incr currentr -1
    if {$currentr <= 0} {
	set currentr $nr
	incr currentr -1
    }
    variable ir [expr {1+$currentr}]
    set rlog [lindex $rloga $currentr]
    RefreshDisplay
    return
}

proc ::sak::review::C_exit {} { variable stop 1 }
proc ::sak::review::C_quit {} { variable stop 1 }

proc ::sak::review::C_? {} { C_help }
proc ::sak::review::C_help {} {
    variable commands
    return [join $commands {, }]
}

proc ::sak::review::C_@? {} { C_@help }
proc ::sak::review::C_@help {} {
    variable navcommands
    return [join $navcommands {, }]
}

proc ::sak::review::C_@start {} { Goto {0 0} }
proc ::sak::review::C_@0     {} { Goto {0 0} }
proc ::sak::review::C_@end   {} { variable end ; Goto $end() }

proc ::sak::review::C_>> {} { C_next 1 }
proc ::sak::review::C_next {{skiprev 0}} {
    variable tags
    variable current
    variable currentp
    variable smode

    if {!($skiprev) && ($smode eq "rev")} {
	variable ir
	variable nr
	if {$ir < $nr} {
	    C_,
	    return
	}
    }

    C_step 0

    set stop @$current/$currentp
    while {[llength $tags] ||
	   ($tags == "---")} {
	C_step 0
	if {"@$current/$currentp" == "$stop"} break
    }

    RefreshDisplay
    return
}

proc ::sak::review::C_step {{refresh 1}} {
    variable nm
    variable np
    variable current
    variable currentp
    variable packages

    incr currentp
    if {$currentp >= $np} {
	# skip to next module, first package
	incr current
	if {$current >= $nm} {
	    # skip to first module
	    set current 0
	}
	set currentp 0

    }
    Goto [list $current $currentp]
    return
}

proc ::sak::review::C_<< {} { C_prev 1 }
proc ::sak::review::C_prev {{skiprev 0}} {
    variable end
    variable nm
    variable np
    variable current
    variable currentp
    variable packages
    variable smode

    if {!$skiprev && ($smode eq "rev")} {
	variable ir
	if {$ir > 1} {
	    C_'
	    return
	}
    }

    incr currentp -1
    if {$currentp < 0} {
	# skip to previous module, last package
	incr current -1
	if {$current < 0} {
	    # skip to back to last module
	    set current [expr {$nm - 1}]
	}
	set currentp $end($current)
    }
    Goto [list $current $currentp]
    return
}

# Commands to add/remove tags, clear set, replace set

proc ::sak::review::C_feature {} { +T EF }
proc ::sak::review::C_test    {} { +T T }
proc ::sak::review::C_doc     {} { +T D }
proc ::sak::review::C_bug     {} { +T B }
proc ::sak::review::C_perf    {} { +T P }
proc ::sak::review::C_example {} { +T EX }
proc ::sak::review::C_api     {} { +T API }
proc ::sak::review::C_impl    {} { +T I }

proc ::sak::review::C_-feature {} { -T EF }
proc ::sak::review::C_-test    {} { -T T }
proc ::sak::review::C_-doc     {} { -T D }
proc ::sak::review::C_-bug     {} { -T B }
proc ::sak::review::C_-perf    {} { -T P }
proc ::sak::review::C_-example {} { -T EX }
proc ::sak::review::C_-api     {} { -T API }
proc ::sak::review::C_-impl    {} { -T I }

proc ::sak::review::C_---   {} { =T --- }
proc ::sak::review::C_clear {} { =T --- }
#proc ::sak::review::C_cn {} { C_clear ; C_next }

proc ::sak::review::+T {tag} {
    variable tags
    if {[lsearch -exact $tags $tag] >= 0} {
	RefreshDisplay
	return
    }
    =T [linsert $tags end $tag]
    return
}

proc ::sak::review::-T {tag} {
    variable tags
    set pos [lsearch -exact $tags $tag]
    if {$pos < 0} {
	RefreshDisplay
	return
    }
    =T [lreplace $tags $pos $pos]
    return
}

proc ::sak::review::=T {newtags} {
    variable review
    variable clog
    variable packages
    variable currentp
    variable p
    variable m
    variable at
    variable name
    variable what
    variable tags

    if {([llength $newtags] > 1) &&
	([set pos [lsearch -exact $newtags ---]] >= 0)} {
	# Drop --- if there are other tags.
	set newtags [lreplace $newtags $pos $pos]
    }

    set tags       [lsort -dict $newtags]
    set p          [list $name $what $newtags]
    set packages   [lreplace $packages $currentp $currentp $p]
    set review($m) [list $packages $clog]

    SaveNote $at $tags
    RefreshDisplay
    return
}

proc ::sak::review::?T {} {
    variable tags
    return $tags
}

##
# ###

namespace eval ::sak::review {}

package provide sak::review 1.0
