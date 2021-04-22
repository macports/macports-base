
[section {JSON notation of tables of contents}]

The JSON format used for tables of contents is a direct translation of
the [sectref {ToC serialization format}], mapping Tcl dictionaries as
JSON objects and Tcl lists as JSON arrays.

For example, the Tcl serialization

[example {
doctools::toc {
    items {
        {reference {
	    desc {DocTools - Tables of Contents}
	     id introduction.man
	     label doctools::toc::introduction
	}}
	{division {
	     id processing.man
	     items {
	         {reference {
		     desc {doctoc serialization utilities}
		     id structure.man
		     label doctools::toc::structure
		 }}
		 {reference {
		     desc {Parsing text in doctoc format}
		     id parse.man
		     label doctools::toc::parse
		 }}
	     }
             label Processing
        }}
    }
    label {Table of Contents} 
    title TOC
}
}]

is equivalent to the JSON string

[example {
{
    "doctools::toc" : {
        "items" : [{
            "reference" : {
                "desc"  : "DocTools - Tables of Contents",
                "id"    : "introduction.man",
                "label" : "doctools::toc::introduction"
            }
        },{
            "division" : {
                "id"    : "processing.man",
                "items" : [{
                    "reference" : {
                        "desc"  : "doctoc serialization utilities",
                        "id"    : "structure.man",
                        "label" : "doctools::toc::structure"
                    }
                },{
                    "reference" : {
                        "desc"  : "Parsing text in doctoc format",
                        "id"    : "parse.man",
                        "label" : "doctools::toc::parse"
                    }
                }],
                "label" : "Processing"
            }
        }],
        "label" : "Table of Contents",
        "title" : "TOC"
    }
}
}]
