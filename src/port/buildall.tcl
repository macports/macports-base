#!/usr/bin/tclsh
# Traverse through all ports and try to build/install each one in a chroot
# tree.

# Not all of these may be necessary.  Prune (or add to) as actual experience
# subsequently dictates.
set chrootfiles {
	bin sbin etc tmp var dev/null usr/include usr/libexec
	usr/sbin usr/lib usr/share private/tmp private/etc
	private/var/at private/var/automount private/var/cron
	private/var/db private/var/empty private/var/log private/var/mail
	private/var/msgs private/var/named private/var/root
	private/var/run private/var/rwho private/var/spool
	private/var/tmp private/var/vm/app_profile
	Developer/Applications/Xcode.app Developer/Applications/Utilities
	Developer/Headers Developer/Makefiles Developer/Private
	Developer/Tools System/Library/Frameworks System/Library/OpenSSL
	System/Library/PHP System/Library/Perl
}

proc makechroot {dir} {
	global chrootfiles verbose

	if {![file exists $dir]} {
		exec mkdir -p $dir
	} elseif {![file isdirectory $dir]} {
		puts "$dir must be a directory"
		exit 5
	}
	puts "Creating chroot environment in $dir"
	foreach idx $chrootfiles {
		if {[catch {exec tar -cpf - -C / $idx | tar ${verbose} -xpf - -C $dir >& /dev/stdout}]} {
			puts "Warning: Unable to copy $idx into $dir"
		}
	}
	if {[file exists darwinports.tar.gz]} {
		puts "copying from local darwinports snapshot"
		exec tar ${verbose} -xpzf darwinports.tar.gz -C $dir >& /dev/stdout
	} else {
		puts "Attempting to grab cvs snapshot of darwinports"
		if {![catch {exec curl -O http://darwinports.opendarwin.org/darwinports-nightly-cvs-snapshot.tar.gz}]} {
			exec tar ${verbose} -xpzf darwinports-nightly-cvs-snapshot.tar.gz -C $dir >& /dev/stdout
		} else {
			puts "Unable to find darwinports anywhere.  I give up"
			exit 7
		}
	}
	exec mkdir -p $dir/.vol
	exec /sbin/mount_devfs devfs ${dir}/dev
	exec /sbin/mount_fdesc -o union fdesc ${dir}/dev
	exec /sbin/mount_volfs ${dir}/.vol
	set f [open $dir/doit.tcl w 0755]
	puts $f "#!/usr/bin/tclsh"
	puts $f [proc_disasm packageall]
	puts $f "cd darwinports"
	puts $f "exec make all install"
	puts $f {set env(PATH) "$env(PATH):/opt/local/bin"}
	puts $f packageall
	close $f
}

proc packageall {} {
	global REPORT REPDIR verbose

	if {[file exists PortIndex]} {
		set PI PortIndex
	} elseif {[file exists dports/PortIndex]} {
		set PI dports/PortIndex
	} else {
		puts "Unable to find PortIndex.  Please run me from darwinports dir"
		exit 2
	}

	if {[catch {set pifile [open $PI r]}]} {
		puts "Unable to open $PI - check permissions."
		exit 3
	}
	if {[catch {set repfile [open $REPORT w]}]} {
		puts "Unable to open $REPORT - check permissions."
		exit 4
	}
	exec mkdir -p /Packages
	exec mkdir -p ${REPDIR}
	if {[catch {exec port ${verbose} install rpm >& /dev/stdout }]} {
		puts "Unable to install rpm port - cannot continue"
		exit 6
	}
	while {[gets $pifile line] != -1} {
		if {[llength $line] != 2} continue
		set portname [lindex $line 0]
		if {[catch {exec port rpmpackage package.destpath=/Packages $portname >& ${REPDIR}/${portname}.out}]} {
			puts $repfile "$portname failure"
			flush $repfile
		} else {
			puts $repfile "$portname success"
			flush $repfile
			exec rm -f ${REPDIR}/${portname}.out
		}
	}
	close $pifile
	close $repfile
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
set dochroot 0

# Where you want the report summary to go.
set REPDIR	"/tmp/packageresults"
set REPORT	"${REPDIR}/package-report.txt"

# Set to -v if you want verbose output, otherwise ""
set verbose	"-v"

### Crank her up! ###

if {$dochroot == 1} {
	makechroot chrootdir
	puts "All set up, now chrooting to ./chrootdir. Report will be in chrootdir/$REPORT"
	exec chroot chrootdir chrootdir/doit.tcl
} else {
	puts "Report will be in $REPORT"
	packageall
}
