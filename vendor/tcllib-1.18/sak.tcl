#!/bin/sh
# -*- tcl -*- \
exec tclsh "$0" ${1+"$@"}

# --------------------------------------------------------------
# Perform various checks and operations on the distribution.
# SAK = Swiss Army Knife.

set distribution   [file dirname [info script]]
set auto_path      [linsert $auto_path 0 [file join $distribution modules]]

set critcldefault {}
set critclnotes   {}
set dist_excluded {}

proc package_name    {text} {global package_name    ; set package_name    $text}
proc package_version {text} {global package_version ; set package_version $text}
proc dist_exclude    {path} {global dist_excluded   ; lappend dist_excluded $path}
proc critcl {name files} {
    global critclmodules
    set    critclmodules($name) $files
    return
}
proc critcl_main {name files} {
    global critcldefault
    set critcldefault $name
    critcl $name $files
    return
}
proc critcl_notes {text} {
    global critclnotes
    set critclnotes [string map {{\n    } \n} $text]
    return
}

source [file join $distribution support installation version.tcl] ; # Get version information.

set package_nv ${package_name}-${package_version}

catch {eval file delete -force [glob [file rootname [info script]].tmp.*]}

# --------------------------------------------------------------
# SAK internal debugging support.

# Configuration, change as needed
set  debug 0

if {$debug} {
    proc sakdebug {script} {uplevel 1 $script ; return}
} else {
    proc sakdebug {args} {}
}

# --------------------------------------------------------------
# Internal helper to load packages straight out of the local directory
# tree. Not something from an installation, possibly incompatible.

proc getpackage {package tclmodule} {
    global distribution
    if {[catch {package present $package}]} {
	set src [file join \
		$distribution modules \
		$tclmodule]
	if {[file exists $src]} {
	    uplevel #0 [list source $src]
	} else {
	    # Fallback
	    package require $package
	}
    }
}

# --------------------------------------------------------------

proc tclfiles {} {
    global distribution
    getpackage fileutil fileutil/fileutil.tcl
    set fl [fileutil::findByPattern $distribution -glob *.tcl]
    # Remove files under SCCS. They are repository, not sources to check.
    set tmp {}
    foreach f $fl {
	if {[string match *SCCS* $f]} continue
	lappend tmp $f
    }
    proc tclfiles {} [list return $tmp]
    return $tmp
}

proc modtclfiles {modules} {
    global mfiles guide
    load_modinfo
    set mfiles [list]
    foreach m $modules {
	eval $guide($m,pkg) $m __dummy__
    }
    return $mfiles
}

proc modules {} {
    global distribution
    set fl [list]
    foreach f [glob -nocomplain [file join $distribution modules *]] {
	if {![file isdirectory $f]} {continue}
	if {[string match CVS [file tail $f]]} {continue}

	if {![file exists [file join $f pkgIndex.tcl]]} {continue}

	lappend fl [file tail $f]
    }
    set fl [lsort $fl]
    proc modules {} [list return $fl]
    return $fl
}

proc modules_mod {m} {
    return [expr {[lsearch -exact [modules] $m] >= 0}]
}

proc dealias {modules} {
    set _ {}
    foreach m $modules {
	if {[file exists $m]} {
	    set m [file tail $m]
	}
	lappend _ $m
    }
    return $_
}

proc load_modinfo {} {
    global distribution modules guide
    source [file join $distribution support installation modules.tcl] ; # Get list of installed modules.
    source [file join $distribution support installation actions.tcl] ; # Get installer support code.
    proc load_modinfo {} {}
    return
}

proc imodules {} {global modules ; load_modinfo ; return $modules}

proc imodules_mod {m} {
    global modules
    load_modinfo
    return [expr {[lsearch -exact $modules $m] > 0}]
}

# Result: dict (package name --> list of package versions).

proc loadpkglist {fname} {
    set f [open $fname r]
    foreach line [split [read $f] \n] {
	set line [string trim $line]
	if {[string match @* $line]} continue
	if {$line == {}} continue
	foreach {n v} $line break
	lappend p($n) $v
	set p($n) [lsort -uniq -dict $p($n)]
    }
    close $f
    return [array get p]
}

# Result: dict (package name => list of (list of package versions, module)).

proc ipackages {args} {
    # Determine indexed packages (ifneeded, pkgIndex.tcl)

    global distribution

    if {[llength $args] == 0} {set args [modules]}

    array set p {}
    foreach m $args {
	set f [open [file join $distribution modules $m pkgIndex.tcl] r]
	foreach line [split [read $f] \n] {
	    if { [regexp {#}        $line]} {continue}
	    if {![regexp {ifneeded} $line]} {continue}
	    regsub {^.*ifneeded } $line {} line
	    regsub {([0-9]) \[.*$}  $line {\1} line

	    foreach {n v} $line break
	    set v [string trimright $v \\]

	    if {![info exists p($n)]} {
		set p($n) [list $v $m]
	    } else {
		# We have multiple versions of the same package. We
		# remember all versions.

		foreach {vlist mx} $p($n) break
		lappend vlist $v
		set p($n) [list [lsort -uniq -dict $vlist] $mx]
	    }
	}
	close $f
    }
    return [array get p]
}


# Result: dict (package name --> list of package versions).

proc ppackages {args} {
    # Determine provided packages (provide, *.tcl - pkgIndex.tcl)
    # We cache results for a bit of speed, some stuff uses this
    # multiple times for the same arguments.

    global ppcache
    if {[info exists ppcache($args)]} {
	return $ppcache($args)
    }

    global    p pf currentfile
    array set p {}

    if {[llength $args] == 0} {
	set files [tclfiles]
    } else {
	set files [modtclfiles $args]
    }

    getpackage fileutil fileutil/fileutil.tcl
    set capout [fileutil::tempfile] ; set capcout [open $capout w]
    set caperr [fileutil::tempfile] ; set capcerr [open $caperr w]

    array set notprovided {}

    foreach f $files {
	# We ignore package indices and all files not in a module.

	if {[string equal pkgIndex.tcl [file tail $f]]} {continue}
	if {![regexp modules $f]}                       {continue}

	# We use two methods to extract the version information from a
	# module and its packages. First we do a static scan for
	# appropriate statements. If that did not work out we try to
	# execute the script in a modified interpreter which lets us
	# pick up dynamically generated version data (like stored in
	# variables). If the second method fails as well we give up.

	# Method I. Static scan.

	# We do heuristic scanning of the code to locate suitable
	# package provide statements.

	set fh [open $f r]

	set currentfile [eval file join [lrange [file split $f] end-1 end]]

	set ok -1
	foreach line [split [read $fh] \n] {
	    if {[regexp "\#\\s*@sak\\s+notprovided\\s+(\[^\\s\]+)" $line -> nppname]} {
		sakdebug {puts stderr "PRAGMA notprovided = $nppname"}
		set notprovided($nppname) .
	    }

	    regsub "\#.*$" $line {} line
	    if {![regexp {provide} $line]} {continue}
	    if {![regexp {package} $line]} {continue}

	    # Now a stronger check for the actual command
	    if {![regexp {package[ 	][ 	]*provide} $line]} {continue}

	    set xline $line
	    regsub {^.*provide } $line {} line
	    regsub {\].*$}       $line {\1} line

	    sakdebug {puts stderr __$f\ _________$line}

	    foreach {n v} $line break

	    # HACK ...
	    # Module 'page', package 'page::gen::peg::cpkg'.
	    # Has a provide statement inside a template codeblock.
	    # Name is placeholder @@. Ignore this specific name.
	    # Better would be to use general static Tcl parsing
	    # to find that the string is a variable value.

	    if {[string equal $n @@]} continue

	    if {[regexp {^[0-9]+(\.[0-9]+)*$} $v]} {
		lappend p($n) $v
		set p($n) [lsort -uniq -dict $p($n)]
		set pf($n,$v) $currentfile
		set ok 1

		# We continue the scan. The file may provide several
		# versions of the same package, or multiple packages.
		continue
	    }

	    # 'package provide foo' are tests. Ignore.
	    if {$v == ""} continue

	    # We do not set the state to bad if we found ok provide
	    # statements before, only if nothing was found before.
	    if {$ok < 0} {
		set ok 0

		# No good version found on the current line. We scan
		# further through the file and hope for more luck.

		sakdebug {puts stderr @_$f\ _________$xline\t<$n>\t($v)}
	    }
	}
	close $fh

	# Method II. Restricted Execution.
	# We now try to run the code through a safe interpreter
	# and hope for better luck regarding package information.

	if {$ok == -1} {sakdebug {puts stderr $f\ IGNORE}}
	if {$ok == 0} {
	    sakdebug {puts -nonewline stderr $f\ EVAL}

	    # Source the code into a sub-interpreter. The sub
	    # interpreter overloads 'package provide' so that the
	    # information about new packages goes directly to us. We
	    # also make sure that the sub interpreter doesn't kill us,
	    # and will not get stuck early by trying to load other
	    # files, or when creating procedures in namespaces which
	    # do not exist due to us disabling most of the package
	    # management.

	    set fh [open $f r]

	    set ip [interp create]

	    # Kill control structures. Namespace is required, but we
	    # skip everything related to loading of packages,
	    # i.e. 'command import'.

	    $ip eval {
		rename ::if        ::_if_
		rename ::namespace ::_namespace_

		proc ::if {args} {}
		proc ::namespace {cmd args} {
		    #puts stderr "_nscmd_ $cmd"
		    ::_if_ {[string equal $cmd import]} return
		    #puts stderr "_nsdo_ $cmd $args"
		    return [uplevel 1 [linsert $args 0 ::_namespace_ $cmd]]
		}
	    }

	    # Kill more package stuff, and ensure that unknown
	    # commands are neither loaded nor abort execution. We also
	    # stop anything trying to kill the application at large.

	    interp alias $ip package {} xPackage
	    interp alias $ip source  {} xNULL
	    interp alias $ip unknown {} xNULL
	    interp alias $ip proc    {} xNULL
	    interp alias $ip exit    {} xNULL

	    # From here on no redefinitions anymore, proc == xNULL !!

	    $ip eval {close stdout} ; interp share {} $capcout $ip
	    $ip eval {close stderr} ; interp share {} $capcerr $ip

	    if {[catch {$ip eval [read $fh]} msg]} {
		sakdebug {puts stderr "ERROR in $currentfile:\n$::errorInfo\n"}
	    }

	    sakdebug {puts stderr ""}

	    close $fh
	    interp delete $ip
	}
    }

    close $capcout ; file delete $capout
    close $capcerr ; file delete $caperr

    # Process the accumulated pragma information, remove all the
    # packages which exist but not really, in terms of indexing.

    foreach n [array names notprovided] {
	catch { unset p($n) }
	array unset pf $n,*
    }

    set   pp [array get p]
    unset p

    set ppcache($args) $pp
    return $pp 
}

proc xNULL    {args} {}
proc xPackage {cmd args} {
    if {[string equal $cmd provide]} {
	global p pf currentfile
	foreach {n v} $args break

	# No version specified, this is an inquiry, we ignore these.
	if {$v == {}} {return}

	sakdebug {puts stderr \tOK\ $n\ =\ $v}

	lappend p($n) $v
	set p($n) [lsort -uniq -dict $p($n)]
	set pf($n,$v) $currentfile
    }
    return
}

proc sep {} {puts ~~~~~~~~~~~~~~~~~~~~~~~~}

proc gd-cleanup {} {
    global package_nv

    puts {Cleaning up...}

    set        fl [glob -nocomplain ${package_nv}*]
    foreach f $fl {
	puts "    Deleting $f ..."
	catch {file delete -force $f}
    }
    return
}

proc gd-gen-archives {} {
    global package_name package_nv

    puts {Generating archives...}

    set tar [auto_execok tar]
    if {$tar != {}} {
        puts "    Gzipped tarball (${package_nv}.tar.gz)..."
        catch {
            exec $tar cf - ${package_nv} | gzip --best > ${package_nv}.tar.gz
        }

        set bzip [auto_execok bzip2]
        if {$bzip != {}} {
            puts "    Bzipped tarball (${package_nv}.tar.bz2)..."
            exec tar cf - ${package_nv} | bzip2 > ${package_nv}.tar.bz2
        }
    }

    set zip [auto_execok zip]
    if {$zip != {}} {
        puts "    Zip archive     (${package_nv}.zip)..."
        catch {
            exec $zip -r ${package_nv}.zip ${package_nv}
        }
    }

    set sdx [auto_execok sdx]
    if {$sdx != {}} {
	file copy -force [file join ${package_nv} support installation main.tcl] \
		[file join ${package_nv} main.tcl]
	file rename ${package_nv} ${package_name}.vfs

	puts "    Starkit         (${package_nv}.kit)..."
	exec sdx wrap ${package_name}
	file rename   ${package_name} ${package_nv}.kit

	if {![file exists tclkit]} {
	    puts "    No tclkit present in current working directory, no starpack."
	} else {
	    puts "    Starpack        (${package_nv}.exe)..."
	    exec sdx wrap ${package_name} -runtime tclkit
	    file rename   ${package_name} ${package_nv}.exe
	}

	file rename ${package_name}.vfs ${package_nv}
    }

    puts {    Keeping directory for other archive types}

    ## Keep the directory for 'sdx' - kit/pack
    return
}

proc xcopyfile {src dest} {
    # dest can be dir or file
    global  mfiles
    lappend mfiles $src
    return
}

proc xcopy {src dest recurse {pattern *}} {
    if {[string equal $pattern *] || !$recurse} {
	foreach file [glob [file join $src $pattern]] {
	    set base [file tail $file]
	    set sub  [file join $dest $base]
	    if {0 == [string compare CVS $base]} {continue}
	    if {[file isdirectory $file]} then {
		if {$recurse} {
		    xcopy $file $sub $recurse $pattern
		}
	    } else {
		xcopyfile $file $sub
	    }
	}
    } else {
	foreach file [glob [file join $src *]] {
	    set base [file tail $file]
	    set sub  [file join $dest $base]
	    if {[string equal CVS $base]} {continue}
	    if {[file isdirectory $file]} then {
		if {$recurse} {
		    xcopy $file $sub $recurse $pattern
		}
	    } else {
		if {![string match $pattern $base]} {continue}
		xcopyfile $file $sub
	    }
	}
    }
}

proc xxcopy {src dest recurse {pattern *}} {
    global package_name

    file mkdir $dest
    foreach file [glob -nocomplain [file join $src $pattern]] {
        set base [file tail $file]
	set sub  [file join $dest $base]

	# Exclude CVS, SCCS, ... automatically, and possibly the temp
	# hierarchy itself too.

	if {0 == [string compare CVS        $base]} {continue}
	if {0 == [string compare SCCS       $base]} {continue}
	if {0 == [string compare BitKeeper  $base]} {continue}
	if {[string match ${package_name}-* $base]} {continue}
	if {[string match *~                $base]} {continue}

        if {[file isdirectory $file]} then {
	    if {$recurse} {
		file mkdir  $sub
		xxcopy $file $sub $recurse $pattern
	    }
        } else {
	    puts -nonewline stdout . ; flush stdout
            file copy -force $file $sub
        }
    }
}

proc gd-assemble {} {
    global package_nv distribution dist_excluded

    puts "Assembling distribution in directory '${package_nv}'"

    xxcopy $distribution ${package_nv} 1

    foreach f $dist_excluded {
	file delete -force [file join $package_nv $f]
    }
    puts ""
    return
}

proc normalize-version {v} {
    # Strip everything after the first non-version character, and any
    # trailing dots left behind by that, to avoid the insertion of bad
    # version numbers into the generated .tap file.

    regsub {[^0-9.].*$} $v {} v
    return [string trimright $v .]
}

proc gd-gen-tap {} {
    getpackage textutil textutil/textutil.tcl
    getpackage fileutil fileutil/fileutil.tcl

    global package_name package_version distribution tcl_platform

    set pname [textutil::cap $package_name]

    set modules   [imodules]
    array set pd  [getpdesc]
    set     lines [list]
    # Header
    lappend lines {format  {TclDevKit Project File}}
    lappend lines {fmtver  2.0}
    lappend lines {fmttool {TclDevKit TclApp PackageDefinition} 2.5}
    lappend lines {}
    lappend lines "##  Saved at : [clock format [clock seconds]]"
    lappend lines "##  By       : $tcl_platform(user)"
    lappend lines {##}
    lappend lines "##  Generated by \"[file tail [info script]] tap\""
    lappend lines "##  of $package_name $package_version"
    lappend lines {}
    lappend lines {########}
    lappend lines {#####}
    lappend lines {###}
    lappend lines {##}
    lappend lines {#}

    # Bundle definition
    lappend lines {}
    lappend lines {# ###############}
    lappend lines {# Complete bundle}
    lappend lines {}
    lappend lines [list Package [list $package_name [normalize-version $package_version]]]
    lappend lines "Base     @TAP_DIR@"
    lappend lines "Platform *"
    lappend lines "Desc     \{$pname: Bundle of all packages\}"
    lappend lines "Path     pkgIndex.tcl"
    lappend lines "Path     [join $modules "\nPath     "]"

    set  strip [llength [file split $distribution]]
    incr strip 2

    foreach m $modules {
	# File set of module ...

	lappend lines {}
	lappend lines "# #########[::textutil::strRepeat {#} [string length $m]]" ; # {}
	lappend lines "# Module \"$m\""
	set n 0
	foreach {p vlist} [ppackages $m] {
	    foreach v $vlist {
		lappend lines "# \[[format %1d [incr n]]\]    | \"$p\" ($v)"
	    }
	}
	if {$n > 1} {
	    # Multiple packages (*). We create one hidden package to
	    # contain all the files and then have all the true
	    # packages in the module refer to it.
	    #
	    # (*) This can also be one package for which we have
	    # several versions. Or a combination thereof.

	    array set _ {}
	    foreach {p vlist} [ppackages $m] {
		catch {set _([lindex $pd($p) 0]) .}
	    }
	    set desc [string trim [join [array names _] ", "] " \n\t\r,"]
	    if {$desc == ""} {set desc "$pname module"}
	    unset _

	    lappend lines "# -------+"
	    lappend lines {}
	    lappend lines [list Package [list __$m 0.0]]
	    lappend lines "Platform *"
	    lappend lines "Desc     \{$desc\}"
	    lappend lines Hidden
	    lappend lines "Base     @TAP_DIR@/$m"

	    foreach f [lsort -dict [modtclfiles $m]] {
		lappend lines "Path     [fileutil::stripN $f $strip]"
	    }

	    # Packages in the module ...
	    foreach {p vlist} [ppackages $m] {
		# NO DANGER. As we are listing only the packages P for
		# the module any other version of P in a different
		# module is _not_ listed here.

		set desc ""
		catch {set desc [string trim [lindex $pd($p) 1]]}
		if {$desc == ""} {set desc "$pname package"}

		foreach v $vlist {
		    lappend lines {}
		    lappend lines [list Package [list $p [normalize-version $v]]]
		    lappend lines "See   [list __$m]"
		    lappend lines "Platform *"
		    lappend lines "Desc     \{$desc\}"
		}
	    }
	} else {
	    # A single package in the module. And only one version of
	    # it as well. Otherwise we are in the multi-pkg branch.

	    foreach {p vlist} [ppackages $m] break
	    set desc ""
	    catch {set desc [string trim [lindex $pd($p) 1]]}
	    if {$desc == ""} {set desc "$pname package"}

	    set v [lindex $vlist 0]

	    lappend lines "# -------+"
	    lappend lines {}
	    lappend lines [list Package [list $p [normalize-version $v]]]
	    lappend lines "Platform *"
	    lappend lines "Desc     \{$desc\}"
	    lappend lines "Base     @TAP_DIR@/$m"

	    foreach f [lsort -dict [modtclfiles $m]] {
		lappend lines "Path     [fileutil::stripN $f $strip]"
	    }
	}
	lappend lines {}
	lappend lines {#}
	lappend lines "# #########[::textutil::strRepeat {#} [string length $m]]"
    }

    lappend lines {}
    lappend lines {#}
    lappend lines {##}
    lappend lines {###}
    lappend lines {#####}
    lappend lines {########}

    # Write definition
    set    f [open [file join $distribution ${package_name}.tap] w]
    puts  $f [join $lines \n]
    close $f
    return
}

proc getpdesc  {} {
    global argv ; if {![checkmod]} return

    package require sak::doc
    sak::doc::Gen desc l $argv
    
    array set _ {}
    foreach file [glob -nocomplain doc/desc/*.l] {
        set f [open $file r]
	foreach l [split [read $f] \n] {
	    foreach {p sd d} $l break
	    set _($p) [list $sd $d]
	}
        close $f
    }
    file delete -force doc/desc

    return [array get _]
}

proc gd-gen-rpmspec {} {
    global package_version package_name distribution

    set in  [file join $distribution support releases package_rpm.txt]
    set out [file join $distribution ${package_name}.spec]

    write_out $out [string map \
			[list \
			     @PACKAGE_VERSION@ $package_version \
			     @PACKAGE_NAME@    $package_name] \
			[get_input $in]]
    return
}

proc gd-gen-yml {} {
    # YAML is the format used for the FreePAN archive network.
    # http://freepan.org/

    global package_version package_name distribution

    set in  [file join $distribution support releases package_yml.txt]
    set out [file join $distribution ${package_name}.yml]

    write_out $out [string map \
			[list \
			     @PACKAGE_VERSION@ $package_version \
			     @PACKAGE_NAME@    $package_name] \
			[get_input $in]]
    return
}

proc docfiles {} {
    global distribution

    getpackage fileutil fileutil/fileutil.tcl

    set res [list]
    foreach f [fileutil::findByPattern $distribution -glob *.man] {
	# Remove files under SCCS. They are repository, not sources to check.
	if {[string match *SCCS* $f]} continue
	lappend res [file rootname [file tail $f]].n
    }
    proc docfiles {} [list return $res]
    return $res
}

proc gd-tip55 {} {
    global package_version package_name distribution contributors
    contributors

    set in  [file join $distribution support releases package_tip55.txt]
    set out [file join $distribution DESCRIPTION.txt]

    set md [string map \
		[list \
		     @PACKAGE_VERSION@ $package_version \
		     @PACKAGE_NAME@    $package_name] \
		[get_input $in]]

    foreach person [lsort [array names contributors]] {
        set mail $contributors($person)
        regsub {@}  $mail " at " mail
        regsub -all {\.} $mail " dot " mail
        append md "Contributor: $person <$mail>\n"
    }

    write_out $out $md
    return
}

# Fill the global array of contributors to the bundle by processing
# the ChangeLog entries.
#
proc contributors {} {
    global distribution contributors
    if {![info exists contributors] || [array size contributors] == 0} {
        get_contributors [file join $distribution ChangeLog]

        foreach f [glob -nocomplain [file join $distribution modules *]] {
            if {![file isdirectory $f]} {continue}
            if {[string match CVS [file tail $f]]} {continue}
            if {![file exists [file join $f ChangeLog]]} {continue}
            get_contributors [file join $f ChangeLog]
        }
    }
}

proc get_contributors {changelog} {
    global contributors
    set f [open $changelog r]
    while {![eof $f]} {
        gets $f line
        if {[regexp {^[\d-]+\s+(.*?)<(.*?)>} $line r name mail]} {
            set name [string trim $name]
            if {![info exists names($name)]} {
                set contributors($name) $mail
            }
        }
    }
    close $f
}

proc validate_imodules_cmp {imvar dmvar} {
    upvar $imvar im $dmvar dm

    foreach m [lsort [array names im]] {
	if {![info exists dm($m)]} {
	    puts "  Installed, does not exist: $m"
	}
    }
    foreach m [lsort [array names dm]] {
	if {![info exists im($m)]} {
	    puts "  Missing in installer:      $m"
	}
    }
    return
}

proc validate_imodules {} {
    foreach m [imodules] {set im($m) .}
    foreach m [modules]  {set dm($m) .}

    validate_imodules_cmp im dm
    return
}

proc validate_imodules_mod {m} {
    array set im {}
    array set dm {}
    if {[imodules_mod $m]} {set im($m) .}
    if {[modules_mod  $m]} {set dm($m) .}

    validate_imodules_cmp im dm
    return
}
proc validate_versions_cmp {ipvar ppvar} {
    global pf
    getpackage struct::set struct/sets.tcl

    upvar $ipvar ip $ppvar pp
    set maxl 0
    foreach name [array names ip] {if {[string length $name] > $maxl} {set maxl [string length $name]}}
    foreach name [array names pp] {if {[string length $name] > $maxl} {set maxl [string length $name]}}

    foreach p [lsort [array names ip]] {
	if {![info exists pp($p)]} {
	    puts "  Indexed, no provider:           $p"
	}
    }
    foreach p [lsort [array names pp]] {
	if {![info exists ip($p)]} {
	    foreach k [array names pf $p,*] {
		puts "  Provided, not indexed:          [format "%-*s | %s" $maxl $p $pf($k)]"
	    }
	}
    }
    foreach p [lsort [array names ip]] {
	if {![info exists pp($p)]}               continue
	if {[struct::set equal $pp($p) $ip($p)]} continue

	# Compute intersection and set differences.
	foreach {__ pmi imp} [struct::set intersect3 $pp($p) $ip($p)] break

	puts "  Index/provided versions differ: [format "%-*s | %8s | %8s" $maxl $p $imp $pmi]"
    }
}

proc validate_versions {} {
    foreach {p vm}    [ipackages] {set ip($p) [lindex $vm 0]}
    foreach {p vlist} [ppackages] {set pp($p) $vlist}

    validate_versions_cmp ip pp
    return
}

proc validate_versions_mod {m} {
    foreach {p vm}    [ipackages $m] {set ip($p) [lindex $vm 0]}
    foreach {p vlist} [ppackages $m] {set pp($p) $vlist}

    validate_versions_cmp ip pp
    return
}

proc validate_testsuite_mod {m} {
    global distribution
    if {[llength [glob -nocomplain [file join $distribution modules $m *.test]]] == 0} {
	puts "  Without testsuite : $m"
    }
    return
}

proc bench_mod {mlist paths interp flags norm format verbose output coll rep} {
    global distribution env tcl_platform

    getpackage logger logger/logger.tcl
    getpackage bench  bench/bench.tcl

    ::logger::setlevel $verbose

    set pattern tclsh*
    if {$interp != {}} {
	set pattern [file tail $interp]
	set paths [list [file dirname $interp]]
    } elseif {![llength $paths]} {
	# Using the environment PATH is not a good default for
	# SAK. Use the interpreter running SAK as the default.
	if 0 {
	    set paths [split $env(PATH) \
			   [expr {($tcl_platform(platform) == "windows") ? ";" : ":"}]]
	}
	set interp [info nameofexecutable]
	set pattern [file tail $interp]
	set paths [list [file dirname $interp]]
    }

    set interps [bench::versions \
	    [bench::locate $pattern $paths]]

    if {![llength $interps]} {
	puts "No interpreters found"
	return
    }

    if {[llength $flags]} {
	set cmd [linsert $flags 0 bench::run]
    } else {
	set cmd [list bench::run]
    }

    array set DATA {}

    foreach m $mlist {
	set files [glob -nocomplain [file join $distribution modules $m *.bench]]
	if {![llength $files]} {
	    bench::log::warn "No benchmark files found for module \"$m\""
	    continue
	}

	for {set i 0} {$i <= $rep} {incr i} {
	    if {$i} { puts "Repeat $i" }

	    set run $cmd
	    lappend run $interps $files
	    array set tmp [eval $run]

	    # Merge new set of data into the previous run, if any.
	    foreach key [array names tmp] {
		set val $tmp($key)
		if {![info exists DATA($key)]} {
		    set DATA($key) $val
		    continue
		} elseif {[string is double -strict $val]} {
		    # Call user-request collation type
		    set DATA($key) [collate_$coll $DATA($key) $val $i]
		}
	    }
	    unset tmp
	}
    }

    _bench_write $output [array get DATA] $norm $format
    return
}

proc collate_min {cur new runs} {
    # Minimum
    return [expr {$cur > $new ? $new : $cur}]
}
proc collate_avg {cur new runs} {
    # Average
    return [expr {($cur * $runs + $new)/($runs+1)}]
}
proc collate_max {cur new runs} {
    # Maximum
    return [expr {$cur < $new ? $new : $cur}]
}

if 0 {proc bench_all {flags norm format verbose output} {
    bench_mod [modules] $flags $norm $format $verbose $output ? ?
    return
}}

proc _bench_write {output data norm format} {
    if {$norm != {}} {
	getpackage logger logger/logger.tcl
	getpackage bench  bench/bench.tcl

	set data [bench::norm $data $norm]
    }

    set data [bench::out::$format $data]

    if {$output == {}} {
	puts $data
    } else {
	set    output [open $output w]
	puts  $output "# -*- tcl -*- bench/$format"
	puts  $output $data
	close $output
    }
}

proc validate_testsuites {} {
    foreach m [modules] {
	validate_testsuite_mod $m
    }
    return
}

proc validate_pkgIndex_mod {m} {
    global distribution
    if {[llength [glob -nocomplain [file join $distribution modules $m pkgIndex.tcl]]] == 0} {
	puts "  Without package index : $m"
    }
    return
}

proc validate_pkgIndex {} {
    global distribution
    foreach m [modules] {
	validate_pkgIndex_mod $m
    }
    return
}

proc validate_doc_existence_mod {m} {
    global distribution
    if {[llength [glob -nocomplain [file join $distribution modules $m {*.[13n]}]]] == 0} {
	if {[llength [glob -nocomplain [file join $distribution modules $m {*.man}]]] == 0} {
	    puts "  Without * any ** manpages : $m"
	}
    } elseif {[llength [glob -nocomplain [file join $distribution modules $m {*.man}]]] == 0} {
	puts "  Without doctools manpages : $m"
    } else {
	foreach f [glob -nocomplain [file join $distribution modules $m {*.[13n]}]] {
	    if {![file exists [file rootname $f].man]} {
		puts "     no .man equivalent : $f"
	    }
	}
    }
    return
}

proc validate_doc_existence {} {
    global distribution
    foreach m [modules] {
	validate_doc_existence_mod $m
    }
    return
}


proc validate_doc_markup_mod {m} {
    package require sak::doc
    sak::doc::Gen null null [list $m]
    return
}

proc validate_doc_markup {} {
    package require sak::doc
    sak::doc::Gen null null [modules]
    return
}

proc run-frink {args} {
    global distribution

    set tmp [file rootname [info script]].tmp.[pid]

    if {[llength $args] == 0} {
	set files [tclfiles]
    } else {
	set files [lsort -dict [modtclfiles $args]]
    }

    foreach f $files {
	puts "FRINK ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	puts "$f..."
	puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

	catch {exec frink 2> $tmp -HJ $f}
	set data [get_input $tmp]
	if {[string length $data] > 0} {
	    puts $data
	}
    }
    catch {file delete -force $tmp}
    return
}

proc run-procheck {args} {
    global distribution

    if {[llength $args] == 0} {
	set files [tclfiles]
    } else {
	set files [lsort -dict [modtclfiles $args]]
    }

    foreach f $files {
	puts "PROCHECK ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	puts "$f ..."
	puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

	catch {exec procheck >@ stdout $f}
    }
    return
}

proc run-tclchecker {args} {
    global distribution

    if {[llength $args] == 0} {
	set files [tclfiles]
    } else {
	set files [lsort -dict [modtclfiles $args]]
    }

    foreach f $files {
	puts "TCLCHECKER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	puts "$f ..."
	puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

	catch {exec tclchecker >@ stdout $f}
    }
    return
}

proc run-nagelfar {args} {
    global distribution

    if {[llength $args] == 0} {
	set files [tclfiles]
    } else {
	set files [lsort -dict [modtclfiles $args]]
    }

    foreach f $files {
	puts "NAGELFAR ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	puts "$f ..."
	puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

	catch {exec nagelfar >@ stdout $f}
    }
    return
}


proc get_input {f} {return [read [set if [open $f r]]][close $if]}

proc write_out {f text} {
    catch {file delete -force $f}
    puts -nonewline [set of [open $f w]] $text
    close $of
}

proc location_PACKAGES {} {
    global distribution
    return [file join $distribution support releases PACKAGES]
}

proc gd-gen-packages {} {
    global package_version distribution

    set P [location_PACKAGES]
    file copy -force $P $P.LAST
    set f [open $P w]
    puts $f "@@ RELEASE $package_version"
    puts $f ""

    array set packages {}
    foreach {p vm} [ipackages] {
	set packages($p) [lindex $vm 0]
    }

    nparray packages $f
    close $f
}

# --------------------------------------------------------------
# Handle modules using docstrip

proc docstripUser {m} {
    global distribution

    set mdir [file join $distribution modules $m]

    if {[llength [glob -nocomplain -dir $mdir *.stitch]]} {return 1}
    return 0
}

proc docstripRegen {m} {
    global distribution
    puts "$m ..."

    getpackage docstrip docstrip/docstrip.tcl

    set mdir [file join $distribution modules $m]

    foreach sf [glob -nocomplain -dir $mdir *.stitch] {
	puts "* [file tail $sf] ..."

	set here [pwd]
	set fail [catch {
	    cd [file dirname $sf]
	    docstripRunStitch [file tail $sf]
	} msg]
	cd $here
	if {$fail} {
	    puts "  [join [split $::errorInfo \n] "\n  "]"
	}
    }
    return
}

proc docstripRunStitch {sf} {
    # Run the stitch file in a restricted sandbox ...

    set box [restrictedIp {
	input   ::dsrs::Input
	options ::dsrs::Options
	stitch  ::dsrs::Stitch
	reset   ::dsrs::Reset
    }]

    ::dsrs::Init
    set fail [catch {interp eval $box [get_input $sf]} msg]
    if {$fail} {
	puts "    [join [split $::errorInfo \n] "\n    "]"
    } else {
	::dsrs::Final
    }

    interp delete $box
    return
}

proc emptyIp {} {
    set box [interp create]
    foreach c [interp eval $box {info commands}] {
	if {[string equal $c "rename"]} continue
	interp eval $box [list rename $c {}]
    }
    # Rename command goes last.
    interp eval $box [list rename rename {}]
    return $box
}

proc restrictedIp {dict} {
    set box [emptyIp]
    foreach {cmd localcmd} $dict {
	interp alias $box $cmd {} $localcmd
    }
    return $box
}

# --------------------------------------------------------------
# docstrip low level operations for stitching.

namespace eval ::dsrs {
    # Standard preamble to preambles

    variable preamble {}
    append   preamble                                       \n
    append   preamble "This is the file `@output@',"        \n
    append   preamble "generated with the SAK utility"      \n
    append   preamble "(sak docstrip/regen)."               \n
    append   preamble                                       \n
    append   preamble "The original source files were:"     \n
    append   preamble                                       \n
    append   preamble "@input@  (with options: `@guards@')" \n
    append   preamble                                       \n

    # Standard postamble to postambles

    variable postamble {}
    append   postamble                           \n
    append   postamble                           \n
    append   postamble "End of file `@output@'."

    # Default values for the options which are relevant to the
    # application itself and thus have to be defined always.
    # They are processed as global options, as part of argv.

    variable defaults {-metaprefix {%} -preamble {} -postamble {}}

    variable options ; array set options {}
    variable outputs ; array set outputs {}
    variable inputs  ; array set inputs  {}
    variable input   {}
}

proc ::dsrs::Init {} {
    variable outputs ; unset outputs ; array set outputs {}
    variable inputs  ; unset inputs  ; array set inputs  {}
    variable input   {}

    Reset ; # options
    return
}

proc ::dsrs::Reset {} {
    variable defaults
    variable options ; unset options ; array set options {}
    eval [linsert $defaults 0 Options]
    return
}

proc ::dsrs::Input {sourcefile} {
    # Relative to current directory = directory containing the active
    # stitch file.

    variable input $sourcefile
}

proc ::dsrs::Options {args} {
    variable options
    variable preamble
    variable postamble

    while {[llength $args]} {
	set opt [lindex $args 0]

	switch -exact -- $opt {
	    -nopreamble -
	    -nopostamble {
		set o -[string range $opt 3 end]
		set options($o) ""
		set args [lrange $args 1 end]
	    }
	    -preamble {
		set val $preamble[lindex $args 1]
		set options($opt) $val
		set args [lrange $args 2 end]
	    }
	    -postamble {
		set val [lindex $args 1]$postamble
		set options($opt) $val
		set args [lrange $args 2 end]
	    }
	    -metaprefix -
	    -onerror    -
	    -trimlines  {
		set val [lindex $args 1]
		set options($opt) $val
		set args [lrange $args 2 end]
	    }
	    default {
		return -code error "Unknown option: \"$opt\""
	    }
	}
    }
    return
}

proc ::dsrs::Stitch {outputfile guards} {
    variable options
    variable inputs
    variable input
    variable outputs
    variable preamble
    variable postamble

    if {[string equal $input {}]} {
	return -code error "No input file defined"
    }

    if {![info exist inputs($input)]} {
	set inputs($input) [get_input $input]
    }

    set intext $inputs($input)
    set otext  ""

    set c   $options(-metaprefix)
    set cc  $c$c

    set pmap [list @output@ $outputfile \
		  @input@   $input  \
		  @guards@  $guards]

    if {[info exists options(-preamble)]} {
	set pre $options(-preamble)

	if {![string equal $pre ""]} {
	    append otext [Subst $pre $pmap $cc] \n
	}
    }

    array set o [array get options]
    catch {unset o(-preamble)}
    catch {unset o(-postamble)}
    set opt [array get o]

    append otext [eval [linsert $opt 0 docstrip::extract $intext $guards]]

    if {[info exists options(-postamble)]} {
	set post $options(-postamble)

	if {![string equal $post ""]} {
	    append otext [Subst $post $pmap $cc]
	}
    }

    # Accumulate outputs in memory

    append outputs($outputfile) $otext
    return
}

proc ::dsrs::Subst {text pmap cc} {
    return [string trim "$cc [join [split [string map $pmap $text] \n] "\n$cc "]"]
}

proc ::dsrs::Final {} {
    variable outputs
    foreach o [array names outputs] {
	puts "  = Writing $o ..."

	if {[string equal \
		 docstrip/docstrip.tcl \
		 [file join [file tail [pwd]] $o]]} {

	    # We are writing over code required by ourselves.
	    # For easy recovery in case of problems we save
	    # the original 

	    puts "    *Saving original of code important to docstrip/regen itself*"
	    write_out $o.bak [get_input $o]
	}

	write_out $o $outputs($o)
    }
}

# --------------------------------------------------------------
# Configuration

proc __name    {} {global package_name    ; puts -nonewline $package_name}
proc __version {} {global package_version ; puts -nonewline $package_version}
proc __minor   {} {global package_version ; puts -nonewline [lindex [split $package_version .] 1]}
proc __major   {} {global package_version ; puts -nonewline [lindex [split $package_version .] 0]}

# --------------------------------------------------------------
# Development

proc __imodules {} {puts [imodules]}
proc __modules  {} {puts [modules]}
proc __lmodules {} {puts [join [modules] \n]}


proc nparray {a {chan stdout}} {
    upvar $a packages

    set maxl 0
    foreach name [lsort [array names packages]] {
        if {[string length $name] > $maxl} {
            set maxl [string length $name]
        }
    }
    foreach name [lsort [array names packages]] {
	foreach v $packages($name) {
	    puts $chan [format "%-*s %s" $maxl $name $v]
	}
    }
    return
}

proc __packages {} {
    array set packages {}
    foreach {p vm} [ipackages] {
	set packages($p) [lindex $vm 0]
    }
    nparray packages
    return
}

proc __provided {} {
    array set packages [ppackages]
    nparray packages
    return
}

proc checkmod {} {
    global argv
    package require sak::util
    return [sak::util::checkModules argv]
}

# -------------------------------------------------------------------------
# Critcl stuff
# -------------------------------------------------------------------------

# Build critcl modules. If no args then build the default critcl module.
proc __critcl {} {
    global argv critcl critclmodules critcldefault critclnotes tcl_platform
    if {$tcl_platform(platform) == "windows"} {

	# Windows is a bit more complicated. We have to choose an
	# interpreter, and a starkit for it, and call both.
	#
	# We prefer tclkitsh, but try to make do with a tclsh. That
	# one will have to have all the necessary packages to support
	# starkits. ActiveTcl for example.

	set interpreter {}
	foreach i {critcl.exe tclkitsh tclsh} {
	    set interpreter [auto_execok $i]
	    if {$interpreter != {}} break
	}

	if {$interpreter == {}} {
            return -code error \
		    "failed to find either tclkitsh.exe or tclsh.exe in path"
	}

	# The critcl starkit can come out of the environment, or we
	# try to locate it using several possible names. We try to
	# find it if and only if we did not find a critcl starpack
	# before.

	if {[file tail $interpreter] == "critcl.exe"} {
	    set critcl $interpreter
	} else {
	    set kit {}
            if {[info exists ::env(CRITCL)]} {
                set kit $::env(CRITCL)
            } else {
		foreach k {critcl.kit critcl} {
		    set kit [auto_execok $k]
		    if {$kit != {}} break
		}
            }

            if {$kit == {}} {
                return -code error "failed to find critcl.kit or critcl in \
                  path.\n\
                  You may wish to set the CRITCL environment variable to the\
                  location of your critcl(.kit) file."
            }
            set critcl [concat $interpreter $kit]
        }
    } else {
        # My, isn't it simpler under unix.
        set critcl [auto_execok critcl]
    }

    set flags ""
    while {[string match -* [set option [lindex $argv 0]]]} {
        # -debug and -clean only work with critcl >= v04
        switch -exact -- $option {
            -keep  { append flags " -keep" }
            -debug {
		append flags " -debug [lindex $argv 1]"
		set argv [lreplace $argv 0 0]
	    }
            -clean { append flags " -clean" }
            -target {
		append flags " -target [lindex $argv 1]"
		set argv [lreplace $argv 0 0]
	    }
            -- { set argv [lreplace $argv 0 0]; break }
            default { break }
        }
        set argv [lreplace $argv 0 0]
    }

    if {$critcl != {}} {
        if {[llength $argv] == 0} {
            puts stderr "[string repeat - 72]"
	    puts stderr "Building critcl components."
	    if {$critclnotes != {}} {
		puts stderr $critclnotes
	    }
	    puts stderr "[string repeat - 72]"

            critcl_module $critcldefault $flags
        } else {
            foreach m [dealias $argv] {
                if {[info exists critclmodules($m)]} {
                    critcl_module $m $flags
                } else {
                    puts "warning: $m is not a critcl module"
                }
            }
        }
    } else {
        puts "error: cannot find a critcl to run."
        return 1
    }
    return
}

# Prints a list of all the modules supporting critcl enhancement.
proc __critcl-modules {} {
    global critclmodules critcldefault
    foreach m [lsort -dict [array names critclmodules]] {
	if {$m == $critcldefault} {
	    puts "$m **"
	} else {
	    puts $m
	}
    }
    return
}

proc critcl_module {pkg {extra ""}} {
    global critcl distribution critclmodules critcldefault

    lappend extra -cache [pwd]/.critcl

    if {$pkg == $critcldefault} {
	set files {}
	foreach f $critclmodules($critcldefault) {
	    lappend files [file join $distribution modules $f]
	}
        foreach m [array names critclmodules] {
	    if {$m == $critcldefault} continue
            foreach f $critclmodules($m) {
                lappend files [file join $distribution modules $f]
            }
        }
    } else {
        foreach f $critclmodules($pkg) {
            lappend files [file join $distribution modules $f]
        }
    }
    set target [file join $distribution modules]
    catch {
        puts "$critcl $extra -force -libdir [list $target] -pkg [list $pkg] $files"
        eval exec $critcl $extra -force -libdir [list $target] -pkg [list $pkg] $files 
    } r
    puts $r
    return
}

# -------------------------------------------------------------------------

proc __bench/edit {} {
    global argv argv0

    set format text
    set output {}

    while {[string match -* [set option [lindex $argv 0]]]} {
	set val [lindex $argv 1]
        switch -exact -- $option {
	    -format {
		switch -exact -- $val {
		    raw - csv - text {}
		    default {
			return -error "Bad format \"$val\", expected text, csv, or raw"
		    }
		}
		set format $val
	    }
	    -o    {set output $val}
            -- {
		set argv [lrange $argv 1 end]
		break
	    }
            default { break }
        }
        set argv [lrange $argv 2 end]
    }

    switch -exact -- $format {
	raw {}
	csv {
	    getpackage csv             csv/csv.tcl
	    getpackage bench::out::csv bench/bench_wcsv.tcl
	}
	text {
	    getpackage report           report/report.tcl
	    getpackage struct::matrix   struct/matrix.tcl
	    getpackage bench::out::text bench/bench_wtext.tcl
	}
    }

    getpackage bench::in bench/bench_read.tcl
    getpackage bench     bench/bench.tcl

    if {[llength $argv] != 3} {
	puts "Usage: $argv0 benchdata column newvalue"
    }

    foreach {in col new} $argv break

    _bench_write $output \
	[bench::edit \
	     [bench::in::read $in] \
	     $col $new] \
	{} $format
    return
}

proc __bench/del {} {
    global argv argv0

    set format text
    set output {}

    while {[string match -* [set option [lindex $argv 0]]]} {
	set val [lindex $argv 1]
        switch -exact -- $option {
	    -format {
		switch -exact -- $val {
		    raw - csv - text {}
		    default {
			return -error "Bad format \"$val\", expected text, csv, or raw"
		    }
		}
		set format $val
	    }
	    -o    {set output $val}
            -- {
		set argv [lrange $argv 1 end]
		break
	    }
            default { break }
        }
        set argv [lrange $argv 2 end]
    }

    switch -exact -- $format {
	raw {}
	csv {
	    getpackage csv             csv/csv.tcl
	    getpackage bench::out::csv bench/bench_wcsv.tcl
	}
	text {
	    getpackage report           report/report.tcl
	    getpackage struct::matrix   struct/matrix.tcl
	    getpackage bench::out::text bench/bench_wtext.tcl
	}
    }

    getpackage bench::in bench/bench_read.tcl
    getpackage bench     bench/bench.tcl

    if {[llength $argv] < 2} {
	puts "Usage: $argv0 benchdata column..."
    }

    set in [lindex $argv 0]

    set data [bench::in::read $in]

    foreach c [lrange $argv 1 end] {
	set data [bench::del $data $c]
    }

    _bench_write $output $data {} $format
    return
}

proc __bench/show {} {
    global argv

    set format text
    set output {}
    set norm   {}

    while {[string match -* [set option [lindex $argv 0]]]} {
	set val [lindex $argv 1]
        switch -exact -- $option {
	    -format {
		switch -exact -- $val {
		    raw - csv - text {}
		    default {
			return -error "Bad format \"$val\", expected text, csv, or raw"
		    }
		}
		set format $val
	    }
	    -o    {set output $val}
	    -norm {set norm $val}
            -- {
		set argv [lrange $argv 1 end]
		break
	    }
            default { break }
        }
        set argv [lrange $argv 2 end]
    }

    switch -exact -- $format {
	raw {}
	csv {
	    getpackage csv             csv/csv.tcl
	    getpackage bench::out::csv bench/bench_wcsv.tcl
	}
	text {
	    getpackage report           report/report.tcl
	    getpackage struct::matrix   struct/matrix.tcl
	    getpackage bench::out::text bench/bench_wtext.tcl
	}
    }

    getpackage bench::in bench/bench_read.tcl

    array set DATA {}

    foreach path $argv {
	array set DATA [bench::in::read $path]
    }

    _bench_write $output [array get DATA] $norm $format
    return
}

proc __bench {} {
    global argv

    # I. Process command line arguments for the
    #    benchmark commands - Validation, possible
    #    translation ...

    set flags   {}
    set norm    {}
    set format  text
    set verbose warn
    set output  {}
    set paths   {}
    set interp  {}
    set repeat  0
    set collate min

    while {[string match -* [set option [lindex $argv 0]]]} {
	set val [lindex $argv 1]
        switch -exact -- $option {
	    -throwerrors {lappend flags -errors $val}
	    -match -
	    -rmatch -
	    -iters -
	    -threads {lappend flags $option $val}
	    -o       {set output $val}
	    -norm    {set norm $val}
	    -path    {lappend paths $val}
	    -interp  {set interp $val}
	    -format  {
		switch -exact -- $val {
		    raw - csv - text {}
		    default {
			return -error "Bad format \"$val\", expected text, csv, or raw"
		    }
		}
		set format $val
	    }
	    -collate {
		switch -exact -- $val {
		    min - max - avg {}
		    default {
			return -error "Bad collation \"$val\", expected avg, max, or min"
		    }
		}
		set collate $val
	    }
	    -repeat {
		# TODO: test for integer >= 0
		set repeat $val
	    }
	    -verbose {
		set verbose info
		set argv [lrange $argv 1 end]
		continue
	    }
	    -debug {
		set verbose debug
		set argv [lrange $argv 1 end]
		continue
	    }
            -- {
		set argv [lrange $argv 1 end]
		break
	    }
            default { break }
        }
        set argv [lrange $argv 2 end]
    }

    switch -exact -- $format {
	raw {}
	csv {
	    getpackage csv             csv/csv.tcl
	    getpackage bench::out::csv bench/bench_wcsv.tcl
	}
	text {
	    getpackage report           report/report.tcl
	    getpackage struct::matrix   struct/matrix.tcl
	    getpackage bench::out::text bench/bench_wtext.tcl
	}
    }

    # Choose between benchmarking everything, or
    # only selected modules.

    if {[llength $argv] == 0} {
	_bench_all $paths $interp $flags $norm $format $verbose $output $collate $repeat
    } else {
	if {![checkmod]} {return}
	_bench_module [dealias $argv] $paths $interp $flags $norm $format $verbose $output $collate $repeat
    }
    return
}

proc _bench_module {mlist paths interp flags norm format verbose output coll rep} {
    global package_name package_version

    puts "Benchmarking $package_name $package_version development"
    puts "======================================================"
    bench_mod $mlist $paths $interp $flags $norm $format $verbose $output $coll $rep
    puts "------------------------------------------------------"
    puts ""
    return
}

proc _bench_all {paths flags interp norm format verbose output coll rep} {
    _bench_module [modules] $paths $interp $flags $norm $format $verbose $output $coll $rep
    return
}

# -------------------------------------------------------------------------

proc __oldvalidate_v {} {
    global argv
    if {[llength $argv] == 0} {
	_validate_all_v
    } else {
	if {![checkmod]} {return}
	foreach m [dealias $argv] {
	    _validate_module_v $m
	}
    }
    return
}

proc _validate_all_v {} {
    global package_name package_version
    set i 0

    puts "Validating $package_name $package_version development"
    puts "==================================================="
    puts "[incr i]: Consistency of package versions ..."
    puts "------------------------------------------------------"
    validate_versions
    puts "------------------------------------------------------"
    puts ""
    return
}

proc _validate_module_v {m} {
    global package_name package_version
    set i 0

    puts "Validating $package_name $package_version development -- $m"
    puts "==================================================="
    puts "[incr i]: Consistency of package versions ..."
    puts "------------------------------------------------------"
    validate_versions_mod $m
    puts "------------------------------------------------------"
    puts ""
    return
}


proc __oldvalidate {} {
    global argv
    if {[llength $argv] == 0} {
	_validate_all
    } else {
	if {![checkmod]} {return}
	foreach m $argv {
	    _validate_module $m
	}
    }
    return
}

proc _validate_all {} {
    global package_name package_version
    set i 0

    puts "Validating $package_name $package_version development"
    puts "==================================================="
    puts "[incr i]: Existence of testsuites ..."
    puts "------------------------------------------------------"
    validate_testsuites
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Existence of package indices ..."
    puts "------------------------------------------------------"
    validate_pkgIndex
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Consistency of package versions ..."
    puts "------------------------------------------------------"
    validate_versions
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Installed vs. developed modules ..."
    puts "------------------------------------------------------"
    validate_imodules
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Existence of documentation ..."
    puts "------------------------------------------------------"
    validate_doc_existence
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Validate documentation markup (doctools) ..."
    puts "------------------------------------------------------"
    validate_doc_markup
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Static syntax check ..."
    puts "------------------------------------------------------"

    set frink      [auto_execok frink]
    set procheck   [auto_execok procheck]
    set tclchecker [auto_execok tclchecker]
    set nagelfar [auto_execok nagelfar]

    if {$frink == {}} {puts "  Tool 'frink'    not found, no check"}
    if {($procheck == {}) || ($tclchecker == {})} {
	puts "  Tools 'procheck'/'tclchecker' not found, no check"
    }
    if {$nagelfar == {}} {puts "  Tool 'nagelfar' not found, no check"}

    if {($frink == {}) || ($procheck == {}) || ($tclchecker == {}) 
        || ($nagelfar == {})} {
	puts "------------------------------------------------------"
    }
    if {($frink == {}) && ($procheck == {}) && ($tclchecker == {})
        && ($nagelfar == {})} {
	return
    }
    if {$frink != {}} {
	run-frink
	puts "------------------------------------------------------"
    }
    if {$tclchecker != {}} {
	run-tclchecker
	puts "------------------------------------------------------"
    } elseif {$procheck != {}} {
	run-procheck
	puts "------------------------------------------------------"
    }
    if {$nagelfar    !={}} {
    	run-nagelfar 
	puts "------------------------------------------------------"
    }
    puts ""
    return
}

proc _validate_module {m} {
    global package_name package_version
    set i 0

    puts "Validating $package_name $package_version development -- $m"
    puts "==================================================="
    puts "[incr i]: Existence of testsuites ..."
    puts "------------------------------------------------------"
    validate_testsuite_mod $m
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Existence of package indices ..."
    puts "------------------------------------------------------"
    validate_pkgIndex_mod $m
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Consistency of package versions ..."
    puts "------------------------------------------------------"
    validate_versions_mod $m
    puts "------------------------------------------------------"
    puts ""

    #puts "[incr i]: Installed vs. developed modules ..."
    puts "------------------------------------------------------"
    validate_imodules_mod $m
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Existence of documentation ..."
    puts "------------------------------------------------------"
    validate_doc_existence_mod $m
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Validate documentation markup (doctools) ..."
    puts "------------------------------------------------------"
    validate_doc_markup_mod $m
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Static syntax check ..."
    puts "------------------------------------------------------"

    set frink    [auto_execok frink]
    set procheck [auto_execok procheck]
    set nagelfar [auto_execok nagelfar]
    set tclchecker [auto_execok tclchecker]
    
    if {$frink    == {}} {puts "  Tool 'frink'    not found, no check"}
    if {($procheck == {}) || ($tclchecker == {})} {
	puts "  Tools 'procheck'/'tclchecker' not found, no check"
    }
    if {$nagelfar == {}} {puts "  Tool 'nagelfar' not found, no check"}
    
    if {($frink == {}) || ($procheck == {}) || ($tclchecker == {}) ||
    	($nagelfar == {})} {
	puts "------------------------------------------------------"
    }
    if {($frink == {}) && ($procheck == {}) && ($nagelfar == {})
        && ($tclchecker == {})} {
	return
    }
    if {$frink    != {}} {
	run-frink $m
	puts "------------------------------------------------------"
    }
    if {$tclchecker != {}} {
	run-tclchecker $m
	puts "------------------------------------------------------"
    } elseif {$procheck != {}} {
	run-procheck $m
	puts "------------------------------------------------------"
    }
    if {$nagelfar    !={}} {
    	run-nagelfar $m
	puts "------------------------------------------------------"
    }
    puts ""

    return
}

# --------------------------------------------------------------
# Release engineering

proc __gendist {} {
    gd-cleanup
    gd-tip55
    gd-gen-rpmspec
    gd-gen-tap
    gd-gen-yml
    gd-assemble
    gd-gen-archives

    puts ...Done
    return
}

proc __gentip55 {} {
    gd-tip55
    puts "Created DESCRIPTION.txt"
    return
}

proc __yml {} {
    global package_name
    gd-gen-yml
    puts "Created YAML spec file \"${package_name}.yml\""
    return
}

proc __contributors {} {
    global contributors
    contributors
    foreach person [lsort [array names contributors]] {
        puts "$person <$contributors($person)>"
    }
    return
}

proc __tap {} {
    global package_name
    gd-gen-tap
    puts "Created Tcl Dev Kit \"${package_name}.tap\""
}

proc __rpmspec {} {
    global package_name
    gd-gen-rpmspec
    puts "Created RPM spec file \"${package_name}.spec\""
}


proc __release {} {
    # Regenerate PACKAGES, and extend
    gd-gen-packages
    return

    global argv argv0 distribution package_name package_version

    getpackage textutil textutil/textutil.tcl

    if {[llength $argv] != 2} {
	puts stderr "$argv0: wrong#args: release name sf-user-id"
	exit 1
    }

    foreach {name sfuser} $argv break
    set email "<${sfuser}@users.sourceforge.net>"
    set pname [textutil::cap $package_name]

    set notice "[clock format [clock seconds] -format "%Y-%m-%d"]  $name  $email

	*
	* Released and tagged $pname $package_version ========================
	* 

"

    set logs [list [file join $distribution ChangeLog]]
    foreach m [modules] {
	set m [file join $distribution modules $m ChangeLog]
	if {![file exists $m]} continue
	lappend logs $m
    }

    foreach f $logs {
	puts "\tAdding release notice to $f"
	set fh [open $f r] ; set data [read $fh] ; close $fh
	set fh [open $f w] ; puts -nonewline $fh $notice$data ; close $fh
    }

    gd-gen-packages
    return
}

# --------------------------------------------------------------
# Documentation

proc __desc  {} {
    global argv ; if {![checkmod]} return
    array set pd [getpdesc]

    getpackage struct::matrix struct/matrix.tcl
    getpackage textutil       textutil/textutil.tcl

    struct::matrix m
    m add columns 3

    puts {Descriptions...}
    if {[llength $argv] == 0} {set argv [modules]}

    foreach m [lsort [dealias $argv]] {
	array set _ {}
	set pkg {}
	foreach {p vlist} [ppackages $m] {
	    catch {set _([lindex $pd($p) 0]) .}
	    lappend pkg $p
	}
	set desc [string trim [join [array names _] ", "] " \n\t\r,"]
	set desc [textutil::adjust $desc -length 20]
	unset _

	m add row [list $m $desc]
	m add row {}

	foreach p [lsort -dictionary $pkg] {
	    set desc ""
	    catch {set desc [lindex $pd($p) 1]}
	    if {$desc != ""} {
		set desc [string trim $desc]
		set desc [textutil::adjust $desc -length 50]
		m add row [list {} $p $desc]
	    } else {
		m add row [list {**} $p ]
	    }
	}
	m add row {}
    }

    m format 2chan
    puts ""
    return
}

proc __desc/2  {} {
    global argv ; if {![checkmod]} return
    array set pd [getpdesc]

    getpackage struct::matrix struct/matrix.tcl
    getpackage textutil       textutil/textutil.tcl

    puts {Descriptions...}
    if {[llength $argv] == 0} {set argv [modules]}

    foreach m [lsort [dealias $argv]] {
	struct::matrix m
	m add columns 3

	m add row {}

	set pkg {}
	foreach {p vlist} [ppackages $m] {lappend pkg $p}

	foreach p [lsort -dictionary $pkg] {
	    set desc ""
	    set sdes ""
	    catch {set desc [lindex $pd($p) 1]}
	    catch {set sdes [lindex $pd($p) 0]}

	    if {$desc != ""} {
		set desc [string trim $desc]
		#set desc [textutil::adjust $desc -length 50]
	    }

	    if {$desc != ""} {
		set desc [string trim $desc]
		#set desc [textutil::adjust $desc -length 50]
	    }

	    m add row [list $p "  $sdes" "  $desc"]
	}
	m format 2chan
	puts ""
	m destroy
    }

    return
}

# --------------------------------------------------------------

proc __docstrip/users {} {
    # Print the list of modules using docstrip for their code.

    set argv [modules]
    foreach m [lsort $argv] {
	if {[docstripUser $m]} {
	    puts $m
	}
    }

    return
}

proc __docstrip/regen {} {
    # Regenerate modules based on docstrip.

    global argv ; if {![checkmod]} return
    if {[llength $argv] == 0} {set argv [modules]}

    foreach m [lsort [dealias $argv]] {
	if {[docstripUser $m]} {
	    docstripRegen $m
	}
    }

    return
}

# --------------------------------------------------------------
## Make sak specific packages visible.

lappend auto_path [file join $distribution support devel sak]

# --------------------------------------------------------------
## Dispatcher to the sak commands.

set  cmd  [lindex $argv 0]
set  argv [lrange $argv 1 end]
incr argc -1

# Prefer a command implementation found in the support tree.
# Then see if the command is implemented here, in this file.
# At last fail and report possible commands.

set base  [file dirname [info script]]
set sbase [file join $base support devel sak]
set cbase [file join $sbase $cmd]
set cmdf  [file join $cbase cmd.tcl]

if {[file exists $cmdf] && [file readable $cmdf]} {
    source $cmdf
    exit 0
}

if {[llength [info procs __$cmd]] == 0} {
    puts stderr "$argv0 : Illegal command \"$cmd\""
    set fl {}
    foreach p [info procs __*] {
	lappend fl [string range $p 2 end]
    }
    foreach p [glob -nocomplain -directory $sbase */cmd.tcl] {
	lappend fl [lindex [file split $p] end-1]
    }

    regsub -all . $argv0 { } blank
    puts stderr "$blank : Should have been [linsert [join [lsort -uniq $fl] ", "] end-1 or]"
    exit 1
}

__$cmd
exit 0
