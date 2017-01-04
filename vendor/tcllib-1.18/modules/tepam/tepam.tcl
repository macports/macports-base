##########################################################################
# TEPAM - Tcl's Enhanced Procedure and Argument Manager
##########################################################################
# tepam.tcl - TEPAM's main Tcl package
# 
# TEPAM offers an alternative way to declare Tcl procedures. It provides 
# enhanced argument handling features like automatically generatehd, 
# graphical entry forms and checkers for the procedure arguments.
#
# Copyright (C) 2009/2010/2011 Andreas Drollinger
# 
# Id: tepam.tcl
##########################################################################
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

package require Tcl 8.3

namespace eval tepam {
   # Exports the major commands from this package:
   namespace export procedure argument_dialogbox

##########################################################################
#                            procedure                                   #
##########################################################################

   ######## Procedure configuration ########
   
   # Set the following variable to 0 (false) prior to the procedure definition, to
   # use first the unnamed arguments and then the named arguments.
   set named_arguments_first 1
   
   # Setting the following variable to 0 will disable the automatic argument name
   # extension feature.
   set auto_argument_name_completion 1

   # Set the following variable prior to the procedure definition to:
   #   - 0 (false): to disable command logging
   #   - 1 (true): to log all commands anytime
   #   - "interactive": to log only interactively called commands
   set command_log "interactive"
   
   # Set the following variable to "short" to generate small interactive dialog boxes.
   set interactive_display_format "extended"

   # The following variable defines the maximum line length a created help text can have:
   set help_line_length 80

   ######## Internal variables ########

   if {![info exists ProcedureList]} {
      set ProcedureList {}
   }

   ######## PureProcName ########

   # PureProcName purifies the procedure name given by the ProcName variable of the calling 
   # function and returns it. PureProcName is basically:
   # * Eliminating the main namespace indicators
   # * Encapsulating the name into '' if it is a composed name
   proc PureProcName {args} {
      upvar ProcName ProcName
      set Name $ProcName
      regsub {^::} $Name {} Name; # Eliminate the main namespace indicators
      if {[lsearch $args -appo]>=0} { # Encapsulate the name into '' if it is a composed name
         set Name "'$Name'"
      }
      return $Name
   }

   ######## Procedure help text ########
   
   set ProcedureHelp {
      procedure <ProcedureName> <ProcedureAttributes> <ProcedureBody>

      <ProcedureAttributes> = {
         [-category <Category>] 
         [-short_description <ShortDescription>]
         [-description <Description>]
         [-return <Return_Type>]
         [-example <Example>]
         [-named_arguments_first 0|1]
         [-command_log 0|1|"interactive"]
         [-auto_argument_name_completion 0|1]
         [-interactive_display_format]
         [-validatecommand <ValidateCommand>]
         [-validatecommand_error_text <ValidateCommandErrorText>]
         [-args <ArgumentDeclarationList>]
      }

      <ArgumentDeclarationList> = {<ArgumentDeclaration> [ArgumentDeclaration ...]}

      <ArgumentDeclaration> = {
         <Argument_Name>
         [-description <ArgumentDescription>]
         [-type <ArgumentType>]
         [-validatecommand <ValidateCommand>]
         [-validatecommand_error_text <ValidateCommandErrorText>]
         [-default <DefaultValue>]
         [-optional | -mandatory]
         [-choices <ChoiceList>]
         [-choicelabels <ChoiceLabelList>]
         [-range {<MinValue> <MaxValue>}
         [-multiple]
         [-auxargs <AuxilaryArgumentList>]
         [-auxargs_commands <AuxilaryArgumentCommandList>]
      }

      <ArgumentType> = {
         none double integer alnum alpha ascii control digit graph lower 
         print punct space upper wordchar xdigit color font boolean ""
      }
   }

   # Eliminate leading tabs in the help text and replace eventual tabs through spaces
   regsub -all -line {^\t\t} $ProcedureHelp "" ProcedureHelp
   regsub -all -line {\t} $ProcedureHelp "   " ProcedureHelp

   ######## Procedure ########

   # Procedure allows declaring a new procedure in the TEPAM syntax:
   #
   #    procedure my_proc {
   #       -args {message}
   #    } {
   #       puts $message; # Procedure body
   #    }
   #
   # Procedure creates in fact a TCL procedure with a patched procedure body. This body calls at 
   # the beginning an argument parser (ProcedureArgumentEvaluation) that is reading and validating 
   # the arguments that have been provided to the procedure. The previous lines are for example 
   # creating the following TCL procedure:
   #
   #    proc my_proc {args} {
   #       ::tepam::ProcedureArgumentEvaluation;
   #       if {$ProcedureArgumentEvaluationResult!=""} {
   #          if {$ProcedureArgumentEvaluationResult=="cancel"} return;
   #          return -code error $ProcedureArgumentEvaluationResult;
   #       }
   #       if {$SubProcedure!=""} {return [$SubProcedure]};
   #
   #       puts $message; # Procedure body
   #    }
   #
   # ProcedureArgumentEvaluation uses the TCL procedure's args argument to read all the provided
   # arguments. It evaluates first if a sub procedure has to be called. This information and the
   # argument validation result are provided to the calling procedure respectively via the 
   # variables SubProcedure and ProcedureArgumentEvaluationResult. In case the result evaluation
   # was not successful, the calling procedure body will simply return. In case the procedure
   # call refers to a sub-procedure, this one will be called. Otherwise, if a valid argument set
   # has been provided to the procedure, and if no sub-procedure has to be called, the original
   # procedure body is executed.
   # Procedure behaves slightly differently in case one or multiple sub-procedures have been 
   # declared without declaring the main procedure itself:
   #
   #    procedure {my_func sub_func} {
   #       -args {message}
   #    } {
   #       puts $message; # Procedure body
   #    }
   #
   # Procedure creates in this case for the main procedure a Tcl procedure as well as for the sub
   # procedure. The main procedure creates an error when it directly called. The sub-procedure
   # is executed within the main procedure's context using the uplevel command.
   #
   #    proc my_proc {args} {
   #       ::tepam::ProcedureArgumentEvaluation;
   #       if {$ProcedureArgumentEvaluationResult!=""} {
   #         if {$ProcedureArgumentEvaluationResult=="cancel"} return;
   #         return -code error $ProcedureArgumentEvaluationResult;
   #       }
   #       if {$SubProcedure!=""} {return [$SubProcedure]};
   #       error "'my_func' requires a subcommand"
   #    }
   #
   #    proc {my_proc sub_func} {args} {
   #       uplevel 1 {
   #          puts $message; # Procedure body
   #       }
   #    }
   #
   # Procedure parses itself the procedure name and attributes and creates the new TCL procedure 
   # with the modified body. For each declared argument it calls ProcedureArgDef which handles the 
   # argument definition.

   proc procedure {args} {
      variable ProcDef
      variable ProcedureHelp
      variable named_arguments_first
      variable command_log
      variable auto_argument_name_completion
      variable interactive_display_format
      variable ProcedureList

      #### Check if help is requested and extract the (sub) procedure name ####

         # Check if help is requested:
         if {[lsearch -exact $args "-help"]>=0} {
            puts $ProcedureHelp
            return
         }

         # Check that the procedure name, argument list and body has been provided:
         if {[llength $args]!=3} {
            return -code error "Missing procedure arguments, correct usage: procedure <ProcedureName>\
                   <ProcedureAttributes> <ProcedureBody>"
         }
      
         # Evaluate the full qualified procedure name including a leading name space identifier.
         # Evaluate the current namespace in case the procedure is not defined explicitly with 
         # a name space:
         regsub -all {\s+} [lindex $args 0] " " ProcName
         if {[string range $ProcName 0 1]!="::"} {
            set NameSpace [uplevel 1 {namespace current}]
            if {$NameSpace!="::"} {append NameSpace "::"}
            set ProcName ${NameSpace}${ProcName}
         }

         # Extract the procedure attributes and the procedure body:
         set ProcedureAttributes [lindex $args 1]
         set ProcedureBody [lindex $args 2]

         # Store the procedure name in the procedure list, if it is not already existing:
         if {[lsearch -exact $ProcedureList $ProcName]<0} {
            lappend ProcedureList $ProcName
         }

      #### Initialize the procedure attributes ####

         # Clean the information of an eventual previous procedure definition, and store
         # the actual configured procedure modes:
         catch {array unset ProcDef $ProcName,*}
         set ProcDef($ProcName,-named_arguments_first) $named_arguments_first
         set ProcDef($ProcName,-command_log) $command_log
         set ProcDef($ProcName,-auto_argument_name_completion) $auto_argument_name_completion
         set ProcDef($ProcName,-interactive_display_format) $interactive_display_format

         # The procedure information will be stored in the array variable ProcDef.
         # The following array members are always defined for each declared procedure:
         set ProcDef($ProcName,-validatecommand) {}
         set ProcDef($ProcName,-validatecommand_error_text) {}
         set ProcDef($ProcName,VarList) {}
         set ProcDef($ProcName,NamedVarList) {}
         set ProcDef($ProcName,UnnamedVarList) {}
         #  ProcDef($ProcName,NbrVars); # 
         #  ProcDef($ProcName,NbrNamedVars)
         #  ProcDef($ProcName,NbrUnnamedVars)

         # The following array members are defined optionally in the argument parsing section:
         #  ProcDef($ProcName,$AttributeName)
         #                    | AttributeName = {-category -return -short_description 
         #                    |                  -description -example}
         #
         #  ProcDef($ProcName,Arg,$Var,IsNamed)
         #  ProcDef($ProcName,Arg,$Var,-type)
         #  ProcDef($ProcName,Arg,$Var,-optional)
         #  ProcDef($ProcName,Arg,$Var,-validatecommand)
         #  ProcDef($ProcName,Arg,$Var,-validatecommand_error_text)
         #  ProcDef($ProcName,Arg,$Var,-default)
         #  ProcDef($ProcName,Arg,$Var,HasDefault)
         #  ProcDef($ProcName,Arg,$Var,-multiple)
         #  ProcDef($ProcName,Arg,$Var,-description)
         #  ProcDef($ProcName,Arg,$Var,-choices)
         #                    | Contains the choice list: {<Choice1> ... <ChoiceN>}
         #  ProcDef($ProcName,Arg,$Var,-choicelabels)
         #                    | Contains the choice label list: {<ChoiceLabel1> ... <ChoiceLabelN>}
         #  ProcDef($ProcName,Arg,$Var,-range)
         #  ProcDef($ProcName,Arg,$Var,SectionComment)
         #  ProcDef($ProcName,Arg,$Var,Comment)

      #### Parse all procedure attributes ####

         set UnnamedHasToBeOptional 0; # Variable that will be set to '1' if an unnamed argument is optional.
         set UnnamedWasMultiple 0;     # Variable that will be set to '1' if an unnamed argument has the -multiple option
      
         # Loop through the argument definition list:
         foreach {AttributeName AttributeValue} $ProcedureAttributes {
            # Evaluate the provided argument attribute
            switch -exact -- $AttributeName {
               -help { # Help has been required in the procedure attribute definition list:
                  puts $ProcedureHelp
                  return
               }
               -category -
               -return -
               -short_description -
               -description -
               -named_arguments_first -
               -command_log -
               -auto_argument_name_completion -
               -example -
               -interactive_display_format {
                  # Save all these information simply in the ProcDef array variable:
                  set ProcDef($ProcName,$AttributeName) $AttributeValue
               }
               -validatecommand -
               -validatecommand_error_text {
                  lappend ProcDef($ProcName,$AttributeName) $AttributeValue
               }
               -args {
                  # Read the procedure arguments with ProcedureArgDef
                  set Comment ""
                  set SectionComment ""
                  foreach arg $AttributeValue {
                     set ErrorMsg [ProcedureArgDef $arg]
                     if {$ErrorMsg!=""} {
                        return -code error "Procedure declaration [PureProcName -appo]: $ErrorMsg"
                     }
                  }
               }
               default {
                  return -code error "Procedure declaration [PureProcName -appo]: Procedure attribute '$AttributeName' not known"
               }
            }
         }

         # Complete the procedure attributes -
         # Number of arguments:
         set ProcDef($ProcName,NbrVars) [llength $ProcDef($ProcName,VarList)]
         # Number of named arguments
         set ProcDef($ProcName,NbrNamedVars) [llength $ProcDef($ProcName,NamedVarList)]
         # Number of unnamed arguments
         set ProcDef($ProcName,NbrUnnamedVars) [llength $ProcDef($ProcName,UnnamedVarList)]

      #### Create the TCL procedure(s) ####
      
         # Create now the TCL procedures. In case a sub procedure is declared, the created TCL 
         # procedure has not to call the argument evaluator, since this one has already been called 
         # in the main procedure. An additional main procedure is created if a sub procedure is 
         # declared and if no main procedure is existing.

         set Body    "::tepam::ProcedureArgumentEvaluation;\n"
         append Body "if {\$ProcedureArgumentEvaluationResult!=\"\"} \{\n"
         append Body "  if {\$ProcedureArgumentEvaluationResult==\"cancel\"} return;\n"
         append Body "  return -code error \$ProcedureArgumentEvaluationResult;\n"
         append Body "\}\n"
         append Body "if {\$SubProcedure!=\"\"} {return \[\$SubProcedure\]};\n\n"

         if {[llength $ProcName]==1} {
            append Body "$ProcedureBody"
            proc $ProcName {args} $Body
         } else {
            proc $ProcName {args} "uplevel 1 \{\n$ProcedureBody\n\}"
            if {[info commands [lindex $ProcName 0]]==""} {
               append Body "return -code error \"'[lindex $ProcName 0]' requires a subcommand\""
               proc [lindex $ProcName 0] {args} $Body
            }
         }
   }

   # ProcedureArgDef reads the definition of a single argument that is provided in form of a list:
   #
   #    -mtype -default Warning -choices {Info Warning Error} -description "M. type"
   #
   # ProcedureArgDef is executed by 'procedure'. The argument definition is provided via the 
   # argument 'ArgDef' variable. ProcedureArgDef is recognizing argument comments and section 
   # comments that can be placed into the argument definitions. ProcedureArgDef is also checking 
   # the validity of the argument specifications.

   proc ProcedureArgDef {ArgDef} {
      variable ProcDef
      variable ProcedureHelp
      variable named_arguments_first
      variable command_log
      variable auto_argument_name_completion
      variable interactive_display_format
      variable ProcedureList

      upvar ProcName ProcName
      upvar Comment Comment
      upvar SectionComment SectionComment
      upvar UnnamedHasToBeOptional UnnamedHasToBeOptional
      upvar UnnamedWasMultiple UnnamedWasMultiple

      # Read the argument name:
      set Opt [lindex $ArgDef 0]
         
      #### Handle section and argument comments, parse the option name ####
         
         # Check if the argument definition is a simply argument comment (either -, "" or {})
         if {$Opt=="" || $Opt=="-"} {
            # Eliminate the entire first word as well as any leading and tailing white spaces
            regexp {^\s*[^\s]+\s+(.*)\s*$} $ArgDef {} Comment
            regsub -all "\"" $Comment "\\\"" Comment
            return ""

         # Check if the argument definition is an argument section begin
         } elseif {[string index $Opt 0]=="\#"} {
            # Eliminate leading and tailing white spaces
            set SectionComment [string trim [string range $ArgDef 1 end]]
               
            # Eliminate the leading and ending #s and white spaces
            regexp {^\s*\#+\s*(.*?)\s*\#*\s*$} $ArgDef {} SectionComment
            # regsub -all "\"" $SectionComment "\\\" SectionComment
               
            # For an eventual interactive call that requires a GUI, swap to the short 
            # representation mode, since the frames are used to display the sections:
            set ProcDef($ProcName,-interactive_display_format) "short"
            return ""

         # Check if the argument is an option or a flag (named argument), that has with a 
         # leading '-':
         } elseif {[string index $Opt 0]=="-"} {
            set Var [string range $Opt 1 end]
            lappend ProcDef($ProcName,NamedVarList) $Var
            set ProcDef($ProcName,Arg,$Var,IsNamed) 1
   
         # The argument is an unnamed argument:
         } else {
            set Var $Opt
            lappend ProcDef($ProcName,UnnamedVarList) $Var
            set ProcDef($ProcName,Arg,$Var,IsNamed) 0
         }
         
         # Assign to the argument an eventually previously defined section or argument comment:
         if {$SectionComment!=""} {
            set ProcDef($ProcName,Arg,$Var,SectionComment) $SectionComment
            set SectionComment ""
         }
         if {$Comment!=""} {
            set ProcDef($ProcName,Arg,$Var,Comment) $Comment
            set Comment ""
         }

         # Check that an argument is not declared multiple times:
         if {[lsearch -exact $ProcDef($ProcName,VarList) $Var]>=0} {
            return "Argument '$Var' defined multiple times"
         }

      #### Define the argument attributes ####
         
         # Append the argument to the argument list and define the argument attributes with the
         # default values:
         lappend ProcDef($ProcName,VarList) $Var
         set ProcDef($ProcName,Arg,$Var,-type) ""; # Undefined
         set ProcDef($ProcName,Arg,$Var,-optional) 0
         set ProcDef($ProcName,Arg,$Var,HasDefault) 0
         set ProcDef($ProcName,Arg,$Var,-multiple) 0

         # Parse all argument attribute definitions:
         for {set a 1} {$a<[llength $ArgDef]} {incr a} {
            set ArgOption [lindex $ArgDef $a]
            set ArgOptionValue [lindex $ArgDef [expr {$a+1}]]
            switch -- $ArgOption {
               -type {
                  # Argument type definition: Check if the validation command is defined for 
                  # the used argument type:
                  if {[catch {Validate($ArgOptionValue) ""}]} {
                     return "Argument type '$ArgOptionValue' not known"
                  }
                     
                  # Store the attribute type:
                  set ProcDef($ProcName,Arg,$Var,-type) $ArgOptionValue
                     
                  # Flags (argument that have the type 'none') are always optional:
                  if {$ProcDef($ProcName,Arg,$Var,-type)=="none"} {
                     set ProcDef($ProcName,Arg,$Var,-optional) 1
                  }
                  incr a
               }
   
               -default {
                  # Arguments that have default values are always optional:
                  set ProcDef($ProcName,Arg,$Var,-default) $ArgOptionValue
                  set ProcDef($ProcName,Arg,$Var,HasDefault) 1
                  set ProcDef($ProcName,Arg,$Var,-optional) 1
                  incr a
               }
   
               -mandatory {# The -mandatory attribute is already the default behavior}
   
               -optional -
               -multiple {
                  # These attributes (flags) have just to be stored for future usage:
                  set ProcDef($ProcName,Arg,$Var,$ArgOption) 1
               }
   
               -range {
                  # Check that the range is defined by two values and that the min value is 
                  # smaller than the max value:
                  if {[llength $ArgOptionValue]!=2 || \
                      ![Validate(double) [lindex $ArgOptionValue 0]] || \
                      ![Validate(double) [lindex $ArgOptionValue 1]]} {
                     return  "Invalid range definition - $ArgOptionValue"
                  }
                  set ProcDef($ProcName,Arg,$Var,$ArgOption) $ArgOptionValue
                  incr a
               }
                  
               -validatecommand -
               -validatecommand_error_text -
               -auxargs_commands -
               -auxargs -
               -description -
               -choices -
               -choicelabels -
               -widget {
                  # Also these attributes have just to be stored for future usage:
                  set ProcDef($ProcName,Arg,$Var,$ArgOption) $ArgOptionValue
                  incr a
               }
   
               default {
                  # Generate an error if the provided attribute name doesn't match with a known
                  # attribute.
                  return "Argument attribute '$ArgOption' not known"
               }
            }
         }

      #### Perform various argument attribute validation checks ####

         # Unnamed argument attribute checks:
         if {!$ProcDef($ProcName,Arg,$Var,IsNamed)} {
            # Check that behind an optional unnamed argumeent there are only other optional 
            # unnamed arguments:
            if {$UnnamedHasToBeOptional && !$ProcDef($ProcName,Arg,$Var,-optional)} {
               return "Argument '$Var' has to be optional"
            }
               
            # Check that only the last unnamed argument can take multiple values:
            if {$UnnamedWasMultiple} {
               return "Attribute '-multiple' is only for the last unnamed argument allowed"
            }
               
            # Check the length of an optional -choicelabels list
            if {[info exists ProcDef($ProcName,Arg,$Var,-choices)] && \
                [info exists ProcDef($ProcName,Arg,$Var,-choicelabels)]} {
               if {[llength $ProcDef($ProcName,Arg,$Var,-choices)]!=
                   [llength $ProcDef($ProcName,Arg,$Var,-choicelabels)]} {
                  return "Argument '$Var' - Choice label list and choice list have different sizes"
               }
            }
               
            # Store the information about the argument attributes the check the consistency of 
            # the following arguments:
            if {$ProcDef($ProcName,Arg,$Var,-optional)} {
               set UnnamedHasToBeOptional 1
            }
            if {$ProcDef($ProcName,Arg,$Var,-multiple)} {
               set UnnamedWasMultiple 1
            }
         }
                     
         # Range checks are only allowed for integers and doubles:
         if {[info exists ProcDef($ProcName,Arg,$Var,-range)]} {
            if {[lsearch {integer double} $ProcDef($ProcName,Arg,$Var,-type)]<0} {
               return "Argument '$Var' - range specification requires type integer or double"
            }
         }

      return ""
   }

   ######## ProcedureArgumentEvaluation ########

   # ProcedureArgumentEvaluation is the argument evaluator that is embedded by the procedure
   # declaration command 'procedure' into the procedure's body in the following way:
   #
   #    proc my_proc {args} {
   #       ::tepam::ProcedureArgumentEvaluation;
   #       if {$ProcedureArgumentEvaluationResult!=""} {
   #         if {$ProcedureArgumentEvaluationResult=="cancel"} return;
   #         return -code error $ProcedureArgumentEvaluationResult;
   #       }
   #       if {$SubProcedure!=""} {return [$SubProcedure]};
   #
   #       puts $message; # Procedure body
   #    }
   #
   # ProcedureArgumentEvaluation has to define in the calling procedure two variables: 
   # The first one is ProcedureArgumentEvaluationResult that has to contain the result of the 
   # evaluation and validation of the argument set. Zero as results means that the provided 
   # arguments are OK and that the procedure body can be executed. A non-zero value indicates 
   # that the procedure body has not to be evaluated, typically because help was requested via
   # the -help option. In case of incorrect arguments an error is generated by 
   # ProcedureArgumentEvaluation.
   # The second variable that is created by ProcedureArgumentEvaluation is 'SubProcedure'. This
   # variable is set to the sub procedure name in case a sub procedure is called. If the main
   # procedure is called this variable is set to an empty string.

   # Delcare first a tiny helper function: ProcedureArgumentEvaluationReturn will assign the 
   # provided result string to the ProcedureArgumentEvaluationResult variable in the context
   # of the calling procedure and will then emulate a return function.

   proc ProcedureArgumentEvaluationReturn {Result} {
      upvar 2 ProcedureArgumentEvaluationResult ProcedureArgumentEvaluationResult
      set ProcedureArgumentEvaluationResult $Result
      return -code return
   }

   proc ProcedureArgumentEvaluation {} {
      variable ProcDef
      upvar args args
      upvar SubProcedure SubProcedure

      #### Extract the procedure and sub procedure names, call the procedure help if requested ####

         # Evaluate the complete main procedure name that contains the namespace identification:
         # The procedure name is given by the first element of 'info level':
         set ProcedureCallLine [info level -1]
         set ProcName [lindex $ProcedureCallLine 0]

         # Create the full qualified procedure name (procedure name including namespace)
         regexp {([^:]*)$} $ProcName {} ProcName
         set NameSpace [uplevel 1 {namespace current}]
         if {$NameSpace!="::"} {append NameSpace "::"}
         set ProcName ${NameSpace}${ProcName}

         # Evaluate the sub command names by checking if the first arguments are matching with
         # a specified sub command name:
         set SubProcedure ""
         while {1} {
            set ProcNameTmp "$ProcName [lindex $args 0]"
            if {![info exists ProcDef($ProcNameTmp,VarList)] && [array names ProcDef "$ProcNameTmp *"]==""} {
               # The argument is not matching with a specified sub command name (so it will be a
               # real argument):
               break
            }
            # Use the argument as sub procedure name:
            set ProcName $ProcNameTmp
            set SubProcedure $ProcName
            set args [lrange $args 1 end]
         }

         # Check if help has been requested in the procedure call:
         if {[lindex $args end]=="-help"} {
            ProcedureHelp $ProcName
            ProcedureArgumentEvaluationReturn "cancel"
         }

         # Check if the procedure call is an interactive call
         set InteractiveCall [string match "-interactive" [lindex $args end]]

         # Return an empty string if the main procedure has been called and if only sub-commands 
         # have been defined, but not the main procedure itself.
         if {![info exists ProcDef($ProcName,VarList)]} {
            ProcedureArgumentEvaluationReturn ""
         }

      #### Call an argument_dialogbox if the procedure has been called with'-interactive' ####
         set NewArgs {}
         if {$InteractiveCall} {
            # Start creating the argument_dialogbox's argument list with the title attribute:
            set DialogBoxArguments [list -title $ProcName -context $ProcName]

            # Add eventual global validation commands
            foreach ValidateCommand $ProcDef($ProcName,-validatecommand) {
               lappend DialogBoxArguments -validatecommand2 $ValidateCommand
            }
            foreach ValidateCommandErrorText $ProcDef($ProcName,-validatecommand_error_text) {
               lappend DialogBoxArguments -validatecommand2_error_text $ValidateCommandErrorText
            }

            # Create for each of the procedure arguments an entry for the argument_dialogbox:
            foreach Var $ProcDef($ProcName,VarList) {
               # Declare the result variables. These variables refer to the variables in the parent 
               # procedure (upvar). Attribute to these variables directly the default values that can be 
               # overwritten later with the new defined values.
               upvar $Var Variable__$Var

               # Create sections, write section and argument comments:
               if {$ProcDef($ProcName,-interactive_display_format)=="extended"} {
                  if {[info exists ProcDef($ProcName,Arg,$Var,SectionComment)]} {
                     # If a section comment is defined, close an eventual open frame, add the 
                     # section comment and add an eventually defined arguement comment:
                     lappend DialogBoxArguments -frame ""; # Close an eventual open frame
                     lappend DialogBoxArguments \
                                 -comment [list -text $ProcDef($ProcName,Arg,$Var,SectionComment)]
                     if {[info exists ProcDef($ProcName,Arg,$Var,Comment)]} {
                        lappend DialogBoxArguments \
                                    -comment [list -text $ProcDef($ProcName,Arg,$Var,Comment)]
                     }
                  }
                  # Create a frame around each argument entry in the extended format:
                  lappend DialogBoxArguments -frame [list -label $Var]
               } elseif {[info exists ProcDef($ProcName,Arg,$Var,SectionComment)]} {
                  # If a section is defined, create a section frame in the sort format:
                  lappend DialogBoxArguments \
                              -frame [list -label $ProcDef($ProcName,Arg,$Var,SectionComment)]
               }
               # If an argument comment is defined but not yet applied, apply it: 
               if {[info exists ProcDef($ProcName,Arg,$Var,Comment)] &&
                   !( $ProcDef($ProcName,-interactive_display_format)=="extended" &&
                     [info exists ProcDef($ProcName,Arg,$Var,SectionComment)] )} {
                  lappend DialogBoxArguments \
                              -comment [list -text $ProcDef($ProcName,Arg,$Var,Comment)]
               }

               # Provide to the argument dialogbox all the argument attributes:
               set ArgAttributes {}
               if {$ProcDef($ProcName,Arg,$Var,-type)!=""} {
                  lappend ArgAttributes -type $ProcDef($ProcName,Arg,$Var,-type)
               }
               if {$ProcDef($ProcName,Arg,$Var,-optional)} {
                  lappend ArgAttributes -optional 1
               }
               if {[info exists ProcDef($ProcName,Arg,$Var,-range)] && \
                   $ProcDef($ProcName,Arg,$Var,-range)!=""} {
                  lappend ArgAttributes -range $ProcDef($ProcName,Arg,$Var,-range)
               }
               if {[info exists ProcDef($ProcName,Arg,$Var,-validatecommand)]} {
                  lappend ArgAttributes -validatecommand $ProcDef($ProcName,Arg,$Var,-validatecommand)
               }
               if {[info exists ProcDef($ProcName,Arg,$Var,-validatecommand_error_text)]} {
                  lappend ArgAttributes -validatecommand_error_text $ProcDef($ProcName,Arg,$Var,-validatecommand_error_text)
               }
               if {[info exists ProcDef($ProcName,Arg,$Var,-auxargs)] && $ProcDef($ProcName,Arg,$Var,-auxargs)!=""} {
                  set ArgAttributes [concat $ArgAttributes $ProcDef($ProcName,Arg,$Var,-auxargs)]
               }
               if {[info exists ProcDef($ProcName,Arg,$Var,-auxargs_commands)]} {
                  foreach {AuxArg_Name AuxArgCommand} $ProcDef($ProcName,Arg,$Var,-auxargs_commands) {
                     lappend ArgAttributes $AuxArg_Name [uplevel #1 $AuxArgCommand]
                  }
               }
               if {[info exists ProcDef($ProcName,Arg,$Var,-choicelabels)]} {
                  lappend ArgAttributes -choicelabels $ProcDef($ProcName,Arg,$Var,-choicelabels)
               }

               # Set the default values
               if {[info exists ProcDef($ProcName,Arg,$Var,-default)]} {
                  lappend ArgAttributes -default $ProcDef($ProcName,Arg,$Var,-default)
               }

               # Add the variable name, type, description and range as labels and comments:
               set Label $Var; # Default label
               if {$ProcDef($ProcName,-interactive_display_format)=="extended"} {
                  # Add the argument description as comment
                  if {[info exists ProcDef($ProcName,Arg,$Var,-description)]} {
                     lappend DialogBoxArguments \
                                    -comment [list -text $ProcDef($ProcName,Arg,$Var,-description)]
                  }

                  # Add the type and ranges as comment
                  if {[lsearch {"" "string" "none"} $ProcDef($ProcName,Arg,$Var,-type)]<0} {
                     set Comment "Type: $ProcDef($ProcName,Arg,$Var,-type), "
                     if {[info exists ProcDef($ProcName,Arg,$Var,-range)]} {
                        append Comment "range: [lindex $ProcDef($ProcName,Arg,$Var,-range) 0] .. \
                                                [lindex $ProcDef($ProcName,Arg,$Var,-range) 1], "
                     }
                     lappend DialogBoxArguments -comment [list -text [string range $Comment 0 end-2]]
                  }
               } else {
                  if {[info exists ProcDef($ProcName,Arg,$Var,-description)]} {
                     set Label $ProcDef($ProcName,Arg,$Var,-description)
                  }
               }
               
               # Select the adequate widget for the argument:
               lappend ArgAttributes -label "$Label:" -variable Variable__$Var

               # A specific entry widget is explicitly specified:
               if {[info exists ProcDef($ProcName,Arg,$Var,-widget)]} {
                  lappend DialogBoxArguments -$ProcDef($ProcName,Arg,$Var,-widget) $ArgAttributes

               # A type specific widget exists, so use this one:
               } elseif {[info procs ad_form($ProcDef($ProcName,Arg,$Var,-type))]!=""} {
                  lappend DialogBoxArguments -$ProcDef($ProcName,Arg,$Var,-type) $ArgAttributes

               # Use a simple checkbutton for flags:
               } elseif {$ProcDef($ProcName,Arg,$Var,-type)=="none"} {
                  lappend DialogBoxArguments -checkbutton $ArgAttributes

               # A choice list is provided with less or equal than 4 options, use radioboxes or checkboxes:
               } elseif {[info exists ProcDef($ProcName,Arg,$Var,-choices)] && \
                   [llength $ProcDef($ProcName,Arg,$Var,-choices)]<=4} {
                  if {$ProcDef($ProcName,Arg,$Var,-multiple)} {
                     lappend DialogBoxArguments -checkbox [concat [list \
                                 -choices $ProcDef($ProcName,Arg,$Var,-choices)] $ArgAttributes]
                  } else {
                     lappend DialogBoxArguments -radiobox [concat [list \
                                 -choices $ProcDef($ProcName,Arg,$Var,-choices)] $ArgAttributes]
                  }

               # A choice list is provided with less than 30 options, use a listbox or a disjointlistbox:
               } elseif {[info exists ProcDef($ProcName,Arg,$Var,-choices)] && \
                         [llength $ProcDef($ProcName,Arg,$Var,-choices)]<30} {
                  if {$ProcDef($ProcName,Arg,$Var,-multiple)} {
                     lappend DialogBoxArguments -disjointlistbox [concat [list \
                                 -choicevariable ProcDef($ProcName,Arg,$Var,-choices) -height 3] $ArgAttributes]
                  } else {
                     lappend DialogBoxArguments -listbox [concat [list \
                                 -choicevariable ProcDef($ProcName,Arg,$Var,-choices) -height 3] $ArgAttributes]
                  }

               # For all other cases, use a simple entry widget:
               } else {
                  lappend DialogBoxArguments -entry $ArgAttributes
               }
            }

            # Call the argument dialogbox
            # puts "argument_dialogbox \{$DialogBoxArguments\}"
            if {[argument_dialogbox $DialogBoxArguments]=="cancel"} {
               # The argument dialogbox has been canceled, leave the calling procedure without
               # executing the procedure body:
               ProcedureArgumentEvaluationReturn cancel
            }

            # Set the variables of the optional arguments to the default values, if the variables
            # haven't been defined by the argument dialogbox:
            foreach Var $ProcDef($ProcName,VarList) {
               if {![info exists Variable__$Var] && \
                    [info exists ProcDef($ProcName,Arg,$Var,-default)]} {
                     set Variable__$Var $ProcDef($ProcName,Arg,$Var,-default)
               }
            }

      #### Non interactive call: Parse all arguments and define the argument variables ####

         } else {

            # Result variable declaration and default value definition
            foreach Var $ProcDef($ProcName,VarList) {
               # Declare the result variables. These variables refer to the variables in the parent 
               # procedure (upvar). Attribute to these variables directly the default values that can be 
               # overwritten later with the new defined values.
               upvar $Var Variable__$Var

               # Set the flags to the default values only when the procedure is called interactively:
               if {$ProcDef($ProcName,Arg,$Var,-type)=="none"} {
                  set Variable__$Var 0
               } elseif {[info exists ProcDef($ProcName,Arg,$Var,-default)]} {
                  # Apply an eventually defined default value, in case the argument is not a flag:
                  set Variable__$Var $ProcDef($ProcName,Arg,$Var,-default)
               }
            }

            # Prepare parsing all arguments
            set NbrArgs [llength $args]; # Number of provided arguments
            set NumberUnnamedArgs 0
            set ArgPos 0

            # Parse the unnamed arguments if they are defined first and if some of them have been 
            # declared:
            if {!$ProcDef($ProcName,-named_arguments_first)} {
               # Parse all unnamed arguments. Stop parsing them when:
               # 1) all unnamed arguments that have been declared have been parsed &&
               #    the last unnamed argument has not the -multiple option &&
               # 2) the parsed argument is optional and starts with '-'
               # 3) the parsed argument has can take multiple values &&
               #    one value has already been read &&
               #    the parsed argument starts with '-'
               
               # An argument value is optional when it has been declared with the -optional option
               # or when it is declared with the -multiple option and already one value has been
               # attributed to the argument:
               set IsOptional 0
               
               # Loop through all arguments (only if unnamed arguments have been declared:
               for {} {$ArgPos<[llength $args] && $ProcDef($ProcName,NbrUnnamedVars)>0} {incr ArgPos} {
                  # Get the next provided parameter value:
                  set arg [lindex $args $ArgPos]
                  
                  # The ordered unnamed argument list provides the relevant argument:
                  set Var [lindex $ProcDef($ProcName,UnnamedVarList) $NumberUnnamedArgs]
                  
                  # Stop parsing the unnamed arguments, if the procedure has also named arguments, 
                  # if the argument to parse is optional, and if it starts with '-':
                  if {$ProcDef($ProcName,Arg,$Var,-optional)} {
                     set IsOptional 1
                  }
                  if {$ProcDef($ProcName,NbrNamedVars)>0 && $IsOptional && \
                      [string index $arg 0]=="-"} {
                     break
                  }

                  # If the argument can have multiple values: Don't update the unnamed argument 
                  # counter to attribute the next values to the same argument. Declare the next
                  # values also as optional
                  if {$ProcDef($ProcName,Arg,$Var,-multiple)} {
                     lappend Variable__$Var $arg
                     set IsOptional 1

                  # Otherwise (the argument cannot have multiple values), assign the value to the
                  # variable. Exit the unnamed argument loop when the last declared argument has
                  # been read:
                  } else {
                     set Variable__$Var $arg
                     incr NumberUnnamedArgs
                     if {$NumberUnnamedArgs==$ProcDef($ProcName,NbrUnnamedVars)} {
                        incr ArgPos
                        break
                     }
                  }
               }
               
               # Create an error if there are other argument values that are provided, but when no
               # named arguments are declared:
               if {$ProcDef($ProcName,NbrNamedVars)==0 && $ArgPos<[llength $args]} {
                  ProcedureArgumentEvaluationReturn "$ProcName: Too many arguments: [lrange $args $ArgPos end]"
               }
            }

            # Parse the named arguments
            for {} {$ArgPos<[llength $args]} {incr ArgPos} {
               # Get the argument name:
               set arg [lindex $args $ArgPos]

               # Ignore the '--' flag. Exit the named argument parsing loop if 'named arguments
               # first' is configured
               if {$arg=="--"} {
                  if {$ProcDef($ProcName,-named_arguments_first)} {
                     incr ArgPos
                     break
                  } else {
                     continue
                  }
               }

               # In case the named arguments are used first: Check if the next argument is not 
               # anymore a named argument and stop parsing the named arguments if this is the case.
               if {$ProcDef($ProcName,-named_arguments_first) && [string index $arg 0]!="-"} {
                  break
               }

               # Otherwise (especially if the unnamed arguments are used first), check that the
               # option name starts with '-':
               if {[string index $arg 0]!="-"} {
                  ProcedureArgumentEvaluationReturn "[PureProcName]: Argument '$arg' is not an option"
               }

               # Extract the variable name (eliminate the '-'):
               set Var [string range $arg 1 end]

               # Check if the variable (name) is known. When it is not known, complete it when the 
               # name matches with the begin of a known variable name, or generate otherwise an 
               # error:
               if {![info exists ProcDef($ProcName,Arg,$Var,-type)]} {
                  
                  # Argument completion is disabled - generate an error:
                  if {!$ProcDef($ProcName,-auto_argument_name_completion)} {
                     ProcedureArgumentEvaluationReturn "[PureProcName -appr]: Argument '-$Var' not known"
                  
                  # Argument completion is enabled - check if the variable name corresponds to the
                  # begin of a known argument name:
                  } else {
                     # set MatchingVarList [lsearch -all -inline -glob $ProcDef($ProcName,VarList) ${Var}*] -> Tcl 8.3 doesn't support the -all and -inline switches!
                     set MatchingVarList {}
                     set VarList $ProcDef($ProcName,VarList)
                     while {[set Pos [lsearch -glob $VarList ${Var}*]]>=0} {
                        lappend MatchingVarList [lindex $VarList $Pos]
                        set VarList [lrange $VarList [expr $Pos+1] end]
                     }
                     # Complete the argument name if the argument doesn't exist, but if it is the begin of a declared argument.
                     switch [llength $MatchingVarList] {
                        1 {set Var $MatchingVarList}
                        0 {ProcedureArgumentEvaluationReturn "[PureProcName]: Argument '-$Var' not known"}
                        default {ProcedureArgumentEvaluationReturn "[PureProcName]: Argument '-$Var' may match multiple options: $MatchingVarList"}
                     }
                  }
               }
                  
               # Set the variable value to '1' if the argument is a flag (type=='none'). Read 
               # otherwise the variable value:
               if {$ProcDef($ProcName,Arg,$Var,-type)=="none"} { # The argument is a flag
                  set Value 1
               
               # No argument value is provided - generate an error:
               } elseif {$ArgPos==[llength $args]-1} {
                  ProcedureArgumentEvaluationReturn "[PureProcName]: No value is provided for argument '-$Var'"

               # Read the argument value
               } else {
                  set Value [lindex $args [incr ArgPos]]
               }

               # Define the argument variable. Append the new value to the existing value of the
               # variable, if the '-multiple' attribute is set for the argument:
               if {$ProcDef($ProcName,Arg,$Var,-multiple)} {
                  lappend Variable__$Var $Value
               } else {
                  set Variable__$Var $Value
               }
            }

            # In case the unnamed arguments are defined last, parse them now:
            if {$ProcDef($ProcName,-named_arguments_first)} {
               
               # Loop through the remaining arguments:
               for {} {$ArgPos<[llength $args]} {incr ArgPos} {
                  # Get the next provided parameter value:
                  set arg [lindex $args $ArgPos]
                  # Assure that the number of provided arguments is not exceeding the total number
                  # of declared unnamed arguments:
                  if {$NumberUnnamedArgs>=$ProcDef($ProcName,NbrUnnamedVars)} {
                     # Too many unnamed arguments are used, generate an adequate error message:
                     if {[string index $arg 0]=="-"} {
                        ProcedureArgumentEvaluationReturn "[PureProcName]: Too many unnamed arguments, or incorrectly used named argument: $arg"
                     } else {
                        ProcedureArgumentEvaluationReturn "[PureProcName]: Too many unnamed arguments: $arg"
                     }
                  }
                  
                  # The ordered unnamed argument list provides the relevant argument:
                  set Var [lindex $ProcDef($ProcName,UnnamedVarList) $NumberUnnamedArgs]

                  # Assign all remaining parameter values to the last argument if this one can 
                  # take multiple values:
                  if {$ProcDef($ProcName,Arg,$Var,-multiple) && \
                     $NumberUnnamedArgs==$ProcDef($ProcName,NbrUnnamedVars)-1} {
                     set Variable__$Var [lrange $args $ArgPos end]
                     # incr NumberUnnamedArgs
                     set ArgPos [llength $args]

                  # Assign otherwise the parameter value to the actual argument
                  } else {
                     set Variable__$Var $arg
                     incr NumberUnnamedArgs
                  }
               }
            }
         }

      #### Argument validation ####

         # Check that all mandatory arguments have been defined and that all arguments satisfy the 
         # defined type:

         # Loop through all named and unnamed arguments:
         foreach Var $ProcDef($ProcName,VarList) {
            
            # An error is created when a variable is not optional and when it is not defined:
            if {!$ProcDef($ProcName,Arg,$Var,-optional) && ![info exists Variable__$Var]} {
               ProcedureArgumentEvaluationReturn "[PureProcName]: Required argument is missing: $Var"
            }
            
            # Check the variable value corresponds to the specified type:
            if {[info exists Variable__$Var]} {
               # Transform the variable value in a list in case the argument is not multiple 
               # definable:
               set ValueList [set Variable__$Var]
               if {!$ProcDef($ProcName,Arg,$Var,-multiple)} {
                  set ValueList [list $ValueList]
               }

               # Loop through all elements of this list and check if each element is valid:
               foreach Value $ValueList {
                  # Check the argument type:
                  if {![Validate($ProcDef($ProcName,Arg,$Var,-type)) $Value]} {
                     ProcedureArgumentEvaluationReturn "[PureProcName]: Argument '$Var' requires type '$ProcDef($ProcName,Arg,$Var,-type)'. Provided value: '$Value'"
                  }
               
                  # Check the argument with an eventually defined validation command:
                  if {[info exists ProcDef($ProcName,Arg,$Var,-validatecommand)]} {
                     regsub {%P} $ProcDef($ProcName,Arg,$Var,-validatecommand) $Value ValidateCommand
                     if {![uplevel $ValidateCommand]} {
                        if {[info exists ProcDef($ProcName,Arg,$Var,-validatecommand_error_text)]} {
                           ProcedureArgumentEvaluationReturn "[PureProcName]: $ProcDef($ProcName,Arg,$Var,-validatecommand_error_text)"
                        } else {
                           ProcedureArgumentEvaluationReturn "[PureProcName]: Argument '$Var' is invalid. Provided value: '$Value'. Constraint: '$ProcDef($ProcName,Arg,$Var,-validatecommand)'"
                        }
                     }
                  }

                  # Check if the variable value satisfies an eventually defined range:
                  if {[info exists ProcDef($ProcName,Arg,$Var,-range)]} {
                     if {$Value<[lindex $ProcDef($ProcName,Arg,$Var,-range) 0] || \
                         $Value>[lindex $ProcDef($ProcName,Arg,$Var,-range) 1]} {
                        ProcedureArgumentEvaluationReturn "[PureProcName]: Argument '$Var' has to be between [lindex $ProcDef($ProcName,Arg,$Var,-range) 0] and [lindex $ProcDef($ProcName,Arg,$Var,-range) 1]"
                     }
                  }

                  # Check the variable value is a member of a provided choice list:
                  if {[info exists ProcDef($ProcName,Arg,$Var,-choices)]} {
                     if {[lsearch -exact $ProcDef($ProcName,Arg,$Var,-choices) $Value]<0} {
                        ProcedureArgumentEvaluationReturn "[PureProcName]: Argument '$Var' has to be one of the following elements: [GetChoiceHelpText $ProcName $Var]"
                     }
                  }
               }
            }
         }

      #### Procedure level validation ####

         foreach ValidateCommand $ProcDef($ProcName,-validatecommand) ValidateCommandErrorText $ProcDef($ProcName,-validatecommand_error_text) {
            # regsub {%P} $ProcDef($ProcName,Arg,$Var,-validatecommand) $Value ValidateCommand
            if {![uplevel $ValidateCommand]} {
               if {$ValidateCommandErrorText!=""} {
                  ProcedureArgumentEvaluationReturn "[PureProcName]: $ValidateCommandErrorText"
               } else {
                  ProcedureArgumentEvaluationReturn "[PureProcName]: Invalid argument(s) provided. Constraint: '$ValidateCommand'"
               }
            }
         }

      #### Log the procedure call ####
      
         variable ProcedureCallLogList

         if {$InteractiveCall && $ProcDef($ProcName,-command_log)=="interactive"} {
            append ProcedureCallLogList $ProcName
            if {$ProcDef($ProcName,-named_arguments_first)} {
               set ParClasses {Named Unnamed}
            } else {
               set ParClasses {Unnamed Named}
            }
            foreach ParClass $ParClasses {
               foreach Var $ProcDef($ProcName,${ParClass}VarList) {
                  if {![info exists Variable__$Var]} continue; # Skip optional arguments that haven't been defined
                  if {$ProcDef($ProcName,Arg,$Var,-type)!="none"} { # Non flag arguments
                     if {$ProcDef($ProcName,Arg,$Var,IsNamed)} {
                        append ProcedureCallLogList " -$Var"
                     }
                     append ProcedureCallLogList " \{[set Variable__$Var]\}"
                  } elseif {[set Variable__$Var]} { # Flags that are set
                     append ProcedureCallLogList " -$Var"
                  }
               }
            }
            append ProcedureCallLogList "; \# interactive call\n"
         } elseif {$ProcDef($ProcName,-command_log)=="1"} {
            append ProcedureCallLogList "$ProcedureCallLine\n"
         }
      
      ProcedureArgumentEvaluationReturn ""
   }

   ######## Validation commands ########
   
   # For each of the standard argument types supported by TEPAM, the validation command 
   # 'Validate(<Type>) specified in the following section. These commands have to return '1' in
   # case the provided value correspond to the relevant type and '0' if not. Additional user or
   # application specific types can easily be supported simply by adding a validation command
   # for the new type into the 'tepam' namespace.

   proc Validate()         {v} {return 1}
   proc Validate(none)     {v} {return 1}
   proc Validate(string)   {v} {return 1}
   proc Validate(text)     {v} {return 1}
   proc Validate(boolean)  {v} {string is boolean -strict $v}
   proc Validate(double)   {v} {string is double -strict $v}
   proc Validate(integer)  {v} {string is integer -strict $v}
   proc Validate(alnum)    {v} {string is alnum $v}
   proc Validate(alpha)    {v} {string is alpha $v}
   proc Validate(ascii)    {v} {string is ascii $v}
   proc Validate(control)  {v} {string is control $v}
   proc Validate(digit)    {v} {string is digit $v}
   proc Validate(graph)    {v} {string is graph $v}
   proc Validate(lower)    {v} {string is lower $v}
   proc Validate(print)    {v} {string is print $v}
   proc Validate(punct)    {v} {string is punct $v}
   proc Validate(space)    {v} {string is space $v}
   proc Validate(upper)    {v} {string is upper $v}
   proc Validate(wordchar) {v} {string is wordchar $v}
   proc Validate(xdigit)   {v} {string is xdigit $v}
   proc Validate(char)     {v} {expr [string length $v]==1}
   proc Validate(color)    {v} {expr ![catch {winfo rgb . $v}]}
   proc Validate(font)     {v} {expr ![catch {font measure $v ""}]}
   proc Validate(file)              {v} {expr [string length $v]>0 && ![regexp {[\"*?<>]} $v]}
   proc Validate(existingfile)      {v} {file exists $v}
   proc Validate(directory)         {v} {return 1}
   proc Validate(existingdirectory) {v} {file isdirectory $v}

   ######## Help text generation ########

   # 'ProcedureHelp_Append' appends a piece of text to the existing HelpText variable of the 
   # calling context (procedure). Tabulator characters are replaced through 3 spaces. Lines are 
   # reformatted to respect the maximum allowed line length. In case a line is wrapped, the leading
   # spaces of the first line are added to the begin of the following lines. Multiple lines can be
   # provided as text piece and these multiple lines are handled independently each to another.

   proc ProcedureHelp_Append {Text} {
      upvar HelpText HelpText
      variable help_line_length
      
      # Replace tabs through 3 spaces:
      regsub -all {\t} $Text "   " Text
      
      # Extract the initial spaces of the first line:
      regexp {^(\s*)} $Text {} SpaceStart
      
      # Loop through each of the provided help text line:
      foreach line [split $Text "\n"] {
         
         # Eliminate leading spaces of the line:
         regexp {^\s+'*(.*)$} $line {} line
         
         # Cut the line into segments that doesn't exceed the maximum allowed help line length. 
         # Add in front of each new line the initial spaces of the first line:
         while {$line!=""} {
            # Align the leading line spaces to the first line:
            set line ${SpaceStart}${line}
            
            #### Next line cutoff position evaluation ####

            # Select the next line cut position. The default position is set to the line end:
            set LastPos [string length $line]
            # Search for the last space inside the line section that is inside the specified 
            # maximum line length:
            if {$LastPos>$help_line_length} {
               set LastPos [string last " " $line $help_line_length]
            }
            # If the evaluated line break position is inside the range of the initial line spaces,
            # something goes wrong and the line should be broken at another adequate character:
            if {$LastPos<=[string length $SpaceStart]-1} {
               # Search for other good line break characters (:
               set LastPos [lindex [lindex \
                  [regexp -inline -indices {[^,:\.?\)]+$} \
                  {ProcDef(::ImportTestPointAssignmentsGeneric,Arg_SectionComment,ColumnSeparation}] 0] 0]
               # No line break position could be found:
               if {$LastPos=={}} {set LinePos 0}
            }
            # Break the line simply at the maximum allowed length in case no break position could 
            # be found:
            if {$LastPos<=[string length $SpaceStart]-1} {set LastPos $help_line_length}

            # Add the line segment to the help text:
            append HelpText [string range $line 0 [expr $LastPos-1]]\n
            
            # Eliminate the segment from the actual line:
            set line [string range $line [expr $LastPos+1] end]
         }
      }
   }

   # GetChoiceHelpText returns a help text for the choice options. The returned string corresponds
   # to the comma separated choice list in case no choice labels are defined. Otherwise, the 
   # choice labels are added behind the choice options in paranthesis.
   
   proc GetChoiceHelpText {ProcName Var} {
      variable ProcDef
      set ChoiceHelpText ""
      set LabelList {}
      catch {set LabelList $ProcDef($ProcName,Arg,$Var,-choicelabels)}
      foreach Choice $ProcDef($ProcName,Arg,$Var,-choices) Label $LabelList {
         append ChoiceHelpText ", $Choice"
         if {$Label!=""} {
            append ChoiceHelpText "($Label)"
         }
      }
      return [string range $ChoiceHelpText 2 end]
   }

   # 'ProcedureHelp' behaves in different ways, depending the provided argument. Called without any
   # argument, it summarizes all the declared procedures without explaining details about the 
   # procedure arguments. Called with a particular procedure name as parameter, it produces for
   # this procedure a comprehensive help text. And finally, if it is called with the name of a main 
   # procedure that has multiple sub procedures, it generates for all the sub procedures the 
   # complete help text.

   proc ProcedureHelp {{ProcName ""} {ReturnHelp 0}} {
      variable ProcDef
      variable ProcedureList
      ProcedureHelp_Append "NAME"
      
      # Print a list of available commands when no procedure name has been provided as argument:
      if {$ProcName==""} {
         foreach ProcName [lsort -dictionary $ProcedureList] {
            if {[info exists ProcDef($ProcName,-short_description)]} {
               ProcedureHelp_Append "      [PureProcName] - $ProcDef($ProcName,-short_description)"
            } else {
               ProcedureHelp_Append "      [PureProcName]"
            }
         }

      # A procedure name has been provided, generate a detailed help text for this procedure, or
      # for all sub procedures if only the main procedure names has been provided:
      } else {
         # Create the full qualified procedure name (procedure name including namespace).
         # Check if the procedure name contains already the name space identification:
         if {[string range $ProcName 0 1]!="::"} {
            # The namespace is not part of the used procedure name call. Evaluate it explicitly:
            set NameSpace [uplevel 1 {namespace current}]
            if {$NameSpace!="::"} {append NameSpace "::"}
            set ProcName ${NameSpace}${ProcName}
         }
         set PureProcName [PureProcName]

         # Add the short description if it exists to the NAME help text section. Please note that
         # only the short description of a main procedure is used in case the procedure has also
         # sub procedures.
         if {[info exists ProcDef($ProcName,-short_description)]} {
            ProcedureHelp_Append "      $PureProcName - $ProcDef($ProcName,-short_description)"
         } else {
            ProcedureHelp_Append "      $PureProcName"
         }

         # Create the SYNOPSIS section which contains also the synopsis of eventual sub procedures:
         ProcedureHelp_Append "SYNOPSIS"
         set NbrDescriptions 0
         set NbrExamples 0
         
         # Loop through all procedures and sub procedures:
         set ProcNames [lsort -dictionary [concat [list $ProcName] [info procs "$ProcName *"]]]
         foreach ProcName $ProcNames {
            # Skip the (sub) procedure if it has not been explicitly declared. This may be the 
            # case for procedures that are not implemented themselves but which have sub procedures:
            if {![info exists ProcDef($ProcName,VarList)]} continue
            set PureProcName [PureProcName]

            # Add to the help text first the procedure name, and then in the following lines its
            # arguments:
            ProcedureHelp_Append "      $PureProcName"
            if {$ProcDef($ProcName,-named_arguments_first)} {
               set ParClasses {Named Unnamed}
            } else {
               set ParClasses {Unnamed Named}
            }
            foreach ParClass $ParClasses {
               foreach Var $ProcDef($ProcName,${ParClass}VarList) {
                  # Section comment: Create a clean separation of the arguments:
                  if {[info exists ProcDef($ProcName,Arg,$Var,SectionComment)]} {
                     ProcedureHelp_Append "         --- $ProcDef($ProcName,Arg,$Var,SectionComment) ---"
                  }

                  # Argument declaration - put optional arguments into brackets, show the name
                  # of named arguments, add existing descriptions as well as range, type, choice
                  # definitions:
                  set HelpLine "            "
                  if {$ProcDef($ProcName,Arg,$Var,-optional)} {
                     append HelpLine "\["
                  }
                  if {$ProcDef($ProcName,Arg,$Var,IsNamed)} {
                     append HelpLine "-$Var "
                  }
                  if {$ProcDef($ProcName,Arg,$Var,-type)!="none"} {
                     append HelpLine "<$Var>"
                  }
                  if {$ProcDef($ProcName,Arg,$Var,-optional)} {
                     append HelpLine "\]"
                  }
                  ProcedureHelp_Append $HelpLine

                  set HelpLine "               "
                  if {[info exists ProcDef($ProcName,Arg,$Var,-description)]} {
                     append HelpLine "$ProcDef($ProcName,Arg,$Var,-description), "
                  }
                  if {[lsearch -exact {"" "none"} $ProcDef($ProcName,Arg,$Var,-type)]<0} {
                     append HelpLine "type: $ProcDef($ProcName,Arg,$Var,-type), "
                  }
                  if {[info exists ProcDef($ProcName,Arg,$Var,-default)]} {
                     if {[lsearch -exact {"" "string"} $ProcDef($ProcName,Arg,$Var,-type)]>=0 || $ProcDef($ProcName,Arg,$Var,-default)==""} {
                        append HelpLine "default: \"$ProcDef($ProcName,Arg,$Var,-default)\", "
                     } else {
                        append HelpLine "default: $ProcDef($ProcName,Arg,$Var,-default), "
                     }
                  }
                  if {$ProcDef($ProcName,Arg,$Var,-multiple)} {
                     append HelpLine "multiple: yes, "
                  }
                  if {[info exists ProcDef($ProcName,Arg,$Var,-range)]} {
                     append HelpLine "range: [lindex $ProcDef($ProcName,Arg,$Var,-range) 0]..[lindex $ProcDef($ProcName,Arg,$Var,-range) 1], "
                  }
                  if {[info exists ProcDef($ProcName,Arg,$Var,-choices)]} {
                     append HelpLine "choices: \{[GetChoiceHelpText $ProcName $Var]\}, "
                  }
                  # Eliminate the last ", ":
                  ProcedureHelp_Append [string range $HelpLine 0 end-2]
               }
            }
            # Remember if descriptions and/or examples are provided for the procedure:
            if {[info exists ProcDef($ProcName,-description)]} {
               incr NbrDescriptions
            }
            if {[info exists ProcDef($ProcName,-example)]} {
               incr NbrExamples
            }
         }
         # Add for the procedure and sub procedures the descriptions:
         if {$NbrDescriptions>0} {
            ProcedureHelp_Append "DESCRIPTION"
            foreach ProcName $ProcNames {
               if {[info exists ProcDef($ProcName,-description)]} {
                  if {[llength $ProcNames]>1} {
                     ProcedureHelp_Append "      $PureProcName"
                     ProcedureHelp_Append "         $ProcDef($ProcName,-description)"
                  } else {
                     ProcedureHelp_Append "      $ProcDef($ProcName,-description)"
                  }
               }
            }
         }
         # Add for the procedure and sub procedures the examples:
         if {$NbrExamples>0} {
            ProcedureHelp_Append "EXAMPLE"
            foreach ProcName $ProcNames {
               if {[info exists ProcDef($ProcName,-example)]} {
                  if {[llength $ProcNames]>1} {
                     ProcedureHelp_Append "      $PureProcName"
                     ProcedureHelp_Append "         $ProcDef($ProcName,-example)"
                  } else {
                     ProcedureHelp_Append "      $ProcDef($ProcName,-example)"
                  }
               }
            }
         }
      }
      # The created help text is by default printed to stdout.  The text will be returned
      # as result when 'ReturnHelp' is set to 1:
      if {$ReturnHelp} {
         return $HelpText
      } else {
         puts $HelpText
      }
   }

##########################################################################
#                        argument_dialogbox                            #
##########################################################################

   ######## Argument_dialogbox configuration ########
   
   # Application specific entry widget procedures can use this array variable to store their own 
   # data, using as index the widget path provided to the procedure, e.g. 
   # argument_dialogbox($W,<sub_index>):
   array set argument_dialogbox {}
   
   # Special elements of this array variable can be specified for testing purposes:
   #
   # Set to following variable to "ok" to simulate an acknowledge of the dialog box and to 
   # "cancel" to simulate an activation of the Cancel button:
   set argument_dialogbox(test,status) ""

   # The following variable can contain a script that is executed for test purposes, before
   # the argument dialog box waits on user interactions. The script is executed in the context
   # of the argument dialog box. Entire user interaction actions can be emulated together 
   # with the previous variable.
   set argument_dialogbox(test,script) {}
   
   # The array variable 'last_parameters' is only used by an argument dialog box when its context 
   # has been specified via the -context attribute. The argument dialog box' position and size as 
   # well as its entered data are stored inside this variable when the data are acknowledged and 
   # the form is closed. This allows the form to restore its previous state once it is called 
   # another time.
   array set last_parameters {}
   

   ######## Argument_dialogbox help text ########

   set ArgumentDialogboxHelp {
      argument_dialogbox \
         [-title <DialogBoxTitle>]
         [-window <DialogBoxWindow>]
         [-context <DialogBoxContext>]
         [-validatecommand <Script>]
         [-validatecommand_error_text <Script>]
         <ArgumentDefinition>|<FrameDefinition>|<Comment>
         [<ArgumentDefinition>|<FrameDefinition>|<Separation>|<Comment>]
         [<ArgumentDefinition>|<FrameDefinition>|<Separation>|<Comment>]
         ...

      <FrameDefinition> = -frame <FrameLabel>
      
      <Separation> = -sep {}
      
      <Comment> = -comment {-text <text>}

      <ArgumentDefinition> =
         <ArgumentWidgetType>
         {
            [-variable <variable>]
            [-label <LabelName>]
            [-choices <ChoiceList>]
            [-choicelabels <ChoiceLabelList>]
            [-choicevariable <ChoiceVariable>]
            [-default <DefaultValue>]
            [-multiple_selection 0|1]
            [-height <Height>]
            [-validatecommand <Script>]
            [-validatecommand_error_text <Script>]
            [-validatecommand2 <Script>]
            [-validatecommand2_error_text <Script>]
            [<WidgetTypeParameter1> <WidgetTypeParameterValue1>]
            [<WidgetTypeParameter2> <WidgetTypeParameterValue2>]
            ...
         }
      
      <ParameterWidgetType> = <StandardParameterWidgetType>|<ApplicationSpecificParameterWidgetType>

      <StandardParameterWidgetType> = {
         -entry
         -checkbox -radiobox -checkbutton
         -listbox -disjointlistbox -combobox
         -file -existingfile -directory -existingdirectory
         -color -font
      }
   }

   # Eliminate leading tabs in the help text and replace eventual tabs through spaces
   regsub -all -line {^\t\t} $ArgumentDialogboxHelp "" ArgumentDialogboxHelp
   regsub -all -line {\t} $ArgumentDialogboxHelp "   " ArgumentDialogboxHelp

   ######## argument_dialogbox ########

   # The argument dialog box allows a very easy generation of complex dialog boxes that can be 
   # used for tool configuration purposes or to control actions.
   # The argument dialog box accepts only named arguments, e.g. all arguments have to be defined 
   # as argument pairs (-<ArgumentName> <ArgumentValue>). There are some view arguments like -title,
   # -windows and -context that effect the argument dialog box' general attitude and embedding. The
   # remaining argument block's objective is the definition of variables. Except the two arguments 
   # -frame and -sep that are used to structure graphically the form, all other arguments have to
   # be assigned either to a local or global variable. The argument dialog box will create in the
   # procedure from which it has been called a local variable, unless the variable has not been 
   # defined explicitly as global variable, or as part of a certain namespace.
   # The argument dialog box requires for each variable that has to be controlled a separate 
   # parameter pair. The first element is indicating the entry form that will be used to control 
   # the variable, the second element provides information concerning the variable that has to be
   # defined and about its validation as well as parameters for the entry form. TEPAM provides
   # already a lot of available entry forms, but other application specific forms can easily been
   # added if necessary.
   # The following lines show an example of the way how the argument dialog box is used:
   #
   #   argument_dialogbox \
   #      -title "System configuration" \
   #      -window .dialog_box \
   #      -context test_1 \
   #      \
   #      -frame {-label "File definitions"} \
   #         -comment {-text "Here are two entry fields"} \
   #         -file {-variable InputFile} \
   #         -file {-label "Output file" -variable OutputFile} \
   #      -frame {-label "Frame2"} \
   #         -entry {-label Offset -variable OffsetValue} \
   #         -sep {} \
   #         -listbox {-label MyListBox -variable O(-lb1) -choices {1 2 3 4 5 6 7 8} -choicevariable ::O(-lb1_contents) -multiple_selection 1} \
   #      -frame {-label "Check and radio boxes"} \
   #         -checkbox {-label MyCheckBox -variable O(-check1) -choices {bold italic underline} -choicelabels {Bold Italic Underline}} \
   #         -radiobox {-label MyRadioBox -variable O(-radio1) -choices {bold italic underline} -choicelabels {Bold Italic Underline}} \
   #         -checkbutton {-label MyCheckButton -variable O(-check2)} \
   #      -frame {-label "Others"} \
   #         -color {-label "Background color" -variable MyColor} \

   proc argument_dialogbox {args} {
      variable argument_dialogbox
      variable ArgumentDialogboxHelp
      variable last_parameters
      # Call an initialization command that generates eventual required images:
      GuiEnvironmentInit

      #### Basic parameter check ####

         # Use the args' first element as args list if args contains only one element:
         if {[llength $args]==1} {
            set args [lindex $args 0]
         }
         # Check if arguments are provided and if the number of arguments is even:
         if {[llength $args]<1} {
            return -code error "argument_dialogbox: no argument is provided"
         }
         if {[llength $args]%2!=0 && $args!="-help"} {
            return -code error "argument_dialogbox: arguments have to be provided in key/value pairs"
         }

      #### Global parameter evaluation and top-level window creation ####

         # The following default widget path can be changed with the -window argument:
         set Wtop .dialog
         
         # Initialize the global parameters
         # YScroll=auto: Scroll is enabled in function of the windows and screen size
         array set ProcOption {
            -validatecommand {} -validatecommand2 {}
            -validatecommand_error_text {} -validatecommand2_error_text {}
            -parent .
            -title "Dialog"
            -yscroll "auto"
         }

         # Read the global parameters by looping through all arguments to select the relevant 
         # ones:
         foreach {ArgName ArgValue} $args {
            switch -- $ArgName {
               -help {puts $ArgumentDialogboxHelp; return}
               -window {set Wtop $ArgValue}
               -parent -
               -context -
               -title -
               -yscroll -
               -validatecommand -
               -validatecommand2 -
               -validatecommand_error_text -
               -validatecommand2_error_text {
                  lappend ProcOption($ArgName) $ArgValue
               }
            }
         }

         # Create the dialog box' top-level window. Hide it until the windows has been entirely 
         # deployed:
         catch {destroy $Wtop}
         toplevel $Wtop
         wm withdraw $Wtop
         wm title $Wtop $ProcOption(-title)
         wm transient $Wtop $ProcOption(-parent)

         grid [frame $Wtop.sf] -row 0 -column 0 -sticky news
         grid columnconfigure $Wtop 0 -weight 1
         grid rowconfigure $Wtop 0 -weight 1
         frame $Wtop.sf.f
         
         # Delete eventually variables defined by a previous call of the argument dialog box:
         catch {array unset argument_dialogbox $Wtop,*}
         catch {array unset argument_dialogbox $Wtop.*}

      #### Argument dependent dialog box generation ####

         # Loop through all arguments and build the dialog box:
         set ArgNbr -1
         set Framed 0
         set W $Wtop.sf.f
         foreach {ArgName ArgValue} $args {
            incr ArgNbr
            
            # Check that the argument is a named argument:
            if {[string index $ArgName 0]!="-"} {
               return -code error "Argument $ArgName not known"
            }

            # Skip the global parameters that have already been processed
            if {[lsearch -exact {-window -parent -context -title -help -yscroll
                                 -validatecommand -validatecommand2
                                 -validatecommand_error_text -validatecommand2_error_text} $ArgName]>=0} continue
            
            # Define the widget path for the new argument:
            set WChild($ArgNbr) $W.child_$ArgNbr
            
            # An argument option array will be created, based on the argument value list:
            if {$ArgName!="-sep"} {
               catch  {unset Option}
               array set Option {-label "" -optional 0}
               if {[llength $ArgValue]%2!=0} {
                  return -code error "argument_dialogbox, argument $ArgName: Attribute definition list has to contain an even number of elements"
               }
               array set Option $ArgValue
            }
            
            # The leading '-' of the argument name will not be used anymore in the remaining code:
            set ElementType [string range $ArgName 1 end]
            switch -- $ElementType {
               frame {
                  # Handle frames - close an eventual already open frame first:
                  if {$Framed} {
                     set W [winfo parent [winfo parent $W]]
                     set WChild($ArgNbr) $W.child_$ArgNbr
                  }
                  set Framed 0
                  
                  # Create only a new frame when the provided argument list is not empty:
                  if {$ArgValue!=""} {
                     # Create a labeled frame (for Tk 8.3 that doesn't contain a label frame)
                     set FontSize 10
                     pack [frame $WChild($ArgNbr) -bd 0] \
                        -pady [expr $FontSize/2] -padx 2 -fill both -expand no
                     pack [frame $WChild($ArgNbr).f -bd 2 -relief groove] \
                        -pady [expr $FontSize/2] -fill both -expand no
                     place [label $WChild($ArgNbr).label -text $Option(-label)] \
                        -x $FontSize -y [expr $FontSize/2] -anchor w
                     pack [canvas $WChild($ArgNbr).f.space -height [expr $FontSize/4] -width 10] \
                        -pady 0
                     set W $WChild($ArgNbr).f
                     set Framed 1
                  }
               }

               sep {
                  # A separator is nothing else than a frame widget that has 'no height' and a 
                  # relief structure:
                  pack [frame $WChild($ArgNbr) -height 2 -borderwidth 1 -relief sunken] \
                     -fill x -expand no -pady 4
               }

               comment {
                  # A simple label widget is used for comments:
                  pack [label $WChild($ArgNbr) -text $Option(-text) -fg blue -justify left] \
                     -anchor w -expand no -pady 2
               }
               
               default {
                  # All other arguments, e.g. the real entries to define the variables, are 
                  # handled by procedures that provides sub commands for the different usages:
                  #   ad_form(<EntryType>) create - creates the entry widget
                  #   ad_form(<EntryType>) set_choice - set the choice constraints
                  #   ad_form(<EntryType>) set - set the default value
                  #   ad_form(<EntryType>) get - read the defined value

                  # Create a text in front of the entry widget if the -text attribute is defined:
                  if {[info exists Option(-text)]} {
                     pack [label $WChild($ArgNbr)_txt -text $Option(-text) -fg blue \
                        -justify left] -anchor w -expand no -pady 2
                  }

                  # Create for the entry a frame and place the label together with a sub frame
                  # into it:
                  pack [frame $WChild($ArgNbr)] -fill x -expand yes
                  pack [label $WChild($ArgNbr).label -text $Option(-label)] -pady 4 -side left
                  pack [frame $WChild($ArgNbr).f] -fill x -expand yes -side left
                              
                  # Delete eventual existing array members related to the new entry:
                  array unset argument_dialogbox $WChild($ArgNbr),*
                  
                  # Create the variable entry form:
                  ad_form($ElementType) $WChild($ArgNbr).f create
                  
                  # Attribute if existing the choice list. This list can either be provided via 
                  # the -choicevariable or via -choices:
                  if {[info exists Option(-choicevariable)] && \
                      [uplevel 1 "info exists \"$Option(-choicevariable)\""]} {
                     ad_form($ElementType) $WChild($ArgNbr).f set_choice \
                           [uplevel 1 "set \"$Option(-choicevariable)\""]
                  } elseif {[info exists Option(-choices)]} {
                     ad_form($ElementType) $WChild($ArgNbr).f set_choice $Option(-choices)
                  }
                  
                  # Apply the default value. If the variable exists already, use the variable value
                  # as default value. Otherwise, check if the last_parameter array provides the
                  # value from a previous usage. And finally, check if a default value is provided
                  # via the -default option:
                  if {[info exists Option(-variable)] && \
                      [uplevel 1 "info exists \"$Option(-variable)\""]} {
                     ad_form($ElementType) $WChild($ArgNbr).f set \
                           [uplevel 1 "set \"$Option(-variable)\""]
                  } elseif {[info exists Option(-variable)] && [info exists ProcOption(-context)] && \
                            [info exists last_parameters($ProcOption(-context),$Option(-variable))]} {
                     ad_form($ElementType) $WChild($ArgNbr).f set \
                              $last_parameters($ProcOption(-context),$Option(-variable))
                  } elseif {[info exists Option(-default)]} {
                     ad_form($ElementType) $WChild($ArgNbr).f set $Option(-default)
                  }
                  
                  # Check if the 'Validate' command is defined for the provided variable type:
                  if {[info exists Option(-type)] && [catch {Validate($Option(-type)) ""}]} {
                     return -code error "Argument_dialogbox: Argument type '$Option(-default)' not known"
                  }
               }
            }
         }

      #### Dialog box finalization ####

         # Add the OK and cancel buttons, restore eventually saved geometry data and deiconify finally 
         # the form:
         grid [frame $Wtop.buttons] -row 1 -column 0 -columnspan 2 -sticky ew
         button $Wtop.buttons.ok -text OK -command "set ::tepam::argument_dialogbox($Wtop,status) ok"
         button $Wtop.buttons.cancel -text Cancel -command "set ::tepam::argument_dialogbox($Wtop,status) cancel"
         pack $Wtop.buttons.ok $Wtop.buttons.cancel -side left -fill x -expand yes

         update
         if {$ProcOption(-yscroll)==1 || ($ProcOption(-yscroll)=="auto" && 
                [winfo reqheight $Wtop.sf.f]+[winfo reqheight $Wtop]>[winfo screenheight $Wtop]*2/3)} {
            place $Wtop.sf.f -x 0 -y 0 -relwidth 1; # -relheight 1
            grid [scrollbar $Wtop.scale -orient v -command "tepam::argument_dialogbox_scroll $Wtop"] -row 0 -column 1 -sticky ns

            wm geometry $Wtop [winfo reqwidth $Wtop.sf.f]x[expr [winfo screenheight $Wtop.sf.f]*2/3]
            update
            tepam::argument_dialogbox_scroll $Wtop init

            # Add the bindings
            bind $Wtop.sf <Configure> "tepam::argument_dialogbox_scroll $Wtop config %W %w %h"
            bind $Wtop <MouseWheel> "if {%D>0} {tepam::argument_dialogbox_scroll $Wtop scroll -1 units} elseif {%D<0} {tepam::argument_dialogbox_scroll $Wtop scroll 1 units}"
            bind $Wtop <Button-4> "tepam::argument_dialogbox_scroll $Wtop scroll -1 units"
            bind $Wtop <Button-5> "tepam::argument_dialogbox_scroll $Wtop scroll 1 units"
         } else {
            pack $Wtop.sf.f -expand yes -fill both
         }

         if {[info exists ProcOption(-context)] && [info exists last_parameters($ProcOption(-context),-geometry)]} {
            ConfigureWindowsGeometry $Wtop $last_parameters($ProcOption(-context),-geometry)
         }

         wm protocol $Wtop WM_DELETE_WINDOW "set ::tepam::argument_dialogbox($Wtop,status) cancel"

         wm deiconify $Wtop

      #### Wait until the dialog box's entries are acknowleged (OK button) or discarded #
      
         # Execute a script if required (only for testing purposes)
         if {$argument_dialogbox(test,script)!={}} {
            eval $argument_dialogbox(test,script)
         }
      
         # Stay in a loop until all the provided values have been validated:
         while {1} {
            # Wait until the OK or cancel button is pressed:
            set argument_dialogbox($Wtop,status) ""
            if {$argument_dialogbox(test,status)==""} {
               vwait ::tepam::argument_dialogbox($Wtop,status)
               set status $argument_dialogbox($Wtop,status)
            } else { # Emulate the button activation for test purposes
               set status $argument_dialogbox(test,status)
            }

            # Cancel has been pressed - exit the wait loop:
            if {$status=="cancel"} break

            # Read all the provided values, validate them, and assign them the corresponding 
            # variables:
            set ErrorMessage ""
            set ArgNbr -1
            foreach {ArgName ArgValue} $args {
               incr ArgNbr
               
               # Extract the element type (eliminate the leading '-') and the parameters to the
               # Option array:
               set ElementType [string range $ArgName 1 end]
               if {[llength $ArgValue]<2 || [llength $ArgValue]%2!=0} continue
               catch  {unset Option}
               array set Option {-label "" -optional 0}
               array set Option $ArgValue
                # No variable is assigned to the entry, so skip this parameter:
               if {![info exists Option(-variable)]} continue
   
               # Read the result, check it and assign the result variable
               set Value [ad_form($ElementType) $WChild($ArgNbr).f get]
   
               # Validate the provided data:
               if {$Value!="" || $Option(-optional)==0} {
                  if {[info exists Option(-type)] && ![Validate($Option(-type)) $Value]} {
                     append ErrorMessage "$Option(-variable): Required type is $Option(-type)\n"
                  }
                  # Apply the validate command if existing:
                  if {[info exists Option(-validatecommand)]} {
                     regsub {%P} $Option(-validatecommand) $Value ValidateCommand
                     if {![uplevel $ValidateCommand]} {
                        if {[info exists Option(-validatecommand_error_text)]} {
                           append ErrorMessage "$Option(-validatecommand_error_text)\n"
                        } else {
                           append ErrorMessage "$Option(-variable): The value '$Value' is not valid\n"
                        }
                     }
                  }
                  # Check against a provided range:
                  if {[info exists Option(-range)]} {
                     if {$Value<[lindex $Option(-range) 0] || \
                         $Value>[lindex $Option(-range) 1]} {
                        append ErrorMessage "$Option(-variable): The value has to be between [lindex $Option(-range) 0] and [lindex $Option(-range) 1]\n"
                     }
                  }
                  # Check that the variable value is a member of a provided choice list. Some 
                  # flexibility is required for this check, since the specified value may be a list 
                  # of multiple elements that are matching the choice list.
                  if {[info exists Option(-choices)]} {
                     set ChoiceError 0
                     foreach v $Value {
                        if {[lsearch -exact $Option(-choices) $v]<0} {
                        incr ChoiceError
                        }
                     }
                     if {$ChoiceError && [lsearch -exact $Option(-choices) $Value]<0} {
                        append ErrorMessage "$Option(-variable): The value(s) has(have) to be one of the following elements: $Option(-choices)\n"
                     }
                  }
               }
               if {[info exists ProcOption(-context)]} {
                  set last_parameters($ProcOption(-context),$Option(-variable)) $Value
               }
            }

            if {$ErrorMessage==""} {
               #### Assign the values to the variables ####
               set ArgNbr -1
               foreach {ArgName ArgValue} $args {
                  incr ArgNbr
                  # Extract the element type (eliminate the leading '-') and the parameters to the
                  # Option array:
                  set ElementType [string range $ArgName 1 end]
                  if {[llength $ArgValue]<2 || [llength $ArgValue]%2!=0} continue
                  catch  {unset Option}
                  array set Option {-label "" -optional 0}
                  array set Option $ArgValue
                   # No variable is assigned to the entry, so skip this parameter:
                  if {![info exists Option(-variable)]} continue
   
                  # Read the result, check it and assign the result variable
                  set Value [ad_form($ElementType) $WChild($ArgNbr).f get]
   
                  # Define the variable in the context of the calling procedure:
                  if {$Value!="" || $Option(-optional)==0} {
                     uplevel 1 "set \"$Option(-variable)\" \{$Value\}"
                  }
               }

               #### Perform the custom argument validations ####
               
               foreach {VCommandO VCommandErrTxtO VLevel} {
                  -validatecommand -validatecommand_error_text 1
                  -validatecommand2 -validatecommand2_error_text 2
               } {
                  foreach ValidateCommand $ProcOption($VCommandO) ValidateCommandErrTxt $ProcOption($VCommandErrTxtO) {
                     if {![uplevel $VLevel $ValidateCommand]} {
                        if {$ValidateCommandErrTxt!=""} {
                           append ErrorMessage "$ValidateCommandErrTxt\n"
                        } else {
                           append ErrorMessage "Validation constraint '$ArgValue' is not satisfied\n"
                        }
                     }
                  }
               }
            }

            # Exit the loop if everything could be validated
            if {$ErrorMessage==""} break

            # Generate otherwise an error message box
            if {$argument_dialogbox(test,status)==""} {
               tk_messageBox -icon error -title Error -type ok -parent $Wtop \
                             -message "The entries could not be successfully validated:\n\n$ErrorMessage\nPlease correct the related entries."
               raise $Wtop
            } else { # Return the error message as error for test purposes
               return -code error "The entries could not be successfully validated:\n\n$ErrorMessage\nPlease correct the related entries."
            }
         }
         
         #### Save the dialog box' geometry and destroy the form ####

         if {[info exists ProcOption(-context)]} {
            set last_parameters($ProcOption(-context),-geometry) [wm geometry $Wtop]
         }
         destroy $Wtop
         array unset argument_dialogbox $Wtop,*
         return $status
   }

   # The procedure 'argument_dialogbox_scroll' is used by the argument dialogbox' y-scrollbar to
   # execute the scroll commands. It implements the Tk typical scroll commands like 'moveto', 
   # 'scroll x pages/units'. In addition to this it implements also an initialization (used to
   # initialize the scrolled frame) and a configuragion command that can be executed when a 
   # configuration event happens.
   proc argument_dialogbox_scroll {Wtop Command args} {
      set FrameHeight [winfo reqheight $Wtop.sf.f]
      set VisibleHeight [expr 1.0*[winfo height $Wtop.sf]/$FrameHeight]
      set ActualPositionY [lindex [$Wtop.scale get] 0]

      switch -- $Command {
         init {
            set ::tepam::argument_dialogbox($Wtop,wsize) ""
         }
         config {
            if {[lindex $args 0]!="$Wtop.sf" || $args==$::tepam::argument_dialogbox($Wtop,wsize)} return
            set ::tepam::argument_dialogbox($Wtop,wsize) $args
            argument_dialogbox_scroll $Wtop moveto 0
         }
         moveto {
            # Get the desired scroll position, and keep it within the valid scroll range
            set NewPositionY [lindex $args 0]
            if {$NewPositionY<0} {set NewPositionY 0}
            if {$NewPositionY>1.0-$VisibleHeight} {set NewPositionY [expr 1.0-$VisibleHeight]}

            # Adjust the scrollable frame location
            place configure $Wtop.sf.f -y [expr -1.0*$NewPositionY*$FrameHeight]

            # Adjust the scrollbar status
            $Wtop.scale set $NewPositionY [expr $NewPositionY+$VisibleHeight]
         }
         scroll {
            set StepH [expr 30.0/$FrameHeight]; # This defines the scroll unit
            switch -- $args {
               "-1 pages" {
                  argument_dialogbox_scroll $Wtop moveto [expr $ActualPositionY-$VisibleHeight]
               }
               "1 pages" {
                  argument_dialogbox_scroll $Wtop moveto [expr $ActualPositionY+$VisibleHeight]
               }
               "-1 units" {
                  argument_dialogbox_scroll $Wtop moveto [expr $ActualPositionY-$StepH]
               }
               "1 units" {
                  argument_dialogbox_scroll $Wtop moveto [expr $ActualPositionY+$StepH]
               }
            }
         }
      }
   }

   # Create the necessary resources when the argument dialog box is called the first time:
   proc GuiEnvironmentInit {} {
      if {[lsearch [image names] Tepam_SmallFlashDown]>=0} return
      image create bitmap Tepam_SmallFlashDown -data {#define down_width 8
         #define down_height 8
         static unsigned char down_bits[] = {
            0x00 0x00 0xff 0x7e 0x3c 0x18 0x00 0x00 }; }
   }

   # The following procedure defines the geometry (WxH+-X+-Y) of a window. The geometry is provided as
   # second parameter. The position (X/Y) are verified and corrected if necessary to make the window
   # entirly visible on the screen.
   # This position correction is particularly interesting if an application runs within the same user 
   # environment, but with different screen configurations.
   proc ConfigureWindowsGeometry {W Geometry} {
      set Width 200
      set Height 150
      regexp {^(\d+)x(\d+)} $Geometry {} Width Height

      set X ""
      set Y ""
      if {[regexp {([+-]+\d+)([+-]+\d+)$} $Geometry {} X Y]} {
         if {$X<0} {set X +0}
         # if {$X>[winfo screenwidth .]-[winfo reqwidth $W]} {set X +[expr [winfo screenwidth .]-[winfo reqwidth $W]]}
         if {$X>[winfo screenwidth .]-$Width} {set X +[expr [winfo screenwidth .]-$Width]}

         if {$Y<0} {set Y +0}
         # if {$Y>[winfo screenheight .]-[winfo reqheight $W]} {set Y +[expr [winfo screenheight .]-[winfo reqheight $W]]}
         if {$Y>[winfo screenheight .]-$Height} {set Y +[expr [winfo screenheight .]-$Height]}
      }
      
      wm geometry $W ${Width}x${Height}${X}${Y}
   }

   ######## Standard entry forms for the argument_dialogbox ########

   # A dedicated procedure that handles the geometrical aspects of the argument dialog box is 
   # required for each argument type. The prototype header of such a procedure is:
   #
   #    proc ad_form(<EntryType>) {W Command {Par ""}} <Body>
   #
   # The argument 'W' provides the path into which the entry has to be embedded.
   # The procedures have to provide several sub command. The optional argument 'Par' is only used 
   # for the 'set' and 'set_choice' sub commands:
   #
   #    ad_form(<EntryType>) <W> create
   #       This sub command has to creates the form for the given entry type.
   #
   #    ad_form(<EntryType>) <W> set_choice <ChoiceList>
   #       This sub command has to define the available selections (choice lists).
   #
   #    ad_form(<EntryType>) <W> set <Value>
   #       This sub command has to set the default value of the form.
   #
   #    ad_form(<EntryType>) <W> get
   #       This sub command has to return the value defined inside the form.
   #
   # To support all these sub commands, the procedures are typically structured in the following
   # way:
   #
   #    proc ad_form(<EntryType>) {W Command {Par ""}} {
   #       upvar Option Option
   #       switch $Command {
   #          "create" {<Form creation script>}
   #          "set" {<Default value setting script>}
   #          "set_choice" {<Choice list definition script>}
   #          "get" {return [<Value evaluation script>]}
   #       }
   #    }
   #
   # The parameter definition list is mapped to the Option array variable when the ad_form
   # procedures are called. These procedures can access these parameters via the Option variable
   # of the calling procedure using the upvar statement.
   # The provided frame into which each ad_form procedure can deploy the argument definition entry
   # is by default not expandable. To make them expandable, for example for list boxes, the
   # procedure ad_form(make_expandable) has to be called providing it with the entry path:

   proc ad_form(make_expandable) {W} {
      upvar 2 Framed Framed  FontSize FontSize
      # Override the not expanded parent frames:
      pack $W -fill both -expand yes
      pack [winfo parent $W] -fill both -expand yes
      if {$Framed} {
         # Make the parent frames expandable for that the listbox can also expand
         pack [winfo parent [winfo parent [winfo parent $W]]] \
            -pady [expr $FontSize/2] -fill both -expand yes
         pack [winfo parent [winfo parent $W]] \
            -pady [expr $FontSize/2] -fill both -expand yes
      }
   }

   # Implement now all entries:

   #### Simple text entry ####

   proc ad_form(entry) {W Command {Par ""}} {
      switch $Command {
         "create" {
            pack [entry $W.entry] -fill x -expand yes -pady 4 -side left }
         "set" {
            $W.entry delete 0 end; # Clear the existing selection in case the 'set' command is called multiple times
            $W.entry insert 0 $Par
         }
         "get" {
            return [$W.entry get]
         }
      }
   }

   #### Text (multi line text) ####

   proc ad_form(text) {W Command {Par ""}} {
      # puts "ad_form(text) $W $Command $Par"
      upvar Option Option
      switch $Command {
         "create" {
            ad_form(make_expandable) $W
            grid [text $W.text -yscrollcommand "$W.yscrollbar set"] -column 0 -row 0 -pady 2 -sticky news
            grid [scrollbar $W.yscrollbar -command "$W.text yview"] -column 1 -row 0 -pady 2 -sticky ns

            # Add a horizontal scroll bar if wrapping is disabled
            if {[info exists Option(-wrap)] && $Option(-wrap)=="none"} {
               grid [scrollbar $W.xscrollbar -command "$W.text xview" -orient horizontal] -column 0 -row 1 -sticky ew
               $W.text config -xscrollcommand "$W.xscrollbar set"
            }
            grid columnconfigure $W 0 -weight 1
            grid rowconfigure $W 0 -weight 1
            
            # Apply the text widget parameters
            $W.text config -wrap word -height 4; # Default parameters
            foreach Par {-height -wrap} {
               if {[info exists Option($Par)]} {
                  $W.text config $Par $Option($Par)
               }
            }
         }
         "set" {
            $W.text delete 0.0 end; # Clear the existing selection in case the 'set' command is called multiple times
            $W.text insert 0.0 $Par
         }
         "get" {
            return [$W.text get 0.0 "end - 1 chars"]
         }
      }
   }

   #### Color entry ####

   # Select_color sets the text and color of the color entry to a new color: 
   proc select_color {W NewColor} {
      if {$NewColor!=""} {
         $W.entry delete 0 end
         $W.entry insert 0 $NewColor
      }
      $W.entry config -background gray80
      catch {$W.entry config -background [$W.entry get]}
   }

   proc ad_form(color) {W Command {Par ""}} {
      upvar Option Option
      if {![info exists Option(-type)]} {
         set Option(-type) color
      }
      set Title ""
      catch {set Title $Option(-label)}
      switch $Command {
         "create" {
            pack [entry $W.entry] -fill x -expand yes -pady 4 -side left
            pack [button $W.button -text Choose -command "::tepam::select_color $W \[tk_chooseColor -parent \{$W\} -title \{$Title\}\]"] -pady 4 -side left
            bind $W.entry <Key-Return> "tepam::select_color $W {}"
            bind $W.entry <Leave> "tepam::select_color $W {}"
         }
         "set" {
            select_color $W $Par
         }
         "get" {
            return [$W.entry get]
         }
      }
   }

   #### File and directory entries ####

   # Select_file sets the file or directory entry to a new file name:
   proc select_file {W NewFile} {
      if {$NewFile==""} return
      $W.entry delete 0 end
      $W.entry insert 0 $NewFile
   }

   # Ad_form(directory_or_file) is a generic implementation of a file and directory selection
   # form. It will be used for the different file and directory types:
   proc ad_form(directory_or_file) {W Type Command {Par ""}} {
      upvar 2 Option Option
      if {![info exists Option(-type)]} {
         set Option(-type) $Type
      }
      set Title ""
      catch {set Title $Option(-label)}
      switch $Command {
         "create" {
            set FileTypes {}
            if {[info exists Option(-filetypes)]} {
               set FileTypes $Option(-filetypes)
            }

            set ActiveDir "\[file dirname \[$W.entry get\]\]";
            if {[info exists Option(-activedir)]} {
               set ActiveDir $Option(-activedir)
            }

            set InitialFile "\[$W.entry get\]";
            if {[info exists Option(-initialfile)]} {
               set InitialFile $Option(-initialfile)
               set ActiveDir [file dirname $Option(-initialfile)]
            }

            pack [entry $W.entry] -fill x -expand yes -pady 4 -side left
            if {$Type=="existingdirectory"} {
               pack [button $W.button -text Browse -command "::tepam::select_file $W \[tk_chooseDirectory -parent $W                         -initialdir \"$ActiveDir\"                               -title \{$Title\}\]"] -pady 4 -side left
            } elseif {$Type=="directory"} {
               pack [button $W.button -text Browse -command "::tepam::select_file $W \[tk_chooseDirectory -parent $W                         -initialdir \"$ActiveDir\"                               -title \{$Title\}\]"] -pady 4 -side left
            } elseif {$Type=="existingfile"} {
               pack [button $W.button -text Browse -command "::tepam::select_file $W \[tk_getOpenFile   -parent $W -filetypes \{$FileTypes\} -initialdir \"$ActiveDir\" -initialfile \"$InitialFile\" -title \{$Title\}\]"] -pady 4 -side left
            } else { # file
               pack [button $W.button -text Browse -command "::tepam::select_file $W \[tk_getSaveFile  -parent $W -filetypes \{$FileTypes\} -initialdir \"$ActiveDir\" -initialfile \"$InitialFile\" -title \{$Title\}\]"] -pady 4 -side left
            }
         }
         "set" {
            $W.entry delete 0 end; # Clear the existing selection in case the 'set' command is called multiple times
            $W.entry insert 0 $Par
         }
         "get" {
            return [$W.entry get]
         }
      }
   }

   # The generic file and directory selection command 'ad_form(directory_or_file)' are used to
   # implement the 4 file and directory selection forms:

   proc ad_form(directory) {W Command {Par ""}} {
      ad_form(directory_or_file) $W directory $Command $Par
   }

   proc ad_form(existingdirectory) {W Command {Par ""}} {
      ad_form(directory_or_file) $W existingdirectory $Command $Par
   }

   proc ad_form(file) {W Command {Par ""}} {
      ad_form(directory_or_file) $W file $Command $Par
   }

   proc ad_form(existingfile) {W Command {Par ""}} {
      ad_form(directory_or_file) $W existingfile $Command $Par
   }

   #### Combobox ####

   proc ad_form(combobox) {W Command {Par ""}} {
      switch $Command {
         "create" {
            pack [entry $W.entry -borderwidth 2] -fill x -expand yes -pady 4 -side left
               pack [button $W.button -relief flat -borderwidth 0 -image Tepam_SmallFlashDown -command "tepam::ad_form(combobox) $W open_selection"] -pady 4 -side left

               toplevel $W.selection -border 1 -background black
               wm overrideredirect $W.selection 1
               wm withdraw $W.selection
            pack [listbox $W.selection.listbox -yscrollcommand "$W.selection.scrollbar set" -exportselection 0] -fill both -expand yes -side left
            pack [scrollbar $W.selection.scrollbar -command "$W.selection.listbox yview"] -fill y -side left -expand no
                     
            bind $W.selection.listbox <<ListboxSelect>> "tepam::ad_form(combobox) $W close_selection"
            bind $W.selection <FocusOut> "wm withdraw $W.selection"
         }
         "set" {
            $W.entry delete 0 end; # Clear the existing selection in case the 'set' command is called multiple times
            $W.entry insert 0 $Par
         }
         "get" {
            return [$W.entry get]
         }
         "set_choice" {
            foreach v $Par {
               $W.selection.listbox insert end $v
            }
         }
         "open_selection" {
            ConfigureWindowsGeometry $W.selection [expr [winfo width $W.entry]+[winfo width $W.button]]x100+[winfo rootx $W.entry]+[expr [winfo rooty $W.entry]+[winfo height $W.entry]]

            catch {$W.selection.listbox selection clear 0 end}
            catch {$W.selection.listbox selection set [lsearch -exact [$W.selection.listbox get 0 end] [$W.entry get]]}
            catch {$W.selection.listbox yview [lsearch -exact [$W.selection.listbox get 0 end] [$W.entry get]]}
            
            wm deiconify $W.selection
            focus $W.selection }
         "close_selection" {
            $W.entry delete 0 end
            $W.entry insert 0 [$W.selection.listbox get [$W.selection.listbox curselection]]
            wm withdraw $W.selection }
      }
   }

   #### Listbox ####

   proc ad_form(listbox) {W Command {Par ""}} {
      # puts "ad_form(listbox) $W $Command $Par"
      upvar Option Option
      switch $Command {
         "create" {
            ad_form(make_expandable) $W
            pack [listbox $W.listbox -yscrollcommand "$W.scrollbar set" -exportselection 0] -fill both -expand yes -pady 4 -side left
            if {[info exists Option(-multiple_selection)] && $Option(-multiple_selection)} {
               $W.listbox config -selectmode extended
            }
            pack [scrollbar $W.scrollbar -command "$W.listbox yview"] -fill y -pady 4 -side left -expand no
            if {[info exists Option(-height)]} {
               $W.listbox config -height $Option(-height)
            }
         }
         "set" {
            catch {$W.listbox selection clear 0 end}; # Clear the existing selection in case the 'set' command is called multiple times
            if {[info exists Option(-multiple_selection)] && $Option(-multiple_selection)} {
               foreach o $Par {
                  catch {$W.listbox selection set [lsearch -exact [$W.listbox get 0 end] $o]}
                  catch {$W.listbox yview [lsearch -exact [$W.listbox get 0 end] $o]}
               }
            } else {
                  catch {$W.listbox selection set [lsearch -exact [$W.listbox get 0 end] $Par]}
                  catch {$W.listbox yview [lsearch -exact [$W.listbox get 0 end] $Par]}
            }
            }
         "get" {
            set Result {}
            foreach o [$W.listbox curselection] {
               lappend Result [$W.listbox get $o]
            }
            if {![info exists Option(-multiple_selection)] || !$Option(-multiple_selection)} {
               set Result [lindex $Result 0]
            }
            return $Result
         }
         "set_choice" {
            foreach v $Par {
               $W.listbox insert end $v
            }
            $W.listbox selection set 0
         }
      }
   }

   #### Disjoint listbox ####

   proc disjointlistbox_move {W Move} {
      switch $Move {
         "add" {
            $W.listbox2 selection clear 0 end
            foreach o [lsort -integer -increasing [$W.listbox1 curselection]] {
               if {[$W.listbox1 itemcget $o -foreground]=="grey"} continue
               $W.listbox2 insert end [$W.listbox1 get $o]
               $W.listbox2 selection set end
               $W.listbox1 itemconfigure $o -foreground grey
            }
            $W.listbox1 selection clear 0 end
         }
         "delete" {
            foreach o [lsort -integer -decreasing [$W.listbox2 curselection]] {
               for {set o1 0} {$o1<[$W.listbox1 index end]} {incr o1} {
                  if {[$W.listbox2 get $o]==[$W.listbox1 get $o1]} {
                     $W.listbox1 itemconfigure $o1 -foreground ""
                  }
               }
               $W.listbox2 delete $o
            }
         }
         "up" {
            foreach o [$W.listbox2 curselection] {
               if {$o==0} continue
               $W.listbox2 insert [expr $o-1] [$W.listbox2 get $o]
               $W.listbox2 delete [expr $o+1]
               $W.listbox2 selection set [expr $o-1]
            }
         }
         "down" {
            foreach o [lsort -integer -decreasing [$W.listbox2 curselection]] {
               if {$o==[$W.listbox2 index end]-1} continue
               $W.listbox2 insert [expr $o+2] [$W.listbox2 get $o]
               $W.listbox2 delete $o
               $W.listbox2 selection set [expr $o+1]
            }
         }
      }
   }

   proc ad_form(disjointlistbox) {W Command {Par ""}} {
      # puts "ad_form(listbox) $W $Command $Par"
      upvar Option Option
      switch $Command {
         "create" {
            ad_form(make_expandable) $W

            grid [label $W.label1 -text "Available"] -column 1 -row 0 -sticky ew
            grid [label $W.label2 -text "Selected"] -column 3 -row 0 -sticky ew

            grid [listbox $W.listbox1 -yscrollcommand "$W.scrollbar1 set" -exportselection 0 -selectmode extended] -column 1 -row 1 -rowspan 2 -sticky news
            grid [scrollbar $W.scrollbar1 -command "$W.listbox1 yview"] -column 2 -row 1 -rowspan 2 -sticky ns
            grid [listbox $W.listbox2 -yscrollcommand "$W.scrollbar2 set" -exportselection 0 -selectmode extended] -column 3 -row 1 -rowspan 2 -sticky news
            grid [scrollbar $W.scrollbar2 -command "$W.listbox2 yview"] -column 4 -row 1 -rowspan 2 -sticky ns

            grid [button $W.up -text "^" -command "::tepam::disjointlistbox_move $W up"] -column 5 -row 1 -sticky news
            grid [button $W.down -text "v" -command "::tepam::disjointlistbox_move $W down"] -column 5 -row 2 -sticky news

            grid [button $W.add -text ">" -command "::tepam::disjointlistbox_move $W add"] -column 1 -row 3 -columnspan 2 -sticky news
            grid [button $W.remove -text "<" -command "::tepam::disjointlistbox_move $W delete"] -column 3 -row 3 -columnspan 2 -sticky news

            foreach {Col Weight} {0 0  1 1   2 0   3 1   4 0   5 0} {
               grid columnconfigure $W $Col -weight $Weight
             }
            grid rowconfigure $W 1 -weight 1
            grid rowconfigure $W 2 -weight 1
            if {[info exists Option(-height)]} {
               $W.listbox1 config -height $Option(-height)
               $W.listbox2 config -height $Option(-height)
            }
         }
         "set" {
            # Delete an eventually previous selection (this should not be required by argument_dialogox)
            $W.listbox2 selection set 0 end
            disjointlistbox_move $W delete
            
            foreach o $Par {
               set p [lsearch -exact [$W.listbox1 get 0 end] $o]
               if {$p>=0} { # Delete the selected item from the available items
                  $W.listbox1 selection set $p
                  disjointlistbox_move $W add
               }
            }
         }
         "get" {
            return [$W.listbox2 get 0 end]
         }
         "set_choice" {
            foreach v $Par {
               $W.listbox1 insert end $v
            }
         }
      }
   }

   #### Checkbox ####

   proc ad_form(checkbox) {W Command {Par ""}} {
      upvar Option Option
      variable argument_dialogbox
      switch $Command {
         "create" {
            set argument_dialogbox($W,ButtonsW) {}
         }
         "set" {
            # Delete an eventually previous selection
            foreach ChoiceIndex [array names argument_dialogbox $W,values,*] {
               set argument_dialogbox($ChoiceIndex) ""
            }
            # Select the check buttons that correspond to the provided values 
            foreach v $Par {
               foreach BW $argument_dialogbox($W,ButtonsW) {
                  if {$v==[$BW cget -onvalue]} {
                     set [$BW cget -variable] $v
                  }
               }
            }
         }
         "get" { # Provide the selected items in the order of the provided choice list
            set Result {}
            foreach ChoiceIndex [lsort -dictionary [array names argument_dialogbox $W,values,*]] {
               if {$argument_dialogbox($ChoiceIndex)!=""} {
                  lappend Result $argument_dialogbox($ChoiceIndex) }
               }
            return $Result
         }
         "set_choice" {
            set ChoiceNumber 0
            set PackSide left
            if {[info exists Option(-direction)] && $Option(-direction)=="vertical"} {
               set PackSide top
            }
            foreach v $Par {
               set label $v
               catch {set label [lindex $Option(-choicelabels) $ChoiceNumber]}
               pack [checkbutton $W.choice_$ChoiceNumber -text $label -variable ::tepam::argument_dialogbox($W,values,$ChoiceNumber) -onvalue $v -offvalue ""] -side $PackSide -anchor w
               lappend argument_dialogbox($W,ButtonsW) $W.choice_$ChoiceNumber
               incr ChoiceNumber
            }
         }
      }
   }

   #### Radiobox ####

   proc ad_form(radiobox) {W Command {Par ""}} {
      upvar Option Option
      variable argument_dialogbox
      switch $Command {
         "create" {
            set argument_dialogbox($W,values) ""
         }
         "set" {
            set argument_dialogbox($W,values) $Par
         }
         "get" {
            return $argument_dialogbox($W,values)
         }
         "set_choice" {
            set argument_dialogbox($W,values) [lindex [lindex $Par 0] 0]
            set ChoiceNumber 0
            set PackSide left
            if {[info exists Option(-direction)] && $Option(-direction)=="vertical"} {
               set PackSide top
            }
            foreach v $Par {
               set label $v
               catch {set label [lindex $Option(-choicelabels) $ChoiceNumber]}
               pack [radiobutton $W.choice_$ChoiceNumber -text $label -variable ::tepam::argument_dialogbox($W,values) -value $v] -side $PackSide -anchor w
               incr ChoiceNumber
            }
         }
      }
   }

   #### Checkbutton ####

   proc ad_form(checkbutton) {W Command {Par ""}} {
      variable argument_dialogbox
      switch $Command {
         "create" {
            pack [checkbutton $W.checkb -variable ::tepam::argument_dialogbox($W,values)] -pady 4 -side left
            set argument_dialogbox($W,values) 0
         }
         "set" {
            set argument_dialogbox($W,values) $Par
         }
         "get" {
            return $argument_dialogbox($W,values)
         }
      }
   }

   #### Font selector ####

   proc ChooseFont_Update {W} {
      catch {$W.text config -font [ChooseFont_Get $W]}
   }

   proc ChooseFont_Get {W} {
      set Result {}
      if {![catch {lappend Result [$W.sels.lb_font get [$W.sels.lb_font curselection]] [$W.sels.lb_size get [$W.sels.lb_size curselection]]}]} {
         foreach Style {bold italic underline overstrike} {
            if {$::tepam::ChooseFont($W,$Style)} {
               lappend Result $Style
            }
         }
      }
      # puts Font:$Result
      return $Result
   }

   procedure ChooseFont {
      -args {
         {-title -type string -default "Font browser"}
         {-parent -type string -default "."}
         {-font_families -type string -default {}}
         {-font_sizes -type string -default {}}
         {-default -type string -optional}
      }
   } {
      regexp {^\.*(\..*)$} $parent.font_selection {} W
      catch {destroy $W}
      toplevel $W
      wm withdraw $W
      wm transient $W $parent
      wm group $W $parent
      wm title $W $title

      pack [label $W.into -text "Please choose a font and its size \nand style, then select OK." -justify left] -expand no -fill x

      pack [frame $W.sels] -expand yes -fill both
      pack [listbox $W.sels.lb_font -yscrollcommand "$W.sels.sb_font set" -exportselection 0 -height 10] -side left -expand yes -fill both
         bind $W.sels.lb_font <<ListboxSelect>> "::tepam::ChooseFont_Update $W"
      pack [scrollbar $W.sels.sb_font -command "$W.sels.lb_font yview"] -side left -expand no -fill both
      pack [listbox $W.sels.lb_size -yscrollcommand "$W.sels.sb_size set" -width 3 -exportselection 0 -height 10] -side left -expand no -fill both
         bind $W.sels.lb_size <<ListboxSelect>> "::tepam::ChooseFont_Update $W"
      pack [scrollbar $W.sels.sb_size -command "$W.sels.lb_size yview"] -side left -expand no -fill both

      set ButtonFont [font actual [[button $W.dummy] cget -font]]
      pack [frame $W.styles] -expand no -fill x
      pack [checkbutton $W.styles.bold -text B -indicatoron off -font "$ButtonFont -weight bold" -variable ::tepam::ChooseFont($W,bold) -command "::tepam::ChooseFont_Update $W"] -side left -expand yes -fill x
      pack [checkbutton $W.styles.italic -text I -indicatoron off -font "$ButtonFont -slant italic" -variable ::tepam::ChooseFont($W,italic) -command "::tepam::ChooseFont_Update $W"] -side left -expand yes -fill x
      pack [checkbutton $W.styles.underline -text U -indicatoron off -font "$ButtonFont -underline 1" -variable ::tepam::ChooseFont($W,underline) -command "::tepam::ChooseFont_Update $W"] -side left -expand yes -fill x
      pack [checkbutton $W.styles.overstrike -text O -indicatoron off -font "$ButtonFont -overstrike 1" -variable ::tepam::ChooseFont($W,overstrike) -command "::tepam::ChooseFont_Update $W"] -side left -expand yes -fill x

      pack [label $W.text -text "Test text 1234"] -expand no -fill x
      
      pack [frame $W.buttons] -expand no -fill x
      pack [button $W.buttons.ok -text OK -command "set ::tepam::ChooseFont($W,status) 0"] -side left -expand yes -fill x
      pack [button $W.buttons.cancel -text Cancel -command "set ::tepam::ChooseFont($W,status) 3"] -side left -expand yes -fill x

      # Create the font size and family lists. Use default lists when no family or sizes
      # are provided.
      if {$font_families=={}} {
         set font_families [font families]
      }
      foreach v $font_families {
         $W.sels.lb_font insert end $v
      }

      if {$font_sizes=={}} {
         set font_sizes {6 7 8 9 10 12 14 16 18 20 24 28 32 36 40}
      }
      foreach v $font_sizes {
         $W.sels.lb_size insert end $v
      }

      # Set the default font selection
      if {![info exists default]} {
         set default [$W.text cget -font]
         # puts "default:$default"
      }
      
      set Index [lsearch -exact $font_families [lindex $default 0]]
      if {$Index<0} {set Index [lsearch -exact $font_families [font actual $default -family]]}
      if {$Index<0} {set Index 0}
      # puts "[font actual $default -family] -> $Index"
      $W.sels.lb_font selection clear 0 end
      $W.sels.lb_font selection set $Index
      $W.sels.lb_font yview $Index

      set Index [lsearch -exact $font_sizes [lindex $default 0]]
      if {$Index<0} {set Index [lsearch -exact $font_sizes [font actual $default -size]]}
      if {$Index<0} {set Index 0}
      # puts "[font actual $default -size] -> $Index"
      $W.sels.lb_size selection clear 0 end
      $W.sels.lb_size selection set $Index
      $W.sels.lb_size yview $Index

      foreach Style {bold italic underline overstrike} {
         set ::tepam::ChooseFont($W,$Style) 0
      }
      foreach Style [lrange $default 2 end] {
         if {[info exists ::tepam::ChooseFont($W,$Style)]} {
            set ::tepam::ChooseFont($W,$Style) 1
         }
      }

      wm protocol $W WM_DELETE_WINDOW "set ::tepam::ChooseFont($W,status) 3"
      ConfigureWindowsGeometry $W "+[expr [winfo rootx $parent]+[winfo width $parent]+10]+[expr [winfo rooty $parent]+0]"
      wm deiconify $W

      # Wait until the OK or cancel button is pressed:
      set ::tepam::ChooseFont($W,status) ""
      vwait ::tepam::ChooseFont($W,status)
      
      set SelectedFont [ChooseFont_Get $W]
      destroy $W
      if {$::tepam::ChooseFont($W,status)==0} {return $SelectedFont}
      return ""
   }

   # Select_font sets the text and the font of the font entry to a font color: 
   proc select_font {W NewFont} {
      variable argument_dialogbox
      if {$NewFont!=""} {
         $W.entry delete 0 end
         $W.entry insert 0 $NewFont
      }
      $W.entry config -bg gray80
      catch {
         $W.entry config -font [$W.entry get]
         $W.entry config -bg $argument_dialogbox($W,DefaultEntryColor)
      }
   }

   proc ad_form(font) {W Command {Par ""}} {
      upvar Option Option
      variable argument_dialogbox
      if {![info exists Option(-type)]} {
         set Option(-type) font
      }
      set Title ""
      catch {set Title $Option(-label)}
      switch $Command {
         "create" {
            # The dedicated attributes -font_families and -font_sizes by this entry widget:
            set FamilyList [font families]
            catch {set FamilyList $Option(-font_families)}
            
            set SizeList {6 7 8 9 10 12 14 16 18 20 24 28 32 36 40}
            catch {set SizeList $Option(-font_sizes)}

            # Create the entry widget
            pack [entry $W.entry] -fill x -expand yes -pady 4 -side left
            pack [button $W.button -text Choose \
               -command "::tepam::select_font $W \[::tepam::ChooseFont -parent \{$W\} -title \{$Title\} -font_families \{$FamilyList\} -font_sizes \{$SizeList\} -default \[$W.entry get\]\]"] -pady 4 -side left
            bind $W.entry <Key-Return> "tepam::select_font $W {}"
            bind $W.entry <Leave> "tepam::select_font $W {}"

            set argument_dialogbox($W,DefaultEntryColor) [$W.entry cget -bg]

            # Use the default font of the entry widget as default font selection if its font 
            # family and font size is part of the selection lists. Use otherwise the first 
            # elements of the family list and the closest size for the default font.
            set DefaultFont [$W.entry cget -font]

            set DefaultFamily [font actual $DefaultFont -family]
            if {[lsearch -exact $FamilyList $DefaultFamily]<0} {
               set DefaultFamily [lindex $FamilyList 0]
            }

            set DefaultSize [font actual $DefaultFont -size]
            if {[lsearch -exact $SizeList $DefaultSize]<0} {
               set SizeList [lsort -real [concat $SizeList $DefaultSize]]
               set Pos [lsearch -exact $SizeList $DefaultSize]
               if {$Pos==0} {
                  set DefaultSize [lindex $SizeList 1]
               } elseif {$Pos==[llength $SizeList]-1} {
                  set DefaultSize [lindex $SizeList end-1]
               } elseif {[lindex $SizeList $Pos]-[lindex $SizeList [expr $Pos-1]] <
                         [lindex $SizeList [expr $Pos+1]]-[lindex $SizeList $Pos] } {
                  set DefaultSize [lindex $SizeList [expr $Pos-1]]
               } else {
                  set DefaultSize [lindex $SizeList [expr $Pos+1]]
               }
            }

            select_font $W [list $DefaultFamily $DefaultSize]
         }
         "set" {
            select_font $W $Par
         }
         "get" {
            return [$W.entry get]
         }
      }
   }

}; # End namespace tepam

# Specify the TEPAM version that is provided by this file:
package provide tepam 0.5

##########################################################################
# Id: tepam.tcl
# Modifications:
#
# TEPAM version 0.5 - 2013/10/14 droll
# * procedure command
#   - New procedure attributes: -validatecommand_error_text, -validatecommand
#   - Updated argument attribute: -validatecommand (the command is now 
#     executed in the context of the procedure body which allows accessing 
#     argument variables)
#   - New argument attribute: -validatecommand_error_text
#   - Minor bug fix: The TEPAM internal procedure list was incorrect if a 
#     procedure was defined multiple times.
#   - Procedure help generation: Indicate if an argument can be used multiple 
#     times
# * argument_dialogbox
#   - New global attributes: -validatecommand_error_text, -validatecommand
#   - New argument attributes: -validatecommand_error_text, -validatecommand,
#                              -validatecommand_error_text2, -validatecommand2
#
# TEPAM version 0.4.1 - 2013/03/25 droll
# * Correction of bug 3608952: Help text is incorrectly generated if procedures 
#   are part of the non-default namespaces
# * Correction of bug 3608951: Help text shows incorrect argument order if 
#   procedure is defined in the "unnamed arguments first, named arguments later" 
#    calling style.
#
# TEPAM version 0.4.0 - 2012/05/07 20:24:58  droll
# * Add the new text procedure argument type and the text multi line data
#   entry widget.
#
# TEPAM version 0.3.0 - 2012/03/26 20:44:10  droll
# * Add support to log the called procedures inside an array variable.
# * Simplify the value validation procedures using the 'string is'
#   procedure's -strict option.
# * Keep the original value list in the right list of the 'disjointlistbox'.
# * Add the procedure 'ConfigureWindowsGeometry' to handle window sizes
#   and positions.
#
# TEPAM version 0.2.0 - 2011/01/21 15:56:20  droll
# * Add the -widget option to the procedure arguments.
# * Add the -yscroll option to the argument dialog box.
# * Bug fixes for the following argument dialog box widgets:
#   - disjointlistbox: Keep always the same element order
#   - checkbox, radiobox: Handle correctly default values
#
# TEPAM version 0.1.0 - 2010/02/11 21:50:55  droll
# * First TEPAM revision
##########################################################################
