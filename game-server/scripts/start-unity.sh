#!/bin/bash
./build/ServerBuild.x86_64 \
    -batchmode \
    -nographics \
    -nakama-server $NAKAMA_SERVER \
    -nakama-port $NAKAMA_PORT \
    -server-port $SERVER_PORT