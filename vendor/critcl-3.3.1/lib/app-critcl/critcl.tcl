#!/bin/sh
# -*- tcl -*-
# # ## ### ##### ######## ############# #####################

# Critcl Application.

# # ## ### ##### ######## ############# #####################

# Prebuild shared libraries using the Critcl package.
#
#   Based originally on critbind by Jean-Claude Wippler
#   Transmogrified into critcl   by Steve Landers
#
# Copyright (c) 2001-20?? Jean-Claude Wippler
# Copyright (c) 2002-20?? Steve Landers
# Copyright (c) 20??-2024 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# \
    exec tclkit $0 ${1+"$@"}

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.6 9
package provide critcl::app [package require critcl]

# It is expected here that critcl already imported platform, or an
# equivalent package, i.e. the critcl::platform fallback. No need to
# do it again.
#package require platform

# Note: We can assume here that the commands lassign and dict are
# available. The critcl package has made sure of that.

namespace eval ::critcl::app {}

# # ## ### ##### ######## ############# #####################
## https://github.com/andreas-kupries/critcl/issues/112
## Ensure that we have maximal 'info frame' data, if supported
#
## ATTENTION: This slows the Tcl core down by about 10%, sometimes
## more, due to the need to track location information in some
## critical paths of Tcl_Obj management.
#
## I am willing to pay that price here, because this is isolated to
## the operation of the critcl application itself. While some more
## time is spent in the ahead-of-time compilation the result is not
## affected. And I want the more precise location information for when
## compilation fails.

catch { interp debug {} -frame 1 }

# # ## ### ##### ######## ############# #####################
## Intercept 'package' calls.
#
# This code is present to handle the possibility of building multiple
# different versions of the same package, or of different packages
# having dependencies on different versions of a 3rd party
# package. Each will 'package provide' its version to our Tcl, and
# thus normally be reported as a conflict. To prevent that the
# intercepted command checks for this situation, and forces Tcl to
# forget the previously registered package.

rename package ::critcl::app::__package
proc package {option args} {
    if {$option eq "provide"} {
        if {![catch {
	    set v [::critcl::app::__package present [lindex $args 0]]
	}] &&
	    ([llength $args] > 1) &&
	    ($v ne [lindex $args 1])
	} {
	    # A package is provided which is already present in
	    # memory, the number of arguments is ok, and the version
	    # of the new package is different from what is
	    # known. Force Tcl to forget the previous package, this is
	    # not truly a conflict.
            ::critcl::app::__package forget [lindex $args 0]
        }
    }

    return [eval [linsert $args 0 ::critcl::app::__package $option]]
}

# # ## ### ##### ######## ############# #####################
## Override the default of the critcl package for errors and
## message. Write them to the terminal (and, for errors, abort the
## application instead of throwing them up the stack to an uncertain
## catch).

proc ::critcl::error {msg} {
    global argv0
    puts stderr "$argv0 error: $msg"
    flush stderr
    exit 1
}

proc ::critcl::msg {args} {
    switch -exact -- [llength $args] {
	1 {
	    puts stdout [lindex $args 0]
	    flush stdout
	}
	2 {
	    lassign $args o m
	    if {$o ne "-nonewline"} {
		return -code error "wrong\#args, expected: ?-nonewline? msg"
	    }
	    puts -nonewline stdout $m
	    flush stdout
	}
	default {
	    return -code error "wrong\#args, expected: ?-nonewline? msg"
	}
    }
    return
}

# # ## ### ##### ######## ############# #####################
##
# Rewrite the hook handling declarations found after the build.
# The default of clearing state for a new build is not the right
# thing to do in mode "precompile". Here we want to see an ERROR.

proc ::critcl::HandleDeclAfterBuild {} {
    if {![done]} return
    set cloc {}
    if {![catch {
	array set loc [info frame -2]
    } msg]} {
	if {$loc(type) eq "source"} {
	    set cloc "@$loc(file):$loc(line)"
	} else {
	    set cloc " ([array get loc])"
	}
    } ;#else { set cloc " ($msg)" }

    append err [lindex [info level -1] 0]
    append err $cloc
    append err ": Illegal attempt to define C code in [This] after it was built."
    append err \n [at::SHOWFRAMES]
    error $err
}

# # ## ### ##### ######## ############# #####################

proc ::critcl::app::main {argv} {
    Cmdline $argv

    # When creating a package use a transient cache which is not in
    # conflict with "compile & run", or other instances of the critcl
    # application.

    if {$v::mode eq "pkg"} {
	set pkgcache [PackageCache]
	critcl::cache $pkgcache
	critcl::fastuuid
    }

    ProcessInput
    StopOnFailed

    # All input files have been processed and their data saved. Now
    # generate the boilerplate bracketing all the sub-ordinate
    # Foo_Init() functions, i.e. the code which provides a single
    # initialization function for the whole set of input files.

    if {$v::mode eq "pkg"} {
	# Create a merged shared library and put a proper Tcl package
	# around it.

	BuildBracket
	StopOnFailed
	AssemblePackage

	if {!$v::keep} {
	    file delete -force $pkgcache
	}
    } elseif {$v::mode eq "tea"} {
	AssembleTEA
    }

    StopOnFailed

    if {$v::keep} {
	::critcl::print stderr "Files left in [critcl::cache]"
    }

    ::critcl::print "Done\n"
    return
}

proc ::critcl::app::PackageCache {} {
    global env
    if {$v::cache ne {}} {
	return $v::cache
    }
    return [file join $env(HOME) .critcl pkg[pid].[clock seconds]]
}

proc ::critcl::app::StopOnFailed {} {
    if {!$v::failed} return
    ::critcl::print stderr "Files left in [critcl::cache]"
    ::critcl::print stderr "FAILURES $v::failed"
    ::critcl::print stderr "FAILED:  [join $v::borken "\nFAILED:  "]"
    ::critcl::print stderr "FAILED   [join [split [join $v::log \n\n] \n] "\nFAILED   "]"
    exit 1 ; #return -code return
}

proc ::critcl::app::Cmdline {argv} {
    variable options

    # Rationalized application name. Direct user is the intercepted
    # '::critcl::error' command.
    set ::argv0 [file rootname [file tail $::argv0]]

    # Semi-global application configuration.
    set v::verbose  0      ; # Default, no logging.
    set v::src     {}      ; # No files to process.
    set v::mode    cache   ; # Fill cache. Alternatively build a
			     # package, or TEA hierarchy.
    set v::shlname ""      ; # Name of shlib to build.
    set v::outname ""      ; # Name of shlib dir to create.
    set v::libdir  lib     ; # Directory to put the -pkg or -tea
			     # directory into.
    set v::incdir  include ; # Directory to put the -pkg include files into (stubs export),
                             # and search in (stubs import)
    set v::keep    0       ; # Default: Do not keep generated .c files.

    # Local actions.
    set selftest   0 ;# Invoke the application selftest, which simply
                      # runs whatever test/*.tst files are found in the
                      # starkit or starpack. IOW, this functionality is
                      # usable only for a wrapped critcl application.
    set cleaning   0 ;# Clean the critcl cache. Default: no.
    set showall    0 ;# Show all configurations in full. Default: no.
    set show       0 ;# Show the chosen build configuration. Default: no.
    set showtarget 0 ;# Show the chosen build target only. Default: no.
    set targets    0 ;# Show the available targets.
    set help       0 ;# Show the application's help text.

    # Local configuration. Seen outside of this procedure only
    # directly, through the chosen build configuration.

    set target     "" ;# The user-specified build target, if any.
    set configfile "" ;# The user-specified custom configuration file,
		       # if any

    # Process the command line...

    while {[set result [Getopt argv $options opt arg]] != 0} {
	if {$result == -1} {
	    switch -glob -- $opt {
		with-* {
		    set argv [lassign $argv opt arg]
		    regsub {^-with-} $opt {} opt
		    lappend v::uc $opt $arg
		    continue
		}
		default {
		    Usage "Unknown option \"$opt\""
		}
	    }
	}
	switch -exact -- $opt {
	    v - -version {
		::critcl::print [package present critcl]
		::exit 0
	    }
	    I          { AddIncludePath $arg }
	    L          { AddLibraryPath $arg }
	    cache      { set v::cache $arg }
	    clean      { incr cleaning }
	    config     { set configfile $arg }
	    debug      {
		lappend v::debug $arg
		#critcl::config lines 0
	    }
	    force      {
		critcl::config force 1
		::critcl::print stderr "Compilation forced"
	    }
	    disable-tcl9 {
		critcl::config tcl9 0
		::critcl::print stderr "Disabled checking for Tcl 9 compatibility issues"
	    }
	    keep       {
		critcl::config keepsrc 1
		#critcl::config lines 0
		set v::keep 1
	    }
	    trace-commands {
		critcl::config trace 1
	    }
	    trace {
		critcl::cflags -DCRITCL_TRACER
	    }
	    help       { incr help }
	    libdir     {
		set v::libdir $arg

		# In case critcl is wrapped Tcl must be told about the
		# outside location for packages.

		lappend ::auto_path $arg
		lappend ::auto_path [file dirname $arg]
		AddLibraryPath $arg
	    }
	    includedir {
		set v::incdir  $arg
		AddIncludePath $arg
	    }
	    enable     { lappend v::uc $arg 1 }
	    disable    { lappend v::uc $arg 0 }
	    pkg        { set v::mode pkg ; incr v::verbose }
	    tea        { set v::mode tea ; incr v::verbose }
	    show       { incr show }
	    showall    { incr showall }
	    showtarget { incr showtarget }
	    target     { set target $arg }
	    targets    { incr targets }
	    test       { set selftest 1 }
	    default {
		Usage "Unknown option \"$opt\""
	    }
	}
    }

    # ... validate the settings, and act on them.

    if {$help} {
	Help
	exit
    }

    # Parse the user-specified configuration file, if any. This
    # overrides the default configuration file read by the critcl
    # package when it was loaded. It does keep the default platform
    # from that active.

    if {$configfile ne ""} {
	if {$argv eq "" && [file extension $configfile] eq ".tcl"} {
	    # probably means the user has omitted the config file and we've
	    # picked up the source file name
	    Usage "-config is missing file argument"
	}
	if {![file exists $configfile]} {
	    Usate "Can't read configuration file $configfile"
	}
	critcl::readconfig $configfile
    }

    # And switch to the user-provided target platform.

    if {$target ne ""} {
	if {($argv eq "") && [file extension $target] eq ".tcl"} {
	    # probably means the user has omitted the config file and we've
	    # picked up the source file name
	    Usage "-target is missing file argument"
	}

	set match [critcl::chooseconfig $target 1]

	if {[llength $match] == 1} {
	    critcl::setconfig [lindex $match 0]
	} else {
	    Usage "multiple targets matched : $match"
	}
    }

    if {($v::mode eq "pkg") || $show} {
	critcl::crosscheck
    }

    if {$cleaning} {
	critcl::clean_cache
    }

    if {$show} {
	if {$v::mode eq "pkg"} {
	    critcl::cache [PackageCache]
	}
	critcl::showconfig stdout
    }

    if {$showall} {
	critcl::showallconfig stdout
    }

    if {$showtarget} {
	::critcl::print [critcl::targetplatform]
    }

    if {$targets} {
	::critcl::print [critcl::knowntargets]
    }

    if {$show || $showall || $targets || $showtarget} {
	exit
    }

    if {$selftest} {
	Selftest
	exit
    }

    # Invoking the application without input files is an error, except
    # if it was to just clean the local critcl cache.

    if {[llength $argv] < 1} {
	if {!$cleaning} Usage
	exit
    }

    # The remainder of the arguments are the files to process, except
    # for lib and pkg modes where they can be prefixed with the name
    # of the output file, i.e. shared library. If however no such
    # output file is present the name of the first input file will be
    # used as name of the library.

    set v::src $argv

    # (%) Determine the name of the shared library to generate from
    # the input files. This location is referenced by (=).

    if {$v::mode ne "cache"} {
	set name [lindex $argv 0]
	set addext 0

	# Split a version number off the package name.
	set ver {}
	if {[regexp {^([^0-9]+)([0-9][.0-9]*)$} $name -> base ver]} {
	    set name $base
	}

	switch [file extension $name] {
	    .dll   -
	    .dylib -
	    .sl    -
	    .so {
		# The name of the result shlib is prefixed, take it as
		# package name, and strip it off the list of input
		# files.
		set v::outname [file rootname $name]
		set v::src     [lrange $v::src 1 end]
		set addext 1
	    }
	    .tcl {
		# We have no discernible result shlib, take
		# the stem of the first input file as package
		# name

		set v::outname [file rootname $name]
		set addext 1
	    }
	    "" {
		# See above for .tcl, except that there is no stem to
		# take. And if this is the only argument we also have
		# to derive the full name of the expected input file
		# from it.
		set v::outname $name
		if {[llength $argv] == 1} {
		    set v::src [list $v::outname.tcl]
		} else {
		    set v::src [lrange $v::src 1 end]
		}
	    }
	    default {
		Usage "Not sure how to handle \"$name\""
	    }
	}

	# Put the version number back. We have to distinguish package
	# library file name and package directory name. Only the
	# latter should have the version number.
	set v::shlname $v::outname
	if {$ver ne {}} {
	    append v::outname $ver
	}

	if {$addext || ([file extension $v::shlname] eq "")} {
	    append v::shlname [critcl::sharedlibext]
	}

	critcl::config combine dynamic

	if {![llength $v::src]} {
	    Usage "No input files"
	}
    }

    # Determine the platform to use by the build backend, based on
    # actual platform we are on and the user's chosen target, if any.

    set v::actualplatform [::critcl::actualtarget]
    return
}

proc ::critcl::app::AddIncludePath {path} {
    set dirs [critcl::config I]
    lappend dirs [file normalize $path]
    critcl::config I $dirs
    return
}

proc ::critcl::app::AddLibraryPath {path} {
    set dirs [critcl::config L]
    lappend dirs [file normalize $path]
    critcl::config L $dirs
    return
}

proc ::critcl::app::Log {text} {
    if {!$v::verbose} return
    ::critcl::print -nonewline $text
    flush stdout
    return
}

proc ::critcl::app::LogLn {text} {
    if {!$v::verbose} return
    ::critcl::print $text
    flush stdout
    return
}

proc ::critcl::app::Usage {args} {
    global argv0
    if {[llength $args]} {
	::critcl::print stderr "$argv0 error: [join $args]"
    }

    ::critcl::print stderr [string map [list @ $argv0] {To compile and run a tcl script
	@ [-force] [-keep] [-cache dir] file[.tcl]

To compile and build a package
    @ options -pkg ?name? [files...]

To repackage for TEA
    @ options -tea ?name? [files...]

Options include:
    -debug [symbols|memory|all] enable debugging
    -force          force compilation of C files
    -show           show the configuration options being used
    -target target  generate binary for specified target platform/architecture

Other options that may be useful:
    -I dir          adds dir to the include search path when compiling.
    -L dir          adds dir to the library search path when linking.
    -cache dir      sets the Critcl cache directory to dir.
    -keep           keep intermediate C files in the Critcl cache
    -config file    read the Critcl configuration options from file
    -libdir dir     location of generated library/package
    -includedir dir location of generated package headers (stubs)
    -showall        show configuration for all supported platforms
    -targets        show all available target platforms

You can display the built-in help wiki on most platforms using:
    @ -help }]
    exit 1
    return
}

proc ::critcl::app::Help {} {
    if {[catch {package require Mk4tcl} msg] ||
	[catch {package require Wikit} msg]} {
	::critcl::print $msg
        set txt "Couldn't load the Critcl help Wiki\n"
        append txt "To display the Critcl help wiki run \"critcl\" "
        append txt "without any options.\n"
        ::critcl::print $txt
        exit
    } else {
        Wikit::init [file join $::starkit::topdir doc critcl.tkd]
    }
}

proc ::critcl::app::Selftest {} {
    foreach t [glob -directory [file join $::starkit::topdir test] *.tst] {
        source $t
    }
    return
}

proc ::critcl::app::ProcessInput {} {
    # Main loop. This processes the input files, one by one.

    set v::debug [lsort -unique $v::debug]

    # NOTE that this effectively executes them (source!) in the
    # context of this application. The files are trusted to not
    # contain malicious side-effects, etc.

    # Initialize the accumulator variables for various per-file
    # information which will be needed later when building the
    # over-arching initialization code.

    set v::clibraries {}  ;# External libraries used. To link the final shlib against.
    set v::ldflags    {}  ;# Linker flags.
    set v::objects    {}  ;# The object files to link.
    set v::edecls     {}  ;# Initialization function decls for the pieces.
    set v::initnames  {}  ;# Initialization function calls for the pieces.
    set v::tsources   {}  ;# Tcl companion sources.
    set v::mintcl     8.4 ;# Minimum version of Tcl required to run the package.
    set v::tk         0   ;# Boolean flag. Set if any sub-package needs Tk, forcing it on the collection as well.
    set v::preload    {}  ;# List of libraries declared for preload.
    set v::license    {}  ;# Accumulated licenses, if any.
    set v::failed      0  ;# Number of build failures encountered.
    set v::borken     {}  ;# List of files which failed to build.
    set v::log        {}  ;# List of log messages for the failed files
    set v::headers    {}  ;# List of header directories (in the result cache)
                           # to export.
    set v::pkgs       {}  ;# List of package names for the pieces.
    set v::inits      {}  ;# Init function names for the pieces, list.
    set v::meta       {}  ;# All meta data declared by the input files.

    # Other loop status information.

    set first  1  ;# Flag, reset after first round, helps with output formatting.
    set missing 0

    if {$v::mode eq "tea"} {
	LogLn "Config:   TEA Generation"
	Log   "Source:   "

	# Initialize the accumulator variables for various per-file
	# information.

	set v::org      {} ; # Organization the package is licensed by.
	set v::ver      {} ; # Version of the package.
	set v::cfiles   {} ; # Companion files (.tcl, .c, .h, etc).
	set v::teasrc   {} ; # Input file(s) transformed for use in the Makefile.in.
	set v::imported {} ; # List of stubs APIs imported from elsewhere.
	set v::config   {} ; # List of user-specified configuration settings.

    } elseif {[llength $v::src]} {
	LogLn "Config:   [::critcl::targetconfig]"
	LogLn "Build:    [::critcl::buildplatform]"

	set t [::critcl::targetplatform]
	if {$v::actualplatform ne $t} {
	    LogLn "Target:   $v::actualplatform (by $t)"
	} else {
	    LogLn "Target:   $v::actualplatform"
	}
	Log   "Source:   "
    }

    foreach f $v::src {
	# Avoid reloading itself.
	if {[file rootname [file tail $f]] eq "critcl"} continue

	if {$v::mode eq "tea"} {
	    lappend v::teasrc "\${srcdir}/src/[file tail $f]"
	}

	# Canonicalize input argument, and search in a few places.
	set fn [file normalize $f]

	set found [file exists $fn]
	if {!$found} {
	    if {[file extension $fn] ne ".tcl"} {
		append fn .tcl
		set found [file exists $fn]
	    }
	    if {!$found} {
		if {!$first} { ::critcl::print stderr "" }
		::critcl::print stderr "$f doesn't exist"
		incr missing
		continue
	    }
	}

	set first 0
	LogLn "[file tail $fn]"
	set dir [file dirname $fn]

	if {$v::mode eq "tea"} {
	    # In TEA mode we are not building anything at all. We only
	    # wish to know and scan for the declarations of companion
	    # files, so that we know what to put these into the TEA
	    # directory hierarchy. This also provides us with the
	    # version number to use.

	    LogLn ""
	    array set r [critcl::scan $fn]
	    lappend v::cfiles $f $r(files)
	    if {$r(org) ne {}} {
		lappend v::org $r(org)
	    }
	    if {$r(version) ne {}} {
		lappend v::ver $r(version)
	    }
	    if {$r(imported) ne {}} {
		critcl::lappendlist v::imported $r(imported)
	    }
	    if {$r(config) ne {}} {
		critcl::lappendlist v::config $r(config)
	    }
	    if {$r(meta) ne {}} {
		lappend v::meta $r(meta)
	    }
	    continue
	}

	# Execute the input file and collect all the crit(i)c(a)l :)
	# information. Depending on the use of 'critcl::failed' this
	# may or may not have generated the internal object file.

	if {$v::mode eq "pkg"} {
	    critcl::buildforpackage
	}

	if {[llength $v::debug]} {
	    # As the debug settings are stored per file we now take
	    # the information from the application's commandline and
	    # force things here, faking the proper path information.

	    set save [info script]
	    info script $fn
	    eval [linsert $v::debug 0 critcl::debug]
	    info script $save
	}

	#puts ||$v::uc||
	if {[llength $v::uc]} {
	    # As the user-config settings are stored per file we now
	    # take the information from the application's commandline
	    # and force things here, faking the proper path information.
	    # Full checking of the data happens only if the setting is
	    # actually used by the file.

	    set save [info script]
	    info script $fn

	    foreach {k v} $v::uc {
		#puts UC($k)=|$v|
		critcl::userconfig set $k $v
	    }
	    info script $save
	}

	# Ensure that critcl's namespace introspection is done
	# correctly, and not thinking that 'critcl::app' is the
	# namespace to use for the user's commands.

	uplevel #0 [list source $fn]

	if {[critcl::cnothingtodo $fn]} {
	    ::critcl::print stderr "nothing to build for $f"
	    continue
	}

	# Force build. Our 'buildforpackage' call above disabled
	# 'critcl::failed' and 'critcl::load' (Causing them to return
	# OK, and bypassing anything conditional on their failure). If
	# there is a failure we want to know it correctly, here.
	#
	# Regardless, we have to force (and later restore) the proper
	# script location, something the 'source' comand above did
	# automatically.

	set save [info script]
	info script $fn
	set failed [critcl::cbuild $fn 0]
	incr v::failed $failed
	info script $save

	# We can skip the part where we collect the build results for
	# use by the overarching code if either no overall shlib is
	# generated from the input, or any of the builds made so far
	# failed.

	# NOTE that we were NOT skipping the build step for any of the
	# packages, even if previous packages failed. We want the
	# maximum information about problems from a single run, not
	# fix things one by one.

	set results [critcl::cresults $fn]
	if {$failed} {
	    lappend v::borken $f
	    lappend v::log    [dict get $results log]
	    Log "(FAILED) "
	} elseif {[dict exists $results warnings]} {
	    # There might be warnings to print even if the build did
	    # not fail.
	    set warnings [dict get $results warnings]
	    if {[llength $warnings]} {
		::critcl::print stderr "\n\nWarning  [join $warnings "\nWarning  "]"
	    }
	}
	if {$v::failed || ($v::mode ne "pkg")} continue

	array set r $results

	append v::edecls    "extern Tcl_AppInitProc $r(initname)_Init;\n"
	append v::initnames "    if ($r(initname)_Init(interp) != TCL_OK) return TCL_ERROR;\n"
	append v::license   [License $f $r(license)]

	lappend v::pkgs  $r(pkgname)
	lappend v::inits $r(initname)
	lappend v::meta  $r(meta)

	# The overall minimum version of Tcl required by the combined
	# packages is the maximum over all of their minima.
	set v::mintcl [Vmax $v::mintcl $r(mintcl)]
	set v::tk     [Max $v::tk $r(tk)]
	critcl::lappendlist v::objects    $r(objects)
	critcl::lappendlist v::tsources   $r(tsources)
	critcl::lappendlist v::clibraries $r(clibraries)
	critcl::lappendlist v::ldflags    $r(ldflags)
	critcl::lappendlist v::preload    $r(preload)

	if {[info exists r(apiheader)]} {
	    critcl::lappendlist v::headers $r(apiheader)
	}
    }

    if {$missing} {
	critcl::error  "Missing files: $missing, aborting"
    }

    # Reduce package and init function to the first pieces. Easier to
    # do it this way than having a conditional set in the loop.

    set v::pkgs  [lindex $v::pkgs  0]
    set v::inits [lindex $v::inits 0]
    # Strip the prefix used by the foundation package. Keep in sync.
    regsub {^ns_} $v::inits {} v::inits

    return
}

proc ::critcl::app::Vmax {a b} {
    if {[package vcompare $a $b] >= 0} {
	return $a
    } else {
	return $b
    }
}

proc ::critcl::app::Max {a b} {
    if {$a >= $b} {
	return $a
    } else {
	return $b
    }
}

proc ::critcl::app::License {file text} {
    if {$text eq "<<Undefined>>"} { return {} }
    return "\n\[\[ [file tail $file] \]\] __________________\n$text"
}

proc ::critcl::app::BuildBracket {} {
    ::critcl::print "\nLibrary:  [file tail $v::shlname]"

    # The overarching initialization code, the bracket, has no real
    # file behind it. Fake it based on the destination shlib, this
    # ensures that the generated _Init function has the proper name
    # without having to redefine things through C macros, as was done
    # before.
    info script $v::shlname

    critcl::config combine ""

    # Inject the information collected from the input files, making
    # them part of the final result.
    critcl::tcl $v::mintcl
    if {$v::tk} { critcl::tk }

    set                 lib critcl::cobjects
    critcl::lappendlist lib $v::objects
    eval $lib

    set                 lib critcl::clibraries
    critcl::lappendlist lib $v::clibraries
    eval $lib

    eval [linsert [lsort -unique $v::ldflags] 0 critcl::ldflags]
    eval [linsert [lsort -unique $v::preload] 0 critcl::preload]

    critcl::cinit $v::initnames $v::edecls

    # And build everything.
    critcl::buildforpackage 0
    set failed [critcl::cbuild "" 0]

    incr v::failed $failed
    if {$failed} {
	lappend v::borken <<Bracket>>
	Log "(FAILED) "
    }
    return
}

proc ::critcl::app::PlaceShlib {} {
    # Copy the generated shlib from the cache to its final resting
    # place. For -pkg this was set be inside the directory hierarchy
    # of the newly-minted package. To prevent hassle a previously
    # existing file gets deleted.

    if {[file exists $v::shlname]} {
	file delete -force $v::shlname
    }

    # NOTE that the fake 'info script location' set by 'BuildBracket'
    # is still in effect, making access to the build results easy.
    set shlib [dict get [critcl::cresults] shlib]
    file copy $shlib $v::shlname

    # For MSVC debug builds we get a separate debug info file.
    set pdb [file root $shlib].pdb
    if {[file exists $pdb]} {
	file copy -force $pdb [file root $v::shlname].pdb
    }

    # Record shlib in the meta data, list of package files.
    set d [file tail [file dirname $v::shlname]]
    set f [file tail $v::shlname]
    lappend v::meta [list included [file join $d $f]]
    return
}

proc ::critcl::app::ExportHeaders {} {
    set incdir [CreateIncludeDirectory]

    foreach dir [lsort -dict -uniq $v::headers] {
	set stem [file tail $dir]
	set dst  [file join $incdir $stem]

	::critcl::print "Headers Placed Into: $v::incdir/$stem"

	file mkdir $dst
	foreach f [glob -nocomplain -directory $dir *] {
	    file copy -force $f $dst
	}
    }
    return
}

proc ::critcl::app::AssemblePackage {} {
    # Validate and/or create the main destination directory L. The
    # package will become a subdirectory of L. See (x). And a platform
    # specific directory inside of that will hold the shared
    # library. This allows us to later merge the packages for
    # different platforms into a single multi-platform package.

    if {![llength $v::pkgs]} {
	::critcl::print stderr "ERROR: `package provide` missing in package sources"
	exit 1
    }

    set libdir [CreateLibDirectory]

    set libname  [file tail $v::outname]
    set pkgdir   [file join $libdir $libname]
    set shlibdir [file join $pkgdir $v::actualplatform]

    # XXX fileutil::stripPwd ...
    if {[string first [pwd] $pkgdir] != -1} {
	set first [string length [pwd]]
	set dir [string range $pkgdir [incr first] end]
    } else {
	set dir $pkgdir
    }
    ::critcl::print "\nPackage Placed Into: $dir"

    file mkdir             $pkgdir
    file mkdir             $shlibdir

    set shl [file tail $v::shlname]

    CreatePackageIndex     $shlibdir [file rootname $shl] \
	[PlaceTclCompanionFiles $pkgdir]
    CreateLicenseTerms     $pkgdir
    CreateRuntimeSupport   $pkgdir

    # Place the shlib generated by BuildBracket into its final resting
    # place, in the directory hierarchy of the just-assembled package.

    set v::shlname [file join $shlibdir $shl]
    PlaceShlib

    # At last we can generate and write the meta data. Many of the
    # commands before added application-level information (like
    # included files, entrytclcommand, ...) to the information
    # collected from the input files

    CreateTeapotMetadata $pkgdir
    ExportHeaders
    return
}

proc ::critcl::app::CreatePackageIndex {shlibdir libname tsources} {
    # Build pkgIndex.tcl

    set version [package present $v::pkgs]

    # (=) The 'package present' works because (a) 'ProcessInput'
    # sources the package files in its own context, this process, and
    # (b) the package files (are expected to) contain the proper
    # 'package provide' commands (for compile & run mode), and we
    # expect that at least one of the input files specifies the
    # overall package built from all the inputs. See also (%) in
    # Cmdline, where the application determines shlib name and package
    # name, often from the first input file, and/or working backwards
    # from package name to input file.

    set    index [open [file join [file dirname $shlibdir] pkgIndex.tcl] w]
    puts  $index [PackageGuard $v::mintcl]
    puts  $index [IndexCommand $version $libname $tsources $shlibdir]
    close $index
    return
}

proc ::critcl::app::Mapping {} {
    # Create the platform mapping for each of the platforms listed on
    # the Config platform line

    set map    [critcl::getconfigvalue platform]
    set minver [lindex $map 1]

    set plats  [list]
    foreach plat [lrange $map 2 end] {
	set mapping($plat) [list [critcl::actualtarget] $minver]
	lappend plats $plat
    }

    if {[llength $plats]} {
	::critcl::print "Platform: [join $plats {, }] $minver and later"
    }

    set map {}
    foreach plat [lsort [array names mapping]] {
	lappend map $plat $mapping($plat)
    }
    return $map
}

proc ::critcl::app::Preload {shlibdir} {
    if {![llength $v::preload]} { return {} }

    # Locate the external libraries declared for preloading and put
    # them into the package. Put the shared library of the internal
    # preload support pseudo-package into it as well. This will all be
    # picked up by the 'package ifneeded' script.

    # First handle the declared libraries. Any problem there throws an
    # error, or aborts.

    set preload {}
    foreach shlib $v::preload {
	file copy -force [PreloadLocation $shlib] $shlibdir
	lappend preload [file tail $shlib]
    }

    # Everything was ok, now place the supporting shlib into the
    # package as well.

    file copy -force \
	[file join [critcl::cache] preload[critcl::sharedlibext]] \
	$shlibdir

    ::critcl::print "Preload:  [join $preload {, }]"
    return $preload
}

proc ::critcl::app::PreloadLocation {shlib} {
    set searchpath [PreloadSearchPath $shlib]

    foreach path $searchpath {
	if {![file exists $path]} continue
	return $path
    }

    set    msg "can't find preload library $shlib"
    append msg " for target platform \"$v::actualplatform\";"
    append msg " searched for "
    append msg [linsert [join $searchpath {, }] end-1 and]
    critcl::error $msg
    return
}

proc ::critcl::app::PreloadSearchPath {shlib} {

    # Look for lib FOO as follows:
    # (1) FOO.so
    # (2) FOO/FOO.so
    # (3) FOO/<platform>/FOO.so
    #
    # Look for lib BAR/FOO as follows:
    # (1) FOO.so
    #
    # Then, if BAR/FOO doesn't exist as directory:
    # (2) BAR/FOO.so
    # (3) BAR/<platform>/FOO.so
    #
    # Conversely, if BAR/FOO does exist as directory:
    # (2) BAR/FOO/FOO.so
    # (3) BAR/FOO/<platform>/FOO.so

    #   - lib.so
    #   - dir/lib.so
    #   - dir/plat/lib.so

    set tail [file tail $shlib]

    if {[file isdirectory $shlib]} {
	set dir $shlib
    } else {
	set dir [file dirname $shlib]
	if {$dir eq "."} {
	    set dir $tail
	}
    }

    set ext [critcl::sharedlibext]
    return [list \
		$tail$ext \
		[file join $dir $tail$ext] \
		[file join $dir $v::actualplatform $tail$ext]]
}

proc ::critcl::app::PackageGuard {v} {
    return [string map [list @ $v] \
	{if {![package vsatisfies [package provide Tcl] @]} {return}}]
}

proc ::critcl::app::IndexCommand {version libname tsources shlibdir} {
    # We precompute as much as possible instead of wholesale defering
    # to the runtime and dynamic code. See ticket (38bf01b26e). That
    # makes it easier to debug the index command, as it is immediately
    # visible in the pkgIndex.tcl file. And supports placement into
    # the meta data.

    set loadcmd [LoadCommand $version $libname $tsources $shlibdir]
    return "package ifneeded [list $v::pkgs $version] $loadcmd"
}

proc ::critcl::app::LoadCommand {version libname tsources shlibdir} {
    # New style. Precompute as much as possible.

    set map [Mapping]
    if {$map ne {}} { set map " [list $map]" }
    set platform "\[::critcl::runtime::MapPlatform$map\]"

    set     loadcmd {}
    lappend loadcmd {source [file join $dir critcl-rt.tcl]}
    lappend loadcmd "set path \[file join \$dir $platform\]"
    lappend loadcmd "set ext \[info sharedlibextension\]"
    lappend loadcmd "set lib \[file join \$path \"$libname\$ext\"\]"

    foreach p [Preload $shlibdir] {
	lappend loadcmd "::critcl::runtime::preFetch \$path \$ext [list $p]"
    }

    lappend loadcmd "load \$lib [list $v::inits]"

    foreach t $tsources {
	lappend loadcmd "::critcl::runtime::Fetch \$dir [list $t]"
    }

    lappend loadcmd [list package provide $v::pkgs $version]

    # Wrap the load command for use by the index command.
    # First make it a proper script, indented, i.e. proc body.

    set loadcmd "\n    [join $loadcmd "\n    "]"

    if {[package vsatisfies $v::mintcl 8.5]} {
	# 8.5+: Put the load command into an ::apply, i.e. make it
	# an anonymous procedure.

	set loadcmd "\[list ::apply \{dir \{$loadcmd\n\}\} \$dir\]"
    } else {
	# 8.4: Use a named, transient procedure. Name is chosen
	# for low probability of collision with anything else.
	# NOTE: We have to catch the auto-delete command because
	# the procedure may have been redefined and destroyed by
	# recursive calls to 'package require' of more critcl-based
	# packages.
	set n __critcl_load__
	append loadcmd "\n    catch \{rename $n {}\}";# auto delete
	set loadcmd "\"\[list proc $n \{dir\} \{[string map [list \n { ; }] $loadcmd]\}\] ; \[list $n \$dir\]\""
    }

    lappend v::meta [list entrytclcommand [list "eval $loadcmd"]]

    return $loadcmd
}

proc ::critcl::app::IndexCommandXXXXX {version libname tsources shlibdir} {
    # Old style critcl. Ifneeded and loading is entirely and
    # dynamically handled in the runtime support code.

    set map       [Mapping]
    set preload   [Preload $shlibdir]
    set arguments [list $v::pkgs $version $libname $v::inits $tsources $map]
    return "source \[file join \$dir critcl-rt.tcl\]\n::critcl::runtime::loadlib \$dir $arguments $preload"
}

proc ::critcl::app::CreateLicenseTerms {pkgdir} {
    # Create a license.terms file.

    if {$v::license eq ""} {
	set v::license <<Undefined>>
    } else {
	set v::license [string trimleft $v::license]
    }
    set    license [open [file join $pkgdir license.terms] w]
    puts  $license $v::license
    close $license
    return
}

proc ::critcl::app::CreateTeapotMetadata {pkgdir} {
    if {![llength $v::meta]} {
	critcl::error "Meta data missing"
	return
    }

    # Merge the data from all input files, creating a list of words
    # per key. Note: Data from later input files does not replace
    # previous words, they get added instead.

    set umd {}
    foreach md $v::meta {
	foreach {k vlist} $md {
	    foreach v $vlist {
		dict lappend umd $k $v
	    }
	}
    }

    # Check the identifying keys, i.e. package name, version, and
    # platform for existence.

    foreach k {name version platform} {
	if {![dict exists $umd $k]} {
	    critcl::error "Package $k missing in meta data"
	}
    }


    # Collapse the data of various keys which must have only one,
    # unique, element.

    foreach k {name version platform build::date generated::date} {
	if {![dict exists $umd $k]} continue
	dict set umd $k [lindex [dict get $umd $k] 0]
    }

    # Add the entity information, and format the data for writing,
    # using the "external" format for TEApot meta data. This writer
    # limits lines to 72 characters, roughly. Beyond that nothing is
    # done to make the output look pretty.

    set md {}
    lappend md "Package [dict get $umd name] [dict get $umd version]"
    dict unset umd name
    dict unset umd version

    dict for {k vlist} $umd {
	set init 1
	foreach v $vlist {
	    if {$init} {
		# The first element of the value list is always added,
		# regardless of length, to avoid infinite looping
		# without progress.
		set line {}
		lappend line Meta $k $v
		set init 0
		continue
	    }
	    if {[string length [linsert $line end $v]] > 72} {
		# If the next element brings us beyond the limit we
		# flush the current state and re-initialize.
		lappend md $line
		set line {}
		lappend line Meta $k $v
		set init 0
		continue
	    }
	    # Add the current element, extending the line.
	    lappend line $v
	}

	# Flush the last line.
	lappend md $line
    }

    # Last step, write the formatted meta data to the associated file.

    set    teapot [open [file join $pkgdir teapot.txt] w]
    puts  $teapot [join $md \n]
    close $teapot
    return
}

proc ::critcl::app::PlaceTclCompanionFiles {pkgdir} {
    # Arrange for the companion Tcl source files (as specified by
    # critcl::tsources) to be copied into the Tcl subdirectory (in
    # accordance with TIP 55)

    if {![llength $v::tsources]} { return {} }

    set tcldir [file join $pkgdir tcl]
    file mkdir $tcldir
    set files {}
    set id 0
    foreach t $v::tsources {
	set dst [file tail $t]
	set dst [file rootname $dst]_[incr id][file extension $dst]

	file copy -force $t $tcldir/$dst
	lappend files $dst

	# Metadata management
	lappend v::meta [list included tcl/$dst]
    }
    return $files
}

proc ::critcl::app::CreateRuntimeSupport {pkgdir} {
    # Create the critcl-rt.tcl file in the generated package. This
    # provides the code which dynamically assembles at runtime the
    # package loading code, i.e. the 'package ifneeded' command
    # expected by Tcl package management.

    variable mydir
    set runtime [file join $mydir runtime.tcl]

    if {![file exists $runtime]} {
	critcl::error "can't find Critcl's package runtime support file \"runtime.tcl\""
    }

    set fd [open $runtime]
    set txt [read $fd]
    close $fd

    append txt [DummyCritclPackage]
    append txt [PlatformGeneric]

    set    fd [open [file join $pkgdir critcl-rt.tcl] w]
    puts  $fd $txt
    close $fd

    lappend v::meta [list included critcl-rt.tcl]
    return
}

proc ::critcl::app::DummyCritclPackage {} {
    # This command provides conditional no-ops for any of the critcl
    # procedures exported by the regular package, so that a .tcl file
    # with embedded C can also be its own companion file declaring Tcl
    # procedures etc. These dummy procedures are defined if and only
    # if their regular counterpart is not present.

    # Note: We are generating code checking each and every relevant
    # command individually to avoid trouble with different versions of
    # critcl which may export a differing set of procedures. This way
    # we will not miss anything just because we assumed that the
    # presence of critcl::FOO also implies having critcl::BAR, or not.

    # Append dummy Critcl procs
    # XXX This should be made conditional on the .tcl actually using itself as companion.
    append txt "\n\# Dummy implementation of the critcl package, if not present\n"

    foreach name [lsort [namespace eval ::critcl {namespace export}]] {
	switch $name {
	    compiled  { set result 1 }
	    compiling { set result 0 }
	    done      { set result 1 }
	    check     { set result 0 }
	    failed    { set result 0 }
	    load      { set result 1 }
	    Ignore    { append txt [DummyCritclCommand $name {
		namespace eval ::critcl::v {}
		set ::critcl::v::ignore([file normalize [lindex $args 0]]) .
	    }]
		continue
	    }
	    default   {
		append txt [DummyCritclCommand $name {}]
		continue
	    }
	}
	append txt [DummyCritclCommand $name "return $result"]
    }

    return $txt
}

proc ::critcl::app::DummyCritclCommand {name result} {
    append txt "if \{!\[llength \[info commands ::critcl::$name\]\]\} \{\n"
    append txt "    namespace eval ::critcl \{\}\n"
    append txt "    proc ::critcl::$name \{args\} \{$result\}\n"
    append txt "\}\n"
    return $txt
}

proc ::critcl::app::PlatformGeneric {} {
    # Return a clone of the platform::generic command, from the
    # currently loaded platform package. The generated package cannot
    # assume that the deployment environment contains this package. To
    # avoid trouble if the DP has the package the definition is made
    # conditional, i.e. the clone is skipped if the command is already
    # present.

    set body [info body ::platform::generic]

    append txt "\n# Define a clone of platform::generic, if needed\n"
    append txt "if \{!\[llength \[info commands ::platform::generic\]\]\} \{\n"
    append txt "    namespace eval ::platform \{\}\n"
    append txt "    proc ::platform::generic \{\} \{"
    append txt [join [split $body \n] "\n    "]
    append txt "\}\n"
    append txt "\}\n\n"

    return $txt
}

proc ::critcl::app::AssembleTEA {} {
    LogLn {Assembling TEA hierarchy...}

    set libdir  [CreateLibDirectory]
    set libname [file rootname [file tail $v::outname]]
    set pkgdir  [file join $libdir $libname]

    LogLn "\tPackage: $pkgdir"

    file mkdir $pkgdir

    # Get a proper version number
    set ver 0.0
    if {[llength $v::ver]} {
	set ver [lindex $v::ver 0]
    }
    # Get a proper organization this is licensed by
    set org Unknown
    if {[llength $v::org]} {
	set org [lindex $v::org 0]
    }

    PlaceTEASupport    $pkgdir $libname $ver $org
    PlaceCritclSupport $pkgdir
    PlaceInputFiles    $pkgdir

    # Last, meta data for the TEA setup.
    CreateTeapotMetadata $pkgdir
    return
}

proc ::critcl::app::CreateLibDirectory {} {
    set libdir [file normalize $v::libdir]
    if {[file isfile $libdir]} {
	critcl::error "can't package $v::shlname - $libdir is not a directory"
    } elseif {![file isdirectory $libdir]} {
	file mkdir $libdir
    }

    return $libdir
}

proc ::critcl::app::CreateIncludeDirectory {} {
    set incdir [file normalize $v::incdir]
    if {[file isfile $incdir]} {
	::critcl::error "can't package $v::shlname headers - $incdir is not a directory"
    } elseif {![file isdirectory $incdir]} {
	file mkdir $incdir
    }

    return $incdir
}

proc ::critcl::app::PlaceTEASupport {pkgdir pkgname pversion porg} {
    # Create the configure.in file in the generated TEA
    # hierarchy.

    LogLn "\tPlacing TEA support..."

    foreach {pmajor pminor} [split $pversion .] break
    if {$pminor eq {}} { set pminor 0 }
    if {$pmajor eq {}} { set pmajor 0 }

    variable mydir
    set tea [file join $mydir tea]

    if {![file exists $tea]} {
	critcl::error "can't find Critcl's TEA support files"
    }

    # Copy the raw support files over.
    foreach f [glob -directory $tea *] {
	file copy $f $pkgdir

	if {[file tail $f] eq "tclconfig"} {
	    foreach f [glob -directory $tea/tclconfig *] {
		lappend v::meta [list included tclconfig/[file tail $f]]
	    }
	} else {
	    lappend v::meta [list included [file tail $f]]
	}
    }

    # Basic map for the placeholders in the templates

    set now  [clock seconds]
    set year [clock format $now -format {%Y}]
    set now  [clock format $now]
    set map  [list \
		 @@CRITCL@@     "\"$::argv0 $::argv\"" \
		 @@PNAME@@   $pkgname \
		 @@PMAJORV@@ $pmajor  \
		 @@PMINORV@@ $pminor  \
		 @@PFILES@@  "\\\n\t[join $v::teasrc " \\\n\t"]" \
		 @@PORG@@    $porg \
		 @@YEAR@@    $year \
		 @@NOW@@     $now]
    set cmap $map
    set mmap $map

    # Extend map with stubs API data

    if {![llength $v::imported]} {
	lappend cmap @@API@@ {}
	lappend mmap @@API@@ {} @@APIUSE@@ {}
    } else {
	set macros {}
	# Creating the --with-foo-include options for imported APIs.

	lappend macros "#-----------------------------------------------------------------------"
	lappend macros "## TEA stubs header setup"
	lappend macros ""
	foreach api $v::imported {
	    set capi [string map {:: _} $api]

	    lappend macros  "CRITCL_TEA_PUBLIC_PACKAGE_HEADERS(\[$capi\])"
	    lappend mvardef "CRITCL_API_${capi}_INCLUDE = @CRITCL_API_${capi}_INCLUDE@"
	    lappend mvaruse "-I \$(CRITCL_API_${capi}_INCLUDE)"
	}
	lappend cmap @@API@@    \n[join $macros \n]\n
	lappend mmap @@API@@    \n[join $mvardef \n]\n
	lappend mmap @@APIUSE@@ " \\\n\t\t[join $mvaruse " \\\n\t\t"]"
    }

    # Extend map with custom user configuration data.

    if {![llength $v::config]} {
	lappend cmap @@UCONFIG@@ {}
	lappend mmap @@UCONFIG@@ {} @@UCONFIGUSE@@ {}
    } else {

	# Note: While we could assume that the user-specified
	# configuration options of a single file are consistent with
	# each other here we have a union of options from multiple
	# files. No such assumption can be made. Thus, we unique the
	# list, and then check that each option name left has a unique
	# definition as well.

	set ok 1
	array set udef {}
	set uclist [lsort -unique $v::config]
	foreach uc $uclist {
	    set oname [lindex $uc 0]
	    if {[info exists udef($oname)]} {
		LogLn "\t    Inconsistent definition for $oname"
		LogLn "\t    (1) $uc"
		LogLn "\t    (2) $udef($oname)"
		set ok 0
		continue
	    }
	    set udef($oname) $uc
	}
	if {!$ok} {
	    ::critcl::error "Conflicting user-specified configuration settings."
	}

	# Creating the --(with,enable,disable)-foo options for
	# user-specified configuration options.

	lappend macros "#-----------------------------------------------------------------------"
	lappend macros "## TEA user option setup"
	lappend macros ""
	foreach uc $uclist {
	    lassign $uc oname odesc otype odefault

	    if {$otype eq "bool"} {
		set odefault [expr {$odefault ? "yes" : "no"}]
		if {$odesc eq {}} {
		    set odesc "--enable-$oname"
		}
		append odesc " (default: $odefault)"

		lappend macros  "CRITCL_TEA_BOOL_CONFIG(\[$oname\],\n\t\[$odefault\],\n\t\[$odesc\])"
	    } else {
		if {$odesc eq {}} {
		    set odesc "--with-$oname"
		}
		append odesc " (default: $odefault, of [join $otype {, }])"

		lappend macros  "CRITCL_TEA_WITH_CONFIG(\[$oname\],\n\t\[[join $otype { }]\],\n\t\[$odefault\],\n\t\[$odesc\])"
	    }

	    lappend mvardef "CRITCL_UCONFIG_${oname} = @CRITCL_UCONFIG_${oname}@"
	    lappend mvaruse "\$(CRITCL_UCONFIG_${oname})"
	}
	lappend cmap @@UCONFIG@@    \n[join $macros \n]\n
	lappend mmap @@UCONFIG@@    \n[join $mvardef \n]\n
	lappend mmap @@UCONFIGUSE@@ " \\\n\t\t[join $mvaruse " \\\n\t\t"]"
    }

    # Postprocess a few files (configure.in, Makefile.in).

    Map  [file join $pkgdir configure.in] $cmap
    Map  [file join $pkgdir Makefile.in]  $mmap
    Map  [file join $pkgdir Config.in]    $map

    # At last locate a suitable autoconf (2.59+), and generate
    # configure from the configure.in.

    set here [pwd]
    cd $pkgdir
    if {$::tcl_platform(platform) eq "windows"} {
	# msys/mingw, cygwin, or other unix emulation on windows.
	exec sh [LocateAutoconf 1]
    } else {
	exec [LocateAutoconf 0]
    }
    file delete -force autom4te.cache

    lappend v::meta [list included configure]

    cd $here

    return
}

proc ::critcl::app::Map {path map} {
    set fd  [open $path r]
    set txt [read $fd]
    close $fd

    set txt [string map $map $txt]

    set    fd  [open $path w]
    puts -nonewline $fd $txt
    close $fd

    return
}

proc ::critcl::app::PlaceCritclSupport {pkgdir} {
    LogLn "\tPlacing Critcl support..."

    set c [file join $pkgdir critcl]
    set l [file join $c lib]
    file mkdir $l

    # Locate the critcl packages, and their forward compatibility
    # support packages, and copy them into the TEA hierarchy for use
    # by the generated Makefile.
    foreach {pkg dir} {
	critcl            critcl
	critcl::app       app-critcl
	critcl::util      critcl-util
        critcl::class     critcl-class
        critcl::iassoc    critcl-iassoc
        critcl::bitmap    critcl-bitmap
        critcl::cutil     critcl-cutil
        critcl::emap      critcl-emap
        critcl::enum      critcl-enum
        critcl::literals  critcl-literals
        critcl::platform  critcl-platform
	stubs::container  stubs_container
        stubs::gen        stubs_genframe
        stubs::gen::decl  stubs_gen_decl
        stubs::gen::lib   stubs_gen_lib
        stubs::gen::macro stubs_gen_macro
        stubs::gen::slot  stubs_gen_slot
        stubs::gen::header stubs_gen_header
        stubs::gen::init  stubs_gen_init
        stubs::reader     stubs_reader
        stubs::writer     stubs_writer
    } {
	set cmd      [package ifneeded $pkg [package require $pkg]]
	set location [file dirname [lindex $cmd end]]

	# Squash any soft-links, which Tcl would copy as links.
	set location [file dirname [file normalize $location/__]]
	file copy $location $l/$dir
    }

    # Generate a suitable main.tcl. Note that this main file sources
    # the critcl packages directly, to ensure that the build uses the
    # code put into the generated TEA hierarchy, and is not influenced
    # by whatever is installed outside.

    set     pfiles {}
    lappend pfiles stubs_container/container stubs_reader/reader
    lappend pfiles stubs_genframe/genframe stubs_gen_decl/gen_decl
    lappend pfiles stubs_gen_macro/gen_macro stubs_gen_slot/gen_slot
    lappend pfiles stubs_gen_header/gen_header stubs_gen_init/gen_init
    lappend pfiles stubs_gen_lib/gen_lib stubs_writer/writer
    lappend pfiles critcl/critcl app-critcl/critcl critcl-util/util
    lappend pfiles critcl-class/class critcl-iassoc/iassoc
    lappend pfiles critcl-bitmap/bitmap critcl-cutil/cutil
    lappend pfiles critcl-literals/literals critcl-platform/platform
    lappend pfiles critcl-emap/emap critcl-enum/enum

    set fd [open [file join $pkgdir critcl main.tcl] w]
    puts $fd [join \
		  [list \
		       "# Required packages: cmdline, md5" \
		       "# Optional: tcllibc, Trf, md5c, cryptkit (md5 acceleration)" \
		       "# Enforce usage of the local critcl packages." \
		       "foreach p \{\n\t[join $pfiles \n\t]\n\} \{" \
		       {    source [file dirname [info script]]/lib/$p.tcl} \
		       "\}" \
		       {critcl::app::main $argv}] \n]
    close $fd

    # Add to set of included files.
    lappend v::meta [list included critcl/main.tcl]
    foreach p $pfiles {
	lappend v::meta [list included critcl/lib/$p.tcl]
    }
    return
}

proc ::critcl::app::PlaceInputFiles {pkgdir} {
    LogLn "\tPlacing input files..."

    # Main critcl source file(s), plus companions

    foreach f $v::src {
	#LogLn "\tB   $f"

	set dst [file join src [file tail $f]]
	lappend v::meta [list included $dst]

	set dst [file join $pkgdir $dst]
	file mkdir [file dirname $dst]
	file copy $f $dst
    }

    foreach {f cf} $v::cfiles {
	set base [file dirname $f]
	foreach f [lsort -unique $cf] {
	    set fs [file join $base $f]

	    #LogLn "\tC   $fs"

	    set dst [file join src $f]
	    lappend v::meta [list included $dst]

	    set dst [file join $pkgdir $dst]

	    file mkdir [file dirname $dst]
	    file copy $fs $dst
	}
    }
    return
}

proc ::critcl::app::LocateAutoconf {iswin} {
    set ac [auto_execok autoconf]

    if {$ac eq {}} {
	return -code error "autoconf 2.59 or higher required, not found"
    }

    if {$iswin} {
	# msys/mingw, cygwin, or other unix emulation on windows.
	set cmd [linsert $ac 0 exec sh]
    } else {
	set cmd [linsert $ac 0 exec]
    }

    set v [lindex [split [eval [linsert $cmd end --version]] \n] 0 end]

    if {![package vsatisfies $v 2.59]} {
	return -code error "$ac $v is not 2.59 or higher, as required"
    }

    return $ac
}


# # ## ### ##### ######## ############# #####################
## inline the needed parts of tcllib's cmdline

proc ::critcl::app::Getopt {argvVar optstring optVar valVar} {
    upvar 1 $argvVar argsList
    upvar 1 $optVar option
    upvar 1 $valVar value

    set result [GetKnownOpt argsList $optstring option value]

    if {$result < 0} {
        # Collapse unknown-option error into any-other-error result.
        set result -1
    }
    return $result
}

proc ::critcl::app::GetKnownOpt {argvVar optstring optVar valVar} {
    upvar 1 $argvVar argsList
    upvar 1 $optVar  option
    upvar 1 $valVar  value

    # default settings for a normal return
    set value ""
    set option ""
    set result 0

    # check if we're past the end of the args list
    if {[llength $argsList] != 0} {

	# if we got -- or an option that doesn't begin with -, return (skipping
	# the --).  otherwise process the option arg.
	switch -glob -- [set arg [lindex $argsList 0]] {
	    "--" {
		set argsList [lrange $argsList 1 end]
	    }
	    "--*" -
	    "-*" {
		set option [string range $arg 1 end]
		if {[string equal [string range $option 0 0] "-"]} {
		    set option [string range $arg 2 end]
		}

		# support for format: [-]-option=value
		set idx [string first "=" $option 1]
		if {$idx != -1} {
		    set _val   [string range $option [expr {$idx+1}] end]
		    set option [string range $option 0   [expr {$idx-1}]]
		}

		if {[lsearch -exact $optstring $option] != -1} {
		    # Booleans are set to 1 when present
		    set value 1
		    set result 1
		    set argsList [lrange $argsList 1 end]
		} elseif {[lsearch -exact $optstring "$option.arg"] != -1} {
		    set result 1
		    set argsList [lrange $argsList 1 end]

		    if {[info exists _val]} {
			set value $_val
		    } elseif {[llength $argsList]} {
			set value [lindex $argsList 0]
			set argsList [lrange $argsList 1 end]
		    } else {
			set value "Option \"$option\" requires an argument"
			set result -2
		    }
		} else {
		    # Unknown option.
		    set value "Illegal option \"-$option\""
		    set result -1
		}
	    }
	    default {
		# Skip ahead
	    }
	}
    }

    return $result
}

# # ## ### ##### ######## ############# #####################

namespace eval ::critcl::app {
    # Path of the application package directory.
    variable myself [file normalize [info script]]
    variable mydir [file dirname $myself]

    variable options {
	I.arg L.arg cache.arg clean config.arg debug.arg force help
	keep libdir.arg pkg show showall target.arg targets
	test tea showtarget includedir.arg enable.arg disable.arg
	v -version
    }

    # Application state
    namespace eval v {
	# - -- --- ----- -------- ------------- ---------------------
	# Data collected from the command line.

	variable verbose    0 ;# Level of chattering written during a run.
	variable src       {} ;# List of files to process.

	variable actualplatform {} ;# Target platform, with x-compile information resolved.

	variable shlname   "" ;# Name of the shlib to generate (-pkg, -tea).
	variable outname   "" ;# Name of the shlib dir to use (-pkg, -tea).
	variable libdir   lib ;# Place for the package (-pkg, -tea).
	variable incdir   include ; # Directory to put the -pkg include files into (stubs export),
                                    # and search in (stubs import)
	variable keep       0 ;# Boolean flag. Default: Do not keep generated .c files.
	variable debug     {} ;# List of debug modes to activate.
	variable cache     {} ;# User specified path to the directory for the result cache.
	variable uc        {} ;# List. User specified configuration data.

	# Build mode. Default is to fill the result
	# cache. Alternatives are building a package (-pkg), or
	# assembling/repackaging for TEWA (-tea).

	variable mode cache ;# pkg, tea

	# - -- --- ----- -------- ------------- ---------------------
	# Data accumulated while processing the input files.

	variable failed      0  ;# Number of build failures encountered.
	variable clibraries {}  ;# External libraries used. To link the final shlib against.
	variable ldflags    {}  ;# Linker flags.
	variable objects    {}  ;# The object files to link.
	variable edecls     {}  ;# Initialization function decls for the pieces (C code block).
	variable initnames  {}  ;# Initialization function calls for the pieces (C code block).
	variable tsources   {}  ;# Tcl companion sources.
	variable mintcl     8.4 ;# Minimum version of Tcl required to run the package.
	variable preload    {}  ;# List of libraries declared for preload.
	variable license    {}  ;# Accumulated licenses, if any.
	variable pkgs       {}  ;# List of package names for the pieces.
	variable inits      {}  ;# Init function names for the pieces, list.
	variable meta       {}  ;# All meta data declared by the input files.

	# critcl::scan results
	variable org        {}  ;# Organization package is licensed by
	variable ver        {}  ;# Version of the package.
	variable cfiles     {}  ;# Companion files (.tcl, .c, .h, etc).
	variable teasrc     {}  ;# Input file(s) transformed for use in the Makefile.in.
	variable imported   {}  ;# List of stubs APIs imported from elsewhere.
	variable config     {}  ;# List of user-specified configuration settings.
	# variable meta         ;# See above.
    }
}

# # ## ### ##### ######## ############# #####################
return
