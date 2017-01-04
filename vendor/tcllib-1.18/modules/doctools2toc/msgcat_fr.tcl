# -*- tcl -*-
package require    msgcat
namespace import ::msgcat::*

# The texts are in english because I have do not have enough knowledge
# of french to make the translation.

mcset fr doctoc/char/syntax             {Bad character in string}
mcset fr doctoc/cmd/illegal		{Illegal command "%1$s", not a doctoc command}       ; # Details: cmdname
mcset fr doctoc/cmd/nested		{Illegal use of "%1$s" as argument of other command} ; # Details: cmdname
mcset fr doctoc/cmd/toomanyargs		{Too many args for "%1$s", at most %2$d allowed}     ; # Details: cmdname, max#args
mcset fr doctoc/cmd/wrongargs		{Wrong#args for "%1$s", need at least %2$d}          ; # Details: cmdname, min#args
mcset fr doctoc/eof/syntax              {Bad <eof>}
mcset fr doctoc/include/path/notfound	{Include file "%1$s" not found}                      ; # Details: file name
mcset fr doctoc/include/read-failed	{Unable to read include file "%1$s", %2$s}           ; # Details: file name and error msg
mcset fr doctoc/include/syntax		{Errors in include file "%1$s"}
mcset fr doctoc/plaintext		{Plain text beyond whitespace is not allowed}
mcset fr doctoc/vset/varname/unknown	{Unknown variable "%1$s"}                            ; # Details: variable name

mcset fr doctoc/division_end/missing	{Expected [division_end], not found}
mcset fr doctoc/division_end/syntax	{Unexpected [division_end], not allowed here}
mcset fr doctoc/division_start/syntax	{Expected [division_start], not found}
mcset fr doctoc/item/syntax		{Unexpected [item], not allowed here}
mcset fr doctoc/toc_begin/missing	{Expected [toc_begin], not found}
mcset fr doctoc/toc_begin/syntax	{Unexpected [toc_begin], not allowed here}
mcset fr doctoc/toc_end/missing		{Expected [toc_end], not found}
mcset fr doctoc/toc_end/syntax		{Unexpected [toc_end], not allowed here}

mcset fr doctoc/redef                   {Bad reuse of label "%1$s"}

package provide doctools::msgcat::toc::fr 0.1
