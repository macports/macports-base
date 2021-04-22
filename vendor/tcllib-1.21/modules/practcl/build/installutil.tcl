proc ::practcl::_pkgindex_simpleIndex {path} {
set buffer {}
  set pkgidxfile    [file join $path pkgIndex.tcl]
  set modfile       [file join $path [file tail $path].tcl]
  set use_pkgindex  [file exists $pkgidxfile]
  set tclfiles      {}
  set found 0
  set mlist [list pkgIndex.tcl index.tcl [file tail $modfile] version_info.tcl]
  foreach file [glob -nocomplain [file join $path *.tcl]] {
    if {[file tail $file] ni $mlist} {
      #puts [list NONMODFILE $file]
      return {}
    }
  }
  foreach file [glob -nocomplain [file join $path *.tcl]] {
    if { [file tail $file] == "version_info.tcl" } continue
    set fin [open $file r]
    set dat [read $fin]
    close $fin
    if {![regexp "package provide" $dat]} continue
    set fname [file rootname [file tail $file]]
    # Look for a package provide statement
    foreach line [split $dat \n] {
      set line [string trim $line]
      if { [string range $line 0 14] != "package provide" } continue
      set package [lindex $line 2]
      set version [lindex $line 3]
      if {[string index $package 0] in "\$ \[ @"} continue
      if {[string index $version 0] in "\$ \[ @"} continue
      #puts "PKGLINE $line"
      append buffer "package ifneeded $package $version \[list source \[file join %DIR% [file tail $file]\]\]" \n
      break
    }
  }
  return $buffer
}


###
# Return true if the pkgindex file contains
# any statement other than "package ifneeded"
# and/or if any package ifneeded loads a DLL
###
proc ::practcl::_pkgindex_directory {path} {
  set buffer {}
  set pkgidxfile    [file join $path pkgIndex.tcl]
  set modfile       [file join $path [file tail $path].tcl]
  set use_pkgindex  [file exists $pkgidxfile]
  set tclfiles      {}
  if {$use_pkgindex && [file exists $modfile]} {
    set use_pkgindex 0
    set mlist [list pkgIndex.tcl [file tail $modfile]]
    foreach file [glob -nocomplain [file join $path *.tcl]] {
      lappend tclfiles [file tail $file]
      if {[file tail $file] in $mlist} continue
      incr use_pkgindex
    }
  }
  if {!$use_pkgindex} {
    # No pkgIndex file, read the source
    foreach file [glob -nocomplain $path/*.tm] {
      set file [file normalize $file]
      set fname [file rootname [file tail $file]]
      ###
      # We used to be able to ... Assume the package is correct in the filename
      # No hunt for a "package provides"
      ###
      set package [lindex [split $fname -] 0]
      set version [lindex [split $fname -] 1]
      ###
      # Read the file, and override assumptions as needed
      ###
      set fin [open $file r]
      set dat [read $fin]
      close $fin
      # Look for a teapot style Package statement
      foreach line [split $dat \n] {
        set line [string trim $line]
        if { [string range $line 0 9] != "# Package " } continue
        set package [lindex $line 2]
        set version [lindex $line 3]
        break
      }
      # Look for a package provide statement
      foreach line [split $dat \n] {
        set line [string trim $line]
        if { [string range $line 0 14] != "package provide" } continue
        set package [lindex $line 2]
        set version [lindex $line 3]
        break
      }
      if {[string trim $version] ne {}} {
        append buffer "package ifneeded $package $version \[list source \[file join \$dir [file tail $file]\]\]" \n
      }
    }
    foreach file [glob -nocomplain $path/*.tcl] {
      if { [file tail $file] == "version_info.tcl" } continue
      set fin [open $file r]
      set dat [read $fin]
      close $fin
      if {![regexp "package provide" $dat]} continue
      set fname [file rootname [file tail $file]]
      # Look for a package provide statement
      foreach line [split $dat \n] {
        set line [string trim $line]
        if { [string range $line 0 14] != "package provide" } continue
        set package [lindex $line 2]
        set version [lindex $line 3]
        if {[string index $package 0] in "\$ \[ @"} continue
        if {[string index $version 0] in "\$ \[ @"} continue
        append buffer "package ifneeded $package $version \[list source \[file join \$dir [file tail $file]\]\]" \n
        break
      }
    }
    return $buffer
  }
  set fin [open $pkgidxfile r]
  set dat [read $fin]
  close $fin
  set trace 0
  #if {[file tail $path] eq "tool"} {
  #  set trace 1
  #}
  set thisline {}
  foreach line [split $dat \n] {
    append thisline $line \n
    if {![info complete $thisline]} continue
    set line [string trim $line]
    if {[string length $line]==0} {
      set thisline {} ; continue
    }
    if {[string index $line 0] eq "#"} {
      set thisline {} ; continue
    }
    if {[regexp "if.*catch.*package.*Tcl.*return" $thisline]} {
      if {$trace} {puts "[file dirname $pkgidxfile] Ignoring $thisline"}
      set thisline {} ; continue
    }
    if {[regexp "if.*package.*vsatisfies.*package.*provide.*return" $thisline]} {
      if {$trace} { puts "[file dirname $pkgidxfile] Ignoring $thisline" }
      set thisline {} ; continue
    }
    if {![regexp "package.*ifneeded" $thisline]} {
      # This package index contains arbitrary code
      # source instead of trying to add it to the master
      # package index
      if {$trace} { puts "[file dirname $pkgidxfile] Arbitrary code $thisline" }
      return {source [file join $dir pkgIndex.tcl]}
    }
    append buffer $thisline \n
    set thisline {}
  }
  if {$trace} {puts [list [file dirname $pkgidxfile] $buffer]}
  return $buffer
}

###
# Helper function for ::practcl::pkgindex_path
###
proc ::practcl::_pkgindex_path_subdir {path} {
  set result {}
  if {[file exists [file join $path src build.tcl]]} {
    # Tool style module, don't dive into subdirectories
    return $path
  }
  foreach subpath [glob -nocomplain [file join $path *]] {
    if {[file isdirectory $subpath]} {
      if {[file tail $subpath] eq "build" && [file exists [file join $subpath build.tcl]]} continue
      lappend result $subpath {*}[_pkgindex_path_subdir $subpath]
    }
  }
  return $result
}
###
# Index all paths given as though they will end up in the same
# virtual file system
###
proc ::practcl::pkgindex_path {args} {
  set stack {}
  set buffer {
lappend ::PATHSTACK $dir
set IDXPATH [lindex $::PATHSTACK end]
  }
  set preindexed {}
  foreach base $args {
    set base [file normalize $base]
    set paths {}
    foreach dir [glob -nocomplain [file join $base *]] {
      set thisdir [file tail $dir]
      if {$thisdir eq "teapot"} continue
      if {$thisdir eq "pkgs"} {
        foreach subdir [glob -nocomplain [file join $dir *]] {
          set thissubdir [file tail $subdir]
          set skip 0
          foreach file {pkgIndex.tcl tclIndex} {
            if {[file exists [file join $subdir $file]]} {
              set skip 1
              append buffer "set dir \[file join \$::IDXPATH [list $thisdir] [list $thissubdir]\] \; "
              append buffer "source \[file join \$dir ${file}\]" \n
            }
          }
          if {$skip} continue
          lappend paths {*}[::practcl::_pkgindex_path_subdir $subdir]
        }
        continue
      }
      lappend paths $dir {*}[::practcl::_pkgindex_path_subdir $dir]
    }
    append buffer ""
    set i    [string length  $base]
    # Build a list of all of the paths
    if {[llength $paths]} {
      foreach path $paths {
        if {$path eq $base} continue
        set path_indexed($path) 0
      }
    } else {
      puts [list WARNING: NO PATHS FOUND IN $base]
    }
    set path_indexed($base) 1
    set path_indexed([file join $base boot tcl]) 1
    append buffer \n {# SINGLE FILE MODULES BEGIN} \n {set dir [lindex $::PATHSTACK end]} \n
    foreach path $paths {
      if {$path_indexed($path)} continue
      set thisdir [file_relative $base $path]
      set simpleIdx [_pkgindex_simpleIndex $path]
      if {[string length $simpleIdx]==0} continue
      incr path_indexed($path)
      if {[string length $simpleIdx]} {
        incr path_indexed($path)
        append buffer [string map [list %DIR% "\$dir \{$thisdir\}"] [string trimright $simpleIdx]] \n
      }
    }
    append buffer {# SINGLE FILE MODULES END} \n
    foreach path $paths {
      if {$path_indexed($path)} continue
      set thisdir [file_relative $base $path]
      set idxbuf [::practcl::_pkgindex_directory $path]
      if {[string length $idxbuf]} {
        incr path_indexed($path)
        append buffer "set dir \[set PKGDIR \[file join \[lindex \$::PATHSTACK end\] $thisdir\]\]" \n
        append buffer [string map {$dir $PKGDIR} [string trimright $idxbuf]] \n
      }
    }
  }
  append buffer {
set dir [lindex $::PATHSTACK end]
set ::PATHSTACK [lrange $::PATHSTACK 0 end-1]
}
  return $buffer
}

# Delete the contents of [emph d2], and then
# recusively Ccopy the contents of [emph d1] to [emph d2].
proc ::practcl::installDir {d1 d2} {
  puts [format {%*sCreating %s} [expr {4 * [info level]}] {} [file tail $d2]]
  file delete -force -- $d2
  file mkdir $d2

  foreach ftail [glob -directory $d1 -nocomplain -tails *] {
    set f [file join $d1 $ftail]
    if {[file isdirectory $f] && [string compare CVS $ftail]} {
      installDir $f [file join $d2 $ftail]
    } elseif {[file isfile $f]} {
	    file copy -force $f [file join $d2 $ftail]
	    if {$::tcl_platform(platform) eq {unix}} {
        file attributes [file join $d2 $ftail] -permissions 0644
	    } else {
        file attributes [file join $d2 $ftail] -readonly 1
	    }
    }
  }

  if {$::tcl_platform(platform) eq {unix}} {
    file attributes $d2 -permissions 0755
  } else {
    file attributes $d2 -readonly 1
  }
}

# Recursively copy the contents of [emph d1] to [emph d2]
proc ::practcl::copyDir {d1 d2 {toplevel 1}} {
  #if {$toplevel} {
  #  puts [list ::practcl::copyDir $d1 -> $d2]
  #}
  #file delete -force -- $d2
  file mkdir $d2
  if {[file isfile $d1]} {
    file copy -force $d1 $d2
    set ftail [file tail $d1]
    if {$::tcl_platform(platform) eq {unix}} {
      file attributes [file join $d2 $ftail] -permissions 0644
    } else {
      file attributes [file join $d2 $ftail] -readonly 1
    }
  } else {
    foreach ftail [glob -directory $d1 -nocomplain -tails *] {
      set f [file join $d1 $ftail]
      if {[file isdirectory $f] && [string compare CVS $ftail]} {
        copyDir $f [file join $d2 $ftail] 0
      } elseif {[file isfile $f]} {
        file copy -force $f [file join $d2 $ftail]
        if {$::tcl_platform(platform) eq {unix}} {
          file attributes [file join $d2 $ftail] -permissions 0644
        } else {
          file attributes [file join $d2 $ftail] -readonly 1
        }
      }
    }
  }
}

proc ::practcl::buildModule {modpath} {
  set buildscript [file join $modpath build build.tcl]
  if {![file exists $buildscript]} return
  set pkgIndexFile [file join $modpath pkgIndex.tcl]
  if {[file exists $pkgIndexFile]} {
    set latest 0
    foreach file [::practcl::findByPattern [file dirname $buildscript] *.tcl] {
      set mtime [file mtime $file]
      if {$mtime>$latest} {
        set latest $mtime
      }
    }
    set IdxTime [file mtime $pkgIndexFile]
    if {$latest<$IdxTime} return
  }
  ::practcl::dotclexec $buildscript
}

###
# Install a module from MODPATH to the directory specified.
# [emph dpath] is assumed to be the fully qualified path where module is to be placed.
# Any existing files will be deleted at that path.
# If the path is symlink the process will return with no error and no action.
# If the module has contents in the build/ directory that are newer than the
# .tcl files in the module source directory, and a build/build.tcl file exists,
# the build/build.tcl file is run.
# If the source directory includes a file named index.tcl, the directory is assumed
# to be in the tao style of modules, and the entire directory (and all subdirectories)
# are copied verbatim.
# If no index.tcl file is present, all .tcl files are copied from the module source
# directory, and a pkgIndex.tcl file is generated if non yet exists.
# I a folder named htdocs exists in the source directory, that directory is copied
# verbatim to the destination.
###
proc ::practcl::installModule {modpath DEST} {
  if {[file exists [file join $DEST modules]]} {
    set dpath [file join $DEST modules [file tail $modpath]]
  } else {
    set dpath $DEST
  }
  if {[file exists $dpath] && [file type $dpath] eq "link"} return
  if {[file exists [file join $modpath index.tcl]]} {
    # IRM/Tao style modules non-amalgamated
    ::practcl::installDir $modpath $dpath
    return
  }
  buildModule $modpath
  set files [glob -nocomplain [file join $modpath *.tcl]]
  if {[llength $files]} {
    if {[llength $files]>1} {
      if {![file exists [file join $modpath pkgIndex.tcl]]} {
        pkg_mkIndex $modpath
      }
    }
    file delete -force $dpath
    file mkdir $dpath
    foreach file $files {
      file copy $file $dpath
    }
  }
  if {[file exists [file join $modpath htdocs]]} {
    ::practcl::copyDir [file join $modpath htdocs] [file join $dpath htdocs]
  }
}
