[subsection {Custom Types, Introduction}]

When writing bindings to external libraries [cmd critcl::cproc] is
usually the most convenient way of writing the lower layers. This is
however hampered by the fact that critcl on its own only supports a
few standard (arguably the most import) standard types, whereas the
functions we wish to bind most certainly will use much more, specific
to the library's function.

[para] The critcl commands [cmd argtype], [cmd resulttype] and their
adjuncts are provided to help here, by allowing a developer to extend
critcl's type system with custom conversions.

[para] This and the three following sections will demonstrate this,
from trivial to complex.

[para] The most trivial use is to create types which are aliases of
existing types, standard or other. As an alias it simply copies and
uses the conversion code from the referenced types.

[para] Our example is pulled from an incomplete project of mine, a
binding to [term {Jeffrey Kegler}]'s [term libmarpa] library managing
Earley parsers. Several custom types simply reflect the typedef's done
by the library, to make the [cmd critcl::cproc]s as self-documenting
as the underlying library functions themselves.

[example {
    critcl::argtype Marpa_Symbol_ID     = int
    critcl::argtype Marpa_Rule_ID       = int
    critcl::argtype Marpa_Rule_Int      = int
    critcl::argtype Marpa_Rank          = int
    critcl::argtype Marpa_Earleme       = int
    critcl::argtype Marpa_Earley_Set_ID = int

    ...

    method sym-rank: proc {
        Marpa_Symbol_ID sym
        Marpa_Rank      rank
    } Marpa_Rank {
        return marpa_g_symbol_rank_set (instance->grammar, sym, rank);
    }

    ...
}]
