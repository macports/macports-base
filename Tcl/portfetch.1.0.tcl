# global port routines
package provide portfetch 1.0
package require portutil

register_target fetch portfetch::main main
namespace eval portfetch {
	variable options
	variable internal
}

# define globals: distname master_sites distfiles patchfiles dist_subdir
globals portfetch::options distname master_sites extract_sufx distfiles patchfiles dist_subdir use_zip use_bzip2

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
	global portpath distname master_sites distpath

	# Set distfile with proper suffix
	set distfile [portfetch::suffix $distname]

	if {![file isdirectory $distpath]} {
		file mkdir $distpath
	}

	if {![file isfile $distpath/$distfile]} {
		puts "$distfile doesn't seem to exist in $distpath"
		foreach site $master_sites {
			puts "Attempting to fetch from $site"
			catch {exec curl -o ${distpath}/${distfile} ${site}${distfile} >&@ stdout} result
			if {$result == 0} {
				break
			}
		}
	}
}

proc portfetch::main {args} {
	global portname
	# Check for files, download if neccesary
	portfetch::checkfiles
}
