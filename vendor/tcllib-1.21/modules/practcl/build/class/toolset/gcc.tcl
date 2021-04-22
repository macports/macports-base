
::clay::define ::practcl::toolset.gcc {
  superclass ::practcl::toolset

  method Autoconf {} {
    ###
    # Re-run autoconf for this project
    # Not a good idea in practice... but in the right hands it can be useful
    ###
    set pwd [pwd]
    set srcdir [file normalize [my define get srcdir]]
    set localsrcdir [my MakeDir $srcdir]
    cd $localsrcdir
    foreach template {configure.ac configure.in} {
      set input [file join $srcdir $template]
      if {[file exists $input]} {
        puts "autoconf -f $input > [file join $srcdir configure]"
        exec autoconf -f $input > [file join $srcdir configure]
      }
    }
    cd $pwd
  }

  method BuildDir {PWD} {
    set name [my define get name]
    set debug [my define get debug 0]
    if {[my <project> define get LOCAL 0]} {
      return [my define get builddir [file join $PWD local $name]]
    }
    if {$debug} {
      return [my define get builddir [file join $PWD debug $name]]
    } else {
      return [my define get builddir [file join $PWD pkg $name]]
    }
  }

  method ConfigureOpts {} {
    set opts {}
    set builddir [my define get builddir]

    if {[my define get broken_destroot 0]} {
      set PREFIX [my <project> define get prefix_broken_destdir]
    } else {
      set PREFIX [my <project> define get prefix]
    }
    switch [my define get name] {
      tcl {
        set opts [::practcl::platform::tcl_core_options [my <project> define get TEACUP_OS]]
      }
      tk {
        set opts [::practcl::platform::tk_core_options  [my <project> define get TEACUP_OS]]
      }
    }
    if {[my <project> define get CONFIG_SITE] != {}} {
      lappend opts --host=[my <project> define get HOST]
    }
    set inside_msys [string is true -strict [my <project> define get MSYS_ENV 0]]
    lappend opts --with-tclsh=[info nameofexecutable]

    if {[my define get tk 0]} {
      if {![my <project> define get LOCAL 0]} {
        set obj [my <project> tclcore]
        if {$obj ne {}} {
          if {$inside_msys} {
            lappend opts --with-tcl=[::practcl::file_relative [file normalize $builddir] [$obj define get builddir]]
          } else {
            lappend opts --with-tcl=[file normalize [$obj define get builddir]]
          }
        }
        set obj [my <project> tkcore]
        if {$obj ne {}} {
          if {$inside_msys} {
            lappend opts --with-tk=[::practcl::file_relative [file normalize $builddir] [$obj define get builddir]]
          } else {
            lappend opts --with-tk=[file normalize [$obj define get builddir]]
          }
        }
      } else {
        lappend opts --with-tcl=[file join $PREFIX lib]
        lappend opts --with-tk=[file join $PREFIX lib]
      }
    } else {
      if {![my <project> define get LOCAL 0]} {
        set obj [my <project> tclcore]
        if {$obj ne {}} {
          if {$inside_msys} {
            lappend opts --with-tcl=[::practcl::file_relative [file normalize $builddir] [$obj define get builddir]]
          } else {
            lappend opts --with-tcl=[file normalize [$obj define get builddir]]
          }
        }
      } else {
        lappend opts --with-tcl=[file join $PREFIX lib]
      }
    }

    lappend opts {*}[my define get config_opts]
    if {![regexp -- "--prefix" $opts]} {
      lappend opts --prefix=$PREFIX --exec-prefix=$PREFIX
    }
    if {[my define get debug 0]} {
      lappend opts --enable-symbols=true
    }
    #--exec_prefix=$PREFIX
    #if {$::tcl_platform(platform) eq "windows"} {
    #  lappend opts --disable-64bit
    #}
    if {[my define get static 1]} {
      lappend opts --disable-shared
      #--disable-stubs
      #
    } else {
      lappend opts --enable-shared
    }
    return $opts
  }

  # Detect what directory contains the Makefile template
  method MakeDir {srcdir} {
    set localsrcdir $srcdir
    if {[file exists [file join $srcdir generic]]} {
      my define add include_dir [file join $srcdir generic]
    }
    set os [my <project> define get TEACUP_OS]
    switch $os {
      windows {
        if {[file exists [file join $srcdir win]]} {
          my define add include_dir [file join $srcdir win]
        }
        if {[file exists [file join $srcdir win Makefile.in]]} {
          set localsrcdir [file join $srcdir win]
        }
      }
      macosx {
        if {[file exists [file join $srcdir unix Makefile.in]]} {
          set localsrcdir [file join $srcdir unix]
        }
      }
      default {
        if {[file exists [file join $srcdir $os]]} {
          my define add include_dir [file join $srcdir $os]
        }
        if {[file exists [file join $srcdir unix]]} {
          my define add include_dir [file join $srcdir unix]
        }
        if {[file exists [file join $srcdir $os Makefile.in]]} {
          set localsrcdir [file join $srcdir $os]
        } elseif {[file exists [file join $srcdir unix Makefile.in]]} {
          set localsrcdir [file join $srcdir unix]
        }
      }
    }
    return $localsrcdir
  }

  Ensemble make::autodetect {} {
    set srcdir [my define get srcdir]
    set localsrcdir [my MakeDir $srcdir]
    if {$localsrcdir eq {}} {
      set localsrcdir $srcdir
    }
    if {$srcdir eq $localsrcdir} {
      if {![file exists [file join $srcdir tclconfig install-sh]]} {
        # ensure we have tclconfig with all of the trimmings
        set teapath {}
        if {[file exists [file join $srcdir .. tclconfig install-sh]]} {
          set teapath [file join $srcdir .. tclconfig]
        } else {
          set tclConfigObj [::practcl::LOCAL tool tclconfig]
          $tclConfigObj load
          set teapath [$tclConfigObj define get srcdir]
        }
        set teapath [file normalize $teapath]
        #file mkdir [file join $srcdir tclconfig]
        if {[catch {file link -symbolic [file join $srcdir tclconfig] $teapath}]} {
          ::practcl::copyDir [file join $teapath] [file join $srcdir tclconfig]
        }
      }
    }
    set builddir [my define get builddir]
    file mkdir $builddir
    if {![file exists [file join $localsrcdir configure]]} {
      if {[file exists [file join $localsrcdir autogen.sh]]} {
        cd $localsrcdir
        catch {exec sh autogen.sh >>& [file join $builddir autoconf.log]}
        cd $::CWD
      }
    }
    set opts [my ConfigureOpts]
    if {[file exists [file join $builddir autoconf.log]]} {
      file delete [file join $builddir autoconf.log]
    }
    ::practcl::debug [list PKG [my define get name] CONFIGURE {*}$opts]
    ::practcl::log   [file join $builddir autoconf.log] [list  CONFIGURE {*}$opts]
    cd $builddir
    if {[my <project> define get CONFIG_SITE] ne {}} {
      set ::env(CONFIG_SITE) [my <project> define get CONFIG_SITE]
    }
    catch {exec sh [file join $localsrcdir configure] {*}$opts >>& [file join $builddir autoconf.log]}
    cd $::CWD
  }

  Ensemble make::clean {} {
    set builddir [file normalize [my define get builddir]]
    catch {::practcl::domake $builddir clean}
  }

  Ensemble make::compile {} {
    set name [my define get name]
    set srcdir [my define get srcdir]
    if {[my define get static 1]} {
      puts "BUILDING Static $name $srcdir"
    } else {
      puts "BUILDING Dynamic $name $srcdir"
    }
    cd $::CWD
    set builddir [file normalize [my define get builddir]]
    file mkdir $builddir
    if {![file exists [file join $builddir Makefile]]} {
      my Configure
    }
    if {[file exists [file join $builddir make.tcl]]} {
      if {[my define get debug 0]} {
        ::practcl::domake.tcl $builddir debug all
      } else {
        ::practcl::domake.tcl $builddir all
      }
    } else {
      ::practcl::domake $builddir all
    }
  }

  Ensemble make::install DEST {
    set PWD [pwd]
    set builddir [my define get builddir]
    if {[my <project> define get LOCAL 0] || $DEST eq {}} {
      if {[file exists [file join $builddir make.tcl]]} {
        puts "[self] Local INSTALL (Practcl)"
        ::practcl::domake.tcl $builddir install
      } elseif {[my define get broken_destroot 0] == 0} {
        puts "[self] Local INSTALL (TEA)"
        ::practcl::domake $builddir install
      }
    } else {
      if {[file exists [file join $builddir make.tcl]]} {
        # Practcl builds can inject right to where we need them
        puts "[self] VFS INSTALL $DEST (Practcl)"
        ::practcl::domake.tcl $builddir install-package $DEST
      } elseif {[my define get broken_destroot 0] == 0} {
        # Most modern TEA projects understand DESTROOT in the makefile
        puts "[self] VFS INSTALL $DEST (TEA)"
        ::practcl::domake $builddir install DESTDIR=[::practcl::file_relative $builddir $DEST]
      } else {
        # But some require us to do an install into a fictitious filesystem
        # and then extract the gooey parts within.
        # (*cough*) TkImg
        set PREFIX [my <project> define get prefix]
        set BROKENROOT [::practcl::msys_to_tclpath [my <project> define get prefix_broken_destdir]]
        file delete -force $BROKENROOT
        file mkdir $BROKENROOT
        ::practcl::domake $builddir $install
        ::practcl::copyDir $BROKENROOT  [file join $DEST [string trimleft $PREFIX /]]
        file delete -force $BROKENROOT
      }
    }
    cd $PWD
  }

  method build-compile-sources {PROJECT COMPILE CPPCOMPILE INCLUDES} {
    set objext [my define get OBJEXT o]
    set EXTERN_OBJS {}
    set OBJECTS {}
    set result {}
    set builddir [$PROJECT define get builddir]
    file mkdir [file join $builddir objs]
    set debug [$PROJECT define get debug 0]

    set task {}
    ###
    # Compile the C sources
    ###
    ::practcl::debug ### COMPILE PRODUCTS
    foreach {ofile info} [${PROJECT} project-compile-products] {
      ::practcl::debug $ofile $info
      if {[dict exists $info library]} {
        #dict set task $ofile done 1
        continue
      }
      # Products with no cfile aren't compiled
      if {![dict exists $info cfile] || [set cfile [dict get $info cfile]] eq {}} {
        #dict set task $ofile done 1
        continue
      }
      set ofile [file rootname $ofile]
      dict set task $ofile done 0
      if {[dict exists $info external] && [dict get $info external]==1} {
        dict set task $ofile external 1
      } else {
        dict set task $ofile external 0
      }
      set cfile [dict get $info cfile]
      if {$debug} {
        set ofilename [file join $builddir objs [file rootname [file tail $ofile]].debug.${objext}]
      } else {
        set ofilename [file join $builddir objs [file tail $ofile]].${objext}
      }
      dict set task $ofile source $cfile
      dict set task $ofile objfile $ofilename
      if {![dict exist $info command]} {
        if {[file extension $cfile] in {.c++ .cpp}} {
          set cmd $CPPCOMPILE
        } else {
          set cmd $COMPILE
        }
        if {[dict exists $info extra]} {
          append cmd " [dict get $info extra]"
        }
        append cmd " $INCLUDES"
        append cmd " -c $cfile"
        append cmd " -o $ofilename"
        dict set task $ofile command $cmd
      }
    }
    set completed 0
    while {$completed==0} {
      set completed 1
      foreach {ofile info} $task {
        set waiting {}
        if {[dict exists $info done] && [dict get $info done]} continue
        ::practcl::debug COMPILING $ofile $info
        set filename [dict get $info objfile]
        if {[file exists $filename] && [file mtime $filename]>[file mtime [dict get $info source]]} {
          lappend result $filename
          dict set task $ofile done 1
          continue
        }
        if {[dict exists $info depend]} {
          foreach file [dict get $info depend] {
            if {[dict exists $task $file command] && [dict exists $task $file done] && [dict get $task $file done] != 1} {
              set waiting $file
              break
            }
          }
        }
        if {$waiting ne {}} {
          set completed 0
          puts "$ofile waiting for $waiting"
          continue
        }
        if {[dict exists $info command]} {
          set cmd [dict get $info command]
          puts "$cmd"
          exec {*}$cmd >&@ stdout
        }
        if {[file exists $filename]} {
          lappend result $filename
          dict set task $ofile done 1
          continue
        }
        error "Failed to produce $filename"
      }
    }
    return $result
  }

method build-Makefile {path PROJECT} {
  array set proj [$PROJECT define dump]
  set path $proj(builddir)
  cd $path
  set includedir .
  set objext [my define get OBJEXT o]

  #lappend includedir [::practcl::file_relative $path $proj(TCL_INCLUDES)]
  lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(TCL_SRC_DIR) generic]]]
  lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(srcdir) generic]]]
  foreach include [$PROJECT toolset-include-directory] {
    set cpath [::practcl::file_relative $path [file normalize $include]]
    if {$cpath ni $includedir} {
      lappend includedir $cpath
    }
  }
  set INCLUDES  "-I[join $includedir " -I"]"
  set NAME [string toupper $proj(name)]
  set result {}
  set products {}
  set libraries {}
  set thisline {}
  ::practcl::cputs result "${NAME}_DEFS = $proj(DEFS)\n"
  ::practcl::cputs result "${NAME}_INCLUDES = -I\"[join $includedir "\" -I\""]\"\n"
  ::practcl::cputs result "${NAME}_COMPILE = \$(CC) \$(CFLAGS) \$(PKG_CFLAGS) \$(${NAME}_DEFS) \$(${NAME}_INCLUDES) \$(INCLUDES) \$(AM_CPPFLAGS) \$(CPPFLAGS) \$(AM_CFLAGS)"
  ::practcl::cputs result "${NAME}_CPPCOMPILE = \$(CXX) \$(CFLAGS) \$(PKG_CFLAGS) \$(${NAME}_DEFS) \$(${NAME}_INCLUDES) \$(INCLUDES) \$(AM_CPPFLAGS) \$(CPPFLAGS) \$(AM_CFLAGS)"

  foreach {ofile info} [$PROJECT project-compile-products] {
    dict set products $ofile $info
    set fname [file rootname ${ofile}].${objext}
    if {[dict exists $info library]} {
lappend libraries $ofile
continue
    }
    if {[dict exists $info depend]} {
      ::practcl::cputs result "\n${fname}: [dict get $info depend]"
    } else {
      ::practcl::cputs result "\n${fname}:"
    }
    set cfile [dict get $info cfile]
    if {[file extension $cfile] in {.c++ .cpp}} {
      set cmd "\t\$\(${NAME}_CPPCOMPILE\)"
    } else {
      set cmd "\t\$\(${NAME}_COMPILE\)"
    }
    if {[dict exists $info extra]} {
      append cmd " [dict get $info extra]"
    }
    append cmd " -c [dict get $info cfile] -o \$@\n\t"
    ::practcl::cputs result  $cmd
  }

  set map {}
  lappend map %LIBRARY_NAME% $proj(name)
  lappend map %LIBRARY_VERSION% $proj(version)
  lappend map %LIBRARY_VERSION_NODOTS% [string map {. {}} $proj(version)]
  lappend map %LIBRARY_PREFIX% [$PROJECT define getnull libprefix]

  if {[string is true [$PROJECT define get SHARED_BUILD]]} {
    set outfile [$PROJECT define get libfile]
  } else {
    set outfile [$PROJECT shared_library]
  }
  $PROJECT define set shared_library $outfile
  ::practcl::cputs result "
${NAME}_SHLIB = $outfile
${NAME}_OBJS = [dict keys $products]
"

  #lappend map %OUTFILE% {\[$]@}
  lappend map %OUTFILE% $outfile
  lappend map %LIBRARY_OBJECTS% "\$(${NAME}_OBJS)"
  ::practcl::cputs result "$outfile: \$(${NAME}_OBJS)"
  ::practcl::cputs result "\t[string map $map [$PROJECT define get PRACTCL_SHARED_LIB]]"
  if {[$PROJECT define get PRACTCL_VC_MANIFEST_EMBED_DLL] ni {: {}}} {
    ::practcl::cputs result "\t[string map $map [$PROJECT define get PRACTCL_VC_MANIFEST_EMBED_DLL]]"
  }
  ::practcl::cputs result {}
  if {[string is true [$PROJECT define get SHARED_BUILD]]} {
    #set outfile [$PROJECT static_library]
    set outfile $proj(name).a
  } else {
    set outfile [$PROJECT define get libfile]
  }
  $PROJECT define set static_library $outfile
  dict set map %OUTFILE% $outfile
  ::practcl::cputs result "$outfile: \$(${NAME}_OBJS)"
  ::practcl::cputs result "\t[string map $map [$PROJECT define get PRACTCL_STATIC_LIB]]"
  ::practcl::cputs result {}
  return $result
}

###
# Produce a static or dynamic library
###
method build-library {outfile PROJECT} {
  array set proj [$PROJECT define dump]
  set path $proj(builddir)
  cd $path
  set includedir .
  #lappend includedir [::practcl::file_relative $path $proj(TCL_INCLUDES)]
  lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(TCL_SRC_DIR) generic]]]
  if {[$PROJECT define get TEA_PRIVATE_TCL_HEADERS 0]} {
    if {[$PROJECT define get TEA_PLATFORM] eq "windows"} {
      lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(TCL_SRC_DIR) win]]]
    } else {
      lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(TCL_SRC_DIR) unix]]]
    }
  }

  lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(srcdir) generic]]]

  if {[$PROJECT define get tk 0]} {
    lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(TK_SRC_DIR) generic]]]
    lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(TK_SRC_DIR) ttk]]]
    lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(TK_SRC_DIR) xlib]]]
    if {[$PROJECT define get TEA_PRIVATE_TK_HEADERS 0]} {
      if {[$PROJECT define get TEA_PLATFORM] eq "windows"} {
        lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(TK_SRC_DIR) win]]]
      } else {
        lappend includedir [::practcl::file_relative $path [file normalize [file join $proj(TK_SRC_DIR) unix]]]
      }
    }
    lappend includedir [::practcl::file_relative $path [file normalize $proj(TK_BIN_DIR)]]
  }
  foreach include [$PROJECT toolset-include-directory] {
    set cpath [::practcl::file_relative $path [file normalize $include]]
    if {$cpath ni $includedir} {
      lappend includedir $cpath
    }
  }
  my build-cflags $PROJECT $proj(DEFS) name version defs
  set NAME [string toupper $name]
  set debug [$PROJECT define get debug 0]
  set os [$PROJECT define get TEACUP_OS]

  set INCLUDES  "-I[join $includedir " -I"]"
  if {$debug} {
    set COMPILE "$proj(CC) $proj(CFLAGS_DEBUG) -ggdb \
$proj(CFLAGS_WARNING) $INCLUDES $defs"

    if {[info exists proc(CXX)]} {
      set COMPILECPP "$proj(CXX) $defs $INCLUDES $proj(CFLAGS_DEBUG) -ggdb \
  $defs $proj(CFLAGS_WARNING)"
    } else {
      set COMPILECPP $COMPILE
    }
  } else {
    set COMPILE "$proj(CC) $proj(CFLAGS) $defs"

    if {[info exists proc(CXX)]} {
      set COMPILECPP "$proj(CXX) $defs $proj(CFLAGS)"
    } else {
      set COMPILECPP $COMPILE
    }
  }

  set products [my build-compile-sources $PROJECT $COMPILE $COMPILECPP $INCLUDES]

  set map {}
  lappend map %LIBRARY_NAME% $proj(name)
  lappend map %LIBRARY_VERSION% $proj(version)
  lappend map %LIBRARY_VERSION_NODOTS% [string map {. {}} $proj(version)]
  lappend map %OUTFILE% $outfile
  lappend map %LIBRARY_OBJECTS% $products
  lappend map {${CFLAGS}} "$proj(CFLAGS_DEFAULT) $proj(CFLAGS_WARNING)"

  if {[string is true [$PROJECT define get SHARED_BUILD 1]]} {
    set cmd [$PROJECT define get PRACTCL_SHARED_LIB]
    append cmd " [$PROJECT define get PRACTCL_LIBS]"
    set cmd [string map $map $cmd]
    puts $cmd
    exec {*}$cmd >&@ stdout
    if {[$PROJECT define get PRACTCL_VC_MANIFEST_EMBED_DLL] ni {: {}}} {
      set cmd [string map $map [$PROJECT define get PRACTCL_VC_MANIFEST_EMBED_DLL]]
      puts $cmd
      exec {*}$cmd >&@ stdout
    }
  } else {
    set cmd [string map $map [$PROJECT define get PRACTCL_STATIC_LIB]]
    puts $cmd
    exec {*}$cmd >&@ stdout
  }
  set ranlib [$PROJECT define get RANLIB]
  if {$ranlib ni {{} :}} {
    catch {exec $ranlib $outfile}
  }
}

###
# Produce a static executable
###
method build-tclsh {outfile PROJECT {path {auto}}} {
  if {[my define get tk 0] && [my define get static_tk 0]} {
    puts " BUILDING STATIC TCL/TK EXE $PROJECT"
    set TKOBJ  [$PROJECT tkcore]
    if {[info command $TKOBJ] eq {}} {
      set TKOBJ ::noop
      $PROJECT define set static_tk 0
    } else {
      ::practcl::toolset select $TKOBJ
      array set TK  [$TKOBJ read_configuration]
      set do_tk [$TKOBJ define get static]
      $PROJECT define set static_tk $do_tk
      $PROJECT define set tk $do_tk
      set TKSRCDIR [$TKOBJ define get srcdir]
    }
  } else {
    puts " BUILDING STATIC TCL EXE $PROJECT"
    set TKOBJ ::noop
    my define set static_tk 0
  }
  set TCLOBJ [$PROJECT tclcore]
  ::practcl::toolset select $TCLOBJ
  set PKG_OBJS {}
  foreach item [$PROJECT link list core.library] {
    if {[string is true [$item define get static]]} {
      lappend PKG_OBJS $item
    }
  }
  foreach item [$PROJECT link list package] {
    if {[string is true [$item define get static]]} {
      lappend PKG_OBJS $item
    }
  }
  array set TCL [$TCLOBJ read_configuration]
  if {$path in {{} auto}} {
    set path [file dirname [file normalize $outfile]]
  }
  if {$path eq "."} {
    set path [pwd]
  }
  cd $path
  ###
  # For a static Tcl shell, we need to build all local sources
  # with the same DEFS flags as the tcl core was compiled with.
  # The DEFS produced by a TEA extension aren't intended to operate
  # with the internals of a staticly linked Tcl
  ###
  my build-cflags $PROJECT $TCL(defs) name version defs
  set debug [$PROJECT define get debug 0]
  set NAME [string toupper $name]
  set result {}
  set libraries {}
  set thisline {}
  set OBJECTS {}
  set EXTERN_OBJS {}
  foreach obj $PKG_OBJS {
    $obj compile
    set config($obj) [$obj read_configuration]
  }
  set os [$PROJECT define get TEACUP_OS]
  set TCLSRCDIR [$TCLOBJ define get srcdir]

  set includedir .
  foreach include [$TCLOBJ toolset-include-directory] {
    set cpath [::practcl::file_relative $path [file normalize $include]]
    if {$cpath ni $includedir} {
      lappend includedir $cpath
    }
  }
  lappend includedir [::practcl::file_relative $path [file normalize ../tcl/compat/zlib]]
  if {[$PROJECT define get static_tk]} {
    lappend includedir [::practcl::file_relative $path [file normalize [file join $TKSRCDIR generic]]]
    lappend includedir [::practcl::file_relative $path [file normalize [file join $TKSRCDIR ttk]]]
    lappend includedir [::practcl::file_relative $path [file normalize [file join $TKSRCDIR xlib]]]
    lappend includedir [::practcl::file_relative $path [file normalize $TKSRCDIR]]
  }

  foreach include [$PROJECT toolset-include-directory] {
    set cpath [::practcl::file_relative $path [file normalize $include]]
    if {$cpath ni $includedir} {
      lappend includedir $cpath
    }
  }

  set INCLUDES  "-I[join $includedir " -I"]"
  if {$debug} {
      set COMPILE "$TCL(cc) $TCL(shlib_cflags) $TCL(cflags_debug) -ggdb \
$TCL(cflags_warning) $TCL(extra_cflags)"
  } else {
      set COMPILE "$TCL(cc) $TCL(shlib_cflags) $TCL(cflags_optimize) \
$TCL(cflags_warning) $TCL(extra_cflags)"
  }
  append COMPILE " " $defs
  lappend OBJECTS {*}[my build-compile-sources $PROJECT $COMPILE $COMPILE $INCLUDES]

  set TCLSRC [file normalize $TCLSRCDIR]

  if {[${PROJECT} define get TEACUP_OS] eq "windows"} {
    set windres [$PROJECT define get RC windres]
    set RSOBJ [file join $path objs tclkit.res.o]
    set RCSRC [${PROJECT} define get kit_resource_file]
    set RCMAN [${PROJECT} define get kit_manifest_file]
    set RCICO [${PROJECT} define get kit_icon_file]

    set cmd [list $windres -o $RSOBJ -DSTATIC_BUILD --include [::practcl::file_relative $path [file join $TCLSRC generic]]]
    if {[$PROJECT define get static_tk]} {
      if {$RCSRC eq {} || ![file exists $RCSRC]} {
        set RCSRC [file join $TKSRCDIR win rc wish.rc]
      }
      if {$RCMAN eq {} || ![file exists $RCMAN]} {
        set RCMAN [file join [$TKOBJ define get builddir] wish.exe.manifest]
      }
      if {$RCICO eq {} || ![file exists $RCICO]} {
        set RCICO [file join $TKSRCDIR win rc wish.ico]
      }
      set TKSRC [file normalize $TKSRCDIR]
      lappend cmd --include [::practcl::file_relative $path [file join $TKSRC generic]] \
        --include [::practcl::file_relative $path [file join $TKSRC win]] \
        --include [::practcl::file_relative $path [file join $TKSRC win rc]]
    } else {
      if {$RCSRC eq {} || ![file exists $RCSRC]} {
        set RCSRC [file join $TCLSRCDIR win tclsh.rc]
      }
      if {$RCMAN eq {} || ![file exists $RCMAN]} {
        set RCMAN [file join [$TCLOBJ define get builddir] tclsh.exe.manifest]
      }
      if {$RCICO eq {} || ![file exists $RCICO]} {
        set RCICO [file join $TCLSRCDIR win tclsh.ico]
      }
    }
    foreach item [${PROJECT} define get resource_include] {
      lappend cmd --include [::practcl::file_relative $path [file normalize $item]]
    }
    lappend cmd [file tail $RCSRC]
    if {![file exists [file join $path [file tail $RCSRC]]]} {
      file copy -force $RCSRC [file join $path [file tail $RCSRC]]
    }
    if {![file exists [file join $path [file tail $RCMAN]]]} {
      file copy -force $RCMAN [file join $path [file tail $RCMAN]]
    }
    if {![file exists [file join $path [file tail $RCICO]]]} {
      file copy -force $RCICO [file join $path [file tail $RCICO]]
    }
    ::practcl::doexec {*}$cmd
    lappend OBJECTS $RSOBJ
  }
  puts "***"
  set cmd "$TCL(cc)"
  if {$debug} {
   append cmd " $TCL(cflags_debug)"
  } else {
   append cmd " $TCL(cflags_optimize)"
  }
  append cmd " $TCL(ld_flags)"
  if {$debug} {
   append cmd " $TCL(ldflags_debug)"
  } else {
   append cmd " $TCL(ldflags_optimize)"
  }

  append cmd " $OBJECTS"
  append cmd " $EXTERN_OBJS"
  if {$debug && $os eq "windows"} {
    ###
    # There is bug in the core's autoconf and the value for
    # tcl_build_lib_spec does not have the 'g' suffix
    ###
    append cmd " -L[file dirname $TCL(build_stub_lib_path)] -ltcl86g"
    if {[$PROJECT define get static_tk]} {
      append cmd " -L[file dirname $TK(build_stub_lib_path)] -ltk86g"
    }
  } else {
    append cmd " $TCL(build_lib_spec)"
    if {[$PROJECT define get static_tk]} {
      append cmd  " $TK(build_lib_spec)"
    }
  }
  foreach obj $PKG_OBJS {
    append cmd " [$obj linker-products $config($obj)]"
  }
  set LIBS {}
  foreach item $TCL(libs) {
    if {[string range $item 0 1] eq "-l" && $item in $LIBS } continue
    lappend LIBS $item
  }
  if {[$PROJECT define get static_tk]} {
    foreach item $TK(libs) {
      if {[string range $item 0 1] eq "-l" && $item in $LIBS } continue
      lappend LIBS $item
    }
  }
  if {[info exists TCL(extra_libs)]} {
    foreach item $TCL(extra_libs) {
      if {[string range $item 0 1] eq "-l" && $item in $LIBS } continue
      lappend LIBS $item
    }
  }
  foreach obj $PKG_OBJS {
    puts [list Checking $obj for external dependencies]
    foreach item [$obj linker-external $config($obj)] {
      puts [list $obj adds $item]
      if {[string range $item 0 1] eq "-l" && $item in $LIBS } continue
      lappend LIBS $item
    }
  }
  append cmd " ${LIBS}"
  foreach obj $PKG_OBJS {
    puts [list Checking $obj for additional link items]
    foreach item [$obj linker-extra $config($obj)] {
      append cmd $item
    }
  }
  if {$debug && $os eq "windows"} {
    append cmd " -L[file dirname $TCL(build_stub_lib_path)] ${TCL(stub_lib_flag)}"
    if {[$PROJECT define get static_tk]} {
      append cmd " -L[file dirname $TK(build_stub_lib_path)] ${TK(stub_lib_flag)}"
    }
  } else {
    append cmd " $TCL(build_stub_lib_spec)"
    if {[$PROJECT define get static_tk]} {
      append cmd " $TK(build_stub_lib_spec)"
    }
  }
  if {[info exists TCL(cc_search_flags)]} {
    append cmd " $TCL(cc_search_flags)"
  }
  append cmd " -o $outfile "
  if {$os eq "windows"} {
    set LDFLAGS_CONSOLE {-mconsole -pipe -static-libgcc}
    set LDFLAGS_WINDOW  {-mwindows -pipe -static-libgcc}
    append cmd " $LDFLAGS_CONSOLE"
  }
  puts "LINK: $cmd"
  exec {*}[string map [list "\n" " " "  " " "] $cmd] >&@ stdout
}

}
