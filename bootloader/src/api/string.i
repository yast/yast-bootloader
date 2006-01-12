/*
 * file:	stl/string.i
 * author:	Martin Lazar <mlazar@suse.cz>
 *
 * std::string helpers and typemas
 *
 * $Id$
 */

%include <std_string.i>
%include <typemaps.i>

%{
#include <string>

/* convert any to SV */
bool FROM_STD_STRING(SV *&sv, const std::string *x, int size, const swig_type_info *t) {
    sv_setpv(sv,x->c_str());
    return true;
}

/* convert SV to any */
bool TO_STD_STRING(SV* sv, std::string *x, int size, const swig_type_info *t) { 
    *x = std::string(SvPV_nolen(sv));
    return true;
}

%}

%typemap(in) std::string* (std::string temp), std::string& (std::string temp),
    const std::string* (std::string temp), const std::string& (std::string temp)
{
    SV *sv;
    if (!SvROK($input) || !(sv = (SV*)SvRV($input)) || !SvPOK(sv) )
	SWIG_croak("Type error in argument $argnum of $symname. Expected a REFERENCE to STRING.\n");

    STRLEN len;
    const char *ptr = SvPV(sv, len);
    if (!ptr)
        SWIG_croak("Undefined variable in argument $argnum of $symname.");
    temp.assign(ptr, len);
    $1 = &temp;
}

%typemap(argout) std::string*, std::string&
{
    SV *sv = (SV *)SvRV($input);
    sv_setpv(sv, $1->c_str());
}

%typemap(argout) const std::string*, const std::string&;


%typemap(out) std::string {
    if (argvi >= items) EXTEND(sp, 1);	// bump stack ptr, if needed
    char *data = const_cast<char*>($1.data());
    sv_setpvn($result = sv_newmortal(), data, $1.size());
    ++argvi;
}

%typemap(out) std::string*, std::string&, const std::string*, const std::string& {
    if (argvi >= items) EXTEND(sp, 1);	// bump stack ptr, if needed
    char *data = const_cast<char*>($1->data());
    sv_setpvn($result = sv_newmortal(), data, $1->size());
    ++argvi;
}
