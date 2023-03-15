#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  echo "Installing addon synocodectool-patch"
  tar -zxvf /addons/codecpatch.tgz -C /tmpRoot/
fi
