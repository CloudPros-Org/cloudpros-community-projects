#!/bin/bash
set -euo pipefail

exec socat TCP-LISTEN:8000,bind=127.0.0.1,reuseaddr,fork EXEC:/opt/cloudpros/respond.sh
