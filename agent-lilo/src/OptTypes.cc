/**
 * File:
 *   OptType.cc
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

#include <map>
#include <string>
#include <ycp/y2log.h>
#include "OptTypes.h"


OptTypes::OptTypes(const string& type)
{
    int val=T_BOOL;

    if (type == "grub")
    {
	_options["hiddenmenu"]=val;
	_options["rarp"]=val;
	_options["debug"]=val;
	_options["displayapm"]=val;
	_options["displaymem"]=val;
	_options["fstest"]=val;
	_options["lock"]=val;
	_options["makeactive"]=val;


    val=T_STR;
	_options["geometry"]=val;
	_options["embed"]=val;
	_options["find"]=val;
	_options["title"]=val;
	_options["bootp"]=val;
	_options["color"]=val;
	_options["device"]=val;
	_options["dhcp"]=val;
	_options["hide"]=val;
	_options["ifconfig"]=val;
	_options["pager"]=val;
	_options["partnew"]=val;
	_options["parttype"]=val;
	_options["password"]=val;
	_options["serial"]=val;
	_options["setkey"]=val;
	_options["terminal"]=val;
	_options["tftpserver"]=val;
	_options["unhide"]=val;
	_options["blocklist"]=val;
	_options["cat"]=val;
	_options["chainloader"]=val;
	_options["cmp"]=val;
	_options["configfile"]=val;
	_options["halt"]=val;
	_options["help"]=val;
	_options["impsprobe"]=val;
	_options["initrd"]=val;
	_options["install"]=val;
	_options["ioprobe"]=val;
	_options["kernel"]=val;
	_options["module"]=val;
	_options["modulenounzip"]=val;
	_options["pause"]=val;
	_options["reboot"]=val;
	_options["read"]=val;
	_options["root"]=val;
	_options["rootnoverify"]=val;
	_options["savedefault"]=val;
	_options["setup"]=val;
	_options["testload"]=val;
	_options["testvbe"]=val;
	_options["uppermem"]=val;
	_options["vbeprobe"]=val;
	_options["map"]=val;

    val=T_INT;

	_options["default"]=val;
	_options["timeout"]=val;
	_options["fallback"]=val;

	return;
    }

    // other bootloader - use LILO
    val = T_BOOL;

    _options["compact"]=val;	    _options["fix-table"]=val;
    _options["ignore-table"]=val;   _options["lba32"]=val;
    _options["linear"]=val;	    _options["lock"]=val;
    _options["nowarn"]=val;	    _options["optional"]=val;
    _options["prompt"]=val;	    _options["read-only"]=val;
    _options["restricted"]=val;	    _options["read-write"]=val;
    _options["unsafe"]=val;	    _options["lock"]=val;
    _options["optional"]=val;	    _options["restricted"]=val;
    _options["makeactive"]=val;	    _options["hiddenmenu"]=val;

    // for ppc:
    _options["copy"]=val;	    _options["activate"]=val;

    val=T_STR;

    _options["backup"]=val;	    _options["serial"]=val;
    _options["boot"]=val;	    _options["append"]=val;
    _options["default"]=val;        _options["initrd"]=val;
    _options["disktab"]=val;        _options["literal"]=val;
    _options["force-backup"]=val;   _options["ramdisk"]=val;
    _options["install"]=val;        _options["root"]=val;
    _options["map"]=val;	    _options["vga"]=val;
    _options["menu-title"]=val;     _options["loader"]=val;
    _options["menu-scheme"]=val;    _options["table"]=val;
    _options["message"]=val;        _options["alias"]=val;
    _options["password"]=val;       _options["label"]=val;
    _options["kernel"]=val;

    val=T_INT;

    _options["delay"]=val;	    _options["verbose"]=val;
    _options["timeout"]=val;       

    val=T_SPEC_CHANGE_RULES;
#ifndef __sparc__    
    _options["change-rules"]=val;   _options["type"]=val;
    _options["reset"]=val;          _options["normal"]=val;
    _options["hidden"]=val;

    val=T_SPEC_DISK;

    _options["disk"]=val;	    _options["heads"]=val;
    _options["inaccessible"]=val;   _options["cylinders"]=val;
    _options["bios"]=val;	    
    _options["sectors"]=val;

    val=T_SPEC_CHANGE;

    _options["change"]=val;	    _options["set"]=val;
    _options["partition"]=val;      _options["deactivate"]=val;
    _options["partition"]=val;      _options["automatic"]=val;

#ifndef __powerpc__
    _options["activate"]=val;
#endif

    val=T_SPEC_MAP_DRIVE;

    _options["map-drive"]=val;	    _options["to"]=val;
#endif

    if (type == "elilo")
    {
	// add exra elilo options, not needed don't have to be removed
	_options["noedd30"] = T_BOOL;
	_options["chooser"] = T_STR;
	_options["relocatable"] = T_BOOL;
	_options.erase ("lba");
	_options.erase ("lba32");
	_options.erase ("linear");
    }

}

int OptTypes::getOptType(const string& optname)
{
    return _options[optname];
}

string OptTypes::getSpecGroup(const string& optname)
{
    switch(_options[optname])
    {
	case T_SPEC_CHANGE_RULES: return string("change-rules");
	case T_SPEC_DISK        : return string("disk");
	case T_SPEC_CHANGE      : return string("change");
	case T_SPEC_MAP_DRIVE   : return string("map-drive");
	case T_SPEC_MAP		: return string("map");
    }

    return "";
}

YCPMap OptTypes::getYCPOptTypes () {
    YCPMap m;
    map <string, int>::iterator it = _options.begin ();
    while (it != _options.end ()) {
	switch(it->second)
	{
	    case T_UNKNOWN: {
		m->add (YCPString (it->first), YCPString ("s"));
		break;
	    }
	    case T_BOOL: {
		m->add (YCPString (it->first), YCPString ("b"));
		break;
	    }
	    case T_STR: {
		m->add (YCPString (it->first), YCPString ("s"));
		break;
	    }
	    case T_INT: {
		m->add (YCPString (it->first), YCPString ("i"));
		break;
	    }
	    default : m->add (YCPString (it->first), YCPString ("x"));
	}
	it ++;
    }
    return m;
}
