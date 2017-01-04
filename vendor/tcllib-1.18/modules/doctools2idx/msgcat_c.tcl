# -*- tcl -*-
package require    msgcat
namespace import ::msgcat::*

mcset c  docidx/char/syntax             {Bad character in string}
mcset c  docidx/cmd/illegal		{Illegal command "%1$s", not a docidx command}       ; # Details: cmdname
mcset c  docidx/cmd/nested		{Illegal use of "%1$s" as argument of other command} ; # Details: cmdname
mcset c  docidx/cmd/toomanyargs		{Too many args for "%1$s", at most %2$d allowed}     ; # Details: cmdname, max#args
mcset c  docidx/cmd/wrongargs		{Wrong#args for "%1$s", need at least %2$d}          ; # Details: cmdname, min#args
mcset c  docidx/eof/syntax              {Bad <eof>}
mcset c  docidx/include/path/notfound	{Include file "%1$s" not found}                      ; # Details: file name
mcset c  docidx/include/read-failed	{Unable to read include file "%1$s", %2$s}           ; # Details: file name and error msg
mcset c  docidx/include/syntax		{Errors in include file "%1$s"}
mcset c  docidx/plaintext		{Plain text beyond whitespace is not allowed}
mcset c  docidx/vset/varname/unknown	{Unknown variable "%1$s"}                            ; # Details: variable name

mcset c  docidx/index_begin/missing	{Expected [index_begin], not found}
mcset c  docidx/index_begin/syntax	{Unexpected [index_begin], not allowed here}
mcset c  docidx/index_end/missing	{Expected [index_end], not found}
mcset c  docidx/index_end/syntax	{Unexpected [index_end], not allowed here}
mcset c  docidx/key/missing		{Expected [key], not found}
mcset c  docidx/key/syntax		{Unexpected [key], not allowed here}

mcset c  docidx/ref/redef               {Bad redefinition of reference "%1$s", first (%2$s "%3$s"), now (%4$s "%5$s")}

package provide doctools::msgcat::idx::c 0.1
