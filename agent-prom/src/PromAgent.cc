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

#define _GNU_SOURCE

#include <fcntl.h>
#include <unistd.h>
#include <string.h>
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
  y2debug ("PromAgent::Write (.prom%s, %s)", path->toString().c_str(),
	   value->toString().c_str());

  if (path->length() == 1)
    {
      if (strcasecmp (path->component_str(0).c_str(), "boot-device") == 0)
	{
	  int promfd, len;
	  char *old_device;

	  if (value.isNull() || !value->isString())
            return YCPError ("Bad argument in call to Write(.prom.boot-device)");
	  if ((promfd = prom_init (O_RDWR)) < 0)
	    return YCPVoid();

	  old_device = prom_getopt (promfd, "boot-device", &len);
	  if (old_device)
	    {
	      prom_setopt (promfd, "boot-device",
			   value->asString()->value().c_str());
	      prom_setopt (promfd, "boot-file", "");
	    }
	  else
	    {
	      old_device = prom_getopt (promfd, "boot-from", &len);
	      if (old_device)
		prom_setopt (promfd, "boot-from",
			     value->asString()->value().c_str());
	    }

	  close (promfd);

	  // return YCPString(old_device);
	  return YCPVoid();
	}

    }
  else if (path->length() == 2)
    {
      if (strcasecmp (path->component_str(0).c_str(), "alias") == 0 &&
	  strcasecmp (path->component_str(1).c_str(), "linux") == 0)
	{
	  int promfd;

	  if (value.isNull() || !value->isString())
            return YCPError ("Bad argument in call to Write(.prom.alias)");

	  if ((promfd = prom_init (O_RDWR)) < 0)
	    return YCPVoid();

	  if (check_aliases (promfd) == 0)
	    return YCPError("No aliases in PROM");

	  char *use_nvramrc;
	  char nvramrc[2048];
	  char *p, *q, *r, *s;
	  int enabled = -1;
	  int count, len;

	  use_nvramrc = prom_getopt (promfd, "use-nvramrc?", &len);
	  if (len > 0)
	    {
	      if (!strcasecmp (use_nvramrc, "false"))
                enabled = 0;
	      else if (!strcasecmp (use_nvramrc, "true"))
                enabled = 1;
	    }
	  if (enabled != -1)
	    {
	      p = prom_getopt (promfd, "nvramrc", &len);
	      if (p)
		{
		  memcpy (nvramrc, p, len);
		  nvramrc [len] = 0;
		  q = nvramrc;
		  for (;;) {
                    /* If there is already
		       `devalias linux /some/ugly/prom/path'
                       make sure we fully understand that and remove it. */
                    if (!strncmp (q, "devalias", 8) && (q[8] == ' ' ||
							q[8] == '\t'))
		      {
			for (r = q + 9; *r == ' ' || *r == '\t'; r++);
                        if (!strncmp (r, "linux", 5))
			  {
                            for (s = r + 5; *s && *s != ' ' &&
				   *s != '\t'; s++);
                            if (!*s) break;
                            if (s == r + 5 ||
                                (r[5] == '#' && r[6] >= '0' && r[6] <= '9' &&
                                 (s == r + 7 ||
                                  (r[7] >= '0' && r[7] <= '9' &&
				   s == r + 8))))
			      {
				for (r = s + 1; *r == ' ' || *r == '\t'; r++);
                                for (; *r && *r != ' ' && *r != '\t' &&
				       *r != '\n'; r++);
                                for (; *r == ' ' || *r == '\t'; r++);
                                if (*r == '\n')
				  {
                                    r++;
                                    memmove (q, r, strlen(r) + 1);
                                    continue;
				  }
			      }
			  }
		      }
                    q = strchr (q, '\n');
                    if (!q) break;
                    q++;
		  }
		  len = strlen (nvramrc);
		  if (len && nvramrc [len-1] != '\n')
                    nvramrc [len++] = '\n';
		  p = nvramrc + len;
		  p = stpcpy (p, "devalias linux ");
		  r = strdup (value->asString()->value().c_str());
		  q = strchr (r, ';');
		  count = 1;
		  while (q)
		    {
		      memcpy (p, r, q - r);
		      p += q - r;
		      sprintf (p, "\ndevalias linux#%d ", count++);
		      p = strchr (p, 0);
		      r = q + 1;
		      q = strchr (r, ';');
		    }
		  p = stpcpy (p, r);
		  *p++ = '\n';
		  *p = 0;
		  prom_setopt (promfd, "nvramrc", nvramrc);
		  if (!enabled)
                    prom_setopt (promfd, "use-nvramrc?", "true");
		}
	    }
	  else
	    y2error("use-nvramrc has no defined status");
	  close(promfd);

	  return YCPVoid();
	}
    }

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
