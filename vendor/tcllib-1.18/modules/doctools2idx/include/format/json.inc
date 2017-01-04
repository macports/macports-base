
[section {JSON notation of keyword indices}]

The JSON format used for keyword indices is a direct translation of
the [sectref {Keyword index serialization format}], mapping Tcl
dictionaries as JSON objects and Tcl lists as JSON arrays.

For example, the Tcl serialization

[example {
doctools::idx {
	label {Keyword Index}
	keywords {
		changelog  {changelog.man cvs.man}
		conversion {doctools.man docidx.man doctoc.man apps/dtplite.man mpexpand.man}
		cvs        cvs.man
	}
	references {
		apps/dtplite.man {manpage dtplite}
		changelog.man    {manpage doctools::changelog}
		cvs.man          {manpage doctools::cvs}
		docidx.man       {manpage doctools::idx}
		doctoc.man       {manpage doctools::toc}
		doctools.man     {manpage doctools}
		mpexpand.man     {manpage mpexpand}
	}
	title {}
}
}]

is equivalent to the JSON string

[example {
{
    "doctools::idx" : {
        "label"      : "Keyword Index",
        "keywords"   : {
            "changelog"  : ["changelog.man","cvs.man"],
            "conversion" : ["doctools.man","docidx.man","doctoc.man","apps\/dtplite.man","mpexpand.man"],
            "cvs"        : ["cvs.man"],
        },
        "references" : {
            "apps\/dtplite.man" : ["manpage","dtplite"],
            "changelog.man"     : ["manpage","doctools::changelog"],
            "cvs.man"           : ["manpage","doctools::cvs"],
            "docidx.man"        : ["manpage","doctools::idx"],
            "doctoc.man"        : ["manpage","doctools::toc"],
            "doctools.man"      : ["manpage","doctools"],
            "mpexpand.man"      : ["manpage","mpexpand"]
        },
        "title"      : ""
    }
}
}]
