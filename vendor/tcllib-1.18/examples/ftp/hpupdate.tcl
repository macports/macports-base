#!/usr/bin/env tclsh
## -*- tcl -*-
#  - homepage update program using FTP -
#
#   Required:   tcl/tk8.2
#
#   Created:    12/96 
#   Changed:    7/2000
#   Version:    2.0
#
#   Copyright (C) 1998 Steffen Traeger
#	EMAIL:  Steffen.Traeger@t-online.de
#	URL:    http://home.t-online.de/home/Steffen.Traeger
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
########################################################################

# load required FTP package library 
package require Tcl 8.3
package require ftp 2.0
package require Tk
if {![llength [info commands tkButtonInvoke]]} {
    ::tk::unsupported::ExposePrivateCommand tkButtonInvoke
}

# LED Colors
set status(off) "#006666"
set status(on)  "#00ff00"
set ftp(Mode) passive

# set palette under X
if { [string range [winfo server .] 0 0] == "X" } {
	set tk_strictMotif 1
	tk_setPalette LightGray
	option add *font                        {Helvetica 12}
	option add *Text.foreground             black
	option add *Text.background             white
	option add *Listbox.background          white
	option add *Listbox.selectForeground    white  
	option add *Entry.background            white
	option add *Entry.selectBackground      black
	option add *Entry.selectForeground      white
	option add *Scrollbar.width             12
}
	
# main window
wm title . "hpupdate 2.0"
wm iconname . hpupdate
wm minsize . 1 1

# Menue
menu .menu -tearoff 0
menu .menu.file -tearoff 0
.menu add cascade -label "File" -menu .menu.file -underline 0
.menu.file add command -label "Connect" -underline 0 -command {BusyCommand Connect} -accelerator Alt+C
.menu.file add command -label "Disconnect" -underline 1 -state disabled -command {BusyCommand Disconnect} -accelerator Alt+I
.menu.file add separator
.menu.file add command -label "Exit" -underline 0 -command Quit -accelerator Alt+X

#menu .menu.edit -tearoff 0
#.menu add cascade -label "Bearbeiten" -menu .menu.edit -underline 0
#.menu.edit add command -label "Alle Löschen" -underline 0 -state disabled -command {
#	.view.remote.list selection set 0 end; BusyCommand DeleteremoteFiles}
#.menu.edit add command -label "Alle Übertragen" -underline 0 -state disabled -command Quit

menu .menu.view -tearoff 0
.menu add cascade -label "View" -menu .menu.view -underline 0
.menu.view add command -label "Refresh" -underline 0 -command {BusyCommand Refresh} -accelerator Alt+R

menu .menu.options -tearoff 0
.menu add cascade -label "Options" -menu .menu.options -underline 0
.menu.options add command -label "Preferences" -underline 0 -command {BusyCommand Config} -accelerator Alt+P

menu .menu.help -tearoff 0
.menu add cascade -label "Help" -menu .menu.help -underline 0
.menu.help add command -label "Overview" -underline 0 -command {Help overview}
.menu.help add command -label "Installation" -underline 0 -command {Help install}
.menu.help add command -label "Usage" -underline 0 -command {Help usage}
.menu.help add separator
.menu.help add command -label "About" -underline 1 -command {Help about}

. configure -menu .menu

# View area
frame .status -bd 1 -relief flat
  pack .status -in . -side bottom -fill x
frame .view -bd 1 -relief flat
  pack .view -in . -side top -expand 1 -fill both

# Status
frame .status.head -bd 1 -relief sunken
  pack .status.head -in .status -side top -fill x
label .status.head.label -textvariable status(header) -relief raised -anchor w -bd 1
  pack .status.head.label -in .status.head -side left -expand 1 -fill x -ipadx 2 -ipady 2
 
# Connection status
frame .view.conn -bd 1 -relief flat
  pack .view.conn -in .view -side top -fill both -padx 8
frame .view.conn.led1 -bd 2 -relief raised -width 20 -height 10 
  pack .view.conn.led1 -in .view.conn -side left -fill x -padx 3
label .view.conn.lab1 -text "No Connection!" -relief flat -anchor w -bd 1 -font {Helvetica 8}
  pack .view.conn.lab1 -in .view.conn -side left -fill x  -padx 3
checkbutton .view.conn.check -text "syncronize scrollbars" -takefocus 0 -variable ftp(SyncScroll) \
	-command SyncScroll -relief flat -anchor w -bd 2 -font {Helvetica 12}
  pack .view.conn.check -in .view.conn -side right 

# Separator
frame .view.line -bd 1 -height 2 -relief sunken
  pack .view.line -in .view -side top -fill x -padx 8 -pady 5

# Dummy
frame .view.dummy -bd 1 -height 5 -relief flat
  pack .view.dummy -in .view -side bottom -fill x -padx 8 -pady 5

# Remote directory
frame .view.remote -bd 1
  pack .view.remote -in .view -side right -expand 1 -fill both -padx 5
frame .view.remote.status -bd 0
  pack .view.remote.status -in .view.remote -side top -fill x
label .view.remote.status.label -text "Remote: " -anchor w -relief flat -font {Helvetica 12 italic}
  pack .view.remote.status.label -in .view.remote.status -side left
label .view.remote.status.mark -text "" -anchor w -relief flat -font {Helvetica 10}
  pack .view.remote.status.mark -in .view.remote.status -side right
label .view.remote.status.use -text "0K" -anchor w  -relief flat  -fg #0000ff
  pack .view.remote.status.use -in .view.remote.status -side left

frame .view.remote.buttons -bd 1
  pack .view.remote.buttons -in .view.remote -side bottom -fill x
button .view.remote.buttons.delete -text "Delete" -under 0 -state disabled -command {BusyCommand DeleteRemoteFiles}
  pack .view.remote.buttons.delete -in .view.remote.buttons -side top -pady 1m
scrollbar .view.remote.yscroll -relief sunken -takefocus 0 -command ".view.remote.list yview"
  pack .view.remote.yscroll -in .view.remote -side right -fill y
scrollbar .view.remote.xscroll -relief sunken -orient horizontal -takefocus 0 -command ".view.remote.list xview"
  pack .view.remote.xscroll -in .view.remote -side bottom -fill x
listbox .view.remote.list -relief sunken -xscroll ".view.remote.xscroll set" -yscroll ".view.remote.yscroll set" \
	-width 40 -height 24 -font {Courier 12} \
	-exportselection 0 -selectmode multiple -takefocus 0 -selectbackground #ff0000
 pack .view.remote.list -in .view.remote -side left -expand 1 -fill both

# Local directory
frame .view.local -bd 1
  pack .view.local -in .view -side left -expand 1 -fill both -padx 5
frame .view.local.status -bd 0
  pack .view.local.status -in .view.local -side top -fill x
label .view.local.status.label -text "Local: " -anchor w -relief flat -font {Helvetica 12 italic}
  pack .view.local.status.label -in .view.local.status -side left
label .view.local.status.mark -text "" -anchor w -relief flat -font {Helvetica 10}
  pack .view.local.status.mark -in .view.local.status -side right
label .view.local.status.use -text "0K" -anchor w  -relief flat -fg #0000ff
  pack .view.local.status.use -in .view.local.status -side left
 
frame .view.local.buttons -bd 1
  pack .view.local.buttons -in .view.local -side bottom -fill x
button .view.local.buttons.transfer -text "Upload->" -under 0 -state disabled -command UpdateRemoteFiles
  pack .view.local.buttons.transfer -in .view.local.buttons -side top -pady 1m
scrollbar .view.local.yscroll -relief sunken -takefocus 0 -command ".view.local.list yview"
  pack .view.local.yscroll -in .view.local -side right -fill y
scrollbar .view.local.xscroll -relief sunken -orient horizontal -takefocus 0 -command ".view.local.list xview"
  pack .view.local.xscroll -in .view.local -side bottom -fill x
listbox .view.local.list -relief sunken -xscroll ".view.local.xscroll set" -yscroll ".view.local.yscroll set" \
	-width 40 -height 24 -font {Courier 12} \
	-exportselection 0 -selectmode multiple -takefocus 0 -selectbackground #000080
 pack .view.local.list -in .view.local -side left -expand 1 -fill both

# Shows selected files 
bindtags .view.local.list {Listbox . all .view.local.list}
bindtags .view.remote.list {Listbox . all .view.remote.list}
bind .view.local.list <ButtonRelease-1> {Showselected local}
bind .view.remote.list <ButtonRelease-1> {Showselected remote}

# Acc. Keys
bind . <Meta-c> {BusyCommand Connect}
bind . <Meta-i> {BusyCommand Disconnect}
bind . <Meta-r> {BusyCommand Refresh}
bind . <Meta-p> {BusyCommand Config}
bind . <Meta-u> "tkButtonInvoke .view.local.buttons.transfer"
bind . <Meta-d> "tkButtonInvoke .view.remote.buttons.delete"
bind . <Meta-x> Quit

proc SyncY {args} {
	eval .view.local.list yview $args
	eval .view.remote.list yview $args
}

proc SyncX {args} {
	eval .view.local.list xview $args
	eval .view.remote.list xview $args
}

# Syncron Scrollbars
proc SyncScroll {} {
global ftp
	if { $ftp(SyncScroll) == 1} {
		.view.local.yscroll configure -command SyncY
		.view.remote.yscroll configure -command SyncY
		.view.local.xscroll configure -command SyncX
		.view.remote.xscroll configure -command SyncX
	} else {
		.view.local.yscroll configure -command ".view.local.list yview"
		.view.remote.yscroll configure -command ".view.remote.list yview"
		.view.local.xscroll configure -command ".view.local.list xview"
		.view.remote.xscroll configure -command ".view.remote.list xview"
	}
}

# messages
proc ftp::DisplayMsg {s msg {state normal}} {
global status

	switch -- $state {
	  data	        {return}
	  control       {return}
	  normal        {.status.head.label configure -fg black}
	  error         {.status.head.label configure -fg red}
	}	 
	set status(header) $msg
	update idletasks
}

################################################
#
#	Procedures
#
################################################

# hourglass
proc BusyCommand {args} {
	set command $args
	set busy {.menu .view .status}
	set window_list {.menu .view .status}
	while {$window_list != ""} {
		set next {}
		foreach w $window_list {
			set class [winfo class $w]
			set cursor [lindex [$w config -cursor] 4]
			if {[winfo toplevel $w] == $w || $cursor != ""} {
				lappend busy [list $w $cursor]
			}
			set next [concat $next [winfo children $w]]
		}
		set window_list $next
	}
	foreach w $busy {
		catch { grab set [lindex $w 0]}
		catch {[lindex $w 0] config -cursor watch}
	}
	update idletasks
	set error [catch {uplevel eval [list $command]} g]
	foreach w $busy {
		catch {grab release [lindex $w 0]}
		catch {[lindex $w 0] config -cursor [lindex $w 1]}
	}
	if { !$error } {
		return $g
	} else {
		bgerror $g
	}
	return ""
}

# read recursive the remote directory tree
proc GetRemoteTree {{dir ""}} {
global ftp

	foreach i [ftp::List $ftp(conn) $dir] {
		set rc [scan $i "%s %s %s %s %s %s %s %s %s" perm l u g size d1 d2 d3 name]
		if {$rc == "9"} {
		
			if { ($name == ".") || ($name == "..") } {
				continue
			}
		
			set type [string range $perm 0 0]
			if { $dir != "" } {
				regsub {\./} [file join $dir $name] "" name
			}
			switch -- $type {
				d {
					lappend ftp(remoteDirList) $name
					lappend ftp(remoteFileList) "$name"
					lappend ftp(remoteSizeList) $size
					GetRemoteTree $name
				  }

				- {	
					lappend ftp(remoteFileList) "$name"
					lappend ftp(remoteSizeList) $size
				  }

				default {       
					lappend ftp(remoteFileList) "$name"
					lappend ftp(remoteSizeList) $size
				  }
			}
		}	        
	}
}

# read remote directory
proc ReadRemoteDir {} {
global ftp opt

	# connected?
	if {(![info exists ftp(conn)]) ||
            (![info exists ftp::ftp${ftp(conn)}(State)])} {
		.view.remote.list delete 0 end
		return
	}

	focus .view.remote.list
	.view.remote.list delete 0 end
	.view.remote.list insert end "Working..."
	update idletasks

	set ftp(remoteDirList) {}
	set ftp(remoteFileList) {}
	set ftp(remoteSizeList) {}
	GetRemoteTree .

	foreach name $ftp(remoteFileList) {
		if { [string length $name] > $ftp(MaxLength) } {
			set ftp(MaxLength) [string length $name]
		}
	}	

	set max_length $ftp(MaxLength)
	.view.remote.list delete 0 end
	update idletasks
	set index 0
	foreach i $ftp(remoteFileList) {

		set name $i
		set size [lindex $ftp(remoteSizeList) $index ]
		set entry [format "%-${max_length}s %8s" $name $size]
		.view.remote.list insert end $entry

		# If file doesn't exist on local location then mark it to delete
		set index [lsearch -regexp [.view.local.list get 0 end] "^$name "]
		if { $index == "-1" } {
			.view.remote.list selection set end end
		}
		incr index
		
	}

	ShowUsed remote
	Showselected remote
	ReadLocalDir
}

# shine a light 
proc Blink {mode} {
global status
	switch -- $mode {
	  on {
		.view.conn.led1 configure -bg $status(on)
		update idletasks
	  }
	  off {
		.view.conn.led1 configure -bg $status(off)
		update idletasks
	  }
	}
}

# connect to ftp server
proc Connect {} {
global ftp opt
	ftp::DisplayMsg "" " ftp> Trying connect to ftp server..."
	Blink on
	if {[set ftp(conn) [ftp::Open $opt(Server) $opt(Username) $opt(Password) -progress {ProgressBar update} ]] == -1} {
		Blink off
		ShowStatus
		return
	}

	# remote homepage directory
	if {![ftp::Cd $ftp(conn) $opt(remoteDir)]} {
		tk_messageBox -parent . -title INFO -message "Directory $opt(remoteDir) on remote ftp server not found!" -type ok
		Disconnect
		return
	}

	ftp::DisplayMsg $ftp(conn) "Connected to ftp service on $opt(Server)!" 
	ReadRemoteDir
	.view.local.buttons.transfer configure -state normal
	.view.remote.buttons.delete configure -state normal
	.menu.file entryconfigure 0 -state disabled
	.menu.file entryconfigure 1 -state normal
	ShowStatus
}

# Remove connection to file server
proc Disconnect {} {
global ftp

	# connected?
	if {([info exists ftp(conn)]) &&
            ([info exists ftp::ftp${ftp(conn)}(State)])} {
		ftp::Close $ftp(conn)
		ftp::DisplayMsg "" "Connection closed!"
	}
        if {[info exists ftp(conn)]} {
            unset ftp(conn)
        }
	set ftp(remoteSizeList) {}
	.view.remote.list delete 0 end
	.view.local.buttons.transfer configure -state disabled
	.view.remote.buttons.delete configure -state disabled
	.menu.file entryconfigure 0 -state normal
	.menu.file entryconfigure 1 -state disabled
	ShowStatus
	ShowUsed remote
	Showselected remote
}

# Display connection status
proc ShowStatus {} {
global status
	if {([info exists ftp(conn)]) &&
            ([info exists ftp::ftp${ftp(conn)}(State)])} {
		.view.conn.led1 configure -bg $status(on) 
		.view.conn.lab1 configure -text "connected"
		update idletasks
	} else {
		.view.conn.led1 configure -bg $status(off)
		.view.conn.lab1 configure -text "not connected"
		update idletasks
	}
}

# display used directory size 
proc ShowUsed {mode} {
global ftp
	set sum 0
	foreach i $ftp(${mode}SizeList) {
		incr sum $i
	}

#	if { $sum > [ expr {1024 * 1024}] } {
#	        set color #ff0000
#	} else {
#	        set color #0000ff
#	}

	set color #0000ff
	.view.$mode.status.use configure -text "[expr {round($sum / 1024.0)}] KB" -fg $color
	update idletasks
}

# display selected directory size 
proc Showselected {mode} {
global ftp
	set sum 0
	set count 0
	if { ([info exists ftp(${mode}SizeList)]) && ([llength $ftp(${mode}SizeList)] != 0) } {
		foreach i [.view.$mode.list curselection] {
			incr sum [lindex $ftp(${mode}SizeList) $i]
			incr count
		}
	}
	.view.$mode.status.mark configure -text  "[expr {round($sum / 1024.0)}] KB \[$count\]"
	update idletasks
}


# read recursive the local directory tree
proc GetLocalTree {dir} {
global ftp
	foreach i [lsort [glob -nocomplain $dir/* $dir/.*]] {
		regsub {\./} $i "" i
		if { ([file tail $i] != ".") && ([file tail $i] != "..") } {

			# exist check
			if {![file exists $i]} {
				continue
			}

			if {[file isdirectory $i]} {
				lappend ftp(localFileList) $i
				lappend ftp(localDirList) $i
				GetLocalTree $i
			} else {
				lappend ftp(localFileList) $i
			}
		}
	}
}

# read local directory
proc ReadLocalDir {} {
global opt ftp

	.view.local.list delete 0 end
	.view.local.list insert end "Working..."
	update

	# local homepage directory
	if {![file isdirectory $opt(localDir)]} {
		tk_messageBox -parent . -title INFO -message "Directory $opt(localDir) not found!" -type ok
		return
		
	}

	# read local homepage directory 
	set ftp(localDirList) {}
	set ftp(localFileList) {}
	set ftp(localSizeList) {}
	cd $opt(localDir)
	GetLocalTree .

	foreach name $ftp(localFileList) {
		if { [string length $name] > $ftp(MaxLength) } {
			set ftp(MaxLength) [string length $name]
		}
	}

	set max_length $ftp(MaxLength)
	.view.local.list delete 0 end
	update idletask
	foreach i $ftp(localFileList) {
	
		set name $i
		set size [file size $name]
		set entry [format "%-${max_length}s %8s" $name $size]
		.view.local.list insert end $entry
		lappend ftp(localSizeList) $size
	
		# if updated then mark to upload 
		if { [file mtime $name] > $opt(Timestamp) } {
			.view.local.list selection set end end
		}

		# if not exist at remote machine then mark to upload 
		if {([info exists ftp(conn)]) &&
                    ([info exists ftp::ftp${ftp(conn)}(State)])} {
			set index [lsearch -regexp [.view.remote.list get 0 end] "^$name "]
			if { $index == "-1" } {
				.view.local.list selection set end end
			}
		}
	}
	
	ShowUsed local
	Showselected local
}

# delete files on remote site
proc DeleteRemoteFiles {} {
global ftp

	# connected?
	if {(![info exists ftp(conn)]) ||
            (![info exists ftp::ftp${ftp(conn)}(State)])} {
		tk_messageBox -parent . -title INFO -message "No connection!" -type ok
		return
	}
	# nothing choosed
	if { [.view.remote.list curselection] == {} } {
		return
	}
	# ask user
	set count [llength [.view.remote.list curselection]]
	set rc [tk_messageBox -parent . -title DELETE -message "Do you really want to delete the $count selected file(s)?" -type yesno]
	if { $rc == "no" } {
		return
	}

	# delete selected files
	focus .view.remote.list
	foreach i [lsort -integer -decreasing [.view.remote.list curselection]] {
		set filename [lindex [.view.remote.list get $i] 0]
		.view.remote.list see $i
		.view.remote.list activate $i
		update idletasks

		# file or directory?
		set index [lsearch -exact $ftp(remoteDirList) $filename]
		if { $index == "-1" } {
			set command "ftp::Delete"
		} else {
			set command "ftp::RmDir"
		}
		
		if {[eval $command $ftp(conn) $filename]} {
			.view.remote.list selection clear $i
			update idletasks
			set ftp(remoteSizeList) [lreplace $ftp(remoteSizeList) $i $i 0]
			ShowUsed remote
			Showselected remote
			Showselected local
		} else {
			tk_messageBox -parent . -title ERROR -message \
				"Error deleting $filename!" -icon error -type ok
			continue
		}	
	}
	BusyCommand Refresh
}

# Progress bar displayed in status line
proc ProgressBar {state {bytes 0} {filename ""}} {
global ftp
	set w .progress
	switch -- $state {
	  init	{
		set ftp(Filename) ""
		set ftp(ProgressProz) "0%"
		toplevel $w -bd 0 -class Progressbar
		wm transient $w .
		wm title $w Upload
		wm iconname $w Upload
		wm resizable $w 0 0
		focus $w
		grab $w
		
		frame $w.buttons
		  pack $w.buttons -side bottom -fill x -pady 2m
		button $w.buttons.esc -text "Cancel" -command "set ftp(escaped) 1"
		  pack $w.buttons.esc -in $w.buttons -side top

		frame $w.frame -bd 4
		  pack $w.frame -side top -fill both
		label $w.frame.label -textvariable ftp(Filename) -relief flat -anchor w -bd 1 -font {Helvetica 12}
		  pack $w.frame.label -in $w.frame -side top -fill x -padx 10 -pady 5
		frame $w.frame.line -bd 1 -height 2 -relief sunken
		  pack $w.frame.line -in $w.frame -side bottom -fill x -padx 2 -pady 5
		frame $w.frame.bar -bd 1 -relief sunken -bg #ffffff
		  pack $w.frame.bar -in $w.frame -side left -padx 10 -pady 5
		frame $w.frame.bar.dummy -bd 0 -width 200 -height 0
		  pack $w.frame.bar.dummy -in $w.frame.bar -side top -fill x
		frame $w.frame.bar.pbar -bd 0 -width 0 -height 20
		  pack $w.frame.bar.pbar -in $w.frame.bar -side left
		label $w.frame.proz -textvariable ftp(ProgressProz) -width 5 -relief flat -anchor e -bd 1 -font {Helvetica 12}
		  pack $w.frame.proz -in $w.frame -side right -padx 10 -pady 5

		wm withdraw $w
		update idletasks
		set x [expr {[winfo x .] + ([winfo width .] / 3) - ([winfo reqwidth $w] / 2)}]
		set y [expr {[winfo y .] + ([winfo height .] / 3) - ([winfo reqheight $w] / 2)}]
		wm geometry $w +$x+$y
		wm deiconify $w
		update idletasks
	  }
	  
	  reset { 
	  		set ftp(Filename) "Uploading $filename...."
			set index [lsearch $ftp(localFileList) $filename]
			if { $index != "-1" } {
				set ftp(progress_sum) [lindex $ftp(localSizeList) $index]
				if { $ftp(progress_sum) == 0 } {
					set ftp(progress_sum) 1
				}
			} else {
				set ftp(progress_sum) 1
			}
			ProgressBar update
			update idletasks
	  	}

	  update {
		if {![winfo exists $w]} {return}  
		set ftp(ProgressProz) "[expr {round( $bytes * 100 / $ftp(progress_sum))}]%"
		set cur_width [expr {round($bytes * 200 / $ftp(progress_sum))}]
		$w.frame.bar.pbar configure -width $cur_width -bg #000080
		focus $w.buttons.esc
		update idletasks
		update
	  }

	  done	{
		set ftp(Filename) "Upload successful!"
		$w.buttons.esc configure -text "OK" -command "destroy $w"
		update idletasks
		tkwait window $w
	  }

	  escape {
		destroy $w
		BusyCommand Refresh
	  }  
	
	  error {
		destroy $w
	  }
	}
}

# upload local files to remote site
proc UpdateRemoteFiles {} {
global ftp opt status
	# connected?
	if {(![info exists ftp(conn)]) ||
            (![info exists ftp::ftp${ftp(conn)}(State)]) } {
		tk_messageBox -parent . -title INFO -message "No connection!" -type ok
		return 0
	}
	
	# nothing selected 
	if { [.view.local.list curselection] == {} } {
		return 0
	}
	
	# ask user
	set count [llength [.view.local.list curselection]]
	set rc [tk_messageBox -parent . -title UPLOAD -message "Do you really want to upload the $count selected file(s)?" -type yesno]
	if { $rc == "no" } {
		return 0
	}
	
	# create list of uploading files
	set upload_list {}
	foreach i [.view.local.list curselection] {
		lappend upload_list $i
	}
	
	# empty list?
	if { $upload_list == {} } {
		tk_messageBox -parent . -title INFO -type ok -message "Nothing selected for upload!!"
		return 0
	}
	focus .view.local.list

	# binary type for all files
	ftp::Type $ftp(conn) binary

	# upload files
	set ftp(escaped) 0
	ProgressBar init
	set ftp(ProgressCount) 0
	foreach i $upload_list {
		set filename [lindex [.view.local.list get $i] 0]
		.view.local.list see $i
		.view.local.list activate $i
		update idletasks	

		# file or directory?
		set index [lsearch -exact $ftp(localDirList) $filename]
		if { $index == "-1" } {
			set command "ftp::Put"
		} else {
		
			# directory already exists
			if { [lsearch -exact $ftp(remoteDirList) $filename] != "-1" } {
				continue
			}
			set command "ftp::MkDir"
		}

		ProgressBar reset 0 $filename
		if {[eval $command $ftp(conn) $filename]} {
			incr ftp(ProgressCount)
			if {$ftp(escaped)} {
				ProgressBar escape
				return 1
			}
			.view.local.list selection clear $i
		} else {
			tk_messageBox -parent . -title ERROR -message "Error uploading $filename!" -icon error -type ok
			ProgressBar error
			continue
		}
	}
	
	ProgressBar done

	# new timestamp
	Touch $opt(TsFile)
	set opt(Timestamp) [file mtime $opt(TsFile)]
	Refresh
	set status(header) " last update: [clock format $opt(Timestamp) -format %d.%m.%Y\ %H:%M:%S\ Uhr -gmt 0]"
	return 0
}

# Refresh
proc Refresh {} {
global ftp
	set ftp(MaxLength) 0
	ReadLocalDir
	ReadRemoteDir
	ShowStatus
	update idletasks
}


if {[package vcompare [info tclversion] 8.4] >= 0} {
    proc Touch {filename} {
	file mtime $filename [clock seconds]
    }
} else {
    # update timestamp
    proc Touch {filename} {
	set file [open $filename w]
	puts -nonewline $file ""
	close $file
    }
}


# quit hpupdate
proc Quit {} {
global ftp
	Disconnect
	destroy .
	exit 0
}


# save current configuration
proc SaveConfig {} {
global opt
	set file [open $opt(ConfigFile) w]
	puts $file  [array get opt]     
	close $file
}

# accept new configuraion
proc AcceptConfig {w} {
global opt ftp

	# get ftp server options
	set opt(Server) [$w.mask.server.entry get]
	set opt(Username) [$w.mask.user.entry get]
	set opt(Password) [$w.mask.passwd.entry get]
	set opt(remoteDir) [$w.mask.remote.entry get]
	
	# get local homepage direction
	set dir [$w.mask.local.entry get]
	if { ![file isdirectory $dir] } {
		tk_messageBox -parent . -title ERROR -message "Directory \"$dir\" not found!" -type ok
		return
	}
	set opt(localDir) [$w.mask.local.entry get]
	cd $opt(localDir)
	
	SaveConfig
	tk_messageBox -parent . -title INFO -message "Configuration applied and saved!" -type ok
	destroy $w
}

# ftp configuration
proc Config {} {
global opt

	# new window
	set w .config

	catch {destroy $w}
	toplevel $w -bd 0 -class Config
	wm transient $w .
	wm title $w "options"
	wm iconname $w "options"
	wm transient $w .
	wm minsize $w 10 10

	frame $w.mask -bd 1 -relief raised
	  pack $w.mask -in $w -side top -expand 1 -fill both 
	frame $w.control -bd 1 -relief raised
	  pack $w.control -in $w -side bottom -fill x

	frame $w.mask.server -bd 1
	  pack $w.mask.server -in $w.mask -side top -expand 1 -fill both -padx 3m -pady 3m
	label $w.mask.server.label -text "ftp server name:" -under 0 -anchor w
	  pack $w.mask.server.label -in $w.mask.server -side top -fill x
	entry $w.mask.server.entry -width 40
	  pack $w.mask.server.entry -in $w.mask.server -expand 1 -side left -fill x

	frame $w.mask.user -bd 1
	  pack $w.mask.user -in $w.mask -side top -expand 1 -fill both -padx 3m -pady 3m
	label $w.mask.user.label -text "User:" -under 0 -anchor w
	  pack $w.mask.user.label -in $w.mask.user -side top -fill x
	entry $w.mask.user.entry -width 40
	  pack $w.mask.user.entry -in $w.mask.user -expand 1 -side left -fill x

	frame $w.mask.passwd -bd 1
	  pack $w.mask.passwd -in $w.mask -side top -expand 1 -fill both -padx 3m -pady 3m
	label $w.mask.passwd.label -text "Password:" -under 0 -anchor w
	  pack $w.mask.passwd.label -in $w.mask.passwd -side top -fill x
	entry $w.mask.passwd.entry -show "*" -width 40
	  pack $w.mask.passwd.entry -in $w.mask.passwd -expand 1 -side left -fill x

	frame $w.mask.remote -bd 1
	  pack $w.mask.remote -in $w.mask -side top -expand 1 -fill both -padx 3m -pady 3m
	label $w.mask.remote.label -text "Remote directory:" -under 0 -anchor w
	  pack $w.mask.remote.label -in $w.mask.remote -side top -fill x
	entry $w.mask.remote.entry -width 40
	  pack $w.mask.remote.entry -in $w.mask.remote -expand 1 -side left -fill x

	frame $w.mask.local -bd 1
	  pack $w.mask.local -in $w.mask -side top -expand 1 -fill both -padx 3m -pady 3m
	label $w.mask.local.label -text "Local directory:" -under 0 -anchor w
	  pack $w.mask.local.label -in $w.mask.local -side top -fill x
	entry $w.mask.local.entry -width 40
	  pack $w.mask.local.entry -in $w.mask.local -expand 1 -side left -fill x

	button $w.control.accept -width 14 -text "Apply & Save" -under 0 -command "AcceptConfig $w"
	  pack $w.control.accept -in $w.control -side left -expand 1 -padx 3m -pady 2m
	button $w.control.quit -width 14 -text "Cancel" -under 0 -command "destroy $w"
	  pack $w.control.quit -in $w.control -side left -expand 1 -padx 3m -pady 2m


	# arrange window
	wm withdraw $w
	update idletasks
	set x [expr {[winfo x .] + ([winfo width .] / 3) - ([winfo reqwidth $w] / 2)}]
	set y [expr {[winfo y .] + ([winfo height .] / 3) - ([winfo reqheight $w] / 2)}]
	wm geometry $w +$x+$y
	wm deiconify $w

	$w.mask.server.entry delete 0 end
	$w.mask.server.entry insert 0 $opt(Server)
	$w.mask.user.entry delete 0 end
	$w.mask.user.entry insert 0 $opt(Username)
	$w.mask.passwd.entry delete 0 end
	$w.mask.passwd.entry insert 0 $opt(Password)
	$w.mask.local.entry delete 0 end
	$w.mask.local.entry insert 0 $opt(localDir)
	$w.mask.remote.entry delete 0 end
	$w.mask.remote.entry insert 0 $opt(remoteDir)

	bind $w <Meta-d> "tkButtonInvoke $w.mask.check.debug"
	bind $w <Meta-v> "tkButtonInvoke $w.mask.check.verbose"
	bind $w <Meta-f> "focus $w.mask.server.entry"
	bind $w <Meta-r> "focus $w.mask.remote.entry"
	bind $w <Meta-l> "focus $w.mask.local.entry"
	bind $w <Meta-s> "tkButtonInvoke $w.control.accept"
	bind $w <Meta-c> "tkButtonInvoke $w.control.cancel"

	focus -force $w.mask.server.entry
	update idletasks
}

proc Usage {} {
	puts "\nusage hpupdate \[-h\] \[directory\]"
	puts "	 -h          help"
	puts "	 directory   local directory"
	puts "	             (default: current directory)\n"
	exit 0
}

# Help
proc Help {mode} {

set help(overview) {
OVERVIEW
---------

In order to simplify the transfer of the files of my homepage to the 
FTP server of my Internet Service Provider, I looked at the end of 
1996 for an useful tool. Linux offered only the 
abilities of the ftp command line utility. As fan of 
Tcl/Tk, my selection immediately fell on "expect",  which was very suitable
to automate interactive processes like FTP sessions. A little bit 
more Tcl source code and hpupdate 0.1 was finished, a script for
automatic updating of my homepage files. 

At the beginning of 1997, I was more intensively occupied with the 
FTP protocol. At the same time I played with Tcl's socket command.
Thus the FTP library package for Tcl7.6 was developed. 
This forms the basis for hpupdate. 

So far, the program runs under Linux with Tcl/Tk 8.0. I have once 
tested it on Windows 3.11 (with Win32s) and Windows 95 and it runs 
perfectly. Today I have no experiences with Windows NT and
Macintosh. Perhaps somebody will be found who will test it in these 
environments. I would like to be informed of your experiences!
Thank you!

	usage:		hpupdate <directoy>
	
			example: hpupdate /home/user/hp

			***
}

set help(install) {
INSTALLATION
------------

The great advantage of hpupdate is its platform independence 
because of using Tcl/Tk.

If you do not have Tcl/Tk 8.0 installed already, at first you must 
install it. Get it from the known locations such as http://tcl.sf.net/
and follow the installation instructions. 

If you have not already installed the ftp library package, you must 
install it. Get it from my homepage and follow the 
installation instructions. 

Start up hpupdate and change the preferred options in option menu.
	
"ftp Server Name" 	- remote FTP server hostname
"User"			- valid username
"Password"		- valid password for user
"Remote Directory"	- remote root for homepage or empty (destination)
"Local Directory"	- local homepage directory (source)


			***
}

set help(usage) {
USAGE
-----

The hpupdate application is divided into 4 areas:

	1.) menu 
	2.) local file list (source)
	3.) remote file list (destination)
	4.) status line

1.) menu

		File / Connect
Opens a connection with the FTP server.
 
		File / Disconnetc
Closes an existing connection with the FTP server.
		
		File / Exit
Quits hpupdate, the connection to the FTP server will be 
closed automatically.

		View / Refresh
Reads new file data and refreshs it in the list.

		Options / Preferences
Interface to saving your login, password, ftp server, etc.
	
		Help / * look there 

2.) local file list 
This list contains the file names and sizes from the local
homepage directory. The file name, date and time-of-day 
of the files are compared with the time stamp of the remote files.
When getting the filename for this list, the date/time entry of each file
is read and compared with the timestamp of the last update.
Files which have a date and/or time newer than the remote file's timestamp
are detected as updated and marked for upload. 
It is also possible to mark/unmark the files manually per mouse click.
The capacity of all files in the directory is displayed in blue. 
Besides this, the capacity of the marked files, as well as the count of files
(in parentheses) are shown.

By pressing the button "Upload", all selected files in  the local 
homepage directory will be transfered to the remote FTP server.

3.) remote file list 
The files at the FTP site appear in this list after connection with
the FTP server. The remote files will be compared with the local files.
Files which are not in the local list are detected as superfluous
and marked for deletion.
It is also possible to mark/unmark files manually per mouse click.
The number of marked files is displayed in an extra frame.
Additionally, the summary disk space is shown. 
The capacity of all files in the directory is displayed in blue. 
Besides this, the capacity of all marked files as well as the count
(in parentheses) is shown.

By pressing the button "Delete", all selected files in the remote homepage
directory will be deleted.

NOTE: Synchronize the scrolling of both lists by pressing the checkbutton 
"sychronize scrollbars ".

4.) status line
The status line shows when the last update of the remote system has taken place.
This display is always updated after every file transfer.
Internally, the file "hpupdate.ts" is provided with a new timestamp.
After this moment, all modified local files are automatically detected
with the next refresh and marked for upload.

Error and status messages for the FTP connection are also displayed in
the status line.

EXTENSION:
The green LED shows the connection status, a lighter green means an
established connection.

			***
}

set help(about) {
  - hpupdate
  homepage update program using FTP 

  Required:   Tcl/Tk8.0x

  Created:    12/96 
  Changed:    04/2002
  Version:    2.1

  Copyright (C) 1997,1998, Steffen Traeger
        EMAIL:  Steffen.Traeger@t-online.de
        URL:    http://home.t-online.de/home/Steffen.Traeger
}

	set w .help
	catch {destroy $w}
 	toplevel $w -bd 0 -class Help
	wm transient $w .
	wm title $w "Help - $mode"
        wm iconname $w Hilfe
	wm minsize $w 10 10
	frame $w.buttons -bd 1 -relief flat 
	  pack $w.buttons -side bottom -fill x -pady 2m
	button $w.buttons.close -text "OK" -command "destroy $w"
	  pack $w.buttons.close -side left -expand 1
	frame $w.ftp -bd 1 -relief flat 
	  pack $w.ftp -side top -expand 1 -fill both
	scrollbar $w.ftp.yscroll -command "$w.ftp.text yview" 
	  pack $w.ftp.yscroll -in $w.ftp -side right -fill y
	scrollbar $w.ftp.xscroll -relief sunken -orient horizontal -command "$w.ftp.text xview" 
	  pack $w.ftp.xscroll -in $w.ftp -side bottom -fill x
	text $w.ftp.text -relief sunken -setgrid 1 -wrap none -height 15 -width 60 -bg white -fg black\
		-state normal  -xscrollcommand "$w.ftp.xscroll set" \
		-yscrollcommand "$w.ftp.yscroll set"
	  pack $w.ftp.text -in $w.ftp -side left  -expand 1 -fill both
	wm withdraw $w
	update idletasks
	set x [expr {[winfo x .] + ([winfo width .] / 3) - ([winfo reqwidth $w] / 2)}]
	set y [expr {[winfo y .] + ([winfo height .] / 3) - ([winfo reqheight $w] / 2)}]
 	wm geometry $w +$x+$y
	wm deiconify $w
	$w.ftp.text insert 0.0 $help($mode)
	$w.ftp.text configure -state disabled
	update idletasks

}
##################### main ###################################################

# determine working directory 
if { $argv != "" && $argv != "{}" } {
	if { [lindex $argv 0] == "-h" } {Usage}
	set dir [lindex $argv 0]
	if { [file exists $dir] && [file isdirectory $dir] } {
		set opt(localDir) $dir
	} else {
		puts "Directory \"$dir\" not found!"
		Usage
	}
} else {
	set opt(localDir) [pwd]
}	

# init defaults
set opt(Server) ""
set opt(Username) "anonymous"
set opt(Password) ""
set opt(remoteDir) "."
set opt(ConfigFile)     $env(HOME)/hpupdate.cnf
set opt(TsFile)         $env(HOME)/hpupdate.ts

# load configuration file
if { [file exists $opt(ConfigFile)] } {
	set file [open $opt(ConfigFile) r]
	array set opt [read $file]
	close $file
} 
set ftp::DEBUG 0
set ftp::VERBOSE 0

# to compare older and newer files hpupdate creates
# a new timesstamp on file "hpupdate.ts" after every update
if { ![file exists $opt(TsFile)] } {Touch $opt(TsFile)}
set opt(Timestamp) [file mtime $opt(TsFile)]
set status(header) " last update: [clock format $opt(Timestamp) -format %d.%m.%Y\ %H:%M:%S\ Uhr -gmt 0]"

BusyCommand Refresh

