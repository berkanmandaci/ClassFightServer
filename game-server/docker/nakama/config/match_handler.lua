local nk = require("nakama")

local function match_create(context, matched_users)
    local match_id = nk.uuid_v4()
    return {
        match_id = match_id,
        metadata = { started = os.time() }
    }
end

nk.register_matchmaker_matched(match_create)