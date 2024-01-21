#!/bin/bash
zip -r ~/Downloads/better-chat_$(jq -r '.version' ./info.json).zip * -x "zipper.sh"