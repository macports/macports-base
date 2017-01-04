################################################################################
#     Logger Utilities - XOTcl wrapper for logger
#     
#     A XOTcl class to wrap logger
#     
#     (c) 2005 Michael Schlenker <mic42@users.sourceforge.net>
#
#         with enhancements by Gustaf Neumann, to be more idiomatic xotcl
#
#     $Id: xotcl-logger.tcl,v 1.3 2008/05/29 19:16:03 mic42 Exp $
#
#################################################################################

package require XOTcl 1.6
package require logger

namespace eval ::logger::xotcl {
 namespace import ::xotcl::*

 ::xotcl::Class create Logger -slots {
   #
   # Define Attributes of the Logger
   #
   # Attribute servicename
   #
   Attribute loggertoken -default ""

   #
   # Attribute servicename
   #
   # When the attribute is set, perform some optional cleanup
   # and the either create a new logger service or attach to
   # an existing one
   #
   Attribute servicename \
       -default {[namespace tail [self]]} \
       -proc assign {domain var value} {
         $domain instvar loggertoken servicename loglevel

         if {$loggertoken ne ""} {
           ${loggertoken}::delete
           set loggertoken ""
         } 

         if {$value ne ""} {
           #
           # If a logging service with this name exists already,
           # attach the logger to it. Otherwise create a service
           # with the specified name
           #
           if {[lsearch -exact [logger::services] $value] == -1} {
             set loggertoken [logger::init $value]
             set servicename $value
           } else {
             set loggertoken [logger::servicecmd $value]
             set servicename $value
           }

           if {[info exists loglevel]} {
             ${loggertoken}::setlevel $loglevel
           }

         }
         return $value
       }

   #
   # Attribute loglevel
   #
   # When the attribute is set, forward the change to the logger command
   # setlevel. For the getter, use the logger command currentloglevel.
   #
   Attribute loglevel \
       -proc assign {domain var value} {
         $domain instvar loggertoken
         if {$loggertoken ne ""} {
           ${loggertoken}::setlevel $value
         }
       } \
       -proc get {domain var} {
         $domain instvar loggertoken
         if {$loggertoken ne ""} {
           return [${loggertoken}::currentloglevel]
         }
       }
 }

 Logger instproc destroy {args} {
   if {[my loggertoken] ne ""} {
     [my loggertoken]::delete
   }
   next
 }

 #
 # provide a few methods to delegate methods to the logger
 # identified by the loggertoken
 #
 Logger instproc loggercmd {subcmd} {
   return [my loggertoken]::$subcmd
 }
 Logger instforward services {%my loggercmd services}
 Logger instforward delproc  {%my loggercmd delproc}
 Logger instforward logproc  {%my loggercmd logproc}

 #
 # since for the log method, the argument has to be foldeded
 # into the command name, we use the plain tcl approach to
 # construct and evaluate the command
 #
 Logger instproc log {level args} {
   eval [linsert $args 0 [my loggertoken]::${level}]   
 }

}

# Usage cases:
#
# 1) Create a logger named 'mylog', which creates 
#    a logging service with the same name
#
#       logger::xotcl::Logger mylog
#       mylog log info "hi there"
#
# 2) Create a logger named 'l1', which creates 
#    a logging service 'global'
# 
#       logger::xotcl::Logger l1 -servicename global
#       l1 log info hello1
#
# 3) Create first a tcl logger 'myservice' and use later 
#    the tcl logger form the wrapper class 'l2'
#
#       set log [logger::init myservice]

#       logger::xotcl::Logger l2 -servicename myservice
#       l2 log info hello2
#
package provide ::logger::xotcl 0.2

