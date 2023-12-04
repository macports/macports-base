proc ui_warn {msg} {
	global warnings
	lappend warnings $msg
}

proc slave_add_sandbox_violation {path} {
	global violations
	lappend violations $path
}

proc slave_add_sandbox_unknown {path} {
	global unknowns
	lappend unknowns $path
}

proc setup {fifo} {
    package require Pextlib 1.0
    global warnings violations unknowns

    set warnings [list]
    set violations [list]
    set unknowns [list]

    tracelib setname $fifo
    tracelib opensocket
}

proc run {} {
	tracelib run
}

proc cleanup {} {
	thread::unwind
}

thread::wait
