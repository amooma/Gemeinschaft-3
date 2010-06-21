#! /bin/sh

WORK_DIR="/tmp/";
DEST_DIR="$WORK_DIR/gemeinschaft/";
CSV_FILE="$WORK_DIR/gemeinschaft_sounds.csv";

# remove old voice directory
rm -r "$DEST_DIR"

# create voice directory
mkdir "$DEST_DIR"

# cd to svox directory
cd /usr/local/svox/delivery/notermout 

# generate voice prompts using svox
nice -19 $WORK_DIR/gen_prompts.php -w"$DEST_DIR"  -f"$CSV_FILE" -g"./svox {INFILE} {OUTFILE}"  -l"de"


