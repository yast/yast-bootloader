/**
 * File:
 *   LiloFile.h
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

#ifndef __LILOFILE
#define __LILOFILE

#include <string>
#include <vector>
#include "LiloSection.h"

/**
 * lilo.conf file memory representation base class
 */

class liloFile
{
public:
    /**
      *  type of parsed file
      */
    string type;

    /**
     *  path to lilo.conf file
     */
    string fname;

    /**
     *  contents of lilo.conf file for restoring from string
     */
    string file_contents;

    /**
     *  use string for parsing/file generating instead of file
     */
    bool use_string;

    /**
     *  lilo.conf global comment (global comment is separated from first option comment by empty line)
     */
    string comment;

    /**
     *  object that holds information about the options order and their value and comments
     */
    liloOrderedOptions options;
    
    /**
     *  sections of lilo.conf file
     */
    vector<liloSection*> sections;

    /**
     *	does nothing but sets the path to lilo.conf file
     */

	liloFile(string filename, const string& init_type);

    /**
     *  
     */
	~liloFile();

    /**
     *  loads and parses the file. returns false on failure
     */ 
    bool parse();

    /** 
     *  saves the memory structure to disk. returns false on failure
     */
    bool save(const char* filename=NULL);

    /**
     * discards changes and reread the lilo.conf file again
     */
    bool reread();

    /** 
     * dumps debug info to file
     */
    void dump(FILE* f);

    /**
     * returns pointer to section that coresponds with the path and section name
     * (eg. for .lilo.image, "vmlinuz" returns pointer to section from imageSections 
     * that matches the "vmlinuz" section name)
     */
    liloSection* getSectPtr(const YCPPath& path);

    /**
     * writing to internal datastructure / writing structure to file
     */
    YCPValue Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg);

    /**
     * reading from internal data structure
     */    
    YCPValue Read(const YCPPath &path, const YCPValue& arg);

    /**
     *	Dir from internal data structure
     */
    YCPValue Dir(const YCPPath& path);

    /**
     *	returns corresponding section vector from the given path
     */
    vector<liloSection*>* getVectByName(const YCPPath& path);
    
    /**
     *  returns position in of section given section name and section's vector
     */
    int getSectPos(string sectname);
};

#endif
