/* prom.cc: Conversions between SCSI and IDE disk names
 *	    and OpenPROM fully qualified paths.
 *
 * Copyright (C) 2001 Thorsten Kukuk <kukuk@suse.de>
 * Copyright (C) 1999, 2000 Jakub Jelinek <jakub@redhat.com>
 *
 * This software may be freely redistributed under the terms of the GNU
 * public license.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#define _GNU_SOURCE
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <asm/openpromio.h>
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/utsname.h>
#include <prom.h>

static char *promdev = "/dev/openprom";
static char sd_targets[10] = "31204567";
static int p1275 = 0;
static int prom_root_node, prom_current_node;
static int promvers;
static void (*prom_walk_callback)(int promfd, int node);
static char prom_path[1024];
#define MAX_PROP        128
#define MAX_VAL         (4096-128-4)
static char buf[4096];
static char regstr[40];
#define DECL_OP(size) struct openpromio *op = (struct openpromio *)buf; op->oprom_size = (size)

static int
prom_getsibling (int promfd, int node)
{
  DECL_OP(sizeof(int));

  if (node == -1)
    return 0;
  *(int *)op->oprom_array = node;
  if (ioctl (promfd, OPROMNEXT, op) < 0)
    return 0;
  prom_current_node = *(int *)op->oprom_array;
  return *(int *)op->oprom_array;
}

static int
prom_getchild (int promfd, int node)
{
  DECL_OP(sizeof(int));

  if (!node || node == -1) return 0;
  *(int *)op->oprom_array = node;
  if (ioctl (promfd, OPROMCHILD, op) < 0)
    return 0;
  prom_current_node = *(int *)op->oprom_array;
  return *(int *)op->oprom_array;
}

static char *
prom_getproperty (int promfd, char *prop, int *lenp)
{
  DECL_OP(MAX_VAL);

  strcpy (op->oprom_array, prop);
  if (ioctl (promfd, OPROMGETPROP, op) < 0)
    return 0;
  if (lenp) *lenp = op->oprom_size;
  return op->oprom_array;
}

static char *
prom_getopt(int promfd, char *var, int *lenp) {
    DECL_OP(MAX_VAL);

    strcpy (op->oprom_array, var);
    if (ioctl (promfd, OPROMGETOPT, op) < 0)
        return 0;
    if (lenp) *lenp = op->oprom_size;
    return op->oprom_array;
}

static int
prom_pci2node(int promfd, int bus, int devfn) {
    DECL_OP(2*sizeof(int));

    ((int *)op->oprom_array)[0] = bus;
    ((int *)op->oprom_array)[1] = devfn;
    if (ioctl (promfd, OPROMPCI2NODE, op) < 0)
        return 0;
    prom_current_node = *(int *)op->oprom_array;
    return *(int *)op->oprom_array;
}

#define PW_TYPE_SBUS	1
#define PW_TYPE_PCI	2
#define PW_TYPE_EBUS	3

static void
prom_walk(int promfd, char *path, int parent, int node, int type) {
    int nextnode;
    int len, ntype = type;
    char *prop;

    prop = prom_getproperty(promfd, "name", &len);
    if (prop && len > 0) {
        if ((!strcmp(prop, "sbus") || !strcmp(prop, "sbi")) && !type)
            ntype = PW_TYPE_SBUS;
        else if (!strcmp(prop, "ebus") && type == PW_TYPE_PCI)
            ntype = PW_TYPE_EBUS;
        else if (!strcmp(prop, "pci") && !type)
            ntype = PW_TYPE_PCI;
    }
    *path = '/';
    strcpy (path + 1, prop);
    prop = prom_getproperty(promfd, "reg", &len);
    if (prop && len >= 4) {
        unsigned int *reg = (unsigned int *)prop;
        int cnt = 0;
        if (!p1275 || (type == PW_TYPE_SBUS))
	    sprintf (regstr, "@%x,%x", reg[0], reg[1]);
        else if (type == PW_TYPE_PCI) {
	    if ((reg[0] >> 8) & 7)
		sprintf (regstr, "@%x,%x", (reg[0] >> 11) & 0x1f, (reg[0] >> 8) & 7);
	    else
		sprintf (regstr, "@%x", (reg[0] >> 11) & 0x1f);
        } else if (len == 4)
	    sprintf (regstr, "@%x", reg[0]);
        else {
	    unsigned int regs[2];

	    /* Things get more complicated on UPA. If upa-portid exists,
	       then address is @upa-portid,second-int-in-reg, otherwise
	       it is @first-int-in-reg/16,second-int-in-reg (well, probably
	       upa-portid always exists, but just to be safe). */
	    memcpy (regs, reg, sizeof(regs));
	    prop = prom_getproperty(promfd, "upa-portid", &len);
	    if (prop && len == 4) {
		reg = (unsigned int *)prop;
		sprintf (regstr, "@%x,%x", reg[0], regs[1]);
	    } else
	        sprintf (regstr, "@%x,%x", regs[0] >> 4, regs[1]);
	}
        for (nextnode = prom_getchild(promfd, parent); nextnode;
	     nextnode = prom_getsibling(promfd, nextnode)) {
	    prop = prom_getproperty(promfd, "name", &len);
	    if (prop && len > 0 && !strcmp (path + 1, prop))
		cnt++;
	}
        if (cnt > 1)
	    strcat (path, regstr);
    }

    prom_walk_callback(promfd, node);

    nextnode = prom_getchild (promfd, node);
    if (nextnode)
      prom_walk (promfd, strchr (path, 0), node, nextnode, ntype);
    nextnode = prom_getsibling (promfd, node);
    if (nextnode)
      prom_walk (promfd, path, parent, nextnode, type);
}

#define SDSK_TYPE_IDE	1
#define SDSK_TYPE_SD	2
#define SDSK_TYPE_PLN	3
#define SDSK_TYPE_FC	4

static struct sdsk_disk {
    unsigned int prom_node;
    unsigned int type, host, hi, mid, lo;
    char *prom_name;
} *hd = NULL, *sd = NULL;
static int hdlen, sdlen;

static void
scan_walk_callback (int promfd, int node)
{
  int nextnode;
  char *prop;
  int len, disk;
  static int v0ctrl = 0;

  for (disk = 0; disk < hdlen + sdlen; disk++)
    {
      if (hd[disk].prom_node == node)
	{
	  switch (hd[disk].type)
	    {
	    case SDSK_TYPE_IDE:
	      for (nextnode = prom_getchild (promfd, node); nextnode;
		   nextnode = prom_getsibling (promfd, nextnode))
		{
		  prop = prom_getproperty (promfd, "name", &len);
		  if (prop && len > 0 && (!strcmp (prop, "ata") ||
					  !strcmp (prop, "disk")))
		    break;
		}
	      if (!nextnode)
		continue;
	      if (prop[0] == 'a')
		sprintf (prop, "/ata@%x,0/cmdk@%x,0", hd[disk].hi, hd[disk].lo);
	      else
		sprintf (prop, "/disk@%x,0", hd[disk].hi * 2 + hd[disk].lo);
	      break;
	    case SDSK_TYPE_SD:
	      for (nextnode = prom_getchild(promfd, node); nextnode;
		   nextnode = prom_getsibling(promfd, nextnode))
		{
		  prop = prom_getproperty(promfd, "compatible", &len);
		  if (prop && len > 0 && !strcmp (prop, "sd"))
		    break;
		  prop = prom_getproperty(promfd, "name", &len);
		  if (prop && len > 0 && (!strcmp (prop, "sd") ||
					  !strcmp (prop, "disk")))
		    break;
		}
	      if (!nextnode || hd[disk].hi)
		continue;
	      if (promvers)
		{
		  char name[1024];
		  prop = prom_getproperty (promfd, "name", &len);
		  if (prop && len > 0)
		    strcpy (name, prop);
		  else
		    strcpy (name, "sd");
		  if (!prop)
		    prop = ((struct openpromio *)buf)->oprom_array;
		  sprintf (prop, "/%s@%x,%x", name, hd[disk].mid, hd[disk].lo);
		}
	      else
		{
		  int i;
		  for (i = 0; sd_targets[i]; i++)
		    if (sd_targets[i] == '0' + hd[disk].mid)
		      break;
		  if (!sd_targets[i])
		    i = hd[disk].mid;
		  sprintf (prop, "sd(%d,%d,", v0ctrl, i);
		}
	      break;
	    case SDSK_TYPE_PLN:
	      prop = ((struct openpromio *)buf)->oprom_array;
	      sprintf (prop, "/SUNW,pln@%x,%x/SUNW,ssd@%x,%x",
		       hd[disk].lo & 0xf0000000, hd[disk].lo & 0xffffff,
		       hd[disk].hi, hd[disk].mid);
	      break;
	    case SDSK_TYPE_FC:
	      prop = ((struct openpromio *)buf)->oprom_array;
	      sprintf (prop, "/sf@0,0/ssd@w%08x%08x,%x", hd[disk].hi, hd[disk].mid, hd[disk].lo);
	      break;
	    default:
	      continue;
	    }
	  hd[disk].prom_name = (char *)malloc (strlen (prom_path) + strlen(prop) + 3);
	  if (!hd[disk].prom_name)
	    continue;
	  if (promvers)
	    strcpy (hd[disk].prom_name, prom_path);
	  else
	    hd[disk].prom_name[0] = '\0';
	  strcat (hd[disk].prom_name, prop);
	}
    }
  v0ctrl++;
}

static int
scan_ide (int promfd)
{
  DIR * dir;
  char path[80];
  char buffer[512];
  int fd, i, disk;
  struct dirent * ent;
  int pci_bus, pci_devfn;

  if (access("/proc/ide", R_OK)) return 0;

  if (!(dir = opendir("/proc/ide")))
    return 1;

  while ((ent = readdir(dir)))
    {
      if (ent->d_name[0] == 'h' && ent->d_name[1] == 'd' &&
	  ent->d_name[2] >= 'a' && ent->d_name[2] <= 'z' &&
	  ent->d_name[3] == '\0') {
	disk = ent->d_name[2] - 'a';
	if (disk >= hdlen) {
	  hd = (struct sdsk_disk *)realloc(hd, ((disk&~3)+4)*sizeof(struct sdsk_disk));
	  memset (hd + hdlen, 0, ((disk&~3)+4-hdlen)*sizeof(struct sdsk_disk));
	  hdlen = (disk&~3)+4;
	}
	for (i = (disk & ~3); i <= (disk | 3); i++) {
	  if (hd[i].type)
	    break;
	}
	if (i > (disk | 3))
	  {
	    sprintf(path, "/proc/ide/%s", ent->d_name);
	    if (readlink(path, buffer, 512) < 5)
	      continue;
	    if (strncmp(buffer, "ide", 3) ||
		!isdigit(buffer[3]) ||
		buffer[4] != '/')
	      continue;
	    buffer[4] = 0;
	    sprintf(path, "/proc/ide/%s/config", buffer);
	    if ((fd = open(path, O_RDONLY)) < 0)
	      continue;
	    i = read(fd, buffer, 50);
	    close(fd);
	    if (i < 50) continue;
	    if (sscanf (buffer, "pci bus %x device %x ",
			&pci_bus, &pci_devfn) != 2)
	      continue;
	    hd[disk].prom_node = prom_pci2node (promfd, pci_bus,
						pci_devfn);
	  }
	else
	  hd[disk].prom_node = hd[i].prom_node;
	hd[disk].type = SDSK_TYPE_IDE;
	hd[disk].hi = (disk & 2) >> 1;
	hd[disk].lo = (disk & 1);
      }
    }

  closedir(dir);

  return 0;
}

static int
scan_scsi (int promfd)
{
    FILE *f;
    DIR * dir, *dirhba;
    struct dirent * ent, *enthba;
    struct stat st;
    char * p, * q;
    char buf[512];
    char path[128];
    int disk = 0;
    int host, channel, id, lun;
    int prom_node, pci_bus, pci_devfn, pci_device, pci_function;

    if (access("/proc/scsi/scsi", R_OK)) {
	return 0;
    }

    f = fopen("/proc/scsi/scsi", "r");
    if (f == NULL) return 1;

    if (fgets(buf, sizeof(buf), f) == NULL) {
	fclose(f);
	return 1;
    }
    if (!strcmp(buf, "Attached devices: none\n")) {
	fclose(f);
	return 0;
    }

    while (fgets(buf, sizeof(buf), f) != NULL) {
	if (sscanf(buf, "Host: scsi%d Channel: %d Id: %d Lun: %d\n",
		   &host, &channel, &id, &lun) != 4)
	    break;
	if (fgets(buf, sizeof(buf), f) == NULL)
	    break;
	if (strncmp(buf, "  Vendor:", 9))
	    break;
	if (fgets(buf, sizeof(buf), f) == NULL)
	    break;
	if (strncmp(buf, "  Type:   ", 10))
	    break;
	if (!strncmp(buf+10, "Direct-Access", 13)) {
	    if (disk >= sdlen) {
		hd = (struct sdsk_disk *)
		     realloc(hd, (hdlen+(disk&~3)+4)*sizeof(struct sdsk_disk));
		sd = hd + hdlen;
		memset (sd + sdlen, 0,
			((disk&~3)+4-sdlen)*sizeof(struct sdsk_disk));
		sdlen = (disk&~3)+4;
	    }
	    sd[disk].type = SDSK_TYPE_SD;
	    sd[disk].host = host;
	    sd[disk].hi = channel;
	    sd[disk].mid = id;
	    sd[disk].lo = lun;
	    disk++;
	}
    }
    fclose (f);

    if (!(dir = opendir("/proc/scsi"))) {
	if (!hdlen && hd) {
	    free(hd);
	    hd = NULL;
	}
	sd = NULL;
	sdlen = 0;
	return 1;
    }

    while ((ent = readdir(dir))) {
	if (!strcmp (ent->d_name, "scsi") || ent->d_name[0] == '.')
	    continue;
	sprintf (path, "/proc/scsi/%s", ent->d_name);
	if (stat (path, &st) < 0 || !S_ISDIR (st.st_mode))
	    continue;
	if (!(dirhba = opendir(path)))
	    continue;

	while ((enthba = readdir(dirhba))) {
	    if (enthba->d_name[0] == '.')
		continue;
	    host = atoi(enthba->d_name);
	    sprintf (path, "/proc/scsi/%s/%s", ent->d_name, enthba->d_name);
	    f = fopen (path, "r");
	    if (f == NULL) continue;

	    if (!strcmp (ent->d_name, "esp") ||
		!strcmp (ent->d_name, "qlogicpti") ||
		!strcmp (ent->d_name, "fcal"))
		p = "PROM node";
	    else if (!strcmp (ent->d_name, "pluto"))
		p = "serial ";
	    else
		p = "PCI bus";
	    while (fgets (buf, sizeof(buf), f) != NULL) {
		q = strstr (buf, p);
		if (q == NULL) continue;
		prom_node = 0;
		switch (p[1]) {
		case 'R':
		    if (sscanf (q, "PROM node %x", &prom_node) == 1)
			q = NULL;
		    break;
		case 'e':
		    if (sscanf (q, "serial 000000%x %*dx%*d on soc%*d port %x PROM node %x",
				&id, &lun, &prom_node) == 3 &&
			lun >= 10 && lun <= 11) {
			q = NULL;
		    }
		    break;
		case 'C':
		    if (sscanf (q, "PCI bus %i, device %i, function %i", &pci_bus, &pci_device, &pci_function) == 3) {
                        pci_devfn = pci_device * 8 + pci_function;
			q = NULL;
			prom_node = prom_pci2node (promfd, pci_bus, pci_devfn);
		    }
		    else
		      if (sscanf (q, "PCI bus %x device %x", &pci_bus, &pci_devfn) == 2) {
			q = NULL;
			prom_node = prom_pci2node (promfd, pci_bus, pci_devfn);
		      }
		    break;
		}
		if (q == NULL) {
		    for (disk = 0; disk < sdlen; disk++)
			if (sd[disk].host == host && sd[disk].type) {
			    sd[disk].prom_node = prom_node;
			    if (p[1] == 'e') {
				sd[disk].type = SDSK_TYPE_PLN;
				sd[disk].lo = (lun << 28) | id;
			    } else if (!strcmp (ent->d_name, "fcal"))
				sd[disk].type = SDSK_TYPE_FC;
			}
		}
	    }
	    if (!strcmp (ent->d_name, "fcal")) {
		while (fgets (buf, sizeof(buf), f) != NULL) {
		    unsigned long long ll;
		    if (sscanf (buf, " [AL-PA: %*x, Id: %d, Port WWN: %Lx, Node WWN: ", &id, &ll) == 2) {
			for (disk = 0; disk < sdlen; disk++)
			if (sd[disk].host == host && sd[disk].mid == id) {
			    sd[disk].hi = ll >> 32;
			    sd[disk].mid = ll;
			}
		    }
		}
	    }
	    fclose(f);
	}
	closedir(dirhba);
    }
    closedir(dir);
    return 0;
}

static int
get_prom_ver(int promfd)
{
    FILE *f = fopen ("/proc/cpuinfo","r");
    int ver = 0;
    char buffer[1024];
    char *p;

    if (f) {
	while (fgets (buffer, 1024, f)) {
	    if (!strncmp (buffer, "promlib", 7)) {
		p = strstr (buffer, "Version ");
		if (p) {
		    p += 8;
		    if (*p == '0' || (*p >= '2' && *p <= '3')) {
			ver = *p - '0';
		    }
		}
		break;
	    }
	}
	fclose(f);
    }
    if (!ver) {
	int len;
        p = prom_getopt(promfd, "sd-targets", &len);
        if (p && len > 0 && len <= 8)
	    strcpy(sd_targets, p);
    }
    return ver;
}

/**********************************************************************/
/*** Public functions *************************************************/
/**********************************************************************/

int
prom_init (int mode)
{
  struct utsname u;
  int promfd;

  promfd = open (promdev, mode);
  if (promfd == -1)
    return -1;
  prom_root_node = prom_getsibling (promfd, 0);
  if (!prom_root_node)
    return -1;

  if (!uname (&u) && !strcmp (u.machine, "sparc64"))
    p1275 = 1;

  return promfd;
}

int
check_aliases (int promfd)
{
  int nextnode, len;
  char *prop;
  int hasaliases = 0;

  for (nextnode = prom_getchild (promfd, prom_root_node); nextnode;
       nextnode = prom_getsibling (promfd, nextnode))
    {
      prop = prom_getproperty (promfd, "name", &len);
      if (prop && len > 0 && !strcmp (prop, "aliases"))
	hasaliases = 1;
    }
  return hasaliases;
}

char *
disk2PromPath (char *disk)
{
  static char prompath[1024];
  int diskno = -1, part;

  if (disk[0] == 'h' && disk[1] == 'd' && disk[2] >= 'a' && disk[2] <= 'z')
    {
      diskno = disk[2] - 'a';
      disk += 3;
    }
  else
    if (disk[0] == 's' && disk[1] == 'd' && disk[2] >= 'a' && disk[2] <= 'z')
      {
	if (disk[3] >= 'a' && disk[3] <= 'z')
	  {
	    diskno = (disk[2] - 'a' + 1) * 26 + (disk[3] - 'a');
	    disk += 4;
	  }
	else
	  {
	    diskno = disk[2] - 'a';
	    disk += 3;
	  }
	if (diskno >= 128)
	  diskno = -1;
	else
	  diskno += hdlen;
      }
  if (diskno == -1)
    part = -1;
  else if (!disk[0])
    part = 3;
  else
    {
      part = atoi (disk);
      if (part <= 0 || part > 8) part = -1;
    }
  if (diskno < 0 || part == -1 ||
      diskno >= hdlen + sdlen || !hd[diskno].prom_name)
    {
      return "error occured!";
    }
  if (!promvers)
    sprintf (prompath, "%s%d)", hd[diskno].prom_name, part ? part - 1 : 2);
  else {
    if (part)
      sprintf (prompath, "%s:%c", hd[diskno].prom_name, part + 'a' - 1);
    else
      strcpy (prompath, hd[diskno].prom_name);
  }
  return prompath;
}

void
init_scan_disks (int promfd)
{
  promvers = get_prom_ver(promfd);
  scan_ide(promfd);
  scan_scsi(promfd);
  prom_walk_callback = scan_walk_callback;
  prom_walk(promfd, prom_path, prom_root_node,
	    prom_getchild (promfd, prom_root_node), 0);
}
