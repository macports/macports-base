#!/usr/bin/tclsh
# Traverse through all ports and try to build/install each one in a chroot
# tree.
#
# Author: Jordan K. Hubbard
# Date:   2004/01/26
#
# NOTES:
#
# This is a simplified version of some of the other scripts you see in
# this directory.  It is completely stand-alone and does not require any
# other scripts to run.  If you have a copy of darwinports you specifically
# wish to use, name it darwinports.tar.gz and put it in the current working
# directory before running this script.  Otherwise, the script will fetch
# the last cvs snapshot from darwinports.opendarwin.org.  The chroot directory
# it creates will be called "chrootdir" and populated from your host system
# (so if you're running Jaguar, it will be a Jaguar chroot, likewise Panther
# or any other release of Mac OS X).  If you have a local URL you wish to
# use for fetching distfiles, set the environment variable MASTER_SITE_LOCAL
# to this URL and it will be propagated into the chroot.
#
# This script ONLY works on Mac OS X!  Not standalone Darwin, not FreeBSD,
# just Mac OS X.

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
	set savedir [exec pwd]
	cd /
	foreach idx $chrootfiles {
		if {[catch {file lstat $idx sbuf} result]} {
			puts "Warning: Couldn't stat $idx: $result"
			continue
		}
		if {$sbuf(type) != "file" && $sbuf(type) != "directory"} {
			if {[catch {exec tar -cpf -  $idx | tar -xpf - -C $dir} result]} {
				puts "Warning: Unable to tar $idx into $dir: $result"
			}
		} else {
			if {[catch {exec ditto -rsrc $idx $dir/$idx} result]} {
				puts "Warning: Unable to ditto $idx into $dir: $result"
			}
		}
	}
	cd $savedir
	if {[file exists darwinports.tar.gz]} {
		puts "Copying from local darwinports.tar.gz snapshot"
		exec tar -xpzf darwinports.tar.gz -C $dir
	} elseif {[file exists darwinports-nightly-cvs-snapshot.tar.gz]} {
		puts "Copying from last darwinports cvs snapshot."
		exec tar -xpzf darwinports-nightly-cvs-snapshot.tar.gz -C $dir
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
	exec mkdir -p ${REPDIR}
	if {[catch {set repfile [open $REPORT w]}]} {
		puts "Unable to open $REPORT - check permissions."
		exit 4
	}
	if {[catch {exec port install rpm} result]} {
		puts "Unable to install rpm port: $result"
		exit 6
	}
	exec mkdir -p /Packages
	while {[gets $pifile line] != -1} {
		if {[llength $line] != 2} continue
		set portname [lindex $line 0]
		if {[catch {exec port rpmpackage package.destpath=/Packages $portname >& ${REPDIR}/${portname}.out}]} {
			puts $repfile "$portname failure [exec env TZ=GMT date {+%Y%m%d %T}]"
			flush $repfile
		} else {
			puts $repfile "$portname success [exec env TZ=GMT date {+%Y%m%d %T}]"
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
	set loc "[exec pwd]/chrootdir"
	makechroot $loc
	puts "All set up, now chrooting to ${loc}. Report will be in ${loc}${REPORT}"
	exec chroot ${loc} /doit.tcl
} else {
	puts "Report will be in $REPORT"
	packageall
}
