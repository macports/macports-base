###
# A toplevel project that produces a self-contained executable
###
::clay::define ::practcl::tclkit {
  superclass ::practcl::library

  method build-tclkit_main {PROJECT PKG_OBJS} {
    ###
    # Build static package list
    ###
    set statpkglist {}
    foreach cobj [list {*}${PKG_OBJS} $PROJECT] {
      foreach {pkg info} [$cobj project-static-packages] {
        dict set statpkglist $pkg $info
      }
    }
    foreach {ofile info} [${PROJECT} project-compile-products] {
      if {![dict exists $info object]} continue
      set cobj [dict get $info object]
      foreach {pkg info} [$cobj project-static-packages] {
        dict set statpkglist $pkg $info
      }
    }

    set result {}
    $PROJECT include {<tcl.h>}
    $PROJECT include {"tclInt.h"}
    $PROJECT include {"tclFileSystem.h"}
    $PROJECT include {<assert.h>}
    $PROJECT include {<stdio.h>}
    $PROJECT include {<stdlib.h>}
    $PROJECT include {<string.h>}
    $PROJECT include {<math.h>}

    $PROJECT code header {
#ifndef MODULE_SCOPE
#   define MODULE_SCOPE extern
#endif

/*
** Provide a dummy Tcl_InitStubs if we are using this as a static
** library.
*/
#ifndef USE_TCL_STUBS
# undef  Tcl_InitStubs
# define Tcl_InitStubs(a,b,c) TCL_VERSION
#endif
#define STATIC_BUILD 1
#undef USE_TCL_STUBS

/* Make sure the stubbed variants of those are never used. */
#undef Tcl_ObjSetVar2
#undef Tcl_NewStringObj
#undef Tk_Init
#undef Tk_MainEx
#undef Tk_SafeInit
}

    # Build an area of the file for #define directives and
    # function declarations
    set define {}
    set mainhook   [$PROJECT define get TCL_LOCAL_MAIN_HOOK Tclkit_MainHook]
    set mainfunc   [$PROJECT define get TCL_LOCAL_APPINIT Tclkit_AppInit]
    set mainscript [$PROJECT define get main.tcl main.tcl]
    set vfsroot    [$PROJECT define get vfsroot "[$PROJECT define get ZIPFS_VOLUME]app"]
    set vfs_main "${vfsroot}/${mainscript}"

    set map {}
    foreach var {
      vfsroot mainhook mainfunc vfs_main
    } {
      dict set map %${var}% [set $var]
    }
    set thread_init_script {namespace eval ::starkit {}}
    append thread_init_script \n [list set ::starkit::topdir $vfsroot]
    set preinitscript {
set ::odie(boot_vfs) %vfsroot%
set ::SRCDIR $::odie(boot_vfs)
namespace eval ::starkit {}
set ::starkit::topdir %vfsroot%
if {[file exists [file join %vfsroot% tcl_library init.tcl]]} {
  set ::tcl_library [file join %vfsroot% tcl_library]
  set ::auto_path {}
}
if {[file exists [file join %vfsroot% tk_library tk.tcl]]} {
  set ::tk_library [file join %vfsroot% tk_library]
}
} ; # Preinitscript

    set zvfsboot {
/*
 * %mainhook% --
 * Performs the argument munging for the shell
 */
  }
    ::practcl::cputs zvfsboot {
  CONST char *archive;
  Tcl_FindExecutable(*argv[0]);
  archive=Tcl_GetNameOfExecutable();
}
    # We have to initialize the virtual filesystem before calling
    # Tcl_Init().  Otherwise, Tcl_Init() will not be able to find
    # its startup script files.
    if {![$PROJECT define get tip_430 0]} {
      # Add declarations of functions that tip430 puts in the stub files
      $PROJECT code public-header {
int TclZipfs_Init(Tcl_Interp *interp);
int TclZipfs_Mount(
    Tcl_Interp *interp,
    const char *mntpt,
    const char *zipname,
    const char *passwd
);
int TclZipfs_Mount_Buffer(
    Tcl_Interp *interp,
    const char *mntpt,
    unsigned char *data,
    size_t datalen,
    int copy
);
}
      ::practcl::cputs zvfsboot {  TclZipfs_Init(NULL);}
    }
    ::practcl::cputs zvfsboot "  if(!TclZipfs_Mount(NULL, \"app\", archive, NULL)) \x7B "
    ::practcl::cputs zvfsboot {
      Tcl_Obj *vfsinitscript;
      vfsinitscript=Tcl_NewStringObj("%vfs_main%",-1);
      Tcl_IncrRefCount(vfsinitscript);
      if(Tcl_FSAccess(vfsinitscript,F_OK)==0) {
        /* Startup script should be set before calling Tcl_AppInit */
        Tcl_SetStartupScript(vfsinitscript,NULL);
      }
    }
    ::practcl::cputs zvfsboot "    TclSetPreInitScript([::practcl::tcl_to_c $preinitscript])\;"
    ::practcl::cputs zvfsboot "  \x7D else \x7B"
    ::practcl::cputs zvfsboot "    TclSetPreInitScript([::practcl::tcl_to_c {
foreach path {../tcl} {
  set p  [file join $path library init.tcl]
  if {[file exists [file join $path library init.tcl]]} {
    set ::tcl_library [file normalize [file join $path library]]
    break
  }
}
foreach path {
  ../tk
} {
  if {[file exists [file join $path library tk.tcl]]} {
    set ::tk_library [file normalize [file join $path library]]
    break
  }
}
}])\;"
    ::practcl::cputs zvfsboot "  \x7D"
    ::practcl::cputs zvfsboot "  return TCL_OK;"

    if {[$PROJECT define get TEACUP_OS] eq "windows"} {
      set header {int %mainhook%(int *argc, TCHAR ***argv)}
    } else {
      set header {int %mainhook%(int *argc, char ***argv)}
    }
    $PROJECT c_function  [string map $map $header] [string map $map $zvfsboot]

    practcl::cputs appinit "int %mainfunc%(Tcl_Interp *interp) \x7B"

  # Build AppInit()
  set appinit {}
  practcl::cputs appinit {
  if ((Tcl_Init)(interp) == TCL_ERROR) {
      return TCL_ERROR;
  }

}
    if {![$PROJECT define get tip_430 0]} {
      ::practcl::cputs appinit {  TclZipfs_Init(interp);}
    }
    set main_init_script {}

    foreach {statpkg info} $statpkglist {
      set initfunc {}
      if {[dict exists $info initfunc]} {
        set initfunc [dict get $info initfunc]
      }
      if {$initfunc eq {}} {
        set initfunc [string totitle ${statpkg}]_Init
      }
      if {![dict exists $info version]} {
        error "$statpkg HAS NO VERSION"
      }
      # We employ a NULL to prevent the package system from thinking the
      # package is actually loaded into the interpreter
      $PROJECT code header "extern Tcl_PackageInitProc $initfunc\;\n"
      set script [list package ifneeded $statpkg [dict get $info version] [list ::load {} $statpkg]]
      append main_init_script \n [list set ::starkit::static_packages(${statpkg}) $script]

      if {[dict get $info autoload]} {
        ::practcl::cputs appinit "  if(${initfunc}(interp)) return TCL_ERROR\;"
        ::practcl::cputs appinit "  Tcl_StaticPackage(interp,\"$statpkg\",$initfunc,NULL)\;"
      } else {
        ::practcl::cputs appinit "\n  Tcl_StaticPackage(NULL,\"$statpkg\",$initfunc,NULL)\;"
        append main_init_script \n $script
      }
    }
    append main_init_script \n {
if {[file exists [file join $::starkit::topdir pkgIndex.tcl]]} {
  #In a wrapped exe, we don't go out to the environment
  set dir $::starkit::topdir
  source [file join $::starkit::topdir pkgIndex.tcl]
}}
    append thread_init_script $main_init_script
    append main_init_script \n {
# Specify a user-specific startup file to invoke if the application
# is run interactively.  Typically the startup file is "~/.apprc"
# where "app" is the name of the application.  If this line is deleted
# then no user-specific startup file will be run under any conditions.
}
    append thread_init_script \n [list set ::starkit::thread_init $thread_init_script]
    append main_init_script \n [list set ::starkit::thread_init $thread_init_script]
    append main_init_script \n [list set tcl_rcFileName [$PROJECT define get tcl_rcFileName ~/.tclshrc]]


    practcl::cputs appinit "  Tcl_Eval(interp,[::practcl::tcl_to_c  $thread_init_script]);"
    practcl::cputs appinit {  return TCL_OK;}
    $PROJECT c_function [string map $map "int %mainfunc%(Tcl_Interp *interp)"] [string map $map $appinit]
  }

  method Collate_Source CWD {
    next $CWD
    set name [my define get name]
    # Assume a static shell
    if {[my define exists SHARED_BUILD]} {
      my define set SHARED_BUILD 0
    }
    if {![my define exists TCL_LOCAL_APPINIT]} {
      my define set TCL_LOCAL_APPINIT Tclkit_AppInit
    }
    if {![my define exists TCL_LOCAL_MAIN_HOOK]} {
      my define set TCL_LOCAL_MAIN_HOOK Tclkit_MainHook
    }
    set PROJECT [self]
    set os [$PROJECT define get TEACUP_OS]
    if {[my define get SHARED_BUILD 0]} {
      puts [list BUILDING TCLSH FOR OS $os]
    } else {
      puts [list BUILDING KIT FOR OS $os]
    }
    set TCLOBJ [$PROJECT tclcore]
    ::practcl::toolset select $TCLOBJ

    set TCLSRCDIR [$TCLOBJ define get srcdir]
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
    # Arrange to build an main.c that utilizes TCL_LOCAL_APPINIT and TCL_LOCAL_MAIN_HOOK
    if {$os eq "windows"} {
      set PLATFORM_SRC_DIR win
      if {![my define get SHARED_BUILD 0]} {
        my add class csource filename [file join $TCLSRCDIR win tclWinReg.c] initfunc Registry_Init pkg_name registry pkg_vers 1.3.1 autoload 1
        my add class csource filename [file join $TCLSRCDIR win tclWinDde.c] initfunc Dde_Init pkg_name dde pkg_vers 1.4.0 autoload 1
      }
      my add class csource ofile [my define get name]_appinit.o filename [file join $TCLSRCDIR win tclAppInit.c] extra [list -DTCL_LOCAL_MAIN_HOOK=[my define get TCL_LOCAL_MAIN_HOOK Tclkit_MainHook] -DTCL_LOCAL_APPINIT=[my define get TCL_LOCAL_APPINIT Tclkit_AppInit]]
    } else {
      set PLATFORM_SRC_DIR unix
      my add class csource ofile [my define get name]_appinit.o filename [file join $TCLSRCDIR unix tclAppInit.c] extra [list -DTCL_LOCAL_MAIN_HOOK=[my define get TCL_LOCAL_MAIN_HOOK Tclkit_MainHook] -DTCL_LOCAL_APPINIT=[my define get TCL_LOCAL_APPINIT Tclkit_AppInit]]
    }

    if {![my define get SHARED_BUILD 0]} {
      ###
      # Add local static Zlib implementation
      ###
      set cdir [file join $TCLSRCDIR compat zlib]
      foreach file {
        adler32.c compress.c crc32.c
        deflate.c infback.c inffast.c
        inflate.c inftrees.c trees.c
        uncompr.c zutil.c
      } {
        my add [file join $cdir $file]
      }
    }
    ###
    # Pre 8.7, Tcl doesn't include a Zipfs implementation
    # in the core. Grab the one from odielib
    ###
    set zipfs [file join $TCLSRCDIR generic tclZipfs.c]
    if {![$PROJECT define exists ZIPFS_VOLUME]} {
      $PROJECT define set ZIPFS_VOLUME "zipfs:/"
    }
    $PROJECT code header "#define ZIPFS_VOLUME \"[$PROJECT define get ZIPFS_VOLUME]\""
    if {[file exists $zipfs]} {
      $TCLOBJ define set tip_430 1
      my define set tip_430 1
    } else {
      # The Tclconfig project maintains a mirror of the version
      # released with the Tcl core
      my define set tip_430 0
      set tclzipfs_c [my define get tclzipfs_c]
      if {![file exists $tclzipfs_c]} {
        ::practcl::LOCAL tool tclconfig unpack
        set COMPATSRCROOT [::practcl::LOCAL tool tclconfig define get srcdir]
        set tclzipfs_c [file join $COMPATSRCROOT compat tclZipfs.c]
      }
      my add class csource ofile tclZipfs.o filename $tclzipfs_c \
        extra -I[::practcl::file_relative $CWD [file join $TCLSRCDIR compat zlib contrib minizip]]
    }

    my define add include_dir [file join $TCLSRCDIR generic]
    my define add include_dir [file join $TCLSRCDIR $PLATFORM_SRC_DIR]
    # This file will implement TCL_LOCAL_APPINIT and TCL_LOCAL_MAIN_HOOK
    my build-tclkit_main $PROJECT $PKG_OBJS
  }

  ## Wrap an executable
  #
  method wrap {PWD exename vfspath args} {
    cd $PWD
    if {![file exists $vfspath]} {
      file mkdir $vfspath
    }
    foreach item [my link list core.library] {
      set name  [$item define get name]
      set libsrcdir [$item define get srcdir]
      if {[file exists [file join $libsrcdir library]]} {
        ::practcl::copyDir [file join $libsrcdir library] [file join $vfspath ${name}_library]
      }
    }
    # Assume the user will populate the VFS path
    #if {[my define get installdir] ne {}} {
    #  ::practcl::copyDir [file join [my define get installdir] [string trimleft [my define get prefix] /] lib] [file join $vfspath lib]
    #}
    foreach arg $args {
       ::practcl::copyDir $arg $vfspath
    }

    set fout [open [file join $vfspath pkgIndex.tcl] w]
    puts $fout [string map [list %platform% [my define get TEACUP_PROFILE]] {set ::tcl_teapot_profile {%platform%}}]
    puts $fout {
namespace eval ::starkit {}
set ::PKGIDXFILE [info script]
set dir [file dirname $::PKGIDXFILE]
if {$::tcl_platform(platform) eq "windows"} {
  set ::starkit::localHome [file join [file normalize $::env(LOCALAPPDATA)] tcl]
} else {
  set ::starkit::localHome [file normalize ~/tcl]
}
set ::tcl_teapot [file join $::starkit::localHome teapot $::tcl_teapot_profile]
lappend ::auto_path $::tcl_teapot
}
    puts $fout [list proc installDir [info args ::practcl::installDir] [info body ::practcl::installDir]]
    set buffer [::practcl::pkgindex_path $vfspath]
    puts $fout $buffer
    puts $fout {
# Advertise statically linked packages
foreach {pkg script} [array get ::starkit::static_packages] {
  eval $script
}
}
    puts $fout {
###
# Cache binary packages distributed as dynamic libraries in a known location
###
foreach teapath [glob -nocomplain [file join $dir teapot $::tcl_teapot_profile *]] {
  set pkg [file tail $teapath]
  set pkginstall [file join $::tcl_teapot $pkg]
  if {![file exists $pkginstall]} {
    installDir $teapath $pkginstall
  }
}
}
    close $fout

    set EXEEXT [my define get EXEEXT]
    set tclkit_bare [my define get tclkit_bare]
    ::practcl::mkzip ${exename}${EXEEXT} $tclkit_bare $vfspath
    if { [my define get TEACUP_OS] ne "windows" } {
      file attributes ${exename}${EXEEXT} -permissions a+x
    }
  }
}
