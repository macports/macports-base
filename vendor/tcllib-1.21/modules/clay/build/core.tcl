package require Tcl 8.6 ;# try in pipeline.tcl. Possibly other things.
if {[info commands irmmd5] eq {}} {
  if {[catch {package require odielibc}]} {
    package require md5 2
  }
}
::namespace eval ::clay {}
::namespace eval ::clay::classes {}
::namespace eval ::clay::define {}
::namespace eval ::clay::tree {}
::namespace eval ::clay::dict {}
::namespace eval ::clay::list {}
::namespace eval ::clay::uuid {}

if {![info exists ::clay::idle_destroy]} {
  set ::clay::idle_destroy {}
}

