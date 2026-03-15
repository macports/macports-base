[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum][vset base][example {
    critcl::cproc hello {bytes x} void {
        /* critcl_bytes x (.s, .len, .o); */
        printf("hello world, with %d bytes \n data: ", x.len);
        for (i = 0; i < x.len; i++) {
            printf(" %02x", x.s[i]);
            if (i % 16 == 15) printf ("\ndata: ");
        }
        if (i % 16 != 0) printf ("\n");
    }
}][vset rebuild]

[enum] To deal with strings holding binary data use the type [type bytes]. It ensures that
the function sees the proper binary data, and not how Tcl is encoding it internally, as
the string types would.

[list_end]
