package require tcltest
namespace import tcltest::*

test basic "Basic compile + go" -body {
    puts stderr "exec = [info nameofexecutable]"
    puts stderr "prog = $starkit::topdir"
}
