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
## Commands for common functions and boilerplate actions required by
## many testsuites of Tcllib modules and packages in a central place
## for easier maintenance.

# ### ### ### ######### ######### #########
## Declare the minimal version of Tcl required to run the package
## tested by this testsuite, and its dependencies.

proc testsNeedTcl {version} {
    # This command ensures that a minimum version of Tcl is used to
    # run the tests in the calling testsuite. If the minimum is not
    # met by the active interpreter we forcibly bail out of the
    # testsuite calling the command. The command has to be called
    # immediately after loading the utilities.

    if {[package vsatisfies [package provide Tcl] $version]} return

    puts "    Aborting the tests found in \"[file tail [info script]]\""
    puts "    Requiring at least Tcl $version, have [package present Tcl]."

    # This causes a 'return' in the calling scope.
    return -code return
}

# ### ### ### ######### ######### #########
## Declare the minimum version of Tcltest required to run the
## testsuite.

proc testsNeedTcltest {version} {
    # This command ensure that a minimum version of the Tcltest
    # support package is used to run the tests in the calling
    # testsuite. If the minimum is not met by the loaded package we
    # forcibly bail out of the testsuite calling the command. The
    # command has to be called after loading the utilities. The only
    # command allowed to come before it is 'testNeedTcl' above.

    # Note that this command will try to load a suitable version of
    # Tcltest if the package has not been loaded yet.

    if {[lsearch [namespace children] ::tcltest] == -1} {
	if {![catch {
	    package require tcltest $version
	}]} {
	    namespace import -force ::tcltest::*
	    InitializeTclTest
	    return
	}
    } elseif {[package vcompare [package present tcltest] $version] >= 0} {
	InitializeTclTest
	return
    }

    puts "    Aborting the tests found in [file tail [info script]]."
    puts "    Requiring at least tcltest $version, have [package present tcltest]"

    # This causes a 'return' in the calling scope.
    return -code return
}

proc testsNeed {name version} {
    # This command ensures that a minimum version of package <name> is
    # used to run the tests in the calling testsuite. If the minimum
    # is not met by the active interpreter we forcibly bail out of the
    # testsuite calling the command. The command has to be called
    # immediately after loading the utilities.

    if {[catch {
	package require $name $version
    }]} {
	puts "    Aborting the tests found in \"[file tail [info script]]\""
	puts "    Requiring at least $name $version, package not found."

	return -code return
    }

    if {[package vsatisfies [package present $name] $version]} return

    puts "    Aborting the tests found in \"[file tail [info script]]\""
    puts "    Requiring at least $name $version, have [package present $name]."

    # This causes a 'return' in the calling scope.
    return -code return
}

# ### ### ### ######### ######### #########

## Save/restore the environment, for testsuites which have to
## manipulate it to (1) either achieve the effects they test
## for/against, or (2) to shield themselves against manipulation by
## the environment. We have examples for both in 'fileutil' (1), and
## 'doctools' (2).
##
## Saving is done automatically at the beginning of a test file,
## through this module. Restoration is done semi-automatically.  We
## __cannot__ hook into the tcltest cleanup hook It is already used by
## all.tcl to transfer the information from the slave doing the actual
## tests to the master. Here the hook is only an alias, and
## unmodifiable. We create a new cleanup command which runs both our
## environment cleanup, and the regular one. All .test files are
## modified to use the new cleanup.

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
## Newer versions of the Tcltest support package for testsuite provide
## various features which make the creation and maintenance of
## testsuites much easier. I consider it important to have these
## features even if an older version of Tcltest is loaded. To this end
## we now provide emulations and implementations, conditional on the
## version of Tcltest found to be active.

# ### ### ### ######### ######### #########
## Easy definition and initialization of test constraints.

proc InitializeTclTest {} {
    global tcltestinit
    if {[info exists tcltestinit] && $tcltestinit} return
    set tcltestinit 1

    if {![package vsatisfies [package provide tcltest] 2.0]} {
	# Tcltest 2.0+ provides a documented public API to define and
	# initialize a test constraint. For earlier versions of the
	# package the user has to directly set a non-public undocumented
	# variable in the package's namespace. We create a command doing
	# this and emulating the public API.

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

    ::tcltest::testConstraint tcl8.4plus \
	[expr {[package vsatisfies [package provide Tcl] 8.4]}]

    ::tcltest::testConstraint tcl8.5plus \
	[expr {[package vsatisfies [package provide Tcl] 8.5]}]

    ::tcltest::testConstraint tcl8.6plus \
	[expr {[package vsatisfies [package provide Tcl] 8.6]}]

    ::tcltest::testConstraint tcl8.4minus \
	[expr {![package vsatisfies [package provide Tcl] 8.5]}]

    ::tcltest::testConstraint tcl8.5minus \
	[expr {![package vsatisfies [package provide Tcl] 8.6]}]

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
	    # create a different message for functions with no args
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
	    # create a different message for functions with no args
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
	# returns only the path of the newly generated file. We
	# standardize on the more useful behaviour of 2.0+. If 1.x is
	# present we have to create an emulation layer to get the
	# wanted result.

	# 1.0 is not fully correctly described. If the file was
	# created before no list is returned at all. We force things
	# by adding a line to the old procedure which makes the result
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
## Command to construct wrong/args messages for Snit methods.

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
	    tcltest::wrongNumArgs "$method" [linsert $arglist 0 \
		    type selfns win self] $missingIndex
	}

	proc snitTooManyArgs {obj method arglist} {
	    tcltest::tooManyArgs "$method" [linsert $arglist 0 \
		    type selfns win self]
	}
    }
}

# ### ### ### ######### ######### #########
## Commands to load files from various locations within the local
## Tcllib, and the loading of local Tcllib packages. None of them goes
## through the auto-loader, nor the regular package management, to
## avoid contamination of the testsuite by packages and code outside
## of the Tcllib under test.

proc localPath {fname} {
    return [file join $::tcltest::testsDirectory $fname]
}

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
    #        binary package, like 'tcllibc'. They cannot
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
    #        binary package, like 'tcllibc'. They cannot
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
    set ::tcllib::testutils::tag "*"
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
#  Sort a dictionary by its keys. I.e. reorder the contents of the
#  dictionary so that in its list representation the keys are found in
#  ascending alphabetical order. In other words, this command creates
#  a canonical list representation of the input dictionary, suitable
#  for direct comparison.
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
## Putting strings together, if they cannot be expressed easily as one
## string due to quoting problems.

proc cat {args} {
    return [join $args ""]
}

# ### ### ### ######### ######### #########
## Mini-logging facility, can also be viewed as an accumulator for
## complex results.
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
## Helper commands to deal with packages
## which have multiple implementations, i.e.
## their pure Tcl base line and one or more
## accelerators. We are assuming a specific
## API for accessing the data about available
## accelerators, switching between them, etc.

# == Assumed API ==
#
# KnownImplementations --
#   Returns list of all known implementations.
#
# Implementations --
#   Returns list of activated implementations.
#   A subset of 'KnownImplementations'
#
# Names --
#   Returns dict mapping all known implementations
#   to human-readable strings for output during a
#   test run
#
# LoadAccelerator accel --
#   Tries to make the implementation named
#   'accel' available for use. Result is boolean.
#   True indicates a successful activation.
#
# SwitchTo accel --
#   Activate the implementation named 'accel'.
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

proc TestFiles {pattern} {
    if {[package vsatisfies [package provide Tcl] 8.3]} {
	# 8.3+ -directory ok
	set flist [glob -nocomplain -directory $::tcltest::testsDirectory $pattern]
    } else {
	# 8.2 or less, no -directory
	set flist [glob -nocomplain [file join $::tcltest::testsDirectory $pattern]]
    }
    foreach f [lsort -dict $flist] {
	uplevel 1 [list source $f]
    }
    return
}

proc TestFilesGlob {pattern} {
    if {[package vsatisfies [package provide Tcl] 8.3]} {
	# 8.3+ -directory ok
	set flist [glob -nocomplain -directory $::tcltest::testsDirectory $pattern]
    } else {
	# 8.2 or less, no -directory
	set flist [glob -nocomplain [file join $::tcltest::testsDirectory $pattern]]
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
