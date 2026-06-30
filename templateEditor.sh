#!/bin/bash
set -euo pipefail
IFS=$'\n\t'



#Requires arguements
#$1 path to file
#$2 New URL
#$3 New Wait time
#$4 optional name of output template
#$5 optinal path to output loging location

#Example usage
#                    path to template               url                                         waitime output name     locations where stats should be stored
#./templateEditor.sh prudentiaPrompts/TEMPLATE.json https://www.youtube.com/watch?v=Exu1SEZE9Ug 100 youtube-test.json /opt/gerbil.jsonl

echo Path to template file is $1





if [[ ! -f "$1" ]]; then
    echo "The filepath you provided was invalid"
    exit 1
fi


if [[ ! -v 4  ]]; then
    echo "No optional name of output template arguement is selected the file is being edited and the output will have the same name with the addition of -filled"
    cp $1 "${1%.*}-filled.json"
    TEMP="${1%.*}-filled.json"
    FILENAME="${TEMP##*/}"
    cd $(dirname "$1")/
else
    cd $(dirname "$1")/
    echo "Output new file in the same dirrectory as the old one name ${4}"
    cp "${1##*/}" $4
    FILENAME=$4
fi


#Figure out how to handel special charecters in sed
echo here
sed -i "s|URL|${2}|g" $FILENAME
echo "Succusfully replaced URL with ${2@Q} in ${FILENAME}"

echo now here
sed -i "s|WAITTIME|${3}|g" $FILENAME
echo "Succusfully replaced WAITTIME with ${3} in ${FILENAME}"
echo "We expect the full workflow to run for $((${3}+20)) seconds spending ${3} seconds watching the vidio"

# Enable case-insensitive matching
shopt -s nocasematch
if [[ "$FILENAME" == *"YOUTUBE"* ]]; then
    if [[ -v 5  ]]; then
        sed -i "s|/capture/stats/youtube_stats.jsonl|${5}|g" $FILENAME
        echo "Stats log will be placed in ${5}"
    fi
elif [[ "$FILENAME" == *"VIMIO"* ]]; then
    if [[ -v 5  ]]; then
        sed -i "s|/capture/stats/vimio_stats.jsonl|${5}|g" $FILENAME
        echo "Stats log will be placed in ${5}"
    fi
fi
# Disable case-insensitive matching to restore default behavior
shopt -u nocasematch