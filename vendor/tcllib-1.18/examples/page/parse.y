/*
** 2001 September 15
**
** The author disclaims copyright to this source code.  In place of
** a legal notice, here is a blessing:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
**
*************************************************************************
** This file contains SQLite's grammar for SQL.  Process this file
** using the lemon parser generator to generate C code that runs
** the parser.  Lemon will also generate a header file containing
** numeric codes for all of the tokens.
**
** @(#) $Id: parse.y,v 1.1 2005/09/28 04:51:19 andreas_kupries Exp $
*/
%token_prefix TK_
%token_type {Token}
%default_type {Token}
%extra_argument {Parse *pParse}
%syntax_error {
  if( pParse->zErrMsg==0 ){
    if( TOKEN.z[0] ){
      sqlite3ErrorMsg(pParse, "near \"%T\": syntax error", &TOKEN);
    }else{
      sqlite3ErrorMsg(pParse, "incomplete SQL statement");
    }
  }
}
%name sqlite3Parser
%include {
#include "sqliteInt.h"
#include "parse.h"

/*
** An instance of this structure holds information about the
** LIMIT clause of a SELECT statement.
*/
struct LimitVal {
  Expr *pLimit;    /* The LIMIT expression.  NULL if there is no limit */
  Expr *pOffset;   /* The OFFSET expression.  NULL if there is none */
};

/*
** An instance of this structure is used to store the LIKE,
** GLOB, NOT LIKE, and NOT GLOB operators.
*/
struct LikeOp {
  int opcode;   /* Either TK_GLOB or TK_LIKE */
  int not;      /* True if the NOT keyword is present */
};

/*
** An instance of the following structure describes the event of a
** TRIGGER.  "a" is the event type, one of TK_UPDATE, TK_INSERT,
** TK_DELETE, or TK_INSTEAD.  If the event is of the form
**
**      UPDATE ON (a,b,c)
**
** Then the "b" IdList records the list "a,b,c".
*/
struct TrigEvent { int a; IdList * b; };

/*
** An instance of this structure holds the ATTACH key and the key type.
*/
struct AttachKey { int type;  Token key; };

} // end %include

// These are extra tokens used by the lexer but never seen by the
// parser.  We put them in a rule so that the parser generator will
// add them to the parse.h output file.
//
%nonassoc END_OF_FILE ILLEGAL SPACE UNCLOSED_STRING COMMENT FUNCTION
          COLUMN AGG_FUNCTION.

// Input is a single SQL command
input ::= cmdlist.
cmdlist ::= cmdlist ecmd.
cmdlist ::= ecmd.
cmdx ::= cmd.           { sqlite3FinishCoding(pParse); }
ecmd ::= SEMI.
ecmd ::= explain cmdx SEMI.
explain ::= .           { sqlite3BeginParse(pParse, 0); }
%ifndef SQLITE_OMIT_EXPLAIN
explain ::= EXPLAIN.    { sqlite3BeginParse(pParse, 1); }
%endif

///////////////////// Begin and end transactions. ////////////////////////////
//

cmd ::= BEGIN transtype(Y) trans_opt.  {sqlite3BeginTransaction(pParse, Y);}
trans_opt ::= .
trans_opt ::= TRANSACTION.
trans_opt ::= TRANSACTION nm.
%type transtype {int}
transtype(A) ::= .             {A = TK_DEFERRED;}
transtype(A) ::= DEFERRED(X).  {A = @X;}
transtype(A) ::= IMMEDIATE(X). {A = @X;}
transtype(A) ::= EXCLUSIVE(X). {A = @X;}
cmd ::= COMMIT trans_opt.      {sqlite3CommitTransaction(pParse);}
cmd ::= END trans_opt.         {sqlite3CommitTransaction(pParse);}
cmd ::= ROLLBACK trans_opt.    {sqlite3RollbackTransaction(pParse);}

///////////////////// The CREATE TABLE statement ////////////////////////////
//
cmd ::= create_table create_table_args.
create_table ::= CREATE(X) temp(T) TABLE nm(Y) dbnm(Z). {
   sqlite3StartTable(pParse,&X,&Y,&Z,T,0);
}
%type temp {int}
%ifndef SQLITE_OMIT_TEMPDB
temp(A) ::= TEMP.  {A = 1;}
%endif
temp(A) ::= .      {A = 0;}
create_table_args ::= LP columnlist conslist_opt(X) RP(Y). {
  sqlite3EndTable(pParse,&X,&Y,0);
}
create_table_args ::= AS select(S). {
  sqlite3EndTable(pParse,0,0,S);
  sqlite3SelectDelete(S);
}
columnlist ::= columnlist COMMA column.
columnlist ::= column.

// About the only information used for a column is the name of the
// column.  The type is always just "text".  But the code will accept
// an elaborate typename.  Perhaps someday we'll do something with it.
//
column(A) ::= columnid(X) type carglist. {
  A.z = X.z;
  A.n = (pParse->sLastToken.z-X.z) + pParse->sLastToken.n;
}
columnid(A) ::= nm(X). {
  sqlite3AddColumn(pParse,&X);
  A = X;
}


// An IDENTIFIER can be a generic identifier, or one of several
// keywords.  Any non-standard keyword can also be an identifier.
//
%type id {Token}
id(A) ::= ID(X).         {A = X;}

// The following directive causes tokens ABORT, AFTER, ASC, etc. to
// fallback to ID if they will not parse as their original value.
// This obviates the need for the "id" nonterminal.
//
%fallback ID
  ABORT AFTER ASC ATTACH BEFORE BEGIN CASCADE CONFLICT
  DATABASE DEFERRED DESC DETACH EACH END EXCLUSIVE EXPLAIN FAIL FOR
  GLOB IGNORE IMMEDIATE INITIALLY INSTEAD LIKE MATCH KEY
  OF OFFSET PRAGMA RAISE REPLACE RESTRICT ROW STATEMENT
  TEMP TRIGGER VACUUM VIEW
%ifdef SQLITE_OMIT_COMPOUND_SELECT
  EXCEPT INTERSECT UNION
%endif
  REINDEX RENAME CDATE CTIME CTIMESTAMP ALTER
  .

// Define operator precedence early so that this is the first occurance
// of the operator tokens in the grammer.  Keeping the operators together
// causes them to be assigned integer values that are close together,
// which keeps parser tables smaller.
//
// The token values assigned to these symbols is determined by the order
// in which lemon first sees them.  It must be the case that ISNULL/NOTNULL,
// NE/EQ, GT/LE, and GE/LT are separated by only a single value.  See
// the sqlite3ExprIfFalse() routine for additional information on this
// constraint.
//
%left OR.
%left AND.
%right NOT.
%left IS LIKE GLOB BETWEEN IN ISNULL NOTNULL NE EQ.
%left GT LE LT GE.
%right ESCAPE.
%left BITAND BITOR LSHIFT RSHIFT.
%left PLUS MINUS.
%left STAR SLASH REM.
%left CONCAT.
%right UMINUS UPLUS BITNOT.

// And "ids" is an identifer-or-string.
//
%type ids {Token}
ids(A) ::= ID(X).        {A = X;}
ids(A) ::= STRING(X).    {A = X;}

// The name of a column or table can be any of the following:
//
%type nm {Token}
nm(A) ::= ID(X).         {A = X;}
nm(A) ::= STRING(X).     {A = X;}
nm(A) ::= JOIN_KW(X).    {A = X;}

type ::= .
type ::= typename(X).                    {sqlite3AddColumnType(pParse,&X,&X);}
type ::= typename(X) LP signed RP(Y).    {sqlite3AddColumnType(pParse,&X,&Y);}
type ::= typename(X) LP signed COMMA signed RP(Y).
                                         {sqlite3AddColumnType(pParse,&X,&Y);}
%type typename {Token}
typename(A) ::= ids(X).             {A = X;}
typename(A) ::= typename(X) ids(Y). {A.z=X.z; A.n=Y.n+(Y.z-X.z);}
%type signed {int}
signed(A) ::= plus_num(X).    { A = atoi(X.z); }
signed(A) ::= minus_num(X).   { A = -atoi(X.z); }
carglist ::= carglist carg.
carglist ::= .
carg ::= CONSTRAINT nm ccons.
carg ::= ccons.
carg ::= DEFAULT term(X).            {sqlite3AddDefaultValue(pParse,X);}
carg ::= DEFAULT PLUS term(X).       {sqlite3AddDefaultValue(pParse,X);}
carg ::= DEFAULT MINUS term(X).      {
  Expr *p = sqlite3Expr(TK_UMINUS, X, 0, 0);
  sqlite3AddDefaultValue(pParse,p);
}
carg ::= DEFAULT id(X).              {
  Expr *p = sqlite3Expr(TK_STRING, 0, 0, &X);
  sqlite3AddDefaultValue(pParse,p);
}

// In addition to the type name, we also care about the primary key and
// UNIQUE constraints.
//
ccons ::= NULL onconf.
ccons ::= NOT NULL onconf(R).               {sqlite3AddNotNull(pParse, R);}
ccons ::= PRIMARY KEY sortorder onconf(R) autoinc(I).
                                     {sqlite3AddPrimaryKey(pParse,0,R,I);}
ccons ::= UNIQUE onconf(R).          {sqlite3CreateIndex(pParse,0,0,0,0,R,0,0);}
ccons ::= CHECK LP expr(X) RP onconf. {sqlite3ExprDelete(X);}
ccons ::= REFERENCES nm(T) idxlist_opt(TA) refargs(R).
                                {sqlite3CreateForeignKey(pParse,0,&T,TA,R);}
ccons ::= defer_subclause(D).   {sqlite3DeferForeignKey(pParse,D);}
ccons ::= COLLATE id(C).  {sqlite3AddCollateType(pParse, C.z, C.n);}

// The optional AUTOINCREMENT keyword
%type autoinc {int}
autoinc(X) ::= .          {X = 0;}
autoinc(X) ::= AUTOINCR.  {X = 1;}

// The next group of rules parses the arguments to a REFERENCES clause
// that determine if the referential integrity checking is deferred or
// or immediate and which determine what action to take if a ref-integ
// check fails.
//
%type refargs {int}
refargs(A) ::= .                     { A = OE_Restrict * 0x010101; }
refargs(A) ::= refargs(X) refarg(Y). { A = (X & Y.mask) | Y.value; }
%type refarg {struct {int value; int mask;}}
refarg(A) ::= MATCH nm.              { A.value = 0;     A.mask = 0x000000; }
refarg(A) ::= ON DELETE refact(X).   { A.value = X;     A.mask = 0x0000ff; }
refarg(A) ::= ON UPDATE refact(X).   { A.value = X<<8;  A.mask = 0x00ff00; }
refarg(A) ::= ON INSERT refact(X).   { A.value = X<<16; A.mask = 0xff0000; }
%type refact {int}
refact(A) ::= SET NULL.              { A = OE_SetNull; }
refact(A) ::= SET DEFAULT.           { A = OE_SetDflt; }
refact(A) ::= CASCADE.               { A = OE_Cascade; }
refact(A) ::= RESTRICT.              { A = OE_Restrict; }
%type defer_subclause {int}
defer_subclause(A) ::= NOT DEFERRABLE init_deferred_pred_opt(X).  {A = X;}
defer_subclause(A) ::= DEFERRABLE init_deferred_pred_opt(X).      {A = X;}
%type init_deferred_pred_opt {int}
init_deferred_pred_opt(A) ::= .                       {A = 0;}
init_deferred_pred_opt(A) ::= INITIALLY DEFERRED.     {A = 1;}
init_deferred_pred_opt(A) ::= INITIALLY IMMEDIATE.    {A = 0;}

// For the time being, the only constraint we care about is the primary
// key and UNIQUE.  Both create indices.
//
conslist_opt(A) ::= .                   {A.n = 0; A.z = 0;}
conslist_opt(A) ::= COMMA(X) conslist.  {A = X;}
conslist ::= conslist COMMA tcons.
conslist ::= conslist tcons.
conslist ::= tcons.
tcons ::= CONSTRAINT nm.
tcons ::= PRIMARY KEY LP idxlist(X) autoinc(I) RP onconf(R).
                                         {sqlite3AddPrimaryKey(pParse,X,R,I);}
tcons ::= UNIQUE LP idxlist(X) RP onconf(R).
                                       {sqlite3CreateIndex(pParse,0,0,0,X,R,0,0);}
tcons ::= CHECK expr onconf.
tcons ::= FOREIGN KEY LP idxlist(FA) RP
          REFERENCES nm(T) idxlist_opt(TA) refargs(R) defer_subclause_opt(D). {
    sqlite3CreateForeignKey(pParse, FA, &T, TA, R);
    sqlite3DeferForeignKey(pParse, D);
}
%type defer_subclause_opt {int}
defer_subclause_opt(A) ::= .                    {A = 0;}
defer_subclause_opt(A) ::= defer_subclause(X).  {A = X;}

// The following is a non-standard extension that allows us to declare the
// default behavior when there is a constraint conflict.
//
%type onconf {int}
%type orconf {int}
%type resolvetype {int}
onconf(A) ::= .                              {A = OE_Default;}
onconf(A) ::= ON CONFLICT resolvetype(X).    {A = X;}
orconf(A) ::= .                              {A = OE_Default;}
orconf(A) ::= OR resolvetype(X).             {A = X;}
resolvetype(A) ::= raisetype(X).             {A = X;}
resolvetype(A) ::= IGNORE.                   {A = OE_Ignore;}
resolvetype(A) ::= REPLACE.                  {A = OE_Replace;}

////////////////////////// The DROP TABLE /////////////////////////////////////
//
cmd ::= DROP TABLE fullname(X). {
  sqlite3DropTable(pParse, X, 0);
}

///////////////////// The CREATE VIEW statement /////////////////////////////
//
%ifndef SQLITE_OMIT_VIEW
cmd ::= CREATE(X) temp(T) VIEW nm(Y) dbnm(Z) AS select(S). {
  sqlite3CreateView(pParse, &X, &Y, &Z, S, T);
}
cmd ::= DROP VIEW fullname(X). {
  sqlite3DropTable(pParse, X, 1);
}
%endif // SQLITE_OMIT_VIEW

//////////////////////// The SELECT statement /////////////////////////////////
//
cmd ::= select(X).  {
  sqlite3Select(pParse, X, SRT_Callback, 0, 0, 0, 0, 0);
  sqlite3SelectDelete(X);
}

%type select {Select*}
%destructor select {sqlite3SelectDelete($$);}
%type oneselect {Select*}
%destructor oneselect {sqlite3SelectDelete($$);}

select(A) ::= oneselect(X).                      {A = X;}
%ifndef SQLITE_OMIT_COMPOUND_SELECT
select(A) ::= select(X) multiselect_op(Y) oneselect(Z).  {
  if( Z ){
    Z->op = Y;
    Z->pPrior = X;
  }
  A = Z;
}
%type multiselect_op {int}
multiselect_op(A) ::= UNION(OP).      {A = @OP;}
multiselect_op(A) ::= UNION ALL.      {A = TK_ALL;}
multiselect_op(A) ::= INTERSECT(OP).  {A = @OP;}
multiselect_op(A) ::= EXCEPT(OP).     {A = @OP;}
%endif // SQLITE_OMIT_COMPOUND_SELECT
oneselect(A) ::= SELECT distinct(D) selcollist(W) from(X) where_opt(Y)
                 groupby_opt(P) having_opt(Q) orderby_opt(Z) limit_opt(L). {
  A = sqlite3SelectNew(W,X,Y,P,Q,Z,D,L.pLimit,L.pOffset);
}

// The "distinct" nonterminal is true (1) if the DISTINCT keyword is
// present and false (0) if it is not.
//
%type distinct {int}
distinct(A) ::= DISTINCT.   {A = 1;}
distinct(A) ::= ALL.        {A = 0;}
distinct(A) ::= .           {A = 0;}

// selcollist is a list of expressions that are to become the return
// values of the SELECT statement.  The "*" in statements like
// "SELECT * FROM ..." is encoded as a special expression with an
// opcode of TK_ALL.
//
%type selcollist {ExprList*}
%destructor selcollist {sqlite3ExprListDelete($$);}
%type sclp {ExprList*}
%destructor sclp {sqlite3ExprListDelete($$);}
sclp(A) ::= selcollist(X) COMMA.             {A = X;}
sclp(A) ::= .                                {A = 0;}
selcollist(A) ::= sclp(P) expr(X) as(Y).     {
   A = sqlite3ExprListAppend(P,X,Y.n?&Y:0);
}
selcollist(A) ::= sclp(P) STAR. {
  A = sqlite3ExprListAppend(P, sqlite3Expr(TK_ALL, 0, 0, 0), 0);
}
selcollist(A) ::= sclp(P) nm(X) DOT STAR. {
  Expr *pRight = sqlite3Expr(TK_ALL, 0, 0, 0);
  Expr *pLeft = sqlite3Expr(TK_ID, 0, 0, &X);
  A = sqlite3ExprListAppend(P, sqlite3Expr(TK_DOT, pLeft, pRight, 0), 0);
}

// An option "AS <id>" phrase that can follow one of the expressions that
// define the result set, or one of the tables in the FROM clause.
//
%type as {Token}
as(X) ::= AS nm(Y).    {X = Y;}
as(X) ::= ids(Y).      {X = Y;}
as(X) ::= .            {X.n = 0;}


%type seltablist {SrcList*}
%destructor seltablist {sqlite3SrcListDelete($$);}
%type stl_prefix {SrcList*}
%destructor stl_prefix {sqlite3SrcListDelete($$);}
%type from {SrcList*}
%destructor from {sqlite3SrcListDelete($$);}

// A complete FROM clause.
//
from(A) ::= .                                 {A = sqliteMalloc(sizeof(*A));}
from(A) ::= FROM seltablist(X).               {A = X;}

// "seltablist" is a "Select Table List" - the content of the FROM clause
// in a SELECT statement.  "stl_prefix" is a prefix of this list.
//
stl_prefix(A) ::= seltablist(X) joinop(Y).    {
   A = X;
   if( A && A->nSrc>0 ) A->a[A->nSrc-1].jointype = Y;
}
stl_prefix(A) ::= .                           {A = 0;}
seltablist(A) ::= stl_prefix(X) nm(Y) dbnm(D) as(Z) on_opt(N) using_opt(U). {
  A = sqlite3SrcListAppend(X,&Y,&D);
  if( Z.n ) sqlite3SrcListAddAlias(A,&Z);
  if( N ){
    if( A && A->nSrc>1 ){ A->a[A->nSrc-2].pOn = N; }
    else { sqlite3ExprDelete(N); }
  }
  if( U ){
    if( A && A->nSrc>1 ){ A->a[A->nSrc-2].pUsing = U; }
    else { sqlite3IdListDelete(U); }
  }
}
%ifndef SQLITE_OMIT_SUBQUERY
  seltablist(A) ::= stl_prefix(X) LP seltablist_paren(S) RP
                    as(Z) on_opt(N) using_opt(U). {
    A = sqlite3SrcListAppend(X,0,0);
    A->a[A->nSrc-1].pSelect = S;
    if( Z.n ) sqlite3SrcListAddAlias(A,&Z);
    if( N ){
      if( A && A->nSrc>1 ){ A->a[A->nSrc-2].pOn = N; }
      else { sqlite3ExprDelete(N); }
    }
    if( U ){
      if( A && A->nSrc>1 ){ A->a[A->nSrc-2].pUsing = U; }
      else { sqlite3IdListDelete(U); }
    }
  }
  
 // A seltablist_paren nonterminal represents anything in a FROM that
  // is contained inside parentheses.  This can be either a subquery or
  // a grouping of table and subqueries.
  //
  %type seltablist_paren {Select*}
  %destructor seltablist_paren {sqlite3SelectDelete($$);}
  seltablist_paren(A) ::= select(S).      {A = S;}
  seltablist_paren(A) ::= seltablist(F).  {
     A = sqlite3SelectNew(0,F,0,0,0,0,0,0,0);
  }
%endif // SQLITE_OMIT_SUBQUERY

%type dbnm {Token}
dbnm(A) ::= .          {A.z=0; A.n=0;}
dbnm(A) ::= DOT nm(X). {A = X;}

%type fullname {SrcList*}
%destructor fullname {sqlite3SrcListDelete($$);}
fullname(A) ::= nm(X) dbnm(Y).  {A = sqlite3SrcListAppend(0,&X,&Y);}

%type joinop {int}
%type joinop2 {int}
joinop(X) ::= COMMA.                   { X = JT_INNER; }
joinop(X) ::= JOIN.                    { X = JT_INNER; }
joinop(X) ::= JOIN_KW(A) JOIN.         { X = sqlite3JoinType(pParse,&A,0,0); }
joinop(X) ::= JOIN_KW(A) nm(B) JOIN.   { X = sqlite3JoinType(pParse,&A,&B,0); }
joinop(X) ::= JOIN_KW(A) nm(B) nm(C) JOIN.
                                       { X = sqlite3JoinType(pParse,&A,&B,&C); }

%type on_opt {Expr*}
%destructor on_opt {sqlite3ExprDelete($$);}
on_opt(N) ::= ON expr(E).   {N = E;}
on_opt(N) ::= .             {N = 0;}

%type using_opt {IdList*}
%destructor using_opt {sqlite3IdListDelete($$);}
using_opt(U) ::= USING LP inscollist(L) RP.  {U = L;}
using_opt(U) ::= .                        {U = 0;}


%type orderby_opt {ExprList*}
%destructor orderby_opt {sqlite3ExprListDelete($$);}
%type sortlist {ExprList*}
%destructor sortlist {sqlite3ExprListDelete($$);}
%type sortitem {Expr*}
%destructor sortitem {sqlite3ExprDelete($$);}

orderby_opt(A) ::= .                          {A = 0;}
orderby_opt(A) ::= ORDER BY sortlist(X).      {A = X;}
sortlist(A) ::= sortlist(X) COMMA sortitem(Y) collate(C) sortorder(Z). {
  A = sqlite3ExprListAppend(X,Y,C.n>0?&C:0);
  if( A ) A->a[A->nExpr-1].sortOrder = Z;
}
sortlist(A) ::= sortitem(Y) collate(C) sortorder(Z). {
  A = sqlite3ExprListAppend(0,Y,C.n>0?&C:0);
  if( A && A->a ) A->a[0].sortOrder = Z;
}
sortitem(A) ::= expr(X).   {A = X;}

%type sortorder {int}
%type collate {Token}

sortorder(A) ::= ASC.           {A = SQLITE_SO_ASC;}
sortorder(A) ::= DESC.          {A = SQLITE_SO_DESC;}
sortorder(A) ::= .              {A = SQLITE_SO_ASC;}
collate(C) ::= .                {C.z = 0; C.n = 0;}
collate(C) ::= COLLATE id(X).   {C = X;}

%type groupby_opt {ExprList*}
%destructor groupby_opt {sqlite3ExprListDelete($$);}
groupby_opt(A) ::= .                      {A = 0;}
groupby_opt(A) ::= GROUP BY exprlist(X).  {A = X;}

%type having_opt {Expr*}
%destructor having_opt {sqlite3ExprDelete($$);}
having_opt(A) ::= .                {A = 0;}
having_opt(A) ::= HAVING expr(X).  {A = X;}

%type limit_opt {struct LimitVal}
%destructor limit_opt {
  sqlite3ExprDelete($$.pLimit);
  sqlite3ExprDelete($$.pOffset);
}
limit_opt(A) ::= .                     {A.pLimit = 0; A.pOffset = 0;}
limit_opt(A) ::= LIMIT expr(X).        {A.pLimit = X; A.pOffset = 0;}
limit_opt(A) ::= LIMIT expr(X) OFFSET expr(Y). 
                                       {A.pLimit = X; A.pOffset = Y;}
limit_opt(A) ::= LIMIT expr(X) COMMA expr(Y). 
                                       {A.pOffset = X; A.pLimit = Y;}

/////////////////////////// The DELETE statement /////////////////////////////
//
cmd ::= DELETE FROM fullname(X) where_opt(Y). {sqlite3DeleteFrom(pParse,X,Y);}

%type where_opt {Expr*}
%destructor where_opt {sqlite3ExprDelete($$);}

where_opt(A) ::= .                    {A = 0;}
where_opt(A) ::= WHERE expr(X).       {A = X;}

%type setlist {ExprList*}
%destructor setlist {sqlite3ExprListDelete($$);}

////////////////////////// The UPDATE command ////////////////////////////////
//
cmd ::= UPDATE orconf(R) fullname(X) SET setlist(Y) where_opt(Z).
    {sqlite3Update(pParse,X,Y,Z,R);}

setlist(A) ::= setlist(Z) COMMA nm(X) EQ expr(Y).
    {A = sqlite3ExprListAppend(Z,Y,&X);}
setlist(A) ::= nm(X) EQ expr(Y).   {A = sqlite3ExprListAppend(0,Y,&X);}

////////////////////////// The INSERT command /////////////////////////////////
//
cmd ::= insert_cmd(R) INTO fullname(X) inscollist_opt(F) 
        VALUES LP itemlist(Y) RP.
            {sqlite3Insert(pParse, X, Y, 0, F, R);}
cmd ::= insert_cmd(R) INTO fullname(X) inscollist_opt(F) select(S).
            {sqlite3Insert(pParse, X, 0, S, F, R);}

%type insert_cmd {int}
insert_cmd(A) ::= INSERT orconf(R).   {A = R;}
insert_cmd(A) ::= REPLACE.            {A = OE_Replace;}


%type itemlist {ExprList*}
%destructor itemlist {sqlite3ExprListDelete($$);}

itemlist(A) ::= itemlist(X) COMMA expr(Y).  {A = sqlite3ExprListAppend(X,Y,0);}
itemlist(A) ::= expr(X).                    {A = sqlite3ExprListAppend(0,X,0);}

%type inscollist_opt {IdList*}
%destructor inscollist_opt {sqlite3IdListDelete($$);}
%type inscollist {IdList*}
%destructor inscollist {sqlite3IdListDelete($$);}

inscollist_opt(A) ::= .                       {A = 0;}
inscollist_opt(A) ::= LP inscollist(X) RP.    {A = X;}
inscollist(A) ::= inscollist(X) COMMA nm(Y).  {A = sqlite3IdListAppend(X,&Y);}
inscollist(A) ::= nm(Y).                      {A = sqlite3IdListAppend(0,&Y);}

/////////////////////////// Expression Processing /////////////////////////////
//

%type expr {Expr*}
%destructor expr {sqlite3ExprDelete($$);}
%type term {Expr*}
%destructor term {sqlite3ExprDelete($$);}

expr(A) ::= term(X).             {A = X;}
expr(A) ::= LP(B) expr(X) RP(E). {A = X; sqlite3ExprSpan(A,&B,&E); }
term(A) ::= NULL(X).             {A = sqlite3Expr(@X, 0, 0, &X);}
expr(A) ::= ID(X).               {A = sqlite3Expr(TK_ID, 0, 0, &X);}
expr(A) ::= JOIN_KW(X).          {A = sqlite3Expr(TK_ID, 0, 0, &X);}
expr(A) ::= nm(X) DOT nm(Y). {
  Expr *temp1 = sqlite3Expr(TK_ID, 0, 0, &X);
  Expr *temp2 = sqlite3Expr(TK_ID, 0, 0, &Y);
  A = sqlite3Expr(TK_DOT, temp1, temp2, 0);
}
expr(A) ::= nm(X) DOT nm(Y) DOT nm(Z). {
  Expr *temp1 = sqlite3Expr(TK_ID, 0, 0, &X);
  Expr *temp2 = sqlite3Expr(TK_ID, 0, 0, &Y);
  Expr *temp3 = sqlite3Expr(TK_ID, 0, 0, &Z);
  Expr *temp4 = sqlite3Expr(TK_DOT, temp2, temp3, 0);
  A = sqlite3Expr(TK_DOT, temp1, temp4, 0);
}
term(A) ::= INTEGER(X).      {A = sqlite3Expr(@X, 0, 0, &X);}
term(A) ::= FLOAT(X).        {A = sqlite3Expr(@X, 0, 0, &X);}
term(A) ::= STRING(X).       {A = sqlite3Expr(@X, 0, 0, &X);}
term(A) ::= BLOB(X).         {A = sqlite3Expr(@X, 0, 0, &X);}
expr(A) ::= REGISTER(X).     {A = sqlite3RegisterExpr(pParse, &X);}
expr(A) ::= VARIABLE(X).     {
  Token *pToken = &X;
  Expr *pExpr = A = sqlite3Expr(TK_VARIABLE, 0, 0, pToken);
  sqlite3ExprAssignVarNumber(pParse, pExpr);
}
expr(A) ::= ID(X) LP exprlist(Y) RP(E). {
  A = sqlite3ExprFunction(Y, &X);
  sqlite3ExprSpan(A,&X,&E);
}
expr(A) ::= ID(X) LP STAR RP(E). {
  A = sqlite3ExprFunction(0, &X);
  sqlite3ExprSpan(A,&X,&E);
}
term(A) ::= CTIME(OP).                  {A = sqlite3Expr(@OP,0,0,0);}
term(A) ::= CDATE(OP).                  {A = sqlite3Expr(@OP,0,0,0);}
term(A) ::= CTIMESTAMP(OP).             {A = sqlite3Expr(@OP,0,0,0);}
expr(A) ::= expr(X) AND(OP) expr(Y).    {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) OR(OP) expr(Y).     {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) LT(OP) expr(Y).     {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) GT(OP) expr(Y).     {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) LE(OP) expr(Y).     {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) GE(OP) expr(Y).     {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) NE(OP) expr(Y).     {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) EQ(OP) expr(Y).     {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) BITAND(OP) expr(Y). {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) BITOR(OP) expr(Y).  {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) LSHIFT(OP) expr(Y). {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) RSHIFT(OP) expr(Y). {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) PLUS(OP) expr(Y).   {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) MINUS(OP) expr(Y).  {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) STAR(OP) expr(Y).   {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) SLASH(OP) expr(Y).  {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) REM(OP) expr(Y).    {A = sqlite3Expr(@OP, X, Y, 0);}
expr(A) ::= expr(X) CONCAT(OP) expr(Y). {A = sqlite3Expr(@OP, X, Y, 0);}
%type likeop {struct LikeOp}
likeop(A) ::= LIKE.     {A.opcode = TK_LIKE; A.not = 0;}
likeop(A) ::= GLOB.     {A.opcode = TK_GLOB; A.not = 0;}
likeop(A) ::= NOT LIKE. {A.opcode = TK_LIKE; A.not = 1;}
likeop(A) ::= NOT GLOB. {A.opcode = TK_GLOB; A.not = 1;}
%type escape {Expr*}
escape(X) ::= ESCAPE expr(A). [ESCAPE] {X = A;}
escape(X) ::= .               [ESCAPE] {X = 0;}
expr(A) ::= expr(X) likeop(OP) expr(Y) escape(E).  [LIKE]  {
  ExprList *pList = sqlite3ExprListAppend(0, Y, 0);
  pList = sqlite3ExprListAppend(pList, X, 0);
  if( E ){
    pList = sqlite3ExprListAppend(pList, E, 0);
  }
  A = sqlite3ExprFunction(pList, 0);
  if( A ) A->op = OP.opcode;
  if( OP.not ) A = sqlite3Expr(TK_NOT, A, 0, 0);
  sqlite3ExprSpan(A, &X->span, &Y->span);
}

expr(A) ::= expr(X) ISNULL(E). {
  A = sqlite3Expr(TK_ISNULL, X, 0, 0);
  sqlite3ExprSpan(A,&X->span,&E);
}
expr(A) ::= expr(X) IS NULL(E). {
  A = sqlite3Expr(TK_ISNULL, X, 0, 0);
  sqlite3ExprSpan(A,&X->span,&E);
}
expr(A) ::= expr(X) NOTNULL(E). {
  A = sqlite3Expr(TK_NOTNULL, X, 0, 0);
  sqlite3ExprSpan(A,&X->span,&E);
}
expr(A) ::= expr(X) NOT NULL(E). {
  A = sqlite3Expr(TK_NOTNULL, X, 0, 0);
  sqlite3ExprSpan(A,&X->span,&E);
}
expr(A) ::= expr(X) IS NOT NULL(E). {
  A = sqlite3Expr(TK_NOTNULL, X, 0, 0);
  sqlite3ExprSpan(A,&X->span,&E);
}
expr(A) ::= NOT(B) expr(X). {
  A = sqlite3Expr(@B, X, 0, 0);
  sqlite3ExprSpan(A,&B,&X->span);
}
expr(A) ::= BITNOT(B) expr(X). {
  A = sqlite3Expr(@B, X, 0, 0);
  sqlite3ExprSpan(A,&B,&X->span);
}
expr(A) ::= MINUS(B) expr(X). [UMINUS] {
  A = sqlite3Expr(TK_UMINUS, X, 0, 0);
  sqlite3ExprSpan(A,&B,&X->span);
}
expr(A) ::= PLUS(B) expr(X). [UPLUS] {
  A = sqlite3Expr(TK_UPLUS, X, 0, 0);
  sqlite3ExprSpan(A,&B,&X->span);
}
%type between_op {int}
between_op(A) ::= BETWEEN.     {A = 0;}
between_op(A) ::= NOT BETWEEN. {A = 1;}
expr(A) ::= expr(W) between_op(N) expr(X) AND expr(Y). [BETWEEN] {
  ExprList *pList = sqlite3ExprListAppend(0, X, 0);
  pList = sqlite3ExprListAppend(pList, Y, 0);
  A = sqlite3Expr(TK_BETWEEN, W, 0, 0);
  if( A ) A->pList = pList;
  if( N ) A = sqlite3Expr(TK_NOT, A, 0, 0);
  sqlite3ExprSpan(A,&W->span,&Y->span);
}
%ifndef SQLITE_OMIT_SUBQUERY
  %type in_op {int}
  in_op(A) ::= IN.      {A = 0;}
  in_op(A) ::= NOT IN.  {A = 1;}
  expr(A) ::= expr(X) in_op(N) LP exprlist(Y) RP(E). [IN] {
    A = sqlite3Expr(TK_IN, X, 0, 0);
    if( A ){
      A->pList = Y;
    }else{
      sqlite3ExprListDelete(Y);
    }
    if( N ) A = sqlite3Expr(TK_NOT, A, 0, 0);
    sqlite3ExprSpan(A,&X->span,&E);
  }
  expr(A) ::= LP(B) select(X) RP(E). {
    A = sqlite3Expr(TK_SELECT, 0, 0, 0);
    if( A ) A->pSelect = X;
    if( !A ) sqlite3SelectDelete(X);
    sqlite3ExprSpan(A,&B,&E);
  }
  expr(A) ::= expr(X) in_op(N) LP select(Y) RP(E).  [IN] {
    A = sqlite3Expr(TK_IN, X, 0, 0);
    if( A ) A->pSelect = Y;
    if( !A ) sqlite3SelectDelete(Y);
    if( N ) A = sqlite3Expr(TK_NOT, A, 0, 0);
    sqlite3ExprSpan(A,&X->span,&E);
  }
  expr(A) ::= expr(X) in_op(N) nm(Y) dbnm(Z). [IN] {
    SrcList *pSrc = sqlite3SrcListAppend(0,&Y,&Z);
    A = sqlite3Expr(TK_IN, X, 0, 0);
    if( A ) A->pSelect = sqlite3SelectNew(0,pSrc,0,0,0,0,0,0,0);
    if( N ) A = sqlite3Expr(TK_NOT, A, 0, 0);
    sqlite3ExprSpan(A,&X->span,Z.z?&Z:&Y);
  }
  expr(A) ::= EXISTS(B) LP select(Y) RP(E). {
    Expr *p = A = sqlite3Expr(TK_EXISTS, 0, 0, 0);
    if( p ){
      p->pSelect = Y;
      sqlite3ExprSpan(p,&B,&E);
    }
    if( !p ) sqlite3SelectDelete(Y);
  }
%endif // SQLITE_OMIT_SUBQUERY

/* CASE expressions */
expr(A) ::= CASE(C) case_operand(X) case_exprlist(Y) case_else(Z) END(E). {
  A = sqlite3Expr(TK_CASE, X, Z, 0);
  if( A ) A->pList = Y;
  sqlite3ExprSpan(A, &C, &E);
}
%type case_exprlist {ExprList*}
%destructor case_exprlist {sqlite3ExprListDelete($$);}
case_exprlist(A) ::= case_exprlist(X) WHEN expr(Y) THEN expr(Z). {
  A = sqlite3ExprListAppend(X, Y, 0);
  A = sqlite3ExprListAppend(A, Z, 0);
}
case_exprlist(A) ::= WHEN expr(Y) THEN expr(Z). {
  A = sqlite3ExprListAppend(0, Y, 0);
  A = sqlite3ExprListAppend(A, Z, 0);
}
%type case_else {Expr*}
case_else(A) ::=  ELSE expr(X).         {A = X;}
case_else(A) ::=  .                     {A = 0;} 
%type case_operand {Expr*}
case_operand(A) ::= expr(X).            {A = X;} 
case_operand(A) ::= .                   {A = 0;} 

%type exprlist {ExprList*}
%destructor exprlist {sqlite3ExprListDelete($$);}
%type expritem {Expr*}
%destructor expritem {sqlite3ExprDelete($$);}

exprlist(A) ::= exprlist(X) COMMA expritem(Y). 
                                        {A = sqlite3ExprListAppend(X,Y,0);}
exprlist(A) ::= expritem(X).            {A = sqlite3ExprListAppend(0,X,0);}
expritem(A) ::= expr(X).                {A = X;}
expritem(A) ::= .                       {A = 0;}

///////////////////////////// The CREATE INDEX command ///////////////////////
//
cmd ::= CREATE(S) uniqueflag(U) INDEX nm(X) dbnm(D)
        ON nm(Y) LP idxlist(Z) RP(E) onconf(R). {
  if( U!=OE_None ) U = R;
  if( U==OE_Default) U = OE_Abort;
  sqlite3CreateIndex(pParse, &X, &D, sqlite3SrcListAppend(0,&Y,0),Z,U, &S, &E);
}

%type uniqueflag {int}
uniqueflag(A) ::= UNIQUE.  {A = OE_Abort;}
uniqueflag(A) ::= .        {A = OE_None;}

%type idxlist {ExprList*}
%destructor idxlist {sqlite3ExprListDelete($$);}
%type idxlist_opt {ExprList*}
%destructor idxlist_opt {sqlite3ExprListDelete($$);}
%type idxitem {Token}

idxlist_opt(A) ::= .                         {A = 0;}
idxlist_opt(A) ::= LP idxlist(X) RP.         {A = X;}
idxlist(A) ::= idxlist(X) COMMA idxitem(Y) collate(C) sortorder.  {
  Expr *p = 0;
  if( C.n>0 ){
    p = sqlite3Expr(TK_COLUMN, 0, 0, 0);
    if( p ) p->pColl = sqlite3LocateCollSeq(pParse, C.z, C.n);
  }
  A = sqlite3ExprListAppend(X, p, &Y);
}
idxlist(A) ::= idxitem(Y) collate(C) sortorder. {
  Expr *p = 0;
  if( C.n>0 ){
    p = sqlite3Expr(TK_COLUMN, 0, 0, 0);
    if( p ) p->pColl = sqlite3LocateCollSeq(pParse, C.z, C.n);
  }
  A = sqlite3ExprListAppend(0, p, &Y);
}
idxitem(A) ::= nm(X).              {A = X;}


///////////////////////////// The DROP INDEX command /////////////////////////
//
cmd ::= DROP INDEX fullname(X).   {sqlite3DropIndex(pParse, X);}

///////////////////////////// The VACUUM command /////////////////////////////
//
cmd ::= VACUUM.                {sqlite3Vacuum(pParse,0);}
cmd ::= VACUUM nm.             {sqlite3Vacuum(pParse,0);}

///////////////////////////// The PRAGMA command /////////////////////////////
//
%ifndef SQLITE_OMIT_PRAGMA
cmd ::= PRAGMA nm(X) dbnm(Z) EQ nm(Y).  {sqlite3Pragma(pParse,&X,&Z,&Y,0);}
cmd ::= PRAGMA nm(X) dbnm(Z) EQ ON(Y).  {sqlite3Pragma(pParse,&X,&Z,&Y,0);}
cmd ::= PRAGMA nm(X) dbnm(Z) EQ plus_num(Y). {sqlite3Pragma(pParse,&X,&Z,&Y,0);}
cmd ::= PRAGMA nm(X) dbnm(Z) EQ minus_num(Y). {
  sqlite3Pragma(pParse,&X,&Z,&Y,1);
}
cmd ::= PRAGMA nm(X) dbnm(Z) LP nm(Y) RP. {sqlite3Pragma(pParse,&X,&Z,&Y,0);}
cmd ::= PRAGMA nm(X) dbnm(Z).             {sqlite3Pragma(pParse,&X,&Z,0,0);}
%endif // SQLITE_OMIT_PRAGMA
plus_num(A) ::= plus_opt number(X).   {A = X;}
minus_num(A) ::= MINUS number(X).     {A = X;}
number(A) ::= INTEGER(X).             {A = X;}
number(A) ::= FLOAT(X).               {A = X;}
plus_opt ::= PLUS.
plus_opt ::= .

//////////////////////////// The CREATE TRIGGER command /////////////////////

%ifndef SQLITE_OMIT_TRIGGER

cmd ::= CREATE trigger_decl(A) BEGIN trigger_cmd_list(S) END(Z). {
  Token all;
  all.z = A.z;
  all.n = (Z.z - A.z) + Z.n;
  sqlite3FinishTrigger(pParse, S, &all);
}

trigger_decl(A) ::= temp(T) TRIGGER nm(B) dbnm(Z) trigger_time(C)
                    trigger_event(D)
                    ON fullname(E) foreach_clause(F) when_clause(G). {
  sqlite3BeginTrigger(pParse, &B, &Z, C, D.a, D.b, E, F, G, T);
  A = (Z.n==0?B:Z);
}

%type trigger_time  {int}
trigger_time(A) ::= BEFORE.      { A = TK_BEFORE; }
trigger_time(A) ::= AFTER.       { A = TK_AFTER;  }
trigger_time(A) ::= INSTEAD OF.  { A = TK_INSTEAD;}
trigger_time(A) ::= .            { A = TK_BEFORE; }

%type trigger_event {struct TrigEvent}
%destructor trigger_event {sqlite3IdListDelete($$.b);}
trigger_event(A) ::= DELETE(OP).              {A.a = @OP; A.b = 0;}
trigger_event(A) ::= INSERT(OP).              {A.a = @OP; A.b = 0;}
trigger_event(A) ::= UPDATE(OP).              {A.a = @OP; A.b = 0;}
trigger_event(A) ::= UPDATE OF inscollist(X). {A.a = TK_UPDATE; A.b = X;}

%type foreach_clause {int}
foreach_clause(A) ::= .                   { A = TK_ROW; }
foreach_clause(A) ::= FOR EACH ROW.       { A = TK_ROW; }
foreach_clause(A) ::= FOR EACH STATEMENT. { A = TK_STATEMENT; }

%type when_clause {Expr*}
when_clause(A) ::= .             { A = 0; }
when_clause(A) ::= WHEN expr(X). { A = X; }

%type trigger_cmd_list {TriggerStep*}
%destructor trigger_cmd_list {sqlite3DeleteTriggerStep($$);}
trigger_cmd_list(A) ::= trigger_cmd(X) SEMI trigger_cmd_list(Y). {
  X->pNext = Y;
  A = X;
}
trigger_cmd_list(A) ::= . { A = 0; }

%type trigger_cmd {TriggerStep*}
%destructor trigger_cmd {sqlite3DeleteTriggerStep($$);}
// UPDATE 
trigger_cmd(A) ::= UPDATE orconf(R) nm(X) SET setlist(Y) where_opt(Z).  
               { A = sqlite3TriggerUpdateStep(&X, Y, Z, R); }

// INSERT
trigger_cmd(A) ::= insert_cmd(R) INTO nm(X) inscollist_opt(F) 
                   VALUES LP itemlist(Y) RP.  
               {A = sqlite3TriggerInsertStep(&X, F, Y, 0, R);}

trigger_cmd(A) ::= insert_cmd(R) INTO nm(X) inscollist_opt(F) select(S).
               {A = sqlite3TriggerInsertStep(&X, F, 0, S, R);}

// DELETE
trigger_cmd(A) ::= DELETE FROM nm(X) where_opt(Y).
               {A = sqlite3TriggerDeleteStep(&X, Y);}

// SELECT
trigger_cmd(A) ::= select(X).  {A = sqlite3TriggerSelectStep(X); }

// The special RAISE expression that may occur in trigger programs
expr(A) ::= RAISE(X) LP IGNORE RP(Y).  {
  A = sqlite3Expr(TK_RAISE, 0, 0, 0); 
  A->iColumn = OE_Ignore;
  sqlite3ExprSpan(A, &X, &Y);
}
expr(A) ::= RAISE(X) LP raisetype(T) COMMA nm(Z) RP(Y).  {
  A = sqlite3Expr(TK_RAISE, 0, 0, &Z); 
  A->iColumn = T;
  sqlite3ExprSpan(A, &X, &Y);
}
%endif // !SQLITE_OMIT_TRIGGER

%type raisetype {int}
raisetype(A) ::= ROLLBACK.  {A = OE_Rollback;}
raisetype(A) ::= ABORT.     {A = OE_Abort;}
raisetype(A) ::= FAIL.      {A = OE_Fail;}


////////////////////////  DROP TRIGGER statement //////////////////////////////
%ifndef SQLITE_OMIT_TRIGGER
cmd ::= DROP TRIGGER fullname(X). {
  sqlite3DropTrigger(pParse,X);
}
%endif // !SQLITE_OMIT_TRIGGER

//////////////////////// ATTACH DATABASE file AS name /////////////////////////
cmd ::= ATTACH database_kw_opt ids(F) AS nm(D) key_opt(K). {
  sqlite3Attach(pParse, &F, &D, K.type, &K.key);
}
%type key_opt {struct AttachKey}
key_opt(A) ::= .                     { A.type = 0; }
key_opt(A) ::= KEY ids(X).           { A.type=1; A.key = X; }
key_opt(A) ::= KEY BLOB(X).          { A.type=2; A.key = X; }

database_kw_opt ::= DATABASE.
database_kw_opt ::= .

//////////////////////// DETACH DATABASE name /////////////////////////////////
cmd ::= DETACH database_kw_opt nm(D). {
  sqlite3Detach(pParse, &D);
}

////////////////////////// REINDEX collation //////////////////////////////////
%ifndef SQLITE_OMIT_REINDEX
cmd ::= REINDEX.                {sqlite3Reindex(pParse, 0, 0);}
cmd ::= REINDEX nm(X) dbnm(Y).  {sqlite3Reindex(pParse, &X, &Y);}
%endif

//////////////////////// ALTER TABLE table ... ////////////////////////////////
%ifndef SQLITE_OMIT_ALTERTABLE
cmd ::= ALTER TABLE fullname(X) RENAME TO nm(Z). {
  sqlite3AlterRenameTable(pParse,X,&Z);
}
cmd ::= ALTER TABLE add_column_fullname ADD kwcolumn_opt column(Y). {
  sqlite3AlterFinishAddColumn(pParse, &Y);
}
add_column_fullname ::= fullname(X). {
  sqlite3AlterBeginAddColumn(pParse, X);
}
kwcolumn_opt ::= .
kwcolumn_opt ::= COLUMNKW.
%endif
