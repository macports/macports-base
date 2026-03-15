[section {Changes for version 3.1.12}]
[list_begin enumerated]

[enum] Fixed issue 42. Clear ::errorInfo immediately after startup to
       prevent leakage of irrelevant (caught) errors into our script
       and confusing the usage code.

[enum] Fixed issue 40. Keep the order of libraries, and allow
       duplicates. Both are things which are occasionally required for
       proper linking.

[enum] Extended the utility package [package critcl::literals] to
       declare a cproc result-type for a pool.

[para] Further fixed the generated header to handle multiple inclusion.

[para] Bumped version to 1.1.

[enum] Fixed issue with utility package [package critcl::bitmap].

[para] Fixed the generated header to handle multiple inclusion.

[para] Bumped version to 1.0.1.

[enum] Created new utility package [package critcl::enum] for the
       quick and easy setup and use of mappings between C values
       and Tcl strings.

       Built on top of [package critcl::literals].

[enum] Added examples demonstrating the use of the utility packages
	[package critcl::literals],
	[package critcl::bitmap], and
	[package critcl::enum]

[list_end]
