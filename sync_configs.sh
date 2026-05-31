#!/usr/bin/env bash
set -euo pipefail

rsync -av config/ voronv02:~/printer_data/config/
