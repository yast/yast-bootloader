
#ifndef __PROM_H__
#define __PROM_H__

int prom_init (int mode);
char *prom_getopt (int promfd, char *var, int *lenp);
void prom_setopt (int promfd, const char *var, const char *value);
int check_aliases (int promfd);
char * disk2PromPath (char *disk);
void init_scan_disks (int promfd);

#endif
