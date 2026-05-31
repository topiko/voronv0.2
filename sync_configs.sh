#!/usr/bin/env bash
set -euo pipefail

rsync -av config/ pi@voronv02.local:~/printer_data/config/
