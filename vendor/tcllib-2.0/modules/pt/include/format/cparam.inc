
[section {C/PARAM code representation of parsing expression grammars}]

[include whatis_cparam_rawc.inc]
[para]

The bulk of such a framework has to be specified through the option
[option -template]. The additional options

[list_begin options]
[opt_def -fun-qualifier string]
[opt_def -main string]
[opt_def -namespace string]
[opt_def -prelude string]
[opt_def -self-command string]
[opt_def -state-decl string]
[opt_def -state-ref string]
[opt_def -string-varname string]
[list_end]

provide code snippets which help to glue framework and generated code
together. Their placeholders are in the [emph generated] code.

Further the options

[list_begin options]
[opt_def -indent integer]
[opt_def -comments boolean]
[list_end]

allow for the customization of the code indent (default none), and
whether to generate comments showing the parsing expressions a
function is for (default on).

[subsection Example]

We are forgoing an example of this representation, with apologies.
It would be way to large for this document.
