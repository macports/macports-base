# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Grammar for reading of PE grammars

## Parsing Expression Grammar 'pg::peg::grammar'.

# ### ### ### ######### ######### #########
## Package description

## It provides a single command returning the handle of a
## grammar container in which the grammar 'pg::peg::grammar'
## is stored. The container is usable by a PEG interpreter
## or other packages taking PE grammars.

# ### ### ### ######### ######### #########
## Requisites.
## - PEG container type

package require grammar::peg

namespace eval ::pg::peg::grammar {}

# ### ### ### ######### ######### #########
## API

proc ::pg::peg::grammar {} {
    return $grammar::gr
}

# ### ### ### ######### ######### #########
# ### ### ### ######### ######### #########
## Data and helpers.

namespace eval ::pg::peg::grammar {
    # Grammar container
    variable gr [::grammar::peg gr]
}

proc ::pg::peg::grammar::Start {pe} {
    variable gr
    $gr start $pe
    return
}

proc ::pg::peg::grammar::Define {mode nt pe} {
    variable gr
    $gr nonterminal add  $nt $pe
    $gr nonterminal mode $nt $mode
    return
}

# ### ### ### ######### ######### #########
## Initialization = Grammar definition
    
namespace eval ::pg::peg::grammar {
    Start  {n Grammar}

    Define leaf    ALNUM         {x {t <} {t a} {t l} {t n} {t u} {t m} {t >} {n SPACE}}
    Define leaf    ALPHA         {x {t <} {t a} {t l} {t p} {t h} {t a} {t >} {n SPACE}}
    Define leaf    AND           {x {t &} {n SPACE}}
    Define discard APOSTROPH     {t '}
    Define value   Attribute     {x {/ {n VOID} {n LEAF} {n MATCH}} {n COLON}}
    Define value   Char          {/ {n CharSpecial} {n CharOctalFull} {n CharOctalPart} {n CharUnicode} {n CharUnescaped}}
    Define match   CharOctalFull {x {t \134} {.. 0 2} {.. 0 7} {.. 0 7}}
    Define match   CharOctalPart {x {t \134} {.. 0 7} {? {.. 0 7}}}
    Define match   CharSpecial   {x {t \134} {/ {t n} {t r} {t t} {t '} {t \42} {t \133} {t \135} {t \134}}}
    Define match   CharUnescaped {x {! {t \134}} dot}
    Define match   CharUnicode   {x {t \134} {t u} {n HexDigit} {? {x {n HexDigit} {? {x {n HexDigit} {? {n HexDigit}}}}}}}
    Define value   Class         {x {n OPENB} {* {x {! {n CLOSEB}} {n Range}}} {n CLOSEB} {n SPACE}}
    Define discard CLOSE         {x {t \51} {n SPACE}}
    Define discard CLOSEB        {t \135}
    Define discard COLON         {x {t :} {n SPACE}}
    Define discard COMMENT       {x {t #} {* {x {! {n EOL}} dot}} {n EOL}}
    Define discard DAPOSTROPH    {t \42}
    Define value   Definition    {x {? {n Attribute}} {n Identifier} {n IS} {n Expression} {n SEMICOLON}}
    Define leaf    DOT           {x {t .} {n SPACE}}
    Define discard END           {x {t E} {t N} {t D} {n SPACE}}
    Define discard EOF           {! dot}
    Define discard EOL           {/ {x {t \n} {t \r}} {t \n} {t \r}}
    Define value   Expression    {x {n Sequence} {* {x {n SLASH} {n Sequence}}}}
    Define discard Final         {x {n END} {n SEMICOLON} {n SPACE}}
    Define value   Grammar       {x {n SPACE} {n Header} {+ {n Definition}} {n Final} {n EOF}}
    Define value   Header        {x {n PEG} {n Identifier} {n StartExpr}}
    Define discard HexDigit      {/ {.. 0 9} {.. a f} {.. A F}}
    Define match   Ident         {x {/ {t _} {t :} alpha} {* {/ {t _} {t :} alnum}}}
    Define value   Identifier    {x {n Ident} {n SPACE}}
    Define discard IS            {x {t <} {t -} {n SPACE}}
    Define leaf    LEAF          {x {t l} {t e} {t a} {t f} {n SPACE}}
    Define value   Literal       {/ {x {n APOSTROPH} {* {x {! {n APOSTROPH}} {n Char}}} {n APOSTROPH} {n SPACE}} {x {n DAPOSTROPH} {* {x {! {n DAPOSTROPH}} {n Char}}} {n DAPOSTROPH} {n SPACE}}}
    Define leaf    MATCH         {x {t m} {t a} {t t} {t c} {t h} {n SPACE}}
    Define leaf    NOT           {x {t !} {n SPACE}}
    Define discard OPEN          {x {t \50} {n SPACE}}
    Define discard OPENB         {t \133}
    Define discard PEG           {x {t P} {t E} {t G} {n SPACE}}
    Define leaf    PLUS          {x {t +} {n SPACE}}
    Define value   Prefix        {x {? {/ {n AND} {n NOT}}} {n Suffix}}
    Define value   Primary       {/ {n ALNUM} {n ALPHA} {n Identifier} {x {n OPEN} {n Expression} {n CLOSE}} {n Literal} {n Class} {n DOT}}
    Define leaf    QUESTION      {x {t ?} {n SPACE}}
    Define value   Range         {/ {x {n Char} {n TO} {n Char}} {n Char}}
    Define discard SEMICOLON     {x {t \73} {n SPACE}}
    Define value   Sequence      {+ {n Prefix}}
    Define discard SLASH         {x {t /} {n SPACE}}
    Define discard SPACE         {* {/ {t \40} {t \t} {n EOL} {n COMMENT}}}
    Define leaf    STAR          {x {t *} {n SPACE}}
    Define value   StartExpr     {x {n OPEN} {n Expression} {n CLOSE}}
    Define value   Suffix        {x {n Primary} {? {/ {n QUESTION} {n STAR} {n PLUS}}}}
    Define discard TO            {t -}
    Define leaf    VOID          {x {t v} {t o} {t i} {t d} {n SPACE}}
}

# ### ### ### ######### ######### #########
## Package Management - Ready

# @sak notprovided pg::peg::grammar
package provide pg::peg::grammar 0.1
    
