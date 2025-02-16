local nk = require("nakama")
nk.logger_info("=== Lua module loaded ===")

-- Matchmaking modülünü yükle
local matchmaking = require("matchmaking")
nk.logger_info("Matchmaking modülü yüklendi")

-- Matchmaking modülünü başlat
matchmaking.InitModule(nil, nil)

-- Health check için basit bir RPC
local function healthcheck_rpc(context, payload)
    nk.logger_info("=== Healthcheck RPC called ===")
    return nk.json_encode({["status"] = "ok" })
end

nk.register_rpc(healthcheck_rpc, "healthcheck_lua")