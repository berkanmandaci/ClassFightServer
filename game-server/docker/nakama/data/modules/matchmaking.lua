local nk = require("nakama")

-- Server havuzu
local server_pool = {
    { id = 1, port = 7777, busy = false },
    { id = 2, port = 7778, busy = false },
    { id = 3, port = 7779, busy = false }
}

-- Match fonksiyonları
local match_callbacks = {
    match_join_attempt = function(context, dispatcher, tick, state, presence)
        if state.presences and #state.presences >= 2 then
            return state, false, "Match is full"
        end
        return state, true
    end,
    
    match_join = function(context, dispatcher, tick, state, presences)
        if not state.presences then
            state.presences = {}
        end
        for _, presence in ipairs(presences) do
            table.insert(state.presences, presence)
        end
        return state
    end,
    
    match_leave = function(context, dispatcher, tick, state, presences)
        if not state.presences then
            return state
        end
        for _, presence in ipairs(presences) do
            for i, p in ipairs(state.presences) do
                if p.user_id == presence.user_id then
                    table.remove(state.presences, i)
                    break
                end
            end
        end
        return state
    end,
    
    match_terminate = function(context, dispatcher, tick, state, grace_seconds)
        for _, server in ipairs(server_pool) do
            if server.id == state.server_id then
                server.busy = false
                nk.logger_info(string.format("Server serbest bırakıldı: %d", server.id))
                break
            end
        end
        return state
    end
}

-- Match oluşturma
local function match_create(context, matched_users)
    nk.logger_info(string.format("Eşleşen oyuncu sayısı: %d", #matched_users))
    
    -- Boş server bul
    local server = nil
    for _, s in ipairs(server_pool) do
        if not s.busy then
            server = s
            nk.logger_info(string.format("Boş server bulundu: %d", s.id))
            break
        end
    end
    
    if not server then
        nk.logger_error("Boş server bulunamadı!")
        return nil, "No available server"
    end
    
    -- Server'ı meşgul olarak işaretle
    server.busy = true
    
    -- Match ID oluştur
    local match_id = nk.uuid_v4()
    
    -- Match state'ini oluştur
    local state = {
        presences = {},
        match_start_time = os.time(),
        server_id = server.id,
        server_port = server.port
    }
    
    -- Match modülünü oluştur
    local match_module = {
        state = state,
        tick_rate = 1,
        label = "game",
        handshake_data = {
            match_id = match_id,
            server_port = server.port
        },
        match_join_attempt = match_callbacks.match_join_attempt,
        match_join = match_callbacks.match_join,
        match_leave = match_callbacks.match_leave,
        match_terminate = match_callbacks.match_terminate
    }

    -- Match bildirimlerini gönder
    local notifications = {}
    for _, user in ipairs(matched_users) do
        local notification = {
            user_id = user.presence.user_id,
            subject = "Match Bulundu",
            content = {
                match_found = true,
                MatchId = match_id,
                server_info = {
                    --host = "localhost",
                    host = "52.59.221.136",
                    port = server.port
                },
                match_data = {
                    server_id = server.id,
                    game_mode = user.properties.gameMode or 1,
                    region = user.properties.region or "eu"
                }
            },
            code = 1001,
            persistent = false
        }
        table.insert(notifications, notification)
    end
    
    if #notifications > 0 then
        nk.notifications_send(notifications)
        nk.logger_info(string.format("Match bildirimleri gönderildi - Server Port: %d", server.port))
    end
    
    return match_module
end

-- Modülü başlat
function InitModule(context, config)
    nk.logger_info("=== MATCHMAKING MODÜLÜ BAŞLATILIYOR ===")
    nk.register_matchmaker_matched(match_create)
    nk.logger_info("=== MATCHMAKING MODÜLÜ BAŞLATILDI ===")
end

return {
    InitModule = InitModule
}