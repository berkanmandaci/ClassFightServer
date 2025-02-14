local nk = require("nakama")
nk.logger_info("=== matchmaking module loaded ===")

local function matchmaker_matched(context, matched_users)
    nk.logger_info("Eşleşen oyuncular: " .. nk.json_encode(matched_users))

    if #matched_users == 2 then
        nk.logger_info("Matchmaking eşleşmesi bulundu! 2 oyuncu eşleşti.")

        -- Maç oluştur
        local module = "match_handler"
        local match_params = { invited_users = matched_users }
        local match_id = nk.match_create(module, match_params)

        -- Eşleşme bildirimi (code 1001)
        local match_notifications = {}
        for _, user in ipairs(matched_users) do
            table.insert(match_notifications, {
                user_id = user.presence.user_id,
                subject = "Eşleşme bulundu!",
                content = { match_found = true, match_id = match_id },
                code = 1001,
                sender_id = nil
            })
        end
        nk.notifications_send(match_notifications)

        -- Kullanıcı verisi bildirimi (code 1002)
        local user_data_notifications = {}
        for _, user in ipairs(matched_users) do
            table.insert(user_data_notifications, {
                user_id = user.presence.user_id,
                subject = "Kullanıcı Verisi",
                content = { user_data = user.presence },
                code = 1002,
                sender_id = nil
            })
        end
        nk.notifications_send(user_data_notifications)
        
        nk.logger_info("Match ID: " .. match_id .. " için bildirimler gönderildi.")
    end
end

nk.register_matchmaker_matched(matchmaker_matched)