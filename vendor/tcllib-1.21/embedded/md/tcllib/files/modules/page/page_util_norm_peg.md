
[//000000001]: # (page\_util\_norm\_peg \- Parser generator tools)
[//000000002]: # (Generated from file 'page\_util\_norm\_peg\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (page\_util\_norm\_peg\(n\) 1\.0 tcllib "Parser generator tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

page\_util\_norm\_peg \- page AST normalization, PEG

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require page::util::norm\_peg ?0\.1?  
package require snit  

[__::page::util::norm::peg__ *tree*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a single utility command which takes an AST for a parsing
expression grammar and normalizes it in various ways\. The result is called a
*Normalized PE Grammar Tree*\.

*Note* that this package can only be used from within a plugin managed by the
package __page::pluginmgr__\.

# <a name='section2'></a>API

  - <a name='1'></a>__::page::util::norm::peg__ *tree*

    This command assumes the *tree* object contains for a parsing expression
    grammar\. It normalizes this tree in place\. The result is called a
    *Normalized PE Grammar Tree*\.

    The following operations are performd

      1. The data for all terminals is stored in their grandparental nodes\. The
         terminal nodes and their parents are removed\. Type information is
         dropped\.

      1. All nodes which have exactly one child are irrelevant and are removed,
         with the exception of the root node\. The immediate child of the root is
         irrelevant as well, and removed as well\.

      1. The name of the grammar is moved from the tree node it is stored in to
         an attribute of the root node, and the tree node removed\.

         The node keeping the start expression separate is removed as irrelevant
         and the root node of the start expression tagged with a marker
         attribute, and its handle saved in an attribute of the root node for
         quick access\.

      1. Nonterminal hint information is moved from nodes into attributes, and
         the now irrelevant nodes are deleted\.

         *Note:* This transformation is dependent on the removal of all nodes
         with exactly one child, as it removes the all 'Attribute' nodes
         already\. Otherwise this transformation would have to put the
         information into the grandparental node\.

         The default mode given to the nonterminals is __value__\.

         Like with the global metadata definition specific information is moved
         out out of nodes into attributes, the now irrelevant nodes are deleted,
         and the root nodes of all definitions are tagged with marker
         attributes\. This provides us with a mapping from nonterminal names to
         their defining nodes as well, which is saved in an attribute of the
         root node for quick reference\.

         At last the range in the input covered by a definition is computed\. The
         left extent comes from the terminal for the nonterminal symbol it
         defines\. The right extent comes from the rightmost child under the
         definition\. While this not an expression tree yet the location data is
         sound already\.

      1. The remaining nodes under all definitions are transformed into proper
         expression trees\. First character ranges, followed by unary operations,
         characters, and nonterminals\. At last the tree is flattened by the
         removal of superfluous inner nodes\.

         The order matters, to shed as much nodes as possible early, and to
         avoid unnecessary work later\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *page* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[PEG](\.\./\.\./\.\./\.\./index\.md\#peg), [graph
walking](\.\./\.\./\.\./\.\./index\.md\#graph\_walking),
[normalization](\.\./\.\./\.\./\.\./index\.md\#normalization),
[page](\.\./\.\./\.\./\.\./index\.md\#page), [parser
generator](\.\./\.\./\.\./\.\./index\.md\#parser\_generator), [text
processing](\.\./\.\./\.\./\.\./index\.md\#text\_processing), [tree
walking](\.\./\.\./\.\./\.\./index\.md\#tree\_walking)

# <a name='category'></a>CATEGORY

Page Parser Generator

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
