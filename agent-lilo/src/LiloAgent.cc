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
#include "OptTypes.h"

/* LiloAgent */
LiloAgent::LiloAgent() : SCRAgent() {
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

YCPValue LiloAgent::Read(const YCPPath &path, const YCPValue& arg, const YCPValue& opt)
{
    y2debug ("Called LiloAgent::Read");
    if (path->length() > 0 && path->component_str(0)=="opttypes")
    {
	y2debug ("Called LiloAgent::Read for opttypes");
	OptTypes o(type);
	return o.getYCPOptTypes ();

    }
    if(lilo)
    {
	return lilo->Read(path, arg);
    }
    else 
    {
	y2error ("File not initialized");
	return YCPVoid();
    }
}

/**
 * method for writing to lilo memory representation 
 */

YCPBoolean LiloAgent::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg) {
    y2debug ("Called LiloAgent::Write");
    if(lilo)
	return lilo->Write(path, value, arg);
    else
	return YCPBoolean(false);
}

/** 
 * returns list of items in given path (see lilo agent docs)
 */

YCPList LiloAgent::Dir(const YCPPath& path) {
    y2debug ("Called LiloAgent::Dir");
    if(lilo)
    {
	return lilo->Dir(path);
    }
    else
    {
	y2error ("File not initialized");
	return YCPNull();
    }
}

YCPValue LiloAgent::Execute (const YCPPath& path, const YCPValue& value, const YCPValue& arg)
{
    return YCPValue (YCPNull ());
}

/**
 * other (unknown) operation on lilo file
 */

YCPValue LiloAgent::otherCommand(const YCPTerm& term) {
    y2debug ("Called LiloAgent::otherCommand");
    y2debug("other: %s", term->toString().c_str());
    if(lilo)	
    {
	delete lilo;
    }
    string sym = term->name();
    if (sym == "LiloConf" && term->size() == 2) 
    {
	if (term->value(0)->isString())
	{
	    YCPString s = term->value(0)->asString();
	    type = s->value ();
	}
        if (term->value(1)->isString()) 
	{
            YCPString s = term->value(1)->asString();
            lilo = new liloFile(s->value(), type);
	    y2debug("Parsing %s", s->value().c_str());
	    lilo->parse();
            return YCPVoid();
        } 
	else
	{
	    return YCPError("Bad first arg of LiloConf(): is not a string.");
	}
    }

    return YCPVoid();
}

