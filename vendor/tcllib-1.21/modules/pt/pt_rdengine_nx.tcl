# -*- tcl -*-
#
# Copyright (c) 2016-2018 by Stefan Sobernig <stefan.sobernig@wu.ac.at>

# # ## ### ##### ######## ############# #####################
## Package description

## An NX implementation of the PackRat Machine (PARAM), a virtual
## machine on top of which parsers for Parsing Expression Grammars
## (PEGs) can be realized. This implementation is tied to the PARAM's
## TclOO implementation and it is automatically derived from the
## corresponding TclOO class (pt::rde::oo) upon loading the package.

# # ## ### ##### ######## ############# #####################
## Requisites

package require pt::rde::oo
package req nx

namespace eval ::pt::rde {

  ##
  ## Helper: An NX metaclass and class generator, which allows for
  ## deriving an NX class from the ::pt::rde::oo class.
  ##
  
  nx::Class create ClassFactory -superclass nx::Class {
    :property prototype:required

    :method mkMethod {name vars params body tmpl} {
      set objVars [list]
      set debugObjVars [list]
      foreach v $vars {
        if {[string first $v $body] > -1} {
          lappend objVars :$v $v
        } else {
          lappend debugObjVars :$v $v
        }
      }
      
      if {[llength $objVars]} {
        set objVars [list upvar 0 {*}$objVars]
      }

      if {[llength $debugObjVars]} {
        set debugObjVars [list debug.pt/rdengine \
                              "\[[list upvar 0 {*}$debugObjVars]\]"]
      }

      set mappings [list @body@ $body @objVars@ $objVars \
                        @debugObjVars@ $debugObjVars @params@ $params]
      
      set finalBody [string map $mappings $tmpl]

      :method $name $params $finalBody
      
    }; # mkMethod
    
    :method init {args} {

      namespace eval [namespace qualifier [self]] {
        namespace import ::nsf::my
      }

      :method debugPrep {cls} {
        :object method TraceInitialization [list [list cls $cls]] {
          set mh [$cls info methods -callprotection all TraceInitialization]
          if {$mh ne ""} {
            set script [$cls info method body $mh]
            apply [list {} $script [self]]
          }
        }
        return
      }

      :method debugOn {} {
        interp alias {} [namespace current]::Instruction {} [self]::Instruction
        interp alias {} [namespace current]::InstReturn {} [self]::InstReturn
        interp alias {} [namespace current]::State {} [self]::State
        interp alias {} [namespace current]::TraceSetupStacks {} [self]::TraceSetupStacks
        return
      }

      :method debugOff {} {
        interp alias {} [namespace current]::Instruction {} 
        interp alias {} [namespace current]::InstReturn {} 
        interp alias {} [namespace current]::State {} 
        interp alias {} [namespace current]::TraceSetupStacks {}
        return
      }

      set vars [info class variables ${:prototype}]
      
      ## clone constructor
      lassign [info class constructor ${:prototype}] ctorParams ctorBody

      :mkMethod init $vars $ctorParams $ctorBody {
        debug.pt/rdengine {[:debugPrep [current class]][self] TraceInitialization indirection}
        :require namespace;
        apply [list {} {
          namespace import ::nsf::my
          @objVars@
          @body@
        } [self]]
        
        debug.pt/rdengine {[:debugOn][self] DebugCmd indirection on}
      }

      :public method destroy {args} {
        debug.pt/rdengine {[:debugOff][self] DebugCmd indirection off}
        next
      }

      ## clone all methods
      foreach m [info class methods ${:prototype} -private] {
        lassign [info class definition ${:prototype} $m] params body

        :mkMethod $m $vars $params $body {
          @objVars@
          @debugObjVars@
          @body@
        }
      }
      
      return
    }; # init
  }; # ClassFactory

  ##
  ## ::pt::rde::nx:
  ##
  ## The NX derivative of ::pt::rde::oo, to be inherited
  ## by the generated grammar class.
  ##
  
  ClassFactory create nx -prototype ::pt::rde::oo

  namespace export nx
}

package provide pt::rde::nx [package req pt::rde::oo].1.1

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:

