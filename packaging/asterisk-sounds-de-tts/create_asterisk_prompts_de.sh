#! /bin/sh

WORK_DIR="/tmp/";
DEST_DIR="$WORK_DIR/asterisk/";
CSV_FILE="$WORK_DIR/asterisk_core_sounds.csv";

# remove old voice directory
rm -r "$DEST_DIR"

# create voice directory
mkdir "$DEST_DIR"

# cd to svox directory
cd /usr/local/svox/delivery/notermout 

# generate voice prompts using svox
#nice -19 $WORK_DIR/gen_prompts.php -w"$DEST_DIR"  -f"$CSV_FILE" -g"./svox {INFILE} {OUTFILE}"  -l"de"

#generate prompts an convert to "gsm"
nice -19 /home/spag/voicegen/gen_prompts.php -w"$DEST_DIR"  -f"/home/spag/voicegen/asterisk_core_sounds.csv" -g"./svox {INFILE} $DEST_DIR/temp.wav &&  sox $DEST_DIR/temp.wav -r 8000 -c 1 {OUTFILE} resample -ql" -l"de" -s".gsm" -v

rm $DEST_DIR/temp.wav

# create archive
tar -czf $WORK_DIR/asterisk-core-sounds-de-gsm.tar.gz -C $DEST_DIR de


