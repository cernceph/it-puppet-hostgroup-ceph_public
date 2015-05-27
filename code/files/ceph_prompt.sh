IPALIAS=`facter -p landb_ip_aliases | tr '[:upper:]' '[:lower:]' | tr ',' '\n' | egrep -v '^ca|cd|--load'`
[  -z "$IPALIAS" ] && IPALIAS=`hostname -s`
HOSTGROUP=`facter -p hostgroup | cut -d_ -f2`
FOREMAN_ENV=`grep environment /etc/motd | awk '{print $4}'`
if [ "$PS1" ]; then
  PS1="[\$(date +%H:%M)][\u@${IPALIAS} (${FOREMAN_ENV}:\e[0;33m${HOSTGROUP}\e[0m*\$(ps -ef | grep /usr/bin/ceph- | grep -v grep | wc -l)) \W]\\$ "
fi
