# Client Geliştirme Önerileri

## 1. Transport Konfigürasyonu

`ProjectNetworkManager.cs` içerisindeki transport ayarlarının aktif edilmesi ve optimize edilmesi gerekiyor:

```csharp
private void ConfigureTransport()
{
    var transport = GetComponent<kcp2k.KcpTransport>();
    if (transport != null)
    {
        // Düşük latency için NoDelay aktif
        transport.NoDelay = true;
        
        // Paket gönderim aralığı (ms)
        transport.Interval = 20;
        
        // Hızlı paket tekrarı için
        transport.FastResend = 2;
        
        // Buffer boyutları
        transport.RecvWindowSize = 4096;
        transport.SendWindowSize = 4096;
        
        LogModel.Instance.Log($"Transport ayarları yapılandırıldı: {transport.GetType().Name}");
    }
    else
    {
        LogModel.Instance.Error("KCP Transport bulunamadı!");
    }
}
```

## 2. State Management Sistemi

Network durumlarını yönetmek için merkezi bir state management sistemi:

```csharp
public class NetworkState
{
    public bool IsConnecting { get; private set; }
    public bool IsReconnecting { get; private set; }
    public bool IsMatchmaking { get; private set; }
    public string CurrentMatchId { get; private set; }
    public MatchState CurrentMatchState { get; private set; }
    
    public void SetConnecting(bool value)
    {
        IsConnecting = value;
        NetworkEvents.TriggerConnectionStateChanged(value ? "Connecting" : "NotConnecting");
    }
    
    public void SetMatchState(MatchState state)
    {
        CurrentMatchState = state;
        NetworkEvents.TriggerMatchStateChanged(state.ToString());
    }
}

public enum MatchState
{
    None,
    Searching,
    Found,
    Connecting,
    Connected,
    Error
}
```

## 3. Event Sistemi

Network olaylarını yönetmek için merkezi event sistemi:

```csharp
public static class NetworkEvents
{
    // Match Events
    public static event Action<string> OnMatchFound;
    public static event Action<string> OnMatchError;
    public static event Action<MatchState> OnMatchStateChanged;
    
    // Connection Events
    public static event Action<string> OnConnectionStateChanged;
    public static event Action<string> OnConnectionError;
    public static event Action OnReconnecting;
    
    // Server Events
    public static event Action<string> OnServerError;
    public static event Action<string> OnServerMessage;
    
    public static void TriggerMatchFound(string matchId)
    {
        LogModel.Instance.Log($"Match bulundu: {matchId}");
        OnMatchFound?.Invoke(matchId);
    }
    
    public static void TriggerMatchError(string error)
    {
        LogModel.Instance.Error($"Match hatası: {error}");
        OnMatchError?.Invoke(error);
    }
}
```

## 4. Error Handling Sistemi

Hata yönetimi için merkezi bir sistem:

```csharp
public static class NetworkErrorHandler
{
    public static void HandleError(Exception ex, string context)
    {
        switch (ex)
        {
            case TimeoutException:
                LogModel.Instance.Error($"[{context}] Zaman aşımı: {ex.Message}");
                NetworkEvents.TriggerConnectionError($"Bağlantı zaman aşımı: {ex.Message}");
                break;
                
            case NetworkException:
                LogModel.Instance.Error($"[{context}] Ağ hatası: {ex.Message}");
                NetworkEvents.TriggerConnectionError($"Ağ hatası: {ex.Message}");
                break;
                
            default:
                LogModel.Instance.Error($"[{context}] Beklenmeyen hata: {ex.Message}");
                NetworkEvents.TriggerConnectionError($"Beklenmeyen hata: {ex.Message}");
                break;
        }
    }
}
```

## 5. Reconnection Sistemi

Bağlantı kopması durumunda yeniden bağlanma mantığı:

```csharp
public class ReconnectionManager
{
    private int reconnectAttempts = 0;
    private const int MAX_RECONNECT_ATTEMPTS = 3;
    private const float RECONNECT_DELAY = 2f; // saniye
    
    public async UniTask<bool> AttemptReconnect()
    {
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS)
        {
            LogModel.Instance.Error("Maximum yeniden bağlanma denemesi aşıldı!");
            return false;
        }

        reconnectAttempts++;
        NetworkEvents.TriggerReconnecting();
        
        try
        {
            // Exponential backoff
            await UniTask.Delay(TimeSpan.FromSeconds(RECONNECT_DELAY * Math.Pow(2, reconnectAttempts - 1)));
            
            // Yeniden bağlanma denemesi
            await PvpServerModel.Instance.OnMatchFound(currentMatch);
            
            // Başarılı bağlantı
            reconnectAttempts = 0;
            return true;
        }
        catch (Exception ex)
        {
            NetworkErrorHandler.HandleError(ex, "Reconnection");
            return false;
        }
    }
}
```

## 6. Match State Senkronizasyonu

Match durumunu server ile senkronize etmek için:

```csharp
public class MatchSynchronizer
{
    private const string MATCH_STATE_RPC = "get_match_state";
    private const float SYNC_INTERVAL = 5f; // saniye
    
    public async UniTask StartSynchronization(string matchId)
    {
        while (NetworkState.CurrentMatchState == MatchState.Connected)
        {
            try
            {
                await SynchronizeMatchState(matchId);
                await UniTask.Delay(TimeSpan.FromSeconds(SYNC_INTERVAL));
            }
            catch (Exception ex)
            {
                NetworkErrorHandler.HandleError(ex, "MatchSync");
                break;
            }
        }
    }
    
    private async UniTask SynchronizeMatchState(string matchId)
    {
        var response = await ServiceModel.Instance.Socket.RpcAsync(
            MATCH_STATE_RPC,
            JsonUtility.ToJson(new { match_id = matchId })
        );
        
        // State'i işle ve güncelle
        var state = JsonUtility.FromJson<MatchStateResponse>(response.Payload);
        UpdateMatchState(state);
    }
}
```

## 7. Önerilen Değişiklikler İçin Test Senaryoları

1. **Transport Testi**
```csharp
[Test]
public async Task TestTransportConfiguration()
{
    // Transport ayarlarını kontrol et
    var transport = networkManager.GetComponent<kcp2k.KcpTransport>();
    Assert.IsNotNull(transport, "Transport bulunamadı");
    Assert.IsTrue(transport.NoDelay, "NoDelay aktif değil");
    Assert.AreEqual(20, transport.Interval, "Interval yanlış");
    Assert.AreEqual(2, transport.FastResend, "FastResend yanlış");
}
```

2. **Reconnection Testi**
```csharp
[Test]
public async Task TestReconnection()
{
    // Bağlantıyı zorla kes
    networkManager.StopClient();
    
    // Yeniden bağlanma denemesi
    var success = await reconnectionManager.AttemptReconnect();
    Assert.IsTrue(success, "Yeniden bağlanma başarısız");
}
```

3. **State Management Testi**
```csharp
[Test]
public void TestNetworkState()
{
    var state = new NetworkState();
    
    // State değişimlerini kontrol et
    state.SetConnecting(true);
    Assert.IsTrue(state.IsConnecting);
    
    state.SetMatchState(MatchState.Searching);
    Assert.AreEqual(MatchState.Searching, state.CurrentMatchState);
}
```

## 8. Performans İyileştirmeleri

1. **Memory Optimizasyonu**
```csharp
// Object pooling kullan
public class NetworkMessagePool
{
    private Queue<NetworkMessage> messagePool = new Queue<NetworkMessage>();
    private const int POOL_SIZE = 100;
    
    public NetworkMessage GetMessage()
    {
        if (messagePool.Count > 0)
            return messagePool.Dequeue();
            
        return new NetworkMessage();
    }
    
    public void ReturnMessage(NetworkMessage message)
    {
        if (messagePool.Count < POOL_SIZE)
            messagePool.Enqueue(message);
    }
}
```

2. **Network Optimizasyonu**
```csharp
// Paket boyutu optimizasyonu
public class NetworkOptimizer
{
    private const int MAX_PACKET_SIZE = 1200; // MTU size
    
    public byte[] OptimizePacket(byte[] data)
    {
        if (data.Length > MAX_PACKET_SIZE)
        {
            // Paketi sıkıştır veya böl
            return CompressPacket(data);
        }
        return data;
    }
}
```

## 9. Güvenlik Önlemleri

1. **Rate Limiting**
```csharp
public class RateLimiter
{
    private Dictionary<string, Queue<DateTime>> requestTimes = new Dictionary<string, Queue<DateTime>>();
    private const int MAX_REQUESTS = 100;
    private const int TIME_WINDOW = 60; // saniye
    
    public bool ShouldAllowRequest(string requestType)
    {
        if (!requestTimes.ContainsKey(requestType))
            requestTimes[requestType] = new Queue<DateTime>();
            
        var queue = requestTimes[requestType];
        var now = DateTime.UtcNow;
        
        // Eski istekleri temizle
        while (queue.Count > 0 && (now - queue.Peek()).TotalSeconds > TIME_WINDOW)
            queue.Dequeue();
            
        if (queue.Count >= MAX_REQUESTS)
            return false;
            
        queue.Enqueue(now);
        return true;
    }
}
```

## 10. Logging ve Monitoring

```csharp
public static class NetworkMonitor
{
    private static Dictionary<string, Stopwatch> latencyTrackers = new Dictionary<string, Stopwatch>();
    
    public static void TrackLatency(string operation)
    {
        var sw = new Stopwatch();
        sw.Start();
        latencyTrackers[operation] = sw;
    }
    
    public static void EndTrackLatency(string operation)
    {
        if (latencyTrackers.TryGetValue(operation, out var sw))
        {
            sw.Stop();
            LogModel.Instance.Log($"[Latency] {operation}: {sw.ElapsedMilliseconds}ms");
            latencyTrackers.Remove(operation);
        }
    }
}
```

## Önemli Notlar

1. Tüm değişiklikleri test ortamında deneyin
2. Her değişiklik için unit test yazın
3. Performans metriklerini takip edin
4. Hata durumlarını detaylı loglayın
5. Rate limiting ve güvenlik önlemlerini aktif edin
6. Memory ve network optimizasyonlarını uygulayın

## Öncelik Sırası

1. Transport konfigürasyonu
2. State management sistemi
3. Error handling
4. Reconnection sistemi
5. Match senkronizasyonu
6. Event sistemi
7. Performans optimizasyonları
8. Güvenlik önlemleri
9. Logging ve monitoring
10. Test senaryoları 