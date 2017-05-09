#!/bin/sh

APP_VOLUME=${APP_VOLUME:-/app_sync}
HOST_VOLUME=${HOST_VOLUME:-/host_sync}
OWNER_UID=${OWNER_UID:-0}

if [ ! -f /unison/initial_sync_finished ]; then
	echo "doing initial sync with cp"
	time cp -au  $HOST_VOLUME/.  $APP_VOLUME
	echo "chown ing file to uid $OWNER_UID"
	chown -R $OWNER_UID $APP_VOLUME
	touch /unison/initial_sync_finished
	echo "initial sync done using cp" >> /tmp/unison.log
else
	echo "skipping initial cp"
fi
