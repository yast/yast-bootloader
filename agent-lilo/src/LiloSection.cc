/**
 * File:
 *   LiloSection.cc
 *
 * Module:
 *   lilo.conf agent
 *
 * Summary:
 *   lilo file internal representation
 *
 * Authors:
 *   dan.meszaros <dmeszar@suse.cz>
 *
 * $Id$
 *
 * lilo.conf file memory representation base class
 *
 */

#include <vector>
#include <string>
#include <stdio.h>

#include "LiloSection.h"
#include "OptTypes.h"
#include <ycp/y2log.h>
#include <ctype.h>

#define WHITESPACE       " \t\n"

//string commentBuffer;
//string type;

string strip(string str)
{
    str=str.erase(0, str.find_first_not_of(WHITESPACE));
    str=str.substr(0, str.find_last_not_of(WHITESPACE)+1);
    return str;
}

string indentString(string str, string indent)
{
    string output;
    for(uint i=0; i<str.length(); i++)
    {
        if(str[i]!='\n')
        {
            output.append(1, str[i]);
        }
        else
        {
	    output.append(1, '\n');
            output.append(indent);
        }
    }
    return output;
}


/*=========================================================
 * inputLine
 *
 *
 */

inputLine::inputLine(const string& line, const string& init_type)
{
    src = line;
    type = init_type;

    // initial state for parser
    int state = 1;

    char* s = strdup (line.c_str ());
    char* orig = s;

    // parser

    while(*s)
    {
	switch(state)
	{
	    case 1:  // skip leading blanks
		if(*s=='#')
		{
		    state=9;
		    continue;
		} else
		if(!isspace(*s))
		{
		    state=2;
		    continue;
		}
		break;

	    case 2:  // read option name
		if(*s=='#')
		{
		    state=9;
		    continue;
		}
		else if(*s=='=')
		{
		    state=4;
		    break;
		}
		else if(!isspace(*s))
		{
		    option+=*s;
		}
		else
		{
		    if (type == "grub")
			state = 4;
		    else
			state=3;
		}
		break;

	    case 3:  // search for '='
		if(*s=='#')
		{
		    state=9;
		    continue;
		}
		else if(*s=='=')
		{
		    state=4;
		}
		break;

	    case 4:  // skip blanks
		if(*s=='#')
		{
		    state=9;
		    continue;
		}
		if(!isspace(*s))
		{
		    state=5;
		    continue;
		}
		break;

	    case 5: // fetch value
		if(*s=='#')
		{
		    state=9;
		    continue;
		}
		if(*s=='\\')
		{
		    state=8;
		}
		if(*s=='\"')
		{
		    state=6;
		}
		value+=*s;
		break;

	    case 6: // fetch quoted value
		if(*s=='\\')
		{
		    state=7;
		    value+=*s;
		    break;
		}
		if(*s=='\"')
		{
		    state=5;
		    value+=*s;
		    break;
		}
		value+=*s;
		break;

	    case 7:  // escaped char for state 6
		value+=*s;
		state=6;
		break;

	    case 8: // escaped char for state 5
		value+=*s;
		state=5;
		break;

	    case 9: // fetch comment
		comment+=*s;
		break;

	}

	s++;
    }

/*    if (type == "grub")
    {
	y2error ("Option: %s, Value: %s", option.c_str(), value.c_str());
    }
*/
    free (orig);
}

void inputLine::dump()
{
//    string val=option+"\t = "+value;
//    y2error("dump: %s\n", val.c_str());//option.c_str(), value.c_str(), comment.c_str());
}

//=========================================================
//
//
//
//

liloOption::liloOption(string optn, string val, string com)
{
    value=val;
    optname=optn;
    comment=com;
}

void liloOption::dump()
{
    y2debug("optname '%s' value '%s' comment '%s'", optname.c_str(), value.c_str(), comment.c_str());
}

//=========================================================
//
//
//
//


liloOrderedOptions::liloOrderedOptions(const string& init_type)
{
    type = init_type;
    o = OptTypes(type);
}

int getPos(vector<liloOption*>* vect, const string& opt)
{
    for(uint i=0; i<vect->size(); i++)
    {
	if((*vect)[i]->optname==opt)
	{
	    return (int)i;
	}
    }
    return -1;
}

bool liloOrderedOptions::processLine(inputLine* li)
{
    string optname;
    string value;
    string norm_value = li->value;

    bool spec=false;
    if(li->option=="") return false;

    if(o.getOptType(li->option)>=T_SPEC)
    {
	optname=o.getSpecGroup(li->option);
	value=li->option;
	if(li->value!="")
	{
	    value=li->option+ (type == "grub" ? " " : "=") +li->value;
	}
	spec=true;
    }
    else
    {
	optname=li->option;
    }

    if (type == "zipl" && optname[0] == '[')
    {
	norm_value = optname;
	norm_value.erase (0,1);
	int strsize = norm_value.size ();
	norm_value.erase (strsize - 1, 1);
        optname = "label";
    }
    if (optname == "label")
	norm_value = replaceBlanks (norm_value, '_');

    int cpos=getPos(&order, optname);

    if(cpos<0)
    {
	if(!spec)
	{
				// was li->option
	    order.push_back(new liloOption(optname, norm_value, li->comment));
	}
	else
	{
	    order.push_back(new liloOption(optname, value, li->comment));
	}
    }
    else
    {
	if(spec)
	{
	    order[cpos]->value=order[cpos]->value+"\n"+value;
	}
	else
	{
	    y2debug("lilo.conf waring: overriding option %s", li->option.c_str());
	    order[cpos]->value=norm_value;
	    order[cpos]->comment=li->comment;
	}
    }
    return true;
}


YCPValue liloOrderedOptions::Read(const YCPPath& path)
{
    if(path->length()==0)
    {
	YCPList l;
	for(uint i=0; i<order.size(); i++)
	{
	    YCPMap m;
	    m->add (YCPString ("key"), YCPString (order[i]->optname));
	    m->add (YCPString ("comment"), YCPString (order[i]->comment));
	    switch(o.getOptType(order[i]->optname))
	    {
		case T_INT:
		{
		    m->add (YCPString ("value"),
			YCPInteger (order[i]->value.c_str()));
		    break;
		}
		case T_BOOL:
		{
		    m->add (YCPString ("value"),
			(order[i]->value=="true" || order[i]->value=="")
			    ? YCPBoolean(true)
			    : YCPBoolean(false));
		    break;
		}
		default: // special options, string and unknown
		{        // special options logic moved to front-end
		    m->add (YCPString ("value"), YCPString (order[i]->value));
		}
	    }
	    l->add (m);
	}
	return l;
    }
    int cpos=getPos(&order, path->component_str(0));

    if(cpos<0)
    {
	string error = string("Warning: reading unknown option ")
			+ path->component_str(0);
	return YCPError(error);
    }
    liloOption* opt=order[cpos];

    if(path->length()==2 && path->component_str(1)=="comment")
    {
	return YCPString(opt->comment);
    }


    switch(o.getOptType(opt->optname))
    {
	case T_STR:
	case T_UNKNOWN:
	    return YCPString(opt->value);
	case T_INT:
	    return YCPInteger(opt->value.c_str());
	case T_BOOL:
	    return (opt->value=="true" || opt->value=="")?YCPBoolean(true):YCPBoolean(false);
	default:
	    // special options
	    {
		YCPList list;
		if(opt->value=="")
		{
		    return list;
		}
		int cursor=0;
		int nl=opt->value.find('\n');
		while(nl!=-1)
		{
		    list->add(YCPString(opt->value.substr(cursor, nl-cursor)));
		    cursor=nl+1;
		    nl=opt->value.find('\n', nl+1);
		}
		list->add(YCPString(opt->value.substr(cursor)));
		return list;
	    }
    }
    return YCPVoid();
}

// replace non-printable chars and space by r
// short to 15 characters
string replaceBlanks (const string &s, char r)
{
    // the STL manual says that assigning to a string character
    // invalidates iterators, so let's use a C string
    char *result = strdup (s.c_str());

    for (char *p = result; *p; ++p)
    {
	*p = (((unsigned char)*p) > 32)? *p : r;
    }

    string s_result = result;
    free (result);
    if (s_result.size() > 15)
	s_result = s_result.substr (0, 15);
    return s_result;
}

YCPValue liloOrderedOptions::Write(const YCPPath& path, const YCPValue& value, const YCPValue& _pos)
{

    if(path->length()==0)
    {
	y2debug ("Writing section");
	order.clear();
	bool ret = true;
	if (value.isNull () || ! value->isList ())
	    return YCPError ("Wrong arguments passed to section write");
        YCPList l = value->asList ();
	for (int index = 0; index < l->size (); index ++)
        {
	y2debug ("Writing option %d", index);
	    if (l->value(index).isNull () || ! l->value(index)->isMap ())
	    {
		y2error ("Wrong arguments passed to section write");
		ret = false;
	    }
            YCPMap m = l->value(index)->asMap ();
	    string comment = "";
	    string value = "";
	    string key = "";
	    if (m->haskey (YCPString ("key")))
	    {
		key = m->value (YCPString ("key"))
		    ->asString()->value_cstr();
	    }
	    if (m->haskey (YCPString ("comment")))
	    {
		comment = m->value (YCPString ("comment"))
		    ->asString()->value_cstr();
	    }
	    if (m->haskey (YCPString ("value")))
	    {
		if(m->value(YCPString ("value"))->isInteger()
		    || m->value(YCPString ("value"))->isBoolean())
		{
		    value = m->value(YCPString ("value"))
			->toString().c_str();
		}
		else
		{
		    value = m->value (YCPString ("value"))
			->asString()->value_cstr();
		}
	    }
// TODO: copy type checking here
// TODO: check correct label when configuring lilo
	    liloOption *op  = new liloOption (key, value, comment);
	    y2debug ("Option %d created", (int) op);
	    order.push_back (op);
        }
	y2debug ("Returning %d", (int)ret);
        return YCPBoolean (ret);
    }

    int newpos = -1;
    if ((! _pos.isNull ()) && _pos->isInteger())
        newpos = _pos->asInteger()->value();
    int cpos=getPos(&order, path->component_str(0));
    if(cpos<0)
    {
	liloOption* oop=new liloOption(path->component_str(0), "", "");
	if (newpos == -1)
	{
	    order.push_back (oop);
	}
	else
	{
	    vector<liloOption*>::iterator it=order.begin();
	    it+=newpos;
	    order.insert(it, oop);
	}
	cpos=getPos(&order, path->component_str(0));
    }
    else if (newpos >= 0 && ! value->isVoid() && newpos != cpos)
    {
	vector<liloOption*>::iterator it=order.begin();
	it+=cpos;
	liloOption* oop = order[cpos];
	order.erase (it);
	vector<liloOption*>::iterator it2=order.begin();
	it2+=newpos;
	if ((unsigned int)newpos > order.size ())
	    newpos = order.size ();
	order.insert(/*order.begin(), */it2, oop);
    }
    if(value->isVoid())
    {
	vector<liloOption*>::iterator it=order.begin();
	it+=cpos;
	delete order[cpos];
	order.erase(it);
	return YCPBoolean(true);
    }
    liloOption* opt=order[cpos];

    if(path->length()==2 && path->component_str(1)=="comment")
    {
        opt->comment=value->asString()->value_cstr();
	return YCPBoolean(true);
    }
    //==========================
    // set the option value
    switch(o.getOptType(opt->optname))
    {
	case T_INT:
	    if(!value->isInteger())
	    {
		y2warning("Warning: integer value for option '%s' expected", path->component_str(0).c_str());
	    }
	    break;
	case T_STR:
	    if(!value->isString())
	    {
		y2warning("Warning: string value for option '%s' expected", path->component_str(0).c_str());
	    }
	    break;
	case T_BOOL:
	    if(!value->isBoolean())
	    {
                y2warning("Warning: boolean value for option '%s' expected", path->component_str(0).c_str());
            }
            break;
	case T_UNKNOWN:
	    {
		break;
	    }
	default:
	    // special value
	    if(!value->isList())
	    {
		y2warning("Warning: list value for option '%s' expected", path->component_str(0).c_str());
	    }
    }
    if(value->isString())
    {
	string tmp = value->asString()->value();
	// Ugh, type is a global variable.
	// Is no more
	// Anyway, this should fix bug #19181.
	// yes, this is slow :(
	if (opt->optname == "label" && type != "grub")
	{
	    tmp = replaceBlanks (tmp, '_');
	}
	opt->value = tmp;
	return YCPBoolean(true);
    }
    if(value->isInteger() || value->isBoolean())
    {
	opt->value=value->toString().c_str();
	return YCPBoolean(true);
    }
    if(value->isList())
    {
	string result;
	YCPList lst=value->asList();
	for(int pos=0; pos<lst->size(); pos++)
	{
	    if(!lst->value(pos)->isString())
	    {
		return YCPError("error: list members must be strings when writing special value");
	    }
	    else
	    {
		if(result!="")
		{
		    result+="\n";
		}
		result+=lst->value(pos)->asString()->value_cstr();
	    }
	}
	opt->value=result;
	return YCPBoolean(true);
    }

    return YCPBoolean(false);
}

YCPValue liloOrderedOptions::Dir()
{
    YCPList list;
    for(uint i=0; i<order.size(); i++)
    {
	list->add(YCPString(order[i]->optname));
    }
    return list;
}

void liloOrderedOptions::dump(FILE* f)
{
    for(uint i=0; i<order.size(); i++)
    {
	fprintf(f, "%s = %s\n", order[i]->optname.c_str(), order[i]->value.c_str());
    }
}

int liloOrderedOptions::saveToFile(ostream* f, string indent)
{
    string separ = (type == "grub") ? " " : " = ";
    for(uint i=0; i<order.size(); i++)
    {
	if ((type == "grub" && (order[i]->optname == "title"))
	    ||(type == "zipl" && (order[i]->optname == "label"))
	    ||(type != "grub" && type != "zipl" && (order[i]->optname == "image" || order[i]->optname == "other")))
	{
	    if(order[i]->comment!="")
	    {
		*f << indentString(order[i]->comment, indent);
		*f << endl;
	    }

	    if (type == "zipl")
		*f << "[" << order[i]->value << "]" << endl;
	    else
		*f <<  order[i]->optname << separ << order[i]->value << endl;
	}
    }

    for(uint i=0; i<order.size(); i++)
    {
        if ((type == "grub" && (order[i]->optname == "title"))
	    ||(type == "zipl" && (order[i]->optname == "label"))
            ||(type != "grub" && type != "zipl" && (order[i]->optname == "image" || order[i]->optname == "other")))
	{
	    continue;
	}

	if(order[i]->comment!="")
	{
	    *f << indent;
	    *f << indentString(order[i]->comment, indent);
	    *f << endl;
	}
	*f << indent;
	switch(o.getOptType(order[i]->optname))
	{
	    case T_BOOL:
		if(order[i]->value=="true" || order[i]->value=="")
		{
		    *f << order[i]->optname << endl;
		}
		break;

	    case T_SPEC_CHANGE_RULES:
	    case T_SPEC_DISK:
	    case T_SPEC_CHANGE:
	    case T_SPEC_MAP_DRIVE:
	    case T_SPEC_MAP:

		*f << indentString(order[i]->value, indent+"    ");
		*f << endl;
		break;
	    default:
		*f <<  order[i]->optname << separ << order[i]->value << endl;

	}
    }

    return 0;
}

//=========================================================
//
//
//
//

liloSection::liloSection(const string& init_type)
{
//    sectName=sname;
    type = init_type;
    options=new liloOrderedOptions(type);
    
}

bool liloSection::processLine(inputLine* line)
{
    if (("grub" == type && line->option == "title")
	||("grub" != type &&(line->option == "image" || line->option == "other")))
    {
	sectName = line->value;
    }
    return options->processLine(line);
}

liloSection::~liloSection()
{

}

string liloSection::getSectName()
{
    int cpos=getPos(&(options->order), string(type == "grub" ? "title" : "label"));
    if(cpos<0 || options->order[cpos]->value=="")
    {
	return sectName.substr(sectName.rfind('/')+1);
    }
    return options->order[cpos]->value;
}

YCPValue liloSection::Read(const YCPPath& path)
{
    if(path->length()==0)
    {
	return options->Read (path);
	    //===========================
	    // return list of options
/*

WHY? The same is result of Dir ()

	YCPList list;
	for(uint i=0; i<options->order.size(); i++)
	{
	    list->add(YCPString(options->order[i]->optname));
	}
	return list;*/
    }

    if(path->length()>0)
    {
	int cpos=getPos(&(options->order), path->component_str(0));
	if(cpos<0 && path->component_str(0)==(type == "grub" ? "title" : "label"))
	{
	    return YCPString(getSectName());
	}
	    //===========================
	    // return option value
	return options->Read(path);
    }
    return YCPVoid();
}

YCPValue liloSection::Write(const YCPPath& path, const YCPValue& val, const YCPValue& pos)
{
    return options->Write(path, val, pos);
}

YCPValue liloSection::Dir()
{
    YCPList list=options->Dir()->asList();
    return list;
}

int liloSection::saveToFile(ostream* of, string indent)
{
    return options->saveToFile(of, indent);
}

