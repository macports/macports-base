# global port routines
package provide portfetch 1.0
package require portutil 1.0

register_target fetch portfetch::main main
namespace eval portfetch {
	variable options
	variable internal
}

# define globals: distname master_sites distfiles patchfiles dist_subdir
globals portfetch::options distname distfiles patchfiles dist_subdir all_dist_files use_zip use_bzip2

# define options: distname master_sites
options portfetch::options distname master_sites patch_sites extract_sufx distfiles extract_only patchfiles dist_subdir use_zip use_bzip2

proc portfetch::suffix {distname} {
	if {[isval portfetch::options extract_sufx]} {
		return ${distname}[getval portfetch::options extract_sufx]
	} elseif {[isval portfetch::options use_bzip2]} {
		return ${distname}.tar.bz2
	} elseif {[isval portfetch::options use_zip]} {
		return ${distname}.zip
	} else {
		return ${distname}.tar.gz
	}
}

proc portfetch::checkfiles {args} {
	global portpath distpath
	lappend filelist [getval portfetch::options distfiles]
	if {[isval portfetch::options patchfiles]} {
		lappend filelist [getval portfetch::options patchfiles]
	}
	# Set all_dist_files to distfiles + patchfiles
	foreach file $filelist {
		if {![file exists files/$file]} {
			appendval portfetch::options all_dist_files $file
		}
	}
}

proc portfetch::fetchfiles {args} {
	global portpath distpath

	if {![file isdirectory $distpath]} {
		file mkdir $distpath
	}

	foreach distfile [getval portfetch::options all_dist_files] {
		if {![file isfile $distpath/$distfile]} {
			puts "$distfile doesn't seem to exist in $distpath"
			foreach site [getval portfetch::options master_sites] {
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

proc portfetch::main {args} {
	global distname
	# Defaults
	default portfetch::options distfiles [portfetch::suffix $distname]

	# Check for files, download if neccesary
	portfetch::checkfiles
	if ![isval portfetch::options all_dist_files] {
		return 0
	} else {
		return [portfetch::fetchfiles]
	}
}
