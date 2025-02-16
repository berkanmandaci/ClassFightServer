"use strict";
/// <reference path="./types/nakama-runtime.d.ts" />
const serverPool = [
    { id: 1, port: 7777, busy: false },
    { id: 2, port: 7778, busy: false },
    { id: 3, port: 7779, busy: false }
];
let matches = {};
function generateMatchId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
}
// Boş server bul
function findAvailableServer() {
    const server = serverPool.find(s => !s.busy);
    if (server) {
        server.busy = true;
        return server;
    }
    return null;
}
// Match oluşturma
const matchmaker = function (ctx, logger, nk, params) {
    var _a;
    const matchId = (_a = params.matchId) !== null && _a !== void 0 ? _a : generateMatchId();
    const server = findAvailableServer();
    if (!server) {
        throw Error("No available server");
    }
    matches[matchId] = {
        matchId: matchId,
        serverId: server.id,
        players: [],
        startTime: Date.now()
    };
    server.matchId = matchId;
    logger.info(`Match ${matchId} created on server ${server.id} (port: ${server.port})`);
    return matchId;
};
// Match'e katılma denemesi
const matchJoinAttempt = function (ctx, logger, nk, matchId, presence) {
    const match = matches[matchId];
    if (!match) {
        return {
            state: {},
            accept: false,
            rejectMessage: "Match not found"
        };
    }
    if (match.players.length >= 2) {
        return {
            state: {},
            accept: false,
            rejectMessage: "Match is full"
        };
    }
    match.players.push(presence.userId);
    logger.info(`Player ${presence.userId} joined match ${matchId}`);
    return {
        state: match,
        accept: true
    };
};
// Match bitimi
const matchTerminate = function (ctx, logger, nk, matchId) {
    const match = matches[matchId];
    if (!match)
        return;
    const server = serverPool.find(s => s.id === match.serverId);
    if (server) {
        server.busy = false;
        server.matchId = undefined;
    }
    delete matches[matchId];
    logger.info(`Match ${matchId} terminated on server ${match.serverId}`);
};
// Server bilgisi alma
const getServerInfo = function (ctx, logger, nk, matchId) {
    var _a;
    const match = matches[matchId];
    if (!match) {
        throw Error("Match not found");
    }
    const server = serverPool.find(s => s.id === match.serverId);
    if (!server) {
        throw Error("Server not found");
    }
    const host = ((_a = nk.runtimeEnvironment) === null || _a === void 0 ? void 0 : _a.envVars["EC2_PUBLIC_IP"]) || "localhost";
    return {
        host: host,
        port: server.port
    };
};
// Match durumu kontrol
const matchLoop = function (ctx, logger, nk, tickRate, state, messages) {
    const matchState = state;
    // 30 dakika sonra match'i sonlandır
    if (Date.now() - matchState.startTime > 30 * 60 * 1000) {
        matchTerminate(ctx, logger, nk, matchState.matchId);
        return null;
    }
    return { state: matchState };
};
// Match RPC fonksiyonları
const rpcFunctions = {
    get_server_info: (ctx, logger, nk, payload) => {
        const matchId = JSON.parse(payload).match_id;
        return getServerInfo(ctx, logger, nk, matchId);
    }
};
// Modül ihracı
const InitModule = function (ctx, logger, nk, initializer) {
    initializer.registerRpc('get_server_info', rpcFunctions.get_server_info);
    initializer.registerMatchmakerMatched(matchmaker);
    logger.info('Match handler module loaded');
};
