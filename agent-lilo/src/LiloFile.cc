/**
 * File:
 *   LiloFile.cc
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

#include "LiloSection.h"
#include "LiloFile.h"
#include <stdio.h>
#include <unistd.h>
#include <ycp/y2log.h>
#include <fstream>

#define headline "# Modified by YaST2. Last modification on"

liloFile::liloFile(string filename) : options()
{
    fname=filename;
}

liloFile::~liloFile()
{
}

bool liloFile::parse()
{
    string str;
    inputLine* li;
    liloSection* curSect=NULL;

    // erase old sections and options
    sections.erase(sections.begin(), sections.end());
    options.order.erase(options.order.begin(), options.order.end());

    ifstream is(fname.c_str());
    
    if(!is)
    {
	return false;
    }

    string commentBuffer="";
    string tmp;

    bool retval = false;
    bool trail=true;

    int linecounter=0;

    while(is)
    {
	
	getline(is, str);
	linecounter++;
    
	if(linecounter==1)
	{
	    if(str.substr(0, strlen(headline))==headline)
	    {
		continue;
	    }
	}
	
	// parse the line
	li=new inputLine(str);

	if(commentBuffer!="")
	{
	    tmp=commentBuffer;
	    if(li->comment!="")
	    {
		tmp=tmp+"\n"+li->comment;
	    }
	    commentBuffer=tmp;
	}
	else
	{
	    commentBuffer=li->comment;
	}

	li->comment=commentBuffer;

	if(trail && strip(li->src)=="")
	{
	    comment=li->comment;
	    trail=false;
	    commentBuffer="";
	    continue;
	}		

	bool header = false;
	if (type == "grub")
	{
	    if (li->option == "title")
	    {
                curSect=new liloSection();
                curSect->processLine(li); 
                sections.push_back(curSect);
                retval=true;
                header = true;
	    }
	}
	else
	{
	    if(li->option=="image" || li->option=="other")
	    {
		curSect=new liloSection();
		curSect->processLine(li); 
		sections.push_back(curSect);
		retval=true;
		header = true;
	    }
	}
	if (! header)
	{
	    if(curSect)
	    {
		retval=curSect->processLine(li);
	    }
	    else
	    {	
		retval=options.processLine(li);
	    }
	}

	if(retval)
	{
	    commentBuffer="";
	    trail=false;
	}

	if(li)
	{	
	    delete li;
	    li=NULL;
	}
    }
    
    return true;

}

bool liloFile::save(const char* filename)
{
    bool del=false;
    string fn;
    if(filename)
    {
	fn=filename;
    }
    else
    {
	fn=fname;
    }
    ofstream of(fn.c_str());
    
    if(!of.good())
    {
	if(del) delete filename;
	return false;
    }

    time_t tim=time(NULL);

    of << headline << " " << string(ctime(&tim)) << endl ;

    if(comment.length()>=0)
    {
	of << comment << endl;
    }

    options.saveToFile(&of, "");
    uint pos;

    for(pos=0; pos<sections.size(); pos++)
    {
	of << endl;
	sections[pos]->saveToFile(&of, "    ");
    }
    return true;
}

bool liloFile::reread()
{
    return parse();
}

int liloFile::getSectPos(string sectname)
{
    uint pos;
    for(pos=0; pos<sections.size(); pos++)
    {
        if(sections[pos]->getSectName()==sectname)
        {
            break;
        }
    }

    if(pos<sections.size())
    {
	return pos;
    }
    else
    {
	return -1;
    }
}

liloSection* liloFile::getSectPtr(const YCPPath& path)
{
    if(path->length()<2)
    {
	return NULL;
    }
    
    int pos=getSectPos(path->component_str(1));
    
    if(pos>=0)
    {
	return sections[pos];
    }
    else
    {
        return NULL;
    }
}

YCPValue liloFile::Write(const YCPPath &path, const YCPValue& value, const YCPValue& _UNUSED)
{
    bool ret;
    if(path->length()==0)
    {
	if(value->isVoid())
	{
	    ret = save();
	}
	else
	{
	    ret = save(value->asString()->value_cstr());
	}
	if (!ret)
	{
	    return YCPError("Error: cannot open output file for writing");
	}
        return YCPBoolean(ret);
    }

    // set config filename
    if(path->component_str(0) == "setfilename")
    {
	fname=value->asString()->value_cstr();
        return YCPBoolean(true);
    }   


    //=========================
    // comment writing

    if(path->component_str(0)=="comment")
    {
	comment=value->asString()->value_cstr();
        return YCPBoolean(true);
    }   

    //==========================
    // sections    

    if(path->component_str(0)=="sections")
    {
	if(path->length()==1)
	{
	    return YCPError("attenpt to write to .lilo.sections", YCPBoolean(false));
	}
    
	liloSection* sect=getSectPtr(path);

	if(value->isVoid() && path->length()==2)
	{
	    //=======================
	    // remove section
	    if(sect)
	    {
		int pos=getSectPos(path->component_str(1));

		vector<liloSection*>::iterator it=sections.begin();
		for(; pos>0; pos--)
		{
		    ++it;
		}

		sections.erase(it);
		return YCPBoolean(true);
	    }
	    else
	    {
		y2warning("Warning: attempt to remove non-existent section '%s'", 
		    path->component_str(1).c_str());
		return YCPBoolean(false);
	    }
	}
	if(sect==NULL)
	{
	    //====================
	    // create new section
	    sect = new liloSection();
	    if (sect)
	    {
		sections.push_back(sect);
		sect->options->order.push_back(new liloOption(type == "grub" ? "title" : "label", path->component_str(1), ""));
	    }
	    else
	    {
		return YCPError("Cannot create new section");
	    }
	}

	//=====================
	// and write some option value

	return sect->Write(path->at(2), value);
    }

    
 
    return options.Write(path, value);
}

YCPValue liloFile::Read(const YCPPath &path, const YCPValue& _UNUSED)
{
    if(path->length()==0)
    {
	// TODO: reread the file
	return YCPBoolean(true);
    }
	

    if(path->component_str(0) == "getfilename")
    {
        return YCPString(fname);
    }

    if(path->component_str(0) == "reread")
    {
        return YCPBoolean(reread());
    }

    //=========================
    // comment reading

    if(path->component_str(0)=="comment")
    {
        return YCPString(comment);
    }

    //=========================
    // section reading    

    if(path->component_str(0)=="sections")
    {
	if(path->length()==1)
	{
	    return YCPError("section name must be specified for reading .image (eg .lilo.sections.vmlinuz)", YCPVoid());
	}
	liloSection* sect=getSectPtr(path);
	if(sect)
	{
	    return (sect->Read(path->at(2)));
	}
	return YCPVoid();
    }

    //=========================
    // option value reading    

    return options.Read(path);	
}

YCPValue liloFile::Dir(const YCPPath& path)
{
    YCPList list;
    if(path->length()>2)
    {
	return YCPVoid();
    }
    if(path->length()==0)
    {
	list=options.Dir()->asList();
	list->add(YCPString("sections"));
	return list;
    }
    if(path->length()>=1)
    {
	if(path->component_str(0) != "sections")
	{
	    return list;
	}
	if(path->length()==1)
	{
	    for(uint i=0; i<sections.size(); i++)
            {
                list->add(YCPString(sections[i]->getSectName()));
            }
            return list;
	}
	liloSection* s=getSectPtr(path);
	if(s)
	{
	    return s->Dir();   
	}
	return list;

    }
    return list;
}

void liloFile::dump(FILE* f)
{
    options.dump(f);
}

