## -*- tcl -*-
##
## Snit-based Tcl/PARAM implementation of the parsing
## expression grammar
##
##	PEG
##
## Generated from file	3_peg_itself
##            for user  aku
##
# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5
package require snit
package require pt::rde ; # Implementation of the PARAM
			  # virtual machine underlying the
			  # Tcl/PARAM code used below.

# # ## ### ##### ######## ############# #####################
##

snit::type ::pt::parse::peg_tcl {
    # # ## ### ##### ######## #############
    ## Public API

    constructor {} {
	# Create the runtime supporting the parsing process.
	set myparser [pt::rde ${selfns}::ENGINE]
	return
    }

    method parse {channel} {
	$myparser reset $channel
	MAIN ; # Entrypoint for the generated code.
	return [$myparser complete]
    }

    method parset {text} {
	$myparser reset
	$myparser data $text
	MAIN ; # Entrypoint for the generated code.
	return [$myparser complete]
    }

    # # ## ### ###### ######## #############
    ## Configuration

    pragma -hastypeinfo    0
    pragma -hastypemethods 0
    pragma -hasinfo        0
    pragma -simpledispatch 1

    # # ## ### ###### ######## #############
    ## Data structures.

    variable myparser {} ; # Our instantiation of the PARAM.

    # # ## ### ###### ######## #############
    ## BEGIN of GENERATED CODE. DO NOT EDIT.

    #
    # Grammar Start Expression
    #
    
    proc MAIN {} { upvar 1 myparser myparser
        sym_Grammar
        return
    }
    
    #
    # leaf Symbol 'ALNUM'
    #
    
    proc sym_ALNUM {} { upvar 1 myparser myparser
        # x
        #     "<alnum>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start ALNUM
        sequence_4
        $myparser si:void_leaf_symbol_end ALNUM
        return
    }
    
    proc sequence_4 {} { upvar 1 myparser myparser
        # x
        #     "<alnum>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <alnum>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'ALPHA'
    #
    
    proc sym_ALPHA {} { upvar 1 myparser myparser
        # x
        #     "<alpha>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start ALPHA
        sequence_9
        $myparser si:void_leaf_symbol_end ALPHA
        return
    }
    
    proc sequence_9 {} { upvar 1 myparser myparser
        # x
        #     "<alpha>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <alpha>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'AND'
    #
    
    proc sym_AND {} { upvar 1 myparser myparser
        # x
        #     '&'
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start AND
        sequence_14
        $myparser si:void_leaf_symbol_end AND
        return
    }
    
    proc sequence_14 {} { upvar 1 myparser myparser
        # x
        #     '&'
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char &
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # void Symbol 'APOSTROPH'
    #
    
    proc sym_APOSTROPH {} { upvar 1 myparser myparser
        # '''
    
        $myparser si:void_void_symbol_start APOSTROPH
        $myparser si:next_char '
        $myparser si:void_clear_symbol_end APOSTROPH
        return
    }
    
    #
    # leaf Symbol 'ASCII'
    #
    
    proc sym_ASCII {} { upvar 1 myparser myparser
        # x
        #     "<ascii>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start ASCII
        sequence_21
        $myparser si:void_leaf_symbol_end ASCII
        return
    }
    
    proc sequence_21 {} { upvar 1 myparser myparser
        # x
        #     "<ascii>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <ascii>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # value Symbol 'Attribute'
    #
    
    proc sym_Attribute {} { upvar 1 myparser myparser
        # x
        #     /
        #         (VOID)
        #         (LEAF)
        #     (COLON)
    
        $myparser si:value_symbol_start Attribute
        sequence_29
        $myparser si:reduce_symbol_end Attribute
        return
    }
    
    proc sequence_29 {} { upvar 1 myparser myparser
        # x
        #     /
        #         (VOID)
        #         (LEAF)
        #     (COLON)
    
        $myparser si:value_state_push
        choice_26
        $myparser si:valuevalue_part
        sym_COLON
        $myparser si:value_state_merge
        return
    }
    
    proc choice_26 {} { upvar 1 myparser myparser
        # /
        #     (VOID)
        #     (LEAF)
    
        $myparser si:value_state_push
        sym_VOID
        $myparser si:valuevalue_branch
        sym_LEAF
        $myparser si:value_state_merge
        return
    }
    
    #
    # value Symbol 'Char'
    #
    
    proc sym_Char {} { upvar 1 myparser myparser
        # /
        #     (CharSpecial)
        #     (CharOctalFull)
        #     (CharOctalPart)
        #     (CharUnicode)
        #     (CharUnescaped)
    
        $myparser si:value_symbol_start Char
        choice_37
        $myparser si:reduce_symbol_end Char
        return
    }
    
    proc choice_37 {} { upvar 1 myparser myparser
        # /
        #     (CharSpecial)
        #     (CharOctalFull)
        #     (CharOctalPart)
        #     (CharUnicode)
        #     (CharUnescaped)
    
        $myparser si:value_state_push
        sym_CharSpecial
        $myparser si:valuevalue_branch
        sym_CharOctalFull
        $myparser si:valuevalue_branch
        sym_CharOctalPart
        $myparser si:valuevalue_branch
        sym_CharUnicode
        $myparser si:valuevalue_branch
        sym_CharUnescaped
        $myparser si:value_state_merge
        return
    }
    
    #
    # leaf Symbol 'CharOctalFull'
    #
    
    proc sym_CharOctalFull {} { upvar 1 myparser myparser
        # x
        #     '\'
        #     range (0 .. 2)
        #     range (0 .. 7)
        #     range (0 .. 7)
    
        $myparser si:void_symbol_start CharOctalFull
        sequence_44
        $myparser si:void_leaf_symbol_end CharOctalFull
        return
    }
    
    proc sequence_44 {} { upvar 1 myparser myparser
        # x
        #     '\'
        #     range (0 .. 2)
        #     range (0 .. 7)
        #     range (0 .. 7)
    
        $myparser si:void_state_push
        $myparser si:next_char \134
        $myparser si:voidvoid_part
        $myparser si:next_range 0 2
        $myparser si:voidvoid_part
        $myparser si:next_range 0 7
        $myparser si:voidvoid_part
        $myparser si:next_range 0 7
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'CharOctalPart'
    #
    
    proc sym_CharOctalPart {} { upvar 1 myparser myparser
        # x
        #     '\'
        #     range (0 .. 7)
        #     ?
        #         range (0 .. 7)
    
        $myparser si:void_symbol_start CharOctalPart
        sequence_52
        $myparser si:void_leaf_symbol_end CharOctalPart
        return
    }
    
    proc sequence_52 {} { upvar 1 myparser myparser
        # x
        #     '\'
        #     range (0 .. 7)
        #     ?
        #         range (0 .. 7)
    
        $myparser si:void_state_push
        $myparser si:next_char \134
        $myparser si:voidvoid_part
        $myparser si:next_range 0 7
        $myparser si:voidvoid_part
        optional_50
        $myparser si:void_state_merge
        return
    }
    
    proc optional_50 {} { upvar 1 myparser myparser
        # ?
        #     range (0 .. 7)
    
        $myparser si:void2_state_push
        $myparser si:next_range 0 7
        $myparser si:void_state_merge_ok
        return
    }
    
    #
    # leaf Symbol 'CharSpecial'
    #
    
    proc sym_CharSpecial {} { upvar 1 myparser myparser
        # x
        #     '\'
        #     [nrt'\"[]\]
    
        $myparser si:void_symbol_start CharSpecial
        sequence_57
        $myparser si:void_leaf_symbol_end CharSpecial
        return
    }
    
    proc sequence_57 {} { upvar 1 myparser myparser
        # x
        #     '\'
        #     [nrt'\"[]\]
    
        $myparser si:void_state_push
        $myparser si:next_char \134
        $myparser si:voidvoid_part
        $myparser si:next_class nrt'\42\133\135\134
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'CharUnescaped'
    #
    
    proc sym_CharUnescaped {} { upvar 1 myparser myparser
        # x
        #     !
        #         '\'
        #     <dot>
    
        $myparser si:void_symbol_start CharUnescaped
        sequence_64
        $myparser si:void_leaf_symbol_end CharUnescaped
        return
    }
    
    proc sequence_64 {} { upvar 1 myparser myparser
        # x
        #     !
        #         '\'
        #     <dot>
    
        $myparser si:void_state_push
        notahead_61
        $myparser si:voidvoid_part
        $myparser i_input_next dot
        $myparser si:void_state_merge
        return
    }
    
    proc notahead_61 {} { upvar 1 myparser myparser
        # !
        #     '\'
    
        $myparser i_loc_push
        $myparser si:next_char \134
        $myparser si:void_notahead_exit
        return
    }
    
    #
    # leaf Symbol 'CharUnicode'
    #
    
    proc sym_CharUnicode {} { upvar 1 myparser myparser
        # x
        #     "\u"
        #     <xdigit>
        #     ?
        #         x
        #             <xdigit>
        #             ?
        #                 x
        #                     <xdigit>
        #                     ?
        #                         <xdigit>
    
        $myparser si:void_symbol_start CharUnicode
        sequence_82
        $myparser si:void_leaf_symbol_end CharUnicode
        return
    }
    
    proc sequence_82 {} { upvar 1 myparser myparser
        # x
        #     "\u"
        #     <xdigit>
        #     ?
        #         x
        #             <xdigit>
        #             ?
        #                 x
        #                     <xdigit>
        #                     ?
        #                         <xdigit>
    
        $myparser si:void_state_push
        $myparser si:next_str \134u
        $myparser si:voidvoid_part
        $myparser si:next_xdigit
        $myparser si:voidvoid_part
        optional_80
        $myparser si:void_state_merge
        return
    }
    
    proc optional_80 {} { upvar 1 myparser myparser
        # ?
        #     x
        #         <xdigit>
        #         ?
        #             x
        #                 <xdigit>
        #                 ?
        #                     <xdigit>
    
        $myparser si:void2_state_push
        sequence_78
        $myparser si:void_state_merge_ok
        return
    }
    
    proc sequence_78 {} { upvar 1 myparser myparser
        # x
        #     <xdigit>
        #     ?
        #         x
        #             <xdigit>
        #             ?
        #                 <xdigit>
    
        $myparser si:void_state_push
        $myparser si:next_xdigit
        $myparser si:voidvoid_part
        optional_76
        $myparser si:void_state_merge
        return
    }
    
    proc optional_76 {} { upvar 1 myparser myparser
        # ?
        #     x
        #         <xdigit>
        #         ?
        #             <xdigit>
    
        $myparser si:void2_state_push
        sequence_74
        $myparser si:void_state_merge_ok
        return
    }
    
    proc sequence_74 {} { upvar 1 myparser myparser
        # x
        #     <xdigit>
        #     ?
        #         <xdigit>
    
        $myparser si:void_state_push
        $myparser si:next_xdigit
        $myparser si:voidvoid_part
        optional_72
        $myparser si:void_state_merge
        return
    }
    
    proc optional_72 {} { upvar 1 myparser myparser
        # ?
        #     <xdigit>
    
        $myparser si:void2_state_push
        $myparser si:next_xdigit
        $myparser si:void_state_merge_ok
        return
    }
    
    #
    # value Symbol 'Class'
    #
    
    proc sym_Class {} { upvar 1 myparser myparser
        # x
        #     (OPENB)
        #     *
        #         x
        #             !
        #                 (CLOSEB)
        #             (Range)
        #     (CLOSEB)
        #     (WHITESPACE)
    
        $myparser si:value_symbol_start Class
        sequence_96
        $myparser si:reduce_symbol_end Class
        return
    }
    
    proc sequence_96 {} { upvar 1 myparser myparser
        # x
        #     (OPENB)
        #     *
        #         x
        #             !
        #                 (CLOSEB)
        #             (Range)
        #     (CLOSEB)
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        sym_OPENB
        $myparser si:voidvalue_part
        kleene_92
        $myparser si:valuevalue_part
        sym_CLOSEB
        $myparser si:valuevalue_part
        sym_WHITESPACE
        $myparser si:value_state_merge
        return
    }
    
    proc kleene_92 {} { upvar 1 myparser myparser
        # *
        #     x
        #         !
        #             (CLOSEB)
        #         (Range)
    
        while {1} {
            $myparser si:void2_state_push
        sequence_90
            $myparser si:kleene_close
        }
        return
    }
    
    proc sequence_90 {} { upvar 1 myparser myparser
        # x
        #     !
        #         (CLOSEB)
        #     (Range)
    
        $myparser si:void_state_push
        notahead_87
        $myparser si:voidvalue_part
        sym_Range
        $myparser si:value_state_merge
        return
    }
    
    proc notahead_87 {} { upvar 1 myparser myparser
        # !
        #     (CLOSEB)
    
        $myparser i_loc_push
        sym_CLOSEB
        $myparser si:void_notahead_exit
        return
    }
    
    #
    # void Symbol 'CLOSE'
    #
    
    proc sym_CLOSE {} { upvar 1 myparser myparser
        # x
        #     '\)'
        #     (WHITESPACE)
    
        $myparser si:void_void_symbol_start CLOSE
        sequence_101
        $myparser si:void_clear_symbol_end CLOSE
        return
    }
    
    proc sequence_101 {} { upvar 1 myparser myparser
        # x
        #     '\)'
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char \51
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # void Symbol 'CLOSEB'
    #
    
    proc sym_CLOSEB {} { upvar 1 myparser myparser
        # ']'
    
        $myparser si:void_void_symbol_start CLOSEB
        $myparser si:next_char \135
        $myparser si:void_clear_symbol_end CLOSEB
        return
    }
    
    #
    # void Symbol 'COLON'
    #
    
    proc sym_COLON {} { upvar 1 myparser myparser
        # x
        #     ':'
        #     (WHITESPACE)
    
        $myparser si:void_void_symbol_start COLON
        sequence_108
        $myparser si:void_clear_symbol_end COLON
        return
    }
    
    proc sequence_108 {} { upvar 1 myparser myparser
        # x
        #     ':'
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char :
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # void Symbol 'COMMENT'
    #
    
    proc sym_COMMENT {} { upvar 1 myparser myparser
        # x
        #     '#'
        #     *
        #         x
        #             !
        #                 (EOL)
        #             <dot>
        #     (EOL)
    
        $myparser si:void_void_symbol_start COMMENT
        sequence_121
        $myparser si:void_clear_symbol_end COMMENT
        return
    }
    
    proc sequence_121 {} { upvar 1 myparser myparser
        # x
        #     '#'
        #     *
        #         x
        #             !
        #                 (EOL)
        #             <dot>
        #     (EOL)
    
        $myparser si:void_state_push
        $myparser si:next_char #
        $myparser si:voidvoid_part
        kleene_118
        $myparser si:voidvoid_part
        sym_EOL
        $myparser si:void_state_merge
        return
    }
    
    proc kleene_118 {} { upvar 1 myparser myparser
        # *
        #     x
        #         !
        #             (EOL)
        #         <dot>
    
        while {1} {
            $myparser si:void2_state_push
        sequence_116
            $myparser si:kleene_close
        }
        return
    }
    
    proc sequence_116 {} { upvar 1 myparser myparser
        # x
        #     !
        #         (EOL)
        #     <dot>
    
        $myparser si:void_state_push
        notahead_113
        $myparser si:voidvoid_part
        $myparser i_input_next dot
        $myparser si:void_state_merge
        return
    }
    
    proc notahead_113 {} { upvar 1 myparser myparser
        # !
        #     (EOL)
    
        $myparser i_loc_push
        sym_EOL
        $myparser si:void_notahead_exit
        return
    }
    
    #
    # leaf Symbol 'CONTROL'
    #
    
    proc sym_CONTROL {} { upvar 1 myparser myparser
        # x
        #     "<control>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start CONTROL
        sequence_126
        $myparser si:void_leaf_symbol_end CONTROL
        return
    }
    
    proc sequence_126 {} { upvar 1 myparser myparser
        # x
        #     "<control>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <control>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # void Symbol 'DAPOSTROPH'
    #
    
    proc sym_DAPOSTROPH {} { upvar 1 myparser myparser
        # '\"'
    
        $myparser si:void_void_symbol_start DAPOSTROPH
        $myparser si:next_char \42
        $myparser si:void_clear_symbol_end DAPOSTROPH
        return
    }
    
    #
    # leaf Symbol 'DDIGIT'
    #
    
    proc sym_DDIGIT {} { upvar 1 myparser myparser
        # x
        #     "<ddigit>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start DDIGIT
        sequence_133
        $myparser si:void_leaf_symbol_end DDIGIT
        return
    }
    
    proc sequence_133 {} { upvar 1 myparser myparser
        # x
        #     "<ddigit>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <ddigit>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # value Symbol 'Definition'
    #
    
    proc sym_Definition {} { upvar 1 myparser myparser
        # x
        #     ?
        #         (Attribute)
        #     (Identifier)
        #     (IS)
        #     (Expression)
        #     (SEMICOLON)
    
        $myparser si:value_symbol_start Definition
        sequence_143
        $myparser si:reduce_symbol_end Definition
        return
    }
    
    proc sequence_143 {} { upvar 1 myparser myparser
        # x
        #     ?
        #         (Attribute)
        #     (Identifier)
        #     (IS)
        #     (Expression)
        #     (SEMICOLON)
    
        $myparser si:value_state_push
        optional_137
        $myparser si:valuevalue_part
        sym_Identifier
        $myparser si:valuevalue_part
        sym_IS
        $myparser si:valuevalue_part
        sym_Expression
        $myparser si:valuevalue_part
        sym_SEMICOLON
        $myparser si:value_state_merge
        return
    }
    
    proc optional_137 {} { upvar 1 myparser myparser
        # ?
        #     (Attribute)
    
        $myparser si:void2_state_push
        sym_Attribute
        $myparser si:void_state_merge_ok
        return
    }
    
    #
    # leaf Symbol 'DIGIT'
    #
    
    proc sym_DIGIT {} { upvar 1 myparser myparser
        # x
        #     "<digit>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start DIGIT
        sequence_148
        $myparser si:void_leaf_symbol_end DIGIT
        return
    }
    
    proc sequence_148 {} { upvar 1 myparser myparser
        # x
        #     "<digit>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <digit>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'DOT'
    #
    
    proc sym_DOT {} { upvar 1 myparser myparser
        # x
        #     '.'
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start DOT
        sequence_153
        $myparser si:void_leaf_symbol_end DOT
        return
    }
    
    proc sequence_153 {} { upvar 1 myparser myparser
        # x
        #     '.'
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char .
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # void Symbol 'EOF'
    #
    
    proc sym_EOF {} { upvar 1 myparser myparser
        # !
        #     <dot>
    
        $myparser si:void_void_symbol_start EOF
        notahead_157
        $myparser si:void_clear_symbol_end EOF
        return
    }
    
    proc notahead_157 {} { upvar 1 myparser myparser
        # !
        #     <dot>
    
        $myparser i_loc_push
        $myparser i_input_next dot
        $myparser si:void_notahead_exit
        return
    }
    
    #
    # void Symbol 'EOL'
    #
    
    proc sym_EOL {} { upvar 1 myparser myparser
        # [\n\r]
    
        $myparser si:void_void_symbol_start EOL
        $myparser si:next_class \n\r
        $myparser si:void_clear_symbol_end EOL
        return
    }
    
    #
    # value Symbol 'Expression'
    #
    
    proc sym_Expression {} { upvar 1 myparser myparser
        # x
        #     (Sequence)
        #     *
        #         x
        #             (SLASH)
        #             (Sequence)
    
        $myparser si:value_symbol_start Expression
        sequence_169
        $myparser si:reduce_symbol_end Expression
        return
    }
    
    proc sequence_169 {} { upvar 1 myparser myparser
        # x
        #     (Sequence)
        #     *
        #         x
        #             (SLASH)
        #             (Sequence)
    
        $myparser si:value_state_push
        sym_Sequence
        $myparser si:valuevalue_part
        kleene_167
        $myparser si:value_state_merge
        return
    }
    
    proc kleene_167 {} { upvar 1 myparser myparser
        # *
        #     x
        #         (SLASH)
        #         (Sequence)
    
        while {1} {
            $myparser si:void2_state_push
        sequence_165
            $myparser si:kleene_close
        }
        return
    }
    
    proc sequence_165 {} { upvar 1 myparser myparser
        # x
        #     (SLASH)
        #     (Sequence)
    
        $myparser si:void_state_push
        sym_SLASH
        $myparser si:voidvalue_part
        sym_Sequence
        $myparser si:value_state_merge
        return
    }
    
    #
    # void Symbol 'Final'
    #
    
    proc sym_Final {} { upvar 1 myparser myparser
        # x
        #     "END"
        #     (WHITESPACE)
        #     (SEMICOLON)
        #     (WHITESPACE)
    
        $myparser si:void_void_symbol_start Final
        sequence_176
        $myparser si:void_clear_symbol_end Final
        return
    }
    
    proc sequence_176 {} { upvar 1 myparser myparser
        # x
        #     "END"
        #     (WHITESPACE)
        #     (SEMICOLON)
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str END
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:voidvoid_part
        sym_SEMICOLON
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # value Symbol 'Grammar'
    #
    
    proc sym_Grammar {} { upvar 1 myparser myparser
        # x
        #     (WHITESPACE)
        #     (Header)
        #     *
        #         (Definition)
        #     (Final)
        #     (EOF)
    
        $myparser si:value_symbol_start Grammar
        sequence_186
        $myparser si:reduce_symbol_end Grammar
        return
    }
    
    proc sequence_186 {} { upvar 1 myparser myparser
        # x
        #     (WHITESPACE)
        #     (Header)
        #     *
        #         (Definition)
        #     (Final)
        #     (EOF)
    
        $myparser si:void_state_push
        sym_WHITESPACE
        $myparser si:voidvalue_part
        sym_Header
        $myparser si:valuevalue_part
        kleene_182
        $myparser si:valuevalue_part
        sym_Final
        $myparser si:valuevalue_part
        sym_EOF
        $myparser si:value_state_merge
        return
    }
    
    proc kleene_182 {} { upvar 1 myparser myparser
        # *
        #     (Definition)
    
        while {1} {
            $myparser si:void2_state_push
        sym_Definition
            $myparser si:kleene_close
        }
        return
    }
    
    #
    # leaf Symbol 'GRAPH'
    #
    
    proc sym_GRAPH {} { upvar 1 myparser myparser
        # x
        #     "<graph>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start GRAPH
        sequence_191
        $myparser si:void_leaf_symbol_end GRAPH
        return
    }
    
    proc sequence_191 {} { upvar 1 myparser myparser
        # x
        #     "<graph>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <graph>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # value Symbol 'Header'
    #
    
    proc sym_Header {} { upvar 1 myparser myparser
        # x
        #     (PEG)
        #     (Identifier)
        #     (StartExpr)
    
        $myparser si:value_symbol_start Header
        sequence_197
        $myparser si:reduce_symbol_end Header
        return
    }
    
    proc sequence_197 {} { upvar 1 myparser myparser
        # x
        #     (PEG)
        #     (Identifier)
        #     (StartExpr)
    
        $myparser si:void_state_push
        sym_PEG
        $myparser si:voidvalue_part
        sym_Identifier
        $myparser si:valuevalue_part
        sym_StartExpr
        $myparser si:value_state_merge
        return
    }
    
    #
    # leaf Symbol 'Ident'
    #
    
    proc sym_Ident {} { upvar 1 myparser myparser
        # x
        #     /
        #         [_:]
        #         <alpha>
        #     *
        #         /
        #             [_:]
        #             <alnum>
    
        $myparser si:void_symbol_start Ident
        sequence_210
        $myparser si:void_leaf_symbol_end Ident
        return
    }
    
    proc sequence_210 {} { upvar 1 myparser myparser
        # x
        #     /
        #         [_:]
        #         <alpha>
        #     *
        #         /
        #             [_:]
        #             <alnum>
    
        $myparser si:void_state_push
        choice_202
        $myparser si:voidvoid_part
        kleene_208
        $myparser si:void_state_merge
        return
    }
    
    proc choice_202 {} { upvar 1 myparser myparser
        # /
        #     [_:]
        #     <alpha>
    
        $myparser si:void_state_push
        $myparser si:next_class _:
        $myparser si:voidvoid_branch
        $myparser si:next_alpha
        $myparser si:void_state_merge
        return
    }
    
    proc kleene_208 {} { upvar 1 myparser myparser
        # *
        #     /
        #         [_:]
        #         <alnum>
    
        while {1} {
            $myparser si:void2_state_push
        choice_206
            $myparser si:kleene_close
        }
        return
    }
    
    proc choice_206 {} { upvar 1 myparser myparser
        # /
        #     [_:]
        #     <alnum>
    
        $myparser si:void_state_push
        $myparser si:next_class _:
        $myparser si:voidvoid_branch
        $myparser si:next_alnum
        $myparser si:void_state_merge
        return
    }
    
    #
    # value Symbol 'Identifier'
    #
    
    proc sym_Identifier {} { upvar 1 myparser myparser
        # x
        #     (Ident)
        #     (WHITESPACE)
    
        $myparser si:value_symbol_start Identifier
        sequence_215
        $myparser si:reduce_symbol_end Identifier
        return
    }
    
    proc sequence_215 {} { upvar 1 myparser myparser
        # x
        #     (Ident)
        #     (WHITESPACE)
    
        $myparser si:value_state_push
        sym_Ident
        $myparser si:valuevalue_part
        sym_WHITESPACE
        $myparser si:value_state_merge
        return
    }
    
    #
    # void Symbol 'IS'
    #
    
    proc sym_IS {} { upvar 1 myparser myparser
        # x
        #     "<-"
        #     (WHITESPACE)
    
        $myparser si:void_void_symbol_start IS
        sequence_220
        $myparser si:void_clear_symbol_end IS
        return
    }
    
    proc sequence_220 {} { upvar 1 myparser myparser
        # x
        #     "<-"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <-
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'LEAF'
    #
    
    proc sym_LEAF {} { upvar 1 myparser myparser
        # x
        #     "leaf"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start LEAF
        sequence_225
        $myparser si:void_leaf_symbol_end LEAF
        return
    }
    
    proc sequence_225 {} { upvar 1 myparser myparser
        # x
        #     "leaf"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str leaf
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # value Symbol 'Literal'
    #
    
    proc sym_Literal {} { upvar 1 myparser myparser
        # /
        #     x
        #         (APOSTROPH)
        #         *
        #             x
        #                 !
        #                     (APOSTROPH)
        #                 (Char)
        #         (APOSTROPH)
        #         (WHITESPACE)
        #     x
        #         (DAPOSTROPH)
        #         *
        #             x
        #                 !
        #                     (DAPOSTROPH)
        #                 (Char)
        #         (DAPOSTROPH)
        #         (WHITESPACE)
    
        $myparser si:value_symbol_start Literal
        choice_254
        $myparser si:reduce_symbol_end Literal
        return
    }
    
    proc choice_254 {} { upvar 1 myparser myparser
        # /
        #     x
        #         (APOSTROPH)
        #         *
        #             x
        #                 !
        #                     (APOSTROPH)
        #                 (Char)
        #         (APOSTROPH)
        #         (WHITESPACE)
        #     x
        #         (DAPOSTROPH)
        #         *
        #             x
        #                 !
        #                     (DAPOSTROPH)
        #                 (Char)
        #         (DAPOSTROPH)
        #         (WHITESPACE)
    
        $myparser si:value_state_push
        sequence_239
        $myparser si:valuevalue_branch
        sequence_252
        $myparser si:value_state_merge
        return
    }
    
    proc sequence_239 {} { upvar 1 myparser myparser
        # x
        #     (APOSTROPH)
        #     *
        #         x
        #             !
        #                 (APOSTROPH)
        #             (Char)
        #     (APOSTROPH)
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        sym_APOSTROPH
        $myparser si:voidvalue_part
        kleene_235
        $myparser si:valuevalue_part
        sym_APOSTROPH
        $myparser si:valuevalue_part
        sym_WHITESPACE
        $myparser si:value_state_merge
        return
    }
    
    proc kleene_235 {} { upvar 1 myparser myparser
        # *
        #     x
        #         !
        #             (APOSTROPH)
        #         (Char)
    
        while {1} {
            $myparser si:void2_state_push
        sequence_233
            $myparser si:kleene_close
        }
        return
    }
    
    proc sequence_233 {} { upvar 1 myparser myparser
        # x
        #     !
        #         (APOSTROPH)
        #     (Char)
    
        $myparser si:void_state_push
        notahead_230
        $myparser si:voidvalue_part
        sym_Char
        $myparser si:value_state_merge
        return
    }
    
    proc notahead_230 {} { upvar 1 myparser myparser
        # !
        #     (APOSTROPH)
    
        $myparser i_loc_push
        sym_APOSTROPH
        $myparser si:void_notahead_exit
        return
    }
    
    proc sequence_252 {} { upvar 1 myparser myparser
        # x
        #     (DAPOSTROPH)
        #     *
        #         x
        #             !
        #                 (DAPOSTROPH)
        #             (Char)
        #     (DAPOSTROPH)
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        sym_DAPOSTROPH
        $myparser si:voidvalue_part
        kleene_248
        $myparser si:valuevalue_part
        sym_DAPOSTROPH
        $myparser si:valuevalue_part
        sym_WHITESPACE
        $myparser si:value_state_merge
        return
    }
    
    proc kleene_248 {} { upvar 1 myparser myparser
        # *
        #     x
        #         !
        #             (DAPOSTROPH)
        #         (Char)
    
        while {1} {
            $myparser si:void2_state_push
        sequence_246
            $myparser si:kleene_close
        }
        return
    }
    
    proc sequence_246 {} { upvar 1 myparser myparser
        # x
        #     !
        #         (DAPOSTROPH)
        #     (Char)
    
        $myparser si:void_state_push
        notahead_243
        $myparser si:voidvalue_part
        sym_Char
        $myparser si:value_state_merge
        return
    }
    
    proc notahead_243 {} { upvar 1 myparser myparser
        # !
        #     (DAPOSTROPH)
    
        $myparser i_loc_push
        sym_DAPOSTROPH
        $myparser si:void_notahead_exit
        return
    }
    
    #
    # leaf Symbol 'LOWER'
    #
    
    proc sym_LOWER {} { upvar 1 myparser myparser
        # x
        #     "<lower>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start LOWER
        sequence_259
        $myparser si:void_leaf_symbol_end LOWER
        return
    }
    
    proc sequence_259 {} { upvar 1 myparser myparser
        # x
        #     "<lower>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <lower>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'NOT'
    #
    
    proc sym_NOT {} { upvar 1 myparser myparser
        # x
        #     '!'
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start NOT
        sequence_264
        $myparser si:void_leaf_symbol_end NOT
        return
    }
    
    proc sequence_264 {} { upvar 1 myparser myparser
        # x
        #     '!'
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char !
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # void Symbol 'OPEN'
    #
    
    proc sym_OPEN {} { upvar 1 myparser myparser
        # x
        #     '\('
        #     (WHITESPACE)
    
        $myparser si:void_void_symbol_start OPEN
        sequence_269
        $myparser si:void_clear_symbol_end OPEN
        return
    }
    
    proc sequence_269 {} { upvar 1 myparser myparser
        # x
        #     '\('
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char \50
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # void Symbol 'OPENB'
    #
    
    proc sym_OPENB {} { upvar 1 myparser myparser
        # '['
    
        $myparser si:void_void_symbol_start OPENB
        $myparser si:next_char \133
        $myparser si:void_clear_symbol_end OPENB
        return
    }
    
    #
    # void Symbol 'PEG'
    #
    
    proc sym_PEG {} { upvar 1 myparser myparser
        # x
        #     "PEG"
        #     !
        #         /
        #             [_:]
        #             <alnum>
        #     (WHITESPACE)
    
        $myparser si:void_void_symbol_start PEG
        sequence_281
        $myparser si:void_clear_symbol_end PEG
        return
    }
    
    proc sequence_281 {} { upvar 1 myparser myparser
        # x
        #     "PEG"
        #     !
        #         /
        #             [_:]
        #             <alnum>
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str PEG
        $myparser si:voidvoid_part
        notahead_278
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    proc notahead_278 {} { upvar 1 myparser myparser
        # !
        #     /
        #         [_:]
        #         <alnum>
    
        $myparser i_loc_push
        choice_206
        $myparser si:void_notahead_exit
        return
    }
    
    #
    # leaf Symbol 'PLUS'
    #
    
    proc sym_PLUS {} { upvar 1 myparser myparser
        # x
        #     '+'
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start PLUS
        sequence_286
        $myparser si:void_leaf_symbol_end PLUS
        return
    }
    
    proc sequence_286 {} { upvar 1 myparser myparser
        # x
        #     '+'
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char +
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # value Symbol 'Prefix'
    #
    
    proc sym_Prefix {} { upvar 1 myparser myparser
        # x
        #     ?
        #         /
        #             (AND)
        #             (NOT)
        #     (Suffix)
    
        $myparser si:value_symbol_start Prefix
        sequence_296
        $myparser si:reduce_symbol_end Prefix
        return
    }
    
    proc sequence_296 {} { upvar 1 myparser myparser
        # x
        #     ?
        #         /
        #             (AND)
        #             (NOT)
        #     (Suffix)
    
        $myparser si:value_state_push
        optional_293
        $myparser si:valuevalue_part
        sym_Suffix
        $myparser si:value_state_merge
        return
    }
    
    proc optional_293 {} { upvar 1 myparser myparser
        # ?
        #     /
        #         (AND)
        #         (NOT)
    
        $myparser si:void2_state_push
        choice_291
        $myparser si:void_state_merge_ok
        return
    }
    
    proc choice_291 {} { upvar 1 myparser myparser
        # /
        #     (AND)
        #     (NOT)
    
        $myparser si:value_state_push
        sym_AND
        $myparser si:valuevalue_branch
        sym_NOT
        $myparser si:value_state_merge
        return
    }
    
    #
    # value Symbol 'Primary'
    #
    
    proc sym_Primary {} { upvar 1 myparser myparser
        # /
        #     (ALNUM)
        #     (ALPHA)
        #     (ASCII)
        #     (CONTROL)
        #     (DDIGIT)
        #     (DIGIT)
        #     (GRAPH)
        #     (LOWER)
        #     (PRINTABLE)
        #     (PUNCT)
        #     (SPACE)
        #     (UPPER)
        #     (WORDCHAR)
        #     (XDIGIT)
        #     (Identifier)
        #     x
        #         (OPEN)
        #         (Expression)
        #         (CLOSE)
        #     (Literal)
        #     (Class)
        #     (DOT)
    
        $myparser si:value_symbol_start Primary
        choice_322
        $myparser si:reduce_symbol_end Primary
        return
    }
    
    proc choice_322 {} { upvar 1 myparser myparser
        # /
        #     (ALNUM)
        #     (ALPHA)
        #     (ASCII)
        #     (CONTROL)
        #     (DDIGIT)
        #     (DIGIT)
        #     (GRAPH)
        #     (LOWER)
        #     (PRINTABLE)
        #     (PUNCT)
        #     (SPACE)
        #     (UPPER)
        #     (WORDCHAR)
        #     (XDIGIT)
        #     (Identifier)
        #     x
        #         (OPEN)
        #         (Expression)
        #         (CLOSE)
        #     (Literal)
        #     (Class)
        #     (DOT)
    
        $myparser si:value_state_push
        sym_ALNUM
        $myparser si:valuevalue_branch
        sym_ALPHA
        $myparser si:valuevalue_branch
        sym_ASCII
        $myparser si:valuevalue_branch
        sym_CONTROL
        $myparser si:valuevalue_branch
        sym_DDIGIT
        $myparser si:valuevalue_branch
        sym_DIGIT
        $myparser si:valuevalue_branch
        sym_GRAPH
        $myparser si:valuevalue_branch
        sym_LOWER
        $myparser si:valuevalue_branch
        sym_PRINTABLE
        $myparser si:valuevalue_branch
        sym_PUNCT
        $myparser si:valuevalue_branch
        sym_SPACE
        $myparser si:valuevalue_branch
        sym_UPPER
        $myparser si:valuevalue_branch
        sym_WORDCHAR
        $myparser si:valuevalue_branch
        sym_XDIGIT
        $myparser si:valuevalue_branch
        sym_Identifier
        $myparser si:valuevalue_branch
        sequence_317
        $myparser si:valuevalue_branch
        sym_Literal
        $myparser si:valuevalue_branch
        sym_Class
        $myparser si:valuevalue_branch
        sym_DOT
        $myparser si:value_state_merge
        return
    }
    
    proc sequence_317 {} { upvar 1 myparser myparser
        # x
        #     (OPEN)
        #     (Expression)
        #     (CLOSE)
    
        $myparser si:void_state_push
        sym_OPEN
        $myparser si:voidvalue_part
        sym_Expression
        $myparser si:valuevalue_part
        sym_CLOSE
        $myparser si:value_state_merge
        return
    }
    
    #
    # leaf Symbol 'PRINTABLE'
    #
    
    proc sym_PRINTABLE {} { upvar 1 myparser myparser
        # x
        #     "<print>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start PRINTABLE
        sequence_327
        $myparser si:void_leaf_symbol_end PRINTABLE
        return
    }
    
    proc sequence_327 {} { upvar 1 myparser myparser
        # x
        #     "<print>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <print>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'PUNCT'
    #
    
    proc sym_PUNCT {} { upvar 1 myparser myparser
        # x
        #     "<punct>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start PUNCT
        sequence_332
        $myparser si:void_leaf_symbol_end PUNCT
        return
    }
    
    proc sequence_332 {} { upvar 1 myparser myparser
        # x
        #     "<punct>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <punct>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'QUESTION'
    #
    
    proc sym_QUESTION {} { upvar 1 myparser myparser
        # x
        #     '?'
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start QUESTION
        sequence_337
        $myparser si:void_leaf_symbol_end QUESTION
        return
    }
    
    proc sequence_337 {} { upvar 1 myparser myparser
        # x
        #     '?'
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char ?
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # value Symbol 'Range'
    #
    
    proc sym_Range {} { upvar 1 myparser myparser
        # /
        #     x
        #         (Char)
        #         (TO)
        #         (Char)
        #     (Char)
    
        $myparser si:value_symbol_start Range
        choice_346
        $myparser si:reduce_symbol_end Range
        return
    }
    
    proc choice_346 {} { upvar 1 myparser myparser
        # /
        #     x
        #         (Char)
        #         (TO)
        #         (Char)
        #     (Char)
    
        $myparser si:value_state_push
        sequence_343
        $myparser si:valuevalue_branch
        sym_Char
        $myparser si:value_state_merge
        return
    }
    
    proc sequence_343 {} { upvar 1 myparser myparser
        # x
        #     (Char)
        #     (TO)
        #     (Char)
    
        $myparser si:value_state_push
        sym_Char
        $myparser si:valuevalue_part
        sym_TO
        $myparser si:valuevalue_part
        sym_Char
        $myparser si:value_state_merge
        return
    }
    
    #
    # void Symbol 'SEMICOLON'
    #
    
    proc sym_SEMICOLON {} { upvar 1 myparser myparser
        # x
        #     ';'
        #     (WHITESPACE)
    
        $myparser si:void_void_symbol_start SEMICOLON
        sequence_351
        $myparser si:void_clear_symbol_end SEMICOLON
        return
    }
    
    proc sequence_351 {} { upvar 1 myparser myparser
        # x
        #     ';'
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char \73
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # value Symbol 'Sequence'
    #
    
    proc sym_Sequence {} { upvar 1 myparser myparser
        # +
        #     (Prefix)
    
        $myparser si:value_symbol_start Sequence
        poskleene_355
        $myparser si:reduce_symbol_end Sequence
        return
    }
    
    proc poskleene_355 {} { upvar 1 myparser myparser
        # +
        #     (Prefix)
    
        $myparser i_loc_push
        sym_Prefix
        $myparser si:kleene_abort
        while {1} {
            $myparser si:void2_state_push
        sym_Prefix
            $myparser si:kleene_close
        }
        return
    }
    
    #
    # void Symbol 'SLASH'
    #
    
    proc sym_SLASH {} { upvar 1 myparser myparser
        # x
        #     '/'
        #     (WHITESPACE)
    
        $myparser si:void_void_symbol_start SLASH
        sequence_360
        $myparser si:void_clear_symbol_end SLASH
        return
    }
    
    proc sequence_360 {} { upvar 1 myparser myparser
        # x
        #     '/'
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char /
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'SPACE'
    #
    
    proc sym_SPACE {} { upvar 1 myparser myparser
        # x
        #     "<space>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start SPACE
        sequence_365
        $myparser si:void_leaf_symbol_end SPACE
        return
    }
    
    proc sequence_365 {} { upvar 1 myparser myparser
        # x
        #     "<space>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <space>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'STAR'
    #
    
    proc sym_STAR {} { upvar 1 myparser myparser
        # x
        #     '*'
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start STAR
        sequence_370
        $myparser si:void_leaf_symbol_end STAR
        return
    }
    
    proc sequence_370 {} { upvar 1 myparser myparser
        # x
        #     '*'
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_char *
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # value Symbol 'StartExpr'
    #
    
    proc sym_StartExpr {} { upvar 1 myparser myparser
        # x
        #     (OPEN)
        #     (Expression)
        #     (CLOSE)
    
        $myparser si:value_symbol_start StartExpr
        sequence_317
        $myparser si:reduce_symbol_end StartExpr
        return
    }
    
    #
    # value Symbol 'Suffix'
    #
    
    proc sym_Suffix {} { upvar 1 myparser myparser
        # x
        #     (Primary)
        #     ?
        #         /
        #             (QUESTION)
        #             (STAR)
        #             (PLUS)
    
        $myparser si:value_symbol_start Suffix
        sequence_386
        $myparser si:reduce_symbol_end Suffix
        return
    }
    
    proc sequence_386 {} { upvar 1 myparser myparser
        # x
        #     (Primary)
        #     ?
        #         /
        #             (QUESTION)
        #             (STAR)
        #             (PLUS)
    
        $myparser si:value_state_push
        sym_Primary
        $myparser si:valuevalue_part
        optional_384
        $myparser si:value_state_merge
        return
    }
    
    proc optional_384 {} { upvar 1 myparser myparser
        # ?
        #     /
        #         (QUESTION)
        #         (STAR)
        #         (PLUS)
    
        $myparser si:void2_state_push
        choice_382
        $myparser si:void_state_merge_ok
        return
    }
    
    proc choice_382 {} { upvar 1 myparser myparser
        # /
        #     (QUESTION)
        #     (STAR)
        #     (PLUS)
    
        $myparser si:value_state_push
        sym_QUESTION
        $myparser si:valuevalue_branch
        sym_STAR
        $myparser si:valuevalue_branch
        sym_PLUS
        $myparser si:value_state_merge
        return
    }
    
    #
    # void Symbol 'TO'
    #
    
    proc sym_TO {} { upvar 1 myparser myparser
        # '-'
    
        $myparser si:void_void_symbol_start TO
        $myparser si:next_char -
        $myparser si:void_clear_symbol_end TO
        return
    }
    
    #
    # leaf Symbol 'UPPER'
    #
    
    proc sym_UPPER {} { upvar 1 myparser myparser
        # x
        #     "<upper>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start UPPER
        sequence_393
        $myparser si:void_leaf_symbol_end UPPER
        return
    }
    
    proc sequence_393 {} { upvar 1 myparser myparser
        # x
        #     "<upper>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <upper>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'VOID'
    #
    
    proc sym_VOID {} { upvar 1 myparser myparser
        # x
        #     "void"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start VOID
        sequence_398
        $myparser si:void_leaf_symbol_end VOID
        return
    }
    
    proc sequence_398 {} { upvar 1 myparser myparser
        # x
        #     "void"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str void
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # void Symbol 'WHITESPACE'
    #
    
    proc sym_WHITESPACE {} { upvar 1 myparser myparser
        # *
        #     /
        #         <space>
        #         (COMMENT)
    
        $myparser si:void_void_symbol_start WHITESPACE
        kleene_405
        $myparser si:void_clear_symbol_end WHITESPACE
        return
    }
    
    proc kleene_405 {} { upvar 1 myparser myparser
        # *
        #     /
        #         <space>
        #         (COMMENT)
    
        while {1} {
            $myparser si:void2_state_push
        choice_403
            $myparser si:kleene_close
        }
        return
    }
    
    proc choice_403 {} { upvar 1 myparser myparser
        # /
        #     <space>
        #     (COMMENT)
    
        $myparser si:void_state_push
        $myparser si:next_space
        $myparser si:voidvoid_branch
        sym_COMMENT
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'WORDCHAR'
    #
    
    proc sym_WORDCHAR {} { upvar 1 myparser myparser
        # x
        #     "<wordchar>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start WORDCHAR
        sequence_410
        $myparser si:void_leaf_symbol_end WORDCHAR
        return
    }
    
    proc sequence_410 {} { upvar 1 myparser myparser
        # x
        #     "<wordchar>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <wordchar>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    #
    # leaf Symbol 'XDIGIT'
    #
    
    proc sym_XDIGIT {} { upvar 1 myparser myparser
        # x
        #     "<xdigit>"
        #     (WHITESPACE)
    
        $myparser si:void_symbol_start XDIGIT
        sequence_415
        $myparser si:void_leaf_symbol_end XDIGIT
        return
    }
    
    proc sequence_415 {} { upvar 1 myparser myparser
        # x
        #     "<xdigit>"
        #     (WHITESPACE)
    
        $myparser si:void_state_push
        $myparser si:next_str <xdigit>
        $myparser si:voidvoid_part
        sym_WHITESPACE
        $myparser si:void_state_merge
        return
    }
    
    ## END of GENERATED CODE. DO NOT EDIT.
    # # ## ### ###### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::parse::peg_tcl 1.0.1
return