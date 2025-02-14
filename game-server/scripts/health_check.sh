#!/bin/bash

check_server() {
    if ! docker ps | grep -q unity-game-server; then
        echo "Game server down, restarting..."
        docker-compose restart game-server
    fi
}

check_nakama() {
    if ! curl -s http://localhost:7350/health; then
        echo "Nakama down, restarting..."
        docker-compose restart nakama
    fi
}

check_server
check_nakama