#!/usr/bin/env tclsh
## -*- tcl -*-
#   - simple tcl/tk test script for FTP library package -
#
#   Required:	tcl/tk8.3
#
#   Created:	07/97 
#   Changed:	07/00 
#   Version:    1.1
#
#   Copyright (C) 1997,1998 Steffen Traeger
#	EMAIL:	Steffen.Traeger@t-online.de
#	URL:	http://home.t-online.de/home/Steffen.Traeger
#
#   This program is free software; you can redistribute it and/or 
#   modify it. 
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
########################################################################

package require Tcl 8.3
package require Tk
package require ftp 2.0

# set palette under X
if { [string range [winfo server .] 0 0] == "X" } {
	option add *background			LightGray
	tk_setPalette LightGray
	option add *Text.foreground		black
	option add *Text.background		[option get . selectBackground Listbox]
	option add *Listbox.background		[option get . selectBackground Listbox]
	option add *Listbox.selectBackground 	[option get . insertBackground Listbox]
	option add *Listbox.selectForeground  	white    
	option add *Entry.background		[option get . selectBackground Listbox]
	option add *Entry.selectBackground 	[option get . insertBackground Listbox]
	option add *Entry.selectForeground  	white
	option add *borderWidth			2
} else {
	option add *Checkbutton.borderWidth	0
	option add *Radiobutton.borderWidth	0

}   

# main window
wm title . "ftp Test"
wm iconname . ftptest
wm minsize . 1 1

# split area
frame .msg -bd 1 -relief raised
  pack .msg -in . -side top -fill both -expand 1
frame .op -bd 1 -relief raised
  pack .op -in . -side top -fill x
frame .but -bd 1 -relief raised
  pack .but -in . -side top -fill both -expand 1
  
####################################################################
# Frame 1
#
# Options
frame .op.f -bd 3
  pack .op.f -in .op -side top -fill x
  
### options   
frame .op.f.f1 -bd 3
  pack .op.f.f1 -in .op.f -side left -fill both
label .op.f.f1.l -bd 2 -text "Server Options: " -relief flat -anchor w
  pack .op.f.f1.l -in .op.f.f1 -side top -fill x

frame .op.f.f1.server -bd 2
  pack .op.f.f1.server -in .op.f.f1 -side top -fill x -padx 15
label .op.f.f1.server.l -text "Host: " -width 10 -relief flat -anchor w
  pack .op.f.f1.server.l -in .op.f.f1.server -side left -fill x
entry .op.f.f1.server.e -width 20
  pack .op.f.f1.server.e -in .op.f.f1.server -side left -fill x

frame .op.f.f1.port -bd 2
  pack .op.f.f1.port -in .op.f.f1 -side top -fill x -padx 15
label .op.f.f1.port.l -text "Port: " -width 10 -relief flat -anchor w
  pack .op.f.f1.port.l -in .op.f.f1.port -side left -fill x
entry .op.f.f1.port.e -width 5
  pack .op.f.f1.port.e -in .op.f.f1.port -side left -fill x

frame .op.f.f1.username -bd 2
  pack .op.f.f1.username -in .op.f.f1 -side top -fill x -padx 15
label .op.f.f1.username.l -text "Username: " -width 10 -relief flat -anchor w
  pack .op.f.f1.username.l -in .op.f.f1.username -side left -fill x
entry .op.f.f1.username.e -width 10
  pack .op.f.f1.username.e -in .op.f.f1.username -side left -fill x

frame .op.f.f1.password -bd 2
  pack .op.f.f1.password -in .op.f.f1 -side top -fill x -padx 15
label .op.f.f1.password.l -text "Password: " -width 10 -relief flat -anchor w
  pack .op.f.f1.password.l -in .op.f.f1.password -side left -fill x
entry .op.f.f1.password.e -width 10 -show "*"
  pack .op.f.f1.password.e -in .op.f.f1.password -side left -fill x

frame .op.f.f1.directory -bd 2
  pack .op.f.f1.directory -in .op.f.f1 -side top -fill x -padx 15
label .op.f.f1.directory.l -text "Directory: " -width 10 -relief flat -anchor w
  pack .op.f.f1.directory.l -in .op.f.f1.directory -side left -fill x
entry .op.f.f1.directory.e -width 20
  pack .op.f.f1.directory.e -in .op.f.f1.directory -side left -fill x

# Separator
frame .op.f.sep1 -bd 1 -relief sunken
  pack .op.f.sep1 -in .op.f -fill y -side left -pady 2 -padx 4
frame .op.f.sep1.f -bd 1 -relief flat
  pack .op.f.sep1.f -in .op.f.sep1 -fill y -side left

frame .op.f.f2 -bd 3
  pack .op.f.f2 -in .op.f -side left -fill both -ipadx 15  
### transfer mode  
label .op.f.f2.l2 -borderwidth 2 -anchor w -text "Transfer mode:" 
  pack .op.f.f2.l2 -in .op.f.f2 -side top -fill x
radiobutton .op.f.f2.active -anchor w -text "Active" -variable test(mode) -value "active"
  pack .op.f.f2.active -in .op.f.f2 -side top -fill x -padx 15
radiobutton .op.f.f2.passive -anchor w -text "Passive" -variable test(mode) -value "passive"
  pack .op.f.f2.passive -in .op.f.f2 -side top -fill x -padx 15

####################################################################
# Frame 2 
#
### debugging  
label .op.f.f2.l1 -borderwidth 2 -anchor w -text "Debugging:" 
  pack .op.f.f2.l1 -in .op.f.f2 -side top -fill x 
checkbutton .op.f.f2.debug -anchor w -text "Debug" -variable ftp::DEBUG
  pack .op.f.f2.debug -in .op.f.f2 -side top -fill x  -padx 15
checkbutton .op.f.f2.verbose -anchor w -text "Verbose" -variable ftp::VERBOSE
  pack .op.f.f2.verbose -in .op.f.f2 -side top -fill x -padx 15

#Iterations
frame .op.f.f2.loops -bd 2
  pack .op.f.f2.loops -in .op.f.f2 -side top -fill x -pady 2
label .op.f.f2.loops.l -borderwidth 2 -text "Iterations: " -relief flat -anchor w
  pack .op.f.f2.loops.l -in .op.f.f2.loops -side left -fill x
entry .op.f.f2.loops.e -borderwidth 2 -width 5
  pack .op.f.f2.loops.e -in .op.f.f2.loops -side left -fill x

# Separator
frame .op.f.sep2 -bd 1 -relief sunken
  pack .op.f.sep2 -in .op.f -fill y -side left -pady 2 -padx 4
frame .op.f.sep2.f -bd 1 -relief flat
  pack .op.f.sep2.f -in .op.f.sep2 -fill y -side left

####################################################################
# Frame 3
#
frame .op.f.f3 -bd 3
  pack .op.f.f3 -in .op.f -side left -fill both -expand 1 -ipadx 15

label .op.f.f3.l1  -anchor w -width 10 -text "Variable trace:" 
  pack .op.f.f3.l1 -in .op.f.f3 -side top -fill x 

frame .op.f.f3.v0 -bd 0
  pack .op.f.f3.v0 -in .op.f.f3 -side top -fill x -pady 2 -padx 15
label .op.f.f3.v0.name  -anchor w -text "iterations = " 
  pack .op.f.f3.v0.name  -in .op.f.f3.v0 -side left -fill x 
label .op.f.f3.v0.value -anchor w -textvariable test(loop)
  pack .op.f.f3.v0.value -in .op.f.f3.v0 -side top -fill x
frame .op.f.f3.v1 -bd 0
  pack .op.f.f3.v1 -in .op.f.f3 -side top -fill x -pady 2 -padx 15
label .op.f.f3.v1.name  -anchor w -text "errors = " 
  pack .op.f.f3.v1.name  -in .op.f.f3.v1 -side left -fill x 
label .op.f.f3.v1.value -anchor w -textvariable test(errors)
  pack .op.f.f3.v1.value -in .op.f.f3.v1 -side top -fill x
frame .op.f.f3.v2 -bd 0
  pack .op.f.f3.v2 -in .op.f.f3 -side top -fill x -pady 2 -padx 15
label .op.f.f3.v2.name  -anchor w -text "after queues = " 
  pack .op.f.f3.v2.name  -in .op.f.f3.v2 -side left -fill x 
label .op.f.f3.v2.value -anchor w -textvariable test(after) 
  pack .op.f.f3.v2.value -in .op.f.f3.v2 -side top -fill x
frame .op.f.f3.v4 -bd 0
  pack .op.f.f3.v4 -in .op.f.f3 -side top -fill x -pady 2 -padx 15
label .op.f.f3.v4.name  -anchor w -text "open channels:" 
  pack .op.f.f3.v4.name  -in .op.f.f3.v4 -side top -fill x 
label .op.f.f3.v4.value -anchor w -textvariable test(open) 
  pack .op.f.f3.v4.value -in .op.f.f3.v4 -side top -fill x -padx 8

#####################################################################################
# Messages
frame .msg.f -bd 3
  pack .msg.f -in .msg -side top -fill both -expand 1

frame .msg.f.f1 -bd 2 -relief groove 
  pack .msg.f.f1 -in .msg.f -side left -fill both -padx 2 -pady 2
label .msg.f.f1.l -text "Test commands: " -relief flat -anchor w
  pack .msg.f.f1.l -in .msg.f.f1 -side top -fill x -padx 4 -pady 2

### Test commands   
set idlist {}  
foreach {id text} { 	quote "System Info"\
			list "List" \
			nlist "NList" \
			dir "Cd, MkDir, RmDir" \
			afile "ASCII Put/Get" \
			bfile "Binary Put/Ret" \
			ren "Rename" \
			append "Append" \
			new "Newer"  \
			reget "Reget" \
			notfound "file not found"} {
	checkbutton .msg.f.f1.$id -anchor w -text $text -variable test($id)
  	  pack .msg.f.f1.$id -in .msg.f.f1 -side top -fill x -padx 16
  	set test($id) 1
  	lappend idlist $id
}
button .msg.f.f1.plus -text "+ all" -command "foreach i {$idlist} {set test(\$i) 1}"
  pack .msg.f.f1.plus -in .msg.f.f1 -side left -fill x -padx 16 -pady 8
button .msg.f.f1.minus -text  "- all" -command "foreach i {$idlist} {set test(\$i) 0}"
  pack .msg.f.f1.minus -in .msg.f.f1 -side left -fill x -pady 8

frame .msg.f.f2 -bd 2 -relief groove 
  pack .msg.f.f2 -in .msg.f -side left -fill both -pady 2

label .msg.f.f2.label -text "Messages:" -anchor w
  pack .msg.f.f2.label -in .msg.f.f2 -side top -fill x -padx 2
scrollbar .msg.f.f2.yscroll -command ".msg.f.f2.text yview" 
  pack .msg.f.f2.yscroll -in .msg.f.f2 -side right -fill y
scrollbar .msg.f.f2.xscroll -relief sunken -orient horizontal -command ".msg.f.f2.text xview" 
  pack .msg.f.f2.xscroll -in .msg.f.f2 -side bottom -fill x
text .msg.f.f2.text -relief sunken -setgrid 1 -wrap none -height 20 -width 80 -bg white -fg black\
	-state disabled  -xscrollcommand ".msg.f.f2.xscroll set" \
	-yscrollcommand ".msg.f.f2.yscroll set"
  pack .msg.f.f2.text -in .msg.f.f2 -side left  -expand 1 -fill both
.msg.f.f2.text tag configure error -foreground red
.msg.f.f2.text tag configure data -foreground brown
.msg.f.f2.text tag configure control -foreground blue
.msg.f.f2.text tag configure header -foreground white -background black

#####################################################################################
# Buttons
frame .but.f -bd 3
  pack .but.f -in .but -side top -fill both -expand 1

frame .but.f.f1 -bd 3 
  pack .but.f.f1 -in .but.f -side top -fill x -padx 15 -pady 6
button .but.f.f1.start -text "Start Test" -width 12 -state normal -command "StartTest" 
   pack .but.f.f1.start -side left -fill x  -padx 15 
button .but.f.f1.stop -text "Stop Test" -width 12 -state disabled -command "StopTest" 
   pack .but.f.f1.stop -side left -fill x  -padx 15 
button .but.f.f1.close -text "Quit" -width 12 -state normal -command "destroy ." 
   pack .but.f.f1.close -side right -fill x  -padx 15 
button .but.f.f1.save -text "Save Options" -width 12 -state normal -command "SaveConfig" 
   pack .but.f.f1.save -side right -fill x  -padx 15 

################ procedures ####################################################################

# overwrite default ftp display message procedure
namespace eval ftp {
proc DisplayMsg {s msg {state ""}} {
global test
	.msg.f.f2.text configure -state normal
	
	# change state from "error" to "" for procedure test_9notfound
	if { ($state == "error") && [info exist test(proc)] && ($test(proc) == "test_99notfound") } {
		set state ""
	}
	
	switch -exact -- $state {
	  data		{.msg.f.f2.text insert end "$msg\n" data}
	  control	{.msg.f.f2.text insert end "$msg\n" control}
	  error		{.msg.f.f2.text insert end "$msg\n" error; incr test(errors)}
	  header	{.msg.f.f2.text insert end "$msg\n" header}
	  default 	{.msg.f.f2.text insert end "$msg\n"}
	}
	.msg.f.f2.text configure -state disabled
	.msg.f.f2.text see end
	update idletasks
}}

# new tracing open command
rename open ftpopen
proc open {args} {
global test
	set rc [eval ftpopen $args]
	if {[lsearch -exact $test(open) $rc] == "-1"} {
		lappend test(open) $rc
	}
#puts "open: $test(open)"
	return $rc
}	

# new tracing close command
rename close ftpclose
proc close {args} {
global test
	set rc [eval ftpclose $args]
	set index [lsearch -exact $test(open) $args]
	if {$index != "-1"} {
		set test(open) [lreplace $test(open) $index $index]
	} 
#puts "close: $test(open)"
	return $rc
}	

# new tracing socket command
rename socket ftpsocket
proc socket {args} {
global test
	set rc [eval ftpsocket $args]
	if {[lsearch -exact $test(open) $rc] == "-1"} {
		lappend test(open) $rc
	} 
#puts "socket: $test(open)"
	return $rc
}	


# new tracing InitDataConn command
namespace eval ftp {
rename InitDataConn ftpInitDataConn 
proc InitDataConn {args} {
global test
	set rc [eval ftpInitDataConn  $args]
	set s [lindex $args 0]
	if {[lsearch -exact $test(open) $s] == "-1"} {
		lappend test(open) $s
	} 
#puts "InitDataConn: $test(open)"
	return $rc
}}

# progress bar for put/get operations 
proc ProgressBar {state {bytes 0} {total {}} {filename {}}} {
global progress
	set w .progress
	switch -exact -- $state {
	  init	{
		set progress(percent) "0%"
		set progress(total) $total
		set progress(left) 0
 		toplevel $w -bd 0 -class Progressbar
		wm transient $w .
		wm title $w Progress
        	wm iconname $w Progress
		wm resizable $w 0 0
		focus $w
		
		frame $w.frame -bd 4
	  	  pack $w.frame -side top -fill both
		label $w.frame.label -text "Transfering $filename..." -relief flat -anchor w -bd 1
	  	  pack $w.frame.label -in $w.frame -side top -fill x -padx 10 -pady 5
		frame $w.frame.bar -bd 1 -relief sunken -bg #ffffff
	  	  pack $w.frame.bar -in $w.frame -side left -padx 10 -pady 5
		frame $w.frame.bar.dummy -bd 0 -width 250 -height 0
	  	  pack $w.frame.bar.dummy -in $w.frame.bar -side top -fill x
		frame $w.frame.bar.pbar -bd 0 -width 0 -height 20
	  	  pack $w.frame.bar.pbar -in $w.frame.bar -side left
		label $w.frame.proz -textvariable progress(percent) -width 5 -relief flat -anchor e -bd 1
	  	  pack $w.frame.proz -in $w.frame -side right -padx 10 -pady 5

		wm withdraw $w
		update idletasks
		set x [expr {[winfo x .] + ([winfo width .] / 2) - ([winfo reqwidth $w] / 2)}]
		set y [expr {[winfo y .] + ([winfo height .] / 2) - ([winfo reqheight $w] / 2)}]
		wm geometry $w +$x+$y
		update idletasks
		wm deiconify $w
		update idletasks
 	  }

	  update {
 		if {![winfo exist $w]} {return}  
		set cur_width 250
		catch {
			set progress(percent) "[expr {round($bytes) * 100 / $progress(total)}]%";
			set cur_width [expr {round($bytes * 250 / $progress(total))}]
		} msg
		$w.frame.bar.pbar configure -width $cur_width -bg #000080
		update idletasks
	  }

	  done 	{
	  	unset progress
		destroy $w
		update
	  }
	  default {
	      error "Unknown state \"$state\""
	  }
	}
}

#
# 1.) list -  returns a long list
#
proc test_10list {loop} {
global test

	# check if enabled
	if {!$test(list)} {return}

	ftp::DisplayMsg $test(conn) "*** TEST $loop.1 (long directory listing)  ***" header
	set remote_list [ftp::List $test(conn)]		
	ftp::DisplayMsg $test(conn) "[llength $remote_list] directory lines!"
}

#
# 2.) nlist - returns a sorted short list
#
proc test_20nlist {loop} {
global test

	# check if enabled
	if {!$test(nlist)} {return}

	ftp::DisplayMsg $test(conn) "*** TEST $loop.2 (short directory listing) ***" header
	set remote_list [ftp::NList $test(conn)]
	ftp::DisplayMsg $test(conn) "[llength $remote_list] directory entries!" 
}


#
# 3.) directory commands (cd, mkdir, rmdir)
#	- creates a remote directory foo
#	- changes to this directory
#	- changes back to parent directory
#	- removes a remote directory foo
#
proc test_30dir {loop} {
global test

	# check if enabled
	if {!$test(dir)} {return}
	ftp::DisplayMsg $test(conn) "*** TEST $loop.3 (directory commands cd,mkdir,rmdir) ***" header
	ftp::Pwd $test(conn)
	ftp::MkDir $test(conn) foo$test(pid)
	ftp::Cd $test(conn) foo$test(pid)
	ftp::Pwd $test(conn)
	ftp::Cd $test(conn) ..
	ftp::Pwd $test(conn)
	ftp::RmDir $test(conn) foo$test(pid)
}

#
# 4.) ascii put/get and delete
#	- go to ascii mode
#	- store a file to remote site
#	- retrieve the same file from remote site
#	- delete a file on remote site
#	- compare the size of both files
#	  (file sizes should be equal or only the "\r" difference 
#	   between DOS/WINDOWS <> UNIX
#
proc test_40afile {loop} {
global test

	# check if enabled
	if {!$test(afile)} {return}

	ftp::DisplayMsg $test(conn) "*** TEST $loop.4 (put/get ascii files) ***" header
	set ascii_file ftpdemo.tcl
	set lsize [file size $ascii_file]
	ftp::Type $test(conn) ascii	
	ftp::Put $test(conn) $ascii_file ignore$test(pid).tmp

	# FileSize only works proper in binary mode
	ftp::Type $test(conn) binary
	set rsize [ftp::FileSize $test(conn) ignore$test(pid).tmp]
	ftp::Type $test(conn) ascii	
	ftp::Get $test(conn) ignore$test(pid).tmp
	ftp::Delete $test(conn) ignore$test(pid).tmp

	catch {
	  	ftp::DisplayMsg $test(conn) "Original File:\t$lsize bytes"
		ftp::DisplayMsg $test(conn) "Stored File:\t$rsize bytes"
  		ftp::DisplayMsg $test(conn) "Retrieved File:\t[file size ignore$test(pid).tmp] bytes"
		file delete ignore$test(pid).tmp	}

}

#
# 5.) binary put/get
#	- switch to binary mode
#	- store a file to remote site
#	- retrieve the same file from remote site
#	- delete a file on remote site
#	- compare the size of both files
#
proc test_50bfile {loop} {
global test tk_library

	# check if enabled
	if {!$test(bfile)} {return}

	ftp::DisplayMsg $test(conn) "*** TEST $loop.5 (put/get binary files) ***" header
	set bin_file $tk_library/demos/images/teapot.ppm
	set lsize [file size $bin_file]
	ftp::Type $test(conn) binary

	# Put with ProgressBar
	#   - ProgressBar init ...
	#   - ProgressBar update ... callback defined in ftp!
	#   - ProgressBar done
	ProgressBar init 0 $lsize teapot.ppm
	ftp::Put $test(conn) $bin_file ignore$test(pid).tmp
	ProgressBar done
	
	# Put with ProgressBar
	set rsize [ftp::FileSize $test(conn) ignore$test(pid).tmp]
	ProgressBar init 0 $rsize ignore$test(pid).tmp
	ftp::Get $test(conn) ignore$test(pid).tmp
	ProgressBar done
	
	ftp::Delete $test(conn) ignore$test(pid).tmp

	catch {
		ftp::DisplayMsg $test(conn) "Original File:\t$lsize bytes"
		ftp::DisplayMsg $test(conn) "Stored File:\t$rsize bytes"
		ftp::DisplayMsg $test(conn) "Retrieved File:\t[file size ignore$test(pid).tmp] bytes"
		file delete ignore$test(pid).tmp
	}
	
}

#
# 6.) rename
#	- stores a binary file on remote site and renames it
#
proc test_60ren {loop} {
global test tk_library

	# check if enabled
	if {!$test(ren)} {return}

	ftp::DisplayMsg $test(conn) "*** TEST $loop.6 (renaming remote files) ***" header
	set bin_file $tk_library/demos/images/earth.gif
	ftp::Type $test(conn) binary
	ftp::Put $test(conn) $bin_file ignore$test(pid).tmp
	ftp::Rename $test(conn) ignore$test(pid).tmp renamed$test(pid).tmp 
	ftp::Delete $test(conn) renamed$test(pid).tmp	

}
#
# 7.) append
#	- go to ascii mode
#	- store a ascii file to remote site
#	- appends ascci file on remote site and renames it
#	- delete a file on remote site
#	- compare the size of both files 
#	  remote file must have the double size
#	  (file sizes should be equal or only the "\r" difference 
#	   between DOS/WINDOWS <> UNIX
#
proc test_70append {loop} {
global test tk_library

	# check if enabled
	if {!$test(append)} {return}

	ftp::DisplayMsg $test(conn) "*** TEST $loop.7 (append ascii file) ***" header
	set ascii_file ftpdemo.tcl
	set lsize [file size $ascii_file]
	ftp::Type $test(conn) ascii	
	ftp::Append $test(conn) $ascii_file ignore$test(pid).tmp
	ftp::Append $test(conn) $ascii_file ignore$test(pid).tmp
	ftp::Get $test(conn) ignore$test(pid).tmp
	ftp::Delete $test(conn) ignore$test(pid).tmp

	catch {
	  	ftp::DisplayMsg $test(conn) "Original File:\t$lsize bytes ( * 2 = [expr {$lsize * 2}])"
  		ftp::DisplayMsg $test(conn) "Appended File:\t[file size ignore$test(pid).tmp] bytes"
		file delete ignore$test(pid).tmp	}

}

#
# 8.) newer
#	- create a local copy of a a file
#	- create a remote copy of a a file
#	- check date entries
#	- transfer only if the specifieid file is newer
#
proc test_80new {loop} {
global test tk_library

	# check if enabled
	if {!$test(new)} {return}

	ftp::DisplayMsg $test(conn) "*** TEST $loop.8 (newer) ***" header
	set bin_file $tk_library/demos/images/earth.gif
	ftp::Type $test(conn) binary

	file copy $bin_file ignore$test(pid).tmp
	ftp::Put $test(conn) $bin_file ignore$test(pid).tmp
	set datestr "%m/%d/%Y, %H:%M"

	set out {}
	catch {
	 	append out "Local File:\t[clock format [file mtime ignore$test(pid).tmp] -format $datestr -gmt 1]" \n
		append out "Remote File:\t[clock format [ftp::ModTime $test(conn) ignore$test(pid).tmp] -format $datestr -gmt 1]" \n
	}

	ftp::Newer $test(conn) ignore$test(pid).tmp	
	
	catch {	
		append out "Local File:\t[clock format [file mtime ignore$test(pid).tmp] -format $datestr -gmt 1] (after ftp::Newer)" 
	}

	ftp::Delete $test(conn) ignore$test(pid).tmp
	catch {file delete ignore$test(pid).tmp}
	ftp::DisplayMsg $test(conn) $out

}

#
# 9.) reget - reget command
#	- store file to remote site
#	- write 6 bytes to local file
#	- test the reget at position 6
#
proc test_90reget {loop} {
global test tk_library

	# check if enabled
	if {!$test(reget)} {return}

	ftp::DisplayMsg $test(conn) "*** TEST $loop.9 (reget command) ***" header
	set bin_file $tk_library/demos/images/earth.gif
	ftp::Type $test(conn) binary
	ftp::Put $test(conn) $bin_file ignore$test(pid).tmp
	set f [open ignore$test(pid).tmp w]
	puts -nonewline $f "123456"
	close $f
	ftp::Reget $test(conn) ignore$test(pid).tmp
	ftp::Delete $test(conn) ignore$test(pid).tmp

	catch {
		ftp::DisplayMsg $test(conn) "Original File:\t\t[file size $bin_file]"
		ftp::DisplayMsg $test(conn) "Transfered  File:\t[file size ignore$test(pid).tmp]"
		file delete ignore$test(pid).tmp
	}
}

##
# 10.) not existing file/directory
#	all command with a not existing file name as parameter
#	- nlist, filesize, modtime, delete, rename, cd, rmdir, put, get, reget, newer
#	- write 6 bytes to local file
#	- test the reget at position 6
#
proc test_99notfound {loop} {
global test tk_library

	# check if enabled
	if {!$test(notfound)} {return}

	ftp::DisplayMsg $test(conn) "*** TEST $loop.10 (not existing file/directory) ***" header
	ftp::NList $test(conn) filenotfound		
	ftp::FileSize $test(conn) filenotfound		
	ftp::ModTime $test(conn) filenotfound		
	ftp::Rename $test(conn) filenotfound filenotfound
	ftp::Delete $test(conn) filenotfound
	ftp::Cd $test(conn) filenotfound
	ftp::RmDir $test(conn) filenotfound
	ftp::Put $test(conn) filenotfound
	ftp::Get $test(conn) filenotfound
	ftp::Reget $test(conn) filenotfound
	ftp::Newer $test(conn) filenotfound
}

# save preferences
proc SaveConfig {} {
global cnf

	set cnf(server) [.op.f.f1.server.e get]
	set cnf(port) [.op.f.f1.port.e get]
	set cnf(username) [.op.f.f1.username.e get]
	set cnf(password) [.op.f.f1.password.e get]
	set cnf(directory) [.op.f.f1.directory.e get]
	set cnf(loops) [.op.f.f2.loops.e get]
	set cnf(debug) $ftp::DEBUG
	set cnf(verbose) $ftp::VERBOSE

	set f [open $cnf(configfile) w]
	puts $f  [array get cnf]	
	close $f
}

# load preferences
proc LoadConfig {} {
global cnf

	# Defaults
	set cnf(server) "xxx"
	set cnf(port) 21
	set cnf(username) "xxx"
	set cnf(password) "xxx"
	set cnf(directory) ""
	set cnf(loops) 1
	set cnf(debug) 0
	set cnf(verbose) 1
	
	if {[file exists $cnf(configfile)]} {
		set f [open $cnf(configfile) r]
		array set cnf [read $f]
		close $f
	}
	
	.op.f.f1.server.e delete 0 end
	.op.f.f1.server.e insert 0 $cnf(server)
	.op.f.f1.port.e delete 0 end
	.op.f.f1.port.e insert 0 $cnf(port)
	.op.f.f1.username.e delete 0 end
	.op.f.f1.username.e insert 0 $cnf(username)
	.op.f.f1.password.e delete 0 end
	.op.f.f1.password.e insert 0 $cnf(password)
	.op.f.f1.directory.e delete 0 end
	.op.f.f1.directory.e insert 0 $cnf(directory)
	.op.f.f2.loops.e delete 0 end
	.op.f.f2.loops.e insert 0 $cnf(loops)
	set ::ftp::DEBUG $cnf(debug)
	set ::ftp::VERBOSE $cnf(verbose)
}

# stop the test
proc StopTest {} {
global test
	set test(break) 1
}

# start the test
proc StartTest {} {
global test

	.but.f.f1.stop configure -state normal
	.but.f.f1.start configure -state disabled
	
	.msg.f.f2.text configure -state normal
	.msg.f.f2.text delete 1.0 end
	.msg.f.f2.text configure -state disabled -fg black

	set loops [.op.f.f2.loops.e get]
	set server [.op.f.f1.server.e get]
	set port [.op.f.f1.port.e get]
	set username [.op.f.f1.username.e get]
	set passwd [.op.f.f1.password.e get]
	set dir [.op.f.f1.directory.e get]

	# open a ftp server connection
	set test(errors) 0
	set test(open) {}
	set test(pid) [pid]
	set start_time [clock seconds]
 	ftp::DisplayMsg "" "*** Test started at [clock format [clock seconds]  -format %d.%m.%Y\ %H:%M:%S ] ..." header
	if {[set conn [ftp::Open $server $username $passwd -port $port -progress {ProgressBar update} -mode $test(mode) -blocksize 8196 -timeout 60]] >= 0} {

		if {$test(quote)} {
			ftp::DisplayMsg $conn [ftp::Quote $conn syst]
    			ftp::DisplayMsg $conn [ftp::Quote $conn site umask 022]
    			ftp::DisplayMsg $conn [ftp::Quote $conn help]
    		}
    		   
    		   
		if { $dir != "" } {
			ftp::Cd $conn $dir
		}
		
    		# begin test loop
    		set test(break) 0
                set test(conn) $conn
    		for {set test(loop) 1} {$test(loop) <= $loops} {incr test(loop)} {
    			if {$test(break)} {break}
			foreach test(proc) [lsort [info proc test*]] {
    				if {$test(break)} {break}
    				
    				# count entries in the after queues
    				set test(after) [after info]

    				# run procedure
				eval $test(proc) $test(loop) 
			}
    		}
    		if {$test(break)} {
    			ftp::DisplayMsg "... user break!" error
    		} else {
			incr test(loop) -1
		}
		
    		ftp::Close $conn
		set stop_time [clock seconds]
		set elapsed [expr {$stop_time - $start_time}]
		if { $elapsed == 0 } { set elapsed 1}
    		ftp::DisplayMsg "" "************************* THE END *************************" header
    		ftp::DisplayMsg "" "=> $loops iterations takes $elapsed seconds" 
 		ftp::DisplayMsg "" "=> $test(errors) error(s) occured" 
	}
	.but.f.f1.stop configure -state disabled
	.but.f.f1.start configure -state normal
}

# Help
proc Help {} {
	.msg.f.f2.text configure -state normal
	.msg.f.f2.text delete 1.0 end
	.msg.f.f2.text insert 1.0 "          **** CONFIGURATION HELP *****
	
Ftp_demo is the simple user interface to the ftp test program. It
checks all ftp commands of the FTP library package against an
existing FTP server. It requires some configuration entries specified
in the form below.

- Host ... Host FTP server on which the connection will be established
- Username ... Users login name at host 
- Password ... Users password at host 
- Directory ... Starting directory when differs from root \"/\"
- Iterations ... Count of interations for the test algorithm (default 1)	

The message window shows all responses from the remote server, as well
as report on data transfer statistics and file sizes. Two switches 
toggles enhanced output:

1. Debug...Enables debugging (return code, state, real FTP commands )
2. Verbose ... Forces to show all responses from the FTP server 

Active or passive file transfer mode is selected in the upper frame.
When ftpdemo uses the active mode it waits for the server to open
a connection to transfer files or get file listings. In passive mode
the server waits for ftpdemo to open a connection to transfer files
or get file listings. Passive mode is normally a requirement when
accessing sites via a firewall.

Press \"Save Options\" to save these options in a configuration file. 
Options will be restored next time you start the ftpdemo program.
Check marked test commands and start test by pressing \"Start test\"
button. Any time the test program can be canceled by pressing the
\"Stop test\" button.
 
NOTE:
-----
THE FTP_DEMO PROGRAM IS A DEVELOPMENT AND DEBUGGING TOOL RATHER THAN
A USEFUL FTP USER INTERFACE. FEEL FREE TO USE IT.


			***"
	.msg.f.f2.text configure -state disabled -fg darkgreen
}

################ main ##########################################################################

# default file transfer mode ... active
set test(mode) active

# Configuration file
set cnf(configfile) "ftpdemo.cnf"
LoadConfig

Help







