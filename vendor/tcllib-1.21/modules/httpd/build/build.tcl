set srcdir [file dirname [file normalize [file join [pwd] [info script]]]]
set moddir [file dirname $srcdir]

if {[file exists [file join $moddir .. .. scripts practcl.tcl]]} {
  source [file join $moddir .. .. scripts practcl.tcl]
} elseif {[file exists [file join $moddir .. practcl build doctool.tcl]]} {
  source [file join $moddir .. practcl build doctool.tcl]
} else {
  package require practcl 0.14
}

::practcl::doctool create AutoDoc
set version 4.3.5
set tclversion 8.6
set module [file tail $moddir]
set filename $module

set fout [open [file join $moddir ${filename}.tcl] w]
dict set modmap  %module% $module
dict set modmap  %version% $version
dict set modmap  %tclversion% $tclversion
dict set modmap  %filename% $filename

puts $fout [string map $modmap {###
# Amalgamated package for %module%
# Do not edit directly, tweak the source in src/ and rerun
# build.tcl
###
package require Tcl %tclversion%
package provide %module% %version%
namespace eval ::%module% {}
set ::%module%::version %version%}]

# Track what files we have included so far
set loaded {}
lappend loaded build.tcl cgi.tcl
# These files must be loaded in a particular order
foreach {file} {
  core.tcl
  reply.tcl
  server.tcl
  dispatch.tcl
  file.tcl
  proxy.tcl
  cgi.tcl
  scgi.tcl
  websocket.tcl
  plugin.tcl
} {
  lappend loaded $file
  puts $fout "###\n# START: [file tail $file]\n###"
  set content [::practcl::cat [file join $srcdir $file]]
  AutoDoc scan_text $content
  puts $fout [::practcl::docstrip $content]
  puts $fout "###\n# END: [file tail $file]\n###"
}
# These files can be loaded in any order
foreach file [glob [file join $srcdir *.tcl]] {
  if {[file tail $file] in $loaded} continue
  lappend loaded $file
  set fin [open [file join $srcdir $file] r]
  puts $fout "###\n# START: [file tail $file]\n###"
  set content [::practcl::cat [file join $srcdir $file]]
  AutoDoc scan_text $content
  puts $fout [::practcl::docstrip $content]
  puts $fout "###\n# END: [file tail $file]\n###"
}

# Provide some cleanup and our final package provide
puts $fout [string map $modmap {
    namespace eval ::%module% {
	namespace export *
    }
}]
close $fout

###
# Build our pkgIndex.tcl file
###
set fout [open [file join $moddir pkgIndex.tcl] w]
puts $fout [string map $modmap {
if {![package vsatisfies [package provide Tcl] %tclversion%]} {return}
package ifneeded %module% %version% [list source [file join $dir %module%.tcl]]
}]
close $fout

set manout [open [file join $moddir $filename.man] w]
puts $manout [AutoDoc manpage map $modmap \
  header [::practcl::cat [file join $srcdir manual.txt]] \
  footer [::practcl::cat [file join $srcdir footer.txt]] \
]
close $manout
