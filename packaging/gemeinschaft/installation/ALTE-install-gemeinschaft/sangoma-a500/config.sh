#! /bin/sh

err()
{
        echo '' >&2
        echo -n '***** Error!' >&2
        [ ! -z "$ERRMSG" ] && echo -n " $ERRMSG" >&2
        echo -e "\n" >&2
        exit 1
}

trap "(echo ''; echo '***** Aborted!') >&2; exit 130" SIGINT SIGTERM SIGQUIT SIGHUP
trap "err; exit 1" ERR

CUR_PATH=`pwd`

_temp="/tmp/answer.$$"

# get Port count
PORTS=$(wanrouter hwprobe | grep AFT-A500 | wc -l >&1)
COUNTER=0
while [ $COUNTER -lt $PORTS  ]; do
        let SHOW_PORT=COUNTER+1
        dialog --backtitle "Point to Point/Multipoint Configuration" --title "Please Choose for Port $SHOW_PORT" --no-cancel \
                --menu "Move using [UP] [DOWN], [Enter] to select" 17 60 10 \
                0 "Point to multipoint" \
                1 "Point to point" \
                2>$_temp

        menuitem=`cat $_temp`

        #ptp=$ptp" "$menuitem
        ptp="$ptp $menuitem"
        let COUNTER=COUNTER+1
done

cd $CUR_PATH
./setup.expect $ptp
