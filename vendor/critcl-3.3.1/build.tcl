#!/bin/sh
# -*- tcl -*- \
exec tclsh "$0" ${1+"$@"}
package require Tcl 8.6 9
unset -nocomplain ::errorInfo
set me [file normalize [info script]]
proc main {} {
    global argv
    if {![llength $argv]} { set argv help}
    if {[catch {
	eval _$argv
    }]} usage
    exit 0
}
set packages {
    {app-critcl       {.. critcl critcl.tcl} critcl-app}
    {critcl           critcl.tcl}
    {critcl-bitmap    bitmap.tcl}
    {critcl-class     class.tcl}
    {critcl-cutil     cutil.tcl}
    {critcl-emap      emap.tcl}
    {critcl-enum      enum.tcl}
    {critcl-iassoc    iassoc.tcl}
    {critcl-literals  literals.tcl}
    {critcl-platform  platform.tcl}
    {critcl-util      util.tcl}
    {stubs_container  container.tcl}
    {stubs_gen_decl   gen_decl.tcl}
    {stubs_gen_header gen_header.tcl}
    {stubs_gen_init   gen_init.tcl}
    {stubs_gen_lib    gen_lib.tcl}
    {stubs_gen_macro  gen_macro.tcl}
    {stubs_gen_slot   gen_slot.tcl}
    {stubs_genframe   genframe.tcl}
    {stubs_reader     reader.tcl}
    {stubs_writer     writer.tcl}
}
proc usage {{status 1}} {
    global errorInfo
    if {[info exists errorInfo] && ($errorInfo ne {}) &&
	![string match {invalid command name "_*"*} $errorInfo]
    } {
	puts stderr $::errorInfo
	exit
    }

    global argv0
    set prefix "Usage: "
    foreach c [lsort -dict [info commands _*]] {
	set c [string range $c 1 end]
	if {[catch {
	    H${c}
	} res]} {
	    puts stderr "$prefix[underlined]$argv0 $c[reset] args...\n"
	} else {
	    puts stderr "$prefix[underlined]$argv0 $c[reset] $res\n"
	}
	set prefix "       "
    }
    exit $status
}

proc underlined {} { return "\033\[4m" }
proc reset      {} { return "\033\[0m" }

proc +x {path} {
    catch { file attributes $path -permissions ugo+x }
    return
}
proc critapp {dst} {
    global tcl_platform
    set app [file join $dst critcl]
    if {$tcl_platform(platform) eq "windows"} {
	append app .tcl
    }
    return $app
}
proc vfile {dir vfile} {
    global me
    set selfdir [file dirname $me]
    eval [linsert $vfile 0 file join $selfdir lib $dir]
}
proc grep {file pattern} {
    set lines [split [read [set chan [open $file r]]] \n]
    close $chan
    return [lsearch -all -inline -glob $lines $pattern]
}
proc version {file} {
    set provisions [grep $file {*package provide*}]
    #puts /$provisions/
    return [lindex $provisions 0 3]
}
proc tmpdir {} {
    set tmpraw "critcl.[clock clicks]"
    set tmpdir $tmpraw.[pid]
    file delete -force $tmpdir
    file mkdir $tmpdir
    file delete -force $tmpraw

    puts "Assembly in: $tmpdir"
    return $tmpdir
}
proc relativedir {dest here} {
    # Convert dest into a relative path which is relative to `here`.
    set save $dest

    #puts stderr [list relativedir $dest $label]

    set here [file split $here]
    set dest [file split $dest]

    #puts stderr [list relativedir < $here]
    #puts stderr [list relativedir > $dest]

    while {[string equal [lindex $dest 0] [lindex $here 0]]} {
	set dest [lrange $dest 1 end]
	set here [lrange $here 1 end]
	if {[llength $dest] == 0} {break}
    }
    set ul [llength $dest]
    set hl [llength $here]

    if {$ul == 0} {
	set dest [lindex [file split $save] end]
    } else {
	while {$hl > 1} {
	    set dest [linsert $dest 0 ..]
	    incr hl -1
	}
	set dest [eval file join $dest]
    }

    #puts stderr [list relativedir --> $dest]
    return $dest
}
proc id {cv vv} {
    upvar 1 $cv commit $vv version

    set commit  [exec git log -1 --pretty=format:%H]
    set version [exec git describe]

    puts "Commit:      $commit"
    puts "Version:     $version"
    return
}
proc savedoc {tmpdir} {
    puts {Collecting the documentation ...}
    file copy -force [file join embedded www] [file join $tmpdir doc]
    return
}
proc pkgdirname {name version} {
	return $name-$version
}
proc placedoc {tmpdir} {
    file delete -force doc
    file copy -force [file join $tmpdir doc] doc
    return
}
proc 2website {} {
    puts {Switching to gh-pages...}
    exec 2>@ stderr >@ stdout git checkout gh-pages
    return
}
proc reminder {commit} {
    puts ""
    puts "We are in branch gh-pages now, coming from $commit"
    puts ""
    return
}
proc shquote value {
    return "\"[string map [list \\ \\\\ $ \\$ ` \\`] $value]\""
}
proc dest-dir {} {
    global paths
    if {![info exists paths(dest-dir)]} {
	global env
	if {[info exists env(DESTDIR)]} {
	    set paths(dest-dir) [string trimright $env(DESTDIR) /]
	} else {
	    set paths(dest-dir) ""
	}
    } elseif {$paths(dest-dir) ne ""} {
	set paths(dest-dir) [string trimright $paths(dest-dir) /]
    }
    return $paths(dest-dir)
}
proc prefix {} {
    global paths
    if {![info exists paths(prefix)]} {
	set paths(prefix) [file dirname [file dirname [norm [info nameofexecutable]]]]
    }
    return $paths(prefix)
}
proc exec-prefix {} {
    global paths
    if {![info exists paths(exec-prefix)]} {
	set paths(exec-prefix) [prefix]
    }
    return $paths(exec-prefix)
}
proc bin-dir {} {
    global paths
    if {![info exists paths(bin-dir)]} {
	set paths(bin-dir) [exec-prefix]/bin
    }
    return $paths(bin-dir)
}
proc lib-dir {} {
    global paths
    if {![info exists paths(lib-dir)]} {
	set paths(lib-dir) [exec-prefix]/lib
    }
    return $paths(lib-dir)
}
proc include-dir {} {
    global paths
    if {![info exists paths(include-dir)]} {
	set paths(include-dir) [prefix]/include
    }
    return $paths(include-dir)
}
proc process-install-options {} {
    upvar 1 args argv target target
    while {[llength $argv]} {
	set o [lindex $argv 0]
	if {![string match -* $o]} break
	switch -exact -- $o {
	    -target {
		#                 ignore 0
		set target [lindex $argv 1]
		set argv   [lrange $argv 2 end]
	    }
	    --dest-dir    -
	    --prefix      -
	    --exec-prefix -
	    --bin-dir     -
	    --lib-dir     -
	    --include-dir {
		#               ignore 0
		set path [lindex $argv 1]
		set argv [lrange $argv 2 end]
		set key  [string range $o 2 end]
		global paths
		set paths($key) [norm $path]
	    }
	    -- break
	    default {
		puts [Hinstall]
		exit 1
	    }
	}
    }
    return
}
proc norm {path} {
    # normalize smybolic links in the path, including the last element.
    return [file dirname [file normalize [file join $path ...]]]
}
proc query {q c} {
    puts -nonewline "$q ? "
    flush stdout
    set a [string tolower [gets stdin]]
    if {($a ne "y" ) && ($a ne "yes")} {
	puts "$c"
	exit 1
    }
}
proc thisexe {} {
    return [info nameofexecutable]
}
proc wfile {path data} {
    # Easier to write our own copy than requiring fileutil and then using fileutil::writeFile.
    set fd [open $path w]
    puts -nonewline $fd $data
    close $fd
    return
}
proc cat {path} {
    # Easier to write our own copy than requiring fileutil and then using fileutil::cat.
    set fd   [open $path r]
    set data [read $fd]
    close $fd
    return $data
}
proc Hsynopsis {} { return "\n\tGenerate a synopsis of procs and builtin types" }
proc _synopsis {} {
    puts Public:
    puts [exec grep -n ^proc lib/critcl/critcl.tcl \
	      | sed -e "s| \{$||" -e {s/:proc ::critcl::/ /} \
	      | grep -v { [A-Z]} \
	      | grep -v { at::[A-Z]} \
	      | sort -k 2 \
	      | sed -e {s/^/    /}]

    puts Private:
    puts [exec grep -n ^proc lib/critcl/critcl.tcl \
	      | sed -e "s| \{$||" -e {s/:proc ::critcl::/ /} \
	      | grep {[A-Z]} \
	      | sort -k 2 \
	      | sed -e {s/^/    /}]

    puts "Builtin argument types:"
    puts [exec grep -n {    argtype} lib/critcl/critcl.tcl \
	      | grep -v "\\\$ntype" \
	      | sed -e "s| \{$||" -e {s/:[ 	]*argtype/ /} \
	      | sort -k 2 \
	      | sed -e {s/^/    /}]

    puts "Builtin result types:"
    puts [exec grep -n {    resulttype} lib/critcl/critcl.tcl \
	      | sed -e "s| \{$||" -e {s/:[ 	]*resulttype/ /} \
	      | sort -k 2 \
	      | sed -e {s/^/    /}]

    return
}

proc Hhelp {} { return "\n\tPrint this help" }
proc _help {} {
    usage 0
    return
}
proc Hrecipes {} { return "\n\tList all build commands, without details" }
proc _recipes {} {
    set r {}
    foreach c [info commands _*] {
	lappend r [string range $c 1 end]
    }
    puts [lsort -dict $r]
    return
}
proc Htest {} { return "\n\tRun the testsuite" }
proc _test {} {
    global argv
    set    argv {} ;# clear -- tcltest shall see nothing
    # Run all .test files in the test directory.
    set selfdir [file dirname $::me]
    foreach testsuite [lsort -dict [glob -directory [file join $selfdir test] *.test]] {
	puts ""
	puts "_ _ __ ___ _____ ________ _____________ _____________________ *** [file tail $testsuite] ***"
	if {[catch {
	    exec >@ stdout 2>@ stderr [thisexe] $testsuite
	}]} {
	    puts $::errorInfo
	}
    }

    puts ""
    puts "_ _ __ ___ _____ ________ _____________ _____________________"
    puts ""
    return
}
proc Hdoc {} { return "\n\t(Re)Generate the embedded documentation" }
proc _doc {} {
    cd [file join [file dirname $::me] doc]

    puts "Removing old documentation..."
    file delete -force [file join .. embedded man]
    file delete -force [file join .. embedded www]
    file delete -force [file join .. embedded md]

    file mkdir [file join .. embedded man]
    file mkdir [file join .. embedded www]
    file mkdir [file join .. embedded md]

    puts "Generating man pages..."
    exec 2>@ stderr >@ stdout dtplite -ext  n -o [file join .. embedded man] nroff .
    puts "Generating html..."
    exec 2>@ stderr >@ stdout dtplite         -o [file join .. embedded www] html .
    puts "Generating markdown..."
    exec 2>@ stderr >@ stdout dtplite -ext md -o [file join .. embedded md] markdown .

    cd  [file join .. embedded man]
    file delete -force .idxdoc .tocdoc
    cd  [file join .. www]
    file delete -force .idxdoc .tocdoc
    cd  [file join .. md]
    file delete -force .idxdoc .tocdoc

    return
}
proc Htextdoc {} { return "destination\n\tWrite plain text documentation to the specified directory" }
proc _textdoc {dst} {
    set destination [file normalize $dst]

    cd [file join [file dirname $::me] doc]

    puts "Removing old text documentation at ${dst}..."
    file delete -force $destination

    file mkdir $destination

    puts "Generating pages..."
    exec 2>@ stderr >@ stdout dtplite -ext txt -o $destination text .

    cd  $destination
    file delete -force .idxdoc .tocdoc

    return
}
proc Hfigures {} { return "\n\t(Re)Generate the figures and diagrams for the documentation" }
proc _figures {} {
    cd [file join [file dirname $::me] doc figures]

    puts "Generating (tklib) diagrams..."
    eval [linsert [glob *.dia] 0 exec 2>@ stderr >@ stdout dia convert -t -o . png]

    return
}
proc Hrelease {} { return "\n\tGenerate a release from the current commit.\n\tAssumed to be properly tagged.\n\tLeaves checkout in the gh-pages branch, ready for commit+push" }
proc _release {} {
    # # ## ### ##### ######## #############
    # Get scratchpad to assemble the release in.
    # Get version and hash of the commit to be released.

    query "Have you run the tests"              "Please do"
    query "Have you run the examples"           "Please do"
    query "Have you bumped the version numbers" "Came back after doing so!"

    set tmpdir [tmpdir]
    id commit version

    savedoc $tmpdir

    # # ## ### ##### ######## #############
    #puts {Generate starkit...}
    #_starkit [file join $tmpdir critcl31.kit]

    # # ## ### ##### ######## #############
    #puts {Collecting starpack prefix...}
    # which we use the existing starpack for, from the gh-pages branch

    #exec 2>@ stderr >@ stdout git checkout gh-pages
    #file copy [file join download critcl31.exe] [file join $tmpdir prefix.exe]
    #exec 2>@ stderr >@ stdout git checkout $commit

    # # ## ### ##### ######## #############
    #puts {Generate starpack...}
    #_starpack [file join $tmpdir prefix.exe] [file join $tmpdir critcl31.exe]
    # TODO: vacuum the thing. fix permissions if so.

    # # ## ### ##### ######## #############
    2website
    placedoc $tmpdir

    #file copy -force [file join $tmpdir critcl31.kit] [file join download critcl31.kit]
    #file copy -force [file join $tmpdir critcl31.exe] [file join download critcl31.exe]

    set index   [cat index.html]
    set pattern   "\\\[commit .*\\\] \\(v\[^)\]*\\)<!-- current"
    set replacement "\[commit $commit\] (v$version)<!-- current"
    regsub $pattern $index $replacement index
    wfile index.html $index

    # # ## ### ##### ######## #############
    reminder $commit

    # # ## ### ##### ######## #############
    return
}
proc Hrelease-doc {} { return "\n\tUpdate the release documentation from the current commit.\n\tAssumed to be properly tagged.\n\tLeaves the checkout in the gh-pages branch, ready for commit+push" }
proc _release-doc {} {
    # # ## ### ##### ######## #############
    # Get scratchpad to assemble the release in.
    # Get version and hash of the commit to be released.

    set tmpdir [tmpdir]
    id _ commit ; # Just for the printout, we are actually not using the data.

    savedoc $tmpdir
    2website
    placedoc $tmpdir
    reminder $commit

    # # ## ### ##### ######## #############
    return
}

proc Hdirs {} { return "[Ioptions]\n\tShow directory setup" }
proc _dirs args {
    process-install-options

    puts "destdir     = [dest-dir]"
    puts "prefix      = [dest-dir][prefix]"
    puts "exec-prefix = [dest-dir][exec-prefix]"
    puts "bin-dir     = [dest-dir][bin-dir]"
    puts "lib-dir     = [dest-dir][lib-dir]"
    puts "include-dir = [dest-dir][include-dir]"
    puts ""
    return
}

proc Ioptions {} { return "?--dest-dir path? ?--prefix path? ?--exec-prefix path? ?--bin-dir path? ?--lib-dir path? ?--include-dir path?" }

proc Htargets {} { return "[Ioptions]\n\tShow available targets.\n\tExpects critcl app to be installed in the \"--bin-dir\" derived from the options and defaults" }
proc _targets args {
    process-install-options
    set dsta [dest-dir][bin-dir]
    puts [join [split [exec [file join $dsta critcl] -targets]] \n]
    return
}

proc Hinstall {} { return "?-target T? [Ioptions]\n\tInstall all packages, and application.\n\tDefault --prefix is \"\$(dirname \$(dirname /path/to/tclsh))\"" }
proc _install {args} {
    global packages me

    set target {}

    process-install-options

    set dsta [dest-dir][bin-dir]
    set dstl [dest-dir][lib-dir]
    set dsti [dest-dir][include-dir]

    set selfdir [file dirname $me]

    puts {Installing into:}
    puts \tPackages:\t$dstl
    puts \tApplication:\t$dsta
    puts \tHeaders:\t$dsti

    file mkdir $dsta $dsti

    if {[catch {
	# Create directories, might not exist.
	file mkdir $dstl
	file mkdir $dsta
	set prefix \n
	foreach item $packages {
	    # Package: /name/

	    if {[llength $item] == 3} {
		foreach {dir vfile name} $item break
	    } elseif {[llength $item] == 1} {
		set dir   $item
		set vfile {}
		set name  $item
	    } else {
		foreach {dir vfile} $item break
		set name $dir
	    }

	    if {$vfile ne {}} {
		set version [version [vfile $dir $vfile]]
	    } else {
		set version {}
	    }

	    set namevers [file join $dstl [pkgdirname $name $version]]

	    file copy -force [file join $selfdir lib $dir] [file join $dstl ${name}-new]
	    file delete -force $namevers
	    puts "${prefix}Installed package:      $namevers"
	    file rename [file join $dstl ${name}-new] $namevers
	    set prefix {}
	}

	# Application: critcl

	set theapp  [critapp     $dsta]
	set reldstl [relativedir $dstl $theapp]

	set c [open $theapp w]
	lappend map @bs@      "\\"
	lappend map @exe@     [shquote [norm [thisexe]]]
	lappend map @relpath@ [file split $reldstl]  ;# insert the dst path
	lappend map "\t    " {}     ;# de-dent
	lappend map "\t\t"   {    } ;# de-dent
	puts $c [string trimleft [string map $map {
	    #!/bin/sh
	    # -*-tcl -*-
	    # hide next line from tcl @bs@
	    exec @exe@ "$0" ${1+"$@"}

	    # Add location of critcl packages to the package load path, if not
	    # yet present. Computed relative to the location of the application,
	    # as per the installation paths.
	    set libpath [file join [file dirname [info script]] @relpath@]
	    set libpath [file dirname [file normalize [file join $libpath ...]]]
	    if {[lsearch -exact $auto_path $libpath] < 0} {
		set auto_path [linsert $auto_path[set auto_path {}] 0 $libpath]
	    }
	    unset libpath

	    package require critcl::app
	    critcl::app::main $argv}]]
	close $c
	+x $theapp

	puts "${prefix}Installed application:  $theapp"

	# C packages - Need major Tcl version
	set major [lindex [split [info patchlevel] .] 0]

	# Special package: critcl_md5c
	# Local MD5 hash implementation.

	puts "\nInstalled C package:\tcritcl::md5c"

	# It is special because it is a critcl-based package, not pure
	# Tcl as everything else of critcl. Its installation makes it
	# the first package which will be compiled with critcl on this
	# machine. It uses the just-installed application for
	# that. This is package-mode, where MD5 itself is not used, so
	# there is no chicken vs. egg.

	set src     [file join $selfdir lib critcl-md5c md5c.tcl]
	set version [version $src]
	set name    critcl_md5c_tcl$major
	set dst     [file join $dstl [pkgdirname $name $version]]
	set cmd     {}

	lappend cmd exec >@ stdout 2>@ stderr
	lappend cmd [thisexe]
	lappend cmd $theapp
	if {$target ne {}} {
	    lappend cmd -target $target
	}
	lappend cmd -libdir [file join $dstl tmp] -pkg $src
	puts [list executing $cmd]
	eval $cmd

	file delete -force $dst
	file rename        [file join $dstl tmp md5c] $dst
	file delete -force [file join $dstl tmp]

	puts "${prefix}Installed package:      $dst"

	# Special package: critcl::callback
	# C/Tcl callback utility code.

	puts "\nInstalled C package:\tcritcl::callback"

	# It is special because it is a critcl-based package, not pure
	# Tcl as everything else of critcl. Its installation makes it
	# the second package which will be compiled with critcl on this
	# machine. It uses the just-installed application for
	# that.

	set src     [file join $selfdir lib critcl-callback callback.tcl]
	set version [version $src]
	set name    critcl_callback_tcl$major
	set dst     [file join $dstl [pkgdirname $name $version]]
	set dsth    [file join $dsti critcl_callback] ;# headers unversioned
	set cmd     {}

	lappend cmd exec >@ stdout 2>@ stderr
	lappend cmd [thisexe]
	lappend cmd $theapp
	if {$target ne {}} {
	    lappend cmd -target $target
	}
	set dstl_tmp [file join $dstl tmp]
	lappend cmd -libdir     $dstl_tmp
	lappend cmd -includedir $dstl_tmp
	lappend cmd -pkg $src
	eval $cmd

	file delete -force $dst $dsth
	file rename  [file join $dstl tmp callback] $dst
	file rename  [file join $dstl tmp critcl_callback] $dsth
	file delete -force $dstl_tmp

	puts "${prefix}Installed package:      $dst"
	puts "${prefix}Installed headers:      [
	    file join $dsti critcl_callback]"

    } msg]} {
	if {![string match {*permission denied*} $msg]} {
	    return -code error -errorcode $::errorCode -errorinfo $::errorInfo $msg
	}
	puts stderr "\n$msg\n\nUse 'sudo' or some other way of running the operation under the user having access to the destination paths.\n"
	exit
    }
    return
}
proc Huninstall {} { Hdrop }
proc _uninstall {args} { eval [linsert $args 0 _drop] }

proc Hdrop {} { return "[Ioptions]\n\tRemove packages" }
proc _drop {args} {
    global packages me

    process-install-options

    set dsta [dest-dir][bin-dir]
    set dstl [dest-dir][lib-dir]
    set dsti [dest-dir][include-dir]

    # C packages - Need major Tcl version
    set major [lindex [split [info patchlevel] .] 0]

    # Add the special packages (see install). Not special with regard
    # to removal. Except for the name
    lappend packages [list critcl-md5c     md5c.tcl     critcl_md5c_tcl$major]
    lappend packages [list critcl-callback callback.tcl critcl_callback_tcl$major]

    set selfdir [file dirname $me]

    foreach item $packages {
	# Package: /name/

	if {[llength $item] == 3} {
	    foreach {dir vfile name} $item break
	} elseif {[llength $item] == 1} {
	    set dir   $item
	    set vfile {}
	    set name  $item
	} else {
	    foreach {dir vfile} $item break
	    set name $dir
	}

	if {$vfile ne {}} {
	    set version [version [vfile $dir $vfile]]
	} else {
	    set version {}
	}

	set namevers [file join $dstl [pkgdirname $name $version]]

	file delete -force $namevers
	puts "Removed package:     $namevers"
    }

    # Application: critcl
    set theapp [critapp $dsta]
    file delete $theapp
    puts "Removed application: $theapp"

    # Includes/Headers (critcl::callback)
    set dsth    [file join $dsti critcl_callback]
    file delete -force $dsth
    puts "Removed headers:     $dsth"

    return
}
proc Hstarkit {} { return "?destination? ?interpreter?\n\tGenerate a starkit\n\tdestination = path of result file, default 'critcl.kit'\n\tinterpreter = (path) name of tcl shell to use for execution, default 'tclkit'" }
proc _starkit {{dst critcl.kit} {interp tclkit}} {
    package require vfs::mk4

    set c [open $dst wb]
    puts -nonewline $c "#!/bin/sh\n# -*- tcl -*- \\\nexec $interp \"\$0\" \$\{1+\"\$@\"\}\npackage require starkit\nstarkit::header mk4 -readonly\n\032################################################################################################################################################################"
    close $c

    vfs::mk4::Mount $dst /KIT
    file copy -force lib /KIT
    file copy -force main.tcl /KIT
    vfs::unmount /KIT
    +x $dst

    puts "Created starkit: $dst"
    return
}
proc Hstarpack {} { return "prefix ?destination?\n\tGenerate a fully-selfcontained executable, i.e. a starpack\n\tprefix      = path of tclkit/basekit runtime to use\n\tdestination = path of result file, default 'critcl'" }
proc _starpack {prefix {dst critcl}} {
    package require vfs::mk4

    file copy -force $prefix $dst

    vfs::mk4::Mount $dst /KIT
    file mkdir [file join /KIT lib]

    foreach d [glob -directory lib *] {
	file delete -force  [file join /KIT lib [file tail $d]]
	file copy -force $d [file join /KIT lib]
    }

    file copy -force main.tcl /KIT
    vfs::unmount /KIT
    +x $dst

    puts "Created starpack: $dst"
    return
}
proc Hexamples {} { return "?args...?\n\tWithout arguments, list the examples.\n\tOtherwise run the recipe with its arguments on the examples" }
proc _examples {args} {
    global me
    set selfdir [file dirname $me]
    set self    [file tail    $me]

    # List examples, or run the build code on the examples, passing any arguments.

    set examples [lsort -dict [glob -directory [file join $selfdir examples] */$self]]

    puts ""
    if {![llength $args]} {
	foreach b $examples {
	    puts "* [file dirname $b]"
	}
    } else {
	foreach b $examples {
	    puts "$b _______________________________________________"
	    eval [linsert $args 0 exec 2>@ stderr >@ stdout [thisexe] $b]
	    puts ""
	    puts ""
	}
    }
    return
}
main
