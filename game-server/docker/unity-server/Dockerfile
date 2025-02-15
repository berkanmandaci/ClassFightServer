FROM ubuntu:22.04

# Gerekli paketleri yükle
RUN apt-get update && apt-get install -y \
    libglu1-mesa \
    libxcursor1 \
    libxrandr2 \
    libasound2 \
    libc6 \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /game

# Unity Linux build dosyalarını kopyala
COPY builds/. /game/builds/

# Tüm build dosyalarına gerekli izinleri ver
RUN chmod -R 755 /game/builds && \
    chmod +x /game/builds/ServerBuild.x86_64 && \
    chmod +x /game/builds/UnityPlayer.so

# Start script'i oluştur
RUN echo '#!/bin/bash\n\
cd /game/builds && \
./ServerBuild.x86_64 \
    -batchmode \
    -nographics \
    -nakama-server $NAKAMA_SERVER \
    -nakama-port $NAKAMA_PORT \
    -server-port $SERVER_PORT \
    -kcp-timeout $KCP_TIMEOUT \
    -kcp-no-delay $KCP_NO_DELAY \
    -kcp-interval $KCP_INTERVAL' > /game/start.sh \
    && chmod +x /game/start.sh

# Environment variables
ENV NAKAMA_SERVER=nakama
ENV NAKAMA_PORT=7350
ENV SERVER_PORT=7777
ENV KCP_TIMEOUT=30000
ENV KCP_NO_DELAY=true
ENV KCP_INTERVAL=10

EXPOSE 7777/udp

ENTRYPOINT ["/game/start.sh"]