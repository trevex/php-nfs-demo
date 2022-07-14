#!/usr/bin/env bash
set -eo pipefail

mkdir -p /var/www/html

if [[ -z "${FILESTORE_IP_ADDRESS}" ]]; then
  echo "Skipping mount of NFS: required environment variables not provided."
else
  echo "Mounting Cloud Filestore."
  mount -o nolock $FILESTORE_IP_ADDRESS:/$FILE_SHARE_NAME /var/www/html
  echo "Mounting completed."
fi

# Start apache2
exec apache2-foreground

# Exit immediately when one of the background processes terminate.
wait -n
