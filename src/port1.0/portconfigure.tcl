# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2007 - 2020 The MacPorts Project
# Copyright (c) 2007 Markus W. Weissmann <mww@macports.org>
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

package provide portconfigure 1.0

set org.macports.configure [target_new org.macports.configure portconfigure::configure_main]
target_provides ${org.macports.configure} configure
target_requires ${org.macports.configure} main fetch checksum extract patch
target_prerun ${org.macports.configure} portconfigure::configure_start
target_postrun ${org.macports.configure} portconfigure::configure_finish
target_runpkg ${org.macports.configure} portconfigure_run

namespace eval portconfigure {
    # configure_get_default_compiler is fairly expensive, so cache the result
    variable recompute_default_compiler 1
    variable cached_default_compiler {}
    variable no_default_compiler_allowed 0
}


# ********** BEGIN C++ / OBJECTIVE-C++ **********

options configure.cxx \
        configure.cxx_archflags \
        configure.cxx_stdlib \
        configure.cxxflags \
        configure.objcxx \
        configure.objcxx_archflags \
        configure.objcxxflags \
        configure.universal_cxxflags \
        configure.universal_objcxxflags

default configure.cxx                   {[portconfigure::configure_get_compiler cxx]}
default configure.cxx_archflags         {[portconfigure::configure_get_archflags cxx]}
default configure.cxx_stdlib            {[portconfigure::configure_get_cxx_stdlib]}
default configure.cxxflags \
        {[portconfigure::construct_cxxflags ${configure.optflags}]}
default configure.objcxx                {[portconfigure::configure_get_compiler objcxx]}
default configure.objcxx_archflags      {[portconfigure::configure_get_archflags objcxx]}
# No current reason for OBJCXXFLAGS to differ from CXXFLAGS.
default configure.objcxxflags           {${configure.cxxflags}}
default configure.universal_cxxflags    {[portconfigure::configure_get_universal_archflags]}
default configure.universal_objcxxflags {${configure.universal_cxxflags}}

# Don't let Portfiles trash "-stdlib"; if they want to remove it, they
# should clear configure.cxx_stdlib.
option_proc configure.cxxflags portconfigure::stdlib_trace
option_proc configure.objcxxflags portconfigure::stdlib_trace

proc portconfigure::should_add_stdlib {} {
    global configure.cxx configure.cxx_stdlib
    if {${configure.cxx_stdlib} eq ""} {
        return 0
    }
    if {[string match *clang* ${configure.cxx}]} {
        return 1
    }
    # GCC also supports -stdlib starting with GCC 10 (and devel), but
    # not with PPC builds
    global configure.build_arch
    if {[string match *g*-mp-* ${configure.cxx}]
            && ${configure.build_arch} ni {ppc ppc64}} {
        # Do not pass stdlib to gcc if it is MacPorts custom macports-libstdc++ setting
        # as gcc does not uderstand this. Instead do nothing, which means gcc will
        # default to using its own libstdc++, which is in fact what we mean by
        # configure.cxx_stdlib=macports-libstdc++
        if {${configure.cxx_stdlib} ne "macports-libstdc++"} {
            # Extract gcc version from value after last -
            set gcc_ver [lindex [split ${configure.cxx} "-"] end]
            if { ${gcc_ver} eq "devel" || ${gcc_ver} >= 10 } {
                return 1
            }
        }
    }
    return 0
}
proc portconfigure::should_add_cxx_abi {} {
    # prior to OS X Mavericks, libstdc++ was the default C++ runtime, so
    #    assume MacPorts libstdc++ must be ABI compatible with system libstdc++
    # for OS X Mavericks and above, users must select libstdc++, so
    #    assume they want default ABI compatibility
    # see https://gcc.gnu.org/onlinedocs/gcc-5.2.0/libstdc++/manual/manual/using_dual_abi.html
    global os.platform os.major configure.cxx_stdlib
    return [expr {${os.major} < 13 &&
                  ${os.platform} eq "darwin" &&
                  ${configure.cxx_stdlib} eq "macports-libstdc++"}]
}
proc portconfigure::construct_cxxflags {flags} {
    if {[should_add_stdlib]} {
        global configure.cxx_stdlib
        lappend flags -stdlib=${configure.cxx_stdlib}
    }
    if {[should_add_cxx_abi]} {
        lappend flags -D_GLIBCXX_USE_CXX11_ABI=0
    }
    return $flags
}
proc portconfigure::stdlib_trace {opt action args} {
    global $opt
    foreach flag [lsearch -all -inline [set $opt] -stdlib=*] {
        $opt-delete $flag
    }
    foreach flag [lsearch -all -exact -inline [set $opt] -D_GLIBCXX_USE_CXX11_ABI=0] {
        $opt-delete $flag
    }
    if {$action eq "read"} {
        if {[should_add_stdlib]} {
            global configure.cxx_stdlib
            $opt-append -stdlib=${configure.cxx_stdlib}
        }
        if {[should_add_cxx_abi]} {
            $opt-append -D_GLIBCXX_USE_CXX11_ABI=0
        }
    }
}
# helper function to set configure.cxx_stdlib
proc portconfigure::configure_get_cxx_stdlib {} {
    global cxx_stdlib compiler.cxx_standard
    if {${compiler.cxx_standard} eq ""} {
        return ""
    } elseif {${cxx_stdlib} eq "libstdc++" && ${compiler.cxx_standard} >= 2011} {
        return macports-libstdc++
    } else {
        return ${cxx_stdlib}
    }
}

# ********** END C++ / OBJECTIVE-C++ **********

# ********** Begin Fortran **********
options                            \
    compiler.require_fortran       \
    compiler.fortran_fallback
default compiler.require_fortran      no
default compiler.fortran_fallback    {[portconfigure::get_fortran_fallback]}
# ********** End Fortran **********

# define options
commands configure autoreconf automake autoconf xmkmf
# defaults
default configure.env       {}
default configure.pre_args  {--prefix=${prefix}}
default configure.cmd       ./configure
default configure.nice      {${buildnicevalue}}
default configure.dir       {${worksrcpath}}
default autoreconf.dir      {${worksrcpath}}
default autoreconf.args     {--install --verbose}
default autoconf.dir        {${worksrcpath}}
default autoconf.args       --verbose
default automake.dir        {${worksrcpath}}
default automake.args       --verbose
default xmkmf.cmd           xmkmf
default xmkmf.dir           {${worksrcpath}}
default use_configure       yes

option_proc use_autoreconf  portconfigure::set_configure_type
option_proc use_automake    portconfigure::set_configure_type
option_proc use_autoconf    portconfigure::set_configure_type
option_proc use_xmkmf       portconfigure::set_configure_type

option_proc autoreconf.cmd  portconfigure::set_configure_type
option_proc automake.cmd    portconfigure::set_configure_type
option_proc autoconf.cmd    portconfigure::set_configure_type
option_proc xmkmf.cmd       portconfigure::set_configure_type

##
# Local helper proc
proc portconfigure::add_build_dep { type dep } {
    global ${type}.cmd options::option_defaults

    if {![info exists ${type}.cmd] || (
        ([dict exists $option_defaults ${type}.cmd] && [set ${type}.cmd] eq [dict get $option_defaults ${type}.cmd]) ||
        (![dict exists $option_defaults ${type}.cmd] && [set ${type}.cmd] eq ${type})
        )} {
            # Add dependencies if they are not already in the list
            depends_build-delete {*}$dep
            depends_build-append {*}$dep
    }
}

##
# Adds dependencies for the binaries which will be called, but only if it is
# the default. If .cmd was overwritten the port has to care for deps itself.
proc portconfigure::set_configure_type {option action args} {
    if {$action eq "set"} {
        set configure_map [dict create \
            autoconf    [list port:autoconf port:automake port:libtool] \
            xmkmf       port:imake \
        ]
        switch $option {
            autoreconf.cmd  -
            automake.cmd    -
            autoconf.cmd {
                depends_build-delete {*}[dict get $configure_map autoconf]
            }
            xmkmf.cmd {
                depends_build-delete {*}[dict get $configure_map xmkmf]
            }
            use_xmkmf {
                if {[tbool args]} {
                    depends_build-append {*}[dict get $configure_map xmkmf]
                }
            }
            default {
                # strip "use_"
                set type [string range $option 4 end]
                if {[tbool args]} {
                    add_build_dep $type [dict get $configure_map autoconf]
                }
            }
        }
    }
}

options configure.asroot
default configure.asroot no

# Configure special environment variables.
# We could have m32/m64/march/mtune be global configurable at some point.
options configure.m32 configure.m64 configure.march configure.mtune
default configure.march     {}
default configure.mtune     {}
# We could have debug/optimizations be global configurable at some point.
options configure.optflags \
        configure.cflags \
        configure.objcflags \
        configure.cppflags configure.ldflags configure.libs \
        configure.fflags configure.f90flags configure.fcflags \
        configure.classpath
# compiler flags section
default configure.optflags      -Os
default configure.cflags        {${configure.optflags}}
default configure.objcflags     {${configure.optflags}}
default configure.cppflags      {[portconfigure::configure_get_cppflags]}
proc portconfigure::configure_get_cppflags {} {
    global prefix compiler.limit_flags
    if {${compiler.limit_flags}} {
        return {}
    } else {
        return -I${prefix}/include
    }
}
default configure.ldflags       {[portconfigure::configure_get_ldflags]}
proc portconfigure::configure_get_ldflags {} {
    global prefix compiler.limit_flags
    if {${compiler.limit_flags}} {
        return -Wl,-headerpad_max_install_names
    } else {
        return "-L${prefix}/lib -Wl,-headerpad_max_install_names"
    }
}
default configure.libs          {}
default configure.fflags        {${configure.optflags}}
default configure.f90flags      {${configure.optflags}}
default configure.fcflags       {${configure.optflags}}
default configure.classpath     {}

# tools section
options configure.perl configure.python configure.ruby \
        configure.install configure.awk configure.bison \
        configure.pkg_config configure.pkg_config_path
default configure.perl              {}
default configure.python            {}
default configure.ruby              {}
default configure.install           {[expr {$system_options(clonebin_path) ne "" ? [file join $system_options(clonebin_path) install] : ${::portutil::autoconf::install_command}}]}
default configure.awk               {}
default configure.bison             {}
default configure.pkg_config        {}
default configure.pkg_config_path   {}

options configure.build_arch configure.ld_archflags \
        configure.sdk_version configure.sdkroot \
        configure.sysroot configure.developer_dir
default configure.build_arch    {[portconfigure::choose_supported_archs $build_arch $supported_archs ${configure.sdk_version}]}
default configure.ld_archflags  {[portconfigure::configure_get_ld_archflags]}
default configure.sdk_version   {$macosx_sdk_version}
default configure.sdkroot       {[portconfigure::configure_get_sdkroot ${configure.sdk_version}]}
default configure.sysroot       {[expr {${configure.sdkroot} ne "" ? ${configure.sdkroot} : "/"}]}
default configure.developer_dir {[portconfigure::configure_get_developer_dir]}
foreach _portconfigure_tool {cc objc f77 f90 fc} {
    options configure.${_portconfigure_tool}_archflags
    default configure.${_portconfigure_tool}_archflags  "\[portconfigure::configure_get_archflags $_portconfigure_tool\]"
}

options configure.universal_archs configure.universal_args \
        configure.universal_cflags \
        configure.universal_objcflags \
        configure.universal_cppflags configure.universal_ldflags
default configure.universal_archs       {[portconfigure::choose_supported_archs $universal_archs $supported_archs ${configure.sdk_version}]}
default configure.universal_args        --disable-dependency-tracking
default configure.universal_cflags      {[portconfigure::configure_get_universal_archflags]}
default configure.universal_objcflags   {${configure.universal_cflags}}
default configure.universal_cppflags    {}
default configure.universal_ldflags     {[portconfigure::configure_get_universal_archflags]}

# Select a distinct compiler (C, C preprocessor, C++)
options configure.ccache configure.distcc configure.pipe configure.cc \
        configure.cpp configure.objc configure.f77 \
        configure.f90 configure.fc configure.javac configure.compiler \
        compiler.blacklist compiler.whitelist compiler.fallback
default configure.ccache        {${configureccache}}
default configure.distcc        {${configuredistcc}}
default configure.pipe          {${configurepipe}}
foreach _portconfigure_tool {cc objc cpp f77 f90 fc javac} {
    default configure.$_portconfigure_tool     "\[portconfigure::configure_get_compiler $_portconfigure_tool\]"
}
unset _portconfigure_tool
default configure.compiler      {[portconfigure::configure_get_default_compiler]}
default compiler.fallback       {[portconfigure::get_compiler_fallback]}
default compiler.blacklist      {}
default compiler.whitelist      {}

# Compiler Restrictions
#   compiler.c_standard            Standard for the C programming language (1989, 1999, 2011, etc.)
#   compiler.cxx_standard          Standard for the C++ programming language (1998, 2011, 2014, 2017, etc.)
#   compiler.openmp_version        Version of OpenMP required (blank, 2.5, 3.0, 3.1, 4.0, 4.5, etc.)
#   compiler.mpi                   MacPorts port that provides MPI (blank, mpich, openmpi)
#   compiler.thread_local_storage  Is thread local storage required, e.g. __thread, _Thread_local, std::thread_local (yes, no)
options                            \
    compiler.c_standard            \
    compiler.cxx_standard          \
    compiler.openmp_version        \
    compiler.mpi                   \
    compiler.thread_local_storage

default compiler.c_standard            {[expr {$supported_archs ne "noarch" ? 1989 : ""}]}
default compiler.cxx_standard          {[expr {$supported_archs ne "noarch" ? 1998 : ""}]}
default compiler.openmp_version        {}
default compiler.mpi                   {}
default compiler.thread_local_storage  no

# internal function to determine the compiler flags to select an arch
proc portconfigure::configure_get_archflags {tool} {
    global configure.build_arch configure.m32 configure.m64 configure.compiler
    set flags ""
    if {[tbool configure.m64]} {
        set flags "-m64"
    } elseif {[tbool configure.m32]} {
        set flags "-m32"
    } elseif {${configure.build_arch} ne ""} {
        if {[arch_flag_supported ${configure.compiler}] &&
            $tool in {cc cxx objc objcxx}
        } then {
            set flags "-arch ${configure.build_arch}"
        } elseif {${configure.build_arch} in [list arm64 ppc64 x86_64]} {
            set flags "-m64"
        } elseif {${configure.compiler} ne "gcc-3.3"} {
            set flags "-m32"
        }
    }
    return $flags
}

# internal function to determine the ld flags to select an arch
# Unfortunately there's no consistent way to do this when the compiler
# doesn't support -arch, because it could be used to link rather than using
# ld directly. So we punt and let portfiles deal with that case.
proc portconfigure::configure_get_ld_archflags {} {
    global configure.build_arch configure.compiler
    if {${configure.build_arch} ne "" && [arch_flag_supported ${configure.compiler}]} {
        return "-arch ${configure.build_arch}"
    } else {
        return ""
    }
}

proc portconfigure::configure_get_sdkroot {sdk_version} {
    global system_options os.platform os.major macos_version_major

    # Explicit override value
    if {[info exists system_options(macosx_sdk_path)]} {
        return $system_options(macosx_sdk_path)
    }

    # Use the DevSDK (eg: /usr/include) if present and the requested SDK version matches the host version
    if {${os.platform} ne "darwin" || (${os.major} < 19 && $sdk_version eq $macos_version_major && [file_exists /usr/include/sys/cdefs.h])} {
        return {}
    }

    global use_xcode
    return [_get_sdkroot $sdk_version [tbool use_xcode]]
}

# internal function to determine DEVELOPER_DIR according to Xcode dependency
proc portconfigure::configure_get_developer_dir {} {
    global use_xcode developer_dir
    # Assume that the existence of libxcselect indicates the earliest version of
    # macOS that places CLT in /Library/Developer/CommandLineTools
    # If port is Xcode-dependent or CommandLineTools directory is invalid, set to developer_dir
    if {[tbool use_xcode]} {
        return ${developer_dir}
    } else {
        return /Library/Developer/CommandLineTools
    }
}

# internal function to determine the "-arch xy" flags for the compiler
proc portconfigure::configure_get_universal_archflags {} {
    global configure.universal_archs
    set flaglist [list]
    foreach arch ${configure.universal_archs} {
        lappend flaglist -arch $arch
    }
    return [join $flaglist]
}

# changing these options will invalidate the cache
foreach varname {compiler.whitelist compiler.fallback compiler.blacklist
    compiler.c_standard compiler.cxx_standard compiler.openmp_version
    compiler.mpi compiler.thread_local_storage configure.cxx_stdlib} {
        trace add variable $varname write portconfigure::recompute_default_compiler_proc
}

proc portconfigure::recompute_default_compiler_proc {varname unused op} {
    variable recompute_default_compiler 1
}

# internal function to determine the default compiler
proc portconfigure::configure_get_default_compiler {} {
    variable recompute_default_compiler
    variable cached_default_compiler
    if {!$recompute_default_compiler} {
        return $cached_default_compiler
    }

    set recompute_default_compiler 0
    variable no_default_compiler_allowed 0
    global compiler.blacklist compiler.fallback compiler.whitelist configure.developer_dir
    set search_list [expr {[llength ${compiler.whitelist}] > 0 ? ${compiler.whitelist} : ${compiler.fallback}}]
    set result [choose_compiler $search_list ${compiler.blacklist} cc ${configure.developer_dir}]
    if {$result ne {}} {
        set cached_default_compiler $result
    } else {
        # Default to first compiler in the fallback list, and set a flag
        # so that a warning can be printed at an appropriate time.
        set no_default_compiler_allowed 1
        set cached_default_compiler [lindex ${compiler.fallback} 0]
    }
    return $cached_default_compiler
}

# internal function to determine the Fortran compiler
proc portconfigure::configure_get_fortran_compiler {} {
    global configure.compiler
    if {[configure_get_compiler fc ${configure.compiler}] ne ""} {
        return ${configure.compiler}
    }

    global compiler.fortran_fallback compiler.blacklist configure.developer_dir
    set result [choose_compiler ${compiler.fortran_fallback} ${compiler.blacklist} fc ${configure.developer_dir}]
    if {$result ne {}} {
        return $result
    }
    ui_warn "All Fortran compilers are either blacklisted or unavailable; defaulting to first fallback option"
    return [lindex ${compiler.fortran_fallback} 0]
}

#
# https://releases.llvm.org/3.1/docs/ClangReleaseNotes.html#cchanges
# _Noreturn implemented in clang 3.3.0:
# https://github.com/llvm/llvm-project/commit/debc59d1f360b1f7a041de72c02d76ed131370c6
# https://gcc.gnu.org/c99status.html
# https://gcc.gnu.org/wiki/C11Status
# https://trac.macports.org/wiki/XcodeVersionInfo
#--------------------------------------------------------------------
#|  C Standard  |   Clang   |  Xcode Clang  |   Xcode   |    GCC    |
#|------------------------------------------------------------------|
#| 1989 (C89)   |     -     |       -       |     -     |     -     |
#| 1999 (C99)   |     -     |       -       |     -     |    4.0    |
#| 2011 (C11)   |    3.3    |  500.2.75     |    5.0    |    4.9    |
#| 2017 (C17)   |    6.0    |  1000.11.45.2 |   10.0    |    8.0    |
#--------------------------------------------------------------------
#
# https://clang.llvm.org/cxx_status.html
# https://gcc.gnu.org/projects/cxx-status.html
# https://en.cppreference.com/w/cpp/compiler_support
# Xcode release notes
# https://trac.macports.org/wiki/XcodeVersionInfo
#-----------------------------------------------------------------------
#| C++ Standard |   Clang   |  Xcode Clang   |   Xcode   |     GCC     |
#|---------------------------------------------------------------------|
#| 1998 (C++98) |     -     |       -        |     -     |      -      |
#| 2011 (C++11) |    3.3    |   500.2.75     |    5.0    |    4.8.1    |
#| 2014 (C++14) |    3.4    |   602.0.49     |    6.3    |      5      |
#| 2017 (C++17) |    5.0    |  1000.11.45.2  |   10.0    |      7      |
#| 2020 (C++20) |    16     |  1500(?)       |   15.0(?) |     12      |
#-----------------------------------------------------------------------
#
# https://openmp.llvm.org
# https://gcc.gnu.org/wiki/openmp
# https://trac.macports.org/wiki/XcodeVersionInfo
#----------------------------------------------------------------
#| OpenMP Version |  Clang  |  Xcode Clang  |  Xcode  |   GCC   |
#|---------------------------------------------------------------
#|      2.5       |   3.8   |    Future?    | Future? |   4.2   |
#|      3.0       |   3.8   |    Future?    | Future? |   4.4   |
#|      3.1       |   3.8   |    Future?    | Future? |   4.7   |
#|      4.0       | Partial |    Future?    | Future? |   4.9   |
#|      4.5       | Partial |    Future?    | Future? |   ???   |
#----------------------------------------------------------------
#
# https://trac.macports.org/wiki/CompilerEnvironmentVariables
# https://trac.macports.org/wiki/CompilerSelection#EnvironmentVariables
#--------------------------------------------------------------------
#|   Environment Variable   | Xcode Clang | Xcode GCC | Clang | GCC |
#|------------------------------------------------------------------|
#| CPATH                    |   318.0.4   |    all    |  all  | all |
#| LIBRARY_PATH             |  421.0.57   |    all    |  all  | all |
#| MACOSX_DEPLOYMENT_TARGET |     all     |    all    |  all  | all |
#| SDKROOT                  | OS X 10.9*  |   none    |  all  |  7  |
#| DEVELOPER_DIR            | OS X 10.9*  |    N/A    |  N/A  | N/A |
#| CC_PRINT_OPTIONS         |     all     |    all    |  all  | all |
#| CC_PRINT_OPTIONS_FILE    |     all     |    all    |  all  | all |
#--------------------------------------------------------------------
# * /usr/lib/libxcselect.dylib exists
#
# utility procedure: get minimum command line compilers version based on restrictions
proc portconfigure::get_min_command_line {compiler} {
    global compiler.thread_local_storage compiler.openmp_version \
           configure.cxx_stdlib os.major
    # thread-local storage only works on Mac OS X Lion and above
    # GCC & MacPorts Clang emulate thread-local storage
    if {(${compiler.thread_local_storage} && ${os.major} < 11)
        || ${compiler.openmp_version} ne {}
        || ${configure.cxx_stdlib} eq "macports-libstdc++"
    } {
        return none
    }

    global compiler.c_standard compiler.cxx_standard \
           compiler.limit_flags compiler.support_environment_sdkroot \
           configure.sdkroot
    set min_value 1.0
    switch ${compiler} {
        clang {
            if {${configure.cxx_stdlib} eq "libc++" && ${os.major} < 11} {
                # no Xcode clang can build against libc++ on < 10.7
                return none
            }
            if {(${compiler.limit_flags} || ${compiler.support_environment_sdkroot}) &&
                ${configure.sdkroot} ne "" &&
                !([file_exists /usr/lib/libxcselect.dylib] || ${os.major} >= 20)
            } {
                return none
            }
            if {${compiler.c_standard} >= 2017} {
                set min_value [max_version $min_value 1000.11.45.2]
            } elseif {${compiler.c_standard} >= 2011} {
                set min_value [max_version $min_value 500.2.75]
            }
            if {${compiler.cxx_standard} >= 2020} {
                set min_value [max_version $min_value 1500]
            } elseif {${compiler.cxx_standard} >= 2017} {
                set min_value [max_version $min_value 1000.11.45.2]
            } elseif {${compiler.cxx_standard} >= 2014} {
                set min_value [max_version $min_value 602.0.49]
            } elseif {${compiler.cxx_standard} >= 2011} {
                set min_value [max_version $min_value 500.2.75]
            }
            if {${compiler.cxx_standard} >= 2011 && ${compiler.thread_local_storage}} {
                # macOS has supported thread-local storage since Mac OS X Lion.
                # So __thread (GNU extension) and _Thread_local (C11) could be used.
                # However, the C++11 keyword was not supported until Xcode 8
                #    (https://developer.apple.com/library/archive/releasenotes/DeveloperTools/RN-Xcode/Chapters/Introduction.html#//apple_ref/doc/uid/TP40001051-CH1-SW127)
                #    (https://developer.apple.com/videos/play/wwdc2016-405/?time=354).
                set min_value [max_version $min_value 800.0.38]
            }
            global compiler.support_environment_paths
            if {${compiler.limit_flags} || ${compiler.support_environment_paths}} {
                set min_value [max_version $min_value 421.0.57]
            }
        }
        llvm-gcc-4.2 -
        gcc-4.2 -
        gcc-4.0 -
        apple-gcc-4.2 {
            if {${compiler.c_standard} > 1999 || ${compiler.cxx_standard} >= 2011 || ${configure.cxx_stdlib} eq "libc++" || ${compiler.thread_local_storage}} {
                return none
            }
            if {(${compiler.limit_flags} || ${compiler.support_environment_sdkroot}) && ${configure.sdkroot} ne ""} {
                return none
            }
        }
        default {
            return -code error "don't recognize compiler \"${compiler}\""
        }
    }

    return ${min_value}
}

# utility procedure: get minimum Clang version based on restrictions
proc portconfigure::get_min_clang {} {
    global compiler.c_standard compiler.cxx_standard compiler.openmp_version \
           compiler.thread_local_storage configure.cxx_stdlib
    set min_value 1.0
    if {${compiler.c_standard} >= 2017} {
        set min_value [max_version $min_value 6.0]
    } elseif {${compiler.c_standard} >= 2011} {
        set min_value [max_version $min_value 3.1]
    }
    if {${compiler.cxx_standard} >= 2020} {
        set min_value [max_version $min_value 16]
    } elseif {${compiler.cxx_standard} >= 2017} {
        set min_value [max_version $min_value 5.0]
    } elseif {${compiler.cxx_standard} >= 2014} {
        if {${configure.cxx_stdlib} eq "libc++"} {
            set min_value [max_version $min_value 3.4]
        } else {
            # macports-libstdc++ only macports-clang compilers >= 5.0 support this
            set min_value [max_version $min_value 5.0]
        }
    } elseif {${compiler.cxx_standard} >= 2011} {
        if {${configure.cxx_stdlib} eq "libc++"} {
            set min_value [max_version $min_value 3.3]
        } else {
            # macports-libstdc++ only macports-clang compilers >= 5.0 support this
            set min_value [max_version $min_value 5.0]
        }
    }
    if {[vercmp ${compiler.openmp_version} 4.0] >= 0} {
        set min_value [max_version $min_value 6.0]
    } elseif {[vercmp ${compiler.openmp_version} 2.5] >= 0} {
        set min_value [max_version $min_value 3.8]
    }
    if {${compiler.thread_local_storage}} {
        # MacPorts patches certain versions of Clang to emulate thread-local storage
        set min_value [max_version $min_value 5.0]
    }
    return ${min_value}
}

# utility procedure: get minimum GCC version based on restrictions
proc portconfigure::get_min_gcc {} {
    global configure.cxx_stdlib

    # Technically these only support macports-libstdc++, but if all the
    # options that use the system libstdc++ have been blacklisted, we
    # still need to use something. So only skip them entirely when
    # using libc++.
    if {${configure.cxx_stdlib} eq "libc++"} {
        return none
    }

    global compiler.c_standard compiler.cxx_standard compiler.openmp_version \
           compiler.thread_local_storage compiler.limit_flags \
           compiler.support_environment_sdkroot configure.sdkroot

    set min_value 1.0
    if {${compiler.c_standard} >= 2017} {
        set min_value [max_version $min_value 8]
    } elseif {${compiler.c_standard} >= 2011} {
        set min_value [max_version $min_value 4.3]
    } elseif {${compiler.c_standard} >= 1999} {
        set min_value [max_version $min_value 4.0]
    }
    if {${compiler.cxx_standard} >= 2020} {
        set min_value [max_version $min_value 12]
    } elseif {${compiler.cxx_standard} >= 2017} {
        set min_value [max_version $min_value 7]
    } elseif {${compiler.cxx_standard} >= 2014} {
        set min_value [max_version $min_value 5]
    } elseif {${compiler.cxx_standard} >= 2011} {
        set min_value [max_version $min_value 4.8]
    }
    if {[vercmp ${compiler.openmp_version} 4.5] >= 0} {
        set min_value [max_version $min_value 8]
    } elseif {[vercmp ${compiler.openmp_version} 4.0] >= 0} {
        set min_value [max_version $min_value 4.9]
    } elseif {[vercmp ${compiler.openmp_version} 3.1] >= 0} {
        set min_value [max_version $min_value 4.7]
    } elseif {[vercmp ${compiler.openmp_version} 3.0] >= 0} {
        set min_value [max_version $min_value 4.4]
    } elseif {[vercmp ${compiler.openmp_version} 2.5] >= 0} {
        set min_value [max_version $min_value 4.4]
    }
    if {${compiler.thread_local_storage}} {
        # GCC emulates thread-local storage, but it seems to be broken on older versions of GCC
        set min_value [max_version $min_value 4.5]
    }
    if {(${compiler.limit_flags} || ${compiler.support_environment_sdkroot})
        && ${configure.sdkroot} ne {}
    } {
        set min_value [max_version $min_value 7]
    }
    return ${min_value}
}

# utility procedure: get minimum Gfortran version based on restrictions
proc portconfigure::get_min_gfortran {} {
    global compiler.openmp_version compiler.thread_local_storage \
           compiler.limit_flags compiler.support_environment_sdkroot \
           configure.sdkroot
    set min_value 1.0
    if {[vercmp ${compiler.openmp_version} 4.5] >= 0} {
        set min_value [max_version $min_value 8]
    } elseif {[vercmp ${compiler.openmp_version} 4.0] >= 0} {
        set min_value [max_version $min_value 4.9]
    } elseif {[vercmp ${compiler.openmp_version} 3.1] >= 0} {
        set min_value [max_version $min_value 4.7]
    } elseif {[vercmp ${compiler.openmp_version} 2.5] >= 0} {
        set min_value [max_version $min_value 4.4]
    }
    if {${compiler.thread_local_storage}} {
        # GCC emulates thread-local storage, but it seems to be broken on older versions of GCC
        set min_value [max_version $min_value 4.5]
    }
    if {(${compiler.limit_flags} || ${compiler.support_environment_sdkroot})
        && ${configure.sdkroot} ne {}
    } {
        set min_value [max_version $min_value 7]
    }
    return ${min_value}
}

#
proc portconfigure::g95_ok {} {
    global os.platform xcodeversion
    if {${os.platform} eq "darwin" && ([vercmp $xcodeversion 9.0] > 0)} {
        # see https://github.com/macports/macports-ports/commit/6b905efc9d5586366ac498ed78d6ac51c120d33f
        return no
    }
    global compiler.openmp_version compiler.limit_flags \
           compiler.support_environment_sdkroot configure.sdkroot
    if {${compiler.openmp_version} ne ""} {
        # G95 does not support OpenMP
        return no
    }
    if {(${compiler.limit_flags} || ${compiler.support_environment_sdkroot})
        && ${configure.sdkroot} ne {}
    } {
        return no
    }
    return yes
}

# internal function to choose compiler fallback list based on platform
proc portconfigure::get_compiler_fallback {} {
    global default_compilers porturl xcodeversion os.platform \
           os.subplatform configure.build_arch compiler.cxx_standard \
           compiler.mpi
    # cxx_standard may be used in hint expressions

    # Check our override
    if {[info exists default_compilers]} {
        return $default_compilers
    }

    if {${os.subplatform} eq "macosx"} {
        # Check for macOS without Xcode (i.e. CLTs only)
        if {$xcodeversion in {none {}}} {
            set available_apple_compilers [get_apple_compilers_os_version]
        } else {
            global configure.sdkroot
            if {[vercmp ${xcodeversion} < 4.0] && [string match *10.4u* ${configure.sdkroot}]} {
                # from Xcode 3.2 release notes:
                #    GCC 4.2 cannot be used with the Mac OS X 10.4u SDK.
                #    If you want to build targets using the 10.4u SDK on Xcode 3.2, you must set the Compiler Version to GCC 4.0
                set available_apple_compilers [list gcc-4.0]
            } else {
                set available_apple_compilers [get_apple_compilers_xcode_version]
            }
        }
        global configure.developer_dir
        set system_compilers [list]
        foreach c ${available_apple_compilers} {
            set vmin [get_min_command_line $c]
            if {$vmin ne "none"} {
                if {$c eq "apple-gcc-4.2"} {
                    # provided by a port, should be the latest version
                    lappend system_compilers $c
                    continue
                }
                set v [get_system_compiler_version $c ${configure.developer_dir}]
                if {[vercmp $vmin <= $v]} {
                    lappend system_compilers $c
                }
            }
        }
    } else {
        # not macosx
        set system_compilers [list cc]
    }

    set cur_arch ${configure.build_arch}
    if {$cur_arch eq ""} {
        global build_arch
        set cur_arch ${build_arch}
    }
    set clang_compilers [list]
    # Clang can't target PowerPC architectures on Darwin
    if {$cur_arch ni {ppc ppc64} || ${os.platform} ne "darwin"} {
        set vmin [get_min_clang]
        foreach c [get_clang_compilers $porturl] {
            set excluded 0
            foreach hint [lrange $c 1 end] {
                if {$hint ne {} && ![expr $hint]} {
                    set excluded 1
                    break
                }
            }
            if {!$excluded} {
                set cname [lindex $c 0]
                set v [lindex [split $cname -] 2]
                if {[vercmp $vmin <= $v]} {
                    lappend clang_compilers $cname
                }
            }
        }
    }

    set gcc_compilers [list]
    set vmin [get_min_gcc]
    if {$vmin ne "none"} {
        foreach c [get_gcc_compilers $porturl] {
            set excluded 0
            foreach hint [lrange $c 1 end] {
                if {$hint ne {} && ![expr $hint]} {
                    set excluded 1
                    break
                }
            }
            if {!$excluded} {
                set cname [lindex $c 0]
                set v [lindex [split $cname -] 2]
                if {[vercmp $vmin <= $v]} {
                    lappend gcc_compilers $c
                }
            }
        }
    }

    set compilers [list {*}$system_compilers {*}$clang_compilers {*}$gcc_compilers]

    if {${compiler.mpi} eq ""} {
        return $compilers
    } else {
        # generate list of MPI wrappers of current compilers
        set mpi_compilers [list]
        foreach mpi ${compiler.mpi} {
            foreach c ${compilers} {
                lappend mpi_compilers [get_mpi_wrapper $mpi $c]
            }
        }
        return $mpi_compilers
    }
}
#
proc portconfigure::get_fortran_fallback {} {
    set compilers [list]
    set vmin [get_min_gfortran]
    foreach c [get_gcc_compilers] {
        set v    [lindex [split $c -] 2]
        if {[vercmp ${vmin} $v] <= 0} {
            lappend compilers $c
        }
    }
    if {[g95_ok]} {
        lappend compilers macports-g95
    }
    global compiler.mpi
    # generate list of MPI wrappers of current compilers
    if {${compiler.mpi} eq ""} {
        return $compilers
    } else {
        set mpi_compilers [list]
        foreach mpi ${compiler.mpi} {
            foreach c ${compilers} {
                lappend mpi_compilers [get_mpi_wrapper $mpi $c]
            }
        }
        return $mpi_compilers
    }
}

# Internal function to find location of compiler executable for a given
# compiler type and compiler suite name.
proc portconfigure::configure_get_compiler {type {compiler {}}} {
    global configure.compiler compiler.require_fortran
    if {$compiler eq {}} {
        if {${compiler.require_fortran} && $type in {fc f77 f90}} {
            set compiler [configure_get_fortran_compiler]
        } else {
            set compiler ${configure.compiler}
        }
    }
    _configure_get_compiler $type $compiler
}

# Automatically called from macports1.0 after evaluating the Portfile
# Some of the compilers we use are provided by MacPorts itself; ensure we
# automatically add a dependency when needed
proc portconfigure::add_automatic_compiler_dependencies {} {
    global configure.compiler configure.compiler.add_deps compiler.require_fortran

    if {!${configure.compiler.add_deps}} {
        return
    }

    if {[compiler_is_port ${configure.compiler}]} {
        ui_debug "Chosen compiler ${configure.compiler} is provided by a port, adding dependency"
        add_compiler_port_dependencies ${configure.compiler}
    }

    if {${compiler.require_fortran} && [configure_get_compiler fc ${configure.compiler}] eq ""} {
        # Fortran is required, but compiler does not provide it
        ui_debug "Adding Fortran compiler dependency"
        add_compiler_port_dependencies [configure_get_fortran_compiler]
    }
}
# Register the above procedure as a callback after Portfile evaluation
port::register_callback portconfigure::add_automatic_compiler_dependencies
# and an option to turn it off if required
options configure.compiler.add_deps
default configure.compiler.add_deps yes
# helper function to add dependencies for a given compiler
proc portconfigure::add_compiler_port_dependencies {compiler} {
    global os.major porturl

    set compiler_port [compiler_port_name ${compiler}]
    if {$compiler eq "apple-gcc-4.0"} {
        # compiler links against ${prefix}/lib/apple-gcc40/lib/libgcc_s.1.dylib
        ui_debug "Adding depends_lib port:$compiler_port"
        depends_lib-delete port:$compiler_port
        depends_lib-append port:$compiler_port
    } elseif {[regexp {^macports-(mpich|openmpi)-(default|clang|gcc)(?:-(\d+(?:\.\d+)?))?$} $compiler -> mpi clang_or_gcc version]} {
        # MPI compilers link against MPI libraries
        ui_debug "Adding depends_lib port:$compiler_port"
        if {${mpi} eq "openmpi"} {
            set pkgname ompi.pc
        } else {
            set pkgname ${mpi}.pc
        }
        depends_lib-delete "path:lib/$compiler_port/pgkconfig/${pkgname}:${compiler_port}"
        depends_lib-append "path:lib/$compiler_port/pkgconfig/${pkgname}:${compiler_port}"
    } else {
        ui_debug "Adding depends_build port:$compiler_port"
        depends_build-delete port:$compiler_port
        depends_build-append port:$compiler_port
        license_noconflict-append $compiler_port

        # add C++ runtime dependency if necessary
        if {[regexp {^macports-gcc-(\d+(?:\.\d+)?)?$} ${compiler} -> gcc_version]} {
            set libgccs [get_gcc_dependencies $porturl $gcc_version]
            foreach libgcc_dep $libgccs {
                ui_debug "Adding depends_lib $libgcc_dep"
                depends_lib-delete $libgcc_dep
                depends_lib-append $libgcc_dep
            }
        } elseif {[regexp {^macports-clang(?:-(\d+(?:\.\d+)?))$} $compiler -> clang_version]} {
            global configure.cxx_stdlib compiler.openmp_version
            if {${configure.cxx_stdlib} eq "macports-libstdc++"} {
                # see https://trac.macports.org/ticket/54766
                ui_debug "Adding depends_lib path:lib/libgcc/libgcc_s.1.dylib:libgcc"
                depends_lib-delete "path:lib/libgcc/libgcc_s.1.dylib:libgcc"
                depends_lib-append "path:lib/libgcc/libgcc_s.1.dylib:libgcc"
            } elseif {${configure.cxx_stdlib} eq "libc++" && ${os.major} < 11} {
                # libc++ does not exist on these systems
                ui_debug "Adding depends_lib libcxx"
                depends_lib-delete "port:libcxx"
                depends_lib-append "port:libcxx"
            }
            if {${compiler.openmp_version} ne ""} {
                ui_debug "Adding depends_lib port:libomp"
                depends_lib-delete "port:libomp"
                depends_lib-append "port:libomp"
            }
        }
    }

    if {[arch_flag_supported $compiler]} {
        ui_debug "Adding depends_skip_archcheck $compiler_port"
        depends_skip_archcheck-delete $compiler_port
        depends_skip_archcheck-append $compiler_port
    }
}

options configure.checks.implicit_int \
        configure.checks.incompatible_function_pointer_types \
        configure.checks.implicit_function_declaration \
        configure.checks.implicit_function_declaration.whitelist

default configure.checks.implicit_int yes
default configure.checks.incompatible_function_pointer_types yes
default configure.checks.implicit_function_declaration yes
default configure.checks.implicit_function_declaration.whitelist {[portconfigure::get_implicit_function_declaration_whitelist ${configure.sdk_version}]}
