# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portfetch 1.0
package require portutil 1.0

register com.apple.fetch target fetch_main fetch_init
register com.apple.fetch provides fetch
register com.apple.fetch requires main depends_fetch

# define options: distname master_sites
options master_sites patch_sites extract_sufx distfiles extract_only patchfiles use_zip use_bzip2 dist_subdir

# Defaults
default extract_sufx .tar.gz

set UI_PREFIX "---> "

proc suffix {distname} {
    global extract_sufx use_bzip2 use_zip
    if {[tbool use_bzip2]} {
	return ${distname}.tar.bz2
    } elseif {[tbool use_zip]} {
	return ${distname}.zip
    } else {
	return ${distname}${extract_sufx}
    }
}

proc checkfiles {args} {
    global distdir distfiles patchfiles all_dist_files

    set filelist $distfiles
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
    global distpath all_dist_files master_sites UI_PREFIX ports_verbose

    if {![file isdirectory $distpath]} {
	file mkdir $distpath
    }

    foreach distfile $all_dist_files {
	if {![file isfile $distpath/$distfile]} {
	    ui_info "$UI_PREFIX $distfile doesn't seem to exist in $distpath"
	    foreach site $master_sites {
		ui_msg "$UI_PREFIX Attempting to fetch $distfile from $site"
		if [tbool ports_verbose] {
			set verboseflag -v
		} else {
			set verboseflag "-s"
		}
		if ![catch {system curl ${verboseflag} -o ${distpath}/${distfile} ${site}${distfile} 2>&1} result] {
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

proc fetch_init {args} {
    global distfiles distname distpath all_dist_files dist_subdir
    # Set distfiles
    if [info exists distname] {
	default distfiles [suffix $distname]
    }
    if {[info exist distpath] && [info exists dist_subdir]} {
	set distpath ${distpath}/${dist_subdir}
    }
    checkfiles
}

proc fetch_main {args} {
    global distname distpath all_dist_files

    # Check for files, download if neccesary
    if ![info exists all_dist_files] {
	return 0
    } else {
	return [fetchfiles]
    }
}
