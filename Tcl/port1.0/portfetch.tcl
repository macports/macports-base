# global port routines
package provide portfetch 1.0
package require portutil 1.0

register com.apple.fetch target build fetch_main
register com.apple.fetch provides fetch
register com.apple.fetch requires main

global fetch_opts

# define globals: all_dist_files
globals fetch_opts all_dist_files

# define options: distname master_sites
options fetch_opts master_sites patch_sites extract_sufx distfiles extract_only patchfiles dist_subdir use_zip use_bzip2

proc suffix {distname} {
    variable fetch_opts

    if {[tbool fetch_opts extract_sufx]} {
	return ${distname}.${fetch_opts(extract_sufx)}
    } elseif {[tbool fetch_opts use_bzip2]} {
	return ${distname}.tar.bz2
    } elseif {[tbool fetch_opts use_zip]} {
	return ${distname}.zip
    } else {
	return ${distname}.tar.gz
    }
}

proc checkfiles {args} {
    global fetch_opts distdir

    lappend filelist $fetch_opts(distfiles)
    if {[info exists fetch_opts(patchfiles)]} {
	set filelist [concat $filelist $fetch_opts(patchfiles)]
    }
    # Set all_dist_files to distfiles + patchfiles
    foreach file $filelist {
	if {![file exists files/$file]} {
	    lappend fetch_opts(all_dist_files) $file
	}
    }
}

proc fetchfiles {args} {
    global fetch_opts distpath

    if {![file isdirectory $distpath]} {
	file mkdir $distpath
    }

    foreach distfile $fetch_opts(all_dist_files) {
	if {![file isfile $distpath/$distfile]} {
	    puts "$distfile doesn't seem to exist in $distpath"
	    foreach site $fetch_opts(master_sites) {
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
    global fetch_opts distname

    # Defaults
    default fetch_opts distfiles [suffix $distname]

    # Check for files, download if neccesary
    checkfiles
    if ![info exists fetch_opts(all_dist_files)] {
	return 0
    } else {
	return [fetchfiles]
    }
}
