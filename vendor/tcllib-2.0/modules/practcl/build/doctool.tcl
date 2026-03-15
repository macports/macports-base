namespace eval ::practcl {}

###
# Concatenate a file
###
proc ::practcl::cat fname {
    if {![file exists $fname]} {
       return
    }
    set fin [open $fname r]
    set data [read $fin]
    close $fin
    return $data
}

###
# Strip the global comments from tcl code. Used to
# prevent the documentation markup comments from clogging
# up files intended for distribution in machine readable format.
###
proc ::practcl::docstrip text {
  set result {}
  foreach line [split $text \n] {
    append thisline $line \n
    if {![info complete $thisline]} continue
    set outline $thisline
    set thisline {}
    if {[string trim $outline] eq {}} {
      continue
    }
    if {[string index [string trim $outline] 0] eq "#"} continue
    set cmd [string trim [lindex $outline 0] :]
    if {$cmd eq "namespace" && [lindex $outline 1] eq "eval"} {
      append result [list {*}[lrange $outline 0 end-1]] " " \{ \n [docstrip [lindex $outline end]]\} \n
      continue
    }
    if {[string match "*::define" $cmd] && [llength $outline]==3} {
      append result [list {*}[lrange $outline 0 end-1]] " " \{ \n [docstrip [lindex $outline end]]\} \n
      continue
    }
    if {$cmd eq "oo::class" && [lindex $outline 1] eq "create"} {
      append result [list {*}[lrange $outline 0 end-1]] " " \{ \n [docstrip [lindex $outline end]]\} \n
      continue
    }
    append result $outline
  }
  return $result
}

###
# Append a line of text to a variable. Optionally apply a string mapping.
# argspec:
#   map {mandatory 0 positional 1}
#   text {mandatory 1 positional 1}
###
proc ::putb {buffername args} {
  upvar 1 $buffername buffer
  switch [llength $args] {
    1 {
      append buffer [lindex $args 0] \n
    }
    2 {
      append buffer [string map {*}$args] \n
    }
    default {
      error "usage: putb buffername ?map? string"
    }
  }
}

###
# Tool for build scripts to dynamically generate manual files from comments
# in source code files
# example:
# set authors {
#   {John Doe} {jdoe@illustrious.edu}
#   {Tom RichardHarry} {tomdickharry@illustrius.edu}
# }
# # Create the object
# ::practcl::doctool create AutoDoc
# set fout [open [file join $moddir module.tcl] w]
# foreach file [glob [file join $srcdir *.tcl]] {
#   set content [::practcl::cat [file join $srcdir $file]]
#    # Scan the file
#    AutoDoc scan_text $content
#    # Strip the comments from the distribution
#    puts $fout [::practcl::docstrip $content]
# }
# # Write out the manual page
# set manout [open [file join $moddir module.man] w]
# dict set args header [string map $modmap [::practcl::cat [file join $srcdir manual.txt]]]
# dict set args footer [string map $modmap [::practcl::cat [file join $srcdir footer.txt]]]
# dict set args authors $authors
# puts $manout [AutoDoc manpage {*}$args]
# close $manout
###
::oo::class create ::practcl::doctool {
  constructor {} {
    my reset
  }

  ###
  # Process an argument list into an informational dict.
  # This method also understands non-positional
  # arguments expressed in the notation of Tip 471
  # [uri https://core.tcl-lang.org/tips/doc/trunk/tip/479.md].
  # [para]
  # The output will be a dictionary of all of the fields and whether the fields
  # are [const positional], [const mandatory], and whether they have a
  # [const default] value.
  # [para]
  # example:
  #   my argspec {a b {c 10}}
  #
  #   > a {positional 1 mandatory 1} b {positional 1 mandatory 1} c {positional 1 mandatory 0 default 10}
  ###
  method argspec {argspec} {
    set result [dict create]
    foreach arg $argspec {
      set name [lindex $arg 0]
      dict set result $name positional 1
      dict set result $name mandatory  1
      if {$name in {args dictargs}} {
        switch [llength $arg] {
          1 {
            dict set result $name mandatory 0
          }
          2 {
            dict for {optname optinfo} [lindex $arg 1] {
              set optname [string trim $optname -:]
              dict set result $optname {positional 1 mandatory 0}
              dict for {f v} $optinfo {
                dict set result $optname [string trim $f -:] $v
              }
            }
          }
          default {
            error "Bad argument"
          }
        }
      } else {
        switch [llength $arg] {
          1 {
            dict set result $name mandatory 1
          }
          2 {
            dict set result $name mandatory 0
            dict set result $name default   [lindex $arg 1]
          }
          default {
            error "Bad argument"
          }
        }
      }
    }
    return $result
  }

  ###
  # Convert a block of comments into an informational dictionary.
  # If lines in the comment start with a single word ending in a colon,
  # all subsequent lines are appended to a dictionary field of that name.
  # If no fields are given, all of the text is appended to the [const description]
  # field.
  # example:
  # my comment {Does something cool}
  # > description {Does something cool}
  #
  # my comment {
  # title : Something really cool
  # author : Sean Woods
  # author : John Doe
  # description :
  # This does something really cool!
  # }
  # > description {This does something really cool!}
  #   title {Something really cool}
  #   author {Sean Woods
  #   John Doe}
  ###
  method comment block {
    set count 0
    set field description
    set result [dict create description {}]
    foreach line [split $block \n] {
      set sline [string trim $line]
      set fwidx [string first " " $sline]
      if {$fwidx < 0} {
        set firstword [string range $sline 0 end]
        set restline {}
      } else {
        set firstword [string range $sline 0 [expr {$fwidx-1}]]
        set restline [string range $sline [expr {$fwidx+1}] end]
      }
      if {[string index $firstword end] eq ":"} {
        set field [string tolower [string trim $firstword -:]]
        switch $field {
          dictargs -
          arglist {
            set field argspec
          }
          desc {
            set field description
          }
        }
        if {[string length $restline]} {
          dict append result $field "$restline\n"
        }
      } else {
        dict append result $field "$line\n"
      }
    }
    return $result
  }

  method keyword.Annotation {resultvar commentblock type name body} {
    upvar 1 $resultvar result
    set name [string trim $name :]
    if {[dict exists $result $type $name]} {
      set info [dict get $result $type $name]
    } else {
      set info [my comment $commentblock]
    }
    foreach {f v} $body {
      dict set info $f $v
    }
    dict set result $type $name $info
  }

  ###
  # Process an oo::objdefine call that modifies the class object
  # itself
  ####
  method keyword.Class {resultvar commentblock name body} {
    upvar 1 $resultvar result
    set name [string trim $name :]
    if {[dict exists $result class $name]} {
      set info [dict get $result class $name]
    } else {
      set info [my comment $commentblock]
    }
    set commentblock {}
    foreach line [split $body \n] {
      append thisline $line \n
      if {![info complete $thisline]} continue
      set thisline [string trim $thisline]
      if {[string index $thisline 0] eq "#"} {
        append commentblock [string trimleft $thisline #] \n
        set thisline {}
        continue
      }
      set cmd [string trim [lindex $thisline 0] ":"]
      switch $cmd {
        Option -
        option {
          my keyword.Annotation info $commentblock option [lindex $thisline 1] [lindex $thisline 2]
          set commentblock {}
        }
        variable -
        Variable {
          my keyword.Annotation info $commentblock variable [lindex $thisline 1] [list type scaler default [lindex $thisline 2]]
          set commentblock {}
        }
        Dict -
        Array {
          set iinfo [lindex $thisline 2]
          dict set iinfo type [string tolower $cmd]
          my keyword.Annotation info $commentblock variable [lindex $thisline 1] $iinfo
          set commentblock {}
        }
        Componant -
        Delegate {
          my keyword.Annotation info $commentblock delegate [lindex $thisline 1] [lindex $thisline 2]
          set commentblock {}
        }
        method -
        Ensemble {
          my keyword.Class_Method info $commentblock  {*}[lrange $thisline 1 end-1]
          set commentblock {}
        }
      }
      set thisline {}
    }
    dict set result class $name $info
  }

  ###
  # Process an oo::define, clay::define, etc statement.
  ###
  method keyword.class {resultvar commentblock name body} {
    upvar 1 $resultvar result
    set name [string trim $name :]
    if {[dict exists $result class $name]} {
      set info [dict get $result class $name]
    } else {
      set info [my comment $commentblock]
    }
    set commentblock {}
    foreach line [split $body \n] {
      append thisline $line \n
      if {![info complete $thisline]} continue
      set thisline [string trim $thisline]
      if {[string index $thisline 0] eq "#"} {
        append commentblock [string trimleft $thisline #] \n
        set thisline {}
        continue
      }
      set cmd [string trim [lindex $thisline 0] ":"]
      switch $cmd {
        Option -
        option {
          puts [list keyword.Annotation $cmd $thisline]
          my keyword.Annotation info $commentblock option [lindex $thisline 1] [lindex $thisline 2]
          set commentblock {}
        }
        variable -
        Variable {
          my keyword.Annotation info $commentblock variable [lindex $thisline 1] [list default [lindex $thisline 2]]
          set commentblock {}
        }
        Dict -
        Array {
          set iinfo [lindex $thisline 2]
          dict set iinfo type [string tolower $cmd]
          my keyword.Annotation info $commentblock variable [lindex $thisline 1] $iinfo
          set commentblock {}
        }
        Componant -
        Delegate {
          my keyword.Annotation info $commentblock delegate [lindex $thisline 1] [lindex $thisline 2]
          set commentblock {}
        }
        superclass {
          dict set info ancestors [lrange $thisline 1 end]
          set commentblock {}
        }
        classmethod -
        class_method -
        Class_Method {
          my keyword.Class_Method info $commentblock  {*}[lrange $thisline 1 end-1]
          set commentblock {}
        }
        destructor -
        constructor {
          my keyword.method info $commentblock {*}[lrange $thisline 0 end-1]
          set commentblock {}
        }
        method -
        Ensemble {
          my keyword.method info $commentblock  {*}[lrange $thisline 1 end-1]
          set commentblock {}
        }
      }
      set thisline {}
    }
    dict set result class $name $info
  }

  ###
  # Process a statement for a clay style class method
  ###
  method keyword.Class_Method {resultvar commentblock name args} {
    upvar 1 $resultvar result
    set info [my comment $commentblock]
    if {[dict exists $info show_body] && [dict get $info show_body]} {
      dict set info internals [lindex $args end]
    }
    if {[dict exists $info ensemble]} {
      dict for {method minfo} [dict get $info ensemble] {
        dict set result Class_Method "${name} $method" $minfo
      }
    } else {
      switch [llength $args] {
        1 {
          set argspec [lindex $args 0]
        }
        0 {
          set argspec dictargs
          #set body [lindex $args 0]
        }
        default {error "could not interpret method $name {*}$args"}
      }
      if {![dict exists $info argspec]} {
        dict set info argspec [my argspec $argspec]
      }
      dict set result Class_Method [string trim $name :] $info
    }
  }

  ###
  # Process a statement for a tcloo style object method
  ###
  method keyword.method {resultvar commentblock name args} {
    upvar 1 $resultvar result
    set info [my comment $commentblock]
    if {[dict exists $info show_body] && [dict get $info show_body]} {
      dict set info internals [lindex $args end]
    }
    if {[dict exists $info ensemble]} {
      dict for {method minfo} [dict get $info ensemble] {
        dict set result method "\"${name} $method\"" $minfo
      }
    } else {
      switch [llength $args] {
        1 {
          set argspec [lindex $args 0]
        }
        0 {
          set argspec dictargs
          #set body [lindex $args 0]
        }
        default {error "could not interpret method $name {*}$args"}
      }
      if {![dict exists $info argspec]} {
        dict set info argspec [my argspec $argspec]
      }
      dict set result method "\"[split [string trim $name :] ::]\"" $info
    }
  }

  ###
  # Process a proc statement
  ###
  method keyword.proc {commentblock name argspec} {
    set info [my comment $commentblock]
    if {![dict exists $info argspec]} {
      dict set info argspec [my argspec $argspec]
    }
    return $info
  }

  ###
  # Reset the state of the object and its embedded coroutine
  ###
  method reset {} {
    my variable coro
    set coro [info object namespace [self]]::coro
    oo::objdefine [self] forward coro $coro
    if {[info command $coro] ne {}} {
      rename $coro {}
    }
    coroutine $coro {*}[namespace code {my Main}]
  }

  ###
  # Main body of the embedded coroutine for the object
  ###
  method Main {} {

    my variable info
    set info [dict create]
    yield [info coroutine]
    set thisline {}
    set commentblock {}
    set linec 0
    while 1 {
      set line [yield]
      append thisline $line \n
      if {![info complete $thisline]} continue
      set thisline [string trim $thisline]
      if {[string index $thisline 0] eq "#"} {
        append commentblock [string trimleft $thisline #] \n
        set thisline {}
        continue
      }
      set cmd [string trim [lindex $thisline 0] ":"]
      switch $cmd {
        dictargs::proc {
          set procinfo [my keyword.proc $commentblock [lindex $thisline 1] [list args [list dictargs [lindex $thisline 2]]]]
          if {[dict exists $procinfo show_body] && [dict get $procinfo show_body]} {
            dict set procinfo internals [lindex $thisline end]
          }
          dict set info proc [string trim [lindex $thisline 1] :] $procinfo
          set commentblock {}
        }
        tcllib::PROC -
        PROC -
        Proc -
        proc {
          set procinfo [my keyword.proc $commentblock {*}[lrange $thisline 1 2]]
          if {[dict exists $procinfo show_body] && [dict get $procinfo show_body]} {
            dict set procinfo internals [lindex $thisline end]
          }
          dict set info proc [string trim [lindex $thisline 1] :] $procinfo
          set commentblock {}
        }
        oo::objdefine {
          if {[llength $thisline]==3} {
            lassign $thisline tcmd name body
            my keyword.Class info $commentblock $name $body
          } else {
            puts "Warning: bare oo::define in library"
          }
        }
        oo::define {
          if {[llength $thisline]==3} {
            lassign $thisline tcmd name body
            my keyword.class info $commentblock $name $body
          } else {
            puts "Warning: bare oo::define in library"
          }
        }
        tao::define -
        clay::define -
        tool::define {
          lassign $thisline tcmd name body
          my keyword.class info $commentblock $name $body
          set commentblock {}
        }
        oo::class {
          lassign $thisline tcmd mthd name body
          my keyword.class info $commentblock $name $body
          set commentblock {}
        }
        default {
          if {[lindex [split $cmd ::] end] eq "define"} {
            lassign $thisline tcmd name body
            my keyword.class info $commentblock $name $body
            set commentblock {}
          }
          set commentblock {}
        }
      }
      set thisline {}
    }
  }

  ###
  # Generate the manual page text for a method or proc
  ###
  method section.method {keyword method minfo} {
    set result {}
    set line "\[call $keyword \[cmd $method\]"
    if {[dict exists $minfo argspec]} {
      dict for {argname arginfo} [dict get $minfo argspec] {
        set positional 1
        set mandatory  1
        set repeating 0
        dict with arginfo {}
        if {$mandatory==0} {
          append line " \[opt \""
        } else {
          append line " "
        }
        if {$positional} {
          append line "\[arg $argname"
        } else {
          append line "\[option \"$argname"
          if {[dict exists $arginfo type]} {
            append line " \[emph [dict get $arginfo type]\]"
          } else {
            append line " \[emph value\]"
          }
          append line "\""
        }
        append line "\]"
        if {$mandatory==0} {
          if {[dict exists $arginfo default]} {
            append line " \[const \"[dict get $arginfo default]\"\]"
          }
          append line "\"\]"
        }
        if {$repeating} {
          append line " \[opt \[option \"$argname...\"\]\]"
        }
      }
    }
    append line \]
    putb result $line
    if {[dict exists $minfo description]} {
      putb result [dict get $minfo description]
    }
    if {[dict exists $minfo example]} {
      putb result "\[para\]Example: \[example [list [dict get $minfo example]]\]"
    }
    if {[dict exists $minfo internals]} {
      putb result "\[para\]Internals: \[example [list [dict get $minfo internals]]\]"
    }
    return $result
  }

  method section.annotation {type name iinfo} {
    set result "\[call $type \[cmd $name\]\]"
    if {[dict exists $iinfo description]} {
      putb result [dict get $iinfo description]
    }
    if {[dict exists $iinfo example]} {
      putb result "\[para\]Example: \[example [list [dict get $minfo example]]\]"
    }
    return $result
  }

  ###
  # Generate the manual page text for a class
  ###
  method section.class {class_name class_info} {
    set result {}
    putb result "\[subsection \{Class  $class_name\}\]"
    if {[dict exists $class_info ancestors]} {
      set line "\[emph \"ancestors\"\]:"
      foreach {c} [dict get $class_info ancestors] {
        append line " \[class [string trim $c :]\]"
      }
      putb result $line
      putb result {[para]}
    }
    dict for {f v} $class_info {
      if {$f in {Class_Method method description ancestors example option variable delegate}} continue
      putb result "\[emph \"$f\"\]: $v"
      putb result {[para]}
    }
    if {[dict exists $class_info example]} {
      putb result "\[example \{[list [dict get $class_info example]]\}\]"
      putb result {[para]}
    }
    if {[dict exists $class_info description]} {
      putb result [dict get $class_info description]
      putb result {[para]}
    }
    dict for {f v} $class_info {
      if {$f ni {option variable delegate}} continue
      putb result "\[class \{[string totitle $f]\}\]"
      #putb result "Methods on the class object itself."
      putb result {[list_begin definitions]}
      dict for {item iinfo} [dict get $class_info $f] {
        putb result [my section.annotation $f $item $iinfo]
      }
      putb result {[list_end]}
      putb result {[para]}
    }
    if {[dict exists $class_info Class_Method]} {
      putb result "\[class \{Class Methods\}\]"
      #putb result "Methods on the class object itself."
      putb result {[list_begin definitions]}
      dict for {method minfo} [dict get $class_info Class_Method] {
        putb result [my section.method classmethod $method $minfo]
      }
      putb result {[list_end]}
      putb result {[para]}
    }
    if {[dict exists $class_info method]} {
      putb result "\[class {Methods}\]"
      putb result {[list_begin definitions]}
      dict for {method minfo} [dict get $class_info method] {
        putb result [my section.method method $method $minfo]
      }
      putb result {[list_end]}
      putb result {[para]}
    }
    return $result
  }

  ###
  # Generate the manual page text for the commands section
  ###
  method section.command {procinfo} {
    set result {}
    putb result "\[section \{Commands\}\]"
    putb result {[list_begin definitions]}
    dict for {method minfo} $procinfo {
      putb result [my section.method proc $method $minfo]
    }
    putb result {[list_end]}
    return $result
  }

  ###
  # Generate the manual page. Returns the completed text suitable for saving in .man file.
  # The header argument is a block of doctools text to go in before the machine generated
  # section. footer is a block of doctools text to go in after the machine generated
  # section. authors is a list of individual authors and emails in the form of AUTHOR EMAIL ?AUTHOR EMAIL?...
  #
  # argspec:
  #   header {mandatory 0 positional 0}
  #   footer {mandatory 0 positional 0}
  #   authors {mandatory 0 positional 0 type list}
  ###
  method manpage args {
    my variable info
    set map {%version% 0.0 %module% {Your_Module_Here}}
    set result {}
    set header {}
    set footer {}
    set authors {}
    dict with args {}
    dict set map %keyword% comment
    putb result $map {[%keyword% {-*- tcl -*- doctools manpage}]
[vset PACKAGE_VERSION %version%]
[manpage_begin %module% n [vset PACKAGE_VERSION]]}
    putb result $map $header

    dict for {sec_type sec_info} $info {
      switch $sec_type {
        proc {
          putb result [my section.command $sec_info]
        }
        class {
          putb result "\[section Classes\]"
          dict for {class_name class_info} $sec_info {
            putb result [my section.class $class_name $class_info]
          }
        }
        default {
          putb result "\[section [list $sec_type $sec_name]\]"
          if {[dict exists $sec_info description]} {
            putb result [dict get $sec_info description]
          }
        }
      }
    }
    if {[llength $authors]} {
      putb result {[section AUTHORS]}
      foreach {name email} $authors {
        putb result "$name \[uri mailto:$email\]\[para\]"
      }
    }
    putb result $footer
    putb result {[manpage_end]}
    return $result
  }

  # Scan a block of text
  method scan_text {text} {
    my variable linecount coro
    set linecount 0
    foreach line [split $text \n] {
      incr linecount
      $coro $line
    }
  }

  # Scan a file of text
  method scan_file {filename} {
    my variable linecount coro
    set fin [open $filename r]
    set linecount 0
    while {[gets $fin line]>=0} {
      incr linecount
      $coro $line
    }
    close $fin
  }
}

