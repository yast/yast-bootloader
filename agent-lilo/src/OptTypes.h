#ifndef __OPTTYPES
#define __OPTTYPES

/**
 * File:
 *   LiloFile.h
 *
 * Module:
 *   lilo.conf agent
 *
 * Summary:
 *   option type database
 *
 * Authors:
 *   dan.meszaros <dmeszar@suse.cz>
 *
 * $Id$
 *
 * 
 *
 */

#define T_STR   1
#define T_INT   2
#define T_BOOL  3
#define T_SPEC  4
#define T_UNKNOWN 0

#define T_SPEC_CHANGE_RULES 16
#define T_SPEC_DISK         17
#define T_SPEC_CHANGE       18
#define T_SPEC_MAP_DRIVE    19

#include <map>
#include <string>

// using std::string;
// using std::map;
using namespace std;

int getOptType(const string& optname);

string getSpecGroup(const string& optname);

#endif
