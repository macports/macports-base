## macOS port of OpenBSD's [signify(1)](https://man.openbsd.org/signify.1)

This macOS port of OpenBSD's `signify` utility intentionally tracks upstream
OpenBSD sources directly, keeping only the smallest portability layer possible,
with the explicit #1 goal of making it as easy to audit as possible.

The latest version was tested on macOS 10.14.2 with Apple LLVM 9.1.0.

Older versions were previously tested as far back as OS X 10.6.8 with GCC 4.2.1.

Some of the OpenBSD-specific functions used by signify that previously required
portability shims were introduced in macOS 10.12(.1), and the corresponding
portability shims have been removed to keep the code as lean and easily
auditable as possible. If you need support for a newer signify on an older
macOS, feel free to open an issue.

Man page at https://man.openbsd.org/signify.1

`src/` is the result of `make fetch` (cvs get) and `make hash-helpers` (sed) as
of the time of the last commit.

If you don't trust me (or github) to not have modified anything in there to
insert a backdoor (why should you?), but you trust the upstream OpenBSD version,
then simply `rm -r src` it and audit the rest of the files that constitute
this "port". It's only ~200 lines, you can do it :)

### Easy (non-paranoid, 3rd party-trusting) installation

If you prefer [MacPorts](https://www.macports.org/):
```
$ sudo port install signify
```

If you prefer [Homebrew](http://brew.sh/):
```
$ brew install signify-osx
```

### Building it yourself

I've included a copy of the upstream signify source in this repo for
convenience, but you should probably fetch it yourself. Doing so requires a
working `cvs`, which does not come with new OS X systems by default, so
either install that first (with macports or homebrew or whatever), or just
use the src shipped in this repo (as I know it works).

To get the latest upstream source:
```
rm -r src
make fetch
```

and then the usual `make`, `make install`.

### Testing

To run the regression tests, `make test`.

### Keeping -current

To check for upstream updates, `make check-updates`. (requires working CVS)
