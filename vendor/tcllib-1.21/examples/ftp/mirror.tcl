#!/usr/bin/env tclsh
## -*- tcl -*-

package require Tcl 8.3
package require ftp 2.0

# user configuration
set server noname
set username anonymous
set passwd xxxxxx 

# simple progress display
proc ProgressBar {bytes} {
    puts -nonewline stdout "."; flush stdout
}

# recursive file transfer 
proc GetTree {conn {dir ""}} {
    catch {file mkdir $dir}
    foreach line [ftp::List $conn $dir] {
    	set rc [scan $line "%s %s %s %s %s %s %s %s %s %s %s" \
            perm l u g size d1 d2 d3 name link linksource]
	if { ($name == ".") || ($name == "..") } {continue}
        set type [string range $perm 0 0]
        set name [file join $dir $name]
        switch -- $type {
            d {GetTree $name}
            l {catch {exec ln -s $linksource $name} msg}
            - {ftp::Get $conn $name}
        }
    }
}

# main	
if {[set conn [ftp::Open $server $username $passwd -progress ProgressBar]] != -1} {
    GetTree $conn
    ftp::Close $conn
    puts "OK!"
}

