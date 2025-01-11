#!/bin/bash

set -euo pipefail

die () {
    echo >&2 "$@"
    exit 1
}

# Request sudo privileges once
if ! sudo -v; then
    echo "This script requires sudo privileges. Please run as a user with sudo access."
    exit 1
fi

trap 'sudo -k' EXIT

echo "This script will blindly sign all nodes with name '*.mullvad.ts.net.'."
read -p "If you wish to proceed, please enter 'Yes, I wish to proceed': " confirm

case $confirm in
    "Yes, I wish to proceed") echo "Confirmed.";;
    *) die "Exiting.";;
esac

ts_lock_json=$(tailscale lock status --json)

echo "$ts_lock_json" | jq -e '.Enabled' || die "Tailnet lock is disabled!"

public_key=$(echo "$ts_lock_json" | jq -r '.PublicKey')

echo "Will sign Mullvad nodes with $public_key"
sleep 1
echo "----------------------------------------"

echo "$ts_lock_json" | jq -c '.FilteredPeers[]' | while IFS= read -r peer; do
    name=$(echo "$peer" | jq -r '.Name')
    if [[ ! $name =~ .*\.mullvad\.ts\.net\. ]]; then
        echo "$name is not a Mullvad node, skipping"
        continue
    fi

    nodekey=$(echo "$peer" | jq -r '.NodeKey')
    echo "Signing $name ($nodekey) with $public_key"
    sudo tailscale lock sign "$nodekey" "$public_key"
done
