#!/usr/bin/tclsh
# Traverse through all ports and try to build/install each one in a chroot
# tree.

# Not all of these may be necessary.  Prune (or add to) as actual experience
# subsequently dictates.
set chrootfiles {
	bin sbin etc tmp var dev/null usr/include usr/libexec
	usr/sbin usr/bin usr/lib usr/share private/tmp private/etc
	private/var/at private/var/cron private/var/db private/var/empty
	private/var/log private/var/mail private/var/msgs
	private/var/named private/var/root private/var/run
	private/var/rwho private/var/spool
	private/var/tmp private/var/vm/app_profile
	Developer/Applications/Xcode.app Developer/Applications/Utilities
	Developer/Headers Developer/Makefiles Developer/Private
	Developer/Tools System/Library/Frameworks System/Library/CoreServices
	System/Library/PrivateFrameworks System/Library/OpenSSL
	System/Library/PHP System/Library/Perl
}

proc makechroot {dir} {
	global env chrootfiles verbose REPORT REPDIR

	if {![file exists $dir]} {
		exec mkdir -p $dir
	} elseif {![file isdirectory $dir]} {
		puts "$dir must be a directory"
		exit 5
	}
	puts "Creating chroot environment in $dir"
	foreach idx $chrootfiles {
		if {[catch {exec tar -cpf - -C / $idx | tar -xpf - -C $dir}]} {
			puts "Warning: Unable to copy $idx into $dir"
		}
	}
	if {[file exists darwinports.tar.gz]} {
		puts "copying from local darwinports snapshot"
		exec tar -xpzf darwinports.tar.gz -C $dir
	} else {
		puts "Attempting to grab cvs snapshot of darwinports"
		if {![catch {exec curl -O http://darwinports.opendarwin.org/darwinports-nightly-cvs-snapshot.tar.gz}]} {
			exec tar -xpzf darwinports-nightly-cvs-snapshot.tar.gz -C $dir
		} else {
			puts "Unable to find darwinports anywhere.  I give up"
			exit 7
		}
	}
	exec mkdir -p $dir/.vol
	if {[catch {exec /sbin/mount_devfs devfs ${dir}/dev} result]} {
		puts "Warning: error mounting devfs: $result"
	}
	if {[catch {exec /sbin/mount_fdesc -o union fdesc ${dir}/dev} result]} {
		puts "Warning: error mounting fdesc: $result"
	}
	if {[catch {exec /sbin/mount_volfs ${dir}/.vol} result]} {
		puts "Warning: error mounting volfs: $result"
	}
	set f [open $dir/doit.tcl w 0755]
	puts $f "#!/usr/bin/tclsh"
	puts $f "set REPDIR $REPDIR"
	puts $f "set REPORT $REPORT"
	puts $f "exec rm -rf /etc/ports"
	puts $f "cd darwinports"
	puts $f {if {[catch {exec make all install} result]} { puts "Warning: darwinports make returned: $result" }}
	puts $f {set env(PATH) "$env(PATH):/opt/local/bin"}
	if {[info exists env(MASTER_SITE_LOCAL)]} {
		puts $f "set env(MASTER_SITE_LOCAL) $env(MASTER_SITE_LOCAL)"
	}
	puts $f [proc_disasm packageall]
	puts $f {if {[catch {packageall} result]} { puts "Warning: packageall returned: $result" }}
	close $f
}

proc packageall {} {
	global REPORT REPDIR verbose
	if {[catch {set out [open /dev/stdout w]}]} {
		set out stdout
	}

	if {[file exists PortIndex]} {
		set PI PortIndex
	} elseif {[file exists dports/PortIndex]} {
		set PI dports/PortIndex
	} else {
		puts $out "Unable to find PortIndex.  Please run me from darwinports dir"
		exit 2
	}

	if {[catch {set pifile [open $PI r]}]} {
		puts $out "Unable to open $PI - check permissions."
		exit 3
	}
	exec mkdir -p ${REPDIR}
	if {[catch {set repfile [open $REPORT w]}]} {
		puts $out "Unable to open $REPORT - check permissions."
		exit 4
	}
	puts $out "Doing initial installation of RPM bits.."
	flush $out
	if {[catch {exec port install rpm} result]} {
		puts $out "Unable to install rpm port: $result"
		exit 6
	}
	exec mkdir -p /Packages
	puts $out "Beginning packaging run.."
	flush $out
	while {[gets $pifile line] != -1} {
		if {[llength $line] != 2} continue
		set portname [lindex $line 0]
		puts -nonewline $out "Trying ${portname}..."
		flush $out
		if {[catch {exec port rpmpackage package.destpath=/Packages $portname >& ${REPDIR}/${portname}.out}]} {
			puts $repfile "$portname failure"
			flush $repfile
			puts $out " failed."
			flush $out
		} else {
			puts $repfile "$portname success"
			flush $repfile
			puts $out " succeeded."
			flush $out
			exec rm -f ${REPDIR}/${portname}.out
		}
	}
	close $pifile
	close $repfile
	if {"$out" != "stdout"} close $out
}

proc proc_disasm {pname} {
    set p "proc "
    append p $pname " {"
    set space ""
    foreach arg [info args $pname] {
        if {[info default $pname $arg value]} {
            append p "$space{" [list $arg $value] "}"
        } else {
            append p $space $arg
        }
        set space " "
    }
    append p "} {" [info body $pname] "}"
    return $p
}

### General option frobs ####

# set dochroot to 1 if you want to do this in a chroot dir.
set dochroot 1

# Where you want the report summary to go.
set REPDIR	"/tmp/packageresults"
set REPORT	"${REPDIR}/package-report.txt"

# Set to -v if you want verbose output, otherwise ""
if {[info exists env(VERBOSE)]} {
	set verbose	"-v"
} else {
	set verbose ""
}

### Crank her up! ###

if {$dochroot == 1} {
	makechroot chrootdir
	puts "All set up, now chrooting to ./chrootdir. Report will be in chrootdir${REPORT}"
	exec chroot chrootdir /doit.tcl
} else {
	puts "Report will be in $REPORT"
	packageall
}
