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

#undef y2log_component
#define y2log_component "ag_liloconf"
#include <Y2.h>
#include <scr/SCRAgent.h>
#include <scr/SCRInterpreter.h>

#include "LiloFile.h"

class LiloFile;

/* An interface class between YaST2 and RcFile */
class LiloAgent : public SCRAgent {
//    LiloFile *rc_file;
    liloFile* lilo;
public:
    LiloAgent();
    virtual ~LiloAgent();
    
    virtual YCPValue Read(const YCPPath &path, const YCPValue& arg = YCPNull());
    virtual YCPValue Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg = YCPNull());
    virtual YCPValue Dir(const YCPPath& path);
    
    virtual YCPValue otherCommand(const YCPTerm& term);
};

#endif /* _RcAgent_h */
