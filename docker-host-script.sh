#!/usr/bin/env bash
mkdir -p /tmp/mu-host
SOCKET_TMPDIR=$(mktemp -d -p /tmp/mu-host/) # this temp folder should then get mounted into the docker container
rm -Rf /tmp/mu-docker-host-socket-dir
ln -s $SOCKET_TMPDIR /tmp/mu-docker-host-socket-dir

# Create the fifo input stream
#
# This stream will be used for requesting commands.  Each command execution gets
# their own sockets
REQUEST_SOCKET_PATH="$SOCKET_TMPDIR/in"
ANSWER_SOCKET_PATH="$SOCKET_TMPDIR/out"
mkfifo $REQUEST_SOCKET_PATH
mkfifo $ANSWER_SOCKET_PATH
exec 10< "$REQUEST_SOCKET_PATH" # keep the answer socket open
exec 11> "$ANSWER_SOCKET_PATH" # keep request socket open
exec 12> "$REQUEST_SOCKET_PATH" # does this keep the socket open when client closes?

function read_allowed_regexes() {
    ALLOWED_COMMAND_COMBINATIONS=""

    while IFS= read -r line; do
        [ "$line" = ":END:" ] && break
        ALLOWED_COMMAND_COMBINATIONS+=("$line")
    done
}

ALLOWED_COMMAND_COMBINATIONS=""
# echo -e "Allowed command combinations\n$ALLOWED_COMMAND_COMBINATIONS" >&2
read_allowed_regexes

# Not called, but should be implemented to ensure the command may be executed on
# the host system
function validate() {
    local command="$1"
    local regex

    # printf "\nallowed combinations:\n%s" "${ALLOWED_COMMAND_COMBINATIONS[@]}"

    for regex in "${ALLOWED_COMMAND_COMBINATIONS[@]}"
    do
        if [[ "$regex" != "" ]]
        then
            # printf "\nComparing %s to %s\n" "$command" $regex >&2
            [[ "$command" =~ $regex ]] && return 0
        fi
    done
    return 1
}

# echo "REQUEST $REQUEST_SOCKET_PATH" >&2
# echo "ANSWER $ANSWER_SOCKET_PATH" >&2

while true
do
    read -u 10 REQUEST
    # echo "Got request $REQUEST" >&2
    if [[ "$REQUEST" == "exit" ]]
    then
        # echo "Request became exit, quitting" >&2
        rm $REQUEST_SOCKET_PATH
        rm $ANSWER_SOCKET_PATH
        rmdir SOCKET_TMPDIR
        exit 0
    else
        # Then we validate the command, but we don't do that now, so just true
        if validate "$REQUEST"
        then
            echo "OK" >&11

            # Create new sockets for each stream and exit code
            # echo "Will create paths" >&2
            COMMAND_EXEC_TMP_DIR=$(mktemp -d -p /tmp/mu-host/)
            COMMAND_INPUT_STREAM_PATH="$COMMAND_EXEC_TMP_DIR/in" # Actually unused now
            COMMAND_OUTPUT_STREAM_PATH="$COMMAND_EXEC_TMP_DIR/out"
            COMMAND_ERR_STREAM_PATH="$COMMAND_EXEC_TMP_DIR/err"
            COMMAND_EXIT_STREAM_PATH="$COMMAND_EXEC_TMP_DIR/exit"
            COMMAND_CLOSE_STREAM_PATH="$COMMAND_EXEC_TMP_DIR/close"

            # echo "Will create mkfifo streams" >&2
            mkfifo $COMMAND_INPUT_STREAM_PATH
            mkfifo $COMMAND_OUTPUT_STREAM_PATH
            mkfifo $COMMAND_ERR_STREAM_PATH
            mkfifo $COMMAND_EXIT_STREAM_PATH
            mkfifo $COMMAND_CLOSE_STREAM_PATH

            # echo "Emitting streams" >&2
            echo "$COMMAND_OUTPUT_STREAM_PATH" >&11
            echo "$COMMAND_ERR_STREAM_PATH" >&11
            echo "$COMMAND_INPUT_STREAM_PATH" >&11
            echo "$COMMAND_EXIT_STREAM_PATH" >&11
            echo "$COMMAND_CLOSE_STREAM_PATH" >&11

            # echo "Dispatching command "$COMMAND_INPUT_STREAM_PATH" "$COMMAND_OUTPUT_STREAM_PATH" "$COMMAND_ERR_STREAM_PATH" "$COMMAND_EXIT_STREAM_PATH" "$COMMAND_CLOSE_STREAM_PATH" $REQUEST" >&2
            $(dirname "$(readlink -f "$0")")/docker-dispatch-call.sh "$COMMAND_INPUT_STREAM_PATH" "$COMMAND_OUTPUT_STREAM_PATH" "$COMMAND_ERR_STREAM_PATH" "$COMMAND_EXIT_STREAM_PATH" "$COMMAND_CLOSE_STREAM_PATH" $REQUEST &
        else
            echo "ERROR" >&11
            echo "Error: command not allowed to run $REQUEST" >&2
        fi
    fi
done
