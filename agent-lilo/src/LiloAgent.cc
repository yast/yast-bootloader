/**
 * File:
 *   LiloAgent.cc
 *
 * Module:
 *   lilo.conf agent
 *
 * Summary:
 *   agent/ycp interface
 *
 * Authors:
 *   dan.meszaros <dmeszar@suse.cz>
 *
 * $Id$
 *
 * interface for acces to lilo file representation from ycp script
 *
 */

#include "LiloAgent.h"
#include "LiloFile.h"

/* LiloAgent */
LiloAgent::LiloAgent() : SCRAgent() {
//    lilo=new liloFile("/tmp/lilo.conf");    
//    const char *tr = getenv("Y2_TARGET_ROOT");
//    y2error("Env value='%s'", tr);
//    lilo->parse();
    lilo=NULL;
}

LiloAgent::~LiloAgent() {
    if(lilo)
    {
	delete lilo;
    }
}

/**
 * method for reading from lilo memory representation
 */

YCPValue LiloAgent::Read(const YCPPath &path, const YCPValue& arg) {
    if(lilo)
	return lilo->Read(path, arg);
    else 
	return YCPVoid();
}

/**
 * method for writing to lilo memory representation 
 */

YCPValue LiloAgent::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg) {
    if(lilo)
	return lilo->Write(path, value, arg);
    else
	return YCPVoid();
}

/** 
 * returns list of items in given path (see lilo agent docs)
 */

YCPValue LiloAgent::Dir(const YCPPath& path) {
    if(lilo)
	return lilo->Dir(path);
    else
	return YCPVoid();
}

/**
 * other (unknown) operation on lilo file
 */

YCPValue LiloAgent::otherCommand(const YCPTerm& term) {
    y2debug("other: %s", term->toString().c_str());
    if(lilo)	
    {
	delete lilo;
    }
    string sym = term->symbol()->symbol();
    if (sym == "LiloConf" && term->size() == 1) 
    {
        if (term->value(0)->isString()) 
	{
            YCPString s = term->value(0)->asString();
            if (lilo)
                delete lilo;
            lilo = new liloFile(s->value());
	    y2debug("Parsing %s", s->value().c_str());
	    lilo->parse();
            return YCPVoid();
        } 
	else
	{
	    return YCPError("Bad first arg of LiloConf(): is not a string.");
	}
    }

//    lilo=new liloFile("/tmp/lilo.conf");     
//    const char *tr = getenv("Y2_TARGET_ROOT");
//    y2error("Env value='%s'", tr);
//    lilo->parse();
    
    return YCPVoid();
}

