#!/usr/bin/tclsh
# ------------------------------------------------------------------------
#
# listPerf.tcl --
#
#  This file provides performance tests for list operations. Run
#     tclsh listPerf.tcl help
#  for options.
# ------------------------------------------------------------------------
#
# See the file "license.terms" for information on usage and redistribution
# of this file.
#
# Note: this file does not use the test-performance.tcl framework as we want
# more direct control over timerate options.

catch {package require twapi}

namespace eval perf::list {
    variable perfScript [file normalize [info script]]

    # Test for each of these lengths
    variable Lengths {10 100 1000 10000}

    variable RunTimes
    set RunTimes(command) 0.0
    set RunTimes(total) 0.0

    variable Options
    array set Options {
	--print-comments   0
	--print-iterations 0
    }

    # Procs used for calibrating overhead
    proc proc2args {a b} {}
    proc proc3args {a b c} {}

    proc print {s} {
	puts $s
    }
    proc print_usage {} {
	puts stderr "Usage: [file tail [info nameofexecutable]] $::argv0 \[options\] \[command ...\]"
	puts stderr "\t--description DESC\tHuman readable description of test run"
	puts stderr "\t--label LABEL\tA label used to identify test environment"
	puts stderr "\t--print-comments\tPrint comment for each test"
	puts stderr "\t--print-iterations\tPrint number of iterations run for each test"
    }

    proc setup {argv} {
	variable Options
	variable Lengths

	while {[llength $argv]} {
	    set argv [lassign $argv arg]
	    switch -glob -- $arg {
		--print-comments -
		--print-iterations {
		    set Options($arg) 1
		}
		--label -
		--description {
		    if {[llength $argv] == 0} {
			error "Missing value for option $arg"
		    }
		    set argv [lassign $argv val]
		    set Options($arg) $val
		}
		--lengths {
		    if {[llength $argv] == 0} {
			error "Missing value for option $arg"
		    }
		    set argv [lassign $argv val]
		    set Lengths $val
		}
		-- {
		    # Remaining will be passed back to the caller
		    break
		}
		--* {
		    puts stderr "Unknown option $arg"
		    print_usage
		    exit 1
		}
		default {
		    # Remaining will be passed back to the caller
		    set argv [linsert $argv 0 $arg]
		    break;
		}
	    }
	}

	return $argv
    }
    proc format_timings {us iters} {
	variable Options
	if {!$Options(--print-iterations)} {
	    return "[format {%#10.4f} $us]"
	}
	return "[format {%#10.4f} $us] [format {%8d} $iters]"
    }
    proc measure {id script args} {
	variable NullOverhead
	variable RunTimes
	variable Options

	set opts(-overhead) ""
	set opts(-runs) 5
	while {[llength $args]} {
	    set args [lassign $args opt]
	    if {[llength $args] == 0} {
		error "No argument supplied for $opt option. Test: $id"
	    }
	    set args [lassign $args val]
	    switch $opt {
		-setup -
		-cleanup -
		-overhead -
		-time -
		-runs -
		-reps {
		    set opts($opt) $val
		}
		default {
		    error "Unknown option $opt. Test: $id"
		}
	    }
	}

	set timerate_args {}
	if {[info exists opts(-time)]} {
	    lappend timerate_args $opts(-time)
	}
	if {[info exists opts(-reps)]} {
	    if {[info exists opts(-time)]} {
		set timerate_args [list $opts(-time) $opts(-reps)]
	    } else {
		# Force the default for first time option
		set timerate_args [list 1000 $opts(-reps)]
	    }
	} elseif {[info exists opts(-time)]} {
	    set timerate_args [list $opts(-time)]
	}
	if {[info exists opts(-setup)]} {
	    uplevel 1 $opts(-setup)
	}
	# Cache the empty overhead to prevent unnecessary delays. Note if you modify
	# to cache other scripts, the cache key must be AFTER substituting the
	# overhead script in the caller's context.
	if {$opts(-overhead) eq ""} {
	    if {![info exists NullOverhead]} {
		set NullOverhead [lindex [timerate {}] 0]
	    }
	    set overhead_us $NullOverhead
	} else {
	    # The overhead measurements might use setup so we need to setup
	    # first and then cleanup in preparation for setting up again for
	    # the script to be measured
	    if {[info exists opts(-setup)]} {
		uplevel 1 $opts(-setup)
	    }
	    set overhead_us [lindex [uplevel 1 [list timerate $opts(-overhead)]] 0]
	    if {[info exists opts(-cleanup)]} {
		uplevel 1 $opts(-cleanup)
	    }
	}
	set timings {}
	for {set i 0} {$i < $opts(-runs)} {incr i} {
	    if {[info exists opts(-setup)]} {
		uplevel 1 $opts(-setup)
	    }
	    lappend timings [uplevel 1 [list timerate -overhead $overhead_us $script {*}$timerate_args]]
	    if {[info exists opts(-cleanup)]} {
		uplevel 1 $opts(-cleanup)
	    }
	}
	set timings [lsort -real -index 0 $timings]
	if {$opts(-runs) > 15} {
	    set ignore [expr {$opts(-runs)/8}]
	} elseif {$opts(-runs) >= 5} {
	    set ignore 2
	} else {
	    set ignore 0
	}
	# Ignore highest and lowest
	set timings [lrange $timings 0 end-$ignore]
	# Average it out
	set us 0
	set iters 0
	foreach timing $timings {
	    set us [expr {$us + [lindex $timing 0]}]
	    set iters [expr {$iters + [lindex $timing 2]}]
	}
	set us [expr {$us/[llength $timings]}]
	set iters [expr {$iters/[llength $timings]}]

	set RunTimes(command) [expr {$RunTimes(command) + $us}]
	print "P [format_timings $us $iters] $id"
    }
    proc comment {args} {
	variable Options
	if {$Options(--print-comments)} {
	    print "# [join $args { }]"
	}
    }
    proc spanned_list {len} {
	# Note - for small len, this will not create a spanned list
	set delta [expr {$len/8}]
	return [lrange [lrepeat [expr {$len+(2*$delta)}] a] $delta [expr {$delta+$len-1}]]
    }
    proc print_separator {command} {
	comment [string repeat = 80]
	comment Command: $command
    }

    oo::class create ListPerf {
	constructor {args} {
	    my variable Opts
	    # Note default Opts can be overridden in construct as well as in measure
	    set Opts [dict merge {
		-setup {
		    set L [lrepeat $len a]
		    set Lspan [perf::list::spanned_list $len]
		} -cleanup {
		    unset -nocomplain L
		    unset -nocomplain Lspan
		    unset -nocomplain L2
		}
	    } $args]
	}
	method measure {comment script locals args} {
	    my variable Opts
	    dict with locals {}
	    ::perf::list::measure $comment $script {*}[dict merge $Opts $args]
	}
	method option {opt val} {
	    my variable Opts
	    dict set Opts $opt $val
	}
	method option_unset {opt} {
	    my variable Opts
	    unset -nocomplain Opts($opt)
	}
    }

    proc linsert_describe {share_mode len at num iters} {
	return "linsert L\[$len\] $share_mode $num elems $iters times at $at"
    }
    proc linsert_perf {} {
	variable Lengths

	print_separator linsert

	ListPerf create perf -overhead {set L {}} -time 1000

	# Note: Const indices take different path through bytecode than variable
	# indices hence separate cases below


	# Var case
	foreach share_mode {shared unshared} {
	    set idx 0
	    if {$share_mode eq "shared"} {
		comment == Insert into empty lists
		comment Insert one element into empty list
		measure [linsert_describe shared 0 "0 (var)" 1 1] {linsert $L $idx ""} -setup {set idx 0; set L {}}
	    } else {
		comment == Insert into empty lists
		comment Insert one element into empty list
		measure [linsert_describe unshared 0 "0 (var)" 1 1] {linsert {} $idx ""} -setup {set idx 0}
	    }
	    foreach idx_str [list 0 1 mid end-1 end] {
		foreach len $Lengths {
		    if {$idx_str eq "mid"} {
			set idx [expr {$len/2}]
		    } else {
			set idx $idx_str
		    }
		    # perf option -reps $reps
		    set reps 1000
		    if {$share_mode eq "shared"} {
			comment Insert once to shared list with variable index
			perf measure [linsert_describe shared $len "$idx (var)" 1 1] \
			    {linsert $L $idx x} [list len $len idx $idx] -overhead {} -reps 100000

			comment Insert multiple times to shared list with variable index
			perf measure [linsert_describe shared $len "$idx (var)" 1 $reps] {
			    set L [linsert $L $idx X]
			} [list len $len idx $idx] -reps $reps

			comment Insert multiple items multiple times to shared list with variable index
			perf measure [linsert_describe shared $len "$idx (var)" 5 $reps] {
			    set L [linsert $L $idx X X X X X]
			} [list len $len idx $idx] -reps $reps
		    } else {
			# NOTE : the Insert once case is left out for unshared lists
			# because it requires re-init on every iteration resulting
			# in a lot of measurement noise
			comment Insert multiple times to unshared list with variable index
			perf measure [linsert_describe unshared $len "$idx (var)" 1 $reps] {
			    set L [linsert $L[set L {}] $idx X]
			} [list len $len idx $idx] -reps $reps
			comment Insert multiple items multiple times to unshared list with variable index
			perf measure [linsert_describe unshared $len "$idx (var)" 5 $reps] {
			    set L [linsert $L[set L {}] $idx X X X X X]
			} [list len $len idx $idx] -reps $reps
		    }
		}
	    }
	}

	# Const index
	foreach share_mode {shared unshared} {
	    if {$share_mode eq "shared"} {
		comment == Insert into empty lists
		comment Insert one element into empty list
		measure [linsert_describe shared 0 "0 (const)" 1 1] {linsert $L 0 ""} -setup {set L {}}
	    } else {
		comment == Insert into empty lists
		comment Insert one element into empty list
		measure [linsert_describe unshared 0 "0 (const)" 1 1] {linsert {} 0 ""}
	    }
	    foreach idx_str [list 0 1 mid end end-1] {
		foreach len $Lengths {
		    # Note end, end-1 explicitly calculated as otherwise they
		    # are not treated as const
		    if {$idx_str eq "mid"} {
			set idx [expr {$len/2}]
		    } elseif {$idx_str eq "end"} {
			set idx [expr {$len-1}]
		    } elseif {$idx_str eq "end-1"} {
			set idx [expr {$len-2}]
		    } else {
			set idx $idx_str
		    }
		    #perf option -reps $reps
		    set reps 100
		    if {$share_mode eq "shared"} {
			comment Insert once to shared list with const index
			perf measure [linsert_describe shared $len "$idx (const)" 1 1] \
			    "linsert \$L $idx x" [list len $len] -overhead {} -reps 10000

			comment Insert multiple times to shared list with const index
			perf measure [linsert_describe shared $len "$idx (const)" 1 $reps] \
			    "set L \[linsert \$L $idx X\]" [list len $len] -reps $reps

			comment Insert multiple items multiple times to shared list with const index
			perf measure [linsert_describe shared $len "$idx (const)" 5 $reps] \
			    "set L \[linsert \$L $idx X X X X X\]" [list len $len] -reps $reps
		    } else {
			comment Insert multiple times to unshared list with const index
			perf measure [linsert_describe unshared $len "$idx (const)" 1 $reps] \
			    "set L \[linsert \$L\[set L {}\] $idx X]" [list len $len] -reps $reps

			comment Insert multiple items multiple times to unshared list with const index
			perf measure [linsert_describe unshared $len "$idx (const)" 5 $reps] \
			    "set L \[linsert \$L\[set L {}\] $idx X X X X X]" [list len $len] -reps $reps
		    }
		}
	    }
	}

	# Note: no span tests because the inserts above will themselves create
	# spanned lists

	perf destroy
    }

    proc list_describe {len text} {
	return "list L\[$len\] $text"
    }
    proc list_perf {} {
	variable Lengths

	print_separator list

	ListPerf create perf
	foreach len $Lengths {
	    set s [join [lrepeat $len x]]
	    comment Create a list from a string
	    perf measure [list_describe $len "from a string"] {list $s} [list s $s len $len]
	}
	foreach len $Lengths {
	    comment Create a list from expansion - single list (special optimal case)
	    perf measure [list_describe $len "from a {*}list"] {list {*}$L} [list len $len]
	    comment Create a list from two lists - real test of expansion speed
	    perf measure [list_describe $len "from a {*}list {*}list"] {list {*}$L {*}$L} [list len [expr {$len/2}]]
	}

	perf destroy
    }

    proc lappend_describe {share_mode len num iters} {
	return "lappend L\[$len\] $share_mode $num elems $iters times"
    }
    proc lappend_perf {} {
	variable Lengths

	print_separator lappend

	ListPerf create perf -setup {set L [lrepeat [expr {$len/4}] x]}

	# Shared
	foreach len $Lengths {
	    comment Append to a shared list variable multiple times
	    perf measure [lappend_describe shared [expr {$len/2}] 1 $len] {
		set L2 $L; # Make shared
		lappend L x
	    } [list len $len] -reps $len -overhead {set L2 $L}
	}

	# Unshared
	foreach len $Lengths {
	    comment Append to a unshared list variable multiple times
	    perf measure [lappend_describe unshared [expr {$len/2}] 1 $len] {
		lappend L x
	    } [list len $len] -reps $len
	}

	# Span
	foreach len $Lengths {
	    comment Append to a unshared-span list variable multiple times
	    perf measure [lappend_describe unshared-span [expr {$len/2}] 1 $len] {
		lappend Lspan x
	    } [list len $len] -reps $len
	}

	perf destroy
    }

    proc lpop_describe {share_mode len at reps} {
	return "lpop L\[$len\] $share_mode at $at $reps times"
    }
    proc lpop_perf {} {
	variable Lengths

	print_separator lpop

	ListPerf create perf

	# Shared
	perf option -overhead {set L2 $L}
	foreach len $Lengths {
	    set reps [expr {($len >= 1000 ? ($len/2) : $len) - 2}]
	    foreach idx {0 1 end-1 end}  {
		comment Pop element at position $idx from a shared list variable
		perf measure [lpop_describe shared $len $idx $reps] {
		    set L2 $L
		    lpop L $idx
		} [list len $len idx $idx] -reps $reps
	    }
	}

	# Unshared
	perf option -overhead {}
	foreach len $Lengths {
	    set reps [expr {($len >= 1000 ? ($len/2) : $len) - 2}]
	    foreach idx {0 1 end-1 end}  {
		comment Pop element at position $idx from an unshared list variable
		perf measure [lpop_describe unshared $len $idx $reps] {
		    lpop L $idx
		} [list len $len idx $idx] -reps $reps
	    }
	}

	perf destroy

	# Nested
	ListPerf create perf -setup {
	    set L [lrepeat $len [list a b]]
	}

	# Shared, nested index
	perf option -overhead {set L2 $L; set L L2}
	foreach len $Lengths {
	    set reps [expr {($len >= 1000 ? ($len/2) : $len) - 2}]
	    foreach idx {0 1 end-1 end}  {
		perf measure [lpop_describe shared $len "{$idx 0}" $reps] {
		    set L2 $L
		    lpop L $idx 0
		    set L $L2
		} [list len $len idx $idx] -reps $reps
	    }
	}

	# TODO - Nested Unshared
	# Not sure how to measure performance. When unshared there is no copy
	# so deleting a nested index repeatedly is not feasible

	perf destroy
    }

    proc lassign_describe {share_mode len num reps} {
	return "lassign L\[$len\] $share_mode $num elems $reps times"
    }
    proc lassign_perf {} {
	variable Lengths

	print_separator lassign

	ListPerf create perf

	foreach share_mode {shared unshared} {
	    foreach len $Lengths {
		if {$share_mode eq "shared"} {
		    set reps 1000
		    comment Reflexive lassign - shared
		    perf measure [lassign_describe shared $len 1 $reps] {
			set L2 $L
			set L2 [lassign $L2 v]
		    } [list len $len] -overhead {set L2 $L} -reps $reps

		    comment Reflexive lassign - shared, multiple
		    perf measure [lassign_describe shared $len 5 $reps] {
			set L2 $L
			set L2 [lassign $L2 a b c d e]
		    } [list len $len] -overhead {set L2 $L} -reps $reps
		} else {
		    set reps [expr {($len >= 1000 ? ($len/2) : $len) - 2}]
		    comment Reflexive lassign - unshared
		    perf measure [lassign_describe unshared $len 1 $reps] {
			set L [lassign $L v]
		    } [list len $len] -reps $reps
		}
	    }
	}
	perf destroy
    }

    proc lrepeat_describe {len num} {
	return "lrepeat L\[$len\] $num elems at a time"
    }
    proc lrepeat_perf {} {
	variable Lengths

	print_separator lrepeat

	ListPerf create perf -reps 100000
	foreach len $Lengths {
	    comment Generate a list from a single repeated element
	    perf measure [lrepeat_describe $len 1] {
		lrepeat $len a
	    } [list len $len]

	    comment Generate a list from multiple repeated elements
	    perf measure [lrepeat_describe $len 5] {
		lrepeat $len a b c d e
	    } [list len $len]
	}

	perf destroy
    }

    proc lreverse_describe {share_mode len} {
	return "lreverse L\[$len\] $share_mode"
    }
    proc lreverse_perf {} {
	variable Lengths

	print_separator lreverse

	ListPerf create perf -reps 10000

	foreach share_mode {shared unshared} {
	    foreach len $Lengths {
		if {$share_mode eq "shared"} {
		    comment Reverse a shared list
		    perf measure [lreverse_describe shared $len] {
			lreverse $L
		    } [list len $len]

		    if {$len > 100} {
			comment Reverse a shared-span list
			perf measure [lreverse_describe shared-span $len] {
			    lreverse $Lspan
			} [list len $len]
		    }
		} else {
		    comment Reverse a unshared list
		    perf measure [lreverse_describe unshared $len] {
			set L [lreverse $L[set L {}]]
		    } [list len $len] -overhead {set L $L; set L {}}

		    if {$len >= 100} {
			comment Reverse a unshared-span list
			perf measure [lreverse_describe unshared-span $len] {
			    set Lspan [lreverse $Lspan[set Lspan {}]]
			} [list len $len] -overhead {set Lspan $Lspan; set Lspan {}}
		    }
		}
	    }
	}

	perf destroy
    }

    proc llength_describe {share_mode len} {
	return "llength L\[$len\] $share_mode"
    }
    proc llength_perf {} {
	variable Lengths

	print_separator llength

	ListPerf create perf -reps 100000

	foreach len $Lengths {
	    comment Length of a list
	    perf measure [llength_describe shared $len] {
		llength $L
	    } [list len $len]

	    if {$len >= 100} {
		comment Length of a span list
		perf measure [llength_describe shared-span $len] {
		    llength $Lspan
		} [list len $len]
	    }
	}

	perf destroy
    }

    proc lindex_describe {share_mode len at} {
	return "lindex L\[$len\] $share_mode at $at"
    }
    proc lindex_perf {} {
	variable Lengths

	print_separator lindex

	ListPerf create perf -reps 100000

	foreach len $Lengths {
	    comment Index into a list
	    set idx [expr {$len/2}]
	    perf measure [lindex_describe shared $len $idx] {
		lindex $L $idx
	    } [list len $len idx $idx]

	    if {$len >= 100} {
		comment Index into a span list
		perf measure [lindex_describe shared-span $len $idx] {
		    lindex $Lspan $idx
		} [list len $len idx $idx]
	    }
	}

	perf destroy
    }

    proc lrange_describe {share_mode len range} {
	return "lrange L\[$len\] $share_mode range $range"
    }

    proc lrange_perf {} {
	variable Lengths

	print_separator lrange

	ListPerf create perf -time 1000 -reps 100000

	foreach share_mode {shared unshared} {
	    foreach len $Lengths {
		set eighth [expr {$len/8}]
		set ranges [list \
				[list 0 0]  [list 0 end-1] \
				[list $eighth [expr {3*$eighth}]] \
				[list $eighth [expr {7*$eighth}]] \
				[list 1 end] [list end-1 end] \
			       ]
		foreach range $ranges {
		    comment Range $range in $share_mode list of length $len
		    if {$share_mode eq "shared"} {
			perf measure [lrange_describe shared $len $range] \
			    "lrange \$L $range" [list len $len range $range]
		    } else {
			perf measure [lrange_describe unshared $len $range] \
			    "lrange \[lrepeat \$len\ a] $range" \
			    [list len $len range $range] -overhead {lrepeat $len a}
		    }
		}

		if {$len >= 100} {
		    foreach range $ranges {
			comment Range $range in ${share_mode}-span list of length $len
			if {$share_mode eq "shared"} {
			    perf measure [lrange_describe shared-span $len $range] \
				"lrange \$Lspan {*}$range" [list len $len range $range]
			} else {
			    perf measure [lrange_describe unshared-span $len $range] \
				"lrange \[perf::list::spanned_list \$len\] $range" \
				[list len $len range $range] -overhead {perf::list::spanned_list $len}
			}
		    }
		}
	    }
	}

	perf destroy
    }

    proc lset_describe {share_mode len at} {
	return "lset L\[$len\] $share_mode at $at"
    }
    proc lset_perf {} {
	variable Lengths

	print_separator lset

	ListPerf create perf -reps 10000

	# Shared
	foreach share_mode {shared unshared} {
	    foreach len $Lengths {
		foreach idx {0 1 end-1 end end+1}  {
		    comment lset at position $idx in a $share_mode list variable
		    if {$share_mode eq "shared"} {
			perf measure [lset_describe shared $len $idx] {
			    set L2 $L
			    lset L $idx X
			} [list len $len idx $idx] -overhead {set L2 $L}
		    } else {
			perf measure [lset_describe unshared $len $idx] {
			    lset L $idx X
			} [list len $len idx $idx]
		    }
		}
	    }
	}

	perf destroy

	# Nested
	ListPerf create perf -setup {
	    set L [lrepeat $len [list a b]]
	}

	foreach share_mode {shared unshared} {
	    foreach len $Lengths {
		foreach idx {0 1 end-1 end}  {
		    comment lset at position $idx in a $share_mode list variable
		    if {$share_mode eq "shared"} {
			perf measure [lset_describe shared $len "{$idx 0}"] {
			    set L2 $L
			    lset L $idx 0 X
			} [list len $len idx $idx] -overhead {set L2 $L}
		    } else {
			perf measure [lset_describe unshared $len "{$idx 0}"] {
			    lset L $idx 0 {X Y}
			} [list len $len idx $idx]
		    }
		}
	    }
	}

	perf destroy
    }

    proc lremove_describe {share_mode len at nremoved} {
	return "lremove L\[$len\] $share_mode $nremoved elements at $at"
    }
    proc lremove_perf {} {
	variable Lengths

	print_separator lremove

	ListPerf create perf -reps 10000

	foreach share_mode {shared unshared} {
	    foreach len $Lengths {
		foreach idx [list 0 1 [expr {$len/2}] end-1 end] {
		    if {$share_mode eq "shared"} {
			comment Remove one element from shared list
			perf measure [lremove_describe shared $len $idx 1] \
			    {lremove $L $idx} [list len $len idx $idx]

		    } else {
			comment Remove one element from unshared list
			set reps [expr {$len >= 1000 ? ($len/8) : ($len-2)}]
			perf measure [lremove_describe unshared $len $idx 1] \
			    {set L [lremove $L[set L {}] $idx]} [list len $len idx $idx] \
			    -overhead {set L $L; set L {}} -reps $reps
		    }
		}
		if {$share_mode eq "shared"} {
		    comment Remove multiple elements from shared list
		    perf measure [lremove_describe shared $len [list 0 1 [expr {$len/2}] end-1 end] 5] {
			lremove $L 0 1 [expr {$len/2}] end-1 end
		    } [list len $len]
		}
	    }
	    # Span
	    foreach len $Lengths {
		foreach idx [list 0 1 [expr {$len/2}] end-1 end] {
		    if {$share_mode eq "shared"} {
			comment Remove one element from shared-span list
			perf measure [lremove_describe shared-span $len $idx 1] \
			    {lremove $Lspan $idx} [list len $len idx $idx]
		    } else {
			comment Remove one element from unshared-span list
			set reps [expr {$len >= 1000 ? ($len/8) : ($len-2)}]
			perf measure [lremove_describe unshared-span $len $idx 1] \
			    {set Lspan [lremove $Lspan[set Lspan {}] $idx]} [list len $len idx $idx] \
			    -overhead {set Lspan $Lspan; set Lspan {}} -reps $reps
		    }
		}
		if {$share_mode eq "shared"} {
		    comment Remove multiple elements from shared-span list
		    perf measure [lremove_describe shared-span $len [list 0 1 [expr {$len/2}] end-1 end] 5] {
			lremove $Lspan 0 1 [expr {$len/2}] end-1 end
		    } [list len $len]
		}
	    }
	}

	perf destroy
    }

    proc lreplace_describe {share_mode len first last ninsert {times 1}} {
	if {$last < $first} {
	    return "lreplace L\[$len\] $share_mode 0 ($first:$last) elems at $first with $ninsert elems $times times."
	}
	return "lreplace L\[$len\] $share_mode $first:$last with $ninsert elems $times times."
    }
    proc lreplace_perf {} {
	variable Lengths

	print_separator lreplace

	set default_reps 10000
	ListPerf create perf -reps $default_reps

	foreach share_mode {shared unshared} {
	    # Insert only
	    foreach len $Lengths {
		set reps [expr {$len <= 100 ? ($len-2) : ($len/8)}]
		foreach first [list 0 1 [expr {$len/2}] end-1 end] {
		    if {$share_mode eq "shared"} {
			comment Insert one to shared list
			perf measure [lreplace_describe shared $len $first -1 1] {
			    lreplace $L $first -1 x
			} [list len $len first $first]

			comment Insert multiple to shared list
			perf measure [lreplace_describe shared $len $first -1 10] {
			    lreplace $L $first -1 X X X X X X X X X X
			} [list len $len first $first]

			comment Insert one to shared list repeatedly
			perf measure [lreplace_describe shared $len $first -1 1 $reps] {
			    set L [lreplace $L $first -1 x]
			} [list len $len first $first] -reps $reps

			comment Insert multiple to shared list repeatedly
			perf measure [lreplace_describe shared $len $first -1 10 $reps] {
			    set L [lreplace $L $first -1 X X X X X X X X X X]
			} [list len $len first $first] -reps $reps

		    } else {
			comment Insert one to unshared list
			perf measure [lreplace_describe unshared $len $first -1 1] {
			    set L [lreplace $L[set L {}] $first -1 x]
			} [list len $len first $first] -overhead {
			    set L $L; set L {}
			} -reps $reps

			comment Insert multiple to unshared list
			perf measure [lreplace_describe unshared $len $first -1 10] {
			    set L [lreplace $L[set L {}] $first -1 X X X X X X X X X X]
			} [list len $len first $first] -overhead {
			    set L $L; set L {}
			} -reps $reps
		    }
		}
	    }

	    # Delete only
	    foreach len $Lengths {
		set reps [expr {$len <= 100 ? ($len-2) : ($len/8)}]
		foreach first [list 0 1 [expr {$len/2}] end-1 end] {
		    if {$share_mode eq "shared"} {
			comment Delete one from shared list
			perf measure [lreplace_describe shared $len $first $first 0] {
			    lreplace $L $first $first
			} [list len $len first $first]
		    } else {
			comment Delete one from unshared list
			perf measure [lreplace_describe unshared $len $first $first 0] {
			    set L [lreplace $L[set L {}] $first $first x]
			} [list len $len first $first] -overhead {
			    set L $L; set L {}
			} -reps $reps
		    }
		}
	    }

	    # Insert + delete
	    foreach len $Lengths {
		set reps [expr {$len <= 100 ? ($len-2) : ($len/8)}]
		foreach range [list {0 1} {1 2} {end-2 end-1} {end-1 end}] {
		    lassign $range first last
		    if {$share_mode eq "shared"} {
			comment Insertions more than deletions from shared list
			perf measure [lreplace_describe shared $len $first $last 3] {
			    lreplace $L $first $last X Y Z
			} [list len $len first $first last $last]

			comment Insertions same as deletions from shared list
			perf measure [lreplace_describe shared $len $first $last 2] {
			    lreplace $L $first $last X Y
			} [list len $len first $first last $last]

			comment Insertions fewer than deletions from shared list
			perf measure [lreplace_describe shared $len $first $last 1] {
			    lreplace $L $first $last X
			} [list len $len first $first last $last]
		    } else {
			comment Insertions more than deletions from unshared list
			perf measure [lreplace_describe unshared $len $first $last 3] {
			    set L [lreplace $L[set L {}] $first $last X Y Z]
			} [list len $len first $first last $last] -overhead {
			    set L $L; set L {}
			} -reps $reps

			comment Insertions same as deletions from unshared list
			perf measure [lreplace_describe unshared $len $first $last 2] {
			    set L [lreplace $L[set L {}] $first $last X Y ]
			} [list len $len first $first last $last] -overhead {
			    set L $L; set L {}
			} -reps $reps

			comment Insertions fewer than deletions from unshared list
			perf measure [lreplace_describe unshared $len $first $last 1] {
			    set L [lreplace $L[set L {}] $first $last X]
			} [list len $len first $first last $last] -overhead {
			    set L $L; set L {}
			} -reps $reps
		    }
		}
	    }
	    # Spanned Insert + delete
	    foreach len $Lengths {
		set reps [expr {$len <= 100 ? ($len-2) : ($len/8)}]
		foreach range [list {0 1} {1 2} {end-2 end-1} {end-1 end}] {
		    lassign $range first last
		    if {$share_mode eq "shared"} {
			comment Insertions more than deletions from shared-span list
			perf measure [lreplace_describe shared-span $len $first $last 3] {
			    lreplace $Lspan $first $last X Y Z
			} [list len $len first $first last $last]

			comment Insertions same as deletions from shared-span list
			perf measure [lreplace_describe shared-span $len $first $last 2] {
			    lreplace $Lspan $first $last X Y
			} [list len $len first $first last $last]

			comment Insertions fewer than deletions from shared-span list
			perf measure [lreplace_describe shared-span $len $first $last 1] {
			    lreplace $Lspan $first $last X
			} [list len $len first $first last $last]
		    } else {
			comment Insertions more than deletions from unshared-span list
			perf measure [lreplace_describe unshared-span $len $first $last 3] {
			    set Lspan [lreplace $Lspan[set Lspan {}] $first $last X Y Z]
			} [list len $len first $first last $last] -overhead {
			    set Lspan $Lspan; set Lspan {}
			} -reps $reps

			comment Insertions same as deletions from unshared-span list
			perf measure [lreplace_describe unshared-span $len $first $last 2] {
			    set Lspan [lreplace $Lspan[set Lspan {}] $first $last X Y ]
			} [list len $len first $first last $last] -overhead {
			    set Lspan $Lspan; set Lspan {}
			} -reps $reps

			comment Insertions fewer than deletions from unshared-span list
			perf measure [lreplace_describe unshared-span $len $first $last 1] {
			    set Lspan [lreplace $Lspan[set Lspan {}] $first $last X]
			} [list len $len first $first last $last] -overhead {
			    set Lspan $Lspan; set Lspan {}
			} -reps $reps
		    }
		}
	    }
	}

	perf destroy
    }

    proc split_describe {len} {
	return "split L\[$len\]"
    }
    proc split_perf {} {
	variable Lengths
	print_separator split

	ListPerf create perf -setup {set S [string repeat "x " $len]}
	foreach len $Lengths {
	    comment Split a string
	    perf measure [split_describe $len] {
		split $S " "
	    } [list len $len]
	}
    }

    proc join_describe {share_mode len} {
	return "join L\[$len\] $share_mode"
    }
    proc join_perf {} {
	variable Lengths

	print_separator join

	ListPerf create perf -reps 10000
	foreach len $Lengths {
	    comment Join a list
	    perf measure [join_describe shared $len] {
		join $L
	    } [list len $len]
	}
	foreach len $Lengths {
	    comment Join a spanned list
	    perf measure [join_describe shared-span $len] {
		join $Lspan
	    } [list len $len]
	}
	perf destroy
    }

    proc lsearch_describe {share_mode len} {
	return "lsearch L\[$len\] $share_mode"
    }
    proc lsearch_perf {} {
	variable Lengths

	print_separator lsearch

	ListPerf create perf -reps 100000
	foreach len $Lengths {
	    comment Search a list
	    perf measure [lsearch_describe shared $len] {
		lsearch $L needle
	    } [list len $len]
	}
	foreach len $Lengths {
	    comment Search a spanned list
	    perf measure [lsearch_describe shared-span $len] {
		lsearch $Lspan needle
	    } [list len $len]
	}
	perf destroy
    }

    proc foreach_describe {share_mode len} {
	return "foreach L\[$len\] $share_mode"
    }
    proc foreach_perf {} {
	variable Lengths

	print_separator foreach

	ListPerf create perf -reps 10000
	foreach len $Lengths {
	    comment Iterate through a list
	    perf measure [foreach_describe shared $len] {
		foreach e $L {}
	    } [list len $len]
	}
	foreach len $Lengths {
	    comment Iterate a spanned list
	    perf measure [foreach_describe shared-span $len] {
		foreach e $Lspan {}
	    } [list len $len]
	}
	perf destroy
    }

    proc lmap_describe {share_mode len} {
	return "lmap L\[$len\] $share_mode"
    }
    proc lmap_perf {} {
	variable Lengths

	print_separator lmap

	ListPerf create perf -reps 10000
	foreach len $Lengths {
	    comment Iterate through a list
	    perf measure [lmap_describe shared $len] {
		lmap e $L {}
	    } [list len $len]
	}
	foreach len $Lengths {
	    comment Iterate a spanned list
	    perf measure [lmap_describe shared-span $len] {
		lmap e $Lspan {}
	    } [list len $len]
	}
	perf destroy
    }

    proc get_sort_sample {{spanned 0}} {
	variable perfScript
	variable sortSampleText

	if {![info exists sortSampleText]} {
	    set fd [open $perfScript]
	    set sortSampleText [split [read $fd] ""]
	    close $fd
	}
	set sortSampleText [string range $sortSampleText 0 9999]

	# NOTE: do NOT cache list result in a variable as we need it unshared
	if {$spanned} {
	    return [lrange [split $sortSampleText ""] 1 end-1]
	} else {
	    return [split $sortSampleText ""]
	}
    }
    proc lsort_describe {share_mode len} {
	return "lsort L\[$len] $share_mode"
    }
    proc lsort_perf {} {
	print_separator lsort

	ListPerf create perf -setup {}

	comment Sort a shared list
	perf measure [lsort_describe shared [llength [perf::list::get_sort_sample]]] {
	    lsort $L
	} {} -setup {set L [perf::list::get_sort_sample]}

	comment Sort a shared-span list
	perf measure [lsort_describe shared-span [llength [perf::list::get_sort_sample 1]]] {
	    lsort $L
	} {} -setup {set L [perf::list::get_sort_sample 1]}

	comment Sort an unshared list
	perf measure [lsort_describe unshared [llength [perf::list::get_sort_sample]]] {
	    lsort [perf::list::get_sort_sample]
	} {} -overhead {perf::list::get_sort_sample}

	comment Sort an unshared-span list
	perf measure [lsort_describe unshared-span [llength [perf::list::get_sort_sample 1]]] {
	    lsort [perf::list::get_sort_sample 1]
	} {} -overhead {perf::list::get_sort_sample 1}

	perf destroy
    }

    proc concat_describe {canonicality len elemlen} {
	return "concat L\[$len\] $canonicality with elements of length $elemlen"
    }
    proc concat_perf {} {
	variable Lengths

	print_separator concat

	ListPerf create perf -reps 100000

	foreach len $Lengths {
	    foreach elemlen {1 100} {
		comment Pure lists (no string representation)
		perf measure [concat_describe "pure lists" $len $elemlen] {
		    concat $L $L
		} [list len $len elemlen $elemlen] -setup {
		    set L [lrepeat $len [string repeat a $elemlen]]
		}

		comment Canonical lists (with string representation)
		perf measure [concat_describe "canonical lists" $len $elemlen] {
		    concat $L $L
		} [list len $len elemlen $elemlen] -setup {
		    set L [lrepeat $len [string repeat a $elemlen]]
		    append x x $L; # Generate string while keeping internal rep list
		    unset x
		}

		comment Non-canonical lists
		perf measure [concat_describe "non-canonical lists" $len $elemlen] {
		    concat $L $L
		} [list len $len elemlen $elemlen] -setup {
		    set L [string repeat "[string repeat a $elemlen] " $len]
		    llength $L
		}
	    }
	}

	# Span version
	foreach len $Lengths {
	    foreach elemlen {1 100} {
		comment Pure span lists (no string representation)
		perf measure [concat_describe "pure spanned lists" $len $elemlen] {
		    concat $L $L
		} [list len $len elemlen $elemlen] -setup {
		    set L [lrange [lrepeat [expr {$len+2}] [string repeat a $elemlen]] 1 end-1]
		}

		comment Canonical span lists (with string representation)
		perf measure [concat_describe "canonical spanned lists" $len $elemlen] {
		    concat $L $L
		} [list len $len elemlen $elemlen] -setup {
		    set L [lrange [lrepeat [expr {$len+2}] [string repeat a $elemlen]] 1 end-1]
		    append x x $L; # Generate string while keeping internal rep list
		    unset x
		}
	    }
	}

	perf destroy
    }

    proc test {} {
	variable RunTimes
	variable Options

	set selections [perf::list::setup $::argv]
	if {[llength $selections] == 0} {
	    set commands [info commands ::perf::list::*_perf]
	} else {
	    set commands [lmap sel $selections {
		if {$sel eq "help"} {
		    print_usage
		    exit 0
		}
		set cmd ::perf::list::${sel}_perf
		if {$cmd ni [info commands ::perf::list::*_perf]} {
		    puts stderr "Error: command $sel is not known or supported. Skipping."
		    continue
		}
		set cmd
	    }]
	}
	comment Setting up
	timerate -calibrate {}
	if {[info exists Options(--label)]} {
	    print "L $Options(--label)"
	}
	print "V [info patchlevel]"
	print "E [info nameofexecutable]"
	if {[info exists Options(--description)]} {
	    print "D $Options(--description)"
	}
	set twapi_keys {-privatebytes -workingset -workingsetpeak}
	if {[info commands ::twapi::get_process_memory_info] ne ""} {
	    set twapi_vm_pre [::twapi::get_process_memory_info]
	}
	foreach cmd [lsort -dictionary $commands] {
	    set RunTimes(command) 0.0
	    $cmd
	    set RunTimes(total) [expr {$RunTimes(total)+$RunTimes(command)}]
	    print "P [format_timings $RunTimes(command) 1] [string range $cmd 14 end-5] total run time"
	}
	# Print total runtime in same format as timerate output
	print "P [format_timings $RunTimes(total) 1] Total run time"

	if {[info exists twapi_vm_pre]} {
	    set twapi_vm_post [::twapi::get_process_memory_info]
	    set MB 1048576.0
	    foreach key $twapi_keys {
		set pre [expr {[dict get $twapi_vm_pre $key]/$MB}]
		set post [expr {[dict get $twapi_vm_post $key]/$MB}]
		print "P [format_timings $pre 1] Memory (MB) $key pre-test"
		print "P [format_timings $post 1] Memory (MB) $key post-test"
		print "P [format_timings [expr {$post-$pre}] 1] Memory (MB) delta $key"
	    }
	}
	if {[info commands memory] ne ""} {
	    foreach line [split [memory info] \n] {
		if {$line eq ""} continue
		set line [split $line]
		set val [expr {[lindex $line end]/1000.0}]
		set line [string trim [join [lrange $line 0 end-1]]]
		print "P [format_timings $val 1] memdbg $line (in thousands)"
	    }
	    print "# Allocations not freed on exit written to the lost-memory.tmp file."
	    print "# These will have to be manually compared."
	    # env TCL_FINALIZE_ON_EXIT must be set to 1 for this.
	    # DO NOT SET HERE - set ::env(TCL_FINALIZE_ON_EXIT) 1
	    # Must be set in environment before starting tclsh else bogus results
	    if {[info exists Options(--label)]} {
		set dump_file list-memory-$Options(--label).memdmp
	    } else {
		set dump_file list-memory-[pid].memdmp
	    }
	    memory onexit $dump_file
	}
    }
}


if {[info exists ::argv0] && [file tail $::argv0] eq [file tail [info script]]} {
    ::perf::list::test
}
