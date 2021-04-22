# The switched class (for the stooop object oriented extension)
#
# Copyright (c) 2001 by Jean-Luc Fontaine <jfontain@free.fr>.
# This code may be distributed under the same terms as Tcl.
#
# $Id: switched.tcl,v 1.5 2006/09/19 23:36:18 andreas_kupries Exp $

package require stooop
package provide switched 2.2.1


::stooop::class switched {

    proc switched {this args} {            ;# arguments are option / value pairs
        if {([llength $args]%2)!=0} {
            error "value for \"[lindex $args end]\" missing"
        }
        set ($this,complete) 0
        # delay arguments processing till completion as pure virtual procedure
        # invocations do not work from base class constructor
        set ($this,arguments) $args
    }

    proc ~switched {this} {}

    # derived class implementation must return a list of
    # {name "default value" "initial value"} lists
    ::stooop::virtual proc options {this}

    # must be invoked once only at the end of derived class constructor so that
    # configuration occurs once derived object is completely built:
    proc complete {this} {
        foreach description [options $this] {
            set option [lindex $description 0]
            # by default always set option to default value:
            set ($this,$option) [set default [lindex $description 1]]
            if {[llength $description]<3} {
                # no initial value so force initialization with default value
                set initialize($option) {}
            } elseif {![string equal $default [lindex $description 2]]} {
                set ($this,$option) [lindex $description 2]
                # initial value different from default value so force
                # initialization
                set initialize($option) {}
            }
        }
        # check validity of constructor options, which always take precedence
        # for initialization
        foreach {option value} $($this,arguments) {
            if {[catch {string compare $($this,$option) $value} different]} {
                error "$($this,_derived): unknown option \"$option\""
            }
            if {$different} {
                set ($this,$option) $value
                set initialize($option) {}
            }
        }
        unset ($this,arguments)
        # all option values are initialized before any of the set procedures are
        # called
        foreach option [array names initialize] {
            $($this,_derived)::set$option $this $($this,$option)
        }
        set ($this,complete) 1
    }

    proc configure {this args} {      ;# should not be invoked before completion
        if {[llength $args]==0} {
            return [descriptions $this]
        }
        foreach {option value} $args {
            # check all options validity before doing anything else
            if {![info exists ($this,$option)]} {
                error "$($this,_derived): unknown option \"$option\""
            }
        }
        if {[llength $args]==1} {
            return [description $this [lindex $args 0]]
        }
        if {([llength $args]%2)!=0} {
            error "value for \"[lindex $args end]\" missing"
        }
        # derived (dynamic virtual) procedure must either accept (or eventually
        # adjust) the value or throw an error
        # option data member is set prior to invoking the procedure in case
        # other procedures are invoked and expect the new value
        foreach {option value} $args {
            if {![string equal $($this,$option) $value]} {
                $($this,_derived)::set$option $this [set ($this,$option) $value]
            }
        }
    }

    proc cget {this option} {
        if {[catch {set value $($this,$option)}]} {
            error "$($this,_derived): unknown option \"$option\""
        }
        return $value                   ;# return specified option current value
    }

    proc description {this option} {  ;# build specified option description list
        foreach description [options $this] {
            if {[string equal [lindex $description 0] $option]} {
                if {[llength $description]<3} {              ;# no initial value
                    lappend description $($this,$option) ;# append current value
                    return $description
                } else {
                    # set current value:
                    return [lreplace $description 2 2 $($this,$option)]
                }
            }
        }
    }

    # build option descriptions list for all supported options:
    proc descriptions {this} {
        set descriptions {}
        foreach description [options $this] {
            if {[llength $description]<3} {                  ;# no initial value
                # append current value:
                lappend description $($this,[lindex $description 0])
                lappend descriptions $description
            } else {
                # set current value:
                lappend descriptions [lreplace\
                    $description 2 2 $($this,[lindex $description 0])\
                ]
            }
        }
        return $descriptions
    }

}
