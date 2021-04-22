[example {
> tclsh8.5
% package require pt::pgen
% puts ====\n[pt::pgen peg {
        PEG calculator (Expression)
            Digit      <- '0'/'1'/'2'/'3'/'4'/'5'/'6'/'7'/'8'/'9'	;
            Sign       <- '-' / '+'					;
            Number     <- Sign? Digit+					;
            Expression <- '(' Expression ')' / (Factor (MulOp Factor)*)	;
            MulOp      <- '*' / '/'					;
            Factor     <- Term (AddOp Term)*				;
            AddOp      <- '+'/'-'					;
            Term       <- Number					;
        END;
    } container -name basic_arithmetic]
====
snit::type basic_arithmetic {
    constructor {} {
        install myg using pt::peg::container ${selfns}::G
        $myg start {n Expression}
        $myg add   AddOp Digit Expression Factor MulOp Number Sign Term
        $myg modes {
            AddOp      value
            Digit      value
            Expression value
            Factor     value
            MulOp      value
            Number     value
            Sign       value
            Term       value
        }
        $myg rules {
            AddOp      {/ {t -} {t +}}
            Digit      {/ {t 0} {t 1} {t 2} {t 3} {t 4} {t 5} {t 6} {t 7} {t 8} {t 9}}
            Expression {/ {x {t \50} {n Expression} {t \51}} {x {n Factor} {* {x {n MulOp} {n Factor}}}}}
            Factor     {x {n Term} {* {x {n AddOp} {n Term}}}}
            MulOp      {/ {t *} {t /}}
            Number     {x {? {n Sign}} {+ {n Digit}}}
            Sign       {/ {t -} {t +}}
            Term       {n Number}
        }
        return
    }

    component myg
    delegate method * to myg
}
%
}]
