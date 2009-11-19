# et:ts=4
# porttest.tcl
# $Id$

package provide porttest 1.0
package require portutil 1.0

set org.macports.test [target_new org.macports.test porttest::test_main]
target_provides ${org.macports.test} test
if {[option portarchivemode] == "yes"} {
target_requires ${org.macports.test} main unarchive fetch extract checksum patch configure build
} else {
    target_requires ${org.macports.test} main fetch extract checksum patch configure build
}
target_prerun ${org.macports.test} porttest::test_start

namespace eval porttest {
}

# define options
options test.run test.target
commands test

# Set defaults
default test.dir {${build.dir}}
default test.cmd {${build.cmd}}
default test.pre_args {${test.target}}
default test.target test

set_ui_prefix

proc porttest::test_start {args} {
    global UI_PREFIX name
    ui_msg "$UI_PREFIX [format [msgcat::mc "Testing %s"] ${name}]"
}

proc porttest::test_main {args} {
    global name test.run
    if {[tbool test.run]} {
        command_exec test
    } else {
    return -code error [format [msgcat::mc "%s has no tests turned on. see 'test.run' in portfile(7)"] $name]
    }
    return 0
}
