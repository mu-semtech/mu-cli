#!/bin/env bash
# set -o xtrace

# Basic setup
SOCKET_FOLDER="/tmp/mu-docker-host-socket-dir"
SOCKET_IN="$SOCKET_FOLDER/in"
SOCKET_OUT="$SOCKET_FOLDER/out"

exec 10> "$SOCKET_IN"
exec 11< "$SOCKET_OUT"

# Send the command
echo "$@" >&10
read -u 11 COMMAND_OK

if [ "$COMMAND_OK" != "OK" ]
then
    echo "ERROR: Not allowed to execute command" >&2
    exit 254
else
    # Read the relevant sockets
    read -u 11 COMMAND_OUTPUT_STREAM_PATH
    #echo "Read socket COMMAND_OUTPUT_STREAM_PATH $COMMAND_OUTPUT_STREAM_PATH" >&2
    read -u 11 COMMAND_ERR_STREAM_PATH
    #echo "Read socket COMMAND_ERR_STREAM_PATH $COMMAND_ERR_STREAM_PATH" >&2
    read -u 11 COMMAND_INPUT_STREAM_PATH
    #echo "Read socket COMMAND_INPUT_STREAM_PATH $COMMAND_INPUT_STREAM_PATH" >&2
    read -u 11 COMMAND_EXIT_STREAM_PATH
    #echo "Read socket $COMMAND_EXIT_STREAM_PATH" >&2
    read -u 11 COMMAND_CLOSE_STREAM_PATH

    # Close the streams we don't need anymore
    exec 10>&-
    exec 11>&-

    # NOTE: trapping would likely be good but we did not test so we're clearing this for now
    # trap 'exec 5>&- 6>&- 7>&- 8>&- 2>/dev/null | true' EXIT INT TERM

    # Wire up our command
    cat <$COMMAND_OUTPUT_STREAM_PATH &   # stdout
    cat <$COMMAND_ERR_STREAM_PATH >&2 &  # stderr
    cat >$COMMAND_INPUT_STREAM_PATH &    # stdin

    #echo "Will read EXIT CODE" >&2

    read -t 30 EXIT_CODE <$COMMAND_EXIT_STREAM_PATH # TODO: don't think we need -t 30

    echo "DONE" >$COMMAND_CLOSE_STREAM_PATH

    exit "$((EXIT_CODE))"
fi
