#!/usr/bin/env tclsh
## -*- tcl -*-
##########################################################################
# TEPAM - Tcl's Enhanced Procedure and Argument Manager
##########################################################################
#
# tepam_demo.tcl:
# This file provides a graphical demo framework for the enhanced procedure
# and argument manager.
#
# Copyright (C) 2009, 2010 Andreas Drollinger
# 
# Id: tepam_demo.tcl
##########################################################################
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

package require Tk
package require tepam

if {$tcl_platform(platform)=={windows}} {
   set Config(MenuBG_Color) "\#c0c0c0"
   set Config(MenuFG_Color) "black"
} else {
   set Config(MenuBG_Color) "\#667de3"
   set Config(MenuFG_Color) "white"
}

######################## Regression test GUI ########################

proc DisplayResult {Result Type} {
   regsub -line -all {^(.)} $Result "$Type: -> \\1" Result
   regsub -line -all {[\t ]+$} $Result "" Result
   .rightside.code insert insert $Result Result_$Type
   # .rightside.code see insert
   update
}

# Implement an own puts function that will display the provided strings inside 
# the execution window.
rename puts puts_orig
proc puts {args} {
   # Use the original function of the write channel if argument 0 is not a standard channel
   if {[llength $args]>1 && [lindex $args 0]!="-nonewline" && [lindex $args 0]!="stdout" && [lindex $args 0]!="stderr"} {
      if {[llength $args]==2} {
         puts_orig [lindex $args 0] [lindex $args 1]
      } else {
         puts_orig [lindex $args 0] [lindex $args 1] [lindex $args 2]
      }
      return
   }

   set EndLine "\n"
   if {[lindex $args end-1]=="-nonewline"} {
      set EndLine ""
   }
   DisplayResult [lindex $args end]$EndLine s
}

# Create an exit function that will just close an eventually opened console 
# window. This demo application can only be closed by calling the orginial
# exit command via the application's menu.
rename exit exit_orig
proc exit {args} {
   catch {destroy .tkcon}
   catch {console hide}
}

proc ExecuteExampleStep {Step} {
   global ExampleScript IsExecutable ExecutedSteps
   set CmdNbr 0
   foreach es $ExampleScript($Step) {
      .rightside.code mark set insert step$Step-cmd$CmdNbr
      if {[catch {set CmdRes [uplevel #0 $es]} ErrorRes]} {
         DisplayResult "$ErrorRes \n" e
      } else {
         DisplayResult "$CmdRes \n" r
      }
      incr CmdNbr
   }
   lappend ExecutedSteps $Step

   foreach Step [array names IsExecutable] {
      set Executed [expr [lsearch -exact $ExecutedSteps $Step]>=0]
      if $IsExecutable($Step) {
         # Activate the section and add the binds
         .rightside.code tag configure step$Step -background white -relief flat
         .rightside.code tag bind step$Step <Any-Enter> ".rightside.code tag configure step$Step -background #43ce80 -relief raised -borderwidth 1"
         .rightside.code tag bind step$Step <Any-Leave> ".rightside.code tag configure step$Step -background {} -relief flat"
         .rightside.code tag bind step$Step <1> "ExecuteExampleStep $Step"
      } else {
         # Deactivate the section and remove the binds
         .rightside.code tag configure step$Step -background gray85 -relief flat
         .rightside.code tag bind step$Step <Any-Enter> {}
         .rightside.code tag bind step$Step <Any-Leave> {}
         .rightside.code tag bind step$Step <1> {}
      }
   }
}

proc SelectExample {example} {
   global RegTestDir ExampleScript LastExecutedExampleStep IsExecutable ExecutedSteps

   wm title . "TEPAM Demo - $example"

   catch {unset ExampleScript}
   .rightside.code delete 0.0 end
   # .rightside.code configure -background white
   foreach tag [.rightside.code tag names] {
      if {[regexp -- {^(step)|(title)\d$} $tag]} {
         .rightside.code tag delete $tag
      }
   }

   .rightside.code insert end "This demo uses the following styles and colors:" Introduction
   .rightside.code insert end "\n  - " Introduction "descriptions and comments" "Introduction Comment"
   .rightside.code insert end "\n  - " Introduction "program code ready to be executed" "Introduction Code"
   .rightside.code insert end "\n  - " Introduction "already executed, or not yet executable program code" "Introduction Code Executed"
   .rightside.code insert end "\n  - " Introduction "r: command return value" "Introduction Result_r"
   .rightside.code insert end "\n  - " Introduction "e: command return error" "Introduction Result_e"
   .rightside.code insert end "\n  - " Introduction "s: standard output print (stdout)" "Introduction Result_s"
   .rightside.code insert end "\nClick now on each demo example section, one after " Introduction
   .rightside.code insert end "the other. This will execute the program code of the " Introduction
   .rightside.code insert end "section and insert the procedure results and standard and error " Introduction
   .rightside.code insert end "outputs into the demo program listing.\n\n" Introduction

   set f [open $RegTestDir/$example]
   set Step -1
   set Script ""
   set ExampleStep ""
   set LastExecutedExampleStep -1
   set InitSteps {}
   catch {array unset IsExecutable}
   set ExecutedSteps {}
   while {![eof $f]} {
      if {[gets $f line]<0} break
      if {[regexp {^\s*\#{4}\s*([^#]*)\s*\#{4}$} $line {} ExampleStep]} {
         incr Step
         set ExampleStep [string trim $ExampleStep]
         .rightside.code insert end "#### $ExampleStep ####\n" "SectionTitle title$Step"
         set ExampleScript($Step) {}
      } elseif {[regexp {^\s*DemoControl\((\w+)\)\s+(.*)\s*} $line {} ControlType ControlExpr]} {
         regexp {^\{\s*(.*)\s*\}$} $ControlExpr {} ControlExpr
         switch $ControlType {
            IsExecutable {set IsExecutable($Step) $ControlExpr}
            Initialization {lappend InitSteps $Step}
         }
      } elseif {$ExampleStep!=""} {
         if {[regexp {^\s*\#{8,100}$} $line]} {
            set ExampleStep ""
            continue
         }
         # regsub $LineStart $line {} line
         regsub -all {\t} $line {   } line
         if {![regexp {^(.*?\{\s*#.*#\s*\}.*?)(#.*){0,1}$} $line {} ScriptLine ScriptComment]} {
            regexp {^(.*?)(#.*){0,1}$} $line {} ScriptLine ScriptComment
         }
         .rightside.code insert end $ScriptLine "Code step$Step" "$ScriptComment\n" "step$Step Comment"

         if {[string trim $ScriptLine]==""} continue

         append Script "$ScriptLine\n"
         if {[info complete $Script]} {
            set Mark "step$Step-cmd[llength $ExampleScript($Step)]"
            .rightside.code mark set $Mark "end - 1 lines"
            .rightside.code mark gravity $Mark left
            lappend ExampleScript($Step) [string trim $Script]
            set Script ""
         }
      }
   }
   close $f
   
   # Execute the initialization step if existing
   foreach Step $InitSteps {
      ExecuteExampleStep $Step
   }
}

proc OpenConsole {} {
   if {[catch {set ::tkcon::PRIV(root)}]} {
      # Set PRIV(root) to an existing window to avoid a console creation
      namespace eval ::tkcon {
         set PRIV(root) .tkcon
         set OPT(exec) ""
         set OPT(slaveexit) "close"
      }
      # Search inside the *n.x environment for TkCon ('tkcon' and 'tkcon.tcl') ...
      set TkConPath ""
      catch {set TkConPath [exec which tkcon]}
      if {$TkConPath==""} {catch {set TkConPath [exec which tkcon.tcl]}}
		
      # Search inide the Windows environment for TkCon ...
      catch {
         package require registry
         set TkConPath [registry get {HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\tclsh.exe} Path]/tkcon.tcl
         regsub -all {\\} $TkConPath {/} TkConPat
      }
      if {$TkConPath!=""} {
         # hide the standard console (only windows)
         catch {console hide}

         # Source tkcon. "Usually" this should also start the tkcon window.
         set ::argv ""
         uplevel #0 "source \{$TkConPath\}"

         # TkCon versions have been observed that doesn't open the tkcon window during sourcing of tkcon. Initialize tkcon explicitly:
         if {[lsearch [winfo children .] ".tkcon"]<0 && [lsearch [namespace children ::] "::tkcon"]} {
            ::tkcon::Init
         }
         tkcon show
      } else {
         if {$::tcl_platform(platform)=={windows}} {
            console show
         } else {
            tk_messageBox -title "TkCon not found" -message "Cannot find tkcon.tcl." -type ok
         }
      }
   } else {
      if {[catch {wm deiconify $::tkcon::PRIV(root)}]} {
         if {$::tcl_platform(platform)=={windows}} {
            console show
         } else {
            tk_messageBox -title "Tk not available" -message "Cannot deiconify tkcon!" -type ok
         }
      }
   }
}

set RegTestDir [file dirname [info script]]

menu .menu -bg $Config(MenuBG_Color) -fg $Config(MenuFG_Color) -tearoff 0
. configure -menu .menu
   .menu add cascade -label File -menu .menu.file
      menu .menu.file -bg $Config(MenuBG_Color) -fg $Config(MenuFG_Color) -tearoff 0
      .menu.file add command -label "Show console" -command OpenConsole
      .menu.file add command -label "Exit" -command exit_orig

pack [frame .leftside] -side left -fill y
   pack [label .leftside.step1 -text "(1) Choose one of the demo \nexamples bellow.\n\n" -anchor w] -fill x
   pack [label .leftside.label1 -text "Demo examples:" -anchor w] -fill x
   set NbrExamples 0
   foreach example [lsort -dictionary [glob $RegTestDir/*.demo]] {
      set example [file tail $example]
      pack [button .leftside.start$NbrExamples -command "SelectExample $example" -text $example -anchor w] -fill x
      incr NbrExamples
   }

pack [frame .rightside] -side left -expand yes -fill both
   grid [label .rightside.step2 -text "(2) Execute the selected demo.\n\n" -anchor w] -row 0 -column 0 -sticky ew
   
   grid [text .rightside.code -height 1 -wrap none -font {Courier 9} -background white -relief sunken -border 2 \
              -yscrollcommand ".rightside.scrolly set" \
              -xscrollcommand ".rightside.scrollx set" ] -row 1 -column 0 -sticky news -padx 2 -pady 2
      .rightside.code tag configure Introduction -foreground blue -font {Courier 9} -wrap word
      .rightside.code tag configure Comment -foreground blue -font {Courier 9}
      .rightside.code tag configure Code -foreground black -font {Courier 9 bold}
      .rightside.code tag configure SectionTitle -foreground black -background yellow -font {Courier 9 bold}
      .rightside.code tag configure Result_r -foreground gold4 -background gray85 -font {Courier 9 italic}
      .rightside.code tag configure Result_e -foreground red -background gray85 -font {Courier 9 italic}
      .rightside.code tag configure Result_s -foreground green4 -background gray85 -font {Courier 9 italic}
      .rightside.code tag configure Executed -background gray85

   grid [scrollbar .rightside.scrolly -command ".rightside.code yview" -orient vertical] -row 1 -column 1 -sticky ns
   grid [scrollbar .rightside.scrollx -command ".rightside.code xview" -orient horizontal] -row 2 -column 0 -sticky new

   bind . <MouseWheel> "if {%D>0} {.rightside.code yview scroll -1 units} elseif {%D<0} {.rightside.code yview scroll 1 units}"
   bind . <Button-4> ".rightside.code yview scroll -1 units"
   bind . <Button-5> ".rightside.code yview scroll 1 units"

   grid rowconfigure .rightside 1 -weight 70
   grid columnconfigure .rightside 0 -weight 1

wm geometry . 900x800
wm title . "TEPAM Demo"

##########################################################################
# Id: tepam_demo.tcl
# Modifications:
#
# Revision 1.4  2013/10/14 droll
# * Improve the output/puts handling (procedure puts implemented by this file)
#
# Revision 1.4  2012/03/26 20:56:45  droll
# * TEPAM version 0.3.0
# * Replaces the control buttons by a menu.
# * Create an exit procedure to catch an eventual call of the exit command
#   inside the console.
# * Adjust the colors and rewrite the explanations.
# * Display eventual errors with message boxes.
#
# Revision 1.3  2011/11/09 05:57:47  andreas_kupries
# * examples/tepam/tepam_demo.tcl [Bug 3425269]: Applied bug fixes
#   for the demo script supplied by Stuart Cassoff.
#
# Revision 1.2  2011/01/21 16:00:49  droll
# * TEPAM version 0.2.0
#
# Revision 1.1  2010/02/11 21:54:38  droll
# * TEPAM module checkin
##########################################################################
