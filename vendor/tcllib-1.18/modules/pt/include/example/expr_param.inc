[example {
# -*- text -*-
# Parsing Expression Grammar 'TEMPLATE'.
# Generated for unknown, from file 'TEST'

#
# Grammar Start Expression
#

<<MAIN>>:
         call              sym_Expression
         halt

#
# value Symbol 'AddOp'
#

sym_AddOp:
# /
#     '-'
#     '+'

         symbol_restore    AddOp
  found! jump              found_7
         loc_push

         call              choice_5

   fail! value_clear
     ok! value_leaf        AddOp
         symbol_save       AddOp
         error_nonterminal AddOp
         loc_pop_discard

found_7:
     ok! ast_value_push
         return

choice_5:
# /
#     '-'
#     '+'

         error_clear

         loc_push
         error_push

         input_next        "t -"
     ok! test_char         "-"

         error_pop_merge
     ok! jump              oknoast_4

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t +"
     ok! test_char         "+"

         error_pop_merge
     ok! jump              oknoast_4

         loc_pop_rewind
         status_fail
         return

oknoast_4:
         loc_pop_discard
         return
#
# value Symbol 'Digit'
#

sym_Digit:
# /
#     '0'
#     '1'
#     '2'
#     '3'
#     '4'
#     '5'
#     '6'
#     '7'
#     '8'
#     '9'

         symbol_restore    Digit
  found! jump              found_22
         loc_push

         call              choice_20

   fail! value_clear
     ok! value_leaf        Digit
         symbol_save       Digit
         error_nonterminal Digit
         loc_pop_discard

found_22:
     ok! ast_value_push
         return

choice_20:
# /
#     '0'
#     '1'
#     '2'
#     '3'
#     '4'
#     '5'
#     '6'
#     '7'
#     '8'
#     '9'

         error_clear

         loc_push
         error_push

         input_next        "t 0"
     ok! test_char         "0"

         error_pop_merge
     ok! jump              oknoast_19

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t 1"
     ok! test_char         "1"

         error_pop_merge
     ok! jump              oknoast_19

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t 2"
     ok! test_char         "2"

         error_pop_merge
     ok! jump              oknoast_19

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t 3"
     ok! test_char         "3"

         error_pop_merge
     ok! jump              oknoast_19

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t 4"
     ok! test_char         "4"

         error_pop_merge
     ok! jump              oknoast_19

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t 5"
     ok! test_char         "5"

         error_pop_merge
     ok! jump              oknoast_19

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t 6"
     ok! test_char         "6"

         error_pop_merge
     ok! jump              oknoast_19

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t 7"
     ok! test_char         "7"

         error_pop_merge
     ok! jump              oknoast_19

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t 8"
     ok! test_char         "8"

         error_pop_merge
     ok! jump              oknoast_19

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t 9"
     ok! test_char         "9"

         error_pop_merge
     ok! jump              oknoast_19

         loc_pop_rewind
         status_fail
         return

oknoast_19:
         loc_pop_discard
         return
#
# value Symbol 'Expression'
#

sym_Expression:
# /
#     x
#         '\('
#         (Expression)
#         '\)'
#     x
#         (Factor)
#         *
#             x
#                 (MulOp)
#                 (Factor)

         symbol_restore    Expression
  found! jump              found_46
         loc_push
         ast_push

         call              choice_44

   fail! value_clear
     ok! value_reduce      Expression
         symbol_save       Expression
         error_nonterminal Expression
         ast_pop_rewind
         loc_pop_discard

found_46:
     ok! ast_value_push
         return

choice_44:
# /
#     x
#         '\('
#         (Expression)
#         '\)'
#     x
#         (Factor)
#         *
#             x
#                 (MulOp)
#                 (Factor)

         error_clear

         ast_push
         loc_push
         error_push

         call              sequence_27

         error_pop_merge
     ok! jump              ok_43

         ast_pop_rewind
         loc_pop_rewind
         ast_push
         loc_push
         error_push

         call              sequence_40

         error_pop_merge
     ok! jump              ok_43

         ast_pop_rewind
         loc_pop_rewind
         status_fail
         return

ok_43:
         ast_pop_discard
         loc_pop_discard
         return

sequence_27:
# x
#     '\('
#     (Expression)
#     '\)'

         loc_push
         error_clear

         error_push

         input_next        "t ("
     ok! test_char         "("

         error_pop_merge
   fail! jump              failednoast_29
         ast_push
         error_push

         call              sym_Expression

         error_pop_merge
   fail! jump              failed_28
         error_push

         input_next        "t )"
     ok! test_char         ")"

         error_pop_merge
   fail! jump              failed_28

         ast_pop_discard
         loc_pop_discard
         return

failed_28:
         ast_pop_rewind

failednoast_29:
         loc_pop_rewind
         return

sequence_40:
# x
#     (Factor)
#     *
#         x
#             (MulOp)
#             (Factor)

         ast_push
         loc_push
         error_clear

         error_push

         call              sym_Factor

         error_pop_merge
   fail! jump              failed_41
         error_push

         call              kleene_37

         error_pop_merge
   fail! jump              failed_41

         ast_pop_discard
         loc_pop_discard
         return

failed_41:
         ast_pop_rewind
         loc_pop_rewind
         return

kleene_37:
# *
#     x
#         (MulOp)
#         (Factor)

         loc_push
         error_push

         call              sequence_34

         error_pop_merge
   fail! jump              failed_38
         loc_pop_discard
         jump              kleene_37

failed_38:
         loc_pop_rewind
         status_ok
         return

sequence_34:
# x
#     (MulOp)
#     (Factor)

         ast_push
         loc_push
         error_clear

         error_push

         call              sym_MulOp

         error_pop_merge
   fail! jump              failed_35
         error_push

         call              sym_Factor

         error_pop_merge
   fail! jump              failed_35

         ast_pop_discard
         loc_pop_discard
         return

failed_35:
         ast_pop_rewind
         loc_pop_rewind
         return
#
# value Symbol 'Factor'
#

sym_Factor:
# x
#     (Term)
#     *
#         x
#             (AddOp)
#             (Term)

         symbol_restore    Factor
  found! jump              found_60
         loc_push
         ast_push

         call              sequence_57

   fail! value_clear
     ok! value_reduce      Factor
         symbol_save       Factor
         error_nonterminal Factor
         ast_pop_rewind
         loc_pop_discard

found_60:
     ok! ast_value_push
         return

sequence_57:
# x
#     (Term)
#     *
#         x
#             (AddOp)
#             (Term)

         ast_push
         loc_push
         error_clear

         error_push

         call              sym_Term

         error_pop_merge
   fail! jump              failed_58
         error_push

         call              kleene_54

         error_pop_merge
   fail! jump              failed_58

         ast_pop_discard
         loc_pop_discard
         return

failed_58:
         ast_pop_rewind
         loc_pop_rewind
         return

kleene_54:
# *
#     x
#         (AddOp)
#         (Term)

         loc_push
         error_push

         call              sequence_51

         error_pop_merge
   fail! jump              failed_55
         loc_pop_discard
         jump              kleene_54

failed_55:
         loc_pop_rewind
         status_ok
         return

sequence_51:
# x
#     (AddOp)
#     (Term)

         ast_push
         loc_push
         error_clear

         error_push

         call              sym_AddOp

         error_pop_merge
   fail! jump              failed_52
         error_push

         call              sym_Term

         error_pop_merge
   fail! jump              failed_52

         ast_pop_discard
         loc_pop_discard
         return

failed_52:
         ast_pop_rewind
         loc_pop_rewind
         return
#
# value Symbol 'MulOp'
#

sym_MulOp:
# /
#     '*'
#     '/'

         symbol_restore    MulOp
  found! jump              found_67
         loc_push

         call              choice_65

   fail! value_clear
     ok! value_leaf        MulOp
         symbol_save       MulOp
         error_nonterminal MulOp
         loc_pop_discard

found_67:
     ok! ast_value_push
         return

choice_65:
# /
#     '*'
#     '/'

         error_clear

         loc_push
         error_push

         input_next        "t *"
     ok! test_char         "*"

         error_pop_merge
     ok! jump              oknoast_64

         loc_pop_rewind
         loc_push
         error_push

         input_next        "t /"
     ok! test_char         "/"

         error_pop_merge
     ok! jump              oknoast_64

         loc_pop_rewind
         status_fail
         return

oknoast_64:
         loc_pop_discard
         return
#
# value Symbol 'Number'
#

sym_Number:
# x
#     ?
#         (Sign)
#     +
#         (Digit)

         symbol_restore    Number
  found! jump              found_80
         loc_push
         ast_push

         call              sequence_77

   fail! value_clear
     ok! value_reduce      Number
         symbol_save       Number
         error_nonterminal Number
         ast_pop_rewind
         loc_pop_discard

found_80:
     ok! ast_value_push
         return

sequence_77:
# x
#     ?
#         (Sign)
#     +
#         (Digit)

         ast_push
         loc_push
         error_clear

         error_push

         call              optional_70

         error_pop_merge
   fail! jump              failed_78
         error_push

         call              poskleene_73

         error_pop_merge
   fail! jump              failed_78

         ast_pop_discard
         loc_pop_discard
         return

failed_78:
         ast_pop_rewind
         loc_pop_rewind
         return

optional_70:
# ?
#     (Sign)

         loc_push
         error_push

         call              sym_Sign

         error_pop_merge
   fail! loc_pop_rewind
     ok! loc_pop_discard
         status_ok
         return

poskleene_73:
# +
#     (Digit)

         loc_push

         call              sym_Digit

   fail! jump              failed_74

loop_75:
         loc_pop_discard
         loc_push
         error_push

         call              sym_Digit

         error_pop_merge
     ok! jump              loop_75
         status_ok

failed_74:
         loc_pop_rewind
         return
#
# value Symbol 'Sign'
#

sym_Sign:
# /
#     '-'
#     '+'

         symbol_restore    Sign
  found! jump              found_86
         loc_push

         call              choice_5

   fail! value_clear
     ok! value_leaf        Sign
         symbol_save       Sign
         error_nonterminal Sign
         loc_pop_discard

found_86:
     ok! ast_value_push
         return
#
# value Symbol 'Term'
#

sym_Term:
# (Number)

         symbol_restore    Term
  found! jump              found_89
         loc_push
         ast_push

         call              sym_Number

   fail! value_clear
     ok! value_reduce      Term
         symbol_save       Term
         error_nonterminal Term
         ast_pop_rewind
         loc_pop_discard

found_89:
     ok! ast_value_push
         return

#
#
}]
