#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# $Id$

# convert existing port image directories into compressed archive versions
# Takes one argument, which should be TCL_PACKAGE_DIR.

source [file join [lindex $argv 0] macports1.0 macports_fastload.tcl]
package require macports 1.0
package require registry 1.0
package require registry2 2.0
package require Pextlib 1.0

umask 022

array set ui_options {ports_verbose yes}

mportinit ui_options

# always converting to tbz2 should be fine as both these programs are
# needed elsewhere and assumed to be available
set tarcmd [macports::findBinary tar ${macports::autoconf::tar_path}]
set bzip2cmd [macports::findBinary bzip2 ${macports::autoconf::bzip2_path}]

if {[catch {set ilist [registry::installed]}]} {
    # no ports installed
    puts "No ports installed to convert."
    exit 0
}

puts "This could take a while..."

# list of ports we successfully create an archive of, to be used to update
# the registry only after we know all creation attempts were successful.
set archived_list {}

foreach installed $ilist {
    set iname [lindex $installed 0]
    set iversion [lindex $installed 1]
    set irevision [lindex $installed 2]
    set ivariants [lindex $installed 3]
    set iepoch [lindex $installed 5]
    set iref [registry::open_entry $iname $iversion $irevision $ivariants $iepoch]
    set installtype [registry::property_retrieve $iref installtype]
    if {$installtype == "image"} {
        set location [registry::property_retrieve $iref location]
        if {$location == "0"} {
            set location [registry::property_retrieve $iref imagedir]
        }
    } else {
        set location ""
    }

    if {$location == "" || ![file isfile $location]} {
        # no image archive present, so make one
        set archs [registry::property_retrieve $iref archs]
        if {$archs == "" || $archs == "0"} {
            set archs ${macports::os_arch}
        }
        # look for any existing archive in the old location
        set oldarchiverootname "${iname}-${iversion}_${irevision}${ivariants}.[join $archs -]"
        set archivetype tbz2
        set oldarchivedir [file join ${macports::portdbpath} packages ${macports::os_platform}_${macports::os_major}]
        set olderarchivedir [file join ${macports::portdbpath} packages ${macports::os_platform}]
        if {[llength $archs] == 1} {
            set oldarchivedir [file join $oldarchivedir $archs $iname]
            set olderarchivedir [file join $olderarchivedir $archs]
        } else {
            set oldarchivedir [file join $oldarchivedir universal $iname]
            set olderarchivedir [file join $olderarchivedir universal]
        }
        set found 0
        foreach adir [list $oldarchivedir $olderarchivedir] {
            foreach type {tbz2 tbz tgz tar txz tlz xar xpkg zip cpgz cpio} {
                set oldarchivefullpath "[file join $adir $oldarchiverootname].${type}"
                if {[file isfile $oldarchivefullpath]} {
                    set found 1
                    set archivetype $type
                    break
                }
            }
            if {$found} {break}
        }

        # compute new name and location of archive
        set archivename "${iname}-${iversion}_${irevision}${ivariants}.${macports::os_platform}_${macports::os_major}.[join $archs -].${archivetype}"
        if {$installtype == "image"} {
            set targetdir [file dirname $location]
        } else {
            set targetdir [file join ${macports::registry.path} software ${iname}]
            file mkdir $targetdir
            set contents [$iref imagefiles]
        }
        set newlocation [file join $targetdir $archivename]

        if {$found} {
            file rename $oldarchivefullpath $newlocation
        } elseif {$installtype == "image"} {
            # create archive from image dir
            system "cd $location && $tarcmd -cjf $newlocation * > ${targetdir}/error.log 2>&1"
            file delete -force ${targetdir}/error.log
        } else {
            # direct mode, create archive from installed files
            # we tell tar to read filenames from a file so as not to run afoul of command line length limits
            set fd [open ${targetdir}/tarlist w]
            foreach entry $contents {
                puts $fd $entry
            }
            close $fd
            system "$tarcmd -cjf $newlocation -T ${targetdir}/tarlist > ${targetdir}/error.log 2>&1"
            file delete -force ${targetdir}/tarlist ${targetdir}/error.log
        }

        lappend archived_list [list $installtype $iref $location $newlocation]
    }
}

registry::write {
    foreach archived $archived_list {
        set installtype [lindex $archived 0]
        set iref [lindex $archived 1]
        set newlocation [lindex $archived 3]
    
        if {$installtype == "direct"} {
            # change receipt to image
            $iref installtype image
            $iref state imaged
            $iref activate [$iref imagefiles]
            $iref state installed
        }
    
        # set the new location in the registry and delete the old dir
        $iref location $newlocation
    }
}

foreach archived $archived_list {
    set location [lindex $archived 2]
    if {$location != "" && [file isdirectory $location]} {
        if {[catch {file delete -force $location} result]} {
            ui_warn "Failed to delete ${location}: $result"
        }
    }
}

exit 0
