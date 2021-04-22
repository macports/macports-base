# # ## ### ##### ######## ############# ####################
## -*- tcl -*-
## (C) 2011-2015 Andreas Kupries, BSD licensed.

# # ## ### ##### ######## ############# ####################
## Requisites

package require Tcl 8.5
package require TclOO

# # ## ### ##### ######## ############# #####################
## Public API implementation

# # ## ### ##### ######## ############# ####################
## Easy callback support.
## http://wiki.tcl.tk/21595. v20, Donal Fellows

proc ::oo::Helpers::mymethod {method args} {
    list [uplevel 1 {namespace which my}] $method {*}$args
}

# # ## ### ##### ######## ############# ####################
## Class variable support. Use within instance methods.
## No use in class definitions.
## http://wiki.tcl.tk/21595. v63, Donal Fellows, tweaked name, comments

proc ::oo::Helpers::classvariable {name args} {
    # Get a reference to the class's namespace
    set ns [info object namespace [uplevel 1 {self class}]]

    # Double up the list of variable names
    set vs [list $name $name]
    foreach v $args {lappend vs $v $v}

    # Lastly, link the caller's local variables to the class's
    # variables
    uplevel 1 [list namespace upvar $ns {*}$vs]
}

#==================================
# Demonstration
#==================================
# % oo::class create Foo {
#     method bar {z} {
#         classvar x y
#         return [incr x $z],[incr y]
#     }
# }
# ::Foo
# % Foo create a
# ::a
# % Foo create b
# ::b
# % a bar 2
# 2,1
# % a bar 3
# 5,2
# % b bar 7
# 12,3
# % b bar -1
# 11,4
# % a bar 0
# 11,5

# # ## ### ##### ######## ############# ####################
## Class method support, with access in derived classes
## http://wiki.tcl.tk/21595. v63, Donal Fellows

proc ::oo::define::classmethod {name {args ""} {body ""}} {
    # Create the method on the class if the caller gave arguments and body
    set argc [llength [info level 0]]
    if {$argc == 3} {
        return -code error "wrong # args: should be \"[lindex [info level 0] 0] name ?args body?\""
    }

    # Get the name of the current class or class delegate 
    set cls [namespace which [lindex [info level -1] 1]]
    set d $cls.Delegate
    if {[info object isa object $d] && [info object isa class $d]} {
        set cls $d
    }

    if {$argc == 4} {
        oo::define $cls method $name $args $body
    }

    # Make the connection by forwarding
    uplevel 1 [list forward $name [info object namespace $cls]::my $name]
}

# Build this *almost* like a class method, but with extra care to avoid nuking
# the existing method.
oo::class create oo::class.Delegate {
    method create {name args} {
        if {![string match ::* $name]} {
            set ns [uplevel 1 {namespace current}]
            if {$ns eq "::"} {set ns ""}
            set name ${ns}::${name}
        }
        if {[string match *.Delegate $name]} {
            return [next $name {*}$args]
        }
        set delegate [oo::class create $name.Delegate]
        set cls [next $name {*}$args]
        set superdelegates [list $delegate]
        foreach c [info class superclass $cls] {
            set d $c.Delegate
            if {[info object isa object $d] && [info object isa class $d]} {
                lappend superdelegates $d
            }
        }
        oo::objdefine $cls mixin {*}$superdelegates
        return $cls
    }
}

oo::define oo::class self mixin oo::class.Delegate

# Demonstrating…
# ======
# oo::class create ActiveRecord {
#     classmethod find args { puts "[self] called with arguments: $args" }
# }
# oo::class create Table {
#     superclass ActiveRecord
# }
# Table find foo bar
# ======
# which will write this out (I tested it):
# ======none
# ::Table called with arguments: foo bar
# ======

# # ## ### ##### ######## ############# ####################
## Singleton Metaclass
## http://wiki.tcl.tk/21595. v63, Donal Fellows

oo::class create ooutil::singleton {
   superclass oo::class
   variable object
   method create {name args} {
      if {![info exists object]} {
         set object [next $name {*}$args]
      }
      return $object
   }
   method new args {
      if {![info exists object]} {
         set object [next {*}$args]
      }
      return $object
   }
}

# ======
# Demonstration
# ======
# % oo::class create example {
#    self mixin singleton
#    method foo {} {self}
# }
# ::example
# % [example new] foo
# ::oo::Obj22
# % [example new] foo
# ::oo::Obj22

# # ## ### ##### ######## ############# ####################
## Linking instance methods into instance namespace for access without 'my'
## http://wiki.tcl.tk/27999, AK

proc ::oo::Helpers::link {args} {
    set ns [uplevel 1 {namespace current}]
    foreach link $args {
	if {[llength $link] == 2} {
	    lassign $link src dst
	} else {
	    lassign $link src
	    set dst $src
	}
	interp alias {} ${ns}::$src {} ${ns}::my $dst
    }
    return
}

# # ## ### ##### ######## ############# ####################
## Ready

package provide oo::util 1.2.2
