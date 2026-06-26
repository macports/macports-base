# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

package provide portconfigure_run 1.0
package require portutil 1.0
package require portprogress 1.0

namespace eval portconfigure {

proc configure_start {args} {
    global UI_PREFIX subport configure.compiler compiler.fallback configure.ccache

    ui_notice "$UI_PREFIX [format [msgcat::mc "Configuring %s"] $subport]"

    set compiler ${configure.compiler}
    set valid_compilers {
        {^apple-gcc-(4\.[02])$}                    {MacPorts Apple GCC %s}
        {^cc$}                                     {System cc}
        {^clang$}                                  {Xcode Clang}
        {^gcc$}                                    {System GCC}
        {^gcc-(3\.3|4\.[02])$}                     {Xcode GCC %s}
        {^llvm-gcc-4\.2$}                          {Xcode LLVM-GCC 4.2}
        {^macports-clang$}                         {MacPorts Clang (port select)}
        {^macports-clang-(\d+(?:\.\d+)?)$}         {MacPorts Clang %s}
        {^macports-gcc$}                           {MacPorts GCC (port select)}
        {^macports-gcc-(\d+(?:\.\d+)?)$}           {MacPorts GCC %s}
        {^macports-llvm-gcc-4\.2$}                 {MacPorts LLVM-GCC 4.2}
        {^macports-g95$}                           {MacPorts G95}
        {^macports-mpich-default$}                 {MacPorts MPICH Wrapper for MacPorts' Default C/C++ Compiler}
        {^macports-openmpi-default$}               {MacPorts Open MPI Wrapper for MacPorts' Default C/C++ Compiler}
        {^macports-mpich-clang$}                   {MacPorts MPICH Wrapper for Xcode Clang}
        {^macports-openmpi-clang$}                 {MacPorts Open MPI Wrapper for Xcode Clang}
        {^macports-mpich-clang-(\d+(?:\.\d+)?)$}   {MacPorts MPICH Wrapper for Clang %s}
        {^macports-openmpi-clang-(\d+(?:\.\d+)?)$} {MacPorts Open MPI Wrapper for Clang %s}
        {^macports-mpich-gcc-(\d+(?:\.\d+)?)$}     {MacPorts MPICH Wrapper for GCC %s}
        {^macports-openmpi-gcc-(\d+(?:\.\d+)?)$}   {MacPorts Open MPI Wrapper for GCC %s}
        {^macports-(clang|gcc)-devel$}             {MacPorts %s Development}
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
    ui_debug "Preferred compilers: ${compiler.fallback}"
    ui_debug "Using compiler '$compiler_name'"
    variable no_default_compiler_allowed
    if {$no_default_compiler_allowed} {
        ui_warn_once no_default_compiler_allowed "All compilers are either blacklisted or unavailable; defaulting to first fallback option"
    }

    # Additional ccache directory setup
    if {${configure.ccache}} {
        global ccache_dir ccache_size macportsuser
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

proc configure_main {args} {
    global worksrcpath use_configure use_autoreconf use_autoconf use_automake use_xmkmf \
           configure.pipe configure.libs configure.classpath configure.universal_args \
           configure.perl configure.python configure.ruby configure.install configure.awk configure.bison \
           configure.pkg_config configure.pkg_config_path \
           configure.ccache configure.distcc configure.javac configure.sdkroot \
           configure.march configure.mtune os.platform os.major \
           compiler.limit_flags
    foreach tool {cc cxx objc objcxx f77 f90 fc ld} {
        global configure.${tool} configure.${tool}_archflags
    }
    foreach flags {cflags cppflags cxxflags objcflags objcxxflags ldflags fflags f90flags fcflags} {
        global configure.${flags} configure.universal_${flags}
    }

    set callback [list "-callback" portprogress::target_progress_callback]

    if {[tbool use_autoreconf]} {
        if {[catch {command_exec {*}${callback} autoreconf} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] autoreconf $result]"
        }
    }

    if {[tbool use_automake]} {
        if {[catch {command_exec {*}${callback} automake} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] automake $result]"
        }
    }

    if {[tbool use_autoconf]} {
        if {[catch {command_exec {*}${callback} autoconf} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] autoconf $result]"
        }
    }

    if {[tbool use_xmkmf]} {
        parse_environment xmkmf
        if {[catch {command_exec {*}${callback} xmkmf} result]} {
            return -code error "[format [msgcat::mc "%s failure: %s"] xmkmf $result]"
        }

        parse_environment xmkmf
        if {[catch {command_exec {*}${callback} -varprefix xmkmf "cd ${worksrcpath} && make Makefiles"} result]} {
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
            DEVELOPER_DIR \
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

        # add SDK flags if needed
        if {${configure.sdkroot} ne "" && !${compiler.limit_flags}} {
            foreach env_var {CPPFLAGS CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS} {
                append_to_environment_value configure $env_var -isysroot${configure.sdkroot}
            }
            append_to_environment_value configure "LDFLAGS" -Wl,-syslibroot,${configure.sdkroot}
        }

        # add extra flags that are conditional on whether we're building universal
        append_to_environment_value configure CFLAGS {*}[get_canonical_archflags cc]
        if {![catch {get_canonical_archflags f77} flags]} {
            append_to_environment_value configure FFLAGS {*}$flags
        }
        foreach tool {cxx objc objcxx cpp f90 fc ld} {
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
        if {[catch {command_exec {*}${callback} configure} result]} {
            global configure.dir build.dir
            foreach error_log [list ${configure.dir}/config.log ${configure.dir}/CMakeFiles/CMakeError.log ${build.dir}/meson-logs/meson-log.txt] {
                if {[file exists ${error_log}]} {
                    ui_error "[format [msgcat::mc "Failed to configure %s: consult %s"] [option subport] ${error_log}]"
                }
            }
            return -code error "[format [msgcat::mc "%s failure: %s"] configure $result]"
        }
    }
    return 0
}

proc check_warnings {warning_flag} {
    global \
        workpath

    set files [list]

    fs-traverse -tails file [list ${workpath}] {
        if {[file tail $file] in [list config.log CMakeError.log meson-log.txt] && [file isfile [file join ${workpath} $file]]} {
            # We could do the searching ourselves, but using a tool optimized for this purpose is likely much faster
            # than using Tcl.
            #
            # Using /usr/bin/grep here so we don't accidentally pick up a MacPorts-installed grep which might
            # currently not be runnable due to a missing library.
            set args [list "/usr/bin/grep" "-El" "--" "-W[quotemeta $warning_flag]\\\]\$"]
            lappend args [file join ${workpath} $file]

            if {![catch {exec -- {*}$args}]} {
                lappend files $file
            }
        }
    }

    if {[llength $files] > 0} {
        ui_warn [format [msgcat::mc "Configuration logfiles contain indications of %s; check that features were not accidentally disabled:"] "-W$warning_flag"]
        foreach file $files {
            ui_msg [format "  found in %s" $file]
        }
    }
}

proc check_implicit_int {} {
    check_warnings {implicit-int}
}

proc check_incompatible_function_pointer_types {} {
    check_warnings {incompatible-function-pointer-types}
}

proc check_implicit_function_declarations {} {
    global \
        workpath \
        configure.checks.implicit_function_declaration.whitelist

    # Map from function name to config.log that used it without declaration
    set undeclared_functions [dict create]

    fs-traverse -tails file [list ${workpath}] {
        if {[file tail $file] in [list config.log CMakeError.log meson-log.txt] && [file isfile [file join ${workpath} $file]]} {
            # We could do the searching ourselves, but using a tool optimized for this purpose is likely much faster
            # than using Tcl.
            #
            # Using /usr/bin/grep here so we don't accidentally pick up a MacPorts-installed grep which might
            # currently not be runnable due to a missing library.
            set args [list "/usr/bin/grep" "-E" "--" "-Wimplicit-function-declaration\\\]\$"]
            lappend args [file join ${workpath} $file]

            if {![catch {set result [exec -- {*}$args]}]} {
                foreach line [split $result "\n"] {
                    if {[regexp -- "(?:implicit declaration of function|implicitly declaring library function|call to undeclared function|call to undeclared library function) '(\[^']+)'" $line -> function]} {
                        set is_whitelisted no
                        foreach whitelisted ${configure.checks.implicit_function_declaration.whitelist} {
                            if {[string match -nocase $whitelisted $function]} {
                                set is_whitelisted yes
                                break
                            }
                        }
                        if {!$is_whitelisted} {
                            dict set undeclared_functions $function $file 1
                        } else {
                            ui_debug [format "Ignoring implicit declaration of function '%s' because it is whitelisted" $function]
                        }
                    }
                }
            }
        }
    }

    if {[dict size $undeclared_functions] > 0} {
        ui_warn [format [msgcat::mc "Configuration logfiles contain indications of %s; check that features were not accidentally disabled:"] "-Wimplicit-function-declaration"]
        dict for {function files} $undeclared_functions {
            ui_msg [format "  %s: found in %s" $function [join [dict keys $files] ", "]]
        }
    }
}

proc configure_finish {args} {
    global \
        configure.dir \
        configure.checks.implicit_function_declaration \
        configure.checks.implicit_int \
        configure.checks.incompatible_function_pointer_types

    if {[file isdirectory ${configure.dir}]} {
        if {${configure.checks.implicit_function_declaration}} {
            check_implicit_function_declarations
        }
        if {${configure.checks.implicit_int}} {
            check_implicit_int
        }
        if {${configure.checks.incompatible_function_pointer_types}} {
            check_incompatible_function_pointer_types
        }
    }
}

}
