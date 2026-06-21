--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "NpcRemotes"
local REMOTE_NAMES = { "Created", "Intent", "Destroyed", "ReportHit", "ReportArrival" }

export type NetRemotes = {
	Created: RemoteEvent,
	Intent: RemoteEvent,
	Destroyed: RemoteEvent,
	ReportHit: RemoteEvent,
	ReportArrival: RemoteEvent,
}

local Net = {}

-- Creates (server) the remotes folder and events, returning typed handles.
function Net.ensureServer(): NetRemotes
	assert(RunService:IsServer(), "Net.ensureServer must run on the server")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	local remotes = {}
	for _, remoteName in REMOTE_NAMES do
		local remote = folder:FindFirstChild(remoteName)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = folder
		end
		remotes[remoteName] = remote
	end
	return remotes :: any
end

-- Waits (client) for the server-created remotes and returns typed handles.
function Net.awaitClient(): NetRemotes
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	local remotes = {}
	for _, remoteName in REMOTE_NAMES do
		remotes[remoteName] = folder:WaitForChild(remoteName)
	end
	return remotes :: any
end

return Net
