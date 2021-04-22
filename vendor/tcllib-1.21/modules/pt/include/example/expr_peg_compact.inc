[example {
PEG calculator (Expression)
    Sign       <- [-+] 						;
    Number     <- Sign? <ddigit>+				;
    Expression <- '(' Expression ')' / (Factor (MulOp Factor)*)	;
    MulOp      <- [*/]						;
    Factor     <- Term (AddOp Term)*				;
    AddOp      <- [-+]						;
    Term       <- Number					;
END;
}]
