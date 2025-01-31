[example {
PEG calculator (Expression)
    Sign       <- [-+]                                          ;
    Number     <- Sign? <ddigit>+                               ;
    Expression <- Term (AddOp Term)*                            ;
    MulOp      <- [*/]						;
    Term       <- Factor (MulOp Factor)*                        ;
    AddOp      <- [-+]						;
    Factor     <- '(' Expression ')' / Number                   ;
END;
}]
