#!/usr/bin/env bash

# Check for missing executable name
if [[ "$#" -lt 1 ]]; then
    echo "Usage: $0 <executable> [args...]"
    exit 1
fi

executable=$1
shift # remove the first parameter (the name of the executable)
"$executable" "$@"
exit_status=$?

if [[ $exit_status -ne 0 ]] || [[ -n "$output" ]]; then
    echo "$executable: error $exit_status"
    exit $exit_status
fi
