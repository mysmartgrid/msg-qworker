#! /bin/sh
# Author: Foo Bar <kai.krueger@itwm.fraunhofer.de>
#

args=$*
pidfile=/var/run/qworker.pid

#

# Do NOT "set -e"

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="MySmartGrid Worker"
NAME=qworker.rb
DAEMON=/usr/local/lib/msg-qworker/bin/$NAME
DAEMON_ARGS="-c /usr/local/lib/msg-qworker/etc/qworkerrc"
DAEMON_LOG_FILE=/var/log/$NAME.log
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

${DAEMON} ${args} &
PID=$!
echo ${PID} > ${pidfile}
