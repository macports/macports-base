# -*- tcl -*-
package require    msgcat
namespace import ::msgcat::*

# The texts are in english because I have do not have enough knowledge
# of french to make the translation.

mcset fr docidx/char/syntax             {Bad character in string}
mcset fr docidx/cmd/illegal		{Illegal command "%1$s", not a docidx command}       ; # Details: cmdname
mcset fr docidx/cmd/nested		{Illegal use of "%1$s" as argument of other command} ; # Details: cmdname
mcset fr docidx/cmd/toomanyargs		{Too many args for "%1$s", at most %2$d allowed}     ; # Details: cmdname, max#args
mcset fr docidx/cmd/wrongargs		{Wrong#args for "%1$s", need at least %2$d}          ; # Details: cmdname, min#args
mcset fr docidx/eof/syntax              {Bad <eof>}
mcset fr docidx/include/path/notfound	{Include file "%1$s" not found}                      ; # Details: file name
mcset fr docidx/include/read-failed	{Unable to read include file "%1$s", %2$s}           ; # Details: file name and error msg
mcset fr docidx/include/syntax		{Errors in include file "%1$s"}
mcset fr docidx/plaintext		{Plain text beyond whitespace is not allowed}
mcset fr docidx/vset/varname/unknown	{Unknown variable "%1$s"}                            ; # Details: variable name

mcset fr docidx/index_begin/missing	{Expected [index_begin], not found}
mcset fr docidx/index_begin/syntax	{Unexpected [index_begin], not allowed here}
mcset fr docidx/index_end/missing	{Expected [index_end], not found}
mcset fr docidx/index_end/syntax	{Unexpected [index_end], not allowed here}
mcset fr docidx/key/missing		{Expected [key], not found}
mcset fr docidx/key/syntax		{Unexpected [key], not allowed here}

mcset fr docidx/ref/redef               {Bad redefinition of reference "%1$s", first (%2$s "%3$s"), now (%4$s "%5$s")}

package provide doctools::msgcat::idx::fr 0.1
