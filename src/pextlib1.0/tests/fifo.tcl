# Test file for Pextlib's mkfifo.
# Requires r/w access to /tmp/
# Syntax:
# tclsh mkfifo.tcl <Pextlib name>

proc main {pextlibname} {
	load $pextlibname
	
	set fifo_path "/tmp/darwinports-pextlib-fifo"
	
	file delete -force $fifo_path

	# Create the named pipe.
	mkfifo $fifo_path 0700
	
	# Check it exists.
	if {![file exists $fifo_path]} {
		puts {![file exists $fifo_path]}
		exit 1
	}

	# Check it's a fifo.
	if {[file type $fifo_path] != "fifo"} {
		puts {[file type $fifo_path] != "fifo"}
		exit 1
	}

	file delete -force $fifo_path
}

main $argv