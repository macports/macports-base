###
# Bits stolen from fileutil
###


###
# Search for the pattern [emph pattern] amongst $files
###
proc ::practcl::grep {pattern {files {}}} {
    set result [list]
    if {[llength $files] == 0} {
            # read from stdin
            set lnum 0
            while {[gets stdin line] >= 0} {
                incr lnum
                if {[regexp -- $pattern $line]} {
                        lappend result "${lnum}:${line}"
                }
            }
    } else {
            foreach filename $files {
            set file [open $filename r]
            set lnum 0
            while {[gets $file line] >= 0} {
                incr lnum
                if {[regexp -- $pattern $line]} {
                    lappend result "${filename}:${lnum}:${line}"
                }
            }
            close $file
            }
    }
    return $result
}

proc ::practcl::file_lexnormalize {sp} {
    set spx [file split $sp]

    # Resolution of embedded relative modifiers (., and ..).

    if {
      ([lsearch -exact $spx . ] < 0) &&
      ([lsearch -exact $spx ..] < 0)
    } {
      # Quick path out if there are no relative modifiers
      return $sp
    }

    set absolute [expr {![string equal [file pathtype $sp] relative]}]
    # A volumerelative path counts as absolute for our purposes.

    set sp $spx
    set np {}
    set noskip 1

    while {[llength $sp]} {
      set ele    [lindex $sp 0]
      set sp     [lrange $sp 1 end]
      set islast [expr {[llength $sp] == 0}]

      if {[string equal $ele ".."]} {
          if {
            ($absolute  && ([llength $np] >  1)) ||
            (!$absolute && ([llength $np] >= 1))
          } {
            # .. : Remove the previous element added to the
            # new path, if there actually is enough to remove.
            set np [lrange $np 0 end-1]
          }
      } elseif {[string equal $ele "."]} {
          # Ignore .'s, they stay at the current location
          continue
      } else {
          # A regular element.
          lappend np $ele
      }
    }
    if {[llength $np] > 0} {
      return [eval [linsert $np 0 file join]]
      # 8.5: return [file join {*}$np]
    }
    return {}
}

###
# Calculate a relative path between base and dst
#
# example:
#  ::practcl::file_relative ~/build/tcl/unix ~/build/tcl/library
#  > ../library
###
proc ::practcl::file_relative {base dst} {
    # Ensure that the link to directory 'dst' is properly done relative to
    # the directory 'base'.

    if {![string equal [file pathtype $base] [file pathtype $dst]]} {
      return -code error "Unable to compute relation for paths of different pathtypes: [file pathtype $base] vs. [file pathtype $dst], ($base vs. $dst)"
    }

    set base [file_lexnormalize [file join [pwd] $base]]
    set dst  [file_lexnormalize [file join [pwd] $dst]]

    set save $dst
    set base [file split $base]
    set dst  [file split $dst]

    while {[string equal [lindex $dst 0] [lindex $base 0]]} {
      set dst  [lrange $dst  1 end]
      set base [lrange $base 1 end]
      if {![llength $dst]} {break}
    }

    set dstlen  [llength $dst]
    set baselen [llength $base]

    if {($dstlen == 0) && ($baselen == 0)} {
      # Cases:
      # (a) base == dst

      set dst .
    } else {
      # Cases:
      # (b) base is: base/sub = sub
      #     dst  is: base     = {}

      # (c) base is: base     = {}
      #     dst  is: base/sub = sub

      while {$baselen > 0} {
          set dst [linsert $dst 0 ..]
          incr baselen -1
      }
      # 8.5: set dst [file join {*}$dst]
      set dst [eval [linsert $dst 0 file join]]
    }

    return $dst
}

# ::fileutil::findByPattern --
#
#      Specialization of find. Finds files based on their names,
#      which have to match the specified patterns. Options are used
#      to specify which type of patterns (regexp-, glob-style) is
#      used.
#
# Arguments:
#      basedir            Directory to start searching from.
#      args            Options (-glob, -regexp, --) followed by a
#                  list of patterns to search for.
#
# Results:
#      files            a list of interesting files.

proc ::practcl::findByPattern {basedir patterns} {
    set queue $basedir
    set result {}
    while {[llength $queue]} {
      set item [lindex $queue 0]
      set queue [lrange $queue 1 end]
      if {[file isdirectory $item]} {
        foreach path [glob -nocomplain [file join $item *]] {
          lappend queue $path
        }
        continue
      }
      foreach pattern $patterns {
        set fname [file tail $item]
        if {[string match $pattern $fname]} {
          lappend result $item
          break
        }
      }
    }
    return $result
}

###
# Record an event in the practcl log
###
proc ::practcl::log {fname comment} {
  set fname [file normalize $fname]
  if {[info exists ::practcl::logchan($fname)]} {
    set fout $::practcl::logchan($fname)
    after cancel $::practcl::logevent($fname)
  } else {
    set fout [open $fname a]
  }
  puts $fout $comment
  # Defer close until idle
  set ::practcl::logevent($fname) [after idle "close $fout ; unset ::practcl::logchan($fname)"]
}
