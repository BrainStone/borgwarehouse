#!/usr/bin/env bash

# Shell Script created by BrainStone for BorgWarehouse.
# This script is executed when a new SSH connection to BorgWarehouse is established. It will then verify that the
# command used is either a borg command or a rsync command and apply the restrictions passed via command line.
# This shell script takes 4 arguments: [poolDirectory] [repositoryName] [quota] [append-only mode (boolean)]

if [[ "$1" == "--debug" ]]; then
		shift
		exec 19>>/home/borgwarehouse/connectionMultiplexer.log
		BASH_XTRACEFD=19

		echo >&19
		export >&19
		echo >&19
		set -x
fi

# Check args
if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ] || ! [[ "$3" =~ ^[0-9]+$ ]] || [ "$4" != "true" ] && [ "$4" != "false" ]; then
    echo -n "This shell takes 4 arguments: [poolDirectory] [repositoryName] [quota] [append-only mode (boolean)]" >&2
    exit 1
fi

pool="$1"
repositoryName="$2"
quota="$3"

# Verify repo
if [[ ! "${repositoryName}" =~ ^[a-f0-9]{8}$ ]]; then
    echo "Invalid repository name. Must be an 8-character hex string." >&2
    exit 3
fi

repositoryPath="${pool}/${repositoryName}"

if [[ ! -d "${repositoryPath}" ]]; then
	  echo "Repository doesn't exist" >&2
	  exit 3
fi

# Append only mode
if [ "$4" == "true" ]; then
    appendOnlyMode=("--append-only")
else
    appendOnlyMode=()
fi

case "$SSH_ORIGINAL_COMMAND" in
    'borg serve'|'borg serve '*)
  			cd "${pool}" || exit
				exec borg serve "${appendOnlyMode[@]}" --restrict-to-path "${repositoryPath}" --storage-quota "$quota"G
				;;
		'rsync --server '*)
				# shellcheck disable=SC2206
				# We really want perform shell splitting, because the command is properly escaped
				rsync_command=($SSH_ORIGINAL_COMMAND)
				if [[ "${rsync_command[-1]}" != "./${repositoryName}" && "${rsync_command[-1]}" != "./${repositoryName}/"* ]]; then
						echo "Trying to access restricted path." >&2
						echo "Only ./${repositoryName} is available" >&2
						exit 1
				fi

				rsync_command[-1]="${rsync_command[-1]/\/$repositoryName/}"
				SSH_ORIGINAL_COMMAND="$(printf '%q ' "${rsync_command[@]}")"
        export SSH_ORIGINAL_COMMAND="${SSH_ORIGINAL_COMMAND% }"

				exec rrsync "${repositoryPath}"
				;;
		*)
				echo "Unsupported command" >&2
				exit 1
				;;
esac
