# -*- tcl -*-
# Testsuite utilities / boilerplate
# Copyright (c) 2006, Andreas Kupries <andreas_kupries@users.sourceforge.net>

namespace eval ::tcllib::testutils {
    variable self    [file dirname [file join [pwd] [info script]]]
    variable tcllib  [file dirname $self]
    variable tag     ""
    variable theEnv  ; # Saved environment.
}

# ### ### ### ######### ######### #########
## Procedures for common functions and boilerplate actions required by many
## test suites of Tcllib modules and packages.


# ### ### ### ######### ######### #########
## Declares the minimal version of Tcl and the dependencies required by the
## package tested by this test suite.  Must be called immediately after loading
## the utilities.  Bails out of the calling level if the required minimum
## version is not met by the active interpreter.

proc testsNeedTcl {version} {
    if {[package vsatisfies [package provide Tcl] $version]} return

    puts "    Aborting the tests found in \"[file tail [info script]]\""
    puts "    Requiring at least Tcl $version, have [package present Tcl]."

    # Effect a 'return' at the caller's level.
    return -code return
}


# ### ### ### ######### ######### #########
## Declares the minimum version of Tcltest required to run the test suite.
## Must be called after loading the utilities.  Loads a suitable version of The
## only procedure that may preceed it is 'testNeedTcl' above.  Tcltest if the
## package has not been loaded yet.  Bail out of the test script that called
## this procedure if the loaded version of tcltest does not meet the given
## minimum version,

proc testsNeedTcltest {version} {
    regexp {^([^-]*)} $version -> minversion
    if {[lsearch [namespace children] ::tcltest] == -1} {
	if {![catch {
	    package require tcltest $version
	}]} {
	    namespace import -force ::tcltest::*
	    InitializeTclTest
	    return
	}
    } elseif {[package vcompare [package present tcltest] $minversion] >= 0} {
	InitializeTclTest
	return
    }

    puts "    Aborting the tests found in [file tail [info script]]."
    puts "    Requiring at least tcltest $version, have [package present tcltest]"

    # Effect a return at the level of the caller.
    return -code return
}

proc testsNeed {name {version {}}} {
    # Must be called immediately after loading the utilities.  Loads the named
    # package if it is not already loaded.  If the version of the loaded
    # package does not meet the given minimum version, bail out of the test
    # suite that called the procedure.

    if {$version != {}} {
	if {[catch {
	    package require $name $version
	}]} {
	    puts "    Aborting the tests found in \"[file tail [info script]]\""
	    puts "    Requiring at least \"$name $version\", package not found."

	    return -code return
	}

	if {[package vsatisfies [package present $name] $version]} return

	puts "    Aborting the tests found in \"[file tail [info script]]\""
	puts "    Requiring at least \"$name $version\", have [package present $name]."

	# This causes a 'return' in the calling scope.
	return -code return
    } else {
	if {[catch {
	    package require $name
	}]} {
	    puts "    Aborting the tests found in \"[file tail [info script]]\""
	    puts "    Requiring \"$name\", package not found."

	    return -code return
	}
    }
}

# ### ### ### ######### ######### #########

## Saves/restores the environment for test suites which manipulate it either to
## achieve the effects they test for/against, or to shield themselves against
## manipulation by the environment.  'fileutil' is an example of the first, and
## 'doctools' is an example of the second.
##
## The environment is automatically saved at the beginning of a test file, and
## restoration is semi-automatic.  The tcltest cleanup hook is an unmodifiable
## alias used by all.tcl to transfer results from the slave iterpreter running
## the tests to the master interpreter, so create instead a new cleanup
## command which runs both our environment cleanup and the regular one. All
## .test files are modified to use the new cleanup.

proc ::tcllib::testutils::SaveEnvironment {} {
    global env
    variable theEnv [array get env]
    return
}

proc ::tcllib::testutils::RestoreEnvironment {} {
    global env
    variable theEnv
    foreach k [array names env] {
	unset env($k)
    }
    array set env $theEnv
    return
}

proc testsuiteCleanup {} {
    ::tcllib::testutils::RestoreEnvironment
    ::tcltest::cleanupTests
    return
}

proc array_unset {a {pattern *}} {
    upvar 1 $a array
    foreach k [array names array $pattern] {
	unset array($k)
    }
    return
}

# ### ### ### ######### ######### #########
## Newer versions of Tcltest provide various features which make it easier to
## create and maintain a test suite.  I consider it important to have these
## features even if an older version of Tcltest is loaded, so we now provide
## emulations and implementations for versions that are missing this
## functionality.

# ### ### ### ######### ######### #########
## Easy definition and initialization of test constraints.

proc InitializeTclTest {} {
    global tcltestinit
    if {[info exists tcltestinit] && $tcltestinit} return
    set tcltestinit 1

    proc ::tcltest::byConstraint {dict} {
	foreach {constraint value} $dict {
	    if {![testConstraint $constraint]} continue
	    return $value
	}
	return -code error "No result available. Failed to match any of the constraints ([join [lsort -dict [dict keys $dict]] ,])."
    }

    if {![package vsatisfies [package provide tcltest] 2.0]} {
	# Tcltest 2.0+ provides a documented public API to define and
	# initialize a test constraint. For earlier versions the user has to
	# directly set a non-public undocumented variable in the package's
	# namespace.  The following procedures do this, adhering the public
	# API.

	proc ::tcltest::testConstraint {c args} {
	    variable testConstraints
	    if {[llength $args] < 1} {
		if {[info exists testConstraints($c)]} {
		    return $testConstraints($c)
		} else {
		    return {}
		}
	    } else {
		set testConstraints($c) [lindex $args 0]
	    }
	    return
	}

	namespace eval ::tcltest {
	    namespace export testConstraint
	}
	uplevel \#0 {namespace import -force ::tcltest::*}
    }

    # ### ### ### ######### ######### #########
    ## Define a set of standard constraints

    ::tcltest::testConstraint tcl8.3only \
	[expr {![package vsatisfies [package provide Tcl] 8.4]}]

    ::tcltest::testConstraint tcl8.3plus \
	[expr {[package vsatisfies [package provide Tcl] 8.3]}]

    ::tcltest::testConstraint tcl8.4only \
	[expr {![package vsatisfies [package provide Tcl] 8.5]}]

    ::tcltest::testConstraint tcl8.4plus \
	[expr {[package vsatisfies [package provide Tcl] 8.4]}]

    ::tcltest::testConstraint tcl8.5only [expr {
	![package vsatisfies [package provide Tcl] 8.6] &&
	 [package vsatisfies [package provide Tcl] 8.5]
    }]

    ::tcltest::testConstraint tcl8.5plus \
	[expr {[package vsatisfies [package provide Tcl] 8.5]}]

    ::tcltest::testConstraint tcl8.6plus \
	[expr {[package vsatisfies [package provide Tcl] 8.6]}]

    ::tcltest::testConstraint tcl8.6not8.7 \
	[expr { [package vsatisfies [package provide Tcl] 8.6] &&
	       ![package vsatisfies [package provide Tcl] 8.7]}]

    ::tcltest::testConstraint tcl8.6not10 \
	[expr { [package vsatisfies [package provide Tcl] 8.6] &&
	       ![package vsatisfies [package provide Tcl] 8.6.10]}]

    ::tcltest::testConstraint tcl8.6.10plus \
	[expr {[package vsatisfies [package provide Tcl] 8.6.10]}]

    ::tcltest::testConstraint tcl8.4minus \
	[expr {![package vsatisfies [package provide Tcl] 8.5]}]

    ::tcltest::testConstraint tcl8.5minus \
	[expr {![package vsatisfies [package provide Tcl] 8.6]}]

    ::tcltest::testConstraint tcl8.7plus \
	[expr {[package vsatisfies [package provide Tcl] 8.7]}]

    # ### ### ### ######### ######### #########
    ## Cross-version code for the generation of the error messages created
    ## by Tcl procedures when called with the wrong number of arguments,
    ## either too many, or not enough.

    if {[package vsatisfies [package provide Tcl] 8.6]} {
	# 8.6+
	proc ::tcltest::wrongNumArgs {functionName argList missingIndex} {
	    if {[string match args [lindex $argList end]]} {
		set argList [lreplace $argList end end ?arg ...?]
	    }
	    if {$argList != {}} {set argList " $argList"}
	    set msg "wrong # args: should be \"$functionName$argList\""
	    return $msg
	}

	proc ::tcltest::tooManyArgs {functionName argList} {
	    # create a different message for functions with no args
	    if {[llength $argList]} {
		if {[string match args [lindex $argList end]]} {
		    set argList [lreplace $argList end end ?arg ...?]
		}
		set msg "wrong # args: should be \"$functionName $argList\""
	    } else {
		set msg "wrong # args: should be \"$functionName\""
	    }
	    return $msg
	}
    } elseif {[package vsatisfies [package provide Tcl] 8.5]} {
	# 8.5
	proc ::tcltest::wrongNumArgs {functionName argList missingIndex} {
	    if {[string match args [lindex $argList end]]} {
		set argList [lreplace $argList end end ...]
	    }
	    if {$argList != {}} {set argList " $argList"}
	    set msg "wrong # args: should be \"$functionName$argList\""
	    return $msg
	}

	proc ::tcltest::tooManyArgs {functionName argList} {
	    # Create a different message for functions with no args.
	    if {[llength $argList]} {
		if {[string match args [lindex $argList end]]} {
		    set argList [lreplace $argList end end ...]
		}
		set msg "wrong # args: should be \"$functionName $argList\""
	    } else {
		set msg "wrong # args: should be \"$functionName\""
	    }
	    return $msg
	}
    } elseif {[package vsatisfies [package provide Tcl] 8.4]} {
	# 8.4+
	proc ::tcltest::wrongNumArgs {functionName argList missingIndex} {
	    if {$argList != {}} {set argList " $argList"}
	    set msg "wrong # args: should be \"$functionName$argList\""
	    return $msg
	}

	proc ::tcltest::tooManyArgs {functionName argList} {
	    # Create a different message for functions with no args.
	    if {[llength $argList]} {
		set msg "wrong # args: should be \"$functionName $argList\""
	    } else {
		set msg "wrong # args: should be \"$functionName\""
	    }
	    return $msg
	}
    } else {
	# 8.2+
	proc ::tcltest::wrongNumArgs {functionName argList missingIndex} {
	    set msg "no value given for parameter "
	    append msg "\"[lindex $argList $missingIndex]\" to "
	    append msg "\"$functionName\""
	    return $msg
	}

	proc ::tcltest::tooManyArgs {functionName argList} {
	    set msg "called \"$functionName\" with too many arguments"
	    return $msg
	}
    }

    # ### ### ### ######### ######### #########
    ## tclTest::makeFile result API changed for 2.0

    if {![package vsatisfies [package provide tcltest] 2.0]} {

	# The 'makeFile' in Tcltest 1.0 returns a list of all the
	# paths generated so far, whereas the 'makeFile' in 2.0+
	# returns only the path of the newly-generated file. We
	# standardize on the more useful behaviour of 2.0+. If 1.x is
	# present we create an emulation layer to get the
	# desired result.

	# 1.0 is not fully described correctly. If the file was
	# created before, no list is returned at all. Force things
	# here by adding a line to the old procedure which makes the result
	# unconditional (the name of the file/dir created).

	# The same change applies to 'makeDirectory'

	if {![llength [info commands ::tcltest::makeFile_1]]} {
	    # Marker first.
	    proc ::tcltest::makeFile_1 {args} {}

	    # Extend procedures with command to return the required
	    # full name.
	    proc ::tcltest::makeFile {contents name} \
		[info body ::tcltest::makeFile]\n[list set fullName]

	    proc ::tcltest::makeDirectory {name} \
		[info body ::tcltest::makeDirectory]\n[list set fullName]

	    # Re-export
	    namespace eval ::tcltest {
		namespace export makeFile makeDirectory
	    }
	    uplevel \#0 {namespace import -force ::tcltest::*}
	}
    }

    # ### ### ### ######### ######### #########
    ## Extended functionality, creation of binary temp. files.
    ## Also creation of paths for temp. files

    proc ::tcltest::makeBinaryFile {data f} {
	set path [makeFile {} $f]
	set ch   [open $path w]
	fconfigure $ch -translation binary
	puts -nonewline $ch $data
	close $ch
	return $path
    }

    proc ::tcltest::tempPath {path} {
	variable temporaryDirectory
	return [file join $temporaryDirectory $path]
    }

    namespace eval ::tcltest {
	namespace export wrongNumArgs tooManyArgs
	namespace export makeBinaryFile tempPath
    }
    uplevel \#0 {namespace import -force ::tcltest::*}
    return
}

# ### ### ### ######### ######### #########
## Constructs wrong/args messages for Snit methods.

proc snitErrors {} {
    if {[package vsatisfies [package provide snit] 2]} {
	# Snit 2.0+

	proc snitWrongNumArgs {obj method arglist missingIndex} {
	    regsub {^.*Snit_method} $method {} method
	    tcltest::wrongNumArgs "$obj $method" $arglist $missingIndex
	}

	proc snitTooManyArgs {obj method arglist} {
	    regsub {^.*Snit_method} $method {} method
	    tcltest::tooManyArgs "$obj $method" $arglist
	}

    } else {
	proc snitWrongNumArgs {obj method arglist missingIndex} {
	    incr missingIndex 4
	    tcltest::wrongNumArgs $method [linsert $arglist 0 \
		    type selfns win self] $missingIndex
	}

	proc snitTooManyArgs {obj method arglist} {
	    tcltest::tooManyArgs $method [linsert $arglist 0 \
		    type selfns win self]
	}
    }
}

# ### ### ### ######### ######### #########
## Procedures that load files from various locations within the local Tcllib
## or that load local Tcllib packages.  To avoid contamination of the test
## suite by packages and code outside of the Tcllib under test, none of them go
## through the auto-loader nor use the regular package management procedures.

proc asset args {
    set localPath [file join [uplevel 1 [
		list [namespace which localPath]]]]
	foreach location {test-assets {.. test-assets}} {
		set candidate [eval file join [list $localPath] $location $args]
		if {[file exists $candidate]} {
			set {asset path} $candidate
			break
		}
	}
	if {![info exists {asset path}]} {
		error [list {can not find asset path}]
	}
	return ${asset path}
}

proc asset-get args {
	file-get [uplevel 1 [list [namespace which asset]] $args]
}

proc file-get path {
    set c [open $path r]
    set d [read $c]
    close $c
    return $d
}

proc localDirectory {} {
    set script [uplevel 1 [list ::info script]]
    file dirname [file dirname [file normalize [
	    file join $script[set script {}] ...]]]
}

# General access to module-local files
proc localPath args {
    set {script dir} [uplevel 1 [list [namespace which localDirectory]]]
    eval file join [list ${script dir}] $args
}

# General access to global (project-local) files
proc tcllibPath {fname} {
    return [file join $::tcllib::testutils::tcllib $fname]
}

proc useLocalFile {fname} {
    return [uplevel 1 [list source [localPath $fname]]]
}

proc useTcllibFile {fname} {
    return [uplevel 1 [list source [tcllibPath $fname]]]
}

proc use {fname pname args} {
    set nsname ::$pname
    if {[llength $args]} {set nsname [lindex $args 0]}

    package forget $pname
    catch {namespace delete $nsname}

    if {[catch {
	uplevel 1 [list useTcllibFile $fname]
    } msg]} {
	puts "    Aborting the tests found in \"[file tail [info script]]\""
	puts "    Error in [file tail $fname]: $msg"
	return -code error ""
    }

    puts "$::tcllib::testutils::tag [list $pname] [package present $pname]"
    return
}

proc useKeep {fname pname args} {
    set nsname ::$pname
    if {[llength $args]} {set nsname [lindex $args 0]}

    package forget $pname

    # Keep = Keep the existing namespace of the package.
    #      = Do not delete it. This is required if the
    #        namespace contains commands created by a
    #        binary package, like 'tcllibc', as they cannot
    #        be re-created.
    ##
    ## catch {namespace delete $nsname}

    if {[catch {
	uplevel 1 [list useTcllibFile $fname]
    } msg]} {
	puts "    Aborting the tests found in \"[file tail [info script]]\""
	puts "    Error in [file tail $fname]: $msg"
	return -code error ""
    }

    puts "$::tcllib::testutils::tag [list $pname] [package present $pname]"
    return
}

proc useLocal {fname pname args} {
    set nsname ::$pname
    if {[llength $args]} {set nsname [lindex $args 0]}

    package forget $pname
    catch {namespace delete $nsname}

    if {[catch {
	uplevel 1 [list useLocalFile $fname]
    } msg]} {
	puts "    Aborting the tests found in \"[file tail [info script]]\""
	puts "    Error in [file tail $fname]: $msg"
	return -code error ""
    }

    puts "$::tcllib::testutils::tag [list $pname] [package present $pname]"
    return
}

proc useLocalKeep {fname pname args} {
    set nsname ::$pname
    if {[llength $args]} {set nsname [lindex $args 0]}

    package forget $pname

    # Keep = Keep the existing namespace of the package.
    #      = Do not delete it. This is required if the
    #        namespace contains commands created by a
    #        binary package, like 'tcllibc', as they cannot
    #        be re-created.
    ##
    ## catch {namespace delete $nsname}

    if {[catch {
	uplevel 1 [list useLocalFile $fname]
    } msg]} {
	puts "    Aborting the tests found in \"[file tail [info script]]\""
	puts "    Error in [file tail $fname]: $msg"
	return -code error ""
    }

    puts "$::tcllib::testutils::tag [list $pname] [package present $pname]"
    return
}

proc useAccel {acc fname pname args} {
    set use [expr {$acc ? "useKeep" : "use"}]
    uplevel 1 [linsert $args 0 $use $fname $pname]
}

proc support {script} {
    InitializeTclTest
    set ::tcllib::testutils::tag "-"
    if {[catch {
	uplevel 1 $script
    } msg]} {
	set prefix "SETUP Error (Support): "
	puts $prefix[join [split $::errorInfo \n] "\n$prefix"]

	return -code return
    }
    return
}

proc testing {script} {
    InitializeTclTest

    set ::tcllib::testutils::tag *
    if {[catch {
	uplevel 1 $script
    } msg]} {
	set prefix "SETUP Error (Testing): "
	puts $prefix[join [split $::errorInfo \n] "\n$prefix"]

	return -code return
    }
    return
}

proc useTcllibC {} {
    set index [tcllibPath tcllibc/pkgIndex.tcl]
    if {![file exists $index]} {
	# Might have an external tcllibc
	if {![catch {
	    package require tcllibc
	}]} {
	    puts "$::tcllib::testutils::tag tcllibc [package present tcllibc]"
	    puts "$::tcllib::testutils::tag tcllibc = [package ifneeded tcllibc [package present tcllibc]]"
	    return 1
	}

	return 0
    }

    set ::dir [file dirname $index]
    uplevel #0 [list source $index]
    unset ::dir

    package require tcllibc

    puts "$::tcllib::testutils::tag tcllibc [package present tcllibc]"
    puts "$::tcllib::testutils::tag tcllibc = [package ifneeded tcllibc [package present tcllibc]]"
    return 1
}

# ### ### ### ######### ######### #########
## General utilities

# - dictsort -
#
#  Sorts a dictionary by its keys so that in its list representation the keys
#  are found in ascending alphabetical order, making it easier to directly
#  compare another dictionary
#
# Arguments:
#	dict:	The dictionary to sort.
#
# Result:
#	The canonical representation of the dictionary.

proc dictsort {dict} {
    array set a $dict
    set out [list]
    foreach key [lsort [array names a]] {
	lappend out $key $a($key)
    }
    return $out
}

# ### ### ### ######### ######### #########
## Puts strings together.  Useful when the strings cannot be expressed easily as
## one string due to quoting problems.

proc cat {args} {
    return [join $args ""]
}

# ### ### ### ######### ######### #########
## Mini-logging facility.  Can also be viewed as an accumulator for complex
## results.
#
# res!      : clear accumulator.
# res+      : add arguments to accumulator.
# res?      : query contents of accumulator.
# res?lines : query accumulator and format as
#             multiple lines, one per list element.

proc res! {} {
    variable result {}
    return
}

proc res+ {args} {
    variable result
    lappend  result $args
    return
}

proc res? {} {
    variable result
    return  $result
}

proc res?lines {} {
    return [join [res?] \n]
}

# ### ### ### ######### ######### #########
## Procedures that help deal with packages that have multiple implementations,
## i.e.  their pure Tcl implementation along with one or more accelerators.
## Assumes a specific API for accessing the data about available accelerators,
## switching between them, etc.

# == Assumed API ==
#
# KnownImplementations --
#   Returns list of all known implementations.
#
# Implementations --
#   Returns list of activated implementations.
#   A subset of 'KnownImplementations'.
#
# Names --
#   Returns a dict mapping all known implementations
#   to human-readable strings for output during a
#   test run.
#
# LoadAccelerator accel --
#   Tries to make the implementation named
#   'accel' available for use.  True if
#   successful, and false otherwise.
#
# SwitchTo accel --
#   Activates the implementation named 'accel'.
#   The empty string disables all implementations.

proc TestAccelInit {namespace} {
    # Disable all implementations ... Base state.
    ${namespace}::SwitchTo {}

    # List the implementations.
    array set map [${namespace}::Names]
    foreach e [${namespace}::KnownImplementations] {
	if {[${namespace}::LoadAccelerator $e]} {
	    puts "> $map($e)"
	}
    }
    return
}

proc TestAccelDo {namespace var script} {
    upvar 1 $var impl
    foreach impl [${namespace}::Implementations] {
	${namespace}::SwitchTo $impl
	uplevel 1 $script
    }
    return
}

proc TestAccelExit {namespace} {
    # Reset the system to a fully inactive state.
    ${namespace}::SwitchTo {}
    return
}

# ### ### ### ######### ######### #########
##

proc TestFiles pattern {
    set {local directory} [uplevel 1 [list [namespace which localDirectory]]]
    if {[package vsatisfies [package provide Tcl] 8.3]} {
	# 8.3+ -directory ok
	set flist [glob -nocomplain -directory ${local directory} $pattern]
    } else {
	# 8.2 or less, no -directory
	set flist [glob -nocomplain [file join ${local directory} $pattern]]
    }
    foreach f [lsort -dict $flist] {
	uplevel 1 [list source $f]
    }
    return
}

proc TestFilesGlob pattern {
    set {local directory} [uplevel 1 [list [namespace which localDirectory]]]
    if {[package vsatisfies [package provide Tcl] 8.3]} {
	# 8.3+ -directory ok
	set flist [glob -nocomplain -directory ${local directory} $pattern]
    } else {
	# 8.2 or less, no -directory
	set flist [glob -nocomplain [file join ${local directory} $pattern]]
    }
    return [lsort -dict $flist]
}

# ### ### ### ######### ######### #########
##

::tcllib::testutils::SaveEnvironment

# ### ### ### ######### ######### #########
package provide tcllib::testutils 1.2
puts "- tcllib::testutils [package present tcllib::testutils]"
return
