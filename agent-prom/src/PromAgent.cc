/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: Prom agent implementation
 *
 * Authors:
 *   Thorsten Kukuk <kukuk@suse.de>
 *
 * $Id$
 */

#include <fcntl.h>
#include <unistd.h>
#include "PromAgent.h"
#include "prom.h"

/**
 * Constructor
 */
PromAgent::PromAgent() : SCRAgent()
{
}

/**
 * Destructor
 */
PromAgent::~PromAgent()
{
}

/**
 * Dir
 */
YCPValue PromAgent::Dir(const YCPPath& path)
{
    y2error("Wrong path '%s' in Read().", path->toString().c_str());
    return YCPVoid();
}

/**
 * Read
 */
YCPValue PromAgent::Read(const YCPPath &path, const YCPValue& arg = YCPNull())
{
  y2debug ("PromAgent::Read (.prom%s)", path->toString().c_str());

  if (path->length() == 1)
    {
      if (strcasecmp (path->component_str(0).c_str(), "hasaliases") == 0)
	{
	  int has_aliases;
	  int promfd;

	  if ((promfd = prom_init (O_RDONLY)) < 0)
	    return YCPVoid();

	  has_aliases = check_aliases (promfd);

	  close (promfd);

	  return YCPInteger(has_aliases);
	}
      else if (strcasecmp (path->component_str(0).c_str(), "path") == 0)
	{
	  int promfd;
	  char *dev;

	  if ((promfd = prom_init (O_RDONLY)) < 0)
	    return YCPVoid();

	  init_scan_disks (promfd);

	  close (promfd);

	  if (arg.isNull() || !arg->isString())
            return YCPError ("Bad device name in call to Read(.prom.path)");

	  if (strrchr (arg->asString()->value().c_str(),'/') == NULL)
	    dev = strdup (arg->asString()->value().c_str());
	  else
	    {
	      dev = strdup (strrchr (arg->asString()->value().c_str(), '/'));
	      ++dev;
	    }

	  return YCPString(disk2PromPath(dev));
	}

    }
  else if (path->length() == 2)
    {
      if (strcasecmp (path->component_str(0).c_str(), "path") == 0)
	{
	  int promfd;
	  char *dev;

	  if ((promfd = prom_init (O_RDONLY)) < 0)
	    return YCPVoid();

	  init_scan_disks(promfd);

	  close(promfd);

	  if (strrchr (path->component_str(1).c_str(),'/') == NULL)
	    dev = strdup (path->component_str(1).c_str());
	  else
	    dev = strdup (strrchr (path->component_str(1).c_str(), '/'));

	  return YCPString(disk2PromPath(dev));
	}
    }

  y2error("Wrong path '%s' in Read().", path->toString().c_str());

  return YCPVoid ();
}

/**
 * Write
 */
YCPValue PromAgent::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg = YCPNull())
{
    y2error("Wrong path '%s' in Write().", path->toString().c_str());
    return YCPVoid();
}

/**
 * otherCommand
 */
YCPValue PromAgent::otherCommand(const YCPTerm& term)
{
    string sym = term->symbol()->symbol();

    if (sym == "PromAgent") {
        /* Your initialization */
        return YCPVoid();
    }

    return YCPNull();
}
