#!/bin/bash
# set -o xtrace

COMMAND_INPUT_STREAM_PATH="${1}"
COMMAND_OUTPUT_STREAM_PATH="${2}"
COMMAND_ERR_STREAM_PATH="${3}"
COMMAND_EXIT_STREAM_PATH="${4}"
COMMAND_CLOSE_STREAM_PATH="${5}"

REQUEST="${@:6}"

# echo "Will execute command $REQUEST" >&2

# This is the magic where we redirect all the mkfifo streams; it should be in a separate command
exec 5> "$COMMAND_OUTPUT_STREAM_PATH" # Open output stream
exec 6> "$COMMAND_ERR_STREAM_PATH" # Open error stream
exec 7< "$COMMAND_INPUT_STREAM_PATH" # Open input stream
exec 8> "$COMMAND_EXIT_STREAM_PATH" # Maybe not needed, can just write once probably
# We don't open 9 because nothing will be ready to write to it on the client script's side

# echo "I will execute command $REQUEST >&5 2>&6 <&7 FROM $COMMAND_INPUT_STREAM_PATH"

$REQUEST >&5 2>&6 <&7
EXIT_CODE=$?

# echo "Will emit exit code $EXIT_CODE" >&2
echo "$EXIT_CODE" >&8

# NOTE: We keep all of this open until the other script tells us we can clean things up.

read -r FINISH_CONFIRMATION < $COMMAND_CLOSE_STREAM_PATH

# echo "Confirmed: $FINISH_CONFIRMATION.  Cleaning up streams" >&2
exec 5>&- 6>&- 7>&- 8>&-

# echo "Removing paths" >&2
rm $COMMAND_INPUT_STREAM_PATH
rm $COMMAND_OUTPUT_STREAM_PATH
rm $COMMAND_ERR_STREAM_PATH
rm $COMMAND_EXIT_STREAM_PATH
rm $COMMAND_CLOSE_STREAM_PATH
rmdir `dirname $COMMAND_INPUT_STREAM_PATH`

exit 0
