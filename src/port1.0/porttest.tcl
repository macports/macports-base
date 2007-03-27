# et:ts=4
# porttest.tcl
# $Id$

package provide porttest 1.0
package require portutil 1.0

set com.apple.test [target_new com.apple.test test_main]
target_provides ${com.apple.test} test
target_requires ${com.apple.test} build
target_prerun ${com.apple.test} test_start

# define options
options test.run test.target 
commands test

# Set defaults
default test.dir {${build.dir}}
default test.cmd {${build.cmd}}
default test.pre_args {${test.target}}
default test.target test

set_ui_prefix

proc test_start {args} {
    global UI_PREFIX portname
    ui_msg "$UI_PREFIX [format [msgcat::mc "Testing %s"] ${portname}]"
}

proc test_main {args} {
    global portname test.run
    if {[tbool test.run]} {
    	command_exec test
    } else {
	return -code error [format [msgcat::mc "%s has no tests turned on. see 'test.run' in portfile(7)"] $portname]
    }
    return 0
}
