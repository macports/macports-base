#-*- mode: Fundamental; tab-width: 4; -*-
# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portfetch 1.0
package require portutil 1.0

register com.apple.fetch target build fetch_main
register com.apple.fetch provides fetch
register com.apple.fetch requires main

# define options: distname master_sites
options master_sites patch_sites extract_sufx distfiles extract_only patchfiles dist_subdir use_zip use_bzip2

proc suffix {distname} {
    global extract_sufx use_bzip2 use_zip
    if {[tbool extract_sufx]} {
	return ${distname}.${extract_sufx}
    } elseif {[tbool use_bzip2]} {
	return ${distname}.tar.bz2
    } elseif {[tbool use_zip]} {
	return ${distname}.zip
    } else {
	return ${distname}.tar.gz
    }
}

proc checkfiles {args} {
    global distdir distfiles patchfiles all_dist_files

    lappend filelist $distfiles
    if {[info exists patchfiles]} {
	set filelist [concat $filelist $patchfiles]
    }
    # Set all_dist_files to distfiles + patchfiles
    foreach file $filelist {
	if {![file exists files/$file]} {
	    lappend all_dist_files $file
	}
    }
}

proc fetchfiles {args} {
    global distpath all_dist_files master_sites

    if {![file isdirectory $distpath]} {
	file mkdir $distpath
    }

    foreach distfile $all_dist_files {
	if {![file isfile $distpath/$distfile]} {
	    puts "$distfile doesn't seem to exist in $distpath"
	    foreach site $master_sites {
		puts "Attempting to fetch from $site"
		if ![catch {exec curl -o ${distpath}/${distfile} ${site}${distfile} >&@ stdout} result] {
		    set fetched 1
		    break
		}
	    }
	    if {![info exists fetched]} {
		return -1
	    } else {
		unset fetched
	    }
	}
    }
    return 0
}

proc fetch_main {args} {
    global distname distpath all_dist_files

    # Set distfiles
    default distfiles [suffix $distname]

    # Check for files, download if neccesary
    checkfiles
    if ![info exists all_dist_files] {
	return 0
    } else {
	return [fetchfiles]
    }
}
