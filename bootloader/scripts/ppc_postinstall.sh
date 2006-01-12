#!/bin/bash
#
#  PPC YaST2 postinstall script
#


while read line; do
    case "$line" in
      *MacRISC*)    MACHINE="mac";;
      *CHRP*)       MACHINE="chrp";;
      *PReP*)       MACHINE="prep" ;;
      *iSeries*)    MACHINE="iseries";;
    esac
done < /proc/cpuinfo

if [ "$MACHINE" = iseries ] ; then
    for i in `fdisk -l | sed -e '/^\/.*PReP/s/[[:blank:]].*$//p;d'`
      do
	  j=`echo $i | sed 's/\([0-9]\)/ \1/'`
	  /sbin/activate $j
    done

    sed '/^.*mingetty.*$/d' /etc/inittab > /etc/inittab.tmp
    diff /etc/inittab /etc/inittab.tmp &>/dev/null || mv -v /etc/inittab.tmp /etc/inittab
    rm -f /etc/inittab.tmp
    
    #echo "1:12345:respawn:/bin/login console" >> /etc/inittab
    cat >> /etc/inittab <<-EOF


# iSeries virtual console:
1:2345:respawn:/sbin/agetty -L 38400 console

# to allow only root to log in on the console, use this:
# 1:2345:respawn:/sbin/sulogin /dev/console

# to disable authentication on the console, use this:
# y:2345:respawn:/bin/bash

EOF

    echo console >> /etc/securetty

    if grep -q tty10 /etc/syslog.conf; then
	echo "changing syslog.conf"
	sed '/.*tty10.*/d; /.*xconsole.*/d' /etc/syslog.conf > /etc/syslog.conf.tmp
	diff /etc/syslog.conf /etc/syslog.conf.tmp &>/dev/null || mv -v /etc/syslog.conf.tmp /etc/syslog.conf
	rm -f /etc/syslog.conf.tmp
    fi

    {
	echo "SuSE Linux on iSeries -- the spicy solution!"
	echo "Have a lot of fun..."
    } > /etc/motd
fi # iseries


# Regatta systems might have a HMC console (hvc)
if [[ $(</proc/cmdline) = *console=hvc* ]]; then
    
    sed '/^.*mingetty.*$/d' /etc/inittab > /etc/inittab.tmp
    diff /etc/inittab /etc/inittab.tmp &>/dev/null || mv -v /etc/inittab.tmp /etc/inittab
    
    cat >> /etc/inittab <<-EOF
    
    
# Regatta systems virtual console:
#V0:12345:respawn:/sbin/agetty -L 9600 hvc0 vt320

# to allow only root to log in on the console, use this:
# 1:2345:respawn:/sbin/sulogin /dev/console

# to disable authentication on the console, use this:
# y:2345:respawn:/bin/bash

EOF
    echo "hvc0" >> /etc/securetty
    echo "hvc/0" >> /etc/securetty

fi
# p690


#
# Local variables:
#     mode: ksh
#     ksh-indent: 4
#     ksh-multiline-offset: 2
#     ksh-if-re: "\\s *\\b\\(if\\)\\b[^=]"
# End:
#
