#!/bin/bash
# make_interval_timer_video
#
# MIT License
# 
# Copyright (c) 2018 Fufu Fang
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

############################ USER CONFIGURATIONS ###############################
# The length of the introduction slide
INTRO_LEN=10
# The resolution of the final video
RESOLUTION=1280x720
# The framerate of the final video
FRAMERATE=30

###################### ADVANCED USER CONFIGURATIONS ############################
# The size of the text for the instruction of the current segment
TITLE_SIZE=11
# The size for the text for the total duration of the current segment
DURATION_SIZE=11
# The size of the text for the elapsed time of the current segment
TIMECODE_SIZE=11
# The size of the text for the instruction of the next segment
NEXT_SIZE=7
# The maximum size of the font in the introduction slide
INTRO_SIZE_MAX=7
# The minimum size of the font in the introduction slide
INTRO_SIZE_MIN=3
# ffmpeg's h264 encoding preset, controls the speed of video encoding
PRESET=slow

########################## Input argument checks ###############################
if [ "$#" -ne 2 ]; then
    echo "make_interval_timer_video , convert a set of interval timings to a \
video"
    echo "Usage: $0 input.txt output.mp4"
    exit 1
fi

# Assign filenames based on input parameters
IN_NAME=${1}
OUT_NAME=${2}

########################### Clean up functions #################################
# Create temporary directory
TMPDIR=$(mktemp -d)

# Clean up function
function cleanup {
    rm -rf ${TMPDIR}
}

# Trap SIGINT and SIGTERM to clean up temporary files
trap 'cleanup; exit' INT TERM

############################# Global constants #################################
# Extracting width and height
VW=$(echo ${RESOLUTION} | cut -d 'x' -f 1)
VH=$(echo ${RESOLUTION} | cut -d 'x' -f 2)

# Recalculate various sizes
let TITLE_SIZE=${VH}*${TITLE_SIZE}/100
let DURATION_SIZE=${VH}*${DURATION_SIZE}/100
let TIMECODE_SIZE=${VH}*${TIMECODE_SIZE}/100
let NEXT_SIZE=${VH}*${NEXT_SIZE}/100
let INTRO_SIZE_MAX=${VH}*${INTRO_SIZE_MAX}/100
let INTRO_SIZE_MIN=${VH}*${INTRO_SIZE_MIN}/100

# Map the input text file into an array
mapfile -t SET_LIST < ${IN_NAME}

# The file number COUNTER
let COUNTER=0

# The length of the set
let SET_LEN=${#SET_LIST[@]}-1

################################# Functions ####################################
# Generate the introduction slide
function introduction {
    filename="${TMPDIR}/seg-${COUNTER}.mp4"
    font_size=${1}

    echo "${INTRO_LEN}s Introduction Slide"
    ffmpeg -f lavfi -i color=c=white:size=${RESOLUTION}:rate=${FRAMERATE} \
    -vf "drawtext=textfile=${IN_NAME}: fontsize=${font_size}: \
    x=(w-tw)/2: y=h-h*0.95: fontcolor=Black:" -t ${INTRO_LEN} \
    -preset ${PRESET} -tune stillimage -y -loglevel warning \
    -stats ${filename}
    echo "file ${filename}" >> ${TMPDIR}/filelist.txt
    let COUNTER++
}

# Generate a video segment
# Calling convention: min, sec, text_now, text_next
function videoSegment {
    filename="${TMPDIR}/seg-${COUNTER}.mp4"
    let duration=${1}*60+${2}
    min=${1}
    sec=${2}
    textNow=${3}
    textNext=${4}

    ffmpeg -f lavfi -i color=c=white:size=${RESOLUTION}:rate=${FRAMERATE} \
    -vf "drawtext=text='${textNow}': fontsize=${TITLE_SIZE}: \
    x=(w-tw)*0.5: y=h-h*0.80: fontcolor=Black:, \
    \
    drawtext=text='Duration: ${min} min ${sec} sec': \
    fontsize=${DURATION_SIZE}: x=(w-tw)*0.5: \
    y=h-h*0.60: fontcolor=Black:, \
    \
    drawtext=timecode='00\:00\:00\:00': fontsize=${TIMECODE_SIZE}: \
    r=${FRAMERATE}: x=(w-tw)*0.5: y=h-h*0.40: fontcolor=Black:, \
    \
    drawtext=text='${textNext}': fontsize=${NEXT_SIZE}: \
    x=(w-tw)*0.5: y=h-h*0.20: fontcolor=SlateGray:" \
    \
    -t ${duration} -preset ${PRESET} -tune stillimage -y -loglevel warning \
    -stats ${filename}
    echo "file ${filename}" >> ${TMPDIR}/filelist.txt
    let COUNTER++
}

# Process the set array, and call the video segment generator
# Calling convention: segment_id
function setSegment {
    thisLine=${SET_LIST[${1}]}
    timing=$(echo $thisLine|cut -d ' ' -f 1)
    min=$(echo $timing|cut -d ':' -f 1)
    sec=$(echo $timing|cut -d ':' -f 2)
    textNow=$(echo $thisLine|cut -d ' ' -f 2-)

    let nextSeg=${1}+1
    if [ ${nextSeg} -le ${SET_LEN} ]; then
        nextLineP1=$(echo ${SET_LIST[${nextSeg}]}|cut -d ' ' -f 1|tr ':' 'm')
        nextLineP2=$(echo ${SET_LIST[${nextSeg}]}|cut -d ' ' -f 2-)
        nextLine="Next - ${nextLineP1}s ${nextLineP2}"
    else
        nextLine="Next - We are done! 😠"
    fi

    echo "Generating segment: ${thisLine} ..."

    videoSegment $min $sec "${textNow}" "${nextLine}"
}

# Concatenate all video segments together
function output {
    echo "Concatenating all video segments..."
    ffmpeg -f concat -safe 0 -i $TMPDIR/filelist.txt -c copy \
    -loglevel warning -stats -y ${OUT_NAME}
}

function checkTotalTime {
    let totalMin=0
    let totalSec=0
    for i in $(seq 0 ${SET_LEN}); do
        thisLine=${SET_LIST[${i}]}
        thisTiming=$(echo $thisLine|cut -d ' ' -f 1)
        let totalMin=${totalMin}+$(echo $thisTiming|cut -d ':' -f 1)
        let totalSec=${totalSec}+$(echo $thisTiming|cut -d ':' -f 2)
    done
    let totalSec=${totalSec}+${INTRO_LEN}
    let secToMin=${totalSec}/60
    let totalMin=${totalMin}+${secToMin}
    let totalSec=${totalSec}-${secToMin}*60

    echo "Total run time: ${totalMin} min ${totalSec} sec"
    read -p "Press enter to continue, or Ctrl+C to cancel..."
}

############################# The main program #################################
if [ ${SET_LEN} -eq 0 ]; then
    echo "${IN_NAME} is an invalid file, is it empty?"
    cleanup
    exit 1
else
    let INTRO_SIZE=${VH}/${SET_LEN}*95/100
fi

# Check the total run time before continuing
checkTotalTime

# If the font size is greater than the maximum font size, clamp it to maximum.
if [ ${INTRO_SIZE} -gt ${INTRO_SIZE_MAX} ]; then
    introduction ${INTRO_SIZE_MAX}
# Only produce introduction slide if the font size is bigger than minimum.
elif [ ${INTRO_SIZE} -gt ${INTRO_SIZE_MIN} ]; then
    introduction ${INTRO_SIZE}
fi

for i in $(seq 0 ${SET_LEN}); do
    setSegment ${i}
done

output

cleanup
