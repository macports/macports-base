# Test file for Pextlib's options.
# Syntax:
# tclsh options.tcl <Pextlib name>

proc main {pextlibname} {
	load $pextlibname
	global foo bar
	
	options foo
	foo foo
	if {${foo} != "foo"} {
		puts {${foo} != "foo"}
		exit 1
	}
	foo-append bar
	if {${foo} != "foo bar"} {
		puts {${foo} != "foo bar"}
		exit 1
	}
	foo-delete foo
	if {${foo} != "bar"} {
		puts {${foo} != "bar"}
		exit 1
	}
	foo-delete foobar
	if {${foo} != "bar"} {
		puts {${foo} != "bar" (2)}
		exit 1
	}
	foo-delete bar
	if {[info exists foo]} {
		puts {[info exists foo]}
		exit 1
	}

	options bar
	bar foo
	if {${bar} != "foo"} {
		puts {${bar} != "foo"}
		exit 1
	}	
	bar
	if {${bar} != ""} {
		puts {${bar} != ""}
		exit 1
	}	
	if {![info exists bar]} {
		puts {![info exists bar]}
		exit 1
	}
}

main $argv