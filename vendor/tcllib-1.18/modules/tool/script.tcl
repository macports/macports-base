###
# Add configure by script facilities to TOOL
###
::tool::define ::tool::object {

  ###
  # Allows for a constructor to accept a psuedo-code
  # initialization script which exercise the object's methods
  # sans "my" in front of every command
  ###
  method Eval_Script script {
    set buffer {}
    set thisline {}
    foreach line [split $script \n] {
      append thisline $line
      if {![info complete $thisline]} {
        append thisline \n
        continue
      }
      set thisline [string trim $thisline]
      if {[string index $thisline 0] eq "#"} continue
      if {[string length $thisline]==0} continue
      if {[lindex $thisline 0] eq "my"} {
        # Line already calls out "my", accept verbatim
        append buffer $thisline \n
      } elseif {[string range $thisline 0 2] eq "::"} {
        # Fully qualified commands accepted verbatim
        append buffer $thisline \n
      } elseif {
        append buffer "my $thisline" \n
      }
      set thisline {}
    }
    eval $buffer
  }
}