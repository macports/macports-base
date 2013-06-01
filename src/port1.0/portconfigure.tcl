# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# $Id$
#
# Copyright (c) 2007 - 2013 The MacPorts Project
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

# define options
commands configure autoreconf automake autoconf xmkmf
# defaults
default configure.env       ""
default configure.pre_args  {--prefix=${prefix}}
default configure.cmd       ./configure
default configure.nice      {${buildnicevalue}}
default configure.dir       {${worksrcpath}}
default autoreconf.dir      {${worksrcpath}}
default autoreconf.pre_args {--install}
default autoconf.dir        {${worksrcpath}}
default automake.dir        {${worksrcpath}}
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
        ([info exists option_defaults(${type}.cmd)] && [set ${type}.cmd] == $option_defaults(${type}.cmd)) ||
        (![info exists option_defaults(${type}.cmd)] && [set ${type}.cmd] == "${type}")
        )} {
            eval depends_build-append $dep
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

    if {[string equal ${action} "set"]} {
        switch $option {
            autoreconf.cmd  -
            automake.cmd    -
            autoconf.cmd {
                eval depends_build-delete $configure_map(autoconf)
            }
            xmkmf.cmd {
                depends_build-delete $configure_map(xmkmf)
            }
            use_xmkmf {
                if {[tbool args]} {
                    depends_build-append $configure_map(xmkmf)
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
options configure.optflags
options configure.cflags configure.cxxflags configure.objcflags
options configure.cppflags configure.ldflags configure.libs
options configure.fflags configure.f90flags configure.fcflags
options configure.classpath
# compiler flags section
default configure.optflags  {-Os}
default configure.cflags    {${configure.optflags}}
default configure.cxxflags  {${configure.optflags}}
default configure.objcflags {${configure.optflags}}
default configure.cppflags  {-I${prefix}/include}
default configure.ldflags   {"-L${prefix}/lib -Wl,-headerpad_max_install_names"}
default configure.libs      {}
default configure.fflags    {${configure.optflags}}
default configure.f90flags  {${configure.optflags}}
default configure.fcflags   {${configure.optflags}}
default configure.classpath {}

# tools section
options configure.perl configure.python configure.ruby
options configure.install configure.awk configure.bison
options configure.pkg_config configure.pkg_config_path
default configure.perl              {}
default configure.python            {}
default configure.ruby              {}
default configure.install           {${portutil::autoconf::install_command}}
default configure.awk               {}
default configure.bison             {}
default configure.pkg_config        {}
default configure.pkg_config_path   {}

options configure.build_arch configure.ld_archflags configure.sdkroot
default configure.build_arch    {[portconfigure::choose_supported_archs ${build_arch}]}
default configure.ld_archflags  {[portconfigure::configure_get_ld_archflags]}
default configure.sdkroot       {[portconfigure::configure_get_sdkroot]}
foreach tool {cc cxx objc f77 f90 fc} {
    options configure.${tool}_archflags
    default configure.${tool}_archflags  "\[portconfigure::configure_get_archflags $tool\]"
}

options configure.universal_archs configure.universal_args
options configure.universal_cflags configure.universal_cxxflags
options configure.universal_cppflags configure.universal_ldflags
default configure.universal_archs       {[portconfigure::choose_supported_archs ${universal_archs}]}
default configure.universal_args        {--disable-dependency-tracking}
default configure.universal_cflags      {[portconfigure::configure_get_universal_cflags]}
default configure.universal_cxxflags    {[portconfigure::configure_get_universal_cflags]}
default configure.universal_cppflags    {}
default configure.universal_ldflags     {[portconfigure::configure_get_universal_ldflags]}

# Select a distinct compiler (C, C preprocessor, C++)
options configure.ccache configure.distcc configure.pipe configure.cc \
        configure.cxx configure.cpp configure.objc configure.f77 \
        configure.f90 configure.fc configure.javac configure.compiler \
        compiler.blacklist compiler.whitelist compiler.fallback
default configure.ccache        {${configureccache}}
default configure.distcc        {${configuredistcc}}
default configure.pipe          {${configurepipe}}
default configure.cc            {[portconfigure::configure_get_compiler cc]}
default configure.cxx           {[portconfigure::configure_get_compiler cxx]}
default configure.cpp           {[portconfigure::configure_get_compiler cpp]}
default configure.objc          {[portconfigure::configure_get_compiler objc]}
default configure.f77           {[portconfigure::configure_get_compiler f77]}
default configure.f90           {[portconfigure::configure_get_compiler f90]}
default configure.fc            {[portconfigure::configure_get_compiler fc]}
default configure.javac         {[portconfigure::configure_get_compiler javac]}
default configure.compiler      {[portconfigure::configure_get_default_compiler]}
default compiler.fallback       {[portconfigure::get_compiler_fallback]}
default compiler.blacklist      {}
default compiler.whitelist      {}

set_ui_prefix

proc portconfigure::configure_start {args} {
    global UI_PREFIX configure.compiler
    
    ui_notice "$UI_PREFIX [format [msgcat::mc "Configuring %s"] [option subport]]"

    set name ""
    switch -exact ${configure.compiler} {
        cc { set name "System cc" }
        gcc { set name "System GCC" }
        gcc-3.3 { set name "Mac OS X GCC 3.3" }
        gcc-4.0 { set name "Mac OS X GCC 4.0" }
        gcc-4.2 { set name "Mac OS X GCC 4.2" }
        llvm-gcc-4.2 { set name "Mac OS X LLVM-GCC 4.2" }
        clang { set name "Mac OS X Clang" }
        apple-gcc-4.0 { set name "MacPorts Apple GCC 4.0" }
        apple-gcc-4.2 { set name "MacPorts Apple GCC 4.2" }
        macports-gcc     { set name "MacPorts GCC (port select)" }
        macports-llvm-gcc-4.2 { set name "MacPorts LLVM-GCC 4.2" }
        macports-clang { set name "MacPorts Clang (port select)" }
        default {
            if {[regexp {macports-clang-(.*)\.(.*)} ${configure.compiler} -> major minor]} {
                set name "MacPorts Clang ${major}.${minor}"
            } elseif {[regexp {macports-dragonegg-(.*)\.(.*)} ${configure.compiler} -> major minor]} {
                set name "MacPorts DragonEgg ${major}.${minor}"
            } elseif {[regexp {macports-gcc-(.*)\.(.*)} ${configure.compiler} -> major minor]} {
                set name "MacPorts GCC ${major}.${minor}"
            } else {
                return -code error "Invalid value for configure.compiler: ${configure.compiler}"
            }
        }
    }
    ui_debug "Using compiler '$name'"

    # Additional ccache directory setup
    global configure.ccache ccache_dir ccache_size macportsuser
    if {${configure.ccache}} {
        # Create ccache directory with correct permissions with root privileges
        elevateToRoot "configure ccache"
        if [catch {
                file mkdir ${ccache_dir}
                file attributes ${ccache_dir} -owner ${macportsuser} -permissions 0755
            } result] {
            ui_warn "ccache_dir ${ccache_dir} could not be created; disabling ccache: $result"
            set configure.ccache no
        }
        dropPrivileges

        # Initialize ccache directory with the given maximum size
        if {${configure.ccache}} {
            if [catch {
                exec ccache -M ${ccache_size} >/dev/null
            } result] {
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
    if {$supported_archs == ""} {
        return $archs
    }
    set ret {}
    foreach arch $archs {
        if {[lsearch -exact $supported_archs $arch] != -1} {
            set add_arch $arch
        } elseif {$arch == "x86_64" && [lsearch -exact $supported_archs "i386"] != -1} {
            set add_arch "i386"
        } elseif {$arch == "ppc64" && [lsearch -exact $supported_archs "ppc"] != -1} {
            set add_arch "ppc"
        } else {
            continue
        }
        if {[lsearch -exact $ret $add_arch] == -1} {
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
    } elseif {${configure.build_arch} != ""} {
        if {[arch_flag_supported ${configure.compiler}] &&
            ($tool == "cc" || $tool == "cxx" || $tool == "objc")
        } then {
            set flags "-arch ${configure.build_arch}"
        } elseif {${configure.build_arch} == "x86_64" || ${configure.build_arch} == "ppc64"} {
            set flags "-m64"
        } elseif {${configure.compiler} != "gcc-3.3"} {
            set flags "-m32"
        }
    }
    return $flags
}

# internal function to determine the ld flags to select an arch
# Unfortunately there's no consistent way to do this when the compiler
# doesn't support -arch, because it could be used to link rather than using
# ld directly. So we punt and let portfiles deal with that case.
proc portconfigure::configure_get_ld_archflags {args} {
    global configure.build_arch configure.compiler
    if {${configure.build_arch} != "" && [arch_flag_supported ${configure.compiler}]} {
        return "-arch ${configure.build_arch}"
    } else {
        return ""
    }
}

proc portconfigure::configure_get_sdkroot {} {
    global developer_dir macosx_deployment_target macosx_version xcodeversion os.arch os.platform
    if {${os.platform} == "darwin" && ($macosx_deployment_target != $macosx_version
        || (${os.arch} == "powerpc" && $macosx_version == "10.4" && [variant_exists universal] && [variant_isset universal]))} {
        if {[vercmp $xcodeversion 4.3] < 0} {
            set sdks_dir "${developer_dir}/SDKs"
        } else {
            set sdks_dir "${developer_dir}/Platforms/MacOSX.platform/Developer/SDKs"
        }
        if {$macosx_deployment_target == "10.4"} {
            set sdk "${sdks_dir}/MacOSX10.4u.sdk"
        } else {
            set sdk "${sdks_dir}/MacOSX${macosx_deployment_target}.sdk"
        }
        if {[file exists $sdk]} {
            return $sdk
        }
    }
    return ""
}

# internal function to determine the "-arch xy" flags for the compiler
proc portconfigure::configure_get_universal_archflags {args} {
    global configure.universal_archs
    set flags ""
    foreach arch ${configure.universal_archs} {
        if {$flags == ""} {
            set flags "-arch $arch"
        } else {
            append flags " -arch $arch"
        }
    }
    return $flags
}

# internal function to determine the CFLAGS for the compiler
proc portconfigure::configure_get_universal_cflags {args} {
    return [configure_get_universal_archflags]
}

# internal function to determine the LDFLAGS for the compiler
proc portconfigure::configure_get_universal_ldflags {args} {
    return [configure_get_universal_archflags]
}

# internal proc to determine if the compiler supports -arch
proc portconfigure::arch_flag_supported {compiler} {
    return [regexp {^gcc-4|llvm|apple|clang} $compiler]
}

# maps compiler names to the port that provides them
# TODO: Remove this after 2.2 is released and ports aren't referring to it.
array set portconfigure::compiler_name_map {
        apple-gcc-4.0           apple-gcc40
        apple-gcc-4.2           apple-gcc42
        macports-gcc-4.2        gcc42
        macports-gcc-4.3        gcc43
        macports-gcc-4.4        gcc44
        macports-gcc-4.5        gcc45
        macports-gcc-4.6        gcc46
        macports-gcc-4.7        gcc47
        macports-gcc-4.8        gcc48
        macports-llvm-gcc-4.2   llvm-gcc42
        macports-clang-2.9      clang-2.9
        macports-clang-3.0      clang-3.0
        macports-clang-3.1      clang-3.1
        macports-clang-3.2      clang-3.2
        macports-clang-3.3      clang-3.3
        macports-dragonegg-3.0  dragonegg-3.0
        macports-dragonegg-3.1  dragonegg-3.1
        macports-dragonegg-3.2  dragonegg-3.2
        macports-dragonegg-3.3  dragonegg-3.3
}

proc portconfigure::compiler_port_name {compiler} {
    if {[regexp {apple-gcc-(.*)\.(.*)} ${compiler} -> major minor]} {
        return "apple-gcc${major}${minor}"
    } elseif {[regexp {macports-clang-(.*)\.(.*)} ${compiler} -> major minor]} {
        return "clang-${major}.${minor}"
    } elseif {[regexp {macports-dragonegg-(.*)\.(.*)} ${compiler} -> major minor]} {
        return "dragonegg-${major}.${minor}"
    } elseif {[regexp {macports-gcc-(.*)\.(.*)} ${compiler} -> major minor]} {
        return "gcc${major}${minor}"
    } elseif {[regexp {macports-llvm-gcc-(.*)\.(.*)} ${compiler} -> major minor]} {
        return "llvm-gcc${major}${minor}"
    }

    return ""
}

proc portconfigure::compiler_is_port {compiler} {
    return [expr {[portconfigure::compiler_port_name ${compiler}] != ""}]
}

# internal function to determine the default compiler
proc portconfigure::configure_get_default_compiler {args} {
    if {[option compiler.whitelist] != {}} {
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
    global xcodeversion macosx_deployment_target default_compilers
    if {[info exists default_compilers]} {
        return $default_compilers
    } elseif {$xcodeversion == "none" || $xcodeversion == ""} {
        return {cc}
    } elseif {[vercmp $xcodeversion 4.6] >= 0} {
        return {clang macports-llvm-gcc-4.2 apple-gcc-4.2 macports-clang-3.2}
    } elseif {[vercmp $xcodeversion 4.2] >= 0} {
        return {clang llvm-gcc-4.2 apple-gcc-4.2 macports-clang-3.2}
    } elseif {[vercmp $xcodeversion 4.0] >= 0} {
        return {llvm-gcc-4.2 clang gcc-4.2 macports-clang-3.2 apple-gcc-4.2}
    } elseif {[vercmp $xcodeversion 3.2] >= 0} {
        if {$macosx_deployment_target == "10.4"} {
            # It's not the deployment target that is the issue, it's the
            # 10.4u SDK which base chooses if the deployment_target is set
            return {gcc-4.0}
        } else {
            return {gcc-4.2 clang llvm-gcc-4.2 macports-clang-3.2 macports-llvm-gcc-4.2 apple-gcc-4.2 gcc-4.0}
        }
    } elseif {[vercmp $xcodeversion 3.0] >= 0} {
        return {gcc-4.2 apple-gcc-4.2 gcc-4.0 macports-clang-3.2}
    } else {
        return {gcc-4.0 apple-gcc-4.2 gcc-3.3 macports-clang-3.2}
    }
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
    if {$compiler == {}} {
        set compiler ${configure.compiler}
    }
    # Tcl 8.4's switch doesn't support -matchvar.
    if {[regexp {^gcc(-3\.3|-4\.0|-4\.2)?$} $compiler -> suffix]} {
        switch $type {
            cc   -
            objc { return [find_developer_tool "gcc${suffix}"] }
            cxx  { return [find_developer_tool "g++${suffix}"] }
            cpp  { return [find_developer_tool "cpp${suffix}"] }
        }
    } elseif {[regexp {^llvm-gcc-4\.2$} $compiler]} {
        switch $type {
            cc   -
            objc { return [find_developer_tool llvm-gcc-4.2] }
            cxx  { return [find_developer_tool llvm-g++-4.2] }
            cpp  { return [find_developer_tool llvm-cpp-4.2] }
        }
    } elseif {[regexp {^clang$} $compiler]} {
        switch $type {
            cc   -
            objc { return [find_developer_tool clang] }
            cxx  {
                set clangpp [find_developer_tool clang++]
                if {[file executable $clangpp]} {
                    return $clangpp
                }
                return [find_developer_tool llvm-g++-4.2]
            }
        }
    } elseif {[regexp {^apple-gcc(-4\.0|-4\.2)$} $compiler -> suffix]} {
        switch $type {
            cc   -
            objc { return ${prefix}/bin/gcc-apple${suffix} }
            cxx  {
                if {$suffix == "-4.2"} {
                    return ${prefix}/bin/g++-apple${suffix}
                }
            }
            cpp  { return ${prefix}/bin/cpp-apple${suffix} }
        }
    } elseif {[regexp {^macports-gcc(-\d+\.\d+)?$} $compiler -> suffix]} {
        if {[string length $suffix]} {
            set suffix "-mp${suffix}"
        }
        switch $type {
            cc   -
            objc { return ${prefix}/bin/gcc${suffix} }
            cxx  { return ${prefix}/bin/g++${suffix} }
            cpp  { return ${prefix}/bin/cpp${suffix} }
            fc   -
            f77  -
            f90  { return ${prefix}/bin/gfortran${suffix} }
        }
    } elseif {[regexp {^macports-llvm-gcc-4\.2$} $compiler]} {
        switch $type {
            cc   -
            objc { return ${prefix}/bin/llvm-gcc-4.2 }
            cxx  { return ${prefix}/bin/llvm-g++-4.2 }
            cpp  { return ${prefix}/bin/llvm-cpp-4.2 }
        }
    } elseif {[regexp {^macports-clang(-\d+\.\d+)?$} $compiler -> suffix]} {
        if {[string length $suffix]} {
            set suffix "-mp${suffix}"
        }
        switch $type {
            cc   -
            objc { return ${prefix}/bin/clang${suffix} }
            cxx  { return ${prefix}/bin/clang++${suffix} }
        }
    } elseif {[regexp {^macports-dragonegg(-\d+\.\d+)$} $compiler -> infix]} {
        switch $type {
            cc   -
            objc { return ${prefix}/bin/dragonegg${infix}-gcc }
            cxx  { return ${prefix}/bin/dragonegg${infix}-g++ }
            cpp  { return ${prefix}/bin/dragonegg${infix}-cpp }
            fc   -
            f77  -
            f90  { return ${prefix}/bin/dragonegg${infix}-gfortran }
        }
    }
    # Fallbacks
    switch $type {
        cc   -
        objc { return [find_developer_tool cc] }
        cxx  { return [find_developer_tool c++] }
        cpp  { return [find_developer_tool cpp] }
    }
    return ""
}

# Automatically called from macports1.0 after evaluating the Portfile
# Some of the compilers we use are provided by MacPorts itself; ensure we
# automatically add a dependency when needed
proc portconfigure::add_automatic_compiler_dependencies {} {
    global configure.compiler

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

proc portconfigure::configure_main {args} {
    global [info globals]
    global worksrcpath use_configure use_autoreconf use_autoconf use_automake use_xmkmf \
           configure.env configure.pipe configure.libs configure.classpath configure.universal_args \
           configure.perl configure.python configure.ruby configure.install configure.awk configure.bison \
           configure.pkg_config configure.pkg_config_path \
           configure.ccache configure.distcc configure.cpp configure.javac configure.sdkroot \
           configure.march configure.mtune \
           os.platform os.major
    foreach tool {cc cxx objc f77 f90 fc ld} {
        global configure.${tool} configure.${tool}_archflags
    }
    foreach flags {cflags cppflags cxxflags objcflags ldflags fflags f90flags fcflags} {
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
        append_list_to_environment_value xmkmf "IMAKECPP" ${configure.cpp}
        if {[catch {command_exec xmkmf} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] xmkmf $result]"
        }

        parse_environment xmkmf
        append_list_to_environment_value xmkmf "IMAKECPP" ${configure.cpp}
        if {[catch {command_exec "cd ${worksrcpath} && make Makefiles" -varprefix xmkmf} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] "make Makefiles" $result]"
        }
    } elseif {[tbool use_configure]} {
        # Merge (ld|c|cpp|cxx)flags into the environment variable.
        parse_environment configure

        # Set pre-compiler filter to use (ccache/distcc), if any.
        if {[tbool configure.ccache] && [tbool configure.distcc]} {
            set filter "ccache "
            append_list_to_environment_value configure "CCACHE_PREFIX" "distcc"
        } elseif {[tbool configure.ccache]} {
            set filter "ccache "
        } elseif {[tbool configure.distcc]} {
            set filter "distcc "
        } else {
            set filter ""
        }
        
        # Set flags controlling the kind of compiler output.
        if {[tbool configure.pipe]} {
            set output "-pipe "
        } else {
            set output ""
        }

        # Append configure flags.
        append_list_to_environment_value configure "CC" ${filter}${configure.cc}
        append_list_to_environment_value configure "CXX" ${filter}${configure.cxx}
        append_list_to_environment_value configure "OBJC" ${filter}${configure.objc}
        append_list_to_environment_value configure "FC" ${configure.fc}
        append_list_to_environment_value configure "F77" ${configure.f77}
        append_list_to_environment_value configure "F90" ${configure.f90}
        append_list_to_environment_value configure "JAVAC" ${configure.javac}
        append_list_to_environment_value configure "CFLAGS" ${output}${configure.cflags}
        append_list_to_environment_value configure "CPPFLAGS" ${configure.cppflags}
        append_list_to_environment_value configure "CXXFLAGS" ${output}${configure.cxxflags}
        append_list_to_environment_value configure "OBJCFLAGS" ${output}${configure.objcflags}
        append_list_to_environment_value configure "LDFLAGS" ${configure.ldflags}
        append_list_to_environment_value configure "LIBS" ${configure.libs}
        append_list_to_environment_value configure "FFLAGS" ${output}${configure.fflags}
        append_list_to_environment_value configure "F90FLAGS" ${output}${configure.f90flags}
        append_list_to_environment_value configure "FCFLAGS" ${output}${configure.fcflags}
        append_list_to_environment_value configure "CLASSPATH" ${configure.classpath}
        append_list_to_environment_value configure "PERL" ${configure.perl}
        append_list_to_environment_value configure "PYTHON" ${configure.python}
        append_list_to_environment_value configure "RUBY" ${configure.ruby}
        append_list_to_environment_value configure "INSTALL" ${configure.install}
        append_list_to_environment_value configure "AWK" ${configure.awk}
        append_list_to_environment_value configure "BISON" ${configure.bison}
        append_list_to_environment_value configure "PKG_CONFIG" ${configure.pkg_config}
        append_list_to_environment_value configure "PKG_CONFIG_PATH" ${configure.pkg_config_path}

        # https://trac.macports.org/ticket/34221
        if {${os.platform} == "darwin" && ${os.major} == 12} {
            append_list_to_environment_value configure "__CFPREFERENCES_AVOID_DAEMON" 1
        }

        # add SDK flags if cross-compiling (or universal on ppc tiger)
        if {${configure.sdkroot} != ""} {
            foreach flags {CPPFLAGS CFLAGS CXXFLAGS OBJCFLAGS} {
                append_list_to_environment_value configure $flags "-isysroot ${configure.sdkroot}"
            }
            append_list_to_environment_value configure "LDFLAGS" "-Wl,-syslibroot,${configure.sdkroot}"
        }

        # add extra flags that are conditional on whether we're building universal
        if {[variant_exists universal] && [variant_isset universal]} {
            foreach flags {CFLAGS OBJCFLAGS} {
                append_list_to_environment_value configure $flags ${configure.universal_cflags}
            }
            append_list_to_environment_value configure "CXXFLAGS" ${configure.universal_cxxflags}
            append_list_to_environment_value configure "CPPFLAGS" ${configure.universal_cppflags}
            append_list_to_environment_value configure "LDFLAGS" ${configure.universal_ldflags}
            eval configure.pre_args-append ${configure.universal_args}
        } else {
            foreach {tool flags} {cc CFLAGS cxx CXXFLAGS objc OBJCFLAGS f77 FFLAGS f90 F90FLAGS fc FCFLAGS ld LDFLAGS} {
                append_list_to_environment_value configure $flags [set configure.${tool}_archflags]
                if {${configure.march} != {}} {
                    append_list_to_environment_value configure $flags "-march=${configure.march}"
                }
                if {${configure.mtune} != {}} {
                    append_list_to_environment_value configure $flags "-mtune=${configure.mtune}"
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
