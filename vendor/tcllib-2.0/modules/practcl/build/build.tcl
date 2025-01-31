set srcdir [file dirname [file normalize [file join [pwd] [info script]]]]
set moddir [file dirname $srcdir]
source [file join $srcdir doctool.tcl]

::practcl::doctool create AutoDoc

set version 0.16.4
set tclversion 8.6
set module [file tail $moddir]
set filename $module

set fout [open [file join $moddir $filename.tcl] w]
fconfigure $fout -translation lf
dict set modmap %module% $module
dict set modmap %version% $version
dict set modmap %tclversion% $tclversion
#dict set modmap {    } {}
#dict set modmap "\t" {    }

puts $fout [string map $modmap {###
# Amalgamated package for %module%
# Do not edit directly, tweak the source in src/ and rerun
# build.tcl
###
package require Tcl %tclversion%
package provide %module% %version%
namespace eval ::%module% {}
}]

# Track what files we have included so far
set loaded {}
# These files must be loaded in a particular order

###
# Load other module code that this module will need
###
foreach {omod files} {
  httpwget wget.tcl
  clay {clay.tcl}
} {
  foreach fname $files {
    set file [file join $moddir .. $omod $fname]
    puts $fout "###\n# START: [file join $omod $fname]\n###"
    set content [::practcl::cat [file join $moddir .. $omod $fname]]
    #AutoDoc scan_text $content
    puts $fout [::practcl::docstrip $content]
    puts $fout "###\n# END: [file join $omod $fname]\n###"
  }
}

foreach {file} {
  setup.tcl
  doctool.tcl
  buildutil.tcl
  fileutil.tcl
  installutil.tcl
  makeutil.tcl
  {class metaclass.tcl}

  {class toolset baseclass.tcl}
  {class toolset gcc.tcl}
  {class toolset msvc.tcl}

  {class target.tcl}
  {class object.tcl}
  {class dynamic.tcl}
  {class product.tcl}
  {class module.tcl}

  {class project baseclass.tcl}
  {class project library.tcl}
  {class project tclkit.tcl}

  {class distro baseclass.tcl}
  {class distro snapshot.tcl}
  {class distro fossil.tcl}
  {class distro git.tcl}

  {class subproject baseclass.tcl}
  {class subproject binary.tcl}
  {class subproject core.tcl}

  {class tool.tcl}

} {
  lappend loaded $file
  puts $fout "###\n# START: [file join $file]\n###"
  set content [::practcl::cat [file join $srcdir {*}$file]]
  AutoDoc scan_text $content
  puts $fout [::practcl::docstrip $content]
  puts $fout "###\n# END: [file join $file]\n###"
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
fconfigure $fout -translation lf
puts $fout [string map $modmap {###
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

