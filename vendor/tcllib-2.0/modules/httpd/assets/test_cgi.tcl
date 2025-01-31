#!/usr/bin/tclsh

puts stdout "Status: 200 OK"
if {$::env(CONTENT_LENGTH) > 0} {
  puts stdout "Content-Type: $::env(CONTENT_TYPE)"
  set dat [read stdin $::env(CONTENT_LENGTH)]
} else {
  puts stdout "Content-Type: text/plain"
  set dat "Hi!"
}
puts stdout "Content-Length: [string length $dat]"
puts stdout {}
puts stdout $dat
exit 0
