#!/usr/bin/tclsh
# ------------------------------------------------------------------------
#
# comparePerf.tcl --
#
#  Script to compare performance data from multiple runs.
#
# ------------------------------------------------------------------------
#
# See the file "license.terms" for information on usage and redistribution
# of this file.
#
# Usage:
#   tclsh comparePerf.tcl [--regexp RE] [--ratio time|rate] [--combine] [--base BASELABEL] PERFFILE ...
#
# The test data from each input file is tabulated so as to compare the results
# of test runs. If a PERFFILE does not exist, it is retried by adding the
# .perf extension. If the --regexp is specified, only test results whose
# id matches RE are examined.
#
# If the --combine option is specified, results of test sets with the same
# label are combined and averaged in the output.
#
# If the --base option is specified, the BASELABEL is used as the label to use
# the base timing. Otherwise, the label of the first data file is used.
#
# If --ratio option is "time" the ratio of test timing vs base test timing
# is shown. If "rate" (default) the inverse is shown.
#
# If --no-header is specified, the header describing test configuration is
# not output.
#
# The format of input files is as follows:
#
# Each line must begin with one of the characters below followed by a space
# followed by a string whose semantics depend on the initial character.
# E - Full path to the Tcl executable that was used to generate the file
# V - The Tcl patchlevel of the implementation
# D - A description for the test run for human consumption
# L - A label used to identify run environment. The --combine option will
#     average all measuremets that have the same label. An input file without
#     a label is treated as having a unique label and not combined with any other.
# P - A test measurement (see below)
# R - The number of runs made for the each test
# # - A comment, may be an arbitrary string. Usually included in performance
#     data to describe the test. This is silently ignored
#
# Any lines not matching one of the above are ignored with a warning to stderr.
#
# A line beginning with the "P" marker is a test measurement. The first word
# following is a floating point number representing the test runtime.
# The remaining line (after trimming of whitespace) is the id of the test.
# Test generators are encouraged to make the id a well-defined machine-parseable
# as well human readable description of the test. The id must not appear more
# than once. An example test measurement line:
# P    2.32280 linsert in unshared L[10000] 1 elems 10000 times at 0 (var)
# Note here the iteration count is not present.
#

namespace eval perf::compare {
    # List of dictionaries, one per input file
    variable PerfData
}

proc perf::compare::warn {message} {
    puts stderr "Warning: $message"
}
proc perf::compare::print {text} {
    puts stdout $text
}
proc perf::compare::slurp {testrun_path} {
    variable PerfData

    set runtimes [dict create]

    set path [file normalize $testrun_path]
    set fd [open $path]
    array set header {}
    while {[gets $fd line] >= 0} {
	set line [regsub -all {\s+} [string trim $line] " "]
	switch -glob -- $line {
	    "#*" {
		# Skip comments
	    }
	    "R *" -
	    "L *" -
	    "D *" -
	    "V *" -
	    "T *" -
	    "E *" {
		set marker [lindex $line 0]
		if {[info exists header($marker)]} {
		    warn "Ignoring $marker record (duplicate): \"$line\""
		}
		set header($marker) [string range $line 2 end]
	    }
	    "P *" {
		if {[scan $line "P %f %n" runtime id_start] == 2} {
		    set id [string range $line $id_start end]
		    if {[dict exists $runtimes $id]} {
			warn "Ignoring duplicate test id \"$id\""
		    } else {
			dict set runtimes $id $runtime
		    }
		} else {
		    warn "Invalid test result line format: \"$line\""
		}
	    }
	    default {
		puts stderr "Warning: ignoring unrecognized line \"$line\""
	    }
	}
    }
    close $fd

    set result [dict create Input $path Runtimes $runtimes]
    foreach {c k} {
	L Label
	V Version
	E Executable
	D Description
    } {
	if {[info exists header($c)]} {
	    dict set result $k $header($c)
	}
    }

    return $result
}

proc perf::compare::burp {test_sets} {
    variable Options

    # Print the key for each test run
    set header "           "
    set separator "           "
    foreach test_set $test_sets {
	set test_set_key "\[[incr test_set_num]\]"
	if {! $Options(--no-header)} {
	    print "$test_set_key"
	    foreach k {Label Executable Version Input Description} {
		if {[dict exists $test_set $k]} {
		    print "$k: [dict get $test_set $k]"
		}
	    }
	}
	append header $test_set_key $separator
	set separator "                 "; # Expand because later columns have ratio
    }
    set header [string trimright $header]

    if {! $Options(--no-header)} {
	print ""
	if {$Options(--ratio) eq "rate"} {
	    set ratio_description "ratio of baseline to the measurement (higher is faster)."
	} else {
	    set ratio_description "ratio of measurement to the baseline (lower is faster)."
	}
	print "The first column \[1\] is the baseline measurement."
	print "Subsequent columns are pairs of the additional measurement and "
	print $ratio_description
	print ""
    }

    # Print the actual test run data

    print $header
    set test_sets [lassign $test_sets base_set]
    set fmt {%#10.5f}
    set fmt_ratio {%-6.2f}
    foreach {id base_runtime} [dict get $base_set Runtimes] {
	if {[info exists Options(--regexp)]} {
	    if {![regexp $Options(--regexp) $id]} {
		continue
	    }
	}
	if {$Options(--print-test-number)} {
	    set line "[format %-4s [incr counter].]"
	} else {
	    set line ""
	}
	append line [format $fmt $base_runtime]
	foreach test_set $test_sets {
	    if {[dict exists $test_set Runtimes $id]} {
		set runtime [dict get $test_set Runtimes $id]
		if {$Options(--ratio) eq "time"} {
		    if {$base_runtime != 0} {
			set ratio [format $fmt_ratio [expr {$runtime/$base_runtime}]]
		    } else {
			if {$runtime == 0} {
			    set ratio "NaN   "
			} else {
			    set ratio "Inf   "
			}
		    }
		} else {
		    if {$runtime != 0} {
			set ratio [format $fmt_ratio [expr {$base_runtime/$runtime}]]
		    } else {
			if {$base_runtime == 0} {
			    set ratio "NaN   "
			} else {
			    set ratio "Inf   "
			}
		    }
		}
		append line "|" [format $fmt $runtime] "|" $ratio
	    } else {
		append line [string repeat { } 11]
	    }
	}
	append line "|" $id
	print $line
    }
}

proc perf::compare::chew {test_sets} {
    variable Options

    # Combine test sets that have the same label, averaging the values
    set unlabeled_sets {}
    array set labeled_sets {}

    foreach test_set $test_sets {
	# If there is no label, treat as independent set
	if {![dict exists $test_set Label]} {
	    lappend unlabeled_sets $test_set
	} else {
	    lappend labeled_sets([dict get $test_set Label]) $test_set
	}
    }

    foreach label [array names labeled_sets] {
	set combined_set [lindex $labeled_sets($label) 0]
	set runtimes [dict get $combined_set Runtimes]
	foreach test_set [lrange $labeled_sets($label) 1 end] {
	    dict for {id timing} [dict get $test_set Runtimes] {
		dict lappend runtimes $id $timing
	    }
	}
	dict for {id timings} $runtimes {
	    set total [tcl::mathop::+ {*}$timings]
	    dict set runtimes $id [expr {$total/[llength $timings]}]
	}
	dict set combined_set Runtimes $runtimes
	set labeled_sets($label) $combined_set
    }

    # Choose the "base" test set
    if {![info exists Options(--base)]} {
	set first_set [lindex $test_sets 0]
	if {[dict exists $first_set Label]} {
	    # Use label of first as the base
	    set Options(--base) [dict get $first_set Label]
	}
    }

    if {[info exists Options(--base)] && $Options(--base) ne ""} {
	lappend combined_sets $labeled_sets($Options(--base));# Will error if no such
	unset labeled_sets($Options(--base))
    } else {
	lappend combined_sets [lindex $unlabeled_sets 0]
	set unlabeled_sets [lrange $unlabeled_sets 1 end]
    }
    foreach label [array names labeled_sets] {
	lappend combined_sets $labeled_sets($label)
    }
    lappend combined_sets {*}$unlabeled_sets

    return $combined_sets
}

proc perf::compare::setup {argv} {
    variable Options

    array set Options {
	--ratio rate
	--combine 0
	--print-test-number 0
	--no-header 0
    }
    while {[llength $argv]} {
	set argv [lassign $argv arg]
	switch -glob -- $arg {
	    -r -
	    --regexp {
		if {[llength $argv] == 0} {
		    error "Missing value for option $arg"
		}
		set argv [lassign $argv val]
		set Options(--regexp) $val
	    }
	    --ratio {
		if {[llength $argv] == 0} {
		    error "Missing value for option $arg"
		}
		set argv [lassign $argv val]
		if {$val ni {time rate}} {
		    error "Value for option $arg must be either \"time\" or \"rate\""
		}
		set Options(--ratio) $val
	    }
	    --print-test-number -
	    --combine -
	    --no-header {
		set Options($arg) 1
	    }
	    --base {
		if {[llength $argv] == 0} {
		    error "Missing value for option $arg"
		}
		set argv [lassign $argv val]
		set Options($arg) $val
	    }
	    -- {
		# Remaining will be passed back to the caller
		break
	    }
	    --* {
		error "Unknown option $arg"
	    }
	    -* {
		error "Unknown option -[lindex $arg 0]"
	    }
	    default {
		# Remaining will be passed back to the caller
		set argv [linsert $argv 0 $arg]
		break;
	    }
	}
    }

    set paths {}
    foreach path $argv {
	set path [file join $path]; # Convert from native else glob fails
	if {[file isfile $path]} {
	    lappend paths $path
	    continue
	}
	if {[file isfile $path.perf]} {
	    lappend paths $path.perf
	    continue
	}
	lappend paths {*}[glob -nocomplain $path]
    }
    return $paths
}
proc perf::compare::main {} {
    variable Options

    set paths [setup $::argv]
    if {[llength $paths] == 0} {
	error "No test data files specified."
    }
    set test_data [list ]
    set seen [dict create]
    foreach path $paths {
	if {![dict exists $seen $path]} {
	    lappend test_data [slurp $path]
	    dict set seen $path ""
	}
    }

    if {$Options(--combine)} {
	set test_data [chew $test_data]
    }

    burp $test_data
}

perf::compare::main
