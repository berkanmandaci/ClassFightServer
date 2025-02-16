# ClassFight Server Mimarisi Dokümantasyonu

## 1. Server Yapılandırması

### 1.1. Docker Container Yapısı
- Üç ana servis: Nakama, Unity Server ve PostgreSQL
- Container'lar arası iletişim bridge network üzerinden
- Her servis için özel volume ve port mapping

```yaml
services:
  postgres:
    container_name: postgres
    image: postgres:12.2-alpine
    environment:
      - POSTGRES_DB=nakama
      - POSTGRES_PASSWORD=localdb
    volumes:
      - data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  nakama:
    container_name: nakama
    image: registry.heroiclabs.com/heroiclabs/nakama:3.22.0
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "7349:7349"
      - "7350:7350"
      - "7351:7351"

  unity-server:
    container_name: unity-server
    build:
      context: .
      dockerfile: docker/unity-server/Dockerfile
    ports:
      - "7777:7777/udp"
```

### 1.2. Environment Değişkenleri
- Nakama güvenlik anahtarları
- Database bağlantı bilgileri
- Port yapılandırmaları
- EC2 public IP

```bash
# Nakama Security
NAKAMA_SESSION_KEY=***
NAKAMA_SOCKET_KEY=***
NAKAMA_RUNTIME_HTTP_KEY=***

# Network
EC2_PUBLIC_IP=52.59.221.136
MATCH_PORT=7777
NAKAMA_PORT=7351
```

## 2. Unity Server Yapılandırması

### 2.1. Server Başlatma
- Headless mode ve batchmode ile çalışma
- Network interface ve port binding
- KCP Transport yapılandırması

```bash
./ServerBuild.x86_64 \
    -batchmode \
    -nographics \
    -nakama-server $NAKAMA_SERVER \
    -nakama-port $NAKAMA_PORT \
    -server-port $SERVER_PORT \
    -bind-ip ${BIND_IP:-0.0.0.0} \
    -external-ip ${EXTERNAL_IP:-0.0.0.0}
```

### 2.2. Network Ayarları
- UDP port 7777 üzerinden iletişim
- KCP Transport optimizasyonları:
  - NoDelay: true
  - Interval: 10ms
  - Timeout: 30000ms

## 3. Nakama Entegrasyonu

### 3.1. Matchmaking Sistemi
- Özel matchmaking mantığı
- Oyuncu eşleştirme kriterleri
- Match oluşturma ve yönetim

```lua
local function match_create(context, payload)
    local match_id = payload.match_id
    local users = payload.users
    
    -- Match mantığı
    for _, user in ipairs(users) do
        -- Kullanıcı işlemleri
    end
    
    return match_id
end
```

### 3.2. Match Handler
- Match yaşam döngüsü yönetimi
- Oyuncu join/leave işlemleri
- Match state senkronizasyonu

```lua
local function match_join_attempt(context, dispatcher, tick, state, presence)
    if state.player_count >= state.max_players then
        return state, false, "Match is full"
    end
    
    return state, true
end
```

## 4. Güvenlik

### 4.1. Network Güvenliği
- AWS Security Group yapılandırması
- UDP port güvenliği
- Nakama authentication

### 4.2. Container Güvenliği
- Container izolasyonu
- Resource limitleri
- Log yönetimi

## 5. Monitoring

### 5.1. Prometheus & Grafana
- Server metrikleri
- Container sağlık durumu
- Network performansı

```yaml
prometheus:
    container_name: prometheus
    image: prom/prometheus:latest
    ports:
      - "9090:9090"

grafana:
    container_name: grafana
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
```

### 5.2. Logging
- Unity Server logları
- Nakama logları
- PostgreSQL logları

## 6. Deployment

### 6.1. AWS EC2 Deployment
- Instance tipi ve yapılandırması
- Security Group ayarları
- Network yapılandırması

### 6.2. Docker Deployment
```bash
# Build ve başlatma
docker-compose build
docker-compose up -d

# Log monitoring
docker-compose logs -f unity-server
```

## 7. Hata Yönetimi

### 7.1. Server Recovery
- Container crash recovery
- Otomatik restart politikaları
- State recovery mekanizmaları

```yaml
unity-server:
    restart: always
    healthcheck:
      test: ["CMD", "nc", "-uz", "localhost", "7777"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 7.2. Error Handling
- Network hata yönetimi
- Database hata yönetimi
- Match hata yönetimi

## 8. Performans Optimizasyonu

### 8.1. Container Optimizasyonu
- Resource limitleri
- Network optimizasyonu
- Volume performansı

### 8.2. Network Optimizasyonu
- UDP paket optimizasyonu
- KCP Transport ayarları
- Latency yönetimi

## 9. Geliştirme Tavsiyeleri

1. **Deployment**:
   - CI/CD pipeline kurulumu
   - Automated testing
   - Version control best practices

2. **Monitoring**:
   - Detaylı metrik toplama
   - Alert sistemi kurulumu
   - Log analizi

3. **Scaling**:
   - Horizontal scaling stratejisi
   - Load balancing
   - Database scaling

## 10. Önemli Notlar

- Server her zaman UTC timezone'da çalışır
- Environment değişkenleri `.env` dosyasından yönetilir
- Tüm servisler bridge network üzerinden haberleşir
- Match verileri PostgreSQL'de saklanır 