--!strict

local RunService = game:GetService("RunService")

-- Static-only type queries: these do not require the modules at runtime, so the
-- client never loads server code and vice versa.
type ServerApi = typeof(require(script.Server))
type ClientApi = typeof(require(script.Client))

local NpcSystem = {}

-- Initialises and returns the server-side API. Call once from a Server Script.
function NpcSystem.InitServer(): ServerApi
	local NpcServer = require(script.Server)
	NpcServer.Init()
	return NpcServer
end

-- Initialises the client replication listener. Call once from a LocalScript.
function NpcSystem.InitClient(): ClientApi
	local NpcClient = require(script.Client)
	NpcClient.Init()
	return NpcClient
end

return NpcSystem
