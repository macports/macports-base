# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portarchivefetch_run.tcl

package provide portarchivefetch 1.0

set org.macports.archivefetch [target_new org.macports.archivefetch portarchivefetch::archivefetch_main]
target_provides ${org.macports.archivefetch} archivefetch
target_requires ${org.macports.archivefetch} main
target_runtype ${org.macports.archivefetch} always
target_prerun ${org.macports.archivefetch} portarchivefetch::archivefetch_start
target_runpkg ${org.macports.archivefetch} portarchivefetch_run

namespace eval portarchivefetch {
    # List of URLs to attempt, filled in by checkarchivefiles
    variable archivefetch_urls {}
    # Whether fetching an archive has been attempted. Used to print an
    # explanatory message when an archive was not available.
    variable attempted 0
}
namespace eval portfetch::mirror_sites {}

options archive_sites archivefetch.user archivefetch.password \
    archivefetch.use_epsv archivefetch.ignore_sslcert \
    archive_sites.mirror_subdir archivefetch.pubkeys \
    archive.subdir

# user name & password
default archivefetch.user {}
default archivefetch.password {}
# Use EPSV for FTP transfers
default archivefetch.use_epsv no
# Ignore SSL certificate
default archivefetch.ignore_sslcert no
default archivefetch.pubkeys {$archivefetch_pubkeys}

default archive_sites {[portarchivefetch::get_sites]}
default archive_sites.listfile archive_sites.tcl
default archive_sites.listpath port1.0/fetch
default archive.subdir {${subport}}

# returns full path to mirror list file
proc portarchivefetch::get_full_archive_sites_path {} {
    global archive_sites.listfile archive_sites.listpath porturl
    # look up archive sites only from this ports tree,
    # do not fallback to the default
    return [getportresourcepath $porturl [file join ${archive_sites.listpath} ${archive_sites.listfile}] no]
}

proc portarchivefetch::get_sites {} {
    global porturl
    # check if porturl itself points to an archive
    if {[file extension $porturl] ne {} && ![catch {get_portimage_name} portimage_name] && [file rootname [file tail $porturl]] eq [file rootname $portimage_name]} {
        archive.subdir
        return [list [string range $porturl 0 end-[string length [file tail $porturl]]]:[string range [file extension $porturl] 1 end]]
    }
    global archive_sites.listpath archive_sites.listfile
    return [portarchivefetch::get_default_archive_sites [get_full_archive_sites_path]]
}

# Start asynchronous fetch of archive
proc portarchivefetch::archivefetch_async_start {logid} {
    package require portarchivefetch_run
    global all_archive_files
    _archivefetch_start yes
    if {![info exists all_archive_files]} {
        # No files to fetch
        return 0
    }
    variable async_logid $logid
    fetchfiles yes
}

proc portarchivefetch::_async_cleanup {} {
    variable async_job
    if {[info exists async_job]} {
        lassign $async_job jobid tmpfiles
        curlwrap_async_cancel $jobid
        file delete {*}$tmpfiles
        unset async_job
    }
}
