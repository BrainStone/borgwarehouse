#!/usr/bin/env bash

### DEPRECATED ### NodeJS will handle this in the future.

# Shell script created by Raven for BorgWarehouse.
# This shell script takes 4 args: [repositoryName] [new SSH pub key] [quota] [append-only mode (boolean)]
# This shell script updates the SSH key and the quota for a repository.

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

# Check args
if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ] || [ "$4" != "true" ] && [ "$4" != "false" ]; then
    echo -n "This shell takes 4 args: [repositoryName] [new SSH pub key] [quota] [Append only mode [true|false]]" >&2
    exit 1
fi

# Check if the SSH public key is a valid format
# This pattern validates SSH public keys for: rsa, ed25519, ed25519-sk
pattern='(ssh-ed25519 AAAAC3NzaC1lZDI1NTE5|sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29t|ssh-rsa AAAAB3NzaC1yc2)[0-9A-Za-z+/]+[=]{0,3}(\s.*)?'
if [[ ! "$2" =~ $pattern ]]; then
    echo -n "Invalid public SSH KEY format. Provide a key in OpenSSH format (rsa, ed25519, ed25519-sk)" >&2
    exit 2
fi

# Check if the repositoryName pattern is a hex string of 8 characters. With createRepo.sh our randoms are hex strings of 8 characters.
# If we receive another pattern there is necessarily a problem.
repositoryName=$1
if ! [[ "$repositoryName" =~ ^[a-f0-9]{8}$ ]]; then
    echo "Invalid repository name. Must be an 8-character hex string." >&2
    exit 3
fi

# Check if a line in authorized_keys contains repository_name
if ! grep -q "command=\".* ${repositoryName} .*\",restrict" "$authorized_keys"; then
    echo -n "No line containing $repositoryName found in authorized_keys" >&2
    exit 4
fi

# Check if the new SSH pub key is already present on a line other than the one corresponding to repositoryName
found=false
regex="command=\".* ${repositoryName} .*\",restrict"
while IFS= read -r line; do
    if [[ $line =~ $pattern ]]; then
        # Get the SSH pub key of the line (ignore the comment)
        key1=$(echo "${BASH_REMATCH[0]}" | awk '{print $1 " " $2}')
        # Get the SSH pub key of the new SSH pub key (ignore the comment)
        key2=$(echo "$2" | awk '{print $1 " " $2}')

        if [ "$key1" == "$key2" ]; then
            # If the SSH pub key is already present on a line other than the one corresponding to repositoryName
            if [[ ! $line =~ $regex ]]; then
                found=true
                break
            fi
        fi
    fi
done <"$authorized_keys"
if [ "$found" = true ]; then
    echo -n "This SSH pub key is already present in authorized_keys on a different line." >&2
    exit 5
fi

# Determine the base dir of this script
scriptPath="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

# Modify authorized_keys for the repositoryName: update the line with the quota and the SSH pub key
sed -ri "s|command=\".* ${repositoryName} .*,restrict .*|command=\"${scriptPath}/connectionMultiplexer.sh ${pool@Q} ${repositoryName} $3 $4\",restrict $2|g" "$authorized_keys"
