#!/bin/bash

# Rødecaster Pro Extraction Tool
# This script assumes all recording files for a podcast episode to be in the same directory as the script
# It then extracts all 14 single channels from the wav file and concatenates them
# Regardless of how many (split) recording wav files you have it will always produce 14 flac files
# sox must be available on the system http://sox.sourceforge.net

# Rødecaster Pro channel config
# adjust this if you have a different channel setup for your polywav files
channelIds=("skip" "01_main_l" "02_main_r" "03_mic_1" "04_mic_2" "05_mic_3" "06_mic_4" "07_usb_l" "08_usb_r" "09_trrs_l" "10_trrs_r" "11_bluetooth_l" "12_bluetooth_r" "13_soundboard_l" "14_soundboard_r")
# if you wish to merge takes set this to
mergeTakes=true
# if you wish to delete the intermediary channel files after concatenating
removeIntermediaryChannelFiles=true

# function to extract a single channel using sox
function extractChannel() {
  filename=$1
  identifier=$2
  channel=$3

  filename_without_ext=`echo "${filename}"|sed "s/\(.*\)\.\(.*\)/\1/"`
  new_filename="${identifier}_${filename_without_ext}.flac"

  echo "extracting channel ${channel} from ${filename} to ${new_filename}"

  sox $filename $new_filename remix $channel
}

# function to concat multiple files using sox
function concatTakes() {
  channelId=$1
  channelFiles=(${channelId}*.flac)
  mergedFile="${channelId}.flac"

  echo "concatenating files ${channelFiles[@]} to $mergedFile"

  sox ${channelFiles[@]} $mergedFile

  # remove the intermediary files if configured
  if [ "$removeIntermediaryChannelFiles" = true ]; then
    echo "removing intermediary channel files"
    rm ${channelFiles[@]}
  fi
}

# let's go
echo "*** Extracting channels from polywav files ***"
echo "finding wav files"

# create an array with all the wav files inside the current directory
# expects all upper case filenames
wavFiles=(*.WAV)

echo "extracting channels"
# iterate through WAV files
for i in ${!wavFiles[*]}; do
  for j in ${!channelIds[@]};
  do
  # skip the array value with index 0
    if [[ "$j" == '0' ]]; then
        continue
    fi
    # extract each channel from the WAV file
    extractChannel ${wavFiles[i]} ${channelIds[$j]} $j
  done
done

if [ "$mergeTakes" = true ]; then
  echo "merging takes"
  # iterate through channels to merge takes
  for k in ${!channelIds[@]};
  do
    # skip the array value with index 0
    if [[ "$k" == '0' ]]; then
        continue
    fi
    # merge all takes into a single file
    concatTakes ${channelIds[$k]}
  done
fi
