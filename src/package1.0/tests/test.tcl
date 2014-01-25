# Global vars
set arguments ""
set test_name ""
set color_out ""
set tcl ""
set err ""

# Get tclsh path.
set autoconf ../../Mk/macports.autoconf.mk
set fp [open $autoconf r]
while {[gets $fp line] != -1} {
    if {[string match "TCLSH*" $line] != 0} {
        set tcl [lrange [split $line " "] 1 1]
    }
}

proc print_help {arg} {
    if { $arg eq "tests" } {
        puts "The list of available tests is:"
	cd tests
	set test_suite [glob *.test]
        foreach test $test_suite {
            puts [puts -nonewline "  "]$test
        }
    } else {
        puts "Usage: tclsh test.tcl \[-debug level\] \[-t test\] \[-l\]\n"
        puts "  -debug LVL : sets the level of printed debug info \[0-3\]"
        puts "  -t TEST    : run a specific test"
        puts "  -nocolor   : disable color output (for automatic testing)"
        puts "  -l         : print the list of available tests"
        puts "  -h, -help  : print this message\n"
    }
}

# Process args
foreach arg $argv {
    if { $arg eq "-h" || $arg eq "-help" } {
        print_help ""
        exit 0
    } elseif { $arg eq "-debug" } {
        set index [expr {[lsearch $argv $arg] + 1}]
        set level [lindex $argv $index]
        if { $level >= 0 && $level <= 3 } {
            append arguments "-debug " $level
        } else {
            puts "Invalid debug level."
            exit 1
        }
    } elseif { $arg eq "-t" } {
        set index [expr {[lsearch $argv $arg] + 1}]
        set test_name [lindex $argv $index]
        set no 0
	cd tests
	set test_suite [glob *.test]
        foreach test $test_suite {
            if { $test_name != $test } {
                set no [expr {$no + 1}]
            }
        }
        if { $no == [llength $test_suite] } {
            print_help tests
            exit 1
        }
    } elseif { $arg eq "-l" } {
        print_help tests
        exit 0
    } elseif { $arg eq "-nocolor" } {
        set color_out "no"
    }
}


# Run tests
if { $test_name ne ""} {
    set result [eval exec $tcl $test_name $arguments 2>@stderr]
    puts $result

} else {
    cd tests
    set test_suite [glob *.test]

    foreach test $test_suite {
        set result [eval exec $tcl $test $arguments 2>@stderr]
		set lastline [lindex [split $result "\n"] end]

	if {[lrange [split $lastline "\t"] 1 1] != "Total"} {
		if {[lrange [split $lastline "\t"] 1 1] == ""} {
			set lastline [lindex [split $result "\n"] 0]
	    	set errmsg [lindex [split $result "\n"] 2]
		} else {
	    	set lastline [lindex [split $result "\n"] end-2]
	    	set errmsg [lindex [split $result "\n"] end]
		}
	}

	set splitresult [split $lastline "\t"]
        set total [lindex $splitresult 2]
        set pass [lindex $splitresult 4]
        set skip [lindex $splitresult 6]
        set fail [lindex $splitresult 8]

	# Format output
	if {$total < 10} { set total "0${total}"}
	if {$pass < 10} { set pass "0${pass}"}
	if {$skip < 10} { set skip "0${skip}"}
	if {$fail < 10} { set fail "0${fail}"}

        # Check for errors.
        if { $fail != 0 } { set err "yes" }

        set out ""
        if { ($fail != 0 || $skip != 0) && $color_out eq "" } {
            # Color failed tests.
            append out "\x1b\[1;31mTotal:" $total " Passed:" $pass " Failed:" $fail " Skipped:" $skip "  \x1b\[0m" $test
        } else {
            append out "Total:" $total " Passed:" $pass " Failed:" $fail " Skipped:" $skip "  " $test
        }

        # Print results and constrints for auto-skipped tests.
        puts $out
        if { $skip != 0 } {
            set out "    Constraint: "
            append out [string trim $errmsg "\t {}"]
            puts $out
        }
	if { $fail != 0 } {
	    set end [expr {[string first $test $result 0] - 1}]
	    puts [string range $result 0 $end]
	}
    }
}

# Return 1 if errors were found.
if {$err ne ""} { exit 1 }

return 0
