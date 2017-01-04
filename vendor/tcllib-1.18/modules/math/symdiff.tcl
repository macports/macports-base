# symdiff.tcl --
#
#       Symbolic differentiation package for Tcl
#
# This package implements a command, "math::calculus::symdiff::symdiff",
# which accepts a Tcl expression and a variable name, and if the expression
# is readily differentiable, returns a Tcl expression that evaluates the
# derivative.
#
# Copyright (c) 2005, 2010 by Kevin B. Kenny.  All rights reserved.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: symdiff.tcl,v 1.2 2011/01/13 02:49:53 andreas_kupries Exp $


# This package requires the 'tclparser' from http://tclpro.sf.net/
# to analyze the expressions presented to it.

package require Tcl 8.4
package require grammar::aycock 1.0
package provide math::calculus::symdiff 1.0.1

namespace eval math {}
namespace eval math::calculus {}
namespace eval math::calculus::symdiff {
    namespace export jacobian symdiff
    namespace eval differentiate {}
}

# math::calculus::symdiff::jacobian --
#
#	Differentiate a set of expressions with respect to a set of
#	model variables
#
# Parameters:
#	model -- A list of alternating {variable name} {expr}
#
# Results:
#	Returns a list of lists.  The ith sublist is the gradient vector
#	of the ith expr in the model; that is, the jth element of
#	the ith sublist is the derivative of the ith expr with respect
#	to the jth variable.
#
#	Returns an error if any expression cannot be differentiated with
#	respect to any of the elements of the list, or if the list has
#	no elements or an odd number of elements.

proc math::calculus::symdiff::jacobian {list} {
    set l [llength $list]
    if {$l == 0 || $l%2 != 0} {
	return -code error "list of variables and expressions must have an odd number of elements"
    }
    set J {}
    foreach {- expr} $list {
	set gradient {}
	foreach {var -} $list {
	    lappend gradient [symdiff $expr $var]
	}
	lappend J $gradient
    }
    return $J
}

# math::calculus::symdiff::symdiff --
#
#       Differentiate an expression with respect to a variable.
#
# Parameters:
#       expr -- expression to differentiate (Must be a Tcl expression,
#               without command substitution.)
#       var -- Name of the variable to differentiate the expression
#              with respect to.
#
# Results:
#       Returns a Tcl expression that evaluates the derivative.

proc math::calculus::symdiff::symdiff {expr var} {
    variable parser
    set parsetree [$parser parse {*}[Lexer $expr] [namespace current]]
    return [ToInfix [differentiate::MakeDeriv $parsetree $var]]
}

# math::calculus::symdiff::Parser --
#
#	Parser for the mathematical expressions that this package can
#	differentiate.

namespace eval math::calculus::symdiff {
    variable parser [grammar::aycock::parser {
	expression ::= expression addop term {
	    set result [${clientData}::MakeOperator [lindex $_ 1]]
	    lappend result [lindex $_ 0] [lindex $_ 2]
	}
	expression ::= term {
	    lindex $_ 0
	}
	
	addop ::= + {
	    lindex $_ 0
	}
	addop ::= - {
	    lindex $_ 0
	}
	
	term ::= term mulop factor {
	    set result [${clientData}::MakeOperator [lindex $_ 1]]
	    lappend result [lindex $_ 0] [lindex $_ 2]
	}
	term ::= factor {
	    lindex $_ 0
	}
	mulop ::= * {
	    lindex $_ 0
	}
	mulop ::= / {
	    lindex $_ 0
	}
	
	factor ::= addop factor {
	    set result [${clientData}::MakeOperator [lindex $_ 0]]
	    lappend result [lindex $_ 1]
	}
	factor ::= expon {
	    lindex $_ 0
	}
	
	expon ::= primary ** expon {
	    set result [${clientData}::MakeOperator [lindex $_ 1]]
	    lappend result [lindex $_ 0] [lindex $_ 2]
	}
	expon ::= primary {
	    lindex $_ 0
	}
	
	primary ::= {$} bareword {
	    ${clientData}::MakeVariable [lindex $_ 1]
	}
	primary ::= number {
	    ${clientData}::MakeConstant [lindex $_ 0]
	}
	primary ::= bareword ( arglist ) {
	    set result [${clientData}::MakeOperator [lindex $_ 0]]
	    lappend result {*}[lindex $_ 2]
	}
	primary ::= ( expression ) {
	    lindex $_ 1
	}
	
	arglist ::= expression {
	    set _
	}
	arglist ::= arglist , expression {
	    linsert [lindex $_ 0] end [lindex $_ 2]
	}
    }]
}

# math::calculus::symdiff::Lexer --
#
#	Lexer for the arithmetic expressions that the 'symdiff' package
#	can differentiate.
#
# Results:
#	Returns a two element list. The first element is a list of the
#	lexical values of the tokens that were found in the expression;
#	the second is a list of the semantic values of the tokens. The
#	two sublists are the same length.

proc math::calculus::symdiff::Lexer {expression} {
    set start 0
    set tokens {}
    set values {}
    while {$expression ne {}} {
	if {[regexp {^\*\*(.*)} $expression -> rest]} {

	    # Exponentiation

	    lappend tokens **
	    lappend values **
	} elseif {[regexp {^([-+/*$(),])(.*)} $expression -> token rest]} {

	    # Single-character operators

	    lappend tokens $token
	    lappend values $token
	} elseif {[regexp {^([[:alpha:]][[:alnum:]_]*)(.*)} \
		       $expression -> token rest]} {

	    # Variable and function names

	    lappend tokens bareword
	    lappend values $token
	} elseif {[regexp -nocase -expanded {
	    ^((?:
	       (?: [[:digit:]]+ (?:[.][[:digit:]]*)? )
	       | (?: [.][[:digit:]]+ ) )
	      (?: e [-+]? [[:digit:]]+ )? )
	    (.*)
	}\
		       $expression -> token rest]} {

	    # Numbers

	    lappend tokens number
	    lappend values $token
	} elseif {[regexp {^[[:space:]]+(.*)} $expression -> rest]} {

	    # Whitespace

	} else {

	    # Anything else is an error

	    return -code error \
		-errorcode [list MATH SYMDIFF INVCHAR \
				[string index $expression 0]] \
		[list invalid character [string index $expression 0]] \
	}
	set expression $rest
    }
    return [list $tokens $values]
}

# math::calculus::symdiff::ToInfix --
#
#       Converts a parse tree to infix notation.
#
# Parameters:
#       tree - Parse tree to convert
#
# Results:
#       Returns the parse tree as a Tcl expression.

proc math::calculus::symdiff::ToInfix {tree} {
    set a [lindex $tree 0]
    set kind [lindex $a 0]
    switch -exact $kind {
        constant -
        text {
            set result [lindex $tree 1]
        }
        var {
            set result \$[lindex $tree 1]
        }
        operator {
            set name [lindex $a 1]
            if {([string is alnum $name] && $name ne {eq} && $name ne {ne})
                || [llength $tree] == 2} {
                set result $name
                append result \(
                set sep ""
                foreach arg [lrange $tree 1 end] {
                    append result $sep [ToInfix $arg]
                    set sep ", "
                }
                append result \)
            } elseif {[llength $tree] == 3} {
                set result \(
                append result [ToInfix [lindex $tree 1]]
                append result " " $name " "
                append result [ToInfix [lindex $tree 2]]
                append result \)
            } else {
                error "symdiff encountered a malformed parse, can't happen"
            }
        }
        default {
            error "symdiff can't synthesize a $kind expression"
        }
    }
    return $result
}

# math::calculus::symdiff::differentiate::MakeDeriv --
#
#       Differentiates a Tcl expression represented as a parse tree.
#
# Parameters:
#       tree -- Parse tree from MakeParseTreeForExpr
#       var -- Variable to differentiate with respect to
#
# Results:
#       Returns the parse tree of the derivative.

proc math::calculus::symdiff::differentiate::MakeDeriv {tree var} {
    return [eval [linsert $tree 1 $var]]
}

# math::calculus::symdiff::differentiate::ChainRule --
#
#       Applies the Chain Rule to evaluate the derivative of a unary 
#       function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       derivMaker -- Command prefix for differentiating the function.
#       u -- Function argument.
#
# Results:
#       Returns a parse tree representing the derivative of f($u).
#
# ChainRule differentiates $u with respect to $var by calling MakeDeriv,
# makes the derivative of f($u) with respect to $u by calling derivMaker
# passing $u as a parameter, and then returns a parse tree representing
# the product of the results.

proc math::calculus::symdiff::differentiate::ChainRule {var derivMaker u} {
    lappend derivMaker $u
    set result [MakeProd [MakeDeriv $u $var] [eval $derivMaker]]
}

# math::calculus::symdiff::differentiate::constant --
#
#       Differentiate a constant.
#
# Parameters:
#       var -- Variable to differentiate with respect to - unused
#       constant -- Constant expression to differentiate - ignored
#
# Results:
#       Returns a parse tree of the derivative, which is, of course, the
#       constant zero.

proc math::calculus::symdiff::differentiate::constant {var constant} {
    return [MakeConstant 0.0]
}

# math::calculus::symdiff::differentiate::var --
#
#       Differentiate a variable expression.
#
# Parameters:
#       var - Variable with which to differentiate.
#       exprVar - Expression being differentiated, which is a single
#                 variable.
#
# Results:
#       Returns a parse tree of the derivative.
#
# The derivative is the constant unity if the variables are the same
# and the constant zero if they are different.

proc math::calculus::symdiff::differentiate::var {var exprVar} {
    if {$exprVar eq $var} {
        return [MakeConstant 1.0]
    } else {
        return [MakeConstant 0.0]
    }
}

# math::calculus::symdiff::differentiate::operator + --
#
#       Forms the derivative of a sum.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       args -- One or two arguments giving augend and addend. If only
#               one argument is supplied, this is unary +.
#
# Results:
#       Returns a parse tree representing the derivative.
#
# Of course, the derivative of a sum is the sum of the derivatives.

proc {math::calculus::symdiff::differentiate::operator +} {var args} {
    if {[llength $args] == 1} {
        set u [lindex $args 0]
        set result [eval [linsert $u 1 $var]]
    } elseif {[llength $args] == 2} {
        foreach {u v} $args break
        set du [eval [linsert $u 1 $var]]
        set dv [eval [linsert $v 1 $var]]
        set result [MakeSum $du $dv]
    } else {
        error "symdiff encountered a malformed parse, can't happen"
    }
    return $result
}

# math::calculus::symdiff::differentiate::operator - --
#
#       Forms the derivative of a difference.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       args -- One or two arguments giving minuend and subtrahend. If only
#               one argument is supplied, this is unary -.
#
# Results:
#       Returns a parse tree representing the derivative.
#
# Of course, the derivative of a sum is the sum of the derivatives.

proc {math::calculus::symdiff::differentiate::operator -} {var args} {
    if {[llength $args] == 1} {
        set u [lindex $args 0]
        set du [eval [linsert $u 1 $var]]
        set result [MakeUnaryMinus $du]
    } elseif {[llength $args] == 2} {
        foreach {u v} $args break
        set du [eval [linsert $u 1 $var]]
        set dv [eval [linsert $v 1 $var]]
        set result [MakeDifference $du $dv]
    } else {
        error "symdiff encounered a malformed parse, can't happen"
    }
    return $result
}

# math::calculus::symdiff::differentiate::operator * --
#
#       Forms the derivative of a product.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u, v -- Multiplicand and multiplier. 
#
# Results:
#       Returns a parse tree representing the derivative.
#
# The familiar freshman calculus product rule.

proc {math::calculus::symdiff::differentiate::operator *} {var u v} {
    set du [eval [linsert $u 1 $var]]
    set dv [eval [linsert $v 1 $var]]
    set result [MakeSum [MakeProd $dv $u] [MakeProd $du $v]]
    return $result
}

# math::calculus::symdiff::differentiate::operator / --
#
#       Forms the derivative of a quotient.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u, v -- Dividend and divisor. 
#
# Results:
#       Returns a parse tree representing the derivative.
#
# The familiar freshman calculus quotient rule.

proc {math::calculus::symdiff::differentiate::operator /} {var u v} {
    set du [eval [linsert $u 1 $var]]
    set dv [eval [linsert $v 1 $var]]
    set result [MakeQuotient \
                    [MakeDifference \
                         $du \
                         [MakeQuotient \
                              [MakeProd $dv $u] \
                              $v]] \
                    $v]
    return $result
}

# math::calculus::symdiff::differentiate::operator acos --
#
#       Differentiates the 'acos' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the acos() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Applies the Chain Rule: D(acos(u))=-D(u)/sqrt(1 - u*u)
# (Might it be better to factor 1-u*u into (1+u)(1-u)? Less likely to be
# catastrophic cancellation if u is near 1?)

proc {math::calculus::symdiff::differentiate::operator acos} {var u} {
    set du [eval [linsert $u 1 $var]]
    set result [MakeQuotient [MakeUnaryMinus $du] \
                    [MakeFunCall sqrt \
                         [MakeDifference [MakeConstant 1.0] \
                              [MakeProd $u $u]]]]
    return $result
}

# math::calculus::symdiff::differentiate::operator asin --
#
#       Differentiates the 'asin' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the asin() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Applies the Chain Rule: D(asin(u))=D(u)/sqrt(1 - u*u)
# (Might it be better to factor 1-u*u into (1+u)(1-u)? Less likely to be
# catastrophic cancellation if u is near 1?)

proc {math::calculus::symdiff::differentiate::operator asin} {var u} {
    set du [eval [linsert $u 1 $var]]
    set result [MakeQuotient $du \
                    [MakeFunCall sqrt \
                         [MakeDifference [MakeConstant 1.0] \
                              [MakeProd $u $u]]]]
    return $result
}

# math::calculus::symdiff::differentiate::operator atan --
#
#       Differentiates the 'atan' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the atan() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Applies the Chain Rule: D(atan(u))=D(u)/(1 + $u*$u)

proc {math::calculus::symdiff::differentiate::operator atan} {var u} {
    set du [eval [linsert $u 1 $var]]
    set result [MakeQuotient $du \
                    [MakeSum [MakeConstant 1.0] \
                         [MakeProd $u $u]]]
}

# math::calculus::symdiff::differentiate::operator atan2 --
#
#       Differentiates the 'atan2' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       f, g -- Arguments to the atan() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Applies the Chain and Quotient Rules: 
#       D(atan2(f, g)) = (D(f)*g - D(g)*f)/(f*f + g*g)

proc {math::calculus::symdiff::differentiate::operator atan2} {var f g} {
    set df [eval [linsert $f 1 $var]]
    set dg [eval [linsert $g 1 $var]]
    return [MakeQuotient \
                [MakeDifference \
                     [MakeProd $df $g] \
                     [MakeProd $f $dg]] \
                [MakeSum \
                     [MakeProd $f $f] \
                     [MakeProd $g $g]]]
}

# math::calculus::symdiff::differentiate::operator cos --
#
#       Differentiates the 'cos' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the cos() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Applies the Chain Rule: D(cos(u))=-sin(u)*D(u)

proc {math::calculus::symdiff::differentiate::operator cos} {var u} {
    return [ChainRule $var MakeMinusSin $u]
}
proc math::calculus::symdiff::differentiate::MakeMinusSin {operand} {
    return [MakeUnaryMinus [MakeFunCall sin $operand]]
}

# math::calculus::symdiff::differentiate::operator cosh --
#
#       Differentiates the 'cosh' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the cosh() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Applies the Chain Rule: D(cosh(u))=sinh(u)*D(u)

proc {math::calculus::symdiff::differentiate::operator cosh} {var u} {
    set result [ChainRule $var [list MakeFunCall sinh] $u]
    return $result
}

# math::calculus::symdiff::differentiate::operator exp --
#
#       Differentiate the exponential function
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument of the exponential function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Uses the Chain Rule D(exp(u)) = exp(u)*D(u).

proc {math::calculus::symdiff::differentiate::operator exp} {var u} {
    set result [ChainRule $var [list MakeFunCall exp] $u]
    return $result
}

# math::calculus::symdiff::differentiate::operator hypot --
#
#       Differentiate the 'hypot' function
#
# Parameters:
#       var - Variable to differentiate with respect to.
#       f, g - Arguments to the 'hypot' function
#
# Results:
#       Returns a parse tree of the derivative
#
# Uses a number of algebraic simplifications to arrive at:
#       D(hypot(f,g)) = (f*D(f)+g*D(g))/hypot(f,g)

proc {math::calculus::symdiff::differentiate::operator hypot} {var f g} {
    set df [eval [linsert $f 1 $var]]
    set dg [eval [linsert $g 1 $var]]
    return [MakeQuotient \
                [MakeSum \
                     [MakeProd $df $f] \
                     [MakeProd $dg $g]] \
                [MakeFunCall hypot $f $g]]
}

# math::calculus::symdiff::differentiate::operator log --
#
#       Differentiates a logarithm.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the log() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# D(log(u))==D(u)/u

proc {math::calculus::symdiff::differentiate::operator log} {var u} {
    set du [eval [linsert $u 1 $var]]
    set result [MakeQuotient $du $u]
    return $result
}

# math::calculus::symdiff::differentiate::operator log10 --
#
#       Differentiates a common logarithm.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the log10() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# D(log(u))==D(u)/(u * log(10))

proc {math::calculus::symdiff::differentiate::operator log10} {var u} {
    set du [eval [linsert $u 1 $var]]
    set result [MakeQuotient $du \
                    [MakeProd [MakeConstant [expr log(10.)]] $u]]
    return $result
}

# math::calculus::symdiff::differentiate::operator ** --
#
#       Differentiate an exponential.
#
# Parameters:
#       var -- Variable to differentiate with respect to
#       f, g -- Base and exponent
#
# Results:
#       Returns the parse tree of the derivative.
#
# Handles the special case where g is constant as
#    D(f**g) == g*f**(g-1)*D(f)
# Otherwise, uses the general power formula
#    D(f**g) == (f**g) * (((D(f)*g)/f) + (D(g)*log(f)))

proc {math::calculus::symdiff::differentiate::operator **} {var f g} {
    set df [eval [linsert $f 1 $var]]
    if {[IsConstant $g]} {
        set gm1 [MakeConstant [expr {[ConstantValue $g] - 1}]]
        set result [MakeProd $df [MakeProd $g [MakePower $f $gm1]]]
        
    } else {
        set dg [eval [linsert $g 1 $var]]
        set result [MakeProd [MakePower $f $g] \
                        [MakeSum \
                             [MakeQuotient [MakeProd $df $g] $f] \
                             [MakeProd $dg [MakeFunCall log $f]]]]
    }
    return $result
}
interp alias {} {math::calculus::symdiff::differentiate::operator pow} \
    {} {math::calculus::symdiff::differentiate::operator **}

# math::calculus::symdiff::differentiate::operator sin --
#
#       Differentiates the 'sin' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the sin() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Applies the Chain Rule: D(sin(u))=cos(u)*D(u)

proc {math::calculus::symdiff::differentiate::operator sin} {var u} {
    set result [ChainRule $var [list MakeFunCall cos] $u]
    return $result
}

# math::calculus::symdiff::differentiate::operator sinh --
#
#       Differentiates the 'sinh' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the sinh() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Applies the Chain Rule: D(sin(u))=cosh(u)*D(u)

proc {math::calculus::symdiff::differentiate::operator sinh} {var u} {
    set result [ChainRule $var [list MakeFunCall cosh] $u]
    return $result
}

# math::calculus::symdiff::differentiate::operator sqrt --
#
#       Differentiate the 'sqrt' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to
#       u -- Parameter of 'sqrt' as a parse tree.
#
# Results:
#       Returns a parse tree representing the derivative.
#
# D(sqrt(u))==D(u)/(2*sqrt(u))

proc {math::calculus::symdiff::differentiate::operator sqrt} {var u} {
    set du [eval [linsert $u 1 $var]]
    set result [MakeQuotient $du [MakeProd [MakeConstant 2.0] \
                                      [MakeFunCall sqrt $u]]]
    return $result
}

# math::calculus::symdiff::differentiate::operator tan --
#
#       Differentiates the 'tan' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the tan() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Applies the Chain Rule: D(tan(u))=D(u)/(cos(u)*cos(u))

proc {math::calculus::symdiff::differentiate::operator tan} {var u} {
    set du [eval [linsert $u 1 $var]]
    set cosu [MakeFunCall cos $u]
    return [MakeQuotient $du [MakeProd $cosu $cosu]]
}

# math::calculus::symdiff::differentiate::operator tanh --
#
#       Differentiates the 'tanh' function.
#
# Parameters:
#       var -- Variable to differentiate with respect to.
#       u -- Argument to the tanh() function.
#
# Results:
#       Returns a parse tree of the derivative.
#
# Applies the Chain Rule: D(tanh(u))=D(u)/(cosh(u)*cosh(u))

proc {math::calculus::symdiff::differentiate::operator tanh} {var u} {
    set du [eval [linsert $u 1 $var]]
    set coshu [MakeFunCall cosh $u]
    return [MakeQuotient $du [MakeProd $coshu $coshu]]
}

# math::calculus::symdiff::MakeFunCall --
#
#       Makes a parse tree for a function call
#
# Parameters:
#       fun -- Name of the function to call
#       args -- Arguments to the function, expressed as parse trees
#
# Results:
#       Returns a parse tree for the result of calling the function.
#
# Performs the peephole optimization of replacing a function with
# constant parameters with its value.

proc math::calculus::symdiff::MakeFunCall {fun args} {
    set constant 1
    set exp $fun
    append exp \(
    set sep ""
    foreach a $args {
        if {[IsConstant $a]} {
            append exp $sep [ConstantValue $a]
            set sep ","
        } else {
            set constant 0
            break
        }
    }
    if {$constant} {
        append exp \)
        return [MakeConstant [expr $exp]]
    }
    set result [MakeOperator $fun]
    foreach arg $args {
        lappend result $arg
    }
    return $result
}

# math::calculus::symdiff::MakeSum --
#
#       Makes the parse tree for a sum.
#
# Parameters:
#       left, right -- Parse trees for augend and addend
#
# Results:
#       Returns the parse tree for the sum.
#
# Performs the following peephole optimizations:
# (1) a + (-b) = a - b
# (2) (-a) + b = b - a
# (3) 0 + a = a
# (4) a + 0 = a
# (5) The sum of two constants may be reduced to a constant

proc math::calculus::symdiff::MakeSum {left right} {
    if {[IsUnaryMinus $right]} {
        return [MakeDifference $left [UnaryMinusArg $right]]
    }
    if {[IsUnaryMinus $left]} {
        return [MakeDifference $right [UnaryMinusArg $left]]
    }
    if {[IsConstant $left]} {
        set v [ConstantValue $left]
        if {$v == 0} {
            return $right
        } elseif {[IsConstant $right]} {
            return [MakeConstant [expr {[ConstantValue $left]
                                        + [ConstantValue $right]}]]
        }
    } elseif {[IsConstant $right]} {
        set v [ConstantValue $right]
        if {$v == 0} {
            return $left
        }
    }
    set result [MakeOperator +]
    lappend result $left $right
    return $result
}

# math::calculus::symdiff::MakeDifference --
#
#       Makes the parse tree for a difference
#
# Parameters:
#       left, right -- Minuend and subtrahend, expressed as parse trees
#
# Results:
#       Returns a parse tree expressing the difference
#
# Performs the following peephole optimizations:
# (1) a - (-b) = a + b
# (2) -a - b = -(a + b)
# (3) 0 - b = -b
# (4) a - 0 = a
# (5) The difference of any two constants can be reduced to a constant.

proc math::calculus::symdiff::MakeDifference {left right} {
    if {[IsUnaryMinus $right]} {
        return [MakeSum $left [UnaryMinusArg $right]]
    }
    if {[IsUnaryMinus $left]} {
        return [MakeUnaryMinus [MakeSum [UnaryMinusArg $left] $right]]
    }
    if {[IsConstant $left]} {
        set v [ConstantValue $left]
        if {$v == 0} {
            return [MakeUnaryMinus $right]
        } elseif {[IsConstant $right]} {
            return [MakeConstant [expr {[ConstantValue $left]
                                        - [ConstantValue $right]}]]
        }
    } elseif {[IsConstant $right]} {
        set v [ConstantValue $right]
        if {$v == 0} {
            return $left
        }
    }
    set result [MakeOperator -]
    lappend result $left $right
    return $result
}

# math::calculus::symdiff::MakeProd --
#
#       Constructs the parse tree for a product, left*right.
#
# Parameters:
#       left, right - Multiplicand and multiplier
#
# Results:
#       Returns the parse tree for the result.
#
# Performs the following peephole optimizations.
# (1) If either operand is a unary minus, it is hoisted out of the
#     expression.
# (2) If either operand is the constant 0, the result is the constant 0
# (3) If either operand is the constant 1, the result is the other operand.
# (4) If either operand is the constant -1, the result is unary minus
#     applied to the other operand
# (5) If both operands are constant, the result is a constant containing
#     their product.

proc math::calculus::symdiff::MakeProd {left right} {
    if {[IsUnaryMinus $left]} {
        return [MakeUnaryMinus [MakeProd [UnaryMinusArg $left] $right]]
    }
    if {[IsUnaryMinus $right]} {
        return [MakeUnaryMinus [MakeProd $left [UnaryMinusArg $right]]]
    }
    if {[IsConstant $left]} {
        set v [ConstantValue $left]
        if {$v == 0} {
            return [MakeConstant 0.0]
        } elseif {$v == 1} {
            return $right
        } elseif {$v == -1} {
            return [MakeUnaryMinus $right]
        } elseif {[IsConstant $right]} {
            return [MakeConstant [expr {[ConstantValue $left]
                                        * [ConstantValue $right]}]]
        }
    } elseif {[IsConstant $right]} {
        set v [ConstantValue $right]
        if {$v == 0} {
            return [MakeConstant 0.0]
        } elseif {$v == 1} {
            return $left
        } elseif {$v == -1} {
            return [MakeUnaryMinus $left]
        }
    }
    set result [MakeOperator *]
    lappend result $left $right
    return $result
}

# math::calculus::symdiff::MakeQuotient --
#
#       Makes a parse tree for a quotient, n/d
#
# Parameters:
#       n, d - Parse trees for numerator and denominator
#
# Results:
#       Returns the parse tree for the quotient.
#
# Performs peephole optimizations:
# (1) If either operand is a unary minus, it is hoisted out.
# (2) If the numerator is the constant 0, the result is the constant 0.
# (3) If the demominator is the constant 1, the result is the numerator
# (4) If the denominator is the constant -1, the result is the unary
#     negation of the numerator.
# (5) If both numerator and denominator are constant, the result is
#     a constant representing their quotient.

proc math::calculus::symdiff::MakeQuotient {n d} {
    if {[IsUnaryMinus $n]} {
        return [MakeUnaryMinus [MakeQuotient [UnaryMinusArg $n] $d]]
    }
    if {[IsUnaryMinus $d]} {
        return [MakeUnaryMinus [MakeQuotient $n [UnaryMinusArg $d]]]
    }
    if {[IsConstant $n]} {
        set v [ConstantValue $n]
        if {$v == 0} {
            return [MakeConstant 0.0]
        } elseif {[IsConstant $d]} {
            return [MakeConstant [expr {[ConstantValue $n]
                                        * [ConstantValue $d]}]]
        }
    } elseif {[IsConstant $d]} {
        set v [ConstantValue $d]
        if {$v == 0} {
            return -code error "requested expression will result in division by zero at run time"
        } elseif {$v == 1} {
            return $n
        } elseif {$v == -1} {
            return [MakeUnaryMinus $n]
        }
    }
    set result [MakeOperator /]
    lappend result $n $d
    return $result
}

# math::calculus::symdiff::MakePower --
#
#       Make a parse tree for an exponentiation operation
#
# Parameters:
#       a -- Base, expressed as a parse tree
#       b -- Exponent, expressed as a parse tree
#
# Results:
#       Returns a parse tree for the expression
#
# Performs peephole optimizations:
# (1) The constant zero raised to any non-zero power is 0
# (2) The constant 1 raised to any power is 1
# (3) Any non-zero quantity raised to the zero power is 1
# (4) Any non-zero quantity raised to the first power is the base itself.
# (5) MakeFunCall will optimize any other case of a constant raised
#     to a constant power.

proc math::calculus::symdiff::MakePower {a b} {
    if {[IsConstant $a]} {
        if {[ConstantValue $a] == 0} {
            if {[IsConstant $b] && [ConstantValue $b] == 0} {
                error "requested expression will result in zero to zero power at run time"
            }
            return [MakeConstant 0.0]
        } elseif {[ConstantValue $a] == 1} {
            return [MakeConstant 1.0]
        }
    }
    if {[IsConstant $b]} {
        if {[ConstantValue $b] == 0} {
            return [MakeConstant 1.0]
        } elseif {[ConstantValue $b] == 1} {
            return $a
        }
    }
    return [MakeFunCall pow $a $b]
}

# math::calculus::symdiff::MakeUnaryMinus --
#
#       Makes the parse tree for a unary negation.
#
# Parameters:
#       operand -- Parse tree for the operand
#
# Results:
#       Returns the parse tree for the expression
#
# Performs the following peephole optimizations:
# (1) -(-$a) = $a
# (2) The unary negation of a constant is another constant

proc math::calculus::symdiff::MakeUnaryMinus {operand} {
    if {[IsUnaryMinus $operand]} {
        return [UnaryMinusArg $operand]
    }
    if {[IsConstant $operand]} {
        return [MakeConstant [expr {-[ConstantValue $operand]}]]
    } else {
        return [list [list operator -] $operand]
    }
}

# math::calculus::symdiff::IsUnaryMinus --
#
#       Determines whether a parse tree represents a unary negation
#
# Parameters:
#       x - Parse tree to examine
#
# Results:
#       Returns 1 if the parse tree represents a unary minus, 0 otherwise

proc math::calculus::symdiff::IsUnaryMinus {x} {
    return [expr {[llength $x] == 2
                  && [lindex $x 0] eq [list operator -]}]
}

# math::calculus::symdiff::UnaryMinusArg --
#
#       Extracts the argument from a unary negation.
#
# Parameters:
#       x - Parse tree to examine, known to represent a unary negation
#
# Results:
#       Returns a parse tree representing the operand.

proc math::calculus::symdiff::UnaryMinusArg {x} {
    return [lindex $x 1]
}

# math::calculus::symdiff::MakeOperator --
#
#       Makes a partial parse tree for an operator
#
# Parameters:
#       op -- Name of the operator
#
# Results:
#       Returns the resulting parse tree.
#
# The caller may use [lappend] to place any needed operands

proc math::calculus::symdiff::MakeOperator {op} {
    if {$op eq {?}} {
        return -code error "symdiff can't differentiate the ternary ?: operator"
    } elseif {[namespace which [list differentiate::operator $op]] ne {}} {
        return [list [list operator $op]]
    } elseif {[string is alnum $op] && ($op ni {eq ne in ni})} {
        return -code error "symdiff can't differentiate the \"$op\" function"
    } else {
        return -code error "symdiff can't differentiate the \"$op\" operator"
    }
}

# math::calculus::symdiff::MakeVariable --
#
#       Makes a partial parse tree for a single variable
#
# Parameters:
#       name -- Name of the variable
#
# Results:
#       Returns a partial parse tree giving the variable

proc math::calculus::symdiff::MakeVariable {name} {
    return [list var $name]
}

# math::calculus::symdiff::MakeConstant --
#
#       Make the parse tree for a constant.
#
# Parameters:
#       value -- The constant's value
#
# Results:
#       Returns a parse tree.

proc math::calculus::symdiff::MakeConstant {value} {
    return [list constant $value]
}

# math::calculus::symdiff::IsConstant --
#
#       Test if an expression represented by a parse tree is a constant.
#
# Parameters:
#       Item - Parse tree to test
#
# Results:
#       Returns 1 for a constant, 0 for anything else

proc math::calculus::symdiff::IsConstant {item} {
    return [expr {[lindex $item 0] eq {constant}}]
}

# math::calculus::symdiff::ConstantValue --
#
#       Recovers a constant value from the parse tree representing a constant
#       expression.
#
# Parameters:
#       item -- Parse tree known to be a constant.
#
# Results:
#       Returns the constant value.

proc math::calculus::symdiff::ConstantValue {item} {
    return [lindex $item 1]
}

# Define the parse tree fabrication routines in the 'differentiate'
# namespace as well as the 'symdiff' namespace, without exporting them
# from the package.

interp alias {} math::calculus::symdiff::differentiate::IsConstant \
    {} math::calculus::symdiff::IsConstant
interp alias {} math::calculus::symdiff::differentiate::ConstantValue \
    {} math::calculus::symdiff::ConstantValue
interp alias {} math::calculus::symdiff::differentiate::MakeConstant \
    {} math::calculus::symdiff::MakeConstant
interp alias {} math::calculus::symdiff::differentiate::MakeDifference \
    {} math::calculus::symdiff::MakeDifference
interp alias {} math::calculus::symdiff::differentiate::MakeFunCall \
    {} math::calculus::symdiff::MakeFunCall
interp alias {} math::calculus::symdiff::differentiate::MakePower \
    {} math::calculus::symdiff::MakePower
interp alias {} math::calculus::symdiff::differentiate::MakeProd \
    {} math::calculus::symdiff::MakeProd
interp alias {} math::calculus::symdiff::differentiate::MakeQuotient \
    {} math::calculus::symdiff::MakeQuotient
interp alias {} math::calculus::symdiff::differentiate::MakeSum \
    {} math::calculus::symdiff::MakeSum
interp alias {} math::calculus::symdiff::differentiate::MakeUnaryMinus \
    {} math::calculus::symdiff::MakeUnaryMinus
interp alias {} math::calculus::symdiff::differentiate::MakeVariable \
    {} math::calculus::symdiff::MakeVariable
interp alias {} math::calculus::symdiff::differentiate::ExtractExpression \
    {} math::calculus::symdiff::ExtractExpression
