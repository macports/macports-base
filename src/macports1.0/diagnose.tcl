# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# diagnose.tcl
#
# Copyright (c) 2002-2003 Apple Inc.
# Copyright (c) 2004-2005 Paul Guyot, <pguyot@kallisys.net>.
# Copyright (c) 2004-2006 Ole Guldberg Jensen <olegb@opendarwin.org>.
# Copyright (c) 2004-2005 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2004-2014, 2016-2018 The MacPorts Project
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

# Todo:

# Done:
# Add -q for quiet mode, where we don't print anything
# Check for command line tools
# Check for any DYLD_* environment variables
# Check for '.la' in dylib and '.prl'
# Check if installed files are readable
# Check for sqlite
# Check for openssl
# Crowd-source more ideas from the mailing-list
# Check if $PATH is first
# Check for issues with compilation. Compile small, simple file, check for "couldn't create cache file"
# check_for_stray_developer_directory
# Check for *.h, *.hpp, *.hxx in /usr/local/include
# Check for *.dylib in /usr/local/lib
# Check for other package managers. Fink = /sw, homebrew = /usr/local/Cellar
# Check for all files installed by ports exists
# Check for archives from all ports exists
# Check for things in /usr/local
# Check for x11.app if the OS is 10.6 and suggest installing xorg-server or the xquartz site
# Add error catching for lines without an equals sign.
# Support comments for the parser
# Check for amount of drive space
# Move port_diagnose.ini to the port tree, below _resources
# Check for curl
# Check for rsync
# Check if macports is in /opt/local


package provide diagnose 1.0

package require macports
package require reclaim 1.0

namespace eval diagnose {

    # Command line argument that determines whether or not to output things fancily.
    variable quiet 0

    proc main {opts} {

        # The main function. Handles all the calls to the correct functions, and sets the config_options array,
        # as well as the parser_options array.
        #
        # Args:
        #           opts - The options passed in. Currently the only option available is 'quiet'.
        # Returns:
        #           None

        # Setting the 'quiet' variable based on what was passed in.
        if {$opts ne ""} {
            set diagnose::quiet 1
        } else {
            set diagnose::quiet 0
        }

        array set config_options    [list]
        set parser_options          [list macports_location profile_path shell_location \
                                    xcode_version_${macports::macos_version_major} xcode_build]

        set user_config_path        "${macports::autoconf::macports_conf_path}/port_diagnose.ini"
        set xcode_config_path       [macports::getdefaultportresourcepath "macports1.0/xcode_versions.ini"]

        # Make sure the xcode config exists
        check_xcode_config $xcode_config_path

        # Read the config files
        get_config config_options $parser_options $user_config_path
        get_config config_options $parser_options $xcode_config_path
        if {![info exists config_options(macports_location)]} {
            set config_options(macports_location) "${macports::prefix}"
        }
        if {![info exists config_options(profile_path)]} {
            set config_options(profile_path) "${macports::user_home}/.bash_profile"
        }
        if {![info exists config_options(shell_location)]} {
            if {[info exists macports::sudo_user]} {
                set username ${macports::sudo_user}
            } else {
                set username [exec id -un]
            }
            set config_options(shell_location) [lindex [exec /usr/bin/dscl . -read "/Users/${username}" shell] end]
        }

        # Start the checks
        check_path $config_options(macports_location) $config_options(profile_path) $config_options(shell_location)
        check_xcode config_options
        check_for_app curl
        check_for_app rsync
        check_for_app openssl
        check_for_app sqlite3
        check_macports_location
        check_free_space
        check_for_x11
        check_for_files_in_usr_local
        check_tarballs
        check_port_files
        check_for_package_managers
        check_for_stray_developer_directory
        check_compilation_error_cache
        check_for_dyld
        check_for_clt
    }

    proc check_for_clt {} {

        # Checks to see if the Xcode Command Line Tools are installed by checking if the file
        # /Library/Developer/CommandLineTools exists if the system is running 10.9, or if they're
        # running an older version, if the command xcode-select -p outputs something.
        #
        # Args:
        #           None
        # Returns:
        #           None

        output "command line tools"

        if {${macports::macos_version_major} eq "10.9"} {

            if {![file exists "/Library/Developer/CommandLineTools/"]} {

                ui_warn "Xcode Command Line Tools are not installed! To install them, please enter the command:
                                    xcode-select --install"
                success_fail 0
                return
            }
            success_fail 1
            return

        } else {

            set xcode_select [exec xcode-select -print-path]

            if {$xcode_select eq ""} {

                ui_warn "Xcode Command Line Tools are not installed! To install them, please enter the command:
                                    xcode-select --install"
                success_fail 0
                return
            }
            success_fail 1
        }
    }

    proc check_for_dyld {} {

        # Checks to see if the current MacPorts session is running with a DYLD_* environment
        # variable set.
        #
        # Args:
        #           None
        # Returns:
        #           None

        output "DYLD_* environment variables"

        set printenv        [exec printenv]
        set split           [split $printenv]

        if {[regexp {DYLD_.} $split]} {
            ui_warn "found a DYLD_* environment variable. These are known to cause issues with MacPorts. Please\
                     unset the variable for the duration MacPorts is running."

            success_fail 0
            return
        }

        success_fail 1
   }

    proc output {string} {

        # Outputs the given string formatted correctly.
        #
        # Args:
        #           string - The string to be output
        # Returns:
        #           None

        if {!${diagnose::quiet}} {
            ui_info -nonewline "Checking for $string... "
        }
    }

    proc success_fail {result} {

        # Either outputs a [SUCCESS] or [FAILED], depending on the result.
        #
        # Args:
        #           result - An integer value. 1 = [SUCCESS], anything else = [FAILED]
        # Returns:
        #           None

        if {!${diagnose::quiet}} {

            if {$result == 1} {

                ui_info "\[SUCCESS\]"
                return
            }

            ui_info "\[FAILED\]"
        }
    }

    proc check_compilation_error_cache {} {

        # Checks to see if the compiler can compile properly, or it throws the error, "couldn't create cache file".
        #
        # Args:
        #           None
        # Returns:
        #           None

        # TODO: Should we drop privileges?

        output "compilation errors"

        # 'clang' will fail when using
        # https://trac.macports.org/wiki/UsingTheRightCompiler#testing
        if {![file isfile /usr/bin/cc]} {
            ui_error "No compiler found at /usr/bin/cc"
            success_fail 0
            return
        }

        set builddir "[macports::gettmpdir]/port_diagnose"
        file mkdir $builddir
        set filepath    "${builddir}/test.c"
        set fd          [open $filepath w]

        puts $fd "int main() { return 0; }"
        close $fd

        catch {exec /usr/bin/cc $filepath -o "${builddir}/main_test"} output

        file delete -force $builddir

        if {[string length $output] > 0} {
            # Some type of error
            if {[string match "*couldn't create cache file*" $output]} {
                ui_warn "found errors when attempting to compile file. To fix this issue, delete your tmp folder using:
                       rm -rf \$TMPDIR"
            } else {
                ui_warn $output
            }
            success_fail 0
            return
        }

        success_fail 1

    }

    proc check_for_stray_developer_directory {} {

        # Checks to see if the script to remove leftover files from Xcode has been run or not. Implementation heavily influenced
        # by Homebrew implementation.
        #
        # Args:
        #           None
        # Returns:
        #           None

        output "stray developer directory"

        set uninstaller "/Developer/Library/uninstall-developer-folder"

        if {${macports::xcodeversion} >= 4.3 && [file exists $uninstaller]} {
            ui_warn "you have leftover files from an older version of Xcode. You should delete them by using, $uninstaller"

            success_fail 0
            return
        }

        success_fail 1
    }

    proc check_for_package_managers {} {

        # Checks to see if either Fink or Homebrew are installed on the system. If they are, it warns them and suggest they uninstall
        # or move them to a different location.
        #
        # Args:
        #           None
        # Returns:
        #           None

        output "HomeBrew"

        if {[file exists "/usr/local/Cellar"]} {
            ui_warn "it seems you have Homebrew installed on this system -- Because Homebrew uses /usr/local, this can potentially cause issues\
                     with MacPorts. We'd recommend you either uninstall it, or move it from /usr/local for now."

            success_fail 0

        } else {

            success_fail 1
        }

        output "Fink"
        if {[file exists "/sw"]} {
            ui_warn "it seems you have Fink installed on your system -- This could potentially cause issues with MacPorts. We'd recommend you\
                     either uninstall it, or move it from /sw for now."

            success_fail 0

        } else {

            success_fail 1
        }
    }

    proc check_port_files {} {

        # Checks to see if each file installed by all active and installed ports actually exists on the filesystem. If not, it warns
        # the user and suggests the user deactivate and reactivate the port.
        #
        # Args:
        #           None
        # Returns:
        #           None


        set apps [registry::entry imaged]

        array set activeApps {}
        set totalFiles 0

        foreach app $apps {
            set files [$app files]
            if {[$app state] eq "installed"} {
                set activeApps([$app name]) $files
                incr totalFiles [llength $files]
            }
        }

        set fancyOutput [expr {   ![macports::ui_isset ports_debug] \
                               && ![macports::ui_isset ports_verbose] \
                               && [info exists macports::ui_options(progress_generic)] \
                               && !${diagnose::quiet}}]

        if {$fancyOutput} {
            set progress $macports::ui_options(progress_generic)
        }

        if {$totalFiles > 0} {
            if {$fancyOutput} {
                output "files installed by ports on disk"
                if {!${diagnose::quiet}} {
                    # we need a newline here or the progress bar will overwrite the line
                    ui_msg ""
                }
                $progress start
            }

            set currentFile 1
            foreach name [lsort [array names activeApps]] {
                foreach file $activeApps($name) {
                    if {$fancyOutput} {
                        $progress update $currentFile $totalFiles
                    } else {
                        output "file '$file' on disk"
                    }

                    if {[catch {file type $file}]} {
                        if {$fancyOutput} {
                            $progress intermission
                        } else {
                            success_fail 0
                        }
                        ui_warn "couldn't find file '$file' for port '$name'. Please deactivate and reactivate the port to fix this issue."
                    } elseif {!$fancyOutput} {
                        success_fail 1
                    }
                    # TODO: check permissions against those in the port image.
                    # Can't just check for readability because some files
                    # (and/or their parent directories) should not be readable
                    # by normal users for various reasons.

                    incr currentFile
                }
            }

            if {$fancyOutput} {
                $progress finish
            }
        }
    }

    proc check_tarballs {} {

        # Checks if the archives for each installed port in /opt/local/var/macports/software/$name is actually in there. If not, it warns
        # the user and suggest a reinstallation of the port.
        #
        # Args:
        #           None
        # Returns:
        #           None

        set ports [registry::entry imaged]

        foreach port $ports {
            if {![file exists [$port location]]} {
                ui_warn "couldn't find the archive for '[$port name] @[$port version]_[$port revision][$port variants]'. Please uninstall and reinstall this port."
            }
        }
    }

    proc check_for_files_in_usr_local {} {

        # Checks for dylibs in /usr/local/lib and header files in /usr/local/include, and warns the user about said files if they
        # are found.
        #
        # Args:
        #           None
        # Returns:
        #           None

        output "dylibs in /usr/local/lib"

        if {[glob -nocomplain -directory "/usr/local/lib" *.dylib *.la *.prl] ne ""} {
            ui_warn "found dylibs in your /usr/local/lib directory. These are known to cause problems. We'd recommend\
                     you remove them."

            success_fail 0

        } else {

            success_fail 1
        }

        output "header files in /usr/local/include"

        if {[glob -nocomplain -directory "/usr/local/include" *.h *.hpp *.hxx] ne ""} {
            ui_warn "found header files in your /usr/local/include directory. These are known to cause problems. We'd recommend\
                     you remove them."

            success_fail 0

        } else {

            success_fail 1
        }
    }

    proc check_for_x11 {} {

        # Checks to see if the user is using the X11.app, and if they're on 10.6. If they are, it alerts them about it.
        #
        # Args:
        #           None
        # Returns:
        #           None

        if {${macports::macos_version_major} eq "10.6"} {
            output "X11.app on Mac OS X 10.6 systems"

            if {[file exists /Applications/X11.app]} {
                ui_error "it seems you have Mac OS X 10.6 installed, and are using X11 from \"X11.app\". This has been known to cause issues.\
                         To fix this, please install xorg-server, by using the command 'sudo port install xorg-server', or installing it from\
                         their website, https://www.xquartz.org/releases/."

                success_fail 0
                return
            }
            success_fail 1
        }
    }

    proc check_free_space {} {

        # Checks to see if the user has less than 5 gigs of space left, and warns if they don't.
        #
        # Args:
        #           None
        # Returns:
        #           None

        output "free disk space"

        set output          [exec df -g]
        set tokens          [split $output \n]
        set disk_info       [lindex $tokens 1]
        set available       [lindex $disk_info 3]

        if {$available < 5} {
            ui_warn "you have less than 5 GiB of free disk space! This can cause serious errors. We recommend trying to clear out unnecessary\
                     programs and files by running 'sudo port reclaim', or manually uninstalling/deleting programs and folders on your drive."

            success_fail 0
            return
        }

        success_fail 1
    }

    proc check_macports_location {} {

        # Checks to see if port is where it should be. If it isn't, freak the frick out.
        #
        # Args:
        #           None
        # Returns:
        #           None

        output "MacPorts' location"

        if {![file exists ${macports::prefix}/bin/port]} {
            ui_error "the port command was not found in ${macports::prefix}/bin. This can potentially cause errors. It's recommended you move it back to ${macports::prefix}/bin."
            success_fail 0
            return
        }

        success_fail 1
   }

    proc check_for_app {app} {

        # Check's if the binary supplied exists in /usr/bin. If it doesn't, it warns the user.
        #
        # Args:
        #           app - The name of the app to check for.
        # Returns
        #           None

        output "for '$app'"

        if {![file exists /usr/bin/$app]} {
            ui_error "$app is needed by MacPorts to function normally, but wasn't found on this system. We'd recommend\
                      installing it for continued use of MacPorts."
            success_fail 0
            return
        }

        success_fail 1
    }

    proc check_xcode {config_options} {

        # Checks to see if the currently installed version of Xcode works with the curent OS version.
        #
        # Args:
        #           config_options - The associative array containing all options in the config files
        # Returns:
        #           None

        output "correct Xcode version"

        upvar $config_options config

        set mac_version     ${macports::macos_version_major}
        set xcode_current   ${macports::xcodeversion}
        if {[info exists config(xcode_version_$mac_version)]} {
            set xcode_versions  $config(xcode_version_$mac_version)
        } else {
            ui_warn "No Xcode version info was found for your OS version."
            success_fail 0
            return
        }

        if {$xcode_current in $xcode_versions} {
            success_fail 1
        } else {
            ui_error "currently installed version of Xcode, $xcode_current, is not supported by MacPorts. \
                      For your currently installed system, only the following versions of Xcode are supported: \
                      $xcode_versions"
            success_fail 0
        }
    }

    proc check_xcode_config {path} {

        # Checks to see if xcode_versions.ini exists. If it does, it returns. If it doesn't, then it raises an error.
        #
        # Args:
        #           None
        # Returns:
        #           None

        if {![file exists $path]} {
            ui_error "No configuration file found at $path. Please run,
                        \"port selfupdate\""
            error "missing [file tail $path]"

        }
    }

    proc get_config {config_options parser_options path} {

        # Reads in and parses the configuration file passed in to $path. After parsing, all variables found are assigned
        # in the 'config_options' associative array.
        #
        # Args:
        #           config_options - The associative array responsible for holding all the configuration options.
        #           parser_options - The list responsible for holding each option to set/look for in the configuration file.
        #           path           - The path to the correct config_file
        # Returns:
        #           None.

        if {![file isfile $path]} {
            return
        }

        upvar $config_options config

        set fd   [open $path r]
        set text [read $fd]
        set data [split $text "\n"]

        close $fd

        foreach line $data {

            # Ignore comments
            if {[string index $line 0] eq "#"} {
                continue
            }

            #The tokens
            set tokens [split $line "="]

            # Only care about things that are in $parser_options
            if {[lindex $tokens 0] in $parser_options} {
                set config([lindex $tokens 0]) [lindex $tokens 1]

            # Ignore whitespace
            } elseif {[lindex $tokens 0] eq ""} {
                continue

            } elseif {![string match xcode_version_* [lindex $tokens 0]]} {
                ui_error "unrecognized config option in file $path: [lindex $tokens 0]"
            }
        }
    }

    proc check_path {port_loc profile_path shell_loc} {

        # Checks to see if port_location/bin and port_location/sbin are in the $PATH environment variable.
        # If they aren't, it appends it to the correct shell's profile file.
        #
        # Args:
        #           port_loc        - The location of port (as set in the config file)
        #           profile_path    - The location of the profile file (as set in the config file)
        #           shell_loc       - The location of the shell binary (as set in the config file)
        # Returns:
        #           None.

        set known_shells [list bash csh ksh sh tcsh zsh]
        set shell_name [file tail $shell_loc]
        if {$shell_name ni $known_shells} {
            return
        }

        set path ${macports::user_path}
        set split [split $path :]

        if {"$port_loc/bin" ni $split || "$port_loc/sbin" ni $split} {
            ui_warn "Your \$PATH environment variable does not currently include $port_loc/bin or $port_loc/sbin"

            ui_msg "Please refer to the guide on how to configure your shell:"
            ui_msg "  https://guide.macports.org/#installing.shell"

            # XXX Only works for bash. Should set default profile_path based on the shell.
            if {[info exists macports::ui_options(questions_yesno)] && $shell_name eq "bash"} {
                ui_msg "MacPorts can also write the required configuration to $profile_path for you."
                set question "Would you like to add $port_loc/bin to your \$PATH variable now?"
                set retval [$macports::ui_options(questions_yesno) $msg "DiagnoseFixPATH" "" n 0 $question]
                if {$retval == 0} {
                    # XXX: this should use the same paths and comments as the
                    # postflight script of the pkg installer. Maybe they could even
                    # share code?
                    ui_debug "Attempting to add $port_loc/bin to $profile_path"

                    if {[file exists $profile_path]} {
                        if {[file writable $profile_path]} {
                            # XXX: Should keep a backup like postflight script does
                            set fd [open $profile_path a]
                            puts $fd ""
                            puts $fd "# MacPorts diagnose addition on [clock format $date -format "%Y-%m-%dT%H:%M:%S%z"]"
                            puts $fd "export PATH=$port_loc/bin:$port_loc/sbin:\$PATH"
                            puts $fd ""
                            close $fd

                            ui_msg "Added PATH environment variable to your $shell_name configuration. It is important that you now close this terminal window and then open a new terminal window to load the modified environment from ${profile_path}."
                        } else {
                            ui_error "Can't write to ${profile_path}."
                        }
                    } else {
                        ui_error "$profile_path does not exist."
                    }
                } else {
                    ui_msg "Not fixing your \$PATH variable."
                }
            }
       }
   }
}
