/**
 * File:
 *   LiloSection.h
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

#ifndef __LILOSECTION
#define __LILOSECTION

#include <string>
#include <vector>
#include <map>

#include <Y2.h>

#include <stdio.h>
#include <iostream>
#include <fstream>

using namespace std;

extern string type;

// using std::vector;
// using std::map;

string strip(string str);
string indentString(string str, string indent);	// replaces each occurence of '\n' by param
class liloSection;

/**
 * for each input line 'inputLine' instance is created. input line is parsed in ctr,
 * results are stored in members
 *
 */

class inputLine {
public:

	// eg. input line is: boot = /dev/hda #comment

	/** option name ('boot') */
    string option;
	/** option value ('/dev/hda') */
    string value;
	/** comment that goes after option on the same line ('#comment') */
    string comment;

	/** not parsed source line */
    string src;    

    inputLine(const string& line);
    void dump();
};

/**
 *  lilo options contains information about option value, its type and comment
 *
 *
 */

class liloOption {
public:
    
    string optname;
    /** value option is always string */
    string value;
    /** option comment */
    string comment;
    liloOption(string optn, string val, string com="");
    void dump();
    liloOption() {};
};

/**
 * class for storing order of options read from file, and 
 * list of all known/set options
 *
 */

class liloOrderedOptions 
{
public:
    /** vector of string for storing options order. new options are appended to the end of vector */
    vector<liloOption*>		order;
   
	/** initialization of options members */ 
	liloOrderedOptions();
	/** creates new 'order' entry ands sets new value in 'options' */
	bool processLine(inputLine* li);
	/** returns value of the given path */
	YCPValue Read(const YCPPath& path);
	/** writes new value to the given path */
	YCPValue Write(const YCPPath& path, const YCPValue& val, const YCPValue& _pos);
	/** dir of sub-stuff... see lilo_agent docs */
	YCPValue Dir();
	/** */
	void dump(FILE* f);
    
	/** saves contents of this to given file */
	int saveToFile(ofstream* f, string indent="");
};


enum {
    SECT_IMAGE = 0,
    SECT_OTHER 
};

/**
 * class for storing single section data
 *
 *
 */

class liloSection {
public:
	/** ordered options */
    liloOrderedOptions	*options;

	/** section name. e.g. if there's a line in "image=/dev/hda3" then sectName="/dev/hda3" */
    string sectName;	    
	/** section comment- comment that was parsed just before section was defined */
    string sectComment;

	/** one of SECT_IMAGE / SECT_OTHER */
    int	sectType; 

	/** default. does nothing */
	liloSection();

	virtual ~liloSection();

	/** only passes argument to 'options' */ 
    virtual bool    processLine(inputLine* line);
    
	/** returns section label. see man /lilo/conf 'label' description */
    string getSectName();

	/** only passes arguments to 'options' */
    int	saveToFile(ofstream* f, string indent="");

	/** method for reading from path */
    virtual YCPValue Read(const YCPPath& path);

	/** method for reading to path */
    virtual YCPValue Write(const YCPPath& path, const YCPValue& val, const YCPValue& pos);


	/** returns list of all set variables */
    virtual YCPValue Dir();
    
};

/**
 * replace non-printable chars and space by r
 */
string replaceBlanks (const string &s, char r);

#endif
