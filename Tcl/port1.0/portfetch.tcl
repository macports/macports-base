# global port routines
package provide portfetch 1.0
package require portutil 1.0

register com.apple.fetch target build portfetch::main
register com.apple.fetch provides fetch
register com.apple.fetch requires main

namespace eval portfetch {
	variable options
}

# define globals: all_dist_files
globals portfetch::options all_dist_files

# define options: distname master_sites
options portfetch::options master_sites patch_sites extract_sufx distfiles extract_only patchfiles dist_subdir use_zip use_bzip2

proc portfetch::suffix {distname} {
	if {[tbool portfetch::options extract_sufx]} {
		return ${distname}.${portfetch::options(extract_sufx)}]
	} elseif {[tbool portfetch::options use_bzip2]} {
		return ${distname}.tar.bz2
	} elseif {[tbool portfetch::options use_zip]} {
		return ${distname}.zip
	} else {
		return ${distname}.tar.gz
	}
}

proc portfetch::checkfiles {args} {
	global distdir
	lappend filelist $portfetch::options(distfiles)
	if {[info exists portfetch::options(patchfiles)]} {
		set filelist [concat $filelist $portfetch::options(patchfiles)]
	}
	# Set all_dist_files to distfiles + patchfiles
	foreach file $filelist {
		if {![file exists files/$file]} {
			lappend portfetch::options(all_dist_files) $file
		}
	}
}

proc portfetch::fetchfiles {args} {
	global distpath

	if {![file isdirectory $distpath]} {
		file mkdir $distpath
	}

	foreach distfile $portfetch::options(all_dist_files) {
		if {![file isfile $distpath/$distfile]} {
			puts "$distfile doesn't seem to exist in $distpath"
			foreach site $portfetch::options(master_sites) {
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
	if ![info exists portfetch::options(all_dist_files)] {
		return 0
	} else {
		return [portfetch::fetchfiles]
	}
}
