#!/bin/bash
if [ ! -f "./info.json" ]; then exit 1; fi
mod_name=$(jq -r '.name' ./info.json)
output_file=~/Downloads/${mod_name}_$(jq -r '.version' ./info.json).zip
cd ../
zip -r "${output_file}" ${mod_name}/* -x "*/.git*" "*/zipper.sh"