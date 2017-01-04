################################################################################
#     Logger Utilities - SNIT wrapper for logger
#     
#     A SNIT type to wrap logger
#     
#     (c) 2005 Michael Schlenker <mic42@users.sourceforge.net>
#     
#     $Id: snit-logger.tcl,v 1.2 2005/04/27 02:40:40 andreas_kupries Exp $
#
#################################################################################

package require snit
package require logger

namespace eval ::logger::snit {
    
    snit::type Logger {
        variable loggertoken ""
        option -servicename -configuremethod servicenameconf 
        option -loglevel -default debug -configuremethod loglevelconf

        delegate method * using "%s _indirect %m"         
        constructor {args} {
            $self configurelist $args            
            ${loggertoken}::setlevel $options(-loglevel)

        }
    
        destructor {
            ${loggertoken}::delete
        }

        method log {level args} {
            eval [linsert $args 0 ${loggertoken}::${level}]   
        }     
        
        method _indirect {cmd args} {
            eval [linsert $args 0 ${loggertoken}::${cmd}]
        }
        
        method servicenameconf {opt val} {
            if {$loggertoken != ""} {
                ${loggertoken}::delete
            }
            
            if {$val != ""} {
            if {[lsearch -exact [logger::services] $val] == -1} {
                set loggertoken [logger::init $val]
                set options(-servicename) $val
            } else {
                set loggertoken [logger::servicecmd $val]
                set options(-servicename) $val
            }
            }
        }
        
        method loglevelconf {opt val} {
            set options($opt) $val
            if {$loggertoken != ""} {
                ${loggertoken}::setlevel $val
            }
        }
    }
}

package provide ::logger::snit 0.1
