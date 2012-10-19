load ../machista.dylib

if {$argc < 1} {
	puts "Usage: $argv0 filename"
	exit 1
}
set h [machista::create_handle]
machista::destroy_handle $h

