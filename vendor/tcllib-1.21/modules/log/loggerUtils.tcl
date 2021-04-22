##Library Header
#
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#	::logger::utils::
#
# Purpose:
#	an extension to the tcllib logger module
#
# Author:
#	 Aamer Akhter / aakhter@cisco.com
#
# Support Alias:
#       aakhter@cisco.com
#
# Usage:
#	package require logger::utils
#
# Description:
#	this extension adds template based appenders
#
# Requirements:
#       package require logger
#
# Variables:
#       namespace   ::logger::utils::
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

package require Tcl 8.4
package require logger
package require logger::appender
package require msgcat

namespace eval ::logger::utils {

    variable packageDir [file dirname [info script]]
    variable log        [logger::init logger::utils]

    logger::import -force -namespace log logger::utils

    # @mdgen OWNER: msgs/*.msg
    ::msgcat::mcload [file join $packageDir msgs]
}

##Internal Procedure Header
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#	::logger::utils::createFormatCmd
#
# Purpose:
#
#
# Synopsis:
#       ::logger::utils::createFormatCmd <formatString>
#
# Arguments:
#       <formatString>
#            string composed of formatting chars (see description)
#
#
# Return Values:
#	a runnable command
#
# Description:
#       createFormatCmd translates <formatString> into an expandable
#       command string.
#
#       The following are the known substitutions (from log4perl):
#            %c category of the logging event
#            %C fully qualified name of logging event
#            %d current date in yyyy/MM/dd hh:mm:ss
#            %H hostname
#            %m message to be logged
#            %M method where logging event was issued
#            %p priority of logging event
#            %P pid of current process
#
#
# Examples:
#       ::logger::new param1
#       ::logger::new param2
#       ::logger::new param3 <option1>
#
#
# Sample Input:
#	(Optional) Sample of input to the proc provided by its argument values.
#
# Sample Output:
#	(Optional) For procs that output to files, provide
#	sample of format of output produced.
# Notes:
#	1.
#
# End of Procedure Header


proc ::logger::utils::createFormatCmd {text args} {
    variable log
    array set opt $args

    regsub -all -- \
	{%P} \
	$text \
	[pid] \
	text

    regsub -all -- \
	{%H} \
	$text \
	[info hostname] \
	text


    #the %d subst has to happen at the end
    regsub -all -- \
	{%d} \
	$text \
	{[clock format [clock seconds] -format {%Y/%m/%d %H:%M:%S}]} \
	text

    if {[info exists opt(-category)]} {
	regsub -all -- \
	    {%c} \
	    $text \
	    $opt(-category) \
	    text

	regsub -all -- \
	    {%C} \
	    $text \
	    [lindex [split $opt(-category) :: ] 0] \
	    text
    }

    if {[info exists opt(-priority)]} {
	regsub -all -- \
	    {%p} \
	    $text \
	    $opt(-priority) \
	    text
    }

    return $text
}



##Procedure Header
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#	::logger::utils::createLogProc
#
# Purpose:
#
#
# Synopsis:
#       ::logger::utils::createLogProc -procName <procName> [options]
#
# Arguments:
#       -procName <procName>
#            name of proc to create
#       -conversionPattern <pattern>
#            see createFormatCmd for <pattern>
#       -category <category>
#            the category (service)
#       -priority <priority>
#            the priority (level)
#       -outputChannel <channel>
#            channel to output on (default stdout)
#
#
# Return Values:
#	a runnable command
#
# Description:
#       createFormatCmd translates <formatString> into an expandable
#       command string.
#
#       The following are the known substitutions (from log4perl):
#            %c category of the logging event
#            %C fully qualified name of logging event
#            %d current date in yyyy/MM/dd hh:mm:ss
#            %H hostname
#            %m message to be logged
#            %M method where logging event was issued
#            %p priority of logging event
#            %P pid of current process
#
#
# Examples:
#
#
# Sample Input:
#	(Optional) Sample of input to the proc provided by its argument values.
#
# Sample Output:
#	(Optional) For procs that output to files, provide
#	sample of format of output produced.
# Notes:
#	1.
#
# End of Procedure Header


proc ::logger::utils::createLogProc {args} {
    variable log
    array set opt $args

    set formatText ""
    set methodText ""
    if {[info exists opt(-conversionPattern)]} {
	set text $opt(-conversionPattern)

	regsub -all -- \
	    {%P} \
	    $text \
	    [pid] \
	    text

	regsub -all -- \
	    {%H} \
	    $text \
	    [info hostname] \
	    text

	if {[info exists opt(-category)]} {
	    regsub -all -- \
		{%c} \
		$text \
		$opt(-category) \
		text

	    regsub -all -- \
		{%C} \
		$text \
		[lindex [split $opt(-category) :: ] 0] \
		text
	}

	if {[info exists opt(-priority)]} {
	    regsub -all -- \
		{%p} \
		$text \
		$opt(-priority) \
		text
	}


	if {[regexp {%M} $text]} {
	    set methodText {
		if {[info level] < 2} {
		    set method "global"
		} elseif {[uplevel 1 {namespace which self}] == "::oo::Helpers::self"} {
		    set    method    [uplevel 1 {self class}]
		    append method :: [uplevel 1 {self method}]
		} else {
		    set method [lindex [info level -1] 0]
		}
	    }

	    regsub -all -- \
		{%M} \
		$text \
		{$method} \
		text
	}

	regsub -all -- \
	    {%m} \
	    $text \
	    {$text} \
	    text

	regsub -all -- \
	    {%d} \
	    $text \
	    {[clock format [clock seconds] -format {%Y/%m/%d %H:%M:%S}]} \
	    text

    }

    if {[info exists opt(-outputChannel)]} {
	set outputChannel $opt(-outputChannel)
    } else {
	set outputChannel stdout
    }

    set formatText $text
    set outputCommand puts

    set procText {
	proc $opt(-procName) {text} {
	    $methodText
	    $outputCommand $outputChannel \"$formatText\"
	}
    }

    set procText [subst $procText]
    return $procText
}


##Procedure Header
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#	::logger::utils::applyAppender
#
# Purpose:
#
#
# Synopsis:
#       ::logger::utils::applyAppender -appender <appenderType> [options]
#
# Arguments:
#       -service <logger service names>
#       -serviceCmd <logger serviceCmds>
#            name of logger instance to modify
#            -serviceCmd takes as input the return of logger::init
#
#       -appender <appenderType>
#            type of appender to use
#             console|colorConsole...
#
#       -appenderArgs <argumentlist>
#            A list of additional options plus their arguments
#
#       -levels <levels to apply to>
#            list of levels to apply this appender to
#            by default all levels are applied to
#
# Return Values:
#
#
# Description:
#       applyAppender will create an appender for the specified
#       logger services. If not service is specified then the
#       appender will be added as the default appender for
#       the specified levels. If no levels are specified, then
#       all levels are assumed.
#
#       The following are the known substitutions (from log4perl):
#            %c category of the logging event
#            %C fully qualified name of logging event
#            %d current date in yyyy/MM/dd hh:mm:ss
#            %H hostname
#            %m message to be logged
#            %M method where logging event was issued
#            %p priority of logging event
#            %P pid of current process
#
#
# Examples:
#        % set log [logger::init testLog]
#        ::logger::tree::testLog
#        % logger::utils::applyAppender -appender console -serviceCmd $log
#        % ${log}::error "this is error"
#        [2005/08/22 10:14:13] [testLog] [global] [error] this is error
#
#
# End of Procedure Header


proc ::logger::utils::applyAppender {args} {
    set usage {logger::utils::applyAppender
	-appender appender
	?-instance?
	?-levels levels?
	?-appenderArgs appenderArgs?
    }
    set levels [logger::levels]
    set appenderArgs {}
    set bargs $args
    while {[llength $args] > 1} {
        set opt [lindex $args 0]
        set args [lrange $args 1 end]
        switch  -exact -- $opt {
            -appender { set appender [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -serviceCmd { set serviceCmd [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -service { set serviceCmd [logger::servicecmd [lindex $args 0]]
		set args [lrange $args 1 end]
	    }
            -levels { set levels [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	    -appenderArgs {
		set appenderArgs [lindex $args 0]
		set args [lrange $args 1 end]
	    }
            default {
                return -code error [msgcat::mc "Unknown argument: \"%s\" :\nUsage:\
                %s" $opt $usage]
            }
        }
    }

    set appender ::logger::appender::${appender}
    if {[info commands $appender] == {}} {
	return -code error [msgcat::mc "could not find appender '%s'" $appender]
    }

    #if service is not specified make all future services with this appender
    # spec
    if {![info exists serviceCmd]} {
	set ::logger::utils::autoApplyAppenderArgs $bargs
	#add trace
	#check to see if trace is already set
	if {[lsearch [trace info execution logger::init] \
		 {leave ::logger::utils::autoApplyAppender} ] == -1} {
	    trace add execution ::logger::init leave ::logger::utils::autoApplyAppender
	}
	return
    }


    #foreach service specified, apply the appender for each of the levels
    # specified
    foreach srvCmd $serviceCmd {

	foreach lvl $levels {
	    set procText [$appender -appenderArgs $appenderArgs \
			      -level $lvl \
			      -service [${srvCmd}::servicename] \
			      -procNameVar procName
			 ]
	    eval $procText
	    ${srvCmd}::logproc $lvl $procName
	}
    }
}


##Internal Procedure Header
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#	::logger::utils::autoApplyAppender
#
# Purpose:
#
#
# Synopsis:
#       ::logger::utils::autoApplyAppender <command> <command-string> <log> <op> <args>
#
# Arguments:
#       <command>
#       <command-string>
#       <log>
#            servicecmd generated by logger:init
#       <op>
#       <args>
#
# Return Values:
#	<log>
#
# Description:
#       autoApplyAppender is designed to be added via trace leave
#       to logger::init calls
#
#       autoApplyAppender will look at preconfigred state (via applyAppender)
#       to autocreate appenders for newly created logger instances
#
# Examples:
#	logger::utils::applyAppender -appender console
#	set log [logger::init applyAppender-3]
#	${log}::error "this is error"
#
#
# Sample Input:
#
# Sample Output:
#
# Notes:
#	1.
#
# End of Procedure Header


proc ::logger::utils::autoApplyAppender {command command-string log op args} {
    variable autoApplyAppenderArgs
    set bAppArgs $autoApplyAppenderArgs
    set levels [logger::levels]
    set appenderArgs {}
    while {[llength $bAppArgs] > 1} {
        set opt [lindex $bAppArgs 0]
        set bAppArgs [lrange $bAppArgs 1 end]
        switch  -exact -- $opt {
            -appender { set appender [lindex $bAppArgs 0]
		set bAppArgs [lrange $bAppArgs 1 end]
	    }
            -levels { set levels [lindex $bAppArgs 0]
		set bAppArgs [lrange $bAppArgs 1 end]
	    }
	    -appenderArgs {
		set appenderArgs [lindex $bAppArgs 0]
		set bAppArgs [lrange $bAppArgs 1 end]
	    }
            default {
                return -code error [msgcat::mc "Unknown argument: \"%s\" :\nUsage:\
                %s" $opt $usage]
            }
        }
    }
    if {![info exists appender]} {
	return -code error [msgcat::mc "need to specify -appender"]
    }
    logger::utils::applyAppender -appender $appender -serviceCmd $log \
	-levels $levels -appenderArgs $appenderArgs
    return $log
}


package provide logger::utils 1.3.1

# ;;; Local Variables: ***
# ;;; mode: tcl ***
# ;;; End: ***
