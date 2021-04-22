##Library Header
#
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#	::logger::appender
#
# Purpose:
#	collection of appenders for tcllib logger
#
# Author:
#	 Aamer Akhter / aakhter@cisco.com
#
# Support Alias:
#       aakhter@cisco.com
#
# Usage:
#	package require logger::appender
#
# Description:
#	set of logger templates
#      
# Requirements:
#       package require logger
#       package require md5
#
# Variables:
#       namespace   ::loggerExtension::
#       id:         CVS ID: keyword extraction
#       version:    current version of package
#       packageDir: directory where package is located
#       log:        instance log
#
# Notes:
#       1.	
#
# Keywords:
#	
#
# Category: 
#       
#
# End of Header

package require md5

namespace eval ::logger::appender {
    variable  fgcolor
    array set fgcolor {
	red      {31m}
	red-bold {1;31m}
	black    {m}
	blue     {1m}
	green    {32m}
	yellow   {33m}
	cyan     {36m}
    }

    variable  levelToColor
    array set levelToColor {
	debug     cyan
	info      blue
	notice    black
	warn      red
	error     red
	critical  red-bold
	alert     red-bold
	emergency red-bold
    }
}



##Procedure Header
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#	::logger::appender::console
#
# Purpose:
#	 
#
# Synopsis:
#       ::logger::appender::console -level <level> -service <service> [options]
#
# Arguments:
#       -level <level>
#            name of level to fill in as 'priority' in log proc
#       -service <service>
#            name of service to fill in as 'category' in log proc
#       -appenderArgs <appenderArgs>
#            any additional args in list form
#       -conversionPattern <conversionPattern>
#            log pattern to use (see genLogProc)
#       -procName <procName>
#            explicitly set the proc name
#       -procNameVar <procNameVar>
#            name of variable to set in the calling context
#            variable has name of proc 
#
#
# Return Values:
#	a runnable command 
#
# Description:
#         
#
# Examples:
#	
#
# Notes:
#	1.
#
# End of Procedure Header 


proc ::logger::appender::console {args} {
    set usage {console 
	?-level level?
	?-service service? 
	?-appenderArgs appenderArgs?
    }
    set bargs $args
    set conversionPattern {\[%d\] \[%c\] \[%M\] \[%p\] %m}
    while {[llength $args] > 1} {
        set opt [lindex $args 0]
        set args [lrange $args 1 end]
        switch  -exact -- $opt {
            -level { set level [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -service { set service [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -appenderArgs {
		set appenderArgs [lindex $args 0]
		set args [lrange $args 1 end]
		set args [concat $args $appenderArgs]
	    }
	    -conversionPattern {
		set conversionPattern [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -procName {
		set procName [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -procNameVar {
		set procNameVar [lindex $args 0]
		set args [lrange $args 1 end]
	    }
            default {
                return -code error [msgcat::mc "Unknown argument: \"%s\" :\nUsage:\
                %s" $opt $usage]
            }
        }
    }
    if {![info exists procName]} {
	set procName [genProcName $bargs]
    }
    if {[info exists procNameVar]} {
	upvar $procNameVar myProcNameVar
    }
    set procText \
	[ ::logger::utils::createLogProc \
	      -procName $procName \
	      -conversionPattern $conversionPattern \
	      -category $service \
	      -priority $level ]
    set myProcNameVar $procName
    return $procText
}



##Procedure Header
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#	::logger::appender::colorConsole
#
# Purpose:
#	 
#
# Synopsis:
#       ::logger::appender::console -level <level> -service <service> [options]
#
# Arguments:
#       -level <level>
#            name of level to fill in as 'priority' in log proc
#       -service <service>
#            name of service to fill in as 'category' in log proc
#       -appenderArgs <appenderArgs>
#            any additional args in list form
#       -conversionPattern <conversionPattern>
#            log pattern to use (see genLogProc)
#       -procName <procName>
#            explicitly set the proc name
#       -procNameVar <procNameVar>
#            name of variable to set in the calling context
#            variable has name of proc 
#
#
# Return Values:
#	a runnable command 
#
# Description:
#       provides colorized logs
#
# Examples:
#	
#
# Notes:
#	1.
#
# End of Procedure Header 


proc ::logger::appender::colorConsole {args} {
    variable fgcolor
    set usage {console 
	?-level level?
	?-service service? 
	?-appenderArgs appenderArgs?
    }
    set bargs $args
    set conversionPattern {\[%d\] \[%c\] \[%M\] \[%p\] %m}
    upvar 0 ::logger::appender::levelToColor colorMap
    while {[llength $args] > 1} {
        set opt [lindex $args 0]
        set args [lrange $args 1 end]
        switch  -exact -- $opt {
            -level { set level [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -service { set service [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -appenderArgs {
		set appenderArgs [lindex $args 0]
		set args [lrange $args 1 end]
		set args [concat $args $appenderArgs]
	    }
	    -conversionPattern {
		set conversionPattern [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -procName {
		set procName [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -procNameVar {
		set procNameVar [lindex $args 0]
		set args [lrange $args 1 end]
	    }
            default {
                return -code error [msgcat::mc "Unknown argument: \"%s\" :\nUsage:\
                %s" $opt $usage]
            }
        }
    }
    if {![info exists procName]} {
	set procName [genProcName $bargs]
    }
    upvar $procNameVar myProcNameVar
    if {[info exists level]} {
	#apply color
	set colorCode $colorMap($level)
	append newCPattern {\033\[} $fgcolor($colorCode) $conversionPattern {\033\[0m}
	set conversionPattern $newCPattern
    }
    set procText \
	[ ::logger::utils::createLogProc \
	      -procName $procName \
	      -conversionPattern $conversionPattern \
	      -category $service \
	      -priority $level ]
    set myProcNameVar $procName
    return $procText
}

##Procedure Header
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#       ::logger::appender::fileAppend
#
# Purpose:
#
#
# Synopsis:
#       ::logger::appender::fileAppend -level <level> -service <service> -outputChannel <channel> [options]
#
# Arguments:
#       -level <level>
#            name of level to fill in as 'priority' in log proc
#       -service <service>
#            name of service to fill in as 'category' in log proc
#       -appenderArgs <appenderArgs>
#            any additional args in list form
#       -conversionPattern <conversionPattern>
#            log pattern to use (see genLogProc)
#       -procName <procName>
#            explicitly set the proc name
#       -procNameVar <procNameVar>
#            name of variable to set in the calling context
#            variable has name of proc
#       -outputChannel <channel>
#            name of output channel (eg stdout, file handle)
#
#
# Return Values:
#       a runnable command
#
# Description:
#
#
# Examples:
#
#
# Notes:
#       1.
#
# End of Procedure Header


proc ::logger::appender::fileAppend {args} {
    set usage {console
	?-level level?
	?-service service?
	?-outputChannel channel?
	?-appenderArgs appenderArgs?
    }
    set bargs $args
    set conversionPattern {\[%d\] \[%c\] \[%M\] \[%p\] %m}
    while {[llength $args] > 1} {
	set opt [lindex $args 0]
	set args [lrange $args 1 end]
	switch  -exact -- $opt {
	    -level { set level [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -service { set service [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -appenderArgs {
		set appenderArgs [lindex $args 0]
		set args [lrange $args 1 end]
		set args [concat $args $appenderArgs]
	    }
	    -conversionPattern {
		set conversionPattern [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -procName {
		set procName [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -procNameVar {
		set procNameVar [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -outputChannel {
		set outputChannel [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    default {
		return -code error [msgcat::mc "Unknown argument: \"%s\" :\nUsage:\
  	                 %s" $opt $usage]
	    }
	}
    }
    if {![info exists procName]} {
	set procName [genProcName $bargs]
    }
    if {[info exists procNameVar]} {
	upvar $procNameVar myProcNameVar
    }
    set procText \
	[ ::logger::utils::createLogProc \
	      -procName $procName \
	      -conversionPattern $conversionPattern \
	      -category $service \
	      -outputChannel $outputChannel \
	      -priority $level ]
    set myProcNameVar $procName
    return $procText
}
  	 



##Internal Procedure Header
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#       ::logger::appender::genProcName
#
# Purpose:
#        
#
# Synopsis:
#       ::logger::appender::genProcName <args>
#
# Arguments:
#       <formatString>
#            string composed of formatting chars (see description)
#
#
# Return Values:
#       a runnable command 
#
# Description:
#         
#
# Examples:
#       ::loggerExtension::new param1
#       ::loggerExtension::new param2
#       ::loggerExtension::new param3 <option1>
#
#
# Sample Input:
#       (Optional) Sample of input to the proc provided by its argument values.
#
# Sample Output:
#       (Optional) For procs that output to files, provide 
#       sample of format of output produced.
# Notes:
#       1.
#
# End of Procedure Header 


proc ::logger::appender::genProcName {args} {
    set name [md5::md5 -hex $args]
    return "::logger::appender::logProc-$name"
}


package provide logger::appender 1.3

# ;;; Local Variables: ***
# ;;; mode: tcl ***
# ;;; End: ***
