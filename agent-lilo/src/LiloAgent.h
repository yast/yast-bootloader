// -*- c++ -*-

/**
 * File:
 *   LiloAgent.h
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
 */


#ifndef __LILOAGENT
#define __LILOAGENT

#include <Y2.h>
#include <scr/SCRAgent.h>
//#include <scr/SCRInterpreter.h>

#include "LiloFile.h"

class LiloFile;

/* An interface class between YaST2 and RcFile */
class LiloAgent : public SCRAgent {
//    LiloFile *rc_file;
    liloFile* lilo;
public:
    LiloAgent();
    virtual ~LiloAgent();
    
    virtual YCPValue Read(const YCPPath &path, const YCPValue& arg = YCPNull(), const YCPValue& opt = YCPNull());
    virtual YCPBoolean Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg = YCPNull());
    virtual YCPList Dir(const YCPPath& path);
    virtual YCPValue Execute (const YCPPath& path, const YCPValue& value = YCPNull(), const YCPValue& arg = YCPNull());
    
    virtual YCPValue otherCommand(const YCPTerm& term);
private:
    string type;
};

#endif /* _RcAgent_h */
