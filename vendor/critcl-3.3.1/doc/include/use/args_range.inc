[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum][vset base][example {
    critcl::cproc hello {{double > 5 < 22} x} void {
	/* double x, range 6-21; */
	printf("hello world, we have %f\n", x);
    }
}][vset rebuild]

[enum] When dealing with simple arguments whose range of legal values is limited to a single
continuous interval extend the base type with the necessary relations ([const >], [const >=],
[const <], and [const <=]) and limiting values.

[para][strong Note] that the limiting values have to be proper constant numbers acceptable by the
base type. Symbolic values are not accepted.

[para] Here the argument [arg x] of the changed function will reject all values outside of the
interval 6 to 21.

[list_end]
