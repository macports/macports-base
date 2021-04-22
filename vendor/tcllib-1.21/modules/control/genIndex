# Utility program to generate tclIndex file

package require Tcl 8.3
set home [file join [pwd] [file dirname [info script]]]
cd $home
set files [glob -nocomplain *.tcl]
set idx [lsearch $files control.tcl]
set files [lreplace $files $idx $idx]
set idx [lsearch $files index.tcl]
set files [lreplace $files $idx $idx]
set idx [lsearch $files pkgIndex.tcl]
set files [lreplace $files $idx $idx]
eval [list auto_mkindex .] $files
#pkg_mkIndex -direct . control.tcl

