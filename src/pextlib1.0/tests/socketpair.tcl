# Test file for Pextlib's unixsocketpair and mkchannelfromfd.
# Syntax:
# tclsh socketpair.tcl <Pextlib name>

proc main {pextlibname} {
	load $pextlibname

	# Create a socket pair.
	set pair [unixsocketpair]
	
	# Create the two channels.
	set channel1 [mkchannelfromfd [lindex $pair 0] r]
	set channel0 [mkchannelfromfd [lindex $pair 1] w]
	
	# Create a fileevent on channel 1
	fileevent $channel1 readable [list read1 $channel1]
	
	# Define the list of what we are going to write in it.
	global buffer bufferWasEmptied
	set buffer [list hello world]
	
	# Write that stuff.
	foreach word $buffer {
		puts $channel0 $word
		flush $channel0
	}
	
	# Wait for that stuff to have been read.
	vwait bufferWasEmptied
}

proc read1 {chan} {
	global buffer bufferWasEmptied
	if {![eof $chan]} {
		set line [gets $chan]
		set expected [lindex $buffer 0]
		if {$line != $expected} {
			puts {$line != $expected}
			exit 1
		}
		set buffer [lreplace $buffer 0 0]
		if {$buffer == {}} {
			set bufferWasEmptied 1
		}
	} else {
		puts "EOF!"
		exit 1
	}
}

main $argv
