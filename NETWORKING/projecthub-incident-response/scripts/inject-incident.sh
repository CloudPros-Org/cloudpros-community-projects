#!/bin/sh
set -eu
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <incident-number 1-5>" >&2
  exit 2
fi
python3 scripts/labctl.py inject "$1"
