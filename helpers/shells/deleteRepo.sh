#!/usr/bin/env bash

### DEPRECATED ### NodeJS will handle this in the future.

# Shell script created by Raven for BorgWarehouse.
# This shell script takes 1 arg: [repositoryName] with 8 char. length only.
# This shell script **deletes the repository** in the arg and **all its data** and the associated line in the
# authorized_keys file.

# Exit when any command fails
set -e

# Load .env if exists
if [[ -f .env ]]; then
    source .env
fi

# Default value if .env not exists
: "${home:=/home/borgwarehouse}"

# Some variables
pool="${home}/repos"
authorized_keys="${home}/.ssh/authorized_keys"

# Check arg
if [[ $# -ne 1 || $1 = "" ]]; then
    echo -n "You must provide a repositoryName in argument." >&2
    exit 1
fi

# Check if the repositoryName pattern is a hex string of 8 characters. With createRepo.sh our randoms are hex strings of 8 characters.
# If we receive another pattern there is necessarily a problem.
repositoryName=$1
if ! [[ "$repositoryName" =~ ^[a-f0-9]{8}$ ]]; then
    echo "Invalid repository name. Must be an 8-character hex string." >&2
    exit 2
fi

# Delete the repository and the line associated in the authorized_keys file
if [ -d "${pool}/${repositoryName}" ]; then
    # Delete the repository
    rm -rf "${pool}/${repositoryName:?}"
    # Delete the line in the authorized_keys file
    sed -i "/ ${repositoryName} /d" "${authorized_keys}"
    echo -n "The folder ""${pool}"/"${repositoryName}"" and all its data have been deleted. The line associated in the authorized_keys file has been deleted."
else
    # Delete the line in the authorized_keys file
    sed -i "/ ${repositoryName} /d" "${authorized_keys}"
    echo -n "The folder ""${pool}"/"${repositoryName}"" did not exist (repository was never initialized or used). The line associated in the authorized_keys file has been deleted."
fi
