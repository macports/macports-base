/*
 * WARNING: for perl iterator/array support you need to run
 *   sed -i -e 's/SvTYPE(tsv) == SVt_PVHV/SvTYPE(tsv) == SVt_PVHV || SvTYPE(tsv) == SVt_PVAV/'
 * on the generated c code
 */

%module solv

#ifdef SWIGRUBY
%markfunc Pool "mark_Pool";
#endif

/*
 * binaryblob handling
 */

%{
typedef struct {
  const void *data;
  size_t len;
} BinaryBlob;
%}

%typemap(in,noblock=1,fragment="SWIG_AsCharPtrAndSize") (const unsigned char *str, size_t len) (int res, char *buf = 0, size_t size = 0, int alloc = 0) {
  res = SWIG_AsCharPtrAndSize($input, &buf, &size, &alloc);
  if (!SWIG_IsOK(res)) {
#if defined(SWIGPYTHON)
    const void *pybuf = 0;
    Py_ssize_t pysize = 0;
    res = PyObject_AsReadBuffer($input, &pybuf, &pysize);
    if (res < 0) {
      %argument_fail(res, "BinaryBlob", $symname, $argnum);
    } else {
      buf = (void *)pybuf;
      size = pysize;
    }
#else
    %argument_fail(res, "const char *", $symname, $argnum);
#endif
  }
  $1 = (unsigned char *)buf;
  $2 = size;
}

%typemap(freearg,noblock=1,match="in") (const unsigned char *str, int len) {
  if (alloc$argnum == SWIG_NEWOBJ) %delete_array(buf$argnum);
}

%typemap(out,noblock=1,fragment="SWIG_FromCharPtrAndSize") BinaryBlob {
#if defined(SWIGPYTHON) && defined(PYTHON3)
  $result = $1.data ? Py_BuildValue("y#", $1.data, $1.len) : SWIG_Py_Void();
#elif defined(SWIGTCL)
  Tcl_SetObjResult(interp, SWIG_FromCharPtrAndSize($1.data, $1.len));
#else
  $result = SWIG_FromCharPtrAndSize($1.data, $1.len);
#if defined(SWIGPERL)
  argvi++;
#endif
#endif
}

#if defined(SWIGPYTHON)
%typemap(in) Queue {
  /* Check if is a list */
  queue_init(&$1);
  if (PyList_Check($input)) {
    int size = PyList_Size($input);
    int i = 0;
    for (i = 0; i < size; i++) {
      PyObject *o = PyList_GetItem($input,i);
      int v;
      int e = SWIG_AsVal_int(o, &v);
      if (!SWIG_IsOK(e)) {
        SWIG_exception_fail(SWIG_ArgError(e), "list must contain only integers");
        queue_free(&$1);
        return NULL;
      }
      queue_push(&$1, v);
    }
  } else {
    PyErr_SetString(PyExc_TypeError,"not a list");
    return NULL;
  }
}

%typemap(out) Queue {
  int i;
  PyObject *o = PyList_New($1.count);
  for (i = 0; i < $1.count; i++)
    PyList_SetItem(o, i, SWIG_From_int($1.elements[i]));
  queue_free(&$1);
  $result = o;
}

%define Queue2Array(type, step, con) %{
  int i;
  int cnt = $1.count / step;
  Id *idp = $1.elements;
  PyObject *o = PyList_New(cnt);
  for (i = 0; i < cnt; i++, idp += step)
    {
      Id id = *idp;
#define result resultx
      type result = con;
      $typemap(out, type)
      PyList_SetItem(o, i, $result);
#undef result
    }
  queue_free(&$1);
  $result = o;
%}

%enddef

#endif

#if defined(SWIGPERL)
%typemap(in) Queue {
  AV *av;
  int i, size;
  queue_init(&$1);
  if (!SvROK($input) || SvTYPE(SvRV($input)) != SVt_PVAV)
    SWIG_croak("Argument $argnum is not an array reference.");
  av = (AV*)SvRV($input);
  size = av_len(av);
  for (i = 0; i <= size; i++) {
    SV **sv = av_fetch(av, i, 0);
    int v;
    int e = SWIG_AsVal_int(*sv, &v);
    if (!SWIG_IsOK(e)) {
      SWIG_croak("list must contain only integers");
    }
    queue_push(&$1, v);
  }
}
/* AV *o = newAV();
 * av_push(o, SvREFCNT_inc(SWIG_From_int($1.elements[i])));
 * $result = newRV_noinc((SV*)o); argvi++;
 */
%typemap(out) Queue {
  int i;
  if (argvi + $1.count + 1 >= items) {
    EXTEND(sp, (argvi + $1.count + 1) - items + 1);
  }
  for (i = 0; i < $1.count; i++)
    ST(argvi++) = SvREFCNT_inc(SWIG_From_int($1.elements[i]));
  queue_free(&$1);
  $result = 0;
}
%define Queue2Array(type, step, con) %{
  int i;
  int cnt = $1.count / step;
  Id *idp = $1.elements;
  if (argvi + cnt + 1 >= items) {
    EXTEND(sp, (argvi + cnt + 1) - items + 1);
  }
  for (i = 0; i < cnt; i++, idp += step)
    {
      Id id = *idp;
#define result resultx
      type result = con;
      $typemap(out, type)
      SvREFCNT_inc(ST(argvi - 1));
#undef result
    }
  queue_free(&$1);
  $result = 0;
%}
%enddef

#endif

%typemap(arginit) Queue {
  queue_init(&$1);
}
%typemap(freearg) Queue {
  queue_free(&$1);
}

#if defined(SWIGRUBY)
%typemap(in) Queue {
  int size, i;
  VALUE *o;
  queue_init(&$1);
  size = RARRAY_LEN($input);
  i = 0;
  o = RARRAY_PTR($input);
  for (i = 0; i < size; i++, o++) {
    int v;
    int e = SWIG_AsVal_int(*o, &v);
    if (!SWIG_IsOK(e))
      {
        SWIG_Error(SWIG_RuntimeError, "list must contain only integers");
        SWIG_fail;
      }
    queue_push(&$1, v);
  }
}
%typemap(out) Queue {
  int i;
  VALUE o = rb_ary_new2($1.count);
  for (i = 0; i < $1.count; i++)
    rb_ary_store(o, i, SWIG_From_int($1.elements[i]));
  queue_free(&$1);
  $result = o;
}
%typemap(arginit) Queue {
  queue_init(&$1);
}
%typemap(freearg) Queue {
  queue_free(&$1);
}
%define Queue2Array(type, step, con) %{
  int i;
  int cnt = $1.count / step;
  Id *idp = $1.elements;
  VALUE o = rb_ary_new2(cnt);
  for (i = 0; i < cnt; i++, idp += step)
    {
      Id id = *idp;
#define result resultx
      type result = con;
      $typemap(out, type)
      rb_ary_store(o, i, $result);
#undef result
    }
  queue_free(&$1);
  $result = o;
%}
%enddef
#endif

#if defined(SWIGTCL)
%typemap(in) Queue {
  /* Check if is a list */
  int retval = TCL_OK;
  int size = 0;
  int i = 0;

  if (TCL_OK != (retval = Tcl_ListObjLength(interp, $input, &size))) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("argument is not a list", -1));
    return retval;
  }

  queue_init(&$1);

  for (i = 0; i < size; i++) {
    Tcl_Obj *o = NULL;
    int v;

    if (TCL_OK != (retval = Tcl_ListObjIndex(interp, $input, i, &o))) {
      queue_free(&$1);
      Tcl_SetObjResult(interp, Tcl_NewStringObj("failed to retrieve a list member", -1));
      return retval;
    }

    int e = SWIG_AsVal_int SWIG_TCL_CALL_ARGS_2(o, &v);
    if (!SWIG_IsOK(e)) {
      queue_free(&$1);
      SWIG_exception_fail(SWIG_ArgError(e), "list must contain only integers");
      return TCL_ERROR;
    }

    queue_push(&$1, v);
  }
}

%typemap(out) Queue {
  Tcl_Obj *objvx[$1.count];
  int i;

  for (i = 0; i < $1.count; i++) {
    objvx[i] = SWIG_From_int($1.elements[i]);
  }

  Tcl_SetObjResult(interp, Tcl_NewListObj($1.count, objvx));

  queue_free(&$1);
}

%define Queue2Array(type, step, con) %{
  { /* scope is needed to make the goto of SWIG_exception_fail work */
    int i;
    int cnt = $1.count / step;
    Id *idp = $1.elements;
    Tcl_Obj *objvx[cnt];

    for (i = 0; i < cnt; i++, idp += step) {
      Id id = *idp;
#define result resultx
#define Tcl_SetObjResult(i, x) resultobj = x
      type result = con;
      Tcl_Obj *resultobj;
      $typemap(out, type)
      objvx[i] = resultobj;
#undef Tcl_SetObjResult
#undef result
    }
    queue_free(&$1);
    Tcl_SetObjResult(interp, Tcl_NewListObj(cnt, objvx));
  }
%}

%enddef

#endif


#if defined(SWIGPERL)

/* work around a swig bug */
%{
#undef SWIG_CALLXS
#ifdef PERL_OBJECT
#  define SWIG_CALLXS(_name) TOPMARK=MARK-PL_stack_base;_name(cv,pPerl)
#else
#  ifndef MULTIPLICITY
#    define SWIG_CALLXS(_name) TOPMARK=MARK-PL_stack_base;_name(cv)
#  else
#    define SWIG_CALLXS(_name) TOPMARK=MARK-PL_stack_base;_name(PERL_GET_THX, cv)
#  endif
#endif
%}


%define perliter(class)
  %perlcode {
    sub class##::FETCH {
      my $i = ${##class##::ITERATORS}{$_[0]};
      if ($i) {
        $_[1] == $i->[0] - 1 ? $i->[1] : undef;
      } else {
        $_[0]->__getitem__($_[1]);
      }
    }
    sub class##::FETCHSIZE {
      my $i = ${##class##::ITERATORS}{$_[0]};
      if ($i) {
        ($i->[1] = $_[0]->__next__()) ? ++$i->[0]  : 0;
      } else {
        $_[0]->__len__();
      }
    }
  }
%enddef

%{

#define SWIG_PERL_ITERATOR      0x80

SWIGRUNTIMEINLINE SV *
SWIG_Perl_NewArrayObj(SWIG_MAYBE_PERL_OBJECT void *ptr, swig_type_info *t, int flags) {
  SV *result = sv_newmortal();
  if (ptr && (flags & (SWIG_SHADOW | SWIG_POINTER_OWN))) {
    SV *self;
    SV *obj=newSV(0);
    AV *array=newAV();
    HV *stash;
    sv_setref_pv(obj, (char *) SWIG_Perl_TypeProxyName(t), ptr);
    stash=SvSTASH(SvRV(obj));
    if (flags & SWIG_POINTER_OWN) {
      HV *hv;
      GV *gv=*(GV**)hv_fetch(stash, "OWNER", 5, TRUE);
      if (!isGV(gv))
        gv_init(gv, stash, "OWNER", 5, FALSE);
      hv=GvHVn(gv);
      hv_store_ent(hv, obj, newSViv(1), 0);
    }
    if (flags & SWIG_PERL_ITERATOR) {
      HV *hv;
      GV *gv=*(GV**)hv_fetch(stash, "ITERATORS", 9, TRUE);
      AV *av=newAV();
      if (!isGV(gv))
        gv_init(gv, stash, "ITERATORS", 9, FALSE);
      hv=GvHVn(gv);
      hv_store_ent(hv, obj, newRV_inc((SV *)av), 0);
    }
    sv_magic((SV *)array, (SV *)obj, 'P', Nullch, 0);
    SvREFCNT_dec(obj);
    self=newRV_noinc((SV *)array);
    sv_setsv(result, self);
    SvREFCNT_dec((SV *)self);
    sv_bless(result, stash);
  } else {
    sv_setref_pv(result, (char *) SWIG_Perl_TypeProxyName(t), ptr);
  }
  return result;
}

%}

%typemap(out) Perlarray {
  ST(argvi) = SWIG_Perl_NewArrayObj(SWIG_PERL_OBJECT_CALL SWIG_as_voidptr(result), $1_descriptor, $owner | $shadow); argvi++;
}
%typemap(out) Perliterator {
  ST(argvi) = SWIG_Perl_NewArrayObj(SWIG_PERL_OBJECT_CALL SWIG_as_voidptr(result), $1_descriptor, $owner | $shadow | SWIG_PERL_ITERATOR); argvi++;
}

%typemap(out) Pool_solvable_iterator * = Perlarray;
%typemap(out) Pool_solvable_iterator * solvables_iter = Perliterator;
%typemap(out) Pool_repo_iterator * = Perlarray;
%typemap(out) Pool_repo_iterator * repos_iter = Perliterator;
%typemap(out) Repo_solvable_iterator * = Perlarray;
%typemap(out) Repo_solvable_iterator * solvables_iter = Perliterator;
%typemap(out) Dataiterator * = Perliterator;

#endif


#if defined(SWIGPYTHON)
typedef PyObject *AppObjectPtr;
%typemap(out) AppObjectPtr {
  $result = $1 ? $1 : Py_None;
  Py_INCREF($result);
}
#elif defined(SWIGPERL)
typedef SV *AppObjectPtr;
%typemap(in) AppObjectPtr {
  $1 = SvROK($input) ? SvRV($input) : 0;
}
%typemap(out) AppObjectPtr {
  $result = $1 ? newRV_inc($1) : newSV(0);
  argvi++;
}
#elif defined(SWIGRUBY)
typedef VALUE AppObjectPtr;
%typemap(in) AppObjectPtr {
  $1 = (void *)$input;
}
%typemap(out) AppObjectPtr {
  $result = (VALUE)$1;
}
#elif defined(SWIGTCL)
typedef TclObj *AppObjectPtr;
%typemap(out) AppObjectPtr {
  Tcl_SetObjResult(interp, $1 ? $1 : Tcl_NewObj());
}
#else
#warning AppObjectPtr not defined for this language!
#endif


#ifdef SWIGPYTHON
%include "file.i"
#else
%fragment("SWIG_AsValFilePtr","header") {}
#endif


%fragment("SWIG_AsValSolvFpPtr","header", fragment="SWIG_AsValFilePtr") {

SWIGINTERN int
#ifdef SWIGRUBY
SWIG_AsValSolvFpPtr(VALUE obj, FILE **val) {
#elif defined(SWIGTCL)
SWIG_AsValSolvFpPtr SWIG_TCL_DECL_ARGS_2(void *obj, FILE **val) {
#else
SWIG_AsValSolvFpPtr(void *obj, FILE **val) {
#endif
  static swig_type_info* desc = 0;
  void *vptr = 0;
  int ecode;

  if (!desc) desc = SWIG_TypeQuery("SolvFp *");
  if ((SWIG_ConvertPtr(obj, &vptr, desc, 0)) == SWIG_OK) {
    if (val)
      *val = vptr ? ((SolvFp *)vptr)->fp : 0;
    return SWIG_OK;
  }
#ifdef SWIGPYTHON
  ecode = SWIG_AsValFilePtr(obj, val);
  if (ecode == SWIG_OK)
    return ecode;
#endif
  return SWIG_TypeError;
}

#if defined(SWIGTCL)
#define SWIG_AsValSolvFpPtr(x, y) SWIG_AsValSolvFpPtr SWIG_TCL_CALL_ARGS_2(x, y)
#endif

}


%fragment("SWIG_AsValDepId","header") {

SWIGINTERN int
#ifdef SWIGRUBY
SWIG_AsValDepId(VALUE obj, int *val) {
#elif defined(SWIGTCL)
SWIG_AsValDepId SWIG_TCL_DECL_ARGS_2(void *obj, int *val) {
#else
SWIG_AsValDepId(void *obj, int *val) {
#endif
  static swig_type_info* desc = 0;
  void *vptr = 0;
  int ecode;
  if (!desc) desc = SWIG_TypeQuery("Dep *");
#ifdef SWIGTCL
  ecode = SWIG_AsVal_int SWIG_TCL_CALL_ARGS_2(obj, val);
#else
  ecode = SWIG_AsVal_int(obj, val);
#endif
  if (SWIG_IsOK(ecode))
    return ecode;
  if ((SWIG_ConvertPtr(obj, &vptr, desc, 0)) == SWIG_OK) {
    if (val)
      *val = vptr ? ((Dep *)vptr)->id : 0;
    return SWIG_OK;
  }
  return SWIG_TypeError;
}

#ifdef SWIGTCL
#define SWIG_AsValDepId(x, y) SWIG_AsValDepId SWIG_TCL_CALL_ARGS_2(x, y)
#endif
}

%typemap(out) disown_helper {
#if defined(SWIGRUBY)
  SWIG_ConvertPtr(self, &argp1,SWIGTYPE_p_Pool, SWIG_POINTER_DISOWN |  0 );
#elif defined(SWIGPYTHON)
  SWIG_ConvertPtr(obj0, &argp1,SWIGTYPE_p_Pool, SWIG_POINTER_DISOWN |  0 );
#elif defined(SWIGPERL)
  SWIG_ConvertPtr(ST(0), &argp1,SWIGTYPE_p_Pool, SWIG_POINTER_DISOWN |  0 );
#elif defined(SWIGTCL)
  SWIG_ConvertPtr(objv[1], &argp1, SWIGTYPE_p_Pool, SWIG_POINTER_DISOWN | 0);
#else
#warning disown_helper not implemented for this language, this is likely going to leak memory
#endif

#ifdef SWIGTCL
  Tcl_SetObjResult(interp, SWIG_From_int((int)(0)));
#else
  $result = SWIG_From_int((int)(0));
#endif
}

%include "typemaps.i"

%typemap(in,numinputs=0,noblock=1) XRule **OUTPUT ($*1_ltype temp) {
  $1 = &temp;
}
%typemap(argout,noblock=1) XRule **OUTPUT {
  %append_output(SWIG_NewPointerObj((void*)(*$1), SWIGTYPE_p_XRule, SWIG_POINTER_OWN | %newpointer_flags));
}

%typemaps_asval(%checkcode(POINTER), SWIG_AsValSolvFpPtr, "SWIG_AsValSolvFpPtr", FILE*);
%typemaps_asval(%checkcode(INT32), SWIG_AsValDepId, "SWIG_AsValDepId", DepId);


%{
#include <stdbool.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/utsname.h>
#include <sys/types.h>
#include <unistd.h>

/* argh, swig undefs bool for perl */
#ifndef bool
typedef int bool;
#endif

#include "pool.h"
#include "poolarch.h"
#include "evr.h"
#include "solver.h"
#include "policy.h"
#include "solverdebug.h"
#include "repo_solv.h"
#include "chksum.h"
#include "selection.h"

#include "repo_write.h"
#ifdef ENABLE_RPMDB
#include "repo_rpmdb.h"
#endif
#ifdef ENABLE_PUBKEY
#include "repo_pubkey.h"
#endif
#ifdef ENABLE_DEBIAN
#include "repo_deb.h"
#endif
#ifdef ENABLE_RPMMD
#include "repo_rpmmd.h"
#include "repo_updateinfoxml.h"
#include "repo_deltainfoxml.h"
#include "repo_repomdxml.h"
#endif
#ifdef ENABLE_SUSEREPO
#include "repo_products.h"
#include "repo_susetags.h"
#include "repo_content.h"
#endif
#ifdef ENABLE_MDKREPO
#include "repo_mdk.h"
#endif
#ifdef ENABLE_ARCHREPO
#include "repo_arch.h"
#endif
#ifdef SUSE
#include "repo_autopattern.h"
#endif
#include "solv_xfopen.h"

/* for old ruby versions */
#ifndef RARRAY_PTR
#define RARRAY_PTR(ary) (RARRAY(ary)->ptr)
#endif
#ifndef RARRAY_LEN
#define RARRAY_LEN(ary) (RARRAY(ary)->len)
#endif

#define SOLVER_SOLUTION_ERASE                   -100
#define SOLVER_SOLUTION_REPLACE                 -101
#define SOLVER_SOLUTION_REPLACE_DOWNGRADE       -102
#define SOLVER_SOLUTION_REPLACE_ARCHCHANGE      -103
#define SOLVER_SOLUTION_REPLACE_VENDORCHANGE    -104
#define SOLVER_SOLUTION_REPLACE_NAMECHANGE      -105

typedef void *AppObjectPtr;
typedef Id DepId;

typedef struct {
  Pool *pool;
  Id id;
} Dep;

typedef struct {
  Pool *pool;
  Id id;
} XSolvable;

typedef struct {
  Solver *solv;
  Id id;
} XRule;

typedef struct {
  Repo *repo;
  Id id;
} XRepodata;

typedef struct {
  Pool *pool;
  Id id;
} Pool_solvable_iterator;

typedef struct {
  Pool *pool;
  Id id;
} Pool_repo_iterator;

typedef struct {
  Repo *repo;
  Id id;
} Repo_solvable_iterator;

typedef struct {
  Pool *pool;
  int how;
  Id what;
} Job;

typedef struct {
  Solver *solv;
  Id id;
} Problem;

typedef struct {
  Solver *solv;
  Id problemid;
  Id id;
} Solution;

typedef struct {
  Solver *solv;
  Id problemid;
  Id solutionid;
  Id id;

  Id type;
  Id p;
  Id rp;
} Solutionelement;

typedef struct {
  Solver *solv;
  Id rid;
  Id type;
  Id source;
  Id target;
  Id dep_id;
} Ruleinfo;

typedef struct {
  Solver *solv;
  Id type;
  Id rid;
  Id from_id;
  Id dep_id;
  Id chosen_id;
  Queue choices;
  int level;
} Alternative;

typedef struct {
  Transaction *transaction;
  int mode;
  Id type;
  int count;
  Id fromid;
  Id toid;
} TransactionClass;

typedef struct {
  Pool *pool;
  Queue q;
  int flags;
} Selection;

typedef struct {
  FILE *fp;
} SolvFp;

typedef Dataiterator Datamatch;

typedef int disown_helper;

%}

#ifdef SWIGRUBY
%mixin Dataiterator "Enumerable";
%mixin Pool_solvable_iterator "Enumerable";
%mixin Pool_repo_iterator "Enumerable";
%mixin Repo_solvable_iterator "Enumerable";
#endif

typedef int Id;

%include "knownid.h"

/* from repodata.h */
%constant Id SOLVID_META;
%constant Id SOLVID_POS;

%constant int REL_EQ;
%constant int REL_GT;
%constant int REL_LT;
%constant int REL_ARCH;

typedef struct {
  Pool* const pool;
} Selection;

typedef struct {
  Pool* const pool;
  Id const id;
} Dep;

/* put before pool/repo so we can access the constructor */
%nodefaultdtor Dataiterator;
typedef struct {} Dataiterator;

typedef struct {
  Pool* const pool;
  Id const id;
} XSolvable;

typedef struct {
  Solver* const solv;
  Id const type;
  Id const dep_id;
} Ruleinfo;

typedef struct {
  Solver* const solv;
  Id const id;
} XRule;

typedef struct {
  Repo* const repo;
  Id const id;
} XRepodata;

typedef struct {} Pool_solvable_iterator;
typedef struct {} Pool_repo_iterator;
typedef struct {} Repo_solvable_iterator;

%nodefaultctor Datamatch;
%nodefaultdtor Datamatch;
typedef struct {
  Pool * const pool;
  Repo * const repo;
  Id const solvid;
} Datamatch;

%nodefaultctor Datapos;
typedef struct {
  Repo * const repo;
} Datapos;

typedef struct {
  Pool * const pool;
  int how;
  Id what;
} Job;

%nodefaultctor Pool;
%nodefaultdtor Pool;
typedef struct {
  AppObjectPtr appdata;
} Pool;

%nodefaultctor Repo;
%nodefaultdtor Repo;
typedef struct {
  Pool * const pool;
  const char * const name;
  int priority;
  int subpriority;
  int const nsolvables;
  AppObjectPtr appdata;
} Repo;

%nodefaultctor Solver;
%nodefaultdtor Solver;
typedef struct {
  Pool * const pool;
} Solver;

typedef struct {
} Chksum;

#ifdef ENABLE_PUBKEY
typedef struct {
  Id const htype;
  unsigned int const created;
  unsigned int const expires;
  const char * const keyid;
} Solvsig;
#endif

%rename(xfopen) solvfp_xfopen;
%rename(xfopen_fd) solvfp_xfopen_fd;

%nodefaultctor SolvFp;
typedef struct {
} SolvFp;

%newobject solvfp_xfopen;
%newobject solvfp_xfopen_fd;

SolvFp *solvfp_xfopen(const char *fn, const char *mode = 0);
SolvFp *solvfp_xfopen_fd(const char *fn, int fd, const char *mode = 0);

%{
  SWIGINTERN SolvFp *solvfp_xfopen_fd(const char *fn, int fd, const char *mode) {
    SolvFp *sfp;
    FILE *fp;
    fd = dup(fd);
    fp = fd == -1 ? 0 : solv_xfopen_fd(fn, fd, mode);
    if (!fp)
      return 0;
    sfp = solv_calloc(1, sizeof(SolvFp));
    sfp->fp = fp;
    return sfp;
  }
  SWIGINTERN SolvFp *solvfp_xfopen(const char *fn, const char *mode) {
    SolvFp *sfp;
    FILE *fp;
    fp = solv_xfopen(fn, mode);
    if (!fp)
      return 0;
    sfp = solv_calloc(1, sizeof(SolvFp));
    sfp->fp = fp;
    return sfp;
  }
%}

typedef struct {
  Solver * const solv;
  Id const id;
} Problem;

typedef struct {
  Solver * const solv;
  Id const problemid;
  Id const id;
} Solution;

typedef struct {
  Solver *const solv;
  Id const problemid;
  Id const solutionid;
  Id const id;
  Id const type;
} Solutionelement;

%nodefaultctor Alternative;
typedef struct {
  Solver *const solv;
  Id const type;
  Id const rid;
  Id const from_id;
  Id const dep_id;
  Id const chosen_id;
  int level;
} Alternative;

%nodefaultctor Transaction;
%nodefaultdtor Transaction;
typedef struct {
  Pool * const pool;
} Transaction;

typedef struct {
  Transaction * const transaction;
  Id const type;
  Id const fromid;
  Id const toid;
  int const count;
} TransactionClass;

%extend SolvFp {
  ~SolvFp() {
    if ($self->fp)
      fclose($self->fp);
    free($self);
  }
  int fileno() {
    return $self->fp ? fileno($self->fp) : -1;
  }
  int dup() {
    return $self->fp ? dup(fileno($self->fp)) : -1;
  }
  bool flush() {
    if (!$self->fp)
      return 1;
    return fflush($self->fp) == 0;
  }
  bool close() {
    bool ret;
    if (!$self->fp)
      return 1;
    ret = fclose($self->fp) == 0;
    $self->fp = 0;
    return ret;
  }
}

%extend Job {
  static const Id SOLVER_SOLVABLE = SOLVER_SOLVABLE;
  static const Id SOLVER_SOLVABLE_NAME = SOLVER_SOLVABLE_NAME;
  static const Id SOLVER_SOLVABLE_PROVIDES = SOLVER_SOLVABLE_PROVIDES;
  static const Id SOLVER_SOLVABLE_ONE_OF = SOLVER_SOLVABLE_ONE_OF;
  static const Id SOLVER_SOLVABLE_REPO = SOLVER_SOLVABLE_REPO;
  static const Id SOLVER_SOLVABLE_ALL = SOLVER_SOLVABLE_ALL;
  static const Id SOLVER_SELECTMASK = SOLVER_SELECTMASK;
  static const Id SOLVER_NOOP = SOLVER_NOOP;
  static const Id SOLVER_INSTALL = SOLVER_INSTALL;
  static const Id SOLVER_ERASE = SOLVER_ERASE;
  static const Id SOLVER_UPDATE = SOLVER_UPDATE;
  static const Id SOLVER_WEAKENDEPS = SOLVER_WEAKENDEPS;
  static const Id SOLVER_MULTIVERSION = SOLVER_MULTIVERSION;
  static const Id SOLVER_LOCK = SOLVER_LOCK;
  static const Id SOLVER_DISTUPGRADE = SOLVER_DISTUPGRADE;
  static const Id SOLVER_VERIFY = SOLVER_VERIFY;
  static const Id SOLVER_DROP_ORPHANED = SOLVER_DROP_ORPHANED;
  static const Id SOLVER_USERINSTALLED = SOLVER_USERINSTALLED;
  static const Id SOLVER_JOBMASK = SOLVER_JOBMASK;
  static const Id SOLVER_WEAK = SOLVER_WEAK;
  static const Id SOLVER_ESSENTIAL = SOLVER_ESSENTIAL;
  static const Id SOLVER_CLEANDEPS = SOLVER_CLEANDEPS;
  static const Id SOLVER_FORCEBEST = SOLVER_FORCEBEST;
  static const Id SOLVER_TARGETED = SOLVER_TARGETED;
  static const Id SOLVER_NOTBYUSER = SOLVER_NOTBYUSER;
  static const Id SOLVER_SETEV = SOLVER_SETEV;
  static const Id SOLVER_SETEVR = SOLVER_SETEVR;
  static const Id SOLVER_SETARCH = SOLVER_SETARCH;
  static const Id SOLVER_SETVENDOR = SOLVER_SETVENDOR;
  static const Id SOLVER_SETREPO = SOLVER_SETREPO;
  static const Id SOLVER_SETNAME = SOLVER_SETNAME;
  static const Id SOLVER_NOAUTOSET = SOLVER_NOAUTOSET;
  static const Id SOLVER_SETMASK = SOLVER_SETMASK;

  Job(Pool *pool, int how, Id what) {
    Job *job = solv_calloc(1, sizeof(*job));
    job->pool = pool;
    job->how = how;
    job->what = what;
    return job;
  }

  %typemap(out) Queue solvables Queue2Array(XSolvable *, 1, new_XSolvable(arg1->pool, id));
  %newobject solvables;
  Queue solvables() {
    Queue q;
    queue_init(&q);
    pool_job2solvables($self->pool, &q, $self->how, $self->what);
    return q;
  }
#ifdef SWIGRUBY
  %rename("isemptyupdate?") isemptyupdate;
#endif
  bool isemptyupdate() {
    return pool_isemptyupdatejob($self->pool, $self->how, $self->what);
  }

  bool __eq__(Job *j) {
    return $self->pool == j->pool && $self->how == j->how && $self->what == j->what;
  }
  bool __ne__(Job *j) {
    return !Job___eq__($self, j);
  }
#if defined(SWIGPERL)
  %rename("str") __str__;
#endif
  const char *__str__() {
    return pool_job2str($self->pool, $self->how, $self->what, 0);
  }
  const char *__repr__() {
    const char *str = pool_job2str($self->pool, $self->how, $self->what, ~0);
    return pool_tmpjoin($self->pool, "<Job ", str, ">");
  }
}

%extend Selection {
  static const Id SELECTION_NAME = SELECTION_NAME;
  static const Id SELECTION_PROVIDES = SELECTION_PROVIDES;
  static const Id SELECTION_FILELIST = SELECTION_FILELIST;
  static const Id SELECTION_CANON = SELECTION_CANON;
  static const Id SELECTION_DOTARCH = SELECTION_DOTARCH;
  static const Id SELECTION_REL = SELECTION_REL;
  static const Id SELECTION_INSTALLED_ONLY = SELECTION_INSTALLED_ONLY;
  static const Id SELECTION_GLOB = SELECTION_GLOB;
  static const Id SELECTION_FLAT = SELECTION_FLAT;
  static const Id SELECTION_NOCASE = SELECTION_NOCASE;
  static const Id SELECTION_SOURCE_ONLY = SELECTION_SOURCE_ONLY;
  static const Id SELECTION_WITH_SOURCE = SELECTION_WITH_SOURCE;

  Selection(Pool *pool) {
    Selection *s;
    s = solv_calloc(1, sizeof(*s));
    s->pool = pool;
    return s;
  }

  ~Selection() {
    queue_free(&$self->q);
    solv_free($self);
  }
  int flags() {
    return $self->flags;
  }
#ifdef SWIGRUBY
  %rename("isempty?") isempty;
#endif
  bool isempty() {
    return $self->q.count == 0;
  }
  void filter(Selection *lsel) {
    if ($self->pool != lsel->pool)
      queue_empty(&$self->q);
    else
      selection_filter($self->pool, &$self->q, &lsel->q);
  }
  void add(Selection *lsel) {
    if ($self->pool == lsel->pool)
      {
        selection_add($self->pool, &$self->q, &lsel->q);
        $self->flags |= lsel->flags;
      }
  }
  void add_raw(Id how, Id what) {
    queue_push2(&$self->q, how, what);
  }
  %typemap(out) Queue jobs Queue2Array(Job *, 2, new_Job(arg1->pool, id, idp[1]));
  %newobject jobs;
  Queue jobs(int flags) {
    Queue q;
    int i;
    queue_init_clone(&q, &$self->q);
    for (i = 0; i < q.count; i += 2)
      q.elements[i] |= flags;
    return q;
  }

  %typemap(out) Queue solvables Queue2Array(XSolvable *, 1, new_XSolvable(arg1->pool, id));
  %newobject solvables;
  Queue solvables() {
    Queue q;
    queue_init(&q);
    selection_solvables($self->pool, &$self->q, &q);
    return q;
  }

#if defined(SWIGPERL)
  %rename("str") __str__;
#endif
  const char *__str__() {
    return pool_selection2str($self->pool, &$self->q, 0);
  }
  const char *__repr__() {
    const char *str = pool_selection2str($self->pool, &$self->q, ~0);
    return pool_tmpjoin($self->pool, "<Selection ", str, ">");
  }
}

%extend Chksum {
  Chksum(Id type) {
    return solv_chksum_create(type);
  }
  Chksum(Id type, const char *hex) {
    unsigned char buf[64];
    int l = solv_chksum_len(type);
    if (!l)
      return 0;
    if (solv_hex2bin(&hex, buf, sizeof(buf)) != l || hex[0])
      return 0;
    return solv_chksum_create_from_bin(type, buf);
  }
  ~Chksum() {
    solv_chksum_free($self, 0);
  }
  Id const type;
  %{
  SWIGINTERN Id Chksum_type_get(Chksum *chk) {
    return solv_chksum_get_type(chk);
  }
  %}
  void add(const unsigned char *str, size_t len) {
    solv_chksum_add($self, str, (int)len);
  }
  void add_fp(FILE *fp) {
    char buf[4096];
    int l;
    while ((l = fread(buf, 1, sizeof(buf), fp)) > 0)
      solv_chksum_add($self, buf, l);
    rewind(fp);         /* convenience */
  }
  void add_fd(int fd) {
    char buf[4096];
    int l;
    while ((l = read(fd, buf, sizeof(buf))) > 0)
      solv_chksum_add($self, buf, l);
    lseek(fd, 0, 0);    /* convenience */
  }
  void add_stat(const char *filename) {
    struct stat stb;
    if (stat(filename, &stb))
      memset(&stb, 0, sizeof(stb));
    solv_chksum_add($self, &stb.st_dev, sizeof(stb.st_dev));
    solv_chksum_add($self, &stb.st_ino, sizeof(stb.st_ino));
    solv_chksum_add($self, &stb.st_size, sizeof(stb.st_size));
    solv_chksum_add($self, &stb.st_mtime, sizeof(stb.st_mtime));
  }
  void add_fstat(int fd) {
    struct stat stb;
    if (fstat(fd, &stb))
      memset(&stb, 0, sizeof(stb));
    solv_chksum_add($self, &stb.st_dev, sizeof(stb.st_dev));
    solv_chksum_add($self, &stb.st_ino, sizeof(stb.st_ino));
    solv_chksum_add($self, &stb.st_size, sizeof(stb.st_size));
    solv_chksum_add($self, &stb.st_mtime, sizeof(stb.st_mtime));
  }
  BinaryBlob raw() {
    BinaryBlob bl;
    int l;
    const unsigned char *b;
    b = solv_chksum_get($self, &l);
    bl.data = b;
    bl.len = l;
    return bl;
  }
  %newobject hex;
  char *hex() {
    int l;
    const unsigned char *b;
    char *ret;

    b = solv_chksum_get($self, &l);
    ret = solv_malloc(2 * l + 1);
    solv_bin2hex(b, l, ret);
    return ret;
  }
  const char *typestr() {
    return solv_chksum_type2str(solv_chksum_get_type($self));
  }

  bool __eq__(Chksum *chk) {
    int l;
    const unsigned char *b, *bo;
    if (!chk)
      return 0;
    if (solv_chksum_get_type($self) != solv_chksum_get_type(chk))
      return 0;
    b = solv_chksum_get($self, &l);
    bo = solv_chksum_get(chk, 0);
    return memcmp(b, bo, l) == 0;
  }
  bool __ne__(Chksum *chk) {
    return !Chksum___eq__($self, chk);
  }
#if defined(SWIGRUBY)
  %rename("to_s") __str__;
#endif
#if defined(SWIGPERL)
  %rename("str") __str__;
#endif
  %newobject __str__;
  const char *__str__() {
    const char *str;
    const char *h = 0;
    if (solv_chksum_isfinished($self))
      h = Chksum_hex($self);
    str = solv_dupjoin(solv_chksum_type2str(solv_chksum_get_type($self)), ":", h ? h : "unfinished");
    solv_free((void *)h);
    return str;
  }
  %newobject __repr__;
  const char *__repr__() {
    const char *h = Chksum___str__($self);
    const char *str = solv_dupjoin("<Chksum ", h, ">");
    solv_free((void *)h);
    return str;
  }
}

%extend Pool {
  static const int POOL_FLAG_PROMOTEEPOCH = POOL_FLAG_PROMOTEEPOCH;
  static const int POOL_FLAG_FORBIDSELFCONFLICTS = POOL_FLAG_FORBIDSELFCONFLICTS;
  static const int POOL_FLAG_OBSOLETEUSESPROVIDES = POOL_FLAG_OBSOLETEUSESPROVIDES;
  static const int POOL_FLAG_IMPLICITOBSOLETEUSESPROVIDES = POOL_FLAG_IMPLICITOBSOLETEUSESPROVIDES;
  static const int POOL_FLAG_OBSOLETEUSESCOLORS = POOL_FLAG_OBSOLETEUSESCOLORS;
  static const int POOL_FLAG_IMPLICITOBSOLETEUSESCOLORS = POOL_FLAG_IMPLICITOBSOLETEUSESCOLORS;
  static const int POOL_FLAG_NOINSTALLEDOBSOLETES = POOL_FLAG_NOINSTALLEDOBSOLETES;
  static const int POOL_FLAG_HAVEDISTEPOCH = POOL_FLAG_HAVEDISTEPOCH;
  static const int POOL_FLAG_NOOBSOLETESMULTIVERSION = POOL_FLAG_NOOBSOLETESMULTIVERSION;

  Pool() {
    Pool *pool = pool_create();
    return pool;
  }
  void set_debuglevel(int level) {
    pool_setdebuglevel($self, level);
  }
  int set_flag(int flag, int value) {
    return pool_set_flag($self, flag, value);
  }
  int get_flag(int flag) {
    return pool_get_flag($self, flag);
  }
  void set_rootdir(const char *rootdir) {
    pool_set_rootdir($self, rootdir);
  }
  const char *get_rootdir(int flag) {
    return pool_get_rootdir($self);
  }
#if defined(SWIGPYTHON)
  %{
  SWIGINTERN int loadcallback(Pool *pool, Repodata *data, void *d) {
    XRepodata *xd = new_XRepodata(data->repo, data->repodataid);
    PyObject *args = Py_BuildValue("(O)", SWIG_NewPointerObj(SWIG_as_voidptr(xd), SWIGTYPE_p_XRepodata, SWIG_POINTER_OWN | 0));
    PyObject *result = PyEval_CallObject((PyObject *)d, args);
    int ecode = 0;
    int vresult = 0;
    Py_DECREF(args);
    if (!result)
      return 0; /* exception */
    ecode = SWIG_AsVal_int(result, &vresult);
    Py_DECREF(result);
    return SWIG_IsOK(ecode) ? vresult : 0;
  }
  %}
  void set_loadcallback(PyObject *callable) {
    if ($self->loadcallback == loadcallback) {
      PyObject *obj = $self->loadcallbackdata;
      Py_DECREF(obj);
    }
    if (callable) {
      Py_INCREF(callable);
    }
    pool_setloadcallback($self, callable ? loadcallback : 0, callable);
  }
#elif defined(SWIGPERL)
%{
  SWIGINTERN int loadcallback(Pool *pool, Repodata *data, void *d) {
    int count;
    int ret = 0;
    dSP;
    XRepodata *xd = new_XRepodata(data->repo, data->repodataid);

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(SWIG_NewPointerObj(SWIG_as_voidptr(xd), SWIGTYPE_p_XRepodata, SWIG_OWNER | SWIG_SHADOW));
    PUTBACK;
    count = perl_call_sv((SV *)d, G_EVAL|G_SCALAR);
    SPAGAIN;
    if (count)
      ret = POPi;
    PUTBACK;
    FREETMPS;
    LEAVE;
    return ret;
  }
%}
  void set_loadcallback(SV *callable) {
    if ($self->loadcallback == loadcallback)
      SvREFCNT_dec($self->loadcallbackdata);
    if (callable)
      SvREFCNT_inc(callable);
    pool_setloadcallback($self, callable ? loadcallback : 0, callable);
  }
#elif defined(SWIGRUBY)
%{
  SWIGINTERN int loadcallback(Pool *pool, Repodata *data, void *d) {
    XRepodata *xd = new_XRepodata(data->repo, data->repodataid);
    VALUE callable = (VALUE)d;
    VALUE rd = SWIG_NewPointerObj(SWIG_as_voidptr(xd), SWIGTYPE_p_XRepodata, SWIG_POINTER_OWN | 0);
    VALUE res = rb_funcall(callable, rb_intern("call"), 1, rd);
    return res == Qtrue;
  }
  SWIGINTERN void mark_Pool(void *ptr) {
    Pool *pool = ptr;
    if (pool->loadcallback == loadcallback && pool->loadcallbackdata) {
      VALUE callable = (VALUE)pool->loadcallbackdata;
      rb_gc_mark(callable);
    }
  }
%}
  %typemap(in, numinputs=0) VALUE callable {
    $1 = rb_block_given_p() ? rb_block_proc() : 0;
  }
  void set_loadcallback(VALUE callable) {
    pool_setloadcallback($self, callable ? loadcallback : 0, (void *)callable);
  }
#elif defined(SWIGTCL)
  %{
  typedef struct {
    Tcl_Interp *interp;
    Tcl_Obj *obj;
  } tcl_callback_t;
  SWIGINTERN int loadcallback(Pool *pool, Repodata *data, void *d) {
    tcl_callback_t *callback_var = (tcl_callback_t *)d;
    XRepodata *xd = new_XRepodata(data->repo, data->repodataid);
    Tcl_Obj *objvx[2];
    objvx[0] = callback_var->obj;
    objvx[1] = SWIG_NewPointerObj(SWIG_as_voidptr(xd), SWIGTYPE_p_XRepodata, SWIG_POINTER_OWN | 0); 
    int result = Tcl_EvalObjv(callback_var->interp, sizeof(objvx), objvx, TCL_EVAL_GLOBAL);
    int ecode = 0;
    int vresult = 0;
    Tcl_DecrRefCount(objvx[1]);
    if (result != TCL_OK)
      return 0; /* exception */
    ecode = SWIG_AsVal_int(callback_var->interp, Tcl_GetObjResult(callback_var->interp), &vresult);
    return SWIG_IsOK(ecode) ? vresult : 0;
  }
  %}
  void set_loadcallback(Tcl_Obj *callable, Tcl_Interp *interp) {
    tcl_callback_t *callable_temp;
    if ($self->loadcallback == loadcallback) {
      tcl_callback_t *obj = $self->loadcallbackdata;
      Tcl_DecrRefCount(obj->obj);
      free(obj);
    }
    if (callable) {
      Tcl_IncrRefCount(callable);
      callable_temp = malloc(sizeof(tcl_callback_t));
      callable_temp->interp = interp;
      callable_temp->obj = callable;
    }
    else {
      callable_temp = NULL;
    }
    pool_setloadcallback($self, callable ? loadcallback : 0, callable_temp);
  }
#else
#warning loadcallback not implemented for this language
#endif

#if defined(SWIGTCL)
  ~Pool() {
    Pool_set_loadcallback($self, 0, 0);
    pool_free($self);
  }
  disown_helper free() {
    Pool_set_loadcallback($self, 0, 0);
    pool_free($self);
    return 0;
  }
#else
  ~Pool() {
    Pool_set_loadcallback($self, 0);
    pool_free($self);
  }
  disown_helper free() {
    Pool_set_loadcallback($self, 0);
    pool_free($self);
    return 0;
  }
#endif
  disown_helper disown() {
    return 0;
  }
  Id str2id(const char *str, bool create=1) {
    return pool_str2id($self, str, create);
  }
  %newobject Dep;
  Dep *Dep(const char *str, bool create=1) {
    Id id = pool_str2id($self, str, create);
    return new_Dep($self, id);
  }
  const char *id2str(Id id) {
    return pool_id2str($self, id);
  }
  const char *dep2str(Id id) {
    return pool_dep2str($self, id);
  }
  Id rel2id(Id name, Id evr, int flags, bool create=1) {
    return pool_rel2id($self, name, evr, flags, create);
  }
  Id id2langid(Id id, const char *lang, bool create=1) {
    return pool_id2langid($self, id, lang, create);
  }
  void setarch(const char *arch = 0) {
    struct utsname un;
    if (!arch) {
      if (uname(&un)) {
        perror("uname");
        return;
      }
      arch = un.machine;
    }
    pool_setarch($self, arch);
  }
  Repo *add_repo(const char *name) {
    return repo_create($self, name);
  }
  const char *lookup_str(Id entry, Id keyname) {
    return pool_lookup_str($self, entry, keyname);
  }
  Id lookup_id(Id entry, Id keyname) {
    return pool_lookup_id($self, entry, keyname);
  }
  unsigned long long lookup_num(Id entry, Id keyname, unsigned long long notfound = 0) {
    return pool_lookup_num($self, entry, keyname, notfound);
  }
  bool lookup_void(Id entry, Id keyname) {
    return pool_lookup_void($self, entry, keyname);
  }
  %newobject lookup_checksum;
  Chksum *lookup_checksum(Id entry, Id keyname) {
    Id type = 0;
    const unsigned char *b = pool_lookup_bin_checksum($self, entry, keyname, &type);
    return solv_chksum_create_from_bin(type, b);
  }

  %newobject Dataiterator;
  Dataiterator *Dataiterator(Id key, const char *match = 0, int flags = 0) {
    return new_Dataiterator($self, 0, 0, key, match, flags);
  }
  %newobject Dataiterator_solvid;
  Dataiterator *Dataiterator_solvid(Id p, Id key, const char *match = 0, int flags = 0) {
    return new_Dataiterator($self, 0, p, key, match, flags);
  }
  const char *solvid2str(Id solvid) {
    return pool_solvid2str($self, solvid);
  }
  void addfileprovides() {
    pool_addfileprovides($self);
  }
  Queue addfileprovides_queue() {
    Queue r;
    queue_init(&r);
    pool_addfileprovides_queue($self, &r, 0);
    return r;
  }
  void createwhatprovides() {
    pool_createwhatprovides($self);
  }

  %newobject id2solvable;
  XSolvable *id2solvable(Id id) {
    return new_XSolvable($self, id);
  }
  %newobject solvables;
  Pool_solvable_iterator * const solvables;
  %{
  SWIGINTERN Pool_solvable_iterator * Pool_solvables_get(Pool *pool) {
    return new_Pool_solvable_iterator(pool);
  }
  %}
  %newobject solvables_iter;
  Pool_solvable_iterator * solvables_iter() {
    return new_Pool_solvable_iterator($self);
  }

  Repo *id2repo(Id id) {
    if (id < 1 || id >= $self->nrepos)
      return 0;
    return pool_id2repo($self, id);
  }

  %newobject repos;
  Pool_repo_iterator * const repos;
  %{
  SWIGINTERN Pool_repo_iterator * Pool_repos_get(Pool *pool) {
    return new_Pool_repo_iterator(pool);
  }
  %}
  %newobject repos_iter;
  Pool_repo_iterator * repos_iter() {
    return new_Pool_repo_iterator($self);
  }

  Repo *installed;
  const char * const errstr;
  %{
  SWIGINTERN void Pool_installed_set(Pool *pool, Repo *installed) {
    pool_set_installed(pool, installed);
  }
  Repo *Pool_installed_get(Pool *pool) {
    return pool->installed;
  }
  const char *Pool_errstr_get(Pool *pool) {
    return pool_errstr(pool);
  }
  %}

  Queue matchprovidingids(const char *match, int flags) {
    Pool *pool = $self;
    Queue q;
    Id id;
    queue_init(&q);
    if (!flags) {
      for (id = 1; id < pool->ss.nstrings; id++)
        if (pool->whatprovides[id])
          queue_push(&q, id);
    } else {
      Datamatcher ma;
      if (!datamatcher_init(&ma, match, flags)) {
        for (id = 1; id < pool->ss.nstrings; id++)
          if (pool->whatprovides[id] && datamatcher_match(&ma, pool_id2str(pool, id)))
            queue_push(&q, id);
        datamatcher_free(&ma);
      }
    }
    return q;
  }

  %newobject Job;
  Job *Job(int how, Id what) {
    return new_Job($self, how, what);
  }

  %typemap(out) Queue whatprovides Queue2Array(XSolvable *, 1, new_XSolvable(arg1, id));
  %newobject whatprovides;
  Queue whatprovides(DepId dep) {
    Pool *pool = $self;
    Queue q;
    Id p, pp;
    queue_init(&q);
    FOR_PROVIDES(p, pp, dep)
      queue_push(&q, p);
    return q;
  }

  Id towhatprovides(Queue q) {
    return pool_queuetowhatprovides($self, &q);
  }

  %typemap(out) Queue whatmatchesdep Queue2Array(XSolvable *, 1, new_XSolvable(arg1, id));
  %newobject whatmatchesdep;
  Queue whatmatchesdep(Id keyname, DepId dep, Id marker = -1) {
    Queue q;
    queue_init(&q);
    pool_whatmatchesdep($self, keyname, dep, &q, marker);
    return q;
  }

#ifdef SWIGRUBY
  %rename("isknownarch?") isknownarch;
#endif
  bool isknownarch(DepId id) {
    Pool *pool = $self;
    if (!id || id == ID_EMPTY)
      return 0;
    if (id == ARCH_SRC || id == ARCH_NOSRC || id == ARCH_NOARCH)
      return 1;
    if (pool->id2arch && (id > pool->lastarch || !pool->id2arch[id]))
      return 0;
    return 1;
  }

  %newobject Solver;
  Solver *Solver() {
    return solver_create($self);
  }

  %newobject Selection;
  Selection *Selection() {
    return new_Selection($self);
  }
  %newobject Selection_all;
  Selection *Selection_all(int setflags=0) {
    Selection *sel = new_Selection($self);
    queue_push2(&sel->q, SOLVER_SOLVABLE_ALL | setflags, 0);
    return sel;
  }
  %newobject select;
  Selection *select(const char *name, int flags) {
    Selection *sel = new_Selection($self);
    sel->flags = selection_make($self, &sel->q, name, flags);
    return sel;
  }

  void setpooljobs_helper(Queue jobs) {
    queue_free(&$self->pooljobs);
    queue_init_clone(&$self->pooljobs, &jobs);
  }
  %typemap(out) Queue getpooljobs Queue2Array(Job *, 2, new_Job(arg1, id, idp[1]));
  %newobject getpooljobs;
  Queue getpooljobs() {
    Queue q;
    queue_init_clone(&q, &$self->pooljobs);
    return q;
  }

#if defined(SWIGPYTHON)
  %pythoncode {
    def setpooljobs(self, jobs):
      j = []
      for job in jobs: j += [job.how, job.what]
      self.setpooljobs_helper(j)
  }
#endif
#if defined(SWIGPERL)
  %perlcode {
    sub solv::Solver::setpooljobs {
      my ($self, $jobs) = @_;
      my @j = map {($_->{'how'}, $_->{'what'})} @$jobs;
      return $self->setpooljobs_helper(\@j);
    }
  }
#endif
#if defined(SWIGRUBY)
%init %{
rb_eval_string(
    "class Solv::Pool\n"
    "  def setpooljobs(jobs)\n"
    "    jl = []\n"
    "    jobs.each do |j| ; jl << j.how << j.what ; end\n"
    "    setpooljobs_helper(jl)\n"
    "  end\n"
    "end\n"
  );
%}
#endif
}

%extend Repo {
  static const int REPO_REUSE_REPODATA = REPO_REUSE_REPODATA;
  static const int REPO_NO_INTERNALIZE = REPO_NO_INTERNALIZE;
  static const int REPO_LOCALPOOL = REPO_LOCALPOOL;
  static const int REPO_USE_LOADING = REPO_USE_LOADING;
  static const int REPO_EXTEND_SOLVABLES = REPO_EXTEND_SOLVABLES;
  static const int REPO_USE_ROOTDIR = REPO_USE_ROOTDIR;
  static const int REPO_NO_LOCATION = REPO_NO_LOCATION;
  static const int SOLV_ADD_NO_STUBS = SOLV_ADD_NO_STUBS;       /* repo_solv */
#ifdef ENABLE_SUSEREPO
  static const int SUSETAGS_RECORD_SHARES = SUSETAGS_RECORD_SHARES;     /* repo_susetags */
#endif

  void free(bool reuseids = 0) {
    repo_free($self, reuseids);
  }
  void empty(bool reuseids = 0) {
    repo_empty($self, reuseids);
  }
#ifdef SWIGRUBY
  %rename("isempty?") isempty;
#endif
  bool isempty() {
    return !$self->nsolvables;
  }
  bool add_solv(const char *name, int flags = 0) {
    FILE *fp = fopen(name, "r");
    int r;
    if (!fp)
      return 0;
    r = repo_add_solv($self, fp, flags);
    fclose(fp);
    return r == 0;
  }
  bool add_solv(FILE *fp, int flags = 0) {
    return repo_add_solv($self, fp, flags) == 0;
  }

  %newobject add_solvable;
  XSolvable *add_solvable() {
    Id solvid = repo_add_solvable($self);
    return new_XSolvable($self->pool, solvid);
  }

#ifdef ENABLE_RPMDB
  bool add_rpmdb(int flags = 0) {
    return repo_add_rpmdb($self, 0, flags) == 0;
  }
  bool add_rpmdb_reffp(FILE *reffp, int flags = 0) {
    return repo_add_rpmdb_reffp($self, reffp, flags) == 0;
  }
  %newobject add_rpm;
  XSolvable *add_rpm(const char *name, int flags = 0) {
    return new_XSolvable($self->pool, repo_add_rpm($self, name, flags));
  }
#endif
#ifdef ENABLE_PUBKEY
#ifdef ENABLE_RPMDB
  bool add_rpmdb_pubkeys(int flags = 0) {
    return repo_add_rpmdb_pubkeys($self, flags) == 0;
  }
#endif
  %newobject add_pubkey;
  XSolvable *add_pubkey(const char *keyfile, int flags = 0) {
    return new_XSolvable($self->pool, repo_add_pubkey($self, keyfile, flags));
  }
  bool add_keyring(FILE *fp, int flags = 0) {
    return repo_add_keyring($self, fp, flags);
  }
  bool add_keydir(const char *keydir, const char *suffix, int flags = 0) {
    return repo_add_keydir($self, keydir, suffix, flags);
  }
#endif
#ifdef ENABLE_RPMMD
  bool add_rpmmd(FILE *fp, const char *language, int flags = 0) {
    return repo_add_rpmmd($self, fp, language, flags) == 0;
  }
  bool add_repomdxml(FILE *fp, int flags = 0) {
    return repo_add_repomdxml($self, fp, flags) == 0;
  }
  bool add_updateinfoxml(FILE *fp, int flags = 0) {
    return repo_add_updateinfoxml($self, fp, flags) == 0;
  }
  bool add_deltainfoxml(FILE *fp, int flags = 0) {
    return repo_add_deltainfoxml($self, fp, flags) == 0;
  }
#endif
#ifdef ENABLE_DEBIAN
  bool add_debdb(int flags = 0) {
    return repo_add_debdb($self, flags) == 0;
  }
  bool add_debpackages(FILE *fp, int flags = 0) {
    return repo_add_debpackages($self, fp, flags) == 0;
  }
  %newobject add_deb;
  XSolvable *add_deb(const char *name, int flags = 0) {
    return new_XSolvable($self->pool, repo_add_deb($self, name, flags));
  }
#endif
#ifdef ENABLE_SUSEREPO
  bool add_susetags(FILE *fp, Id defvendor, const char *language, int flags = 0) {
    return repo_add_susetags($self, fp, defvendor, language, flags) == 0;
  }
  bool add_content(FILE *fp, int flags = 0) {
    return repo_add_content($self, fp, flags) == 0;
  }
  bool add_products(const char *proddir, int flags = 0) {
    return repo_add_products($self, proddir, flags) == 0;
  }
#endif
#ifdef ENABLE_MDKREPO
  bool add_mdk(FILE *fp, int flags = 0) {
    return repo_add_mdk($self, fp, flags) == 0;
  }
  bool add_mdk_info(FILE *fp, int flags = 0) {
    return repo_add_mdk_info($self, fp, flags) == 0;
  }
#endif
#ifdef ENABLE_ARCHREPO
  bool add_arch_repo(FILE *fp, int flags = 0) {
    return repo_add_arch_repo($self, fp, flags) == 0;
  }
  bool add_arch_local(const char *dir, int flags = 0) {
    return repo_add_arch_local($self, dir, flags) == 0;
  }
  %newobject add_arch_pkg;
  XSolvable *add_arch_pkg(const char *name, int flags = 0) {
    return new_XSolvable($self->pool, repo_add_arch_pkg($self, name, flags));
  }
#endif
#ifdef SUSE
  bool add_autopattern(int flags = 0) {
    return repo_add_autopattern($self, flags) == 0;
  }
#endif
  void internalize() {
    repo_internalize($self);
  }
  bool write(FILE *fp) {
    return repo_write($self, fp) == 0;
  }
  /* HACK, remove if no longer needed! */
  bool write_first_repodata(FILE *fp) {
    int oldnrepodata = $self->nrepodata;
    int res;
    $self->nrepodata = oldnrepodata > 2 ? 2 : oldnrepodata;
    res = repo_write($self, fp);
    $self->nrepodata = oldnrepodata;
    return res == 0;
  }

  %newobject Dataiterator;
  Dataiterator *Dataiterator(Id key, const char *match = 0, int flags = 0) {
    return new_Dataiterator($self->pool, $self, 0, key, match, flags);
  }
  %newobject Dataiterator_meta;
  Dataiterator *Dataiterator_meta(Id key, const char *match = 0, int flags = 0) {
    return new_Dataiterator($self->pool, $self, SOLVID_META, key, match, flags);
  }

  Id const id;
  %{
  SWIGINTERN Id Repo_id_get(Repo *repo) {
    return repo->repoid;
  }
  %}
  %newobject solvables;
  Repo_solvable_iterator * const solvables;
  %{
  SWIGINTERN Repo_solvable_iterator * Repo_solvables_get(Repo *repo) {
    return new_Repo_solvable_iterator(repo);
  }
  %}
  %newobject meta;
  Datapos * const meta;
  %{
  SWIGINTERN Datapos * Repo_meta_get(Repo *repo) {
    Datapos *pos = solv_calloc(1, sizeof(*pos));
    pos->solvid = SOLVID_META;
    pos->repo = repo;
    return pos;
  }
  %}

  %newobject solvables_iter;
  Repo_solvable_iterator *solvables_iter() {
    return new_Repo_solvable_iterator($self);
  }

  %newobject add_repodata;
  XRepodata *add_repodata(int flags = 0) {
    Repodata *rd = repo_add_repodata($self, flags);
    return new_XRepodata($self, rd->repodataid);
  }

  void create_stubs() {
    Repodata *data;
    if (!$self->nrepodata)
      return;
    data = repo_id2repodata($self, $self->nrepodata - 1);
    if (data->state != REPODATA_STUB)
      (void)repodata_create_stubs(data);
  }
#ifdef SWIGRUBY
  %rename("iscontiguous?") iscontiguous;
#endif
  bool iscontiguous() {
    int i;
    for (i = $self->start; i < $self->end; i++)
      if ($self->pool->solvables[i].repo != $self)
        return 0;
    return 1;
  }
  %newobject first_repodata;
  XRepodata *first_repodata() {
    Repodata *data;
    int i;
    if ($self->nrepodata < 2)
      return 0;
    /* make sure all repodatas but the first are extensions */
    data = repo_id2repodata($self, 1);
    if (data->loadcallback)
       return 0;
    for (i = 2; i < $self->nrepodata; i++)
      {
        data = repo_id2repodata($self, i);
        if (!data->loadcallback)
          return 0;       /* oops, not an extension */
      }
    return new_XRepodata($self, 1);
  }

  %newobject Selection;
  Selection *Selection(int setflags=0) {
    Selection *sel = new_Selection($self->pool);
    setflags |= SOLVER_SETREPO;
    queue_push2(&sel->q, SOLVER_SOLVABLE_REPO | setflags, $self->repoid);
    return sel;
  }

#ifdef ENABLE_PUBKEY
  %newobject find_pubkey;
  XSolvable *find_pubkey(const char *keyid) {
    return new_XSolvable($self->pool, repo_find_pubkey($self, keyid));
  }
#endif

  bool __eq__(Repo *repo) {
    return $self == repo;
  }
  bool __ne__(Repo *repo) {
    return $self != repo;
  }
#if defined(SWIGPERL)
  %rename("str") __str__;
#endif
  %newobject __str__;
  const char *__str__() {
    char buf[20];
    if ($self->name)
      return solv_strdup($self->name);
    sprintf(buf, "Repo#%d", $self->repoid);
    return solv_strdup(buf);
  }
  %newobject __repr__;
  const char *__repr__() {
    char buf[20];
    if ($self->name)
      {
        sprintf(buf, "<Repo #%d ", $self->repoid);
        return solv_dupjoin(buf, $self->name, ">");
      }
    sprintf(buf, "<Repo #%d>", $self->repoid);
    return solv_strdup(buf);
  }
}

%extend Dataiterator {
  static const int SEARCH_STRING = SEARCH_STRING;
  static const int SEARCH_STRINGSTART = SEARCH_STRINGSTART;
  static const int SEARCH_STRINGEND = SEARCH_STRINGEND;
  static const int SEARCH_SUBSTRING = SEARCH_SUBSTRING;
  static const int SEARCH_GLOB = SEARCH_GLOB;
  static const int SEARCH_REGEX = SEARCH_REGEX;
  static const int SEARCH_NOCASE = SEARCH_NOCASE;
  static const int SEARCH_FILES = SEARCH_FILES;
  static const int SEARCH_COMPLETE_FILELIST = SEARCH_COMPLETE_FILELIST;
  static const int SEARCH_CHECKSUMS = SEARCH_CHECKSUMS;

  Dataiterator(Pool *pool, Repo *repo, Id p, Id key, const char *match, int flags) {
    Dataiterator *di = solv_calloc(1, sizeof(*di));
    dataiterator_init(di, pool, repo, p, key, match, flags);
    return di;
  }
  ~Dataiterator() {
    dataiterator_free($self);
    solv_free($self);
  }
#if defined(SWIGPYTHON)
  %pythoncode {
    def __iter__(self): return self
  }
#ifndef PYTHON3
  %rename("next") __next__();
#endif
  %exception __next__ {
    $action
    if (!result) {
      PyErr_SetString(PyExc_StopIteration,"no more matches");
      return NULL;
    }
  }
#endif
#ifdef SWIGPERL
  perliter(solv::Dataiterator)
#endif
  %newobject __next__;
  Datamatch *__next__() {
    Dataiterator *ndi;
    if (!dataiterator_step($self)) {
      return 0;
    }
    ndi = solv_calloc(1, sizeof(*ndi));
    dataiterator_init_clone(ndi, $self);
    dataiterator_strdup(ndi);
    return ndi;
  }
#ifdef SWIGRUBY
  void each() {
    Datamatch *d;
    while ((d = Dataiterator___next__($self)) != 0) {
      rb_yield(SWIG_NewPointerObj(SWIG_as_voidptr(d), SWIGTYPE_p_Datamatch, SWIG_POINTER_OWN | 0));
    }
  }
#endif
  void prepend_keyname(Id key) {
    dataiterator_prepend_keyname($self, key);
  }
  void skip_solvable() {
    dataiterator_skip_solvable($self);
  }
}

%extend Datapos {
  Id lookup_id(Id keyname) {
    Pool *pool = $self->repo->pool;
    Datapos oldpos = pool->pos;
    Id r;
    pool->pos = *$self;
    r = pool_lookup_id(pool, SOLVID_POS, keyname);
    pool->pos = oldpos;
    return r;
  }
  const char *lookup_str(Id keyname) {
    Pool *pool = $self->repo->pool;
    Datapos oldpos = pool->pos;
    const char *r;
    pool->pos = *$self;
    r = pool_lookup_str(pool, SOLVID_POS, keyname);
    pool->pos = oldpos;
    return r;
  }
  unsigned long long lookup_num(Id keyname, unsigned long long notfound = 0) {
    Pool *pool = $self->repo->pool;
    Datapos oldpos = pool->pos;
    unsigned long long r;
    pool->pos = *$self;
    r = pool_lookup_num(pool, SOLVID_POS, keyname, notfound);
    pool->pos = oldpos;
    return r;
  }
  bool lookup_void(Id keyname) {
    Pool *pool = $self->repo->pool;
    Datapos oldpos = pool->pos;
    int r;
    pool->pos = *$self;
    r = pool_lookup_void(pool, SOLVID_POS, keyname);
    pool->pos = oldpos;
    return r;
  }
  %newobject lookup_checksum;
  Chksum *lookup_checksum(Id keyname) {
    Pool *pool = $self->repo->pool;
    Datapos oldpos = pool->pos;
    Id type = 0;
    const unsigned char *b;
    pool->pos = *$self;
    b = pool_lookup_bin_checksum(pool, SOLVID_POS, keyname, &type);
    pool->pos = oldpos;
    return solv_chksum_create_from_bin(type, b);
  }
  const char *lookup_deltaseq() {
    Pool *pool = $self->repo->pool;
    Datapos oldpos = pool->pos;
    const char *seq;
    pool->pos = *$self;
    seq = pool_lookup_str(pool, SOLVID_POS, DELTA_SEQ_NAME);
    if (seq) {
      seq = pool_tmpjoin(pool, seq, "-", pool_lookup_str(pool, SOLVID_POS, DELTA_SEQ_EVR));
      seq = pool_tmpappend(pool, seq, "-", pool_lookup_str(pool, SOLVID_POS, DELTA_SEQ_NUM));
    }
    pool->pos = oldpos;
    return seq;
  }
  const char *lookup_deltalocation(unsigned int *OUTPUT) {
    Pool *pool = $self->repo->pool;
    Datapos oldpos = pool->pos;
    const char *loc;
    pool->pos = *$self;
    loc = pool_lookup_deltalocation(pool, SOLVID_POS, OUTPUT);
    pool->pos = oldpos;
    return loc;
  }
  Queue lookup_idarray(Id keyname) {
    Pool *pool = $self->repo->pool;
    Datapos oldpos = pool->pos;
    Queue r;
    queue_init(&r);
    pool->pos = *$self;
    pool_lookup_idarray(pool, SOLVID_POS, keyname, &r);
    pool->pos = oldpos;
    return r;
  }
  %newobject Dataiterator;
  Dataiterator *Dataiterator(Id key, const char *match = 0, int flags = 0) {
    Pool *pool = $self->repo->pool;
    Datapos oldpos = pool->pos;
    Dataiterator *di;
    pool->pos = *$self;
    di = new_Dataiterator(pool, 0, SOLVID_POS, key, match, flags);
    pool->pos = oldpos;
    return di;
  }
}

%extend Datamatch {
  ~Datamatch() {
    dataiterator_free($self);
    solv_free($self);
  }
  %newobject solvable;
  XSolvable * const solvable;
  Id const key_id;
  const char * const key_idstr;
  Id const type_id;
  const char * const type_idstr;
  Id const id;
  const char * const idstr;
  const char * const str;
  BinaryBlob const binary;
  unsigned long long const num;
  unsigned int const num2;
  %{
  SWIGINTERN XSolvable *Datamatch_solvable_get(Dataiterator *di) {
    return new_XSolvable(di->pool, di->solvid);
  }
  SWIGINTERN Id Datamatch_key_id_get(Dataiterator *di) {
    return di->key->name;
  }
  SWIGINTERN const char *Datamatch_key_idstr_get(Dataiterator *di) {
    return pool_id2str(di->pool, di->key->name);
  }
  SWIGINTERN Id Datamatch_type_id_get(Dataiterator *di) {
    return di->key->type;
  }
  SWIGINTERN const char *Datamatch_type_idstr_get(Dataiterator *di) {
    return pool_id2str(di->pool, di->key->type);
  }
  SWIGINTERN Id Datamatch_id_get(Dataiterator *di) {
    return di->kv.id;
  }
  SWIGINTERN const char *Datamatch_idstr_get(Dataiterator *di) {
   if (di->data && (di->key->type == REPOKEY_TYPE_DIR || di->key->type == REPOKEY_TYPE_DIRSTRARRAY || di->key->type == REPOKEY_TYPE_DIRNUMNUMARRAY))
      return repodata_dir2str(di->data,  di->kv.id, 0);
    if (di->data && di->data->localpool)
      return stringpool_id2str(&di->data->spool, di->kv.id);
    return pool_id2str(di->pool, di->kv.id);
  }
  SWIGINTERN const char * const Datamatch_str_get(Dataiterator *di) {
    return di->kv.str;
  }
  SWIGINTERN BinaryBlob Datamatch_binary_get(Dataiterator *di) {
    BinaryBlob bl;
    bl.data = 0;
    bl.len = 0;
    if (di->key->type == REPOKEY_TYPE_BINARY)
      {
        bl.data = di->kv.str;
        bl.len = di->kv.num;
      }
    else if ((bl.len = solv_chksum_len(di->key->type)) != 0)
      bl.data = di->kv.str;
    return bl;
  }
  SWIGINTERN unsigned long long Datamatch_num_get(Dataiterator *di) {
   if (di->key->type == REPOKEY_TYPE_NUM)
     return SOLV_KV_NUM64(&di->kv);
   return di->kv.num;
  }
  SWIGINTERN unsigned int Datamatch_num2_get(Dataiterator *di) {
    return di->kv.num2;
  }
  %}
  %newobject pos;
  Datapos *pos() {
    Pool *pool = $self->pool;
    Datapos *pos, oldpos = pool->pos;
    dataiterator_setpos($self);
    pos = solv_calloc(1, sizeof(*pos));
    *pos = pool->pos;
    pool->pos = oldpos;
    return pos;
  }
  %newobject parentpos;
  Datapos *parentpos() {
    Pool *pool = $self->pool;
    Datapos *pos, oldpos = pool->pos;
    dataiterator_setpos_parent($self);
    pos = solv_calloc(1, sizeof(*pos));
    *pos = pool->pos;
    pool->pos = oldpos;
    return pos;
  }
#if defined(SWIGPERL)
  /* cannot use str here because swig reports a bogus conflict... */
  %rename("stringify") __str__;
  %perlcode {
    *solv::Datamatch::str = *solvc::Datamatch_stringify;
  }
#endif
  const char *__str__() {
    KeyValue kv = $self->kv;
    const char *str = repodata_stringify($self->pool, $self->data, $self->key, &kv, SEARCH_FILES | SEARCH_CHECKSUMS);
    return str ? str : "";
  }
}

%extend Pool_solvable_iterator {
  Pool_solvable_iterator(Pool *pool) {
    Pool_solvable_iterator *s;
    s = solv_calloc(1, sizeof(*s));
    s->pool = pool;
    return s;
  }
#if defined(SWIGPYTHON)
  %pythoncode {
    def __iter__(self): return self
  }
#ifndef PYTHON3
  %rename("next") __next__();
#endif
  %exception __next__ {
    $action
    if (!result) {
      PyErr_SetString(PyExc_StopIteration,"no more matches");
      return NULL;
    }
  }
#endif
#ifdef SWIGPERL
  perliter(solv::Pool_solvable_iterator)
#endif
  %newobject __next__;
  XSolvable *__next__() {
    Pool *pool = $self->pool;
    if ($self->id >= pool->nsolvables)
      return 0;
    while (++$self->id < pool->nsolvables)
      if (pool->solvables[$self->id].repo)
        return new_XSolvable(pool, $self->id);
    return 0;
  }
#ifdef SWIGRUBY
  void each() {
    XSolvable *n;
    while ((n = Pool_solvable_iterator___next__($self)) != 0) {
      rb_yield(SWIG_NewPointerObj(SWIG_as_voidptr(n), SWIGTYPE_p_XSolvable, SWIG_POINTER_OWN | 0));
    }
  }
#endif
  %newobject __getitem__;
  XSolvable *__getitem__(Id key) {
    Pool *pool = $self->pool;
    if (key > 0 && key < pool->nsolvables && pool->solvables[key].repo)
      return new_XSolvable(pool, key);
    return 0;
  }
  int __len__() {
    return $self->pool->nsolvables;
  }
}

%extend Pool_repo_iterator {
  Pool_repo_iterator(Pool *pool) {
    Pool_repo_iterator *s;
    s = solv_calloc(1, sizeof(*s));
    s->pool = pool;
    return s;
  }
#if defined(SWIGPYTHON)
  %pythoncode {
    def __iter__(self): return self
  }
#ifndef PYTHON3
  %rename("next") __next__();
#endif
  %exception __next__ {
    $action
    if (!result) {
      PyErr_SetString(PyExc_StopIteration,"no more matches");
      return NULL;
    }
  }
#endif
#ifdef SWIGPERL
  perliter(solv::Pool_repo_iterator)
#endif
  %newobject __next__;
  Repo *__next__() {
    Pool *pool = $self->pool;
    if ($self->id >= pool->nrepos)
      return 0;
    while (++$self->id < pool->nrepos) {
      Repo *r = pool_id2repo(pool, $self->id);
      if (r)
        return r;
    }
    return 0;
  }
#ifdef SWIGRUBY
  void each() {
    Repo *n;
    while ((n = Pool_repo_iterator___next__($self)) != 0) {
      rb_yield(SWIG_NewPointerObj(SWIG_as_voidptr(n), SWIGTYPE_p_Repo, SWIG_POINTER_OWN | 0));
    }
  }
#endif
  Repo *__getitem__(Id key) {
    Pool *pool = $self->pool;
    if (key > 0 && key < pool->nrepos)
      return pool_id2repo(pool, key);
    return 0;
  }
  int __len__() {
    return $self->pool->nrepos;
  }
}

%extend Repo_solvable_iterator {
  Repo_solvable_iterator(Repo *repo) {
    Repo_solvable_iterator *s;
    s = solv_calloc(1, sizeof(*s));
    s->repo = repo;
    return s;
  }
#if defined(SWIGPYTHON)
  %pythoncode {
    def __iter__(self): return self
  }
#ifndef PYTHON3
  %rename("next") __next__();
#endif
  %exception __next__ {
    $action
    if (!result) {
      PyErr_SetString(PyExc_StopIteration,"no more matches");
      return NULL;
    }
  }
#endif
#ifdef SWIGPERL
  perliter(solv::Repo_solvable_iterator)
#endif
  %newobject __next__;
  XSolvable *__next__() {
    Repo *repo = $self->repo;
    Pool *pool = repo->pool;
    if (repo->start > 0 && $self->id < repo->start)
      $self->id = repo->start - 1;
    if ($self->id >= repo->end)
      return 0;
    while (++$self->id < repo->end)
      if (pool->solvables[$self->id].repo == repo)
        return new_XSolvable(pool, $self->id);
    return 0;
  }
#ifdef SWIGRUBY
  void each() {
    XSolvable *n;
    while ((n = Repo_solvable_iterator___next__($self)) != 0) {
      rb_yield(SWIG_NewPointerObj(SWIG_as_voidptr(n), SWIGTYPE_p_XSolvable, SWIG_POINTER_OWN | 0));
    }
  }
#endif
  %newobject __getitem__;
  XSolvable *__getitem__(Id key) {
    Repo *repo = $self->repo;
    Pool *pool = repo->pool;
    if (key > 0 && key < pool->nsolvables && pool->solvables[key].repo == repo)
      return new_XSolvable(pool, key);
    return 0;
  }
  int __len__() {
    return $self->repo->pool->nsolvables;
  }
}

%extend Dep {
  Dep(Pool *pool, Id id) {
    Dep *s;
    if (!id)
      return 0;
    s = solv_calloc(1, sizeof(*s));
    s->pool = pool;
    s->id = id;
    return s;
  }
  %newobject Rel;
  Dep *Rel(int flags, DepId evrid, bool create=1) {
    Id id = pool_rel2id($self->pool, $self->id, evrid, flags, create);
    if (!id)
      return 0;
    return new_Dep($self->pool, id);
  }
  %newobject Selection_name;
  Selection *Selection_name(int setflags=0) {
    Selection *sel = new_Selection($self->pool);
    if (ISRELDEP($self->id)) {
      Reldep *rd = GETRELDEP($self->pool, $self->id);
      if (rd->flags == REL_EQ) {
        setflags |= $self->pool->disttype == DISTTYPE_DEB || strchr(pool_id2str($self->pool, rd->evr), '-') != 0 ? SOLVER_SETEVR : SOLVER_SETEV;
        if (ISRELDEP(rd->name))
          rd = GETRELDEP($self->pool, rd->name);
      }
      if (rd->flags == REL_ARCH)
        setflags |= SOLVER_SETARCH;
    }
    queue_push2(&sel->q, SOLVER_SOLVABLE_NAME | setflags, $self->id);
    return sel;
  }
  %newobject Selection_provides;
  Selection *Selection_provides(int setflags=0) {
    Selection *sel = new_Selection($self->pool);
    if (ISRELDEP($self->id)) {
      Reldep *rd = GETRELDEP($self->pool, $self->id);
      if (rd->flags == REL_ARCH)
        setflags |= SOLVER_SETARCH;
    }
    queue_push2(&sel->q, SOLVER_SOLVABLE_PROVIDES | setflags, $self->id);
    return sel;
  }
  const char *str() {
    return pool_dep2str($self->pool, $self->id);
  }
  bool __eq__(Dep *s) {
    return $self->pool == s->pool && $self->id == s->id;
  }
  bool __ne__(Dep *s) {
    return !Dep___eq__($self, s);
  }
#if defined(SWIGPERL)
  %rename("str") __str__;
#endif
  const char *__str__() {
    return pool_dep2str($self->pool, $self->id);
  }
  %newobject __repr__;
  const char *__repr__() {
    char buf[20];
    sprintf(buf, "<Id #%d ", $self->id);
    return solv_dupjoin(buf, pool_dep2str($self->pool, $self->id), ">");
  }
}

%extend XSolvable {
  XSolvable(Pool *pool, Id id) {
    XSolvable *s;
    if (!id || id >= pool->nsolvables)
      return 0;
    s = solv_calloc(1, sizeof(*s));
    s->pool = pool;
    s->id = id;
    return s;
  }
  const char *str() {
    return pool_solvid2str($self->pool, $self->id);
  }
  const char *lookup_str(Id keyname) {
    return pool_lookup_str($self->pool, $self->id, keyname);
  }
  Id lookup_id(Id keyname) {
    return pool_lookup_id($self->pool, $self->id, keyname);
  }
  unsigned long long lookup_num(Id keyname, unsigned long long notfound = 0) {
    return pool_lookup_num($self->pool, $self->id, keyname, notfound);
  }
  bool lookup_void(Id keyname) {
    return pool_lookup_void($self->pool, $self->id, keyname);
  }
  %newobject lookup_checksum;
  Chksum *lookup_checksum(Id keyname) {
    Id type = 0;
    const unsigned char *b = pool_lookup_bin_checksum($self->pool, $self->id, keyname, &type);
    return solv_chksum_create_from_bin(type, b);
  }
  Queue lookup_idarray(Id keyname, Id marker = -1) {
    Solvable *s = $self->pool->solvables + $self->id;
    Queue r;
    queue_init(&r);
    solvable_lookup_deparray(s, keyname, &r, marker);
    return r;
  }
  %typemap(out) Queue lookup_deparray Queue2Array(Dep *, 1, new_Dep(arg1->pool, id));
  %newobject lookup_deparray;
  Queue lookup_deparray(Id keyname, Id marker = -1) {
    Solvable *s = $self->pool->solvables + $self->id;
    Queue r;
    queue_init(&r);
    solvable_lookup_deparray(s, keyname, &r, marker);
    return r;
  }
  const char *lookup_location(unsigned int *OUTPUT) {
    return solvable_lookup_location($self->pool->solvables + $self->id, OUTPUT);
  }
  %newobject Dataiterator;
  Dataiterator *Dataiterator(Id key, const char *match = 0, int flags = 0) {
    return new_Dataiterator($self->pool, 0, $self->id, key, match, flags);
  }
#ifdef SWIGRUBY
  %rename("installable?") installable;
#endif
  bool installable() {
    return pool_installable($self->pool, pool_id2solvable($self->pool, $self->id));
  }
#ifdef SWIGRUBY
  %rename("isinstalled?") isinstalled;
#endif
  bool isinstalled() {
    Pool *pool = $self->pool;
    return pool->installed && pool_id2solvable(pool, $self->id)->repo == pool->installed;
  }

  const char *name;
  %{
    SWIGINTERN void XSolvable_name_set(XSolvable *xs, const char *name) {
      Pool *pool = xs->pool;
      pool->solvables[xs->id].name = pool_str2id(pool, name, 1);
    }
    SWIGINTERN const char *XSolvable_name_get(XSolvable *xs) {
      Pool *pool = xs->pool;
      return pool_id2str(pool, pool->solvables[xs->id].name);
    }
  %}
  Id nameid;
  %{
    SWIGINTERN void XSolvable_nameid_set(XSolvable *xs, Id nameid) {
      xs->pool->solvables[xs->id].name = nameid;
    }
    SWIGINTERN Id XSolvable_nameid_get(XSolvable *xs) {
      return xs->pool->solvables[xs->id].name;
    }
  %}
  const char *evr;
  %{
    SWIGINTERN void XSolvable_evr_set(XSolvable *xs, const char *evr) {
      Pool *pool = xs->pool;
      pool->solvables[xs->id].evr = pool_str2id(pool, evr, 1);
    }
    SWIGINTERN const char *XSolvable_evr_get(XSolvable *xs) {
      Pool *pool = xs->pool;
      return pool_id2str(pool, pool->solvables[xs->id].evr);
    }
  %}
  Id evrid;
  %{
    SWIGINTERN void XSolvable_evrid_set(XSolvable *xs, Id evrid) {
      xs->pool->solvables[xs->id].evr = evrid;
    }
    SWIGINTERN Id XSolvable_evrid_get(XSolvable *xs) {
      return xs->pool->solvables[xs->id].evr;
    }
  %}
  const char *arch;
  %{
    SWIGINTERN void XSolvable_arch_set(XSolvable *xs, const char *arch) {
      Pool *pool = xs->pool;
      pool->solvables[xs->id].arch = pool_str2id(pool, arch, 1);
    }
    SWIGINTERN const char *XSolvable_arch_get(XSolvable *xs) {
      Pool *pool = xs->pool;
      return pool_id2str(pool, pool->solvables[xs->id].arch);
    }
  %}
  Id archid;
  %{
    SWIGINTERN void XSolvable_archid_set(XSolvable *xs, Id archid) {
      xs->pool->solvables[xs->id].arch = archid;
    }
    SWIGINTERN Id XSolvable_archid_get(XSolvable *xs) {
      return xs->pool->solvables[xs->id].arch;
    }
  %}
  const char *vendor;
  %{
    SWIGINTERN void XSolvable_vendor_set(XSolvable *xs, const char *vendor) {
      Pool *pool = xs->pool;
      pool->solvables[xs->id].vendor = pool_str2id(pool, vendor, 1);
    }
    SWIGINTERN const char *XSolvable_vendor_get(XSolvable *xs) {
      Pool *pool = xs->pool;
      return pool_id2str(pool, pool->solvables[xs->id].vendor);
    }
  %}
  Id vendorid;
  %{
    SWIGINTERN void XSolvable_vendorid_set(XSolvable *xs, Id vendorid) {
      xs->pool->solvables[xs->id].vendor = vendorid;
    }
    SWIGINTERN Id XSolvable_vendorid_get(XSolvable *xs) {
      return xs->pool->solvables[xs->id].vendor;
    }
  %}
  Repo * const repo;
  %{
    SWIGINTERN Repo *XSolvable_repo_get(XSolvable *xs) {
      return xs->pool->solvables[xs->id].repo;
    }
  %}

  /* old interface, please use the generic add_deparray instead */
  void add_provides(DepId id, Id marker = -1) {
    Solvable *s = $self->pool->solvables + $self->id;
    marker = solv_depmarker(SOLVABLE_PROVIDES, marker);
    s->provides = repo_addid_dep(s->repo, s->provides, id, marker);
  }
  void add_obsoletes(DepId id) {
    Solvable *s = $self->pool->solvables + $self->id;
    s->obsoletes = repo_addid_dep(s->repo, s->obsoletes, id, 0);
  }
  void add_conflicts(DepId id) {
    Solvable *s = $self->pool->solvables + $self->id;
    s->conflicts = repo_addid_dep(s->repo, s->conflicts, id, 0);
  }
  void add_requires(DepId id, Id marker = -1) {
    Solvable *s = $self->pool->solvables + $self->id;
    marker = solv_depmarker(SOLVABLE_REQUIRES, marker);
    s->requires = repo_addid_dep(s->repo, s->requires, id, marker);
  }
  void add_recommends(DepId id) {
    Solvable *s = $self->pool->solvables + $self->id;
    s->recommends = repo_addid_dep(s->repo, s->recommends, id, 0);
  }
  void add_suggests(DepId id) {
    Solvable *s = $self->pool->solvables + $self->id;
    s->suggests = repo_addid_dep(s->repo, s->suggests, id, 0);
  }
  void add_supplements(DepId id) {
    Solvable *s = $self->pool->solvables + $self->id;
    s->supplements = repo_addid_dep(s->repo, s->supplements, id, 0);
  }
  void add_enhances(DepId id) {
    Solvable *s = $self->pool->solvables + $self->id;
    s->enhances = repo_addid_dep(s->repo, s->enhances, id, 0);
  }

  void unset(Id keyname) {
    Solvable *s = $self->pool->solvables + $self->id;
    repo_unset(s->repo, $self->id, keyname);
  }

  void add_deparray(Id keyname, DepId id, Id marker = -1) {
    Solvable *s = $self->pool->solvables + $self->id;
    solvable_add_deparray(s, keyname, id, marker);
  }

  %newobject Selection;
  Selection *Selection(int setflags=0) {
    Selection *sel = new_Selection($self->pool);
    queue_push2(&sel->q, SOLVER_SOLVABLE | setflags, $self->id);
    return sel;
  }

#ifdef SWIGRUBY
  %rename("identical?") identical;
#endif
  bool identical(XSolvable *s2) {
    return solvable_identical($self->pool->solvables + $self->id, s2->pool->solvables + s2->id);
  }
  int evrcmp(XSolvable *s2) {
    return pool_evrcmp($self->pool, $self->pool->solvables[$self->id].evr, s2->pool->solvables[s2->id].evr, EVRCMP_COMPARE);
  }

  bool __eq__(XSolvable *s) {
    return $self->pool == s->pool && $self->id == s->id;
  }
  bool __ne__(XSolvable *s) {
    return !XSolvable___eq__($self, s);
  }
#if defined(SWIGPERL)
  %rename("str") __str__;
#endif
  const char *__str__() {
    return pool_solvid2str($self->pool, $self->id);
  }
  %newobject __repr__;
  const char *__repr__() {
    char buf[20];
    sprintf(buf, "<Solvable #%d ", $self->id);
    return solv_dupjoin(buf, pool_solvid2str($self->pool, $self->id), ">");
  }
}

%extend Problem {
  Problem(Solver *solv, Id id) {
    Problem *p;
    p = solv_calloc(1, sizeof(*p));
    p->solv = solv;
    p->id = id;
    return p;
  }
  %newobject findproblemrule;
  XRule *findproblemrule() {
    Id r = solver_findproblemrule($self->solv, $self->id);
    return new_XRule($self->solv, r);
  }
  %newobject findallproblemrules;
  %typemap(out) Queue findallproblemrules Queue2Array(XRule *, 1, new_XRule(arg1->solv, id));
  Queue findallproblemrules(int unfiltered=0) {
    Solver *solv = $self->solv;
    Id probr;
    int i, j;
    Queue q;
    queue_init(&q);
    solver_findallproblemrules(solv, $self->id, &q);
    if (!unfiltered)
      {
        for (i = j = 0; i < q.count; i++)
          {
            SolverRuleinfo rclass;
            probr = q.elements[i];
            rclass = solver_ruleclass(solv, probr);
            if (rclass == SOLVER_RULE_UPDATE || rclass == SOLVER_RULE_JOB)
              continue;
            q.elements[j++] = probr;
          }
        if (j)
          queue_truncate(&q, j);
      }
    return q;
  }
  int solution_count() {
    return solver_solution_count($self->solv, $self->id);
  }
  %typemap(out) Queue solutions Queue2Array(Solution *, 1, new_Solution(arg1, id));
  %newobject solutions;
  Queue solutions() {
    Queue q;
    int i, cnt;
    queue_init(&q);
    cnt = solver_solution_count($self->solv, $self->id);
    for (i = 1; i <= cnt; i++)
      queue_push(&q, i);
    return q;
  }
#if defined(SWIGPERL)
  %rename("str") __str__;
#endif
  const char *__str__() {
    return solver_problem2str($self->solv, $self->id);
  }
}

%extend Solution {
  Solution(Problem *p, Id id) {
    Solution *s;
    s = solv_calloc(1, sizeof(*s));
    s->solv = p->solv;
    s->problemid = p->id;
    s->id = id;
    return s;
  }
  int element_count() {
    return solver_solutionelement_count($self->solv, $self->problemid, $self->id);
  }

  %typemap(out) Queue elements Queue2Array(Solutionelement *, 4, new_Solutionelement(arg1->solv, arg1->problemid, arg1->id, id, idp[1], idp[2], idp[3]));
  %newobject elements;
  Queue elements(bool expandreplaces=0) {
    Queue q;
    int i, cnt;
    queue_init(&q);
    cnt = solver_solutionelement_count($self->solv, $self->problemid, $self->id);
    for (i = 1; i <= cnt; i++)
      {
        Id p, rp, type;
        solver_next_solutionelement($self->solv, $self->problemid, $self->id, i - 1, &p, &rp);
        if (p > 0) {
          type = rp ? SOLVER_SOLUTION_REPLACE : SOLVER_SOLUTION_ERASE;
        } else {
          type = p;
          p = rp;
          rp = 0;
        }
        if (type == SOLVER_SOLUTION_REPLACE && expandreplaces) {
          int illegal = policy_is_illegal(self->solv, self->solv->pool->solvables + p, self->solv->pool->solvables + rp, 0);
          if (illegal) {
            if ((illegal & POLICY_ILLEGAL_DOWNGRADE) != 0) {
              queue_push2(&q, i, SOLVER_SOLUTION_REPLACE_DOWNGRADE);
              queue_push2(&q, p, rp);
            }
            if ((illegal & POLICY_ILLEGAL_ARCHCHANGE) != 0) {
              queue_push2(&q, i, SOLVER_SOLUTION_REPLACE_ARCHCHANGE);
              queue_push2(&q, p, rp);
            }
            if ((illegal & POLICY_ILLEGAL_VENDORCHANGE) != 0) {
              queue_push2(&q, i, SOLVER_SOLUTION_REPLACE_VENDORCHANGE);
              queue_push2(&q, p, rp);
            }
            if ((illegal & POLICY_ILLEGAL_NAMECHANGE) != 0) {
              queue_push2(&q, i, SOLVER_SOLUTION_REPLACE_NAMECHANGE);
              queue_push2(&q, p, rp);
            }
            continue;
          }
        }
        queue_push2(&q, i, type);
        queue_push2(&q, p, rp);
      }
    return q;
  }
}

%extend Solutionelement {
  Solutionelement(Solver *solv, Id problemid, Id solutionid, Id id, Id type, Id p, Id rp) {
    Solutionelement *e;
    e = solv_calloc(1, sizeof(*e));
    e->solv = solv;
    e->problemid = problemid;
    e->solutionid = id;
    e->id = id;
    e->type = type;
    e->p = p;
    e->rp = rp;
    return e;
  }
  const char *str() {
    Id p = $self->type;
    Id rp = $self->p;
    int illegal = 0;
    if (p == SOLVER_SOLUTION_ERASE)
      {
        p = rp;
        rp = 0;
      }
    else if (p == SOLVER_SOLUTION_REPLACE)
      {
        p = rp;
        rp = $self->rp;
      }
    else if (p == SOLVER_SOLUTION_REPLACE_DOWNGRADE)
      illegal = POLICY_ILLEGAL_DOWNGRADE;
    else if (p == SOLVER_SOLUTION_REPLACE_ARCHCHANGE)
      illegal = POLICY_ILLEGAL_ARCHCHANGE;
    else if (p == SOLVER_SOLUTION_REPLACE_VENDORCHANGE)
      illegal = POLICY_ILLEGAL_VENDORCHANGE;
    else if (p == SOLVER_SOLUTION_REPLACE_NAMECHANGE)
      illegal = POLICY_ILLEGAL_NAMECHANGE;
    if (illegal)
      return pool_tmpjoin($self->solv->pool, "allow ", policy_illegal2str($self->solv, illegal, $self->solv->pool->solvables + $self->p, $self->solv->pool->solvables + $self->rp), 0);
    return solver_solutionelement2str($self->solv, p, rp);
  }
  %typemap(out) Queue replaceelements Queue2Array(Solutionelement *, 1, new_Solutionelement(arg1->solv, arg1->problemid, arg1->solutionid, arg1->id, id, arg1->p, arg1->rp));
  %newobject replaceelements;
  Queue replaceelements() {
    Queue q;
    int illegal;

    queue_init(&q);
    if ($self->type != SOLVER_SOLUTION_REPLACE || $self->p <= 0 || $self->rp <= 0)
      illegal = 0;
    else
      illegal = policy_is_illegal($self->solv, $self->solv->pool->solvables + $self->p, $self->solv->pool->solvables + $self->rp, 0);
    if ((illegal & POLICY_ILLEGAL_DOWNGRADE) != 0)
      queue_push(&q, SOLVER_SOLUTION_REPLACE_DOWNGRADE);
    if ((illegal & POLICY_ILLEGAL_ARCHCHANGE) != 0)
      queue_push(&q, SOLVER_SOLUTION_REPLACE_ARCHCHANGE);
    if ((illegal & POLICY_ILLEGAL_VENDORCHANGE) != 0)
      queue_push(&q, SOLVER_SOLUTION_REPLACE_VENDORCHANGE);
    if ((illegal & POLICY_ILLEGAL_NAMECHANGE) != 0)
      queue_push(&q, SOLVER_SOLUTION_REPLACE_NAMECHANGE);
    if (!q.count)
      queue_push(&q, $self->type);
    return q;
  }
  int illegalreplace() {
    if ($self->type != SOLVER_SOLUTION_REPLACE || $self->p <= 0 || $self->rp <= 0)
      return 0;
    return policy_is_illegal($self->solv, $self->solv->pool->solvables + $self->p, $self->solv->pool->solvables + $self->rp, 0);
  }
  %newobject solvable;
  XSolvable * const solvable;
  %newobject replacement;
  XSolvable * const replacement;
  int const jobidx;
  %{
    SWIGINTERN XSolvable *Solutionelement_solvable_get(Solutionelement *e) {
      return new_XSolvable(e->solv->pool, e->p);
    }
    SWIGINTERN XSolvable *Solutionelement_replacement_get(Solutionelement *e) {
      return new_XSolvable(e->solv->pool, e->rp);
    }
    SWIGINTERN int Solutionelement_jobidx_get(Solutionelement *e) {
      if (e->type != SOLVER_SOLUTION_JOB && e->type != SOLVER_SOLUTION_POOLJOB)
        return -1;
      return (e->p - 1) / 2;
    }
  %}
  %newobject Job;
  Job *Job() {
    Id extraflags = solver_solutionelement_extrajobflags($self->solv, $self->problemid, $self->solutionid);
    if ($self->type == SOLVER_SOLUTION_JOB || $self->type == SOLVER_SOLUTION_POOLJOB)
      return new_Job($self->solv->pool, SOLVER_NOOP, 0);
    if ($self->type == SOLVER_SOLUTION_INFARCH || $self->type == SOLVER_SOLUTION_DISTUPGRADE || $self->type == SOLVER_SOLUTION_BEST)
      return new_Job($self->solv->pool, SOLVER_INSTALL|SOLVER_SOLVABLE|SOLVER_NOTBYUSER|extraflags, $self->p);
    if ($self->type == SOLVER_SOLUTION_REPLACE || $self->type == SOLVER_SOLUTION_REPLACE_DOWNGRADE || $self->type == SOLVER_SOLUTION_REPLACE_ARCHCHANGE || $self->type == SOLVER_SOLUTION_REPLACE_VENDORCHANGE || $self->type == SOLVER_SOLUTION_REPLACE_NAMECHANGE)
      return new_Job($self->solv->pool, SOLVER_INSTALL|SOLVER_SOLVABLE|SOLVER_NOTBYUSER|extraflags, $self->rp);
    if ($self->type == SOLVER_SOLUTION_ERASE)
      return new_Job($self->solv->pool, SOLVER_ERASE|SOLVER_SOLVABLE|extraflags, $self->p);
    return 0;
  }
}

%extend Solver {
  static const int SOLVER_RULE_UNKNOWN = SOLVER_RULE_UNKNOWN;
  static const int SOLVER_RULE_PKG = SOLVER_RULE_PKG;
  static const int SOLVER_RULE_PKG_NOT_INSTALLABLE = SOLVER_RULE_PKG_NOT_INSTALLABLE;
  static const int SOLVER_RULE_PKG_NOTHING_PROVIDES_DEP = SOLVER_RULE_PKG_NOTHING_PROVIDES_DEP;
  static const int SOLVER_RULE_PKG_REQUIRES = SOLVER_RULE_PKG_REQUIRES;
  static const int SOLVER_RULE_PKG_SELF_CONFLICT = SOLVER_RULE_PKG_SELF_CONFLICT;
  static const int SOLVER_RULE_PKG_CONFLICTS = SOLVER_RULE_PKG_CONFLICTS;
  static const int SOLVER_RULE_PKG_SAME_NAME = SOLVER_RULE_PKG_SAME_NAME;
  static const int SOLVER_RULE_PKG_OBSOLETES = SOLVER_RULE_PKG_OBSOLETES;
  static const int SOLVER_RULE_PKG_IMPLICIT_OBSOLETES = SOLVER_RULE_PKG_IMPLICIT_OBSOLETES;
  static const int SOLVER_RULE_PKG_INSTALLED_OBSOLETES = SOLVER_RULE_PKG_INSTALLED_OBSOLETES;
  static const int SOLVER_RULE_UPDATE = SOLVER_RULE_UPDATE;
  static const int SOLVER_RULE_FEATURE = SOLVER_RULE_FEATURE;
  static const int SOLVER_RULE_JOB = SOLVER_RULE_JOB;
  static const int SOLVER_RULE_JOB_NOTHING_PROVIDES_DEP = SOLVER_RULE_JOB_NOTHING_PROVIDES_DEP;
  static const int SOLVER_RULE_JOB_PROVIDED_BY_SYSTEM = SOLVER_RULE_JOB_PROVIDED_BY_SYSTEM;
  static const int SOLVER_RULE_JOB_UNKNOWN_PACKAGE = SOLVER_RULE_JOB_UNKNOWN_PACKAGE;
  static const int SOLVER_RULE_JOB_UNSUPPORTED = SOLVER_RULE_JOB_UNSUPPORTED;
  static const int SOLVER_RULE_DISTUPGRADE = SOLVER_RULE_DISTUPGRADE;
  static const int SOLVER_RULE_INFARCH = SOLVER_RULE_INFARCH;
  static const int SOLVER_RULE_CHOICE = SOLVER_RULE_CHOICE;
  static const int SOLVER_RULE_LEARNT = SOLVER_RULE_LEARNT;

  static const int SOLVER_SOLUTION_JOB = SOLVER_SOLUTION_JOB;
  static const int SOLVER_SOLUTION_POOLJOB = SOLVER_SOLUTION_POOLJOB;
  static const int SOLVER_SOLUTION_INFARCH = SOLVER_SOLUTION_INFARCH;
  static const int SOLVER_SOLUTION_DISTUPGRADE = SOLVER_SOLUTION_DISTUPGRADE;
  static const int SOLVER_SOLUTION_BEST = SOLVER_SOLUTION_BEST;
  static const int SOLVER_SOLUTION_ERASE = SOLVER_SOLUTION_ERASE;
  static const int SOLVER_SOLUTION_REPLACE = SOLVER_SOLUTION_REPLACE;
  static const int SOLVER_SOLUTION_REPLACE_DOWNGRADE = SOLVER_SOLUTION_REPLACE_DOWNGRADE;
  static const int SOLVER_SOLUTION_REPLACE_ARCHCHANGE = SOLVER_SOLUTION_REPLACE_ARCHCHANGE;
  static const int SOLVER_SOLUTION_REPLACE_VENDORCHANGE = SOLVER_SOLUTION_REPLACE_VENDORCHANGE;
  static const int SOLVER_SOLUTION_REPLACE_NAMECHANGE = SOLVER_SOLUTION_REPLACE_NAMECHANGE;

  static const int POLICY_ILLEGAL_DOWNGRADE = POLICY_ILLEGAL_DOWNGRADE;
  static const int POLICY_ILLEGAL_ARCHCHANGE = POLICY_ILLEGAL_ARCHCHANGE;
  static const int POLICY_ILLEGAL_VENDORCHANGE = POLICY_ILLEGAL_VENDORCHANGE;
  static const int POLICY_ILLEGAL_NAMECHANGE = POLICY_ILLEGAL_NAMECHANGE;

  static const int SOLVER_FLAG_ALLOW_DOWNGRADE = SOLVER_FLAG_ALLOW_DOWNGRADE;
  static const int SOLVER_FLAG_ALLOW_ARCHCHANGE = SOLVER_FLAG_ALLOW_ARCHCHANGE;
  static const int SOLVER_FLAG_ALLOW_VENDORCHANGE = SOLVER_FLAG_ALLOW_VENDORCHANGE;
  static const int SOLVER_FLAG_ALLOW_NAMECHANGE = SOLVER_FLAG_ALLOW_NAMECHANGE;
  static const int SOLVER_FLAG_ALLOW_UNINSTALL = SOLVER_FLAG_ALLOW_UNINSTALL;
  static const int SOLVER_FLAG_NO_UPDATEPROVIDE = SOLVER_FLAG_NO_UPDATEPROVIDE;
  static const int SOLVER_FLAG_SPLITPROVIDES = SOLVER_FLAG_SPLITPROVIDES;
  static const int SOLVER_FLAG_IGNORE_RECOMMENDED = SOLVER_FLAG_IGNORE_RECOMMENDED;
  static const int SOLVER_FLAG_ADD_ALREADY_RECOMMENDED = SOLVER_FLAG_ADD_ALREADY_RECOMMENDED;
  static const int SOLVER_FLAG_NO_INFARCHCHECK = SOLVER_FLAG_NO_INFARCHCHECK;
  static const int SOLVER_FLAG_BEST_OBEY_POLICY = SOLVER_FLAG_BEST_OBEY_POLICY;
  static const int SOLVER_FLAG_NO_AUTOTARGET = SOLVER_FLAG_NO_AUTOTARGET;
  static const int SOLVER_FLAG_DUP_ALLOW_DOWNGRADE = SOLVER_FLAG_DUP_ALLOW_DOWNGRADE;
  static const int SOLVER_FLAG_DUP_ALLOW_ARCHCHANGE = SOLVER_FLAG_DUP_ALLOW_ARCHCHANGE;
  static const int SOLVER_FLAG_DUP_ALLOW_VENDORCHANGE = SOLVER_FLAG_DUP_ALLOW_VENDORCHANGE;
  static const int SOLVER_FLAG_DUP_ALLOW_NAMECHANGE = SOLVER_FLAG_DUP_ALLOW_NAMECHANGE;
  static const int SOLVER_FLAG_KEEP_ORPHANS = SOLVER_FLAG_KEEP_ORPHANS;
  static const int SOLVER_FLAG_BREAK_ORPHANS = SOLVER_FLAG_BREAK_ORPHANS;
  static const int SOLVER_FLAG_FOCUS_INSTALLED = SOLVER_FLAG_FOCUS_INSTALLED;
  static const int SOLVER_FLAG_YUM_OBSOLETES = SOLVER_FLAG_YUM_OBSOLETES;
  static const int SOLVER_FLAG_NEED_UPDATEPROVIDE = SOLVER_FLAG_NEED_UPDATEPROVIDE;

  static const int SOLVER_REASON_UNRELATED = SOLVER_REASON_UNRELATED;
  static const int SOLVER_REASON_UNIT_RULE = SOLVER_REASON_UNIT_RULE;
  static const int SOLVER_REASON_KEEP_INSTALLED = SOLVER_REASON_KEEP_INSTALLED;
  static const int SOLVER_REASON_RESOLVE_JOB = SOLVER_REASON_RESOLVE_JOB;
  static const int SOLVER_REASON_UPDATE_INSTALLED = SOLVER_REASON_UPDATE_INSTALLED;
  static const int SOLVER_REASON_CLEANDEPS_ERASE = SOLVER_REASON_CLEANDEPS_ERASE;
  static const int SOLVER_REASON_RESOLVE = SOLVER_REASON_RESOLVE;
  static const int SOLVER_REASON_WEAKDEP = SOLVER_REASON_WEAKDEP;
  static const int SOLVER_REASON_RESOLVE_ORPHAN = SOLVER_REASON_RESOLVE_ORPHAN;
  static const int SOLVER_REASON_RECOMMENDED = SOLVER_REASON_RECOMMENDED;
  static const int SOLVER_REASON_SUPPLEMENTED = SOLVER_REASON_SUPPLEMENTED;

  /* legacy */
  static const int SOLVER_RULE_RPM = SOLVER_RULE_RPM;

  ~Solver() {
    solver_free($self);
  }

  int set_flag(int flag, int value) {
    return solver_set_flag($self, flag, value);
  }
  int get_flag(int flag) {
    return solver_get_flag($self, flag);
  }
#if defined(SWIGPYTHON)
  %pythoncode {
    def solve(self, jobs):
      j = []
      for job in jobs: j += [job.how, job.what]
      return self.solve_helper(j)
  }
#endif
#if defined(SWIGPERL)
  %perlcode {
    sub solv::Solver::solve {
      my ($self, $jobs) = @_;
      my @j = map {($_->{'how'}, $_->{'what'})} @$jobs;
      return $self->solve_helper(\@j);
    }
  }
#endif
#if defined(SWIGRUBY)
%init %{
rb_eval_string(
    "class Solv::Solver\n"
    "  def solve(jobs)\n"
    "    jl = []\n"
    "    jobs.each do |j| ; jl << j.how << j.what ; end\n"
    "    solve_helper(jl)\n"
    "  end\n"
    "end\n"
  );
%}
#endif
  %typemap(out) Queue solve_helper Queue2Array(Problem *, 1, new_Problem(arg1, id));
  %newobject solve_helper;
  Queue solve_helper(Queue jobs) {
    Queue q;
    int i, cnt;
    queue_init(&q);
    solver_solve($self, &jobs);
    cnt = solver_problem_count($self);
    for (i = 1; i <= cnt; i++)
      queue_push(&q, i);
    return q;
  }
  %newobject transaction;
  Transaction *transaction() {
    return solver_create_transaction($self);
  }

  int describe_decision(XSolvable *s, XRule **OUTPUT) {
    int ruleid;
    int reason = solver_describe_decision($self, s->id, &ruleid);
    *OUTPUT = new_XRule($self, ruleid);
    return reason;
  }

  int alternatives_count() {
    return solver_alternatives_count($self);
  }

  %newobject alternative;
  Alternative *alternative(Id aid) {
    Alternative *a = solv_calloc(1, sizeof(*a));
    a->solv = $self;
    queue_init(&a->choices);
    a->type = solver_get_alternative($self, aid, &a->dep_id, &a->from_id, &a->chosen_id, &a->choices, &a->level);
    if (!a->type) {
      queue_free(&a->choices);
      solv_free(a);
      return 0;
    }
    if (a->type == SOLVER_ALTERNATIVE_TYPE_RULE) {
      a->rid = a->dep_id;
      a->dep_id = 0;
    }
    return a;
  }

  %typemap(out) Queue all_alternatives Queue2Array(Alternative *, 1, Solver_alternative(arg1, id));
  %newobject all_alternatives;
  Queue all_alternatives() {
    Queue q;
    int i, cnt;
    queue_init(&q);
    cnt = solver_alternatives_count($self);
    for (i = 1; i <= cnt; i++)
      queue_push(&q, i);
    return q;
  }
}

%extend Transaction {
  static const int SOLVER_TRANSACTION_IGNORE = SOLVER_TRANSACTION_IGNORE;
  static const int SOLVER_TRANSACTION_ERASE = SOLVER_TRANSACTION_ERASE;
  static const int SOLVER_TRANSACTION_REINSTALLED = SOLVER_TRANSACTION_REINSTALLED;
  static const int SOLVER_TRANSACTION_DOWNGRADED = SOLVER_TRANSACTION_DOWNGRADED;
  static const int SOLVER_TRANSACTION_CHANGED = SOLVER_TRANSACTION_CHANGED;
  static const int SOLVER_TRANSACTION_UPGRADED = SOLVER_TRANSACTION_UPGRADED;
  static const int SOLVER_TRANSACTION_OBSOLETED = SOLVER_TRANSACTION_OBSOLETED;
  static const int SOLVER_TRANSACTION_INSTALL = SOLVER_TRANSACTION_INSTALL;
  static const int SOLVER_TRANSACTION_REINSTALL = SOLVER_TRANSACTION_REINSTALL;
  static const int SOLVER_TRANSACTION_DOWNGRADE = SOLVER_TRANSACTION_DOWNGRADE;
  static const int SOLVER_TRANSACTION_CHANGE = SOLVER_TRANSACTION_CHANGE;
  static const int SOLVER_TRANSACTION_UPGRADE = SOLVER_TRANSACTION_UPGRADE;
  static const int SOLVER_TRANSACTION_OBSOLETES = SOLVER_TRANSACTION_OBSOLETES;
  static const int SOLVER_TRANSACTION_MULTIINSTALL = SOLVER_TRANSACTION_MULTIINSTALL;
  static const int SOLVER_TRANSACTION_MULTIREINSTALL = SOLVER_TRANSACTION_MULTIREINSTALL;
  static const int SOLVER_TRANSACTION_MAXTYPE = SOLVER_TRANSACTION_MAXTYPE;
  static const int SOLVER_TRANSACTION_SHOW_ACTIVE = SOLVER_TRANSACTION_SHOW_ACTIVE;
  static const int SOLVER_TRANSACTION_SHOW_ALL = SOLVER_TRANSACTION_SHOW_ALL;
  static const int SOLVER_TRANSACTION_SHOW_OBSOLETES = SOLVER_TRANSACTION_SHOW_OBSOLETES;
  static const int SOLVER_TRANSACTION_SHOW_MULTIINSTALL = SOLVER_TRANSACTION_SHOW_MULTIINSTALL;
  static const int SOLVER_TRANSACTION_CHANGE_IS_REINSTALL = SOLVER_TRANSACTION_CHANGE_IS_REINSTALL;
  static const int SOLVER_TRANSACTION_OBSOLETE_IS_UPGRADE = SOLVER_TRANSACTION_OBSOLETE_IS_UPGRADE;
  static const int SOLVER_TRANSACTION_MERGE_VENDORCHANGES = SOLVER_TRANSACTION_MERGE_VENDORCHANGES;
  static const int SOLVER_TRANSACTION_MERGE_ARCHCHANGES = SOLVER_TRANSACTION_MERGE_ARCHCHANGES;
  static const int SOLVER_TRANSACTION_RPM_ONLY = SOLVER_TRANSACTION_RPM_ONLY;
  static const int SOLVER_TRANSACTION_ARCHCHANGE = SOLVER_TRANSACTION_ARCHCHANGE;
  static const int SOLVER_TRANSACTION_VENDORCHANGE = SOLVER_TRANSACTION_VENDORCHANGE;
  static const int SOLVER_TRANSACTION_KEEP_ORDERDATA = SOLVER_TRANSACTION_KEEP_ORDERDATA;
  ~Transaction() {
    transaction_free($self);
  }
#ifdef SWIGRUBY
  %rename("isempty?") isempty;
#endif
  bool isempty() {
    return $self->steps.count == 0;
  }

  %newobject othersolvable;
  XSolvable *othersolvable(XSolvable *s) {
    Id op = transaction_obs_pkg($self, s->id);
    return new_XSolvable($self->pool, op);
  }

  %typemap(out) Queue allothersolvables Queue2Array(XSolvable *, 1, new_XSolvable(arg1->pool, id));
  %newobject allothersolvables;
  Queue allothersolvables(XSolvable *s) {
    Queue q;
    queue_init(&q);
    transaction_all_obs_pkgs($self, s->id, &q);
    return q;
  }

  %typemap(out) Queue classify Queue2Array(TransactionClass *, 4, new_TransactionClass(arg1, arg2, id, idp[1], idp[2], idp[3]));
  %newobject classify;
  Queue classify(int mode = 0) {
    Queue q;
    queue_init(&q);
    transaction_classify($self, mode, &q);
    return q;
  }

  /* deprecated, use newsolvables instead */
  %typemap(out) Queue newpackages Queue2Array(XSolvable *, 1, new_XSolvable(arg1->pool, id));
  %newobject newpackages;
  Queue newpackages() {
    Queue q;
    int cut;
    queue_init(&q);
    cut = transaction_installedresult(self, &q);
    queue_truncate(&q, cut);
    return q;
  }

  /* deprecated, use keptsolvables instead */
  %typemap(out) Queue keptpackages Queue2Array(XSolvable *, 1, new_XSolvable(arg1->pool, id));
  %newobject keptpackages;
  Queue keptpackages() {
    Queue q;
    int cut;
    queue_init(&q);
    cut = transaction_installedresult(self, &q);
    if (cut)
      queue_deleten(&q, 0, cut);
    return q;
  }

  %typemap(out) Queue newsolvables Queue2Array(XSolvable *, 1, new_XSolvable(arg1->pool, id));
  %newobject newsolvables;
  Queue newsolvables() {
    Queue q;
    int cut;
    queue_init(&q);
    cut = transaction_installedresult(self, &q);
    queue_truncate(&q, cut);
    return q;
  }

  %typemap(out) Queue keptsolvables Queue2Array(XSolvable *, 1, new_XSolvable(arg1->pool, id));
  %newobject keptsolvables;
  Queue keptsolvables() {
    Queue q;
    int cut;
    queue_init(&q);
    cut = transaction_installedresult(self, &q);
    if (cut)
      queue_deleten(&q, 0, cut);
    return q;
  }

  %typemap(out) Queue steps Queue2Array(XSolvable *, 1, new_XSolvable(arg1->pool, id));
  %newobject steps;
  Queue steps() {
    Queue q;
    queue_init_clone(&q, &$self->steps);
    return q;
  }

  int steptype(XSolvable *s, int mode) {
    return transaction_type($self, s->id, mode);
  }
  int calc_installsizechange() {
    return transaction_calc_installsizechange($self);
  }
  void order(int flags=0) {
    transaction_order($self, flags);
  }
}

%extend TransactionClass {
  TransactionClass(Transaction *trans, int mode, Id type, int count, Id fromid, Id toid) {
    TransactionClass *cl = solv_calloc(1, sizeof(*cl));
    cl->transaction = trans;
    cl->mode = mode;
    cl->type = type;
    cl->count = count;
    cl->fromid = fromid;
    cl->toid = toid;
    return cl;
  }
  %typemap(out) Queue solvables Queue2Array(XSolvable *, 1, new_XSolvable(arg1->transaction->pool, id));
  %newobject solvables;
  Queue solvables() {
    Queue q;
    queue_init(&q);
    transaction_classify_pkgs($self->transaction, $self->mode, $self->type, $self->fromid, $self->toid, &q);
    return q;
  }
  const char * const fromstr;
  const char * const tostr;
  %{
    SWIGINTERN const char *TransactionClass_fromstr_get(TransactionClass *cl) {
      return pool_id2str(cl->transaction->pool, cl->fromid);
    }
    SWIGINTERN const char *TransactionClass_tostr_get(TransactionClass *cl) {
      return pool_id2str(cl->transaction->pool, cl->toid);
    }
  %}
}

%extend XRule {
  XRule(Solver *solv, Id id) {
    if (!id)
      return 0;
    XRule *xr = solv_calloc(1, sizeof(*xr));
    xr->solv = solv;
    xr->id = id;
    return xr;
  }
  int const type;
  %{
    SWIGINTERN int XRule_type_get(XRule *xr) {
      return solver_ruleclass(xr->solv, xr->id);
    }
  %}
  %newobject info;
  Ruleinfo *info() {
    Id type, source, target, dep;
    type = solver_ruleinfo($self->solv, $self->id, &source, &target, &dep);
    return new_Ruleinfo($self, type, source, target, dep);
  }
  %typemap(out) Queue allinfos Queue2Array(Ruleinfo *, 4, new_Ruleinfo(arg1, id, idp[1], idp[2], idp[3]));
  %newobject allinfos;
  Queue allinfos() {
    Queue q;
    queue_init(&q);
    solver_allruleinfos($self->solv, $self->id, &q);
    return q;
  }

  bool __eq__(XRule *xr) {
    return $self->solv == xr->solv && $self->id == xr->id;
  }
  bool __ne__(XRule *xr) {
    return !XRule___eq__($self, xr);
  }
  %newobject __repr__;
  const char *__repr__() {
    char buf[20];
    sprintf(buf, "<Rule #%d>", $self->id);
    return solv_strdup(buf);
  }
}

%extend Ruleinfo {
  Ruleinfo(XRule *r, Id type, Id source, Id target, Id dep_id) {
    Ruleinfo *ri = solv_calloc(1, sizeof(*ri));
    ri->solv = r->solv;
    ri->rid = r->id;
    ri->type = type;
    ri->source = source;
    ri->target = target;
    ri->dep_id = dep_id;
    return ri;
  }
  %newobject solvable;
  XSolvable * const solvable;
  %newobject othersolvable;
  XSolvable * const othersolvable;
  %newobject dep;
  Dep * const dep;
  %{
    SWIGINTERN XSolvable *Ruleinfo_solvable_get(Ruleinfo *ri) {
      return new_XSolvable(ri->solv->pool, ri->source);
    }
    SWIGINTERN XSolvable *Ruleinfo_othersolvable_get(Ruleinfo *ri) {
      return new_XSolvable(ri->solv->pool, ri->target);
    }
    SWIGINTERN Dep *Ruleinfo_dep_get(Ruleinfo *ri) {
      return new_Dep(ri->solv->pool, ri->dep_id);
    }
  %}
  const char *problemstr() {
    return solver_problemruleinfo2str($self->solv, $self->type, $self->source, $self->target, $self->dep_id);
  }
}

%extend XRepodata {
  XRepodata(Repo *repo, Id id) {
    XRepodata *xr = solv_calloc(1, sizeof(*xr));
    xr->repo = repo;
    xr->id = id;
    return xr;
  }
  Id new_handle() {
    return repodata_new_handle(repo_id2repodata($self->repo, $self->id));
  }
  void set_id(Id solvid, Id keyname, DepId id) {
    repodata_set_id(repo_id2repodata($self->repo, $self->id), solvid, keyname, id);
  }
  void set_str(Id solvid, Id keyname, const char *str) {
    repodata_set_str(repo_id2repodata($self->repo, $self->id), solvid, keyname, str);
  }
  void set_poolstr(Id solvid, Id keyname, const char *str) {
    repodata_set_poolstr(repo_id2repodata($self->repo, $self->id), solvid, keyname, str);
  }
  void add_idarray(Id solvid, Id keyname, DepId id) {
    repodata_add_idarray(repo_id2repodata($self->repo, $self->id), solvid, keyname, id);
  }
  void add_flexarray(Id solvid, Id keyname, Id handle) {
    repodata_add_flexarray(repo_id2repodata($self->repo, $self->id), solvid, keyname, handle);
  }
  void set_checksum(Id solvid, Id keyname, Chksum *chksum) {
    const unsigned char *buf = solv_chksum_get(chksum, 0);
    if (buf)
      repodata_set_bin_checksum(repo_id2repodata($self->repo, $self->id), solvid, keyname, solv_chksum_get_type(chksum), buf);
  }
  const char *lookup_str(Id solvid, Id keyname) {
    return repodata_lookup_str(repo_id2repodata($self->repo, $self->id), solvid, keyname);
  }
  Queue lookup_idarray(Id solvid, Id keyname) {
    Queue r;
    queue_init(&r);
    repodata_lookup_idarray(repo_id2repodata($self->repo, $self->id), solvid, keyname, &r);
    return r;
  }
  %newobject lookup_checksum;
  Chksum *lookup_checksum(Id solvid, Id keyname) {
    Id type = 0;
    const unsigned char *b = repodata_lookup_bin_checksum(repo_id2repodata($self->repo, $self->id), solvid, keyname, &type);
    return solv_chksum_create_from_bin(type, b);
  }
  void internalize() {
    repodata_internalize(repo_id2repodata($self->repo, $self->id));
  }
  void create_stubs() {
    Repodata *data = repo_id2repodata($self->repo, $self->id);
    data = repodata_create_stubs(data);
    $self->id = data->repodataid;
  }
  bool write(FILE *fp) {
    return repodata_write(repo_id2repodata($self->repo, $self->id), fp) == 0;
  }
  bool add_solv(FILE *fp, int flags = 0) {
    Repodata *data = repo_id2repodata($self->repo, $self->id);
    int r, oldstate = data->state;
    data->state = REPODATA_LOADING;
    r = repo_add_solv(data->repo, fp, flags | REPO_USE_LOADING);
    if (r || data->state == REPODATA_LOADING)
      data->state = oldstate;
    return r;
  }
  void extend_to_repo() {
    Repodata *data = repo_id2repodata($self->repo, $self->id);
    repodata_extend_block(data, data->repo->start, data->repo->end - data->repo->start);
  }
  bool __eq__(XRepodata *xr) {
    return $self->repo == xr->repo && $self->id == xr->id;
  }
  bool __ne__(XRepodata *xr) {
    return !XRepodata___eq__($self, xr);
  }
  %newobject __repr__;
  const char *__repr__() {
    char buf[20];
    sprintf(buf, "<Repodata #%d>", $self->id);
    return solv_strdup(buf);
  }
}

#ifdef ENABLE_PUBKEY
%extend Solvsig {
  Solvsig(FILE *fp) {
    return solvsig_create(fp);
  }
  ~Solvsig() {
    solvsig_free($self);
  }
  %newobject Chksum;
  Chksum *Chksum() {
    return $self->htype ? (Chksum *)solv_chksum_create($self->htype) : 0;
  }
#ifdef ENABLE_PGPVRFY
  %newobject verify;
  XSolvable *verify(Repo *repo, Chksum *chksum) {
    Id p = solvsig_verify($self, repo, chksum);
    return new_XSolvable(repo->pool, p);
  }
#endif
}
#endif

%extend Alternative {
  static const int SOLVER_ALTERNATIVE_TYPE_RULE = SOLVER_ALTERNATIVE_TYPE_RULE;
  static const int SOLVER_ALTERNATIVE_TYPE_RECOMMENDS = SOLVER_ALTERNATIVE_TYPE_RECOMMENDS;
  static const int SOLVER_ALTERNATIVE_TYPE_SUGGESTS = SOLVER_ALTERNATIVE_TYPE_SUGGESTS;

  ~Alternative() {
    queue_free(&$self->choices);
    solv_free($self);
  }
  %newobject chosen;
  XSolvable * const chosen;
  %newobject rule;
  XRule * const rule;
  %newobject depsolvable;
  XSolvable * const depsolvable;
  %newobject dep;
  Dep * const dep;
  %{
    SWIGINTERN XSolvable *Alternative_chosen_get(Alternative *a) {
      return new_XSolvable(a->solv->pool, a->chosen_id);
    }
    SWIGINTERN XRule *Alternative_rule_get(Alternative *a) {
      return new_XRule(a->solv, a->rid);
    }
    SWIGINTERN XSolvable *Alternative_depsolvable_get(Alternative *a) {
      return new_XSolvable(a->solv->pool, a->from_id);
    }
    SWIGINTERN Dep *Alternative_dep_get(Alternative *a) {
      return new_Dep(a->solv->pool, a->dep_id);
    }
  %}

  Queue choices_raw() {
    Queue r;
    queue_init_clone(&r, &$self->choices);
    return r;
  }

  %typemap(out) Queue choices Queue2Array(XSolvable *, 1, new_XSolvable(arg1->solv->pool, id));
  Queue choices() {
    int i;
    Queue r;
    queue_init_clone(&r, &$self->choices);
    for (i = 0; i < r.count; i++)
      if (r.elements[i] < 0)
        r.elements[i] = -r.elements[i];
    return r;
  }

#if defined(SWIGPERL)
  %rename("str") __str__;
#endif
  const char *__str__() {
    return solver_alternative2str($self->solv, $self->type, $self->type == SOLVER_ALTERNATIVE_TYPE_RULE ? $self->rid : $self->dep_id, $self->from_id);
  }
}
