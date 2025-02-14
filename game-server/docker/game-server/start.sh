#!/bin/bash

cd /game/builds/ServerBuild
chmod +x ./ServerBuild.x86_64

./ServerBuild.x86_64 -batchmode -nographics \
    --port ${MATCH_PORT:-7777} \
    --logFile /game/server.log