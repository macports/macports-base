#!/usr/bin/env tclsh
# 
# Logger example - How to log to a text widget
#
# (c) 2005 Michael Schlenker <mic42@users.sourceforge.net>
#
# $Id: logtotext.tcl,v 1.2 2005/06/01 03:09:49 andreas_kupries Exp $

package require Tcl 8.4
package require Tk
package require logger

set config(elide,time) 0
set config(elide,level) 0
foreach level [logger::levels] {
    set config(elide,$level) 0
}

set logmessage "A little log message"
#
# Create a simple logger with the servicename 'global'
#
#
proc createLogger {} {
    global mylogger
    set mylogger [logger::init global]

    # loggers logproc takes just one arg, so curry 
    # our proc with the loglevel and use an alias
    foreach level [logger::levels] {
        interp alias {} insertLogLine_$level {} insertLogLine $level
        ${mylogger}::logproc $level insertLogLine_$level        
    }
}

# Put the logmessage to the logger system
proc sendMessageToLog {level} {
    ${::mylogger}::$level $::logmessage
}

proc createGUI {} {
    global mylogger
    global logwidget
    
    wm title . "Logger example - log to text widget"
    
    # a little compose window for entering messages
    labelframe .compose -text "Compose log message"
    entry .compose.logmessage -textvariable logmessage
    frame .compose.levels 
    foreach level [logger::levels] {
        set p .compose.levels.$level 
        button $p -command [list sendMessageToLog $level] -text "Log as $level"
        lappend buttons $p                
    }
    eval grid $buttons -sticky ew -padx 2 -pady 5
    grid .compose.logmessage -sticky ew
    grid .compose.levels -sticky ew
    grid .compose -sticky ew
    
    # The output window
    labelframe .log -text "Log output" 
    text .log.text -yscrollcommand [list .log.yscroll set] -wrap none
    set logwidget .log.text 
    scrollbar .log.yscroll -orient vertical -command [list $logwidget yview]
    frame .log.buttons 
    frame .log.buttons.elide
    checkbutton .log.buttons.elide.toggletime -text "Display Timestamp" -command [list toggleElide time] \
        -onvalue 0 -offvalue 1 -variable config(elide,time)
    checkbutton .log.buttons.elide.togglelevel -text "Display Level" -command [list toggleElide level] \
        -onvalue 0 -offvalue 1 -variable config(elide,level)
    frame .log.buttons.elidelevels
    foreach level [logger::levels] {
        set b .log.buttons.elidelevels.$level 
        checkbutton $b -text "Display $level" -command [list toggleElide $level] -variable config(elide,$level) \
                       -onvalue 0 -offvalue 1
        lappend elides $b
    }
    eval grid $elides 
    grid .log.text .log.yscroll -sticky nsew
    grid configure .log.yscroll -sticky nws
    grid .log.buttons.elide.toggletime .log.buttons.elide.togglelevel
    grid .log.buttons.elide -sticky ew
    grid .log.buttons.elidelevels -sticky ew
    grid .log.buttons -columnspan 2 -sticky ew
    grid .log -sticky news
    grid columnconfigure . 0 -weight 1
    grid rowconfigure . 0 -weight 0
    grid rowconfigure . 1 -weight 1
    grid columnconfigure .log 0 -weight 1
    grid columnconfigure .log 1 -weight 0
    grid rowconfigure .log 0 -weight 1
    
    #
    # Now we create some fonts
    # a fixed font for the first two columns, so they stay nicely lined up
    # a proportional font for the message as it is probably better to read
    #
    font create logger::timefont -family {Courier} -size 12
    font create logger::levelfont -family {Courier} -size 12 
    font create logger::msgfont -family {Times} -size 12    
    $logwidget tag configure logger::time -font logger::timefont
    $logwidget tag configure logger::level -font logger::levelfont
    $logwidget tag configure logger::message -font logger::msgfont

    # Now we create some colors for the levels, so our messages appear in different colors    
    foreach level [logger::levels] color {darkgrey lightgrey brown blue orange red} {
        $logwidget tag configure logger::$level -background $color        
    }
    
    # Disable the widget, so it is read only
    $logwidget configure -state disabled
    
}

# Allow toggling of display
# 
# only time and level are used in this example, but you could
# elide specific messages levels too
#
proc toggleElide {type} {
    global config
    $::logwidget tag configure logger::$type -elide $config(elide,$type)
    return
}

# A rather basic insert
#
# I a long running application we would probably add some code to only keep
# a specific number of log messages in the text widget, and throw away some older
# ones. (basic stuff, just count lines and for example add a 
# $logwidget delete 1.0 2.0
# if the log grows too long, needs refinement if you have multi line log messages )
# 
proc insertLogLine {level txt} {
    global logwidget    
    
    $logwidget configure -state normal
    $logwidget insert end "<[clock format [clock seconds] -format "%H:%M:%S"]> " [list logger::time logger::$level] \
                          [format "%10.10s : " <$level>]   [list logger::level logger::$level] \
                          $txt\n [list logger::message logger::$level] 
    $logwidget configure -state disabled
}

proc every {time body} {
    after $time [info level 0]
    uplevel #0 $body
}

proc main {} {
    createLogger
    createGUI  
}

main

# Add some repeating message 
every 10000 {${mylogger}::info "The current time is [clock format [clock seconds] -format "%H:%M:%S"]"} 