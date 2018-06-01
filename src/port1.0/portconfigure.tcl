# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2007 - 2015 The MacPorts Project
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
#

package provide portconfigure 1.0
package require portutil 1.0

set org.macports.configure [target_new org.macports.configure portconfigure::configure_main]
target_provides ${org.macports.configure} configure
target_requires ${org.macports.configure} main fetch checksum extract patch
target_prerun ${org.macports.configure} portconfigure::configure_start

namespace eval portconfigure {
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
default configure.universal_cxxflags    {[portconfigure::configure_get_universal_cflags]}
default configure.universal_objcxxflags {${configure.universal_cxxflags}}

# Don't let Portfiles trash "-stdlib"; if they want to remove it, they
# should clear configure.cxx_stdlib.
option_proc configure.cxxflags portconfigure::stdlib_trace
option_proc configure.objcxxflags portconfigure::stdlib_trace

proc portconfigure::should_add_stdlib {} {
    set has_stdlib [expr {[option configure.cxx_stdlib] ne ""}]
    set is_clang [string match *clang* [option configure.cxx]]
    return [expr {$has_stdlib && $is_clang}]
}
proc portconfigure::should_add_cxx_abi {} {
    set is_oldos [expr {[option os.platform] eq "darwin" && [option os.major] < 10}]
    set is_mp_gcc [string match *g++-mp-* [option configure.cxx]]
    return [expr {$is_oldos && $is_mp_gcc}]
}
proc portconfigure::construct_cxxflags {flags} {
    if {[portconfigure::should_add_stdlib]} {
        lappend flags -stdlib=[option configure.cxx_stdlib]
    } elseif {[portconfigure::should_add_cxx_abi]} {
        lappend flags -D_GLIBCXX_USE_CXX11_ABI=0
    }
    return $flags
}
proc portconfigure::stdlib_trace {opt action args} {
    foreach flag [lsearch -all -inline [option $opt] -stdlib=*] {
        $opt-delete $flag
    }
    if {$action eq "read" && [portconfigure::should_add_stdlib]} {
        $opt-append -stdlib=[option configure.cxx_stdlib]
    }
    return
}
proc portconfigure::configure_get_cxx_stdlib {} {
    global cxx_stdlib configure.cxx
    if {![string match *g++-mp-* ${configure.cxx}]} {
        return $cxx_stdlib
    } else {
        return macports-libstdc++
    }
}

# ********** END C++ / OBJECTIVE-C++ **********


# define options
commands configure autoreconf automake autoconf xmkmf
# defaults
default configure.env       ""
default configure.pre_args  {--prefix=${prefix}}
default configure.cmd       ./configure
default configure.nice      {${buildnicevalue}}
default configure.dir       {${worksrcpath}}
default autoreconf.dir      {${worksrcpath}}
default autoreconf.args     {{--install --verbose}}
default autoconf.dir        {${worksrcpath}}
default autoconf.args       {--verbose}
default automake.dir        {${worksrcpath}}
default automake.args       {--verbose}
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
    global ${type}.cmd option_defaults

    if {![info exists ${type}.cmd] || (
        ([info exists option_defaults(${type}.cmd)] && [set ${type}.cmd] eq $option_defaults(${type}.cmd)) ||
        (![info exists option_defaults(${type}.cmd)] && [set ${type}.cmd] eq ${type})
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
    global autoreconf.cmd automake.cmd autoconf.cmd xmkmf.cmd

    array set configure_map {
        autoconf    {port:autoconf port:automake port:libtool}
        xmkmf       port:imake
    }

    if {$action eq "set"} {
        switch $option {
            autoreconf.cmd  -
            automake.cmd    -
            autoconf.cmd {
                depends_build-delete {*}$configure_map(autoconf)
            }
            xmkmf.cmd {
                depends_build-delete {*}$configure_map(xmkmf)
            }
            use_xmkmf {
                if {[tbool args]} {
                    depends_build-append {*}$configure_map(xmkmf)
                }
            }
            default {
                # strip "use_"
                set type [string range $option 4 end]
                if {[tbool args]} {
                    add_build_dep $type $configure_map(autoconf)
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
default configure.optflags      {-Os}
default configure.cflags        {${configure.optflags}}
default configure.objcflags     {${configure.optflags}}
default configure.cppflags      {-I${prefix}/include}
default configure.ldflags       {"-L${prefix}/lib -Wl,-headerpad_max_install_names"}
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
default configure.install           {${portutil::autoconf::install_command}}
default configure.awk               {}
default configure.bison             {}
default configure.pkg_config        {}
default configure.pkg_config_path   {}

options configure.build_arch configure.ld_archflags \
        configure.sdk_version configure.sdkroot
default configure.build_arch    {[portconfigure::choose_supported_archs ${build_arch}]}
default configure.ld_archflags  {[portconfigure::configure_get_ld_archflags]}
default configure.sdk_version   {$macosx_sdk_version}
default configure.sdkroot       {[portconfigure::configure_get_sdkroot ${configure.sdk_version}]}
foreach tool {cc objc f77 f90 fc} {
    options configure.${tool}_archflags
    default configure.${tool}_archflags  "\[portconfigure::configure_get_archflags $tool\]"
}

options configure.universal_archs configure.universal_args \
        configure.universal_cflags \
        configure.universal_objcflags \
        configure.universal_cppflags configure.universal_ldflags
default configure.universal_archs       {[portconfigure::choose_supported_archs ${universal_archs}]}
default configure.universal_args        {--disable-dependency-tracking}
default configure.universal_cflags      {[portconfigure::configure_get_universal_cflags]}
default configure.universal_objcflags   {${configure.universal_cflags}}
default configure.universal_cppflags    {}
default configure.universal_ldflags     {[portconfigure::configure_get_universal_ldflags]}

# Select a distinct compiler (C, C preprocessor, C++)
options configure.ccache configure.distcc configure.pipe configure.cc \
        configure.cpp configure.objc configure.f77 \
        configure.f90 configure.fc configure.javac configure.compiler \
        compiler.blacklist compiler.whitelist compiler.fallback
default configure.ccache        {${configureccache}}
default configure.distcc        {${configuredistcc}}
default configure.pipe          {${configurepipe}}
foreach tool {cc objc cpp f77 f90 fc javac} {
    default configure.$tool     "\[portconfigure::configure_get_compiler $tool\]"
}
default configure.compiler      {[portconfigure::configure_get_default_compiler]}
default compiler.fallback       {[portconfigure::get_compiler_fallback]}
default compiler.blacklist      {}
default compiler.whitelist      {}

set_ui_prefix

proc portconfigure::configure_start {args} {
    global UI_PREFIX

    ui_notice "$UI_PREFIX [format [msgcat::mc "Configuring %s"] [option subport]]"

    set compiler [option configure.compiler]
    set valid_compilers {
        {^apple-gcc-(4\.[02])$}             {MacPorts Apple GCC %s}
        {^cc$}                              {System cc}
        {^clang$}                           {Xcode Clang}
        {^gcc$}                             {System GCC}
        {^gcc-(3\.3|4\.[02])$}              {Xcode GCC %s}
        {^llvm-gcc-4\.2$}                   {Xcode LLVM-GCC 4.2}
        {^macports-clang$}                  {MacPorts Clang (port select)}
        {^macports-clang-(\d+\.\d+)$}       {MacPorts Clang %s}
        {^macports-dragonegg-(\d+\.\d+)$}   {MacPorts DragonEgg %s}
        {^macports-dragonegg-(\d+\.\d+)-gcc-(\d+\.\d+)$}
            {MacPorts DragonEgg %s with GCC %s}
        {^macports-gcc$}                    {MacPorts GCC (port select)}
        {^macports-gcc-(\d+(?:\.\d+)?)$}    {MacPorts GCC %s}
        {^macports-llvm-gcc-4\.2$}          {MacPorts LLVM-GCC 4.2}
    }
    foreach {re fmt} $valid_compilers {
        if {[set matches [regexp -inline $re $compiler]] ne ""} {
            set compiler_name [format $fmt {*}[lrange $matches 1 end]]
            break
        }
    }
    if {![info exists compiler_name]} {
        return -code error "Invalid value for configure.compiler: $compiler"
    }
    ui_debug "Preferred compilers: [option compiler.fallback]"
    ui_debug "Using compiler '$compiler_name'"

    # Additional ccache directory setup
    global configure.ccache ccache_dir ccache_size macportsuser
    if {${configure.ccache}} {
        # Create ccache directory with correct permissions with root privileges
        elevateToRoot "configure ccache"
        if {[catch {
                file mkdir ${ccache_dir}
                file attributes ${ccache_dir} -owner ${macportsuser} -permissions 0755
            } result]} {
            ui_warn "ccache_dir ${ccache_dir} could not be created; disabling ccache: $result"
            set configure.ccache no
        }
        dropPrivileges

        # Initialize ccache directory with the given maximum size
        if {${configure.ccache}} {
            if {[catch {
                exec ccache -M ${ccache_size} >/dev/null
            } result]} {
                ui_warn "ccache_dir ${ccache_dir} could not be initialized; disabling ccache: $result"
                set configure.ccache no
            }
        }
    }
}

# internal function to choose the default configure.build_arch and
# configure.universal_archs based on supported_archs and build_arch or
# universal_archs
proc portconfigure::choose_supported_archs {archs} {
    global supported_archs
    if {$supported_archs eq ""} {
        return $archs
    }
    set ret {}
    foreach arch $archs {
        if {$arch in $supported_archs} {
            set add_arch $arch
        } elseif {$arch eq "x86_64" && "i386" in $supported_archs} {
            set add_arch "i386"
        } elseif {$arch eq "ppc64" && "ppc" in $supported_archs} {
            set add_arch "ppc"
        } else {
            continue
        }
        if {$add_arch ni $ret} {
            lappend ret $add_arch
        }
    }
    return $ret
}

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
            [regexp {^(?:cc|cxx|objc|objcxx)$} $tool]
        } then {
            set flags "-arch ${configure.build_arch}"
        } elseif {${configure.build_arch} eq "x86_64" || ${configure.build_arch} eq "ppc64"} {
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
    global developer_dir macosx_version xcodeversion os.arch os.platform

    # This is only relevant for macOS
    if {${os.platform} ne "darwin"} {
        return {}
    }

    # Special hack for Tiger/ppc, since the system libraries do not contain intel slices
    if {${os.arch} eq "powerpc" && $macosx_version eq "10.4" && [variant_exists universal] && [variant_isset universal]} {
        return ${developer_dir}/SDKs/MacOSX10.4u.sdk
    }

    # Use the DevSDK (eg: /usr/include) if present and the requested SDK version matches the host version
    if {$sdk_version eq $macosx_version && [file exists /usr/include]} {
        return {}
    }

    if {[vercmp $xcodeversion 4.3] < 0} {
        set sdks_dir ${developer_dir}/SDKs
    } else {
        set sdks_dir ${developer_dir}/Platforms/MacOSX.platform/Developer/SDKs
    }

    if {$sdk_version eq "10.4"} {
        set sdk ${sdks_dir}/MacOSX10.4u.sdk
    } else {
        set sdk ${sdks_dir}/MacOSX${sdk_version}.sdk
    }

    if {[file exists $sdk]} {
        return $sdk
    }

    if {![catch {set sdk [exec xcrun --sdk macosx${sdk_version} --show-sdk-path 2> /dev/null]}]} {
        return $sdk
    }

    set sdk /Library/Developer/CommandLineTools/SDKs/MacOSX${sdk_version}.sdk
    if {[file exists $sdk]} {
        return $sdk
    }

    # TODO: Support falling back to "macosx" if it is present?
    #       This leads to problems when it is newer than the base OS because many OSS assume that
    #       the SDK version matches the deployment target, so they unconditionally try to use
    #       symbols that are only available on newer OS versions..
    #if {![catch {set sdk [exec xcrun --sdk macosx --show-sdk-path 2> /dev/null]}]} {
    #    ui_warn "Unable to determine location of the macOS ${sdk_version} SDK.  Using the default macOS SDK."
    #    return $sdk
    #}

    ui_error "Unable to determine location of a macOS SDK."
    return -code error "Unable to determine location of a macOS SDK."
}

# internal function to determine the "-arch xy" flags for the compiler
proc portconfigure::configure_get_universal_archflags {} {
    global configure.universal_archs
    set flags ""
    foreach arch ${configure.universal_archs} {
        if {$flags eq ""} {
            set flags "-arch $arch"
        } else {
            append flags " -arch $arch"
        }
    }
    return $flags
}

# internal function to determine the CFLAGS for the compiler
proc portconfigure::configure_get_universal_cflags {} {
    return [configure_get_universal_archflags]
}

# internal function to determine the LDFLAGS for the compiler
proc portconfigure::configure_get_universal_ldflags {} {
    return [configure_get_universal_archflags]
}

# internal proc to determine if the compiler supports -arch
proc portconfigure::arch_flag_supported {compiler} {
    return [regexp {^gcc-4|llvm|apple|clang} $compiler]
}

proc portconfigure::compiler_port_name {compiler} {
    set valid_compiler_ports {
        {^apple-gcc-(\d+)\.(\d+)$}                          {apple-gcc%s%s}
        {^macports-clang-(\d+\.\d+)$}                       {clang-%s}
        {^macports-dragonegg-(\d+\.\d+)(-gcc-\d+\.\d+)?$}   {dragonegg-%s%s}
        {^macports-(llvm-)?gcc-(\d+)(?:\.(\d+))?$}          {%sgcc%s%s}
    }
    foreach {re fmt} $valid_compiler_ports {
        if {[set matches [regexp -inline $re $compiler]] ne ""} {
            return [format $fmt {*}[lrange $matches 1 end]]
        }
    }
    return {}
}

proc portconfigure::compiler_is_port {compiler} {
    return [expr {[portconfigure::compiler_port_name ${compiler}] ne ""}]
}

# internal function to determine the default compiler
proc portconfigure::configure_get_default_compiler {} {
    if {[option compiler.whitelist] ne ""} {
        set search_list [option compiler.whitelist]
    } else {
        set search_list [option compiler.fallback]
    }
    foreach compiler $search_list {
        set allowed yes
        foreach pattern [option compiler.blacklist] {
            if {[string match $pattern $compiler]} {
                set allowed no
                break
            }
        }
        if {$allowed &&
            ([file executable [configure_get_compiler cc $compiler]] ||
             [compiler_is_port $compiler])
        } then {
            return $compiler
        }
    }
    ui_warn "All compilers are either blacklisted or unavailable; defaulting to first fallback option"
    return [lindex [option compiler.fallback] 0]
}

# internal function to choose compiler fallback list based on platform
proc portconfigure::get_compiler_fallback {} {
    global xcodeversion macosx_deployment_target default_compilers configure.sdkroot configure.cxx_stdlib os.major

    # Check our override
    if {[info exists default_compilers]} {
        return $default_compilers
    }

    # Check for platforms without Xcode
    if {$xcodeversion eq "none" || $xcodeversion eq ""} {
        return {cc}
    }

    # Legacy cases
    if {[vercmp $xcodeversion 4.0] < 0} {
        set canonical_archs [get_canonical_archs]
        if {[vercmp $xcodeversion 3.2] >= 0} {
            if {[string match *10.4u* ${configure.sdkroot}]} {
                return {gcc-4.0}
            }
            # No return here. 3.2.x with newer SDKs than 10.4u is handled below.
        } elseif {[vercmp $xcodeversion 3.0] >= 0} {
            if {"ppc" in $canonical_archs || "ppc64" in $canonical_archs} {
                return {gcc-4.2 apple-gcc-4.2 gcc-4.0 macports-gcc-6 macports-gcc-7}
            } else {
                return {gcc-4.2 apple-gcc-4.2 gcc-4.0 macports-clang-3.4 macports-clang-3.3}
            }
        } else {
            # Xcode 2.x (Tiger)
            if {"ppc" in $canonical_archs || "ppc64" in $canonical_archs} {
                if {"i386" in $canonical_archs} {
                    # universal
                    return {apple-gcc-4.2 gcc-4.0 macports-gcc-6 macports-gcc-7}
                } else {
                    # ppc only
                    return {apple-gcc-4.2 gcc-4.0 gcc-3.3 macports-gcc-6 macports-gcc-7}
                }
            } else {
                # i386 only
                return {apple-gcc-4.2 gcc-4.0 macports-clang-3.3}
            }
        }
    }

    set compilers {}

    # Set our preferred Xcode-provided compilers
    if {[vercmp $xcodeversion 5.0] >= 0} {
        lappend compilers clang
    } elseif {[vercmp $xcodeversion 4.3] >= 0} {
        lappend compilers clang llvm-gcc-4.2
    } elseif {[vercmp $xcodeversion 4.0] >= 0} {
        lappend compilers llvm-gcc-4.2 clang
    } else {
        # 3.2.x
        lappend compilers gcc-4.2 clang llvm-gcc-4.2
    }

    # Determine which versions of clang we prefer
    if {${configure.cxx_stdlib} eq "libc++"} {
        # clang-3.5+ require libc++
        lappend compilers macports-clang-5.0 macports-clang-4.0

        if {${os.major} < 17} {
            # The High Sierra SDK requires a toolchain that can apply nullability to uuid_t
            lappend compilers macports-clang-3.9
        }

        if {${os.major} < 16} {
            # The Sierra SDK requires a toolchain that supports class properties
            lappend compilers macports-clang-3.7
        }
    }

    if {${os.major} < 16} {
        # We dropped support for these compilers on Sierra
        lappend compilers macports-clang-3.4 macports-llvm-gcc-4.2 apple-gcc-4.2
    }

    return $compilers
}

# Find a developer tool
proc portconfigure::find_developer_tool {name} {
	global developer_dir

    # first try /usr/bin since this doesn't move around
    set toolpath "/usr/bin/${name}"
    if {[file executable $toolpath]} {
        return $toolpath
    }

	# Use xcode's xcrun to find the named tool.
	if {![catch {exec [findBinary xcrun $portutil::autoconf::xcrun_path] -find ${name}} toolpath]} {
		return ${toolpath}
	}

	# If xcrun failed to find the tool, return a path from
	# the developer_dir.
	# The tool may not be there, but we'll leave it up to
	# the invoking code to figure out that it doesn't have
	# a valid compiler
	return "${developer_dir}/usr/bin/${name}"
}


# internal function to find correct compilers
proc portconfigure::configure_get_compiler {type {compiler {}}} {
    global configure.compiler prefix
    if {$compiler eq ""} {
        set compiler ${configure.compiler}
    }
    # Tcl 8.4's switch doesn't support -matchvar.
    if {[regexp {^apple-gcc(-4\.[02])$} $compiler -> suffix]} {
        switch $type {
            cc      -
            objc    { return ${prefix}/bin/gcc-apple${suffix} }
            cxx     -
            objcxx  {
                if {$suffix eq "-4.2"} {
                    return ${prefix}/bin/g++-apple${suffix}
                }
            }
            cpp     { return ${prefix}/bin/cpp-apple${suffix} }
        }
    } elseif {[regexp {^clang$} $compiler]} {
        switch $type {
            cc      -
            objc    { return [find_developer_tool clang] }
            cxx     -
            objcxx  {
                set clangpp [find_developer_tool clang++]
                if {[file executable $clangpp]} {
                    return $clangpp
                }
                return [find_developer_tool llvm-g++-4.2]
            }
        }
    } elseif {[regexp {^gcc(-3\.3|-4\.[02])?$} $compiler -> suffix]} {
        switch $type {
            cc      -
            objc    { return [find_developer_tool "gcc${suffix}"] }
            cxx     -
            objcxx  { return [find_developer_tool "g++${suffix}"] }
            cpp     { return [find_developer_tool "cpp${suffix}"] }
        }
    } elseif {[regexp {^llvm-gcc-4\.2$} $compiler]} {
        switch $type {
            cc      -
            objc    { return [find_developer_tool llvm-gcc-4.2] }
            cxx     -
            objcxx  { return [find_developer_tool llvm-g++-4.2] }
            cpp     { return [find_developer_tool llvm-cpp-4.2] }
        }
    } elseif {[regexp {^macports-clang(-\d+\.\d+)?$} $compiler -> suffix]} {
        if {$suffix ne ""} {
            set suffix "-mp${suffix}"
        }
        switch $type {
            cc      -
            objc    { return ${prefix}/bin/clang${suffix} }
            cxx     -
            objcxx  { return ${prefix}/bin/clang++${suffix} }
        }
    } elseif {[regexp {^macports-dragonegg(-\d+\.\d+)(?:-gcc(-\d+\.\d+))?$} $compiler \
                -> infix suffix]} {
        if {$suffix ne ""} {
            set suffix "-mp${suffix}"
        }
        switch $type {
            cc      -
            objc    { return ${prefix}/bin/dragonegg${infix}-gcc${suffix} }
            cxx     -
            objcxx  { return ${prefix}/bin/dragonegg${infix}-g++${suffix} }
            cpp     { return ${prefix}/bin/dragonegg${infix}-cpp${suffix} }
            fc      -
            f77     -
            f90     { return ${prefix}/bin/dragonegg${infix}-gfortran${suffix} }
        }
    } elseif {[regexp {^macports-gcc(-\d+(?:\.\d+)?)?$} $compiler -> suffix]} {
        if {$suffix ne ""} {
            set suffix "-mp${suffix}"
        }
        switch $type {
            cc      -
            objc    { return ${prefix}/bin/gcc${suffix} }
            cxx     -
            objcxx  { return ${prefix}/bin/g++${suffix} }
            cpp     { return ${prefix}/bin/cpp${suffix} }
            fc      -
            f77     -
            f90     { return ${prefix}/bin/gfortran${suffix} }
        }
    } elseif {[regexp {^macports-llvm-gcc-4\.2$} $compiler]} {
        switch $type {
            cc      -
            objc    { return ${prefix}/bin/llvm-gcc-4.2 }
            cxx     -
            objcxx  { return ${prefix}/bin/llvm-g++-4.2 }
            cpp     { return ${prefix}/bin/llvm-cpp-4.2 }
        }
    }
    # Fallbacks
    switch $type {
        cc      -
        objc    { return [find_developer_tool cc] }
        cxx     -
        objcxx  { return [find_developer_tool c++] }
        cpp     { return [find_developer_tool cpp] }
    }
    return ""
}

# Automatically called from macports1.0 after evaluating the Portfile
# Some of the compilers we use are provided by MacPorts itself; ensure we
# automatically add a dependency when needed
proc portconfigure::add_automatic_compiler_dependencies {} {
    global configure.compiler configure.compiler.add_deps

    if {!${configure.compiler.add_deps}} {
        return
    }

    # The default value requires substitution before use.
    set compiler [subst ${configure.compiler}]
    if {![compiler_is_port $compiler]} {
        return
    }

    ui_debug "Chosen compiler ${compiler} is provided by a port, adding dependency"

    set compiler_port [portconfigure::compiler_port_name ${compiler}]
    set deptype "build"
    if {[string first "macports-gcc-" $compiler] == 0} {
        set deptype "lib"
    }
    ui_debug "Adding depends_${deptype} port:$compiler_port"
    depends_${deptype}-delete port:$compiler_port
    depends_${deptype}-append port:$compiler_port

    if {[arch_flag_supported $compiler]} {
        ui_debug "Adding depends_skip_archcheck $compiler_port"
        depends_skip_archcheck-delete $compiler_port
        depends_skip_archcheck-append $compiler_port
    }
}
# Register the above procedure as a callback after Portfile evaluation
port::register_callback portconfigure::add_automatic_compiler_dependencies
# and an option to turn it off if required
options configure.compiler.add_deps
default configure.compiler.add_deps yes

proc portconfigure::configure_main {args} {
    global [info globals]
    global worksrcpath use_configure use_autoreconf use_autoconf use_automake use_xmkmf \
           configure.env configure.pipe configure.libs configure.classpath configure.universal_args \
           configure.perl configure.python configure.ruby configure.install configure.awk configure.bison \
           configure.pkg_config configure.pkg_config_path \
           configure.ccache configure.distcc configure.cpp configure.javac configure.sdkroot \
           configure.march configure.mtune configure.cxx_stdlib \
           os.platform os.major
    foreach tool {cc cxx objc objcxx f77 f90 fc ld} {
        global configure.${tool} configure.${tool}_archflags
    }
    foreach flags {cflags cppflags cxxflags objcflags objcxxflags ldflags fflags f90flags fcflags} {
        global configure.${flags} configure.universal_${flags}
    }
    
    if {[tbool use_autoreconf]} {
        if {[catch {command_exec autoreconf} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] autoreconf $result]"
        }
    }
    
    if {[tbool use_automake]} {
        if {[catch {command_exec automake} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] automake $result]"
        }
    }
    
    if {[tbool use_autoconf]} {
        if {[catch {command_exec autoconf} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] autoconf $result]"
        }
    }

    if {[tbool use_xmkmf]} {
        parse_environment xmkmf
        if {[catch {command_exec xmkmf} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] xmkmf $result]"
        }

        parse_environment xmkmf
        if {[catch {command_exec "cd ${worksrcpath} && make Makefiles" -varprefix xmkmf} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] "make Makefiles" $result]"
        }
    } elseif {[tbool use_configure]} {
        # Merge (ld|c|cpp|cxx)flags into the environment variable.
        parse_environment configure

        # Set pre-compiler filter to use (ccache/distcc), if any.
        if {[tbool configure.ccache] && [tbool configure.distcc]} {
            set filter ccache
            append_to_environment_value configure "CCACHE_PREFIX" "distcc"
        } elseif {[tbool configure.ccache]} {
            set filter ccache
        } elseif {[tbool configure.distcc]} {
            set filter distcc
        } else {
            set filter ""
        }
        foreach env_var {CC CXX OBJC OBJCXX} {
            append_to_environment_value configure $env_var $filter
        }

        # Set flags controlling the kind of compiler output.
        if {[tbool configure.pipe]} {
            set output -pipe
        } else {
            set output ""
        }
        foreach env_var {CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS FFLAGS F90FLAGS FCFLAGS} {
            append_to_environment_value configure $env_var $output
        }

        # Append configure flags.
        foreach env_var { \
            CC CXX OBJC OBJCXX FC F77 F90 JAVAC \
            CFLAGS CPPFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS \
            FFLAGS F90FLAGS FCFLAGS LDFLAGS LIBS CLASSPATH \
            PERL PYTHON RUBY INSTALL AWK BISON PKG_CONFIG \
        } {
            set value [option configure.[string tolower $env_var]]
            append_to_environment_value configure $env_var {*}$value
        }

        foreach env_var { \
            PKG_CONFIG_PATH \
        } {
            set value [option configure.[string tolower $env_var]]
            append_to_environment_value configure $env_var [join $value ":"]
        }

        # https://trac.macports.org/ticket/34221
        if {${os.platform} eq "darwin" && ${os.major} == 12} {
            append_to_environment_value configure "__CFPREFERENCES_AVOID_DAEMON" 1
        }

        # add SDK flags if cross-compiling (or universal on ppc tiger)
        if {${configure.sdkroot} ne ""} {
            foreach env_var {CPPFLAGS CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS} {
                append_to_environment_value configure $env_var -isysroot${configure.sdkroot}
            }
            append_to_environment_value configure "LDFLAGS" -Wl,-syslibroot,${configure.sdkroot}
        }

        # add extra flags that are conditional on whether we're building universal
        append_to_environment_value configure CFLAGS {*}[get_canonical_archflags cc]
        foreach tool {cxx objc objcxx cpp f77 f90 fc ld} {
            if {[catch {get_canonical_archflags $tool} flags]} {
                continue
            }
            set env_var [string toupper $tool]FLAGS
            append_to_environment_value configure $env_var {*}$flags
        }
        if {[variant_exists universal] && [variant_isset universal]} {
            configure.pre_args-append {*}${configure.universal_args}
        } else {
            foreach env_var {CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS FFLAGS F90FLAGS FCFLAGS LDFLAGS} {
                if {${configure.march} ne ""} {
                    append_to_environment_value configure $env_var -march=${configure.march}
                }
                if {${configure.mtune} ne ""} {
                    append_to_environment_value configure $env_var -mtune=${configure.mtune}
                }
            }
        }

        # Execute the command (with the new environment).
        if {[catch {command_exec configure} result]} {
            global configure.dir
            if {[file exists ${configure.dir}/config.log]} {
                ui_error "[format [msgcat::mc "Failed to configure %s, consult %s/config.log"] [option subport] ${configure.dir}]"
            }
            return -code error "[format [msgcat::mc "%s failure: %s"] configure $result]"
        }
    }
    return 0
}
