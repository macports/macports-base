package require darwinports
proc ui_puts {args} {
	puts "puts: $args"
}
proc ui_event {args} {
	puts "event: $args"
}
dportinit
package require port
