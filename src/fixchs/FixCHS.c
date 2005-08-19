#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <err.h>

unsigned char buf[512];
#define PARTTAB_OFFSET 446

/* The BIOS' idea of the disk geometry */
int cylinders, heads, sectors;

/* -------------------- from fdisk.c --------------------*/
#define sector(s)       ((s) & 0x3f)
#define cylinder(s, c)  ((c) | (((s) & 0xc0) << 2))
#define hsc2sector(h,s,c) (sector(s) - 1 + sectors * \
                                ((h) + heads * cylinder(s,c)))
#define set_hsc(h,s,c,sector) { \
                                s = sector % sectors + 1;       \
                                sector /= sectors;      \
                                h = sector % heads;     \
                                sector /= heads;        \
                                c = sector & 0xff;      \
                                s |= (sector >> 2) & 0xc0;      \
                        }
/* -------------------- from fdisk.c --------------------*/

typedef struct
{
  unsigned char h;
  unsigned char s;
  unsigned char c;
}
  chs_bytes __attribute__((packed));


typedef struct
{
  unsigned char flags;
  chs_bytes start_chs;
  unsigned char sysId;
  chs_bytes end_chs;
  /* XXX assumes wrong-endian native && sizeof(int)==4 */
  unsigned int lstart;
  unsigned int lsize;
}
  part_entry __attribute__((packed));

int read_ascii(char * fname)
{
  FILE * F;
  int ret = 0;

  if ((F = fopen(fname, "r")) == 0)
    return 0;

  if (fscanf(F, "%d", &ret) < 1)
    ret = 0;
  
  fclose(F);
  return ret;
}

int
check_part(int n, int do_fix)
{
  int c, h, s;
  unsigned LBA;
  
  
  part_entry * parttab = (part_entry *)(buf+PARTTAB_OFFSET);
  n--;

  if(parttab[n].lstart / (heads*sectors) > 1023) /* out of range anyways */
    return 0;
  if(parttab[n].sysId == 0)     /* unused partition */
    return 0;

  LBA = parttab[n].lstart;
  
  set_hsc(h,s,c,LBA);
  
  if (c != parttab[n].start_chs.c ||
      h != parttab[n].start_chs.h ||
      s != parttab[n].start_chs.s)
    {
      printf("Partition %d mismatch\n", n+1);
      printf("[ %02x %02x %02x ] ",
             parttab[n].start_chs.h,
             parttab[n].start_chs.s,
             parttab[n].start_chs.c);
      printf("[ %02x %02x %02x ] ", h, s, c);
      if (do_fix)
        {
          parttab[n].start_chs.c = c;
          parttab[n].start_chs.h = h;
          parttab[n].start_chs.s = s;
          printf("(Fixed)\n");
          return 1;
        }
      putchar('\n');
    }
  return 0;
}

int
main(int argc, char ** argv)
{
  
  if (chdir("/sys/firmware/edd/int13_dev80") != 0)
    err(1, "edd module loaded?\n chdir to /sys/firmware/edd/int13_dev80");

  cylinders = read_ascii("legacy_max_cylinder");
  heads     = read_ascii("legacy_max_head");
  sectors   = read_ascii("legacy_sectors_per_track");
  heads++;

  if (cylinders*heads*sectors == 0)
    errx(1, "cannot determine BIOS geometry");

  //  printf("%d/%d/%d\n", c, h, s);
  
  chdir("/dev");
  if (argc > 1)
    {
      int fd, i;
      
      fd = open(argv[1], O_RDWR, 0);
      if (fd < 0)
        err(1, "Cannot open %s", argv[1]);

      if (read(fd, buf, 512) < 512)
        err(1, "Read from %s", argv[1]);

      if (lseek(fd, 0, SEEK_SET) != 0)
        err(1, "%s not seekable", argv[1]);

      if (argc > 2)
        {
          int partno;
          
          partno = atoi(argv[2]);
          if (partno < 1 || partno > 4)
            errx(1, "Usage: %s <device> [primary_partition_number]", argv[0] );
          if (check_part(partno, 1) > 0)
            {
              write(fd, buf, 512);
            }
        }
      else
        for (i=1; i<=4; i++)
          check_part(i, 0);
    }

  return 0;
}

