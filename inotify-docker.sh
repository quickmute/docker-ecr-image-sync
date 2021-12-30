#!/bin/sh
# get Docker Root Director
DOCKERROOT=`docker info | grep 'Docker Root Dir' | awk -F ": " '{print $2}'`
# Append the image SHA256 to the above path, this is where the new images go
IMAGEMETADATA="$DOCKERROOT/image/overlay2"
# create a notify event on this dir, specifically we are watching repositories.json file
inotifywait -m -e moved_to $IMAGEMETADATA \
| while read FILENAME
        do
                /home/ubuntu/update_ecr.sh
        done
