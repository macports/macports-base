# -*- tcl -*-
# libbench.tcl ?(<option> <value>)...? <benchFile>...
#
# This file has to have code that works in any version of Tcl that
# the user would want to benchmark.
#
# RCS: @(#) $Id: libbench.tcl,v 1.4 2008/07/02 23:34:06 andreas_kupries Exp $
#
# Copyright (c) 2000-2001 Jeffrey Hobbs.
# Copyright (c) 2007      Andreas Kupries
#

# This code provides the supporting commands for the execution of a
# benchmark files. It is actually an application and is exec'd by the
# management code.

# Options:
# -help				Print usage message.
# -rmatch <regexp-pattern>	Run only tests whose description matches the pattern.
# -match  <glob-pattern>	Run only tests whose description matches the pattern.
# -interp <name>		Name of the interp running the benchmarks.
# -thread <num>                 Invoke threaded benchmarks, number of threads to use.
# -errors <boolean>             Throw errors, or not.

# Note: If both -match and -rmatch are specified then _both_
# apply. I.e. a benchmark will be run if and only if it matches both
# patterns.

# Application activity and results are communicated to the highlevel
# management via text written to stdout. Each line written is a list
# and has one of the following forms:
#
# __THREADED <version>     - Indicates threaded mode, and version
#                            of package Thread in use.
#
# Sourcing {<desc>: <res>} - Benchmark <desc> has started.
#                            <res> is the result from executing
#                            it once (compilation of body.)
#
# Sourcing <file>          - Benchmark file <file> starts execution.
#
# <desc> <res>             - Result of a benchmark.
#
# The above implies that no benchmark may use the strings 'Sourcing'
# or '__THREADED' as their description.

# We will put our data into these named globals.

global BENCH bench

# 'BENCH' contents:
#
# - ERRORS  : Boolean flag. If set benchmark output mismatches are
#             reported by throwing an error. Otherwise they are simply
#             listed as BAD_RES. Default true. Can be set/reset via
#             option -errors.
#
# - MATCH   : Match pattern, see -match, default empty, aka everything
#             matches.
#
# - RMATCH  : Match pattern, see -rmatch, default empty, aka
#             everything matches.
#
# - OUTFILE : Name of output file, default is special value "stdout".
# - OUTFID  : Channel for output.
#
# The outfile cannot be set by the caller, thus output is always
# written to stdout.
#
# - FILES   : List of benchmark files to run.
#
# - ITERS   : Number of iterations to run a benchmark body, default
#             1000. Can be overridden by the individual benchmarks.
#
# - THREADS : Number of threads to use. 0 signals no threading.
#             Limited to number of files if there are less files than
#             requested threads.
#
# - EXIT    : Boolean flag. True when appplication is run by wish, for
#             special exit processing. ... Actually always true.
#
# - INTERP  : Name of the interpreter running the benchmarks. Is the
#             executable running this code. Can be overridden via the
#             command line option -interp.
#
# - uniqid  : Counter for 'bench_tmpfile' to generate unique names of
#             tmp files.
#
# - us      : Thread id of main thread.
#
# - inuse   : Number of threads active, present and relevant only in
#             threaded mode.
#
# - file    : Currently executed benchmark file. Relevant only in
#             non-threaded mode.

#
# 'bench' contents.

# Benchmark results, mapping from the benchmark descriptions to their
# results. Usually time in microseconds, but the following special
# values can occur:
#
# - BAD_RES    - Result from benchmark body does not match expectations.
# - ERR        - Benchmark body aborted with an error.
# - Any string - Forced by error code 666 to pass to management.

#
# We claim all procedures starting with bench*
#

# bench_tmpfile --
#
#   Return a temp file name that can be modified at will
#
# Arguments:
#   None
#
# Results:
#   Returns file name
#
proc bench_tmpfile {} {
    global tcl_platform env BENCH
    if {![info exists BENCH(uniqid)]} { set BENCH(uniqid) 0 }
    set base "tclbench[incr BENCH(uniqid)].dat"
    if {[info exists tcl_platform(platform)]} {
	if {$tcl_platform(platform) == "unix"} {
	    return "/tmp/$base"
	} elseif {$tcl_platform(platform) == "windows"} {
	    return [file join $env(TEMP) $base]
	} else {
	    return $base
	}
    } else {
	# The Good Ol' Days (?) when only Unix support existed
	return "/tmp/$base"
    }
}

# bench_rm --
#
#   Remove a file silently (no complaining)
#
# Arguments:
#   args	Files to delete
#
# Results:
#   Returns nothing
#
proc bench_rm {args} {
    foreach file $args {
	if {[info tclversion] > 7.4} {
	    catch {file delete $file}
	} else {
	    catch {exec /bin/rm $file}
	}
    }
}

proc bench_puts {args} {
    eval [linsert $args 0 FEEDBACK]
    return
}

# bench --
#
#   Main bench procedure.
#   The bench test is expected to exit cleanly.  If an error occurs,
#   it will be thrown all the way up.  A bench proc may return the
#   special code 666, which says take the string as the bench value.
#   This is usually used for N/A feature situations.
#
# Arguments:
#
#   -pre	script to run before main timed body
#   -body	script to run as main timed body
#   -post	script to run after main timed body
#   -ipre	script to run before timed body, per iteration of the body.
#   -ipost	script to run after timed body, per iteration of the body.
#   -desc	message text
#   -iterations	<#>
#
# Note:
#
#   Using -ipre and/or -ipost will cause us to compute the average
#   time ourselves, i.e. 'time body 1' n times. Required to ensure
#   that prefix/post operation are executed, yet not timed themselves.
#
# Results:
#
#   Returns nothing
#
# Side effects:
#
#   Sets up data in bench global array
#
proc bench {args} {
    global BENCH bench errorInfo errorCode

    # -pre script
    # -body script
    # -desc msg
    # -post script
    # -ipre script
    # -ipost script
    # -iterations <#>
    array set opts {
	-pre	{}
	-body	{}
	-desc	{}
	-post	{}
	-ipre	{}
	-ipost	{}
    }
    set opts(-iter) $BENCH(ITERS)
    while {[llength $args]} {
	set key [lindex $args 0]
	switch -glob -- $key {
	    -res*	{ set opts(-res)  [lindex $args 1] }
	    -pr*	{ set opts(-pre)  [lindex $args 1] }
	    -po*	{ set opts(-post) [lindex $args 1] }
	    -ipr*	{ set opts(-ipre)  [lindex $args 1] }
	    -ipo*	{ set opts(-ipost) [lindex $args 1] }
	    -bo*	{ set opts(-body) [lindex $args 1] }
	    -de*	{ set opts(-desc) [lindex $args 1] }
	    -it*	{
		# Only change the iterations when it is smaller than
		# the requested default
		set val [lindex $args 1]
		if {$opts(-iter) > $val} { set opts(-iter) $val }
	    }
	    default {
		error "unknown option $key"
	    }
	}
	set args [lreplace $args 0 1]
    }

    FEEDBACK "Running <$opts(-desc)>"

    if {($BENCH(MATCH) != "") && ![string match $BENCH(MATCH) $opts(-desc)]} {
	return
    }
    if {($BENCH(RMATCH) != "") && ![regexp $BENCH(RMATCH) $opts(-desc)]} {
	return
    }
    if {$opts(-pre) != ""} {
	uplevel \#0 $opts(-pre)
    }
    if {$opts(-body) != ""} {
	# always run it once to remove compile phase confusion
	if {$opts(-ipre) != ""} {
	    uplevel \#0 $opts(-ipre)
	}
	set code [catch {uplevel \#0 $opts(-body)} res]
	if {$opts(-ipost) != ""} {
	    uplevel \#0 $opts(-ipost)
	}
	if {!$code && [info exists opts(-res)] \
		&& [string compare $opts(-res) $res]} {
	    if {$BENCH(ERRORS)} {
		return -code error "Result was:\n$res\nResult\
			should have been:\n$opts(-res)"
	    } else {
		set res "BAD_RES"
	    }
	    #set bench($opts(-desc)) $res
	    RESULT $opts(-desc) $res
	} else {
	    if {($opts(-ipre) != "") || ($opts(-ipost) != "")} {
		# We do the averaging on our own, to allow untimed
		# pre/post execution per iteration. We catch and
		# handle problems in the pre/post code as if
		# everything was executed as one block (like it would
		# be in the other path). We are using floating point
		# to avoid integer overflow, easily happening when
		# accumulating a high number (iterations) of large
		# integers (microseconds).

		set total 0.0
		for {set i 0} {$i < $opts(-iter)} {incr i} {
		    set code 0
		    if {$opts(-ipre) != ""} {
			set code [catch {uplevel \#0 $opts(-ipre)} res]
			if {$code} break
		    }
		    set code [catch {uplevel \#0 [list time $opts(-body) 1]} res]
		    if {$code} break
		    set total [expr {$total + [lindex $res 0]}]
		    if {$opts(-ipost) != ""} {
			set code [catch {uplevel \#0 $opts(-ipost)} res]
			if {$code} break
		    }
		}
		if {!$code} {
		    set res [list [expr {int ($total/$opts(-iter))}] microseconds per iteration]
		}
	    } else {
		set code [catch {uplevel \#0 \
			[list time $opts(-body) $opts(-iter)]} res]
	    }
	    if {!$BENCH(THREADS)} {
		if {$code == 0} {
		    # Get just the microseconds value from the time result
		    set res [lindex $res 0]
		} elseif {$code != 666} {
		    # A 666 result code means pass it through to the bench
		    # suite. Otherwise throw errors all the way out, unless
		    # we specified not to throw errors (option -errors 0 to
		    # libbench).
		    if {$BENCH(ERRORS)} {
			return -code $code -errorinfo $errorInfo \
				-errorcode $errorCode
		    } else {
			set res "ERR"
		    }
		}
		#set bench($opts(-desc)) $res
		RESULT $opts(-desc) $res
	    } else {
		# Threaded runs report back asynchronously
		thread::send $BENCH(us) \
			[list thread_report $opts(-desc) $code $res]
	    }
	}
    }
    if {($opts(-post) != "") && [catch {uplevel \#0 $opts(-post)} err] \
	    && $BENCH(ERRORS)} {
	return -code error "post code threw error:\n$err"
    }
    return
}

proc RESULT {desc time} {
    global BENCH
    puts $BENCH(OUTFID) [list RESULT $desc $time]
    return
}

proc FEEDBACK {text} {
    global BENCH
    puts $BENCH(OUTFID) [list LOG $text]
    return
}


proc usage {} {
    set me [file tail [info script]]
    puts stderr "Usage: $me ?options?\
	    \n\t-help			# print out this message\
	    \n\t-rmatch <regexp>	# only run tests matching this pattern\
	    \n\t-match <glob>		# only run tests matching this pattern\
	    \n\t-interp	<name>		# name of interp (tries to get it right)\
	    \n\t-thread	<num>		# number of threads to use\
	    \n\tfileList		# files to benchmark"
    exit 1
}

#
# Process args
#
if {[catch {set BENCH(INTERP) [info nameofexec]}]} {
    set BENCH(INTERP) $argv0
}
foreach {var val} {
	ERRORS		1
	MATCH		{}
	RMATCH		{}
	OUTFILE		stdout
	FILES		{}
	ITERS		1000
	THREADS		0
        PKGDIR          {}
	EXIT		"[info exists tk_version]"
} {
    if {![info exists BENCH($var)]} {
	set BENCH($var) [subst $val]
    }
}
set BENCH(EXIT) 1

if {[llength $argv]} {
    while {[llength $argv]} {
	set key [lindex $argv 0]
	switch -glob -- $key {
	    -help*	{ usage }
	    -err*	{ set BENCH(ERRORS)  [lindex $argv 1] }
	    -int*	{ set BENCH(INTERP)  [lindex $argv 1] }
	    -rmat*	{ set BENCH(RMATCH)  [lindex $argv 1] }
	    -mat*	{ set BENCH(MATCH)   [lindex $argv 1] }
	    -iter*	{ set BENCH(ITERS)   [lindex $argv 1] }
	    -thr*	{ set BENCH(THREADS) [lindex $argv 1] }
            -pkg*       { set BENCH(PKGDIR)  [lindex $argv 1] }
	    default {
		foreach arg $argv {
		    if {![file exists $arg]} { usage }
		    lappend BENCH(FILES) $arg
		}
		break
	    }
	}
	set argv [lreplace $argv 0 1]
    }
}

if {[string length $BENCH(PKGDIR)]} {
    set auto_path [linsert $auto_path 0 $BENCH(PKGDIR)]
}

if {$BENCH(THREADS)} {
    # We have to be able to load threads if we want to use threads, and
    # we don't want to create more threads than we have files.
    if {[catch {package require Thread}]} {
	set BENCH(THREADS) 0
    } elseif {[llength $BENCH(FILES)] < $BENCH(THREADS)} {
	set BENCH(THREADS) [llength $BENCH(FILES)]
    }
}

rename exit exit.true
proc exit args {
    error "called \"exit $args\" in benchmark test"
}

if {[string compare $BENCH(OUTFILE) stdout]} {
    set BENCH(OUTFID) [open $BENCH(OUTFILE) w]
} else {
    set BENCH(OUTFID) stdout
}

#
# Everything that gets output must be in pairwise format, because
# the data will be collected in via an 'array set'.
#

if {$BENCH(THREADS)} {
    # Each file must run in it's own thread because of all the extra
    # header stuff they have.
    #set DEBUG 1
    proc thread_one {{id 0}} {
	global BENCH
	set file [lindex $BENCH(FILES) 0]
	set BENCH(FILES) [lrange $BENCH(FILES) 1 end]
	if {[file exists $file]} {
	    incr BENCH(inuse)
	    FEEDBACK [list Sourcing $file]
	    if {$id} {
		set them $id
	    } else {
		set them [thread::create]
		thread::send -async $them { load {} Thread }
		thread::send -async $them \
			[list array set BENCH [array get BENCH]]
		thread::send -async $them \
			[list proc bench_tmpfile {} [info body bench_tmpfile]]
		thread::send -async $them \
			[list proc bench_rm {args} [info body bench_rm]]
		thread::send -async $them \
			[list proc bench {args} [info body bench]]
	    }
	    if {[info exists ::DEBUG]} {
		FEEDBACK "SEND [clock seconds] thread $them $file INUSE\
		$BENCH(inuse) of $BENCH(THREADS)"
	    }
	    thread::send -async $them [list source $file]
	    thread::send -async $them \
		    [list thread::send $BENCH(us) [list thread_ready $them]]
	    #thread::send -async $them { thread::unwind }
	}
    }

    proc thread_em {} {
	global BENCH
	while {[llength $BENCH(FILES)]} {
	    if {[info exists ::DEBUG]} {
		FEEDBACK "THREAD ONE [lindex $BENCH(FILES) 0]"
	    }
	    thread_one
	    if {$BENCH(inuse) >= $BENCH(THREADS)} {
		break
	    }
	}
    }

    proc thread_ready {id} {
	global BENCH

	incr BENCH(inuse) -1
	if {[llength $BENCH(FILES)]} {
	    if {[info exists ::DEBUG]} {
		FEEDBACK "SEND ONE [clock seconds] thread $id"
	    }
	    thread_one $id
	} else {
	    if {[info exists ::DEBUG]} {
		FEEDBACK "UNWIND thread $id"
	    }
	    thread::send -async $id { thread::unwind }
	}
    }

    proc thread_report {desc code res} {
	global BENCH bench errorInfo errorCode

	if {$code == 0} {
	    # Get just the microseconds value from the time result
	    set res [lindex $res 0]
	} elseif {$code != 666} {
	    # A 666 result code means pass it through to the bench suite.
	    # Otherwise throw errors all the way out, unless we specified
	    # not to throw errors (option -errors 0 to libbench).
	    if {$BENCH(ERRORS)} {
		return -code $code -errorinfo $errorInfo \
			-errorcode $errorCode
	    } else {
		set res "ERR"
	    }
	}
	#set bench($desc) $res
	RESULT $desc $res
    }

    proc thread_finish {{delay 4000}} {
	global BENCH bench
	set val [expr {[llength [thread::names]] > 1}]
	#set val [expr {$BENCH(inuse)}]
	if {$val} {
	    after $delay [info level 0]
	} else {
	    if {0} {foreach desc [array names bench] {
		RESULT $desc $bench($desc)
	    }}
	    if {$BENCH(EXIT)} {
		exit.true ; # needed for Tk tests
	    }
	}
    }

    set BENCH(us) [thread::id]
    set BENCH(inuse) 0 ; # num threads in use
    FEEDBACK [list __THREADED [package provide Thread]]

    thread_em
    thread_finish
    vwait forever
} else {
    foreach BENCH(file) $BENCH(FILES) {
	if {[file exists $BENCH(file)]} {
	    FEEDBACK [list Sourcing $BENCH(file)]
	    source $BENCH(file)
	}
    }

    if {0} {foreach desc [array names bench] {
	RESULT $desc $bench($desc)
    }}

    if {$BENCH(EXIT)} {
	exit.true ; # needed for Tk tests
    }
}
