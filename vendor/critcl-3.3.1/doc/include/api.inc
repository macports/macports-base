
A short note ahead of the documentation: Instead of repeatedly talking
about
"a Tcl script with embbedded C code", or
"a Tcl script containing CriTcl commands",
we call such a script a [vset critcl_script].  A file containing a
[vset critcl_script] usually has the extension [const .tcl] or
[const .critcl].

[comment {
	Uncompleted docs for

	config -I ... - describe the options ...

	Undocumented commands ...

	c++command	-
}]

[subsection {Embedded C Code}]			[include include/api_embedc.inc]
[subsection {Stubs Table Management}]		[include include/api_stubs.inc]
[subsection {Package Meta Data}]		[include include/api_meta.inc]
[subsection {Control & Interface}]		[include include/api_control.inc]
[subsection {Introspection}]			[include include/api_introspection.inc]
[subsection {Build Management}]			[include include/api_bmgmt.inc]
[subsection {Result Cache Management}]		[include include/api_rcache.inc]
[subsection {Build Configuration}]		[include include/api_bconfig.inc]
[subsection {Tool API}]				[include include/api_tools.inc]
[subsection {Advanced: Embedded C Code}]	[include include/api_aembedc.inc]
[subsection {Custom Build Configuration}]	[include include/api_cbconfig.inc]
[subsection {Advanced: Location management}]	[include include/api_location.inc]
[subsection {Advanced: Diversions}]		[include include/api_diversions.inc]
[subsection {Advanced: File Generation}]	[include include/api_generation.inc]
