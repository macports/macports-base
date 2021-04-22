## 
## This is the file `docstrip.tcl',
## generated with the SAK utility
## (sak docstrip/regen).
## 
## The original source files were:
## 
## tcldocstrip.dtx  (with options: `pkg')
## 
## In other words:
## **************************************
## * This Source is not the True Source *
## **************************************
## the true source is the file from which this one was generated.
##
package require Tcl 8.4
package provide docstrip 1.2
namespace eval docstrip {
   namespace export extract sourcefrom
}
proc docstrip::extract {text terminals args} {
   array set O {
      -annotate 0
      -metaprefix %%
      -onerror throw
      -trimlines 1
   }
   array set O $args
   foreach t $terminals {set T($t) ""}
   set stripped ""
   set block_stack [list]
   set offlevel 0
   set verbatim 0
   set lineno 0
   foreach line [split $text \n] {
      incr lineno
      if {$O(-trimlines)} then {
         set line [string trimright $line " "]
      }
      if {$verbatim} then {
         if {$line eq $endverbline} then {
            set verbatim 0
            continue
         } elseif {$offlevel} then {
            continue
         }
         append stripped $line \n
         if {$O(-annotate)>=1} then {append stripped {V "" ""} \n}
      } else {
         switch -glob -- $line %%* {
            if {!$offlevel} then {
               append stripped $O(-metaprefix)\
                 [string range $line 2 end] \n
               if {$O(-annotate)>=1} then {
                  append stripped [list M %% $O(-metaprefix)] \n
               }
            }
         } %<<* {
            set endverbline "%[string range $line 3 end]"
            set verbatim 1
            continue
         } %<* {
            if {![
               regexp -- {^%<([*/+-]?)([^>]*)>(.*)$} $line ""\
                 modifier expression line
            ]} then {
               extract,error BADGUARD\
                 "Malformed guard \"\n$line\n\""
                 "Malformed guard on line $lineno"
               continue
            }
            regsub -all -- {\\|\{|\}|\$|\[|\]| |;} $expression\
              {\\&} E
            regsub -all -- {,} $E {|} E
            regsub -all -- {[^()|&!]+} $E {[info exists T(&)]} E
            if {[catch {expr $E} val]} then {
               extract,error EXPRERR\
                 "Error in expression <$expression> ignored"\
                 "docstrip: $val"
               set val -1
            }
            switch -exact -- $modifier * {
               lappend block_stack $expression
               if {$offlevel || !$val} then {incr offlevel}
               continue
            } / {
               if {![llength $block_stack]} then {
                  extract,error SPURIOUS\
                    "Spurious end block </$expression> ignored"\
                    "Spurious end block </$expression>"
               } else {
                  if {[string compare $expression\
                    [lindex $block_stack end]]} then {
                     extract,error MISMATCH\
                       "Found </$expression> instead of\
                       </[lindex $block_stack end]>"
                  }
                  if {$offlevel} then {incr offlevel -1}
                  set block_stack [lreplace $block_stack end end]
               }
               continue
            } - {
               if {$offlevel || $val} then {continue}
               append stripped $line \n
               if {$O(-annotate)>=1} then {
                  append stripped [list - %<-${expression}> ""] \n
               }
            } default {
               if {$offlevel || !$val} then {continue}
               append stripped $line \n
               if {$O(-annotate)>=1} then {
                  append stripped\
                    [list + %<${modifier}${expression}> ""] \n
               }
            }
         } %* {continue}\
         {\\endinput} {
           break
         } default {
            if {$offlevel} then {continue}
            append stripped $line \n
            if {$O(-annotate)>=1} then {append stripped {. "" ""} \n}
         }
      }
      if {$O(-annotate)>=2} then {append stripped $lineno \n}
      if {$O(-annotate)>=3} then {append stripped $block_stack \n}
   }
   return $stripped
}
proc docstrip::extract,error {situation message {errmessage ""}} {
   upvar 1 O(-onerror) onerror lineno lineno
   switch -- [string tolower $onerror] "puts" {
      puts stderr "docstrip: $message on line $lineno."
   } "ignore" {} default {
      if {$errmessage ne ""} then {
         error $errmessage "" [list DOCSTRIP $situation $lineno]
      } else {
         error $message "" [list DOCSTRIP $situation $lineno]
      }
   }
}
proc docstrip::sourcefrom {name terminals args} {
   set F [open $name r]
   if {[llength $args]} then {
      eval [linsert $args 0 fconfigure $F]
   }
   set text [read $F]
   close $F
   set oldscr [info script]
   info script $name
   set code [catch {
      uplevel 1 [extract $text $terminals -metaprefix #]
   } res]
   info script $oldscr
   if {$code == 1} then {
      error $res $::errorInfo $::errorCode
   } else {
      return $res
   }
}
## 
## 
## End of file `docstrip.tcl'.