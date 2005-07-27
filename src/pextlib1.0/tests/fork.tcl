# Test file for Pextlib's fork, unixsocketpair and mkchannelfromfd.
# Syntax:
# tclsh fork.tcl <Pextlib name>

# fork just doesn't work on 10.4 (even TclX' fork) but actually we don't
# need it if threads are compiled in (actually, it seems to simply be
# incompatible with threads being compiled in).
# So we just skip this test if threads are in.

proc main {pextlibname} {
	load $pextlibname

	# Create a socket pair.
	set pair [unixsocketpair]
	
	# Fork.
	if {[fork] == 0} {
		# I'm the child.
		# I'll use the first element.
		set channel [mkchannelfromfd [lindex $pair 0] w]
		puts $channel "hello"
		close $channel
	} else {
		# I'm the parent.
		# I'll use the second element.
		set channel [mkchannelfromfd [lindex $pair 1] r]
		set hello [gets $channel]
		if {$hello != "hello"} {
			puts {$hello != "hello"}
			exit 1
		}
		close $channel
	}
}

if {[catch {package require Thread}]} {
	main $argv
}