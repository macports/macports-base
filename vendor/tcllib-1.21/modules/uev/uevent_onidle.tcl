## -*- tcl -*-
# ### ### ### ######### ######### #########

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4 ; #
package require snit    ; # 

# ### ### ### ######### ######### #########
##

snit::type uevent::onidle {
    # ### ### ### ######### ######### #########
    ## API 

    constructor {cmd} {
	set mycmd $cmd
	return
    }

    method request {} {
	if {$myhasrequest} return
	after idle [mymethod RunAction]
	set myhasrequest 1
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal commands

    method RunAction {} {
	set myhasrequest 0
	uplevel \#0 $mycmd
	return
    }

    # ### ### ### ######### ######### #########
    ## State

    variable mycmd        {} ; # Command prefix of the action to perform
    variable myhasrequest 0  ; # Boolean flag, set when the action has
    #                        ; # been requested

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide uevent::onidle 0.1
