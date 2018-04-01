package require tcltest 2
package require lambda
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl
set path [file dirname [file normalize $argv0]]

initial_setup

customMatch notGlob [lambda {needle haystack} {
	puts "string match -nocase $needle"
	if {[string match -nocase $needle $haystack]} {
		return 0
	}
	return 1
}]

test svn-patchsites {
    Regression test for svn-and-patchsites.
} -body {
	return [exec -ignorestderr cat $path/$output_file]
} -result "error*" -match notGlob


cleanup
cleanupTests
