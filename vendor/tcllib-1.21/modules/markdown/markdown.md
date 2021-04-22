# Markdown

*Markdown* is a Markdown to XHTML processor.  It supports the original 
basic syntax as defined by John Gruber on his homepage at [http://daringfireball.net/projects/markdown/syntax](http://daringfireball.net/projects/markdown/syntax).

# Markdown Dialect

Tcl-markdown is intended to support the same range of inputs and outputs
as John Gruber's original Markdown processor.

Common extensions are not supported at this time.

## Known Bugs

Per Markdown.mdtest, reflink text can contain brackets.   This input
should produce a link to the "/url/"; at present it does not
(see Tcl-markdown test mdtest-1.3):
```
With [embedded [brackets]] [b].

[b]: /url/
```

Simple reference links are ignored.  The following link should be
expanded, but it isn't (see Tcl-markdown test mdtest-1.4):

```
Simple link [this].

[this]: /url/
```

Oddly, a line beginning and ending with brackets can contain 
reference links within it.  The following links should be expanded,
but are not (see Tcl-markdown tests mdtest-1.5 and 1.6):

```
[Links can be [embedded][] in brackets]
[Links can be [embedded] in brackets]

[embedded]: /url/

```

Simple reflinks can have line breaks in them; these are currently not
supported (see Tcl-markdown tests mdtest-1.7 and 1.8):

```
The [link
breaks] across lines.

The [link 
breaks] across lines, but with a line-ending space.

[link breaks]: /url/

```

## Mdtest Results

Tcl-markdown has been run against the Markdown.mdtest test set provided by 
[mdtest](https://github.com/michelf/mdtest) test suite, with mixed 
results.  

* Running the test suite on OSX 10.8.5, using PHP 5.3.28, most
  tests fail.  Examination of the results reveals that most of the 
  "failures" involve whitespace differences with no effect on the rendered
  appearance of the output.

* Running the test suite on OSX 10.9, using PHP 5.4.30, most tests pass.
  The test files and Tcl-markdown outputs are identical on both platforms.
  My conjecture is that an XML-parser is used to compare the actual and
  expected results, and that the comparison is a little more forgiving on 
  PHP 5.4.30.

I am trying to fix substantive bugs; but see the mdtest-\*.\* tests
in test/markdown/markdown.test that are tagged with the constraint
"knownbug".

## CommonMark Results

Tcl-markdown has not been run against the CommonMark test suite as yet.
I would like to evolve it into a CommonMark compliant processor, but that
will take some time.

# Provenance

This module originated as the Tcl-Markdown project by Tobias Koch and Danyil Bohdan, 
as part of the Caius Test Tool. [https://github.com/tobijk/caius/](https://github.com/tobijk/caius/)

The module incorporated into Tcllib is based on a version that was modifed and enhanced 
by Will Duquette. [https://github.com/wduquette/tcl-markdown](https://github.com/wduquette/tcl-markdown)

