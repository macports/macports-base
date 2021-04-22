# # ## ### ##### ######## ############# ####################
## -*- tcl -*-
## (C) 2015 Miguel Martínez López, BSD licensed.

# The code here is a forward-compatibility implementation of Tcl 8.6's
# throw command (TIP 329), for Tcl 8.5.

# # ## ### ##### ######## ############# ####################

package provide throw 1
package require Tcl 8.5

# Do nothing if the "throw" command exists already (8.6 and higher).
if {[llength [info commands throw]]} return

proc throw {code msg} {
    return -code error -errorcode $code $msg
}
