#!/usr/bin/env bash
set -e

if [ "$1" == 'supervisord' ]; then

    # Increase the maximum watches for inotify for very large repositories to be watched
    # Needs the privilegied docker option
    [ ! -z $MAX_INOTIFY_WATCHES ] && echo fs.inotify.max_user_watches=$MAX_INOTIFY_WATCHES | tee -a /etc/sysctl.conf && sysctl -p || true

    [ -z $UNISON_DIR ] && export UNISON_DIR="/data"

    [ ! -d $UNISON_DIR ] && mkdir -p $UNISON_DIR

    # if the user did not set anything particular to use, we use root
    # since this means, no special user has been created on the target container
    # thus it is most probably root to run the daemon and thats a good default then
    if [ -z $UNISON_OWNER_UID ];then
       UNISON_OWNER_UID=0
    fi

    # if the user with the uid does not exist, create him, otherwise reuse him
    if ! cut -d: -f3 /etc/passwd | grep -q $UNISON_OWNER_UID; then
        echo "no user has uid $UNISON_OWNER_UID"

        # If user doesn't exist on the system
        if ! cut -d: -f1 /etc/passwd | grep -q $UNISON_OWNER; then
            useradd -u $UNISON_OWNER_UID dockersync -m
        else
            usermod -u $UNISON_OWNER_UID dockersync
        fi
    else
        if [ $UNISON_OWNER_UID == 0 ]; then
            # in case it is root, we need a special treatment
            echo "user with uid $UNISON_OWNER_UID already exist and its root"
        else
            # we actually rename the user to unison, since we do not care about
            # the username on the sync container, it will be matched to whatever the target container uses for this uid
            # on the target container anyway, no matter how our user is name here
            echo "user with uid $UNISON_OWNER_UID already exist"
            existing_user_with_uid=$(awk -F: "/:$UNISON_OWNER_UID:/{print \$1}" /etc/passwd)
            mkdir -p /home/dockersync
            usermod --home /home/dockersync --login dockersync $existing_user_with_uid
            chown -R unison /home/dockersync
         fi

    fi
    export UNISON_OWNER_HOMEDIR=`getent passwd $UNISON_OWNER_UID | cut -f6 -d:`
    export UNISON_OWNER=`getent passwd "$UNISON_OWNER_UID" | cut -d: -f1`

    chown -R $UNISON_OWNER_UID $UNISON_DIR

    # see https://wiki.alpinelinux.org/wiki/Setting_the_timezone
    if [ -n ${TZ} ] && [ -f /usr/share/zoneinfo/${TZ} ]; then
        ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
        echo ${TZ} > /etc/timezone
    fi

    # Check if a script is available in /docker-entrypoint.d and source it
    for f in /docker-entrypoint.d/*; do
        case "$f" in
            *.sh)     echo "$0: running $f"; . "$f" ;;
            *)        echo "$0: ignoring $f" ;;
        esac
    done
fi

exec "$@"
