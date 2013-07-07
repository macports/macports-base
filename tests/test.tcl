set test_suite {
    case-insensitive-deactivate
    checksums-1
    dependencies-a
    dependencies-b
    dependencies-c
    dependencies-d
    dependencies-e
    envvariables
    site-tags
    statefile-unknown-version
    statefile-version1
    statefile-version1-outdated
    statefile-version2
    statefile-version2-invalid
    statefile-version2-outdated
    svn-and-patchsites
    universal
    variants
    xcodeversion
}
set arguments ""
set test_name ""

proc print_help {arg} {
    if { $arg == "tests" } {
        puts "test list"
    } else {
        puts "help message"
    }
}

# Process args
foreach arg $argv {
    if { $arg == "-h" || $arg == "-help" } {
        print_help
        exit 0
    } elseif { $arg == "-debug" } {
        set index [expr [lsearch $argv $arg] + 1]
        set level [lindex $argv $index]
        if { $level >= 0 && $level <= 5 } {
            append arguments "-debug " $level
        } else {
            puts "Invalid debug level."
            exit 1
        }
    } elseif { $arg == "-t" } {
        set index [expr [lsearch $argv $arg] + 1]
        set test_name [lindex $argv $index]
        set no 0
        foreach test $test_suite {
            if { $test_name != $test } {
                set no [expr $no + 1]
            }
        }
        if { $no == [llength $test_suite] } {
            print_help tests
            exit 1
        }
    }       
}

# Run tests
if { $test_name != ""} {
    cd test/$test_name

    set result [eval exec tclsh test.tcl $arguments]
    puts $result

} else {
    foreach test $test_suite {
        cd test/$test
    
        set result [eval exec tclsh test.tcl $arguments]
        puts $result
    
        cd ../..
    }
}
