# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2004 - 2014, 2016 The MacPorts Project
# Copyright (c) 2002 - 2003 Apple Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide portfetch 1.0
package require fetch_common 1.0
package require portutil 1.0
package require Pextlib 1.0

set org.macports.fetch [target_new org.macports.fetch portfetch::fetch_main]
target_init ${org.macports.fetch} portfetch::fetch_init
target_provides ${org.macports.fetch} fetch
target_requires ${org.macports.fetch} main
target_prerun ${org.macports.fetch} portfetch::fetch_start

namespace eval portfetch {
    namespace export suffix
    variable fetch_urls {}
}

# define options: distname master_sites
options master_sites patch_sites extract.suffix distfiles patchfiles use_bzip2 use_lzma use_xz use_zip use_7z use_lzip use_dmg dist_subdir \
    fetch.type fetch.user fetch.password fetch.use_epsv fetch.ignore_sslcert \
    master_sites.mirror_subdir patch_sites.mirror_subdir \
    bzr.cmd bzr.url bzr.revision bzr.file bzr.file_prefix \
    cvs.cmd cvs.root cvs.password cvs.module cvs.tag cvs.date cvs.file cvs.file_prefix \
    svn.cmd svn.url svn.revision svn.file svn.file_prefix \
    git.cmd git.url git.branch git.file git.file_prefix git.fetch_submodules \
    hg.cmd hg.url hg.tag hg.file hg.file_prefix

# Defaults
default extract.suffix .tar.gz
default fetch.type standard

default bzr.cmd {[findBinary bzr $portutil::autoconf::bzr_path]}
default bzr.revision {-1}
default bzr.file {${distname}.${fetch.type}.tar.bz2}
default bzr.file_prefix {${distname}}

default cvs.cmd {[findBinary cvs $portutil::autoconf::cvs_path]}
default cvs.root ""
default cvs.password ""
default cvs.module {$distname}
default cvs.tag ""
default cvs.date ""
default cvs.file {${distname}.${fetch.type}.tar.bz2}
default cvs.file_prefix {${distname}}

default svn.cmd {[portfetch::find_svn_path]}
default svn.url ""
default svn.revision ""
default svn.file {${distname}.${fetch.type}.tar.bz2}
default svn.file_prefix {${distname}}

default git.cmd {[portfetch::find_git_path]}
default git.url ""
default git.branch ""
default git.file {${distname}.${fetch.type}.tar.bz2}
default git.file_prefix {${distname}}
default git.fetch_submodules "yes"

default hg.cmd {[findBinary hg $portutil::autoconf::hg_path]}
default hg.tag {tip}
default hg.file {${distname}.${fetch.type}.tar.bz2}
default hg.file_prefix {${distname}}

# Set distfiles
default distfiles {[list [portfetch::suffix $distname]]}
default dist_subdir {${name}}

# user name & password
default fetch.user ""
default fetch.password ""
# Use EPSV for FTP transfers
default fetch.use_epsv "yes"
# Ignore SSL certificate
default fetch.ignore_sslcert "no"
# Use remote timestamps
default fetch.remote_time "no"

default global_mirror_site "macports_distfiles"
default mirror_sites.listfile {"mirror_sites.tcl"}
default mirror_sites.listpath {"port1.0/fetch"}

# Option-executed procedures
option_proc use_bzip2 portfetch::set_extract_type
option_proc use_lzma  portfetch::set_extract_type
option_proc use_xz    portfetch::set_extract_type
option_proc use_zip   portfetch::set_extract_type
option_proc use_7z    portfetch::set_extract_type
option_proc use_lzip  portfetch::set_extract_type
option_proc use_dmg   portfetch::set_extract_type

option_proc fetch.type portfetch::set_fetch_type

proc portfetch::set_extract_type {option action args} {
    global extract.suffix
    if {[string equal ${action} "set"] && [tbool args]} {
        switch $option {
            use_bzip2 {
                set extract.suffix .tar.bz2
                if {![catch {findBinary lbzip2} result]} {
                    depends_extract-append bin:lbzip2:lbzip2
                }
            }
            use_lzma {
                set extract.suffix .tar.lzma
                depends_extract-append bin:lzma:xz
            }
            use_xz {
                set extract.suffix .tar.xz
                depends_extract-append bin:xz:xz
            }
            use_zip {
                set extract.suffix .zip
                depends_extract-append bin:unzip:unzip
            }
            use_7z {
                set extract.suffix .7z
                depends_extract-append bin:7za:p7zip
            }
            use_lzip {
                set extract.suffix .tar.lz
                depends_extract-append bin:lzip:lzip
            }
            use_dmg {
                set extract.suffix .dmg
            }
        }
    }
}

proc portfetch::set_fetch_type {option action args} {
    global os.platform os.major
    if {[string equal ${action} "set"]} {
        if {$args ne "standard"} {
            distfiles
        }
        switch $args {
            bzr {
                depends_fetch-append bin:bzr:bzr
                default distname {${name}-${bzr.revision}}
            }
            cvs {
                depends_fetch-append bin:cvs:cvs
                default distname {${name}-${cvs.tag}${cvs.date}}
            }
            svn {
                # Sierra is the first macOS version whose svn supports modern TLS cipher suites.
                if {${os.major} >= 16 || ${os.platform} ne "darwin"} {
                    depends_fetch-append bin:svn:subversion
                } else {
                    depends_fetch-append port:subversion
                }
                default distname {${name}-${svn.revision}}
            }
            git {
                # Always use the git port and not /usr/bin/git.
                # The output format changed with git @1.8.1.1 due to a bugfix.
                # https://github.com/git/git/commit/22f0dcd9634a818a0c83f23ea1a48f2d620c0546
                depends_fetch-append port:git
                default distname {${name}-${git.branch}}
            }
            hg {
                depends_fetch-append bin:hg:mercurial
                default distname {${name}-${hg.tag}}
            }
        }

        switch $args {
            bzr -
            cvs -
            svn -
            git -
            hg {
                # bzip2 is needed to create and extract generated tarballs.
                # It might not be used if the fetch was not tarballable,
                # but we cannot decide this yet, so we just add it anyway.
                use_bzip2 yes
            }
        }
    }
}

proc portfetch::find_svn_path {args} {
    global prefix os.platform os.major
    # Sierra is the first macOS version whose svn supports modern TLS cipher suites.
    if {${os.major} >= 16 || ${os.platform} ne "darwin"} {
        return [findBinary svn $portutil::autoconf::svn_path]
    } else {
        return ${prefix}/bin/svn
    }
}

proc portfetch::find_git_path {args} {
    global prefix os.platform os.major
    # Mavericks is the first OS X version whose git supports modern TLS cipher suites.
    if {${os.major} >= 13 || ${os.platform} ne "darwin"} {
        return [findBinary git $portutil::autoconf::git_path]
    } else {
        return ${prefix}/bin/git
    }
}

set_ui_prefix


# Given a distname, return the distname with extract.suffix appended
proc portfetch::suffix {distname} {
    global extract.suffix
    return "${distname}${extract.suffix}"
}
# XXX import suffix into the global namespace as it is currently used from
# Portfiles, but should better go somewhere else
namespace import portfetch::suffix

# Checks patch files and their tags to assemble url lists for later fetching
proc portfetch::checkpatchfiles {urls} {
    global patchfiles all_dist_files patch_sites filespath
    upvar $urls fetch_urls

    if {[info exists patchfiles]} {
        foreach file $patchfiles {
            if {![file exists "${filespath}/${file}"]} {
                set distsite [getdisttag $file]
                set file [getdistname $file]
                lappend all_dist_files $file
                if {$distsite ne ""} {
                    lappend fetch_urls $distsite $file
                } elseif {[info exists patch_sites]} {
                    lappend fetch_urls patch_sites $file
                } else {
                    lappend fetch_urls master_sites $file
                }
            }
        }
    }
}

# Checks dist files and their tags to assemble url lists for later fetching
proc portfetch::checkdistfiles {urls} {
    global distfiles all_dist_files filespath
    upvar $urls fetch_urls

    if {[info exists distfiles]} {
        foreach file $distfiles {
            if {![file exists "${filespath}/${file}"]} {
                set distsite [getdisttag $file]
                set file [getdistname $file]
                lappend all_dist_files $file
                if {$distsite ne ""} {
                    lappend fetch_urls $distsite $file
                } else {
                    lappend fetch_urls master_sites $file
                }
            }
        }
    }
}

# returns full path to mirror list file
proc portfetch::get_full_mirror_sites_path {} {
    global mirror_sites.listfile mirror_sites.listpath porturl
    return [getportresourcepath $porturl [file join ${mirror_sites.listpath} ${mirror_sites.listfile}]]
}

# Perform the full checksites/checkpatchfiles/checkdistfiles sequence.
# This method is used by distcheck target.
proc portfetch::checkfiles {urls} {
    global global_mirror_site ports_fetch_no-mirrors
    upvar $urls fetch_urls

    set sites [list patch_sites {} \
                    master_sites {}]
    if {![info exists ports_fetch_no-mirrors] || ${ports_fetch_no-mirrors} eq "no"} {
        set sites [list patch_sites [list $global_mirror_site PATCH_SITE_LOCAL] \
                        master_sites [list $global_mirror_site MASTER_SITE_LOCAL]]
    }

    checksites $sites [get_full_mirror_sites_path]
    checkpatchfiles fetch_urls
    checkdistfiles fetch_urls
}

# Compress a file and remove the original
proc compressfile {file} {
    set bzip2 [findBinary bzip2 ${portutil::autoconf::bzip2_path}]
    set cmdstring "$bzip2 ${file}"
    if {[catch {system $cmdstring} result]} {
        delete "${file}"
        delete "${file}.bz2"
        return -code error "Compression failed"
    }
    return "${file}.bz2"
}

# Create a reproducible tarball of the contents of a directory
proc portfetch::mktar {tarfile dir mtime} {
    set mtreefile "${tarfile}.mtree"

    # write the list of files in sorted order to mtree file with the
    # permissions and ownership we want
    set mtreefd [open $mtreefile w]
    puts $mtreefd "#mtree"
    puts $mtreefd "/set uname=root uid=0 gname=root gid=0 time=$mtime"
    fs-traverse -tails f $dir {
        set fpath [file join $dir $f]
        if {$f ne "."} {
            # map type from Tcl to mtree
            set type [file type $fpath]
            array set typemap {
                    file file
                    directory dir
                    characterSpecial char
                    blockSpecial block
                    fifo fifo
                    link link
                    socket socket
                }
            if {![info exists typemap($type)]} {
               return -code error "unknown file type $type"
            }
            set type $typemap($type)

            if {$type eq "link"} {
                set mode 0777
            } else {
                # use user permissions only, ignore the rest
                set mode [format "%o" [expr [file attributes $fpath -permissions] & 0700]]
            }

            # add entry to mtree output
            puts $mtreefd "$f type=$type mode=$mode"
        }
    }
    close $mtreefd

    # TODO: add dependency on libarchive, if /usr/bin/tar is not bsdtar
    set tar [findBinary bsdtar tar]
    set cmdstring "${tar} -cf $tarfile @$mtreefile 2>&1"
    if {[catch {system -W $dir $cmdstring} result]} {
        delete $mtreefile
        delete $tarfile
        return -code error [msgcat::mc "tarball creation failed"]
    }

    delete $mtreefile

    return 0
}

# Perform a bzr fetch
proc portfetch::bzrfetch {args} {
    global UI_PREFIX \
           env distpath worksrcpath \
           bzr.cmd bzr.url bzr.revision bzr.file bzr.file_prefix \
           name distname fetch.type

    set generatedfile "${distpath}/${bzr.file}"

    if {[bzr_tarballable] && [file isfile "${generatedfile}"]} {
        return 0
    }

    # Behind a proxy bzr will fail with the following error if proxies
    # listed in macports.conf appear in the environment in their
    # unmodified form:
    #   bzr: ERROR: Invalid url supplied to transport:
    #   "proxy.example.com:8080": No host component
    # Set the "http_proxy" and "HTTPS_PROXY" environmental variables
    # to valid URLs by prepending "http://" and appending "/".
    if {   [info exists env(http_proxy)]
        && [string compare -length 7 {http://} $env(http_proxy)] != 0} {
        set orig_http_proxy $env(http_proxy)
        set env(http_proxy) http://${orig_http_proxy}/
    }

    if {   [info exists env(HTTPS_PROXY)]
        && [string compare -length 7 {http://} $env(HTTPS_PROXY)] != 0} {
        set orig_https_proxy $env(HTTPS_PROXY)
        set env(HTTPS_PROXY) http://${orig_https_proxy}/
    }

    try -pass_signal {
        ui_info "$UI_PREFIX Checking out ${fetch.type} repository"
        set tmppath [mkdtemp "/tmp/macports.portfetch.${name}.XXXXXXXX"]
        set tmpxprt [file join ${tmppath} export]
        file mkdir ${tmpxprt}
        set cmdstring "${bzr.cmd} --builtin --no-aliases checkout --lightweight --verbose -r ${bzr.revision} ${bzr.url} ${tmpxprt}/${bzr.file_prefix} 2>&1"
        if {[catch {system $cmdstring} result]} {
            delete ${tmppath}
            error [msgcat::mc "Bazaar checkout failed"]
        }

        if {![bzr_tarballable]} {
            file rename ${tmppath}/${bzr.file_prefix} ${worksrcpath}
            return 0
        }

        ui_info "$UI_PREFIX Generating tarball ${bzr.file}"

        # get timestamp of latest revision
        set cmdstring "${bzr.cmd} --builtin --no-aliases version-info --format=custom --template=\"{date}\" ${tmpxprt}/${bzr.file_prefix}"
        ui_debug "exec: $cmdstring"
        if {[catch {exec -ignorestderr sh -c $cmdstring} result]} {
            delete ${tmppath}
            error [msgcat::mc "Bazaar version-info failed: $result"]
        }
        set tstamp $result
        set mtime [clock scan [lindex [split $tstamp "."] 0] -format "%Y-%m-%d %H:%M:%S %z" -timezone "UTC"]

        set tardst [join [list [mktemp "/tmp/macports.portfetch.${name}.XXXXXXXX"] ".tar"] ""]

        mktar $tardst $tmpxprt $mtime
        set compressed [compressfile ${tardst}]
        file rename -force ${compressed} ${generatedfile}

        ui_debug "Created tarball for fetch.type ${fetch.type} at ${generatedfile}"

        # cleanup
        delete ${tmppath}

        return 0
    } catch {{*} eCode eMessage} {
        throw
    } finally {
        if {[info exists orig_http_proxy]} {
            set env(http_proxy) ${orig_http_proxy}
        }
        if {[info exists orig_https_proxy]} {
            set env(HTTPS_PROXY) ${orig_https_proxy}
        }
    }

    return 0
}

# Perform a CVS login and fetch, storing the CVS login
# information in a custom .cvspass file
proc portfetch::cvsfetch {args} {
    global UI_PREFIX \
           env distpath workpath worksrcpath \
           cvs.cmd cvs.root cvs.tag cvs.date cvs.password cvs.file cvs.file_prefix \
           name distname fetch.type \

    set generatedfile "${distpath}/${cvs.file}"

    if {[cvs_tarballable] && [file isfile "${generatedfile}"]} {
        return 0
    }

    if {![string length ${cvs.tag}] && ![string length ${cvs.date}]} {
        set cvs.tag "HEAD"
    }
    if {[string length ${cvs.tag}]} {
        set cvs.args "${cvs.args} -r ${cvs.tag}"
    }

    if {[string length ${cvs.date}]} {
        set cvs.args "${cvs.args} -D ${cvs.date}"
    }

    ui_info "$UI_PREFIX Checking out ${fetch.type} repository"

    array set orig_env [array get env]

    # create an empty passfile to suppress warnings from CVS
    close [open "$env(HOME)/.cvspass" w]

    try -pass_signal {
        if {[regexp ^:pserver: ${cvs.root}]} {
            set cmdstring "echo ${cvs.password} | ${cvs.cmd} -z9 -f -d ${cvs.root} login 2>&1"
            if {[catch {system -notty $cmdstring} result]} {
                error [msgcat::mc "CVS login failed: $result"]
            }
        } else {
            set env(CVS_RSH) ssh
        }

        set tmppath [mkdtemp "/tmp/macports.portfetch.${name}.XXXXXXXX"]
        set tmpxprt [file join ${tmppath} export]
        file mkdir ${tmpxprt}
        set cmdstring "${cvs.cmd} -z9 -f -d ${cvs.root} export -d ${cvs.file_prefix} ${cvs.args} ${cvs.module} 2>&1"
        if {[catch {system -notty -W ${tmpxprt} $cmdstring} result]} {
            delete ${tmppath}
            error [msgcat::mc "CVS checkout failed"]
        }

        if {![cvs_tarballable]} {
            file rename ${tmpxprt}/${svn.file_prefix} ${worksrcpath}
            return 0
        }

        ui_info "$UI_PREFIX Generating tarball ${cvs.file}"

        # get timestamp by looking for the newest file in the exported source
        set mtime 0
        fs-traverse f ${tmpxprt}/${cvs.file_prefix} {
            if {![file isdirectory $f]} {
                set ft [file mtime $f]
                if {$ft > $mtime} {
                    set mtime $ft
                }
            }
        }

        set tardst [join [list [mktemp "/tmp/macports.portfetch.${name}.XXXXXXXX"] ".tar"] ""]

        mktar $tardst $tmpxprt $mtime
        set compressed [compressfile ${tardst}]
        file rename -force ${compressed} ${generatedfile}

        ui_debug "Created tarball for fetch.type ${fetch.type} at ${generatedfile}"
    } catch {{*} ecode emessage} {
        throw
    } finally {
        # cleanup
        delete ${tmppath}

        array unset env *
        array set env [array get orig_env]
    }

    return 0
}

# Given a URL to a Subversion repository, if the URL is http:// or
# https:// and MacPorts has been configured with a proxy for that URL
# type, then return command line options that should be passed to the
# svn command line client to enable use of that proxy.  There are no
# proxies for Subversion's native protocol, identified by svn:// URLs.
proc portfetch::svn_proxy_args {url} {
    global env

    if {   [string compare -length 7 {http://} ${url}] == 0
        && [info exists env(http_proxy)]} {
        set proxy_str $env(http_proxy)
    } elseif {   [string compare -length 8 {https://} ${url}] == 0
              && [info exists env(HTTPS_PROXY)]} {
        set proxy_str $env(HTTPS_PROXY)
    } else {
        return ""
    }
    regexp {(.*://)?([[:alnum:].-]+)(:(\d+))?} $proxy_str - - proxy_host - proxy_port
    set ret "--config-option servers:global:http-proxy-host=${proxy_host}"
    if {$proxy_port ne ""} {
        append ret " --config-option servers:global:http-proxy-port=${proxy_port}"
    }
    return $ret
}

# Perform an svn fetch
proc portfetch::svnfetch {args} {
    global UI_PREFIX \
           distpath workpath worksrcpath \
           svn.cmd svn.args svn.revision svn.url svn.file svn.file_prefix \
           name distname fetch.type

    set generatedfile "${distpath}/${svn.file}"

    if {[svn_tarballable] && [file isfile "${generatedfile}"]} {
        return 0
    }

    if {[regexp {\s} ${svn.url}]} {
        return -code error [msgcat::mc "Subversion URL cannot contain whitespace"]
    }

    if {[string length ${svn.revision}]} {
        append svn.url "@${svn.revision}"
    }

    set proxy_args [svn_proxy_args ${svn.url}]

    ui_info "$UI_PREFIX Checking out ${fetch.type} repository"
    set tmppath [mkdtemp "/tmp/macports.portfetch.${name}.XXXXXXXX"]
    set tmpxprt [file join ${tmppath} export]
    set cmdstring "${svn.cmd} --non-interactive ${proxy_args} export ${svn.url} ${tmpxprt}/${svn.file_prefix} 2>&1"
    if {[catch {system $cmdstring} result]} {
        delete ${tmppath}
        return -code error [msgcat::mc "Subversion checkout failed"]
    }

    if {![svn_tarballable]} {
        file rename ${tmpxprt}/${svn.file_prefix} ${worksrcpath}
        return 0
    }

    ui_info "$UI_PREFIX Generating tarball ${svn.file}"

    # get timestamp of latest revision
    set cmdstring "${svn.cmd} --non-interactive ${proxy_args} info --show-item last-changed-date ${svn.url}"
    if {[catch {exec -ignorestderr sh -c $cmdstring} result]} {
        delete ${tmppath}
        return -code error [msgcat::mc "Subversion info failed"]
    }
    set tstamp $result
    set mtime [clock scan [lindex [split $tstamp "."] 0] -format "%Y-%m-%dT%H:%M:%S" -timezone "UTC"]

    set tardst [join [list [mktemp "/tmp/macports.portfetch.${name}.XXXXXXXX"] ".tar"] ""]

    mktar $tardst $tmpxprt $mtime
    set compressed [compressfile ${tardst}]
    file rename -force ${compressed} ${generatedfile}

    ui_debug "Created tarball for fetch.type ${fetch.type} at ${generatedfile}"

    # cleanup
    delete ${tmppath}

    return 0
}

# Check if a tarball can be produced for bzr
proc portfetch::bzr_tarballable {args} {
    global bzr.revision
    if {${bzr.revision} eq "" || ${bzr.revision} eq "-1"} {
        return no
    } else {
        return yes
    }
}

# Check if a tarball can be produced for cvs
proc portfetch::cvs_tarballable {args} {
    global cvs.tag cvs.date
    if {${cvs.tag} ni {"HEAD" ""} || ${cvs.date} ne ""} {
        return yes
    } else {
        return no
    }
}

# Check if a tarball can be produced for svn
proc portfetch::svn_tarballable {args} {
    global svn.revision
    if {${svn.revision} eq "" || ${svn.revision} eq "HEAD"} {
        return no
    } else {
        return yes
    }
}

# Check if a tarball can be produced for git
proc portfetch::git_tarballable {args} {
    global git.branch
    if {${git.branch} eq "" || ${git.branch} eq "HEAD"} {
        return no
    } else {
        return yes
    }
}

# Check if a tarball can be produced for hg
proc portfetch::hg_tarballable {args} {
    global hg.tag
    if {${hg.tag} eq "" || ${hg.tag} eq "tip"} {
        return no
    } else {
        return yes
    }
}

# Returns true if port is fetched from VCS and can be put into a tarball
proc portfetch::tarballable {args} {
    global fetch.type

    if {[info commands ${fetch.type}_tarballable] ne ""} {
        return [${fetch.type}_tarballable]
    }

    return no
}

# Returns true if port can be mirrored
proc portfetch::mirrorable {args} {
    global fetch.type checksums
    switch -- "${fetch.type}" {
        bzr -
        cvs -
        svn -
        git -
        hg {
            if {[info exists checksums] && $checksums eq ""} {
                ui_debug "port cannot be mirrored, no checksums for fetch.type ${fetch.type}"
                return no
            }
            if {![tarballable]} {
                ui_debug "port cannot be mirrored, not tarballable for fetch.type ${fetch.type}"
                return no
            }
            return yes
        }
        standard -
        default {
            return yes
        }
    }
}

# Perform a git fetch
proc portfetch::gitfetch {args} {
    global UI_PREFIX \
           distpath workpath worksrcpath \
           git.url git.branch git.fetch_submodules git.file git.file_prefix git.cmd \
           name distname fetch.type

    set generatedfile "${distpath}/${git.file}"

    if {[git_tarballable] && [file isfile "${generatedfile}"]} {
        return 0
    }

    set options "--progress"
    if {${git.branch} eq ""} {
        # If we're just using HEAD, we can make a shallow repo. In other cases,
        # it might cause a failure for some repos if the requested sha1 is not
        # reachable from any head.
        append options " --depth=1"
    }
    # XXX: this might be usable in some cases to reduce transfers, but does not always work
    #append options " --single-branch"
    #append options " --branch ${git.branch}"

    ui_info "$UI_PREFIX Cloning ${fetch.type} repository"
    set tmppath [mkdtemp "/tmp/macports.portfetch.${name}.XXXXXXXX"]
    set cmdstring "${git.cmd} clone -q $options ${git.url} ${tmppath} 2>&1"
    if {[catch {system $cmdstring} result]} {
        delete ${tmppath}
        return -code error [msgcat::mc "Git clone failed"]
    }

    # checkout branch
    # required to have the right version of .gitmodules
    if {${git.branch} ne ""} {
        ui_debug "Checking out branch ${git.branch}"
        set cmdstring "${git.cmd} checkout -q ${git.branch} 2>&1"
        if {[catch {system -W $tmppath $cmdstring} result]} {
            delete $tmppath
            return -code error [msgcat::mc "Git checkout failed"]
        }
    }

    # fetch all submodules
    if {[file isfile "$tmppath/.gitmodules"] && [tbool git.fetch_submodules]} {
        ui_info "$UI_PREFIX Cloning git submodules"
        set cmdstring "${git.cmd} submodule -q update --init --recursive 2>&1"
        if {[catch {system -W $tmppath $cmdstring} result]} {
            delete ${tmppath}
            return -code error [msgcat::mc "Git submodule init failed"]
        }
    }

    if {![git_tarballable]} {
        file rename ${tmppath} ${worksrcpath}
        return 0
    }

    ui_info "$UI_PREFIX Generating tarball ${git.file}"

    # generate main tarball
    set tardst [join [list [mktemp "/tmp/macports.portfetch.${name}.XXXXXXXX"] ".tar"] ""]
    set cmdstring "${git.cmd} archive --format=tar --prefix=\"${git.file_prefix}/\" --output=${tardst} ${git.branch} 2>&1"
    if {[catch {system -W $tmppath $cmdstring} result]} {
        delete $tardst
        delete $tmppath
        return -code error [msgcat::mc "Git archive creation failed"]
    }

    # generate tarballs for submodules and merge them into the main tarball
    if {[file isfile "$tmppath/.gitmodules"] && [tbool git.fetch_submodules]} {
        set xz [findBinary xz ${portutil::autoconf::xz_path}]
        # TODO: add dependency on libarchive, if /usr/bin/tar is not bsdtar
        set tar [findBinary bsdtar tar]
        # determine tmppath again in shell, as the real path might be different
        # due to symlinks (/tmp vs. /private/tmp), pass it as MPTOPDIR in
        # environment
        set cmdstring [join [list \
            "MPTOPDIR=\$PWD " \
            "${git.cmd} submodule -q foreach --recursive '" \
            "${git.cmd} archive --format=tar --prefix=\"${git.file_prefix}/\${PWD#\$MPTOPDIR/}/\" \$sha1 " \
            "| tar -uf ${tardst} @-" \
            "' 2>&1"] ""]
        if {[catch {system -W $tmppath $cmdstring} result]} {
            delete $tardst
            delete $tmppath
            return -code error [msgcat::mc "Git submodule archive creation failed"]
        }
    }

    # compress resulting tarball
    set compressed [compressfile ${tardst}]
    file rename -force ${compressed} ${generatedfile}

    ui_debug "Created tarball for fetch.type ${fetch.type} at ${generatedfile}"

    # cleanup
    delete ${tmppath}

    return 0
}

# Perform a mercurial fetch.
proc portfetch::hgfetch {args} {
    global UI_PREFIX \
           distpath worksrcpath \
           hg.cmd hg.url hg.tag hg.file hg.file_prefix \
           name distname fetch.type fetch.ignore_sslcert

    set generatedfile "${distpath}/${hg.file}"

    if {[hg_tarballable] && [file isfile "${generatedfile}"]} {
        return 0
    }

    ui_info "$UI_PREFIX Checking out ${fetch.type} repository"

    set insecureflag ""
    if {${fetch.ignore_sslcert}} {
        set insecureflag " --insecure"
    }

    set tmppath [mkdtemp "/tmp/macports.portfetch.${name}.XXXXXXXX"]
    set tmpxprt [file join ${tmppath} export]
    set cmdstring "${hg.cmd} clone${insecureflag} --rev \"${hg.tag}\" ${hg.url} ${tmpxprt}/${hg.file_prefix} 2>&1"
    if {[catch {system $cmdstring} result]} {
        delete ${tmppath}
        return -code error [msgcat::mc "Mercurial clone failed"]
    }

    if {![hg_tarballable]} {
        file rename ${tmpxprt}/${hg.file_prefix} ${worksrcpath}
        return 0
    }

    ui_info "$UI_PREFIX Generating tarball ${hg.file}"

    # get timestamp of latest revision
    set cmdstring "${hg.cmd} log -r ${hg.tag} --template=\"{date}\"i -R ${tmpxprt}/${hg.file_prefix}"
    if {[catch {exec -ignorestderr sh -c $cmdstring} result]} {
        delete ${tmppath}
        return -code error [msgcat::mc "Mercurial log failed"]
    }
    set mtime $result

    set tardst [join [list [mktemp "/tmp/macports.portfetch.${name}.XXXXXXXX"] ".tar"] ""]

    mktar $tardst $tmpxprt $mtime
    set compressed [compressfile ${tardst}]
    file rename -force ${compressed} ${generatedfile}

    ui_debug "Created tarball for fetch.type ${fetch.type} at ${generatedfile}"

    # cleanup
    delete ${tmppath}

    return 0
}

# Perform a standard fetch, assembling fetch urls from
# the listed url variable and associated distfile
proc portfetch::fetchfiles {args} {
    global distpath all_dist_files UI_PREFIX \
           fetch.user fetch.password fetch.use_epsv fetch.ignore_sslcert fetch.remote_time \
           portverbose
    variable fetch_urls
    variable urlmap

    set fetch_options {}
    if {[string length ${fetch.user}] || [string length ${fetch.password}]} {
        lappend fetch_options -u
        lappend fetch_options "${fetch.user}:${fetch.password}"
    }
    if {${fetch.use_epsv} ne "yes"} {
        lappend fetch_options "--disable-epsv"
    }
    if {${fetch.ignore_sslcert} ne "no"} {
        lappend fetch_options "--ignore-ssl-cert"
    }
    if {${fetch.remote_time} ne "no"} {
        lappend fetch_options "--remote-time"
    }
    if {$portverbose eq "yes"} {
        lappend fetch_options "--progress"
        lappend fetch_options "builtin"
    } elseif {[llength [info commands ui_progress_download]] > 0} {
        lappend fetch_options "--progress"
        lappend fetch_options "ui_progress_download"
    }
    set sorted no

    foreach {url_var distfile} $fetch_urls {
        if {![file isfile "${distpath}/${distfile}"]} {
            ui_info "$UI_PREFIX [format [msgcat::mc "%s does not exist in %s"] $distfile $distpath]"
            if {![file writable $distpath]} {
                return -code error [format [msgcat::mc "%s must be writable"] $distpath]
            }
            if {!$sorted} {
                sortsites fetch_urls master_sites
                set sorted yes
            }
            if {![info exists urlmap($url_var)]} {
                ui_error [format [msgcat::mc "No defined site for tag: %s, using master_sites"] $url_var]
                set urlmap($url_var) $urlmap(master_sites)
            }
            unset -nocomplain fetched
            set lastError ""
            foreach site $urlmap($url_var) {
                ui_notice "$UI_PREFIX [format [msgcat::mc "Attempting to fetch %s from %s"] $distfile $site]"
                set file_url [portfetch::assemble_url $site $distfile]
                try -pass_signal {
                    curl fetch {*}$fetch_options $file_url "${distpath}/${distfile}.TMP"
                    file rename -force "${distpath}/${distfile}.TMP" "${distpath}/${distfile}"
                    set fetched 1
                    break
                } catch {{*} eCode eMessage} {
                    ui_debug [msgcat::mc "Fetching distfile failed: %s" $eMessage]
                    set lastError $eMessage
                } finally {
                    file delete -force "${distpath}/${distfile}.TMP"
                }
            }
            if {![info exists fetched]} {
                if {$lastError ne ""} {
                    error $lastError
                } else {
                    error [msgcat::mc "fetch failed"]
                }
            }
        }
    }
    return 0
}

# Utility function to delete fetched files.
proc portfetch::fetch_deletefiles {args} {
    global distpath fetch.type svn.file git.file
    variable fetch_urls
    foreach {url_var distfile} $fetch_urls {
        if {[file isfile $distpath/$distfile]} {
            file delete -force "${distpath}/${distfile}"
        }
    }

    switch -- "${fetch.type}" {
        svn {
            if {[file isfile "${distpath}/${svn.file}"]} {
                file delete -force "${distpath}/${svn.file}"
            }
        }
        git {
            if {[file isfile "${distpath}/${git.file}"]} {
                file delete -force "${distpath}/${git.file}"
            }
        }
    }
}

# Utility function to add files to a list of fetched files.
proc portfetch::fetch_addfilestomap {filemapname} {
    global distpath fetch.type svn.file git.file $filemapname
    variable fetch_urls
    foreach {url_var distfile} $fetch_urls {
        if {[file isfile $distpath/$distfile]} {
            filemap set $filemapname $distpath/$distfile 1
        }
    }

    switch -- "${fetch.type}" {
        svn {
            if {[svn_tarballable] && [file isfile "${distpath}/${svn.file}"]} {
                filemap set $filemapname ${distpath}/${svn.file} 1
            }
        }
        git {
            if {[git_tarballable] && [file isfile "${distpath}/${git.file}"]} {
                filemap set $filemapname ${distpath}/${git.file} 1
            }
        }
    }
}

# Initialize fetch target and call checkfiles.
proc portfetch::fetch_init {args} {
    global fetch.type distname all_dist_files
    variable fetch_urls

    portfetch::checkfiles fetch_urls

    if {[tarballable]} {
        global ${fetch.type}.file
        lappend all_dist_files [set ${fetch.type}.file]
        distfiles-append [set ${fetch.type}.file]
    }
}

proc portfetch::fetch_start {args} {
    global UI_PREFIX subport distpath

    ui_notice "$UI_PREFIX [format [msgcat::mc "Fetching distfiles for %s"] $subport]"

    # create and chown $distpath
    if {![file isdirectory $distpath]} {
        if {[catch {file mkdir $distpath} result]} {
            elevateToRoot "fetch"
            if {[catch {file mkdir $distpath} result]} {
                return -code error [format [msgcat::mc "Unable to create distribution files path: %s"] $result]
            }
            chownAsRoot $distpath
            dropPrivileges
        }
    }
    if {![file owned $distpath]} {
        if {[catch {chownAsRoot $distpath} result]} {
            if {[file writable $distpath]} {
                ui_warn "$UI_PREFIX [format [msgcat::mc "Couldn't change ownership of distribution files path to macports user: %s"] $result]"
            } else {
                return -code error [format [msgcat::mc "Distribution files path %s not writable and could not be chowned: %s"] $distpath $result]
            }
        }
    }

    portfetch::check_dns
}

# Main fetch routine
# If all_dist_files is not populated and $fetch.type == standard, then
# there are no files to download. Otherwise, either do a cvs checkout
# or call the standard fetchfiles procedure
proc portfetch::fetch_main {args} {
    global all_dist_files fetch.type patchfiles

    # Check for files, download if necessary
    if {![info exists all_dist_files] && "${fetch.type}" eq "standard"} {
        return 0
    }

    # Fetch the files
    switch -- "${fetch.type}" {
        bzr     { bzrfetch }
        cvs     { cvsfetch }
        svn     { svnfetch }
        git     { gitfetch }
        hg      { hgfetch }
    }

    if {${fetch.type} eq "standard" || ${fetch.type} eq "default" || [info exists patchfiles]} {
        return [portfetch::fetchfiles]
    }
}
