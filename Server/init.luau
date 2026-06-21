--!strict

local Net = require(script.Parent.Shared.Net)
local SessionManager = require(script.SessionManager)

local NpcServer = {}

-- Sets up remotes, session lifecycle handling, and client hit-report routing.
function NpcServer.Init()
	local remotes = Net.ensureServer()
	SessionManager.init()
	remotes.ReportHit.OnServerEvent:Connect(function(player: Player, payload: any)
		if typeof(payload) ~= "table" then return end
		if typeof(payload.npcId) ~= "number" then return end
		SessionManager.handleHit(player, payload.npcId)
	end)
	remotes.ReportArrival.OnServerEvent:Connect(function(player: Player, payload: any)
		if typeof(payload) ~= "table" then return end
		if typeof(payload.npcId) ~= "number" then return end
		SessionManager.handleArrival(player, payload.npcId)
	end)
end

NpcServer.createSession = SessionManager.createSession
NpcServer.destroySession = SessionManager.destroySession
NpcServer.addPlayer = SessionManager.addPlayer
NpcServer.removePlayer = SessionManager.removePlayer

return NpcServer
