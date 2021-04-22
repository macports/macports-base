package require practcl

::practcl::library create HELLO {
  name hello
  version 0.1
}
set mod [HELLO add class module]
$mod define set loader-funct HelloWorld_Init
$mod add hellocmd.tcl
$mod add helloclass.tcl
$mod add hellotype.tcl

HELLO go
$mod go
puts "***\nTCL LOADER:\n***"
puts [$mod generate-tcl]
puts "***\nPublic H file\n***"
puts [$mod generate-h]
puts "***\nC implementation\n***"
puts [$mod generate-c]
