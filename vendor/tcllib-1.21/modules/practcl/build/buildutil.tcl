###
# Build utility functions
###

###
# Generate a proc if no command already exists by that name
###
proc Proc {name arglist body} {
  if {[info command $name] ne {}} return
  proc $name $arglist $body
}

###
# A command to do nothing. A handy way of
# negating an instruction without
# having to comment it completely out.
# It's also a handy attachment point for
# an object to be named later
###
Proc ::noop args {}

proc ::practcl::debug args {
  #puts $args
  ::practcl::cputs ::DEBUG_INFO $args
}

###
# Drop in a static copy of Tcl
###
proc ::practcl::doexec args {
  puts [list {*}$args]
  exec {*}$args >&@ stdout
}

proc ::practcl::doexec_in {path args} {
  set PWD [pwd]
  cd $path
  puts [list {*}$args]
  exec {*}$args >&@ stdout
  cd $PWD
}

proc ::practcl::dotclexec args {
  puts [list [info nameofexecutable] {*}$args]
  exec [info nameofexecutable] {*}$args >&@ stdout
}

proc ::practcl::domake {path args} {
  set PWD [pwd]
  cd $path
  puts [list *** $path ***]
  puts [list make {*}$args]
  exec make {*}$args >&@ stdout
  cd $PWD
}

proc ::practcl::domake.tcl {path args} {
  set PWD [pwd]
  cd $path
  puts [list *** $path ***]
  puts [list make.tcl {*}$args]
  exec [info nameofexecutable] make.tcl {*}$args >&@ stdout
  cd $PWD
}

proc ::practcl::fossil {path args} {
  set PWD [pwd]
  cd $path
  puts [list {*}$args]
  exec fossil {*}$args >&@ stdout
  cd $PWD
}


proc ::practcl::fossil_status {dir} {
  if {[info exists ::fosdat($dir)]} {
    return $::fosdat($dir)
  }
  set result {
tags experimental
version {}
  }
  set pwd [pwd]
  cd $dir
  set info [exec fossil status]
  cd $pwd
  foreach line [split $info \n] {
    if {[lindex $line 0] eq "checkout:"} {
      set hash [lindex $line end-3]
      set maxdate [lrange $line end-2 end-1]
      dict set result hash $hash
      dict set result maxdate $maxdate
      regsub -all {[^0-9]} $maxdate {} isodate
      dict set result isodate $isodate
    }
    if {[lindex $line 0] eq "tags:"} {
      set tags [lrange $line 1 end]
      dict set result tags $tags
      break
    }
  }
  set ::fosdat($dir) $result
  return $result
}

proc ::practcl::os {} {
  return [${::practcl::MAIN} define get TEACUP_OS]
}

###
# Build a zipfile. On tcl8.6 this invokes the native Zip implementation
# on older interpreters this invokes zip via exec
###
proc ::practcl::mkzip {exename barekit vfspath} {
  ::practcl::tcllib_require zipfile::mkzip
  ::zipfile::mkzip::mkzip $exename -runtime $barekit -directory $vfspath
}
###
# Dictionary sort a key/value list. Needed because pre tcl8.6
# does not have [emph {lsort -stride 2}]
###
proc ::practcl::sort_dict list {
  return [::lsort -stride 2 -dictionary $list]
}
if {[::package vcompare $::tcl_version 8.6] < 0} {
  # Approximate ::zipfile::mkzip with exec calls
  proc ::practcl::mkzip {exename barekit vfspath} {
    set path [file dirname [file normalize $exename]]
    set zipfile [file join $path [file rootname $exename].zip]
    file copy -force $barekit $exename
    set pwd [pwd]
    cd $vfspath
    exec zip -r $zipfile .
    cd $pwd
    set fout [open $exename a]
    set fin [open $zipfile r]
    chan configure $fout -translation binary
    chan configure $fin -translation binary
    chan copy $fin $fout
    chan close $fin
    chan close $fout
    exec zip -A $exename
  }
  proc ::practcl::sort_dict list {
    set result {}
    foreach key [lsort -dictionary [dict keys $list]] {
      dict set result $key [dict get $list $key]
    }
    return $result
  }
}


###
# Returns a dictionary describing the local operating system.
# Fields return include:
# [list_begin itemized]
# [item] download - Filesystem path where fossil repositories and source tarballs are downloaded for the current user
# [item] EXEEXT - The extension to give to executables. (i.e. .exe on windows)
# [item] fossil_mirror - A URI for a local network web server who acts as a fossil repository mirror
# [item] local_install - Filesystem path where packages for local consumption by the current user are installed
# [item] prefix - The prefix as given to the Tcl core/TEA for installation to local_install in ./configure
# [item] sandbox - The file location where this project unpacks external projects
# [item] TEACUP_PROFILE - The ActiveState/Teacup canonical name for this platform (i.e. win32-ix86 macosx10.5-i386-x86_84)
# [item] TEACUP_OS - The local operating system (windows, macosx, openbsd, etc). Gives the same answer as tcl.m4, except that macosx is given as macosx instead of Darwin.
# [item] TEA_PLATFORM - The platform returned by uname -s-uname -r (on Unix), or "windows" on Windows
# [item] TEACUP_ARCH - The processor architecture for the local os (i.e. ix86, x86_64)
# [item] TEACUP_ARCH - The processor architecture for the local os (i.e. ix86, x86_64)
# [item] teapot - Filesystem path where teapot package files are downloaded for the current user
# [item] userhome - File path to store localized preferences, cache download files, etc for the current user
# [list_end]
# This command uses a combination of local checks with Exec, any tclConfig.sh file that is
# resident, autoconf data where already computed, and data gleaned from a file named
# practcl.rc in userhome. The location for userhome varies by platform and operating system:
# [list_begin itemized]
# [item] Windows: ::env(LOCALAPPDATA)/Tcl
# [item] Macos: ~/Library/Application Support/Tcl
# [item] Other: ~/tcl
# [list_end]
###
proc ::practcl::local_os {} {
  # If we have already run this command, return
  # a cached copy of the data
  if {[info exists ::practcl::LOCAL_INFO]} {
    return $::practcl::LOCAL_INFO
  }
  set result [array get ::practcl::CONFIG]
  dict set result TEACUP_PROFILE unknown
  dict set result TEACUP_OS unknown
  dict set result EXEEXT {}
  set windows 0
  if {$::tcl_platform(platform) eq "windows"} {
    set windows 1
  }
  if {$windows} {
    set system "windows"
    set arch ix86
    dict set result TEACUP_PROFILE win32-ix86
    dict set result TEACUP_OS windows
    dict set result EXEEXT .exe
  } else {
    set system [exec uname -s]-[exec uname -r]
    set arch unknown
    dict set result TEACUP_OS generic
  }
  dict set result TEA_PLATFORM $system
  dict set result TEA_SYSTEM $system
  if {[info exists ::SANDBOX]} {
    dict set result sandbox $::SANDBOX
  }
  switch -glob $system {
    Linux* {
      dict set result TEACUP_OS linux
      set arch [exec uname -m]
      dict set result TEACUP_PROFILE "linux-glibc2.3-$arch"
    }
    GNU* {
      set arch [exec uname -m]
      dict set result TEACUP_OS "gnu"
    }
    NetBSD-Debian {
      set arch [exec uname -m]
      dict set result TEACUP_OS "netbsd-debian"
    }
    OpenBSD-* {
      set arch [exec arch -s]
      dict set result TEACUP_OS "openbsd"
    }
    Darwin* {
      set arch [exec uname -m]
      dict set result TEACUP_OS "macosx"
      if {$arch eq "x86_64"} {
        dict set result TEACUP_PROFILE "macosx10.5-i386-x86_84"
      } else {
        dict set result TEACUP_PROFILE "macosx-universal"
      }
    }
    OpenBSD* {
      set arch [exec arch -s]
      dict set result TEACUP_OS "openbsd"
    }
  }
  if {$arch eq "unknown"} {
    catch {set arch [exec uname -m]}
  }
  switch -glob $arch {
    i*86 {
      set arch "ix86"
    }
    amd64 {
      set arch "x86_64"
    }
  }
  dict set result TEACUP_ARCH $arch
  if {[dict get $result TEACUP_PROFILE] eq "unknown"} {
    dict set result TEACUP_PROFILE [dict get $result TEACUP_OS]-$arch
  }
  set OS [dict get $result TEACUP_OS]
  dict set result os $OS

  # Look for a local preference file
  set pathlist {}
  set userhome [file normalize ~/tcl]
  set local_install [file join $userhome lib]
  switch $OS {
    windows {
      set userhome [file join [file normalize $::env(LOCALAPPDATA)] Tcl]
      if {[file exists c:/Tcl/Teapot]} {
        dict set result teapot c:/Tcl/Teapot
      }
    }
    macosx {
      set userhome [file join [file normalize {~/Library/Application Support/}] Tcl]
      if {[file exists {~/Library/Application Support/ActiveState/Teapot/repository/}]} {
        dict set result teapot [file normalize {~/Library/Application Support/ActiveState/Teapot/repository/}]
      }
      dict set result local_install [file normalize ~/Library/Tcl]
      if {![dict exists $result sandbox]} {
        dict set result sandbox       [file normalize ~/Library/Tcl/sandbox]
      }
    }
    default {
    }
  }
  dict set result userhome $userhome
  # Load user preferences
  if {[file exists [file join $userhome practcl.rc]]} {
    set dat [::practcl::read_rc_file [file join $userhome practcl.rc]]
    foreach {f v} $dat {
      dict set result $f $v
    }
  }
  if {![dict exists $result prefix]} {
    dict set result prefix   $userhome
  }

  # Create a default path for the teapot
  if {![dict exists $result teapot]} {
    dict set result teapot [file join $userhome teapot]
  }
  # Create a default path for the local sandbox
  if {![dict exists $result sandbox]} {
    dict set result sandbox [file join $userhome sandbox]
  }
  # Create a default path for download folder
  if {![dict exists $result download]} {
    dict set result download [file join $userhome download]
  }
  # Path to install local packages
  if {![dict exists $result local_install]} {
    dict set result local_install [file join $userhome lib]
  }
  if {![dict exists result fossil_mirror] && [::info exists ::env(FOSSIL_MIRROR)]} {
    dict set result fossil_mirror $::env(FOSSIL_MIRROR)
  }

  set ::practcl::LOCAL_INFO $result
  return $result
}


###
# A transparent call to ::practcl::read_configuration to preserve backward compadibility
# with older copies of Practcl
###
proc ::practcl::config.tcl {path} {
   return [read_configuration $path]
}

###
# Detect local platform. This command looks for data gleaned by autoconf or autosetup
# in the path specified, or perform its own logic tests if neither has been run.
# A file named config.site present in the location indicates that this project is
# cross compiling, and the data stored in that file is used for the compiler and linker.
# [para]
# This command looks for information from the following files, in the following order:
# [list_begin itemized]
# [item] config.tcl - A file generated by autoconf/configure in newer editions of TEA, encoded as a Tcl script.
# [item] config.site - A file containing cross compiler information, encoded as a SH script
# [item] ::env(VisualStudioVersion) - On Windows, and environmental value that indicates MS Visual Studio is installed
# [list_end]
# [para]
# This command returns a dictionary containing all of the data cleaned from the sources above.
# In the absence of any guidance this command returns the same output as ::practcl::local_os.
# In this mode, if the environmental variable VisualStudioVersion exists, this command
# will provide a template of fields that are appropriate for compiling on Windows under
# Microsoft Visual Studio. The USEMSVC flag in the dictionary is a boolean flag to indicate
# if this is indeed the case.
###
proc ::practcl::read_configuration {path} {
  dict set result buildpath $path
  set result [local_os]
  set OS [dict get $result TEACUP_OS]
  set windows 0
  dict set result USEMSVC 0
  if {[file exists [file join $path config.tcl]]} {
    # We have a definitive configuration file. Read its content
    # and take it as gospel
    set cresult [read_rc_file [file join $path config.tcl]]
    set cresult [::practcl::de_shell $cresult]
    if {[dict exists $cresult srcdir] && ![dict exists $cresult sandbox]} {
      dict set cresult sandbox  [file dirname [dict get $cresult srcdir]]
    }
    set result [dict merge $result [::practcl::de_shell $cresult]]
  }
  if {[file exists [file join $path config.site]]} {
    # No config.tcl file is present but we do seed
    dict set result USEMSVC 0
    foreach {f v} [::practcl::de_shell [::practcl::read_sh_file [file join $path config.site]]] {
      dict set result $f $v
      dict set result XCOMPILE_${f} $v
    }
    dict set result CONFIG_SITE [file join $path config.site]
    if {[dict exist $result XCOMPILE_CC] && [regexp mingw [dict get $result XCOMPILE_CC]]} {
      set windows 1
    }
  } elseif {[info exists ::env(VisualStudioVersion)]} {
    set windows 1
    dict set result USEMSVC 1
  }
  if {$windows && [dict get $result TEACUP_OS] ne "windows"} {
    if {![dict exists exists $result TEACUP_ARCH]} {
      dict set result TEACUP_ARCH ix86
    }
    dict set result TEACUP_PROFILE win32-[dict get $result TEACUP_ARCH]
    dict set result TEACUP_OS windows
    dict set result EXEEXT .exe
  }
  return $result
}


###
# Convert an MSYS path to a windows native path
###
if {$::tcl_platform(platform) eq "windows"} {
proc ::practcl::msys_to_tclpath msyspath {
  return [exec sh -c "cd $msyspath ; pwd -W"]
}
proc ::practcl::tcl_to_myspath tclpath {
  set path [file normalize $tclpath]
  return "/[string index $path 0][string range $path 2 end]"
  #return [exec sh -c "cd $tclpath ; pwd"]
}
} else {
proc ::practcl::msys_to_tclpath msyspath {
  return [file normalize $msyspath]
}
proc ::practcl::tcl_to_myspath msyspath {
  return [file normalize $msyspath]
}
}


# Try to load  a package, and failing that
# retrieve tcllib
proc ::practcl::tcllib_require {pkg args} {
  # Try to load the package from the local environment
  if {[catch [list ::package require $pkg {*}$args] err]==0} {
    return $err
  }
  ::practcl::LOCAL tool tcllib env-load
  uplevel #0 [list ::package require $pkg {*}$args]
}

namespace eval ::practcl::platform {}

###
# Return the string to pass to ./configure to compile the Tcl core for the given OS.
# [list_begin itemized]
# [item] windows: --with-tzdata --with-encoding utf-8
# [item] macosx: --enable-corefoundation=yes  --enable-framework=no --with-tzdata --with-encoding utf-8
# [item] other: --with-tzdata --with-encoding utf-8
# [list_end]
###
proc ::practcl::platform::tcl_core_options {os} {
  ###
  # Download our required packages
  ###
  set tcl_config_opts {}
  # Auto-guess options for the local operating system
  switch $os {
    windows {
      #lappend tcl_config_opts --disable-stubs
    }
    linux {
    }
    macosx {
      lappend tcl_config_opts --enable-corefoundation=yes  --enable-framework=no
    }
  }
  lappend tcl_config_opts --with-tzdata --with-encoding utf-8
  return $tcl_config_opts
}

proc ::practcl::platform::tk_core_options {os} {
  ###
  # Download our required packages
  ###
  set tk_config_opts {}

  # Auto-guess options for the local operating system
  switch $os {
    windows {
    }
    linux {
      lappend tk_config_opts --enable-xft=no --enable-xss=no
    }
    macosx {
      lappend tk_config_opts --enable-aqua=yes
    }
  }
  return $tk_config_opts
}

###
# Read a stylized key/value list stored in a file
###
proc ::practcl::read_rc_file {filename {localdat {}}} {
  set result $localdat
  set fin [open $filename r]
  set bufline {}
  set rawcount 0
  set linecount 0
  while {[gets $fin thisline]>=0} {
    incr rawcount
    append bufline \n $thisline
    if {![info complete $bufline]} continue
    set line [string trimleft $bufline]
    set bufline {}
    if {[string index [string trimleft $line] 0] eq "#"} continue
    append result \n $line
    #incr linecount
    #set key [lindex $line 0]
    #set value [lindex $line 1]
    #dict set result $key $value
  }
  close $fin
  return $result
}

###
# topic: e71f3f61c348d56292011eec83e95f0aacc1c618
# description: Converts a XXX.sh file into a series of Tcl variables
###
proc ::practcl::read_sh_subst {line info} {
  regsub -all {\x28} $line \x7B line
  regsub -all {\x29} $line \x7D line

  #set line [string map $key [string trim $line]]
  foreach {field value} $info {
    catch {set $field $value}
  }
  if [catch {subst $line} result] {
    return {}
  }
  set result [string trim $result]
  return [string trim $result ']
}

###
# topic: 03567140cca33c814664c7439570f669b9ab88e6
###
proc ::practcl::read_sh_file {filename {localdat {}}} {
  set fin [open $filename r]
  set result {}
  if {$localdat eq {}} {
    set top 1
    set local [array get ::env]
    dict set local EXE {}
  } else {
    set top 0
    set local $localdat
  }
  while {[gets $fin line] >= 0} {
    set line [string trim $line]
    if {[string index $line 0] eq "#"} continue
    if {$line eq {}} continue
    catch {
    if {[string range $line 0 6] eq "export "} {
      set eq [string first "=" $line]
      set field [string trim [string range $line 6 [expr {$eq - 1}]]]
      set value [read_sh_subst [string range $line [expr {$eq+1}] end] $local]
      dict set result $field [read_sh_subst $value $local]
      dict set local $field $value
    } elseif {[string range $line 0 7] eq "include "} {
      set subfile [read_sh_subst [string range $line 7 end] $local]
      foreach {field value} [read_sh_file $subfile $local] {
        dict set result $field $value
      }
    } else {
      set eq [string first "=" $line]
      if {$eq > 0} {
        set field [read_sh_subst [string range $line 0 [expr {$eq - 1}]] $local]
        set value [string trim [string range $line [expr {$eq+1}] end] ']
        #set value [read_sh_subst [string range $line [expr {$eq+1}] end] $local]
        dict set local $field $value
        dict set result $field $value
      }
    }
    } err opts
    if {[dict get $opts -code] != 0} {
      #puts $opts
      puts "Error reading line:\n$line\nerr: $err\n***"
      return $err {*}$opts
    }
  }
  return $result
}

###
# A simpler form of read_sh_file tailored
# to pulling data from (tcl|tk)Config.sh
###
proc ::practcl::read_Config.sh filename {
  set fin [open $filename r]
  set result {}
  set linecount 0
  while {[gets $fin line] >= 0} {
    set line [string trim $line]
    if {[string index $line 0] eq "#"} continue
    if {$line eq {}} continue
    catch {
      set eq [string first "=" $line]
      if {$eq > 0} {
        set field [string range $line 0 [expr {$eq - 1}]]
        set value [string trim [string range $line [expr {$eq+1}] end] ']
        #set value [read_sh_subst [string range $line [expr {$eq+1}] end] $local]
        dict set result $field $value
        incr $linecount
      }
    } err opts
    if {[dict get $opts -code] != 0} {
      #puts $opts
      puts "Error reading line:\n$line\nerr: $err\n***"
      return $err {*}$opts
    }
  }
  return $result
}

###
# A simpler form of read_sh_file tailored
# to pulling data from a Makefile
###
proc ::practcl::read_Makefile filename {
  set fin [open $filename r]
  set result {}
  while {[gets $fin line] >= 0} {
    set line [string trim $line]
    if {[string index $line 0] eq "#"} continue
    if {$line eq {}} continue
    catch {
      set eq [string first "=" $line]
      if {$eq > 0} {
        set field [string trim [string range $line 0 [expr {$eq - 1}]]]
        set value [string trim [string trim [string range $line [expr {$eq+1}] end] ']]
        switch $field {
          PKG_LIB_FILE {
            dict set result libfile $value
          }
          srcdir {
            if {$value eq "."} {
              dict set result srcdir [file dirname $filename]
            } else {
              dict set result srcdir $value
            }
          }
          PACKAGE_NAME {
            dict set result name $value
          }
          PACKAGE_VERSION {
            dict set result version $value
          }
          LIBS {
            dict set result PRACTCL_LIBS $value
          }
          PKG_LIB_FILE {
            dict set result libfile $value
          }
        }
      }
    } err opts
    if {[dict get $opts -code] != 0} {
      #puts $opts
      puts "Error reading line:\n$line\nerr: $err\n***"
      return $err {*}$opts
    }
    # the Compile field is about where most TEA files start getting silly
    if {$field eq "compile"} {
      break
    }
  }
  return $result
}

## Append arguments to a buffer
# The command works like puts in that each call will also insert
# a line feed. Unlike puts, blank links in the interstitial are
# suppressed
proc ::practcl::cputs {varname args} {
  upvar 1 $varname buffer
  if {[llength $args]==1 && [string length [string trim [lindex $args 0]]] == 0} {

  }
  if {[info exist buffer]} {
    if {[string index $buffer end] ne "\n"} {
      append buffer \n
    }
  } else {
    set buffer \n
  }
  # Trim leading \n's
  append buffer [string trimleft [lindex $args 0] \n] {*}[lrange $args 1 end]
}

proc ::practcl::tcl_to_c {body} {
  set result {}
  foreach rawline [split $body \n] {
    set line [string map [list \" \\\" \\ \\\\] $rawline]
    cputs result "\n        \"$line\\n\" \\"
  }
  return [string trimright $result \\]
}


proc ::practcl::_tagblock {text {style tcl} {note {}}} {
  if {[string length [string trim $text]]==0} {
    return {}
  }
  set output {}
  switch $style {
    tcl {
      ::practcl::cputs output "# BEGIN $note"
    }
    c {
      ::practcl::cputs output "/* BEGIN $note */"
    }
    default {
      ::practcl::cputs output "# BEGIN $note"
    }
  }
  ::practcl::cputs output $text
  switch $style {
    tcl {
      ::practcl::cputs output "# END $note"
    }
    c {
      ::practcl::cputs output "/* END $note */"
    }
    default {
      ::practcl::cputs output "# END $note"
    }
  }
  return $output
}

proc ::practcl::de_shell {data} {
  set values {}
  foreach flag {DEFS TCL_DEFS TK_DEFS} {
    if {[dict exists $data $flag]} {
      #set value {}
      #foreach item [dict get $data $flag] {
      #  append value " " [string map {{ } {\ }} $item]
      #}
      dict set values $flag [dict get $data $flag]
    }
  }
  set map {}
  lappend map {${PKG_OBJECTS}} %LIBRARY_OBJECTS%
  lappend map {$(PKG_OBJECTS)} %LIBRARY_OBJECTS%
  lappend map {${PKG_STUB_OBJECTS}} %LIBRARY_STUB_OBJECTS%
  lappend map {$(PKG_STUB_OBJECTS)} %LIBRARY_STUB_OBJECTS%

  if {[dict exists $data name]} {
    lappend map %LIBRARY_NAME% [dict get $data name]
    lappend map %LIBRARY_VERSION% [dict get $data version]
    lappend map %LIBRARY_VERSION_NODOTS% [string map {. {}} [dict get $data version]]
    if {[dict exists $data libprefix]} {
      lappend map %LIBRARY_PREFIX% [dict get $data libprefix]
    } else {
      lappend map %LIBRARY_PREFIX% [dict get $data prefix]
    }
  }
  foreach flag [dict keys $data] {
    if {$flag in {TCL_DEFS TK_DEFS DEFS}} continue
    set value [string trim [dict get $data $flag] \"]
    dict set map "\$\{${flag}\}" $value
    dict set map "\$\(${flag}\)" $value
    #dict set map "\$${flag}" $value
    dict set map "%${flag}%" $value
    dict set values $flag [dict get $data $flag]
    #dict set map "\$\{${flag}\}" $proj($flag)
  }
  set changed 1
  while {$changed} {
    set changed 0
    foreach {field value} $values {
      if {$field in {TCL_DEFS TK_DEFS DEFS}} continue
      dict with values {}
      set newval [string map $map $value]
      if {$newval eq $value} continue
      set changed 1
      dict set values $field $newval
    }
  }
  return $values
}
