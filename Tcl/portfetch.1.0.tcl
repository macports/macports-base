# global port routines
package provide portfetch 1.0
package require portutil

register_target fetch portfetch::main main
namespace eval portfetch {
	variable options
	variable internal
}

# define globals: distname master_sites distfiles patchfiles dist_subdir
globals portfetch::options distname distfiles patchfiles dist_subdir all_dist_files use_zip use_bzip2

# define options: distname master_sites
options portfetch::options distname master_sites extract_sufx distfiles extract_only patchfiles dist_subdir use_zip use_bzip2

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

	if {![file isdirectory $distpath]} {
		file mkdir $distpath
	}
	foreach distfile [getval portfetch::options distfiles] {
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
	# Set distfiles if not defined
	if ![isval portfetch::options distfiles] {
		setval portfetch::options distfiles [portfetch::suffix $distname]
	}

	# Set all_dist_files to distfiles + patchfiles
	setval portfetch::options all_dist_files [getval portfetch::options distfiles]
	if [isval portfetch::options patchfiles] {
		appendval portfetch::options all_dist_files [getval portfetch::options patchfiles]
	}

	# Check for files, download if neccesary
	return [portfetch::checkfiles]
}
