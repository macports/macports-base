## 
## This is the file `pkgIndex.tcl',
## generated with the SAK utility
## (sak docstrip/regen).
## 
## The original source files were:
## 
## tcldocstrip.dtx  (with options: `idx')
## 
## In other words:
## **************************************
## * This Source is not the True Source *
## **************************************
## the true source is the file from which this one was generated.
##
if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded docstrip 1.2\
  [list source [file join $dir docstrip.tcl]]
package ifneeded docstrip::util 1.3.1\
  [list source [file join $dir docstrip_util.tcl]]
## 
## 
## End of file `pkgIndex.tcl'.