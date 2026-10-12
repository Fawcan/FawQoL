local ADDON, ns = ...
local core = {}
ns.core = core

local DB_VERSION = 2
local modules, order = {}, {}
local db, loaded

function core:Print(msg)
	print("|cff33ff99FawQoL|r: " .. msg)
end

local function FillDefaults(dst, src)
	for k, v in pairs(src) do
		if type(dst[k]) ~= type(v) then
			dst[k] = v
		end
	end
end

-- combat queue: anything requested in combat runs once on REGEN_ENABLED
local queue, queueOrder = {}, {}
local gate = CreateFrame("Frame")
gate:SetScript("OnEvent", function(self)
	if InCombatLockdown() then return end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	local q, o = queue, queueOrder
	queue, queueOrder = {}, {}
	for i = 1, #o do q[o[i]]() end
end)

function core:RunOutOfCombat(key, fn)
	if not InCombatLockdown() then
		fn()
		return true
	end
	if not queue[key] then
		queueOrder[#queueOrder + 1] = key
	end
	queue[key] = fn
	gate:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function core:RegisterModule(m)
	modules[m.key] = m
	order[#order + 1] = m
end

function core:GetModules() return order end
function core:GetSettings(key) return db.modules[key] end

local function Sync(m)
	local s = db.modules[m.key]
	if s.enabled and not m.active then
		m.active = true
		m:OnEnable(s)
	elseif not s.enabled and m.active then
		m.active = false
		m:OnDisable()
	end
end

function core:SetModuleEnabled(key, on)
	local m = modules[key]
	db.modules[key].enabled = on and true or false
	if not self:RunOutOfCombat("sync:" .. key, function() Sync(m) end) then
		self:Print(m.name .. " will be " .. (on and "enabled" or "disabled") .. " after combat.")
	end
end

function core:ApplySettings(key)
	local m = modules[key]
	self:RunOutOfCombat("apply:" .. key, function()
		if m.active and m.OnUpdateSettings then
			m:OnUpdateSettings(db.modules[key])
		end
	end)
end

local function Load()
	if loaded then return end
	loaded = true
	for i = 1, #order do Sync(order[i]) end
	ns.BuildOptions()
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" then
		if name ~= ADDON then return end
		self:UnregisterEvent("ADDON_LOADED")
		FawQoLDB = FawQoLDB or {}
		db = FawQoLDB
		db.modules = db.modules or {}
		-- defaults changed in v2, reset old values but keep on/off
		if (db.version or 1) < DB_VERSION then
			for k, s in pairs(db.modules) do
				db.modules[k] = { enabled = s.enabled }
			end
		end
		db.version = DB_VERSION
		for _, m in ipairs(order) do
			db.modules[m.key] = db.modules[m.key] or {}
			FillDefaults(db.modules[m.key], m.defaults)
		end
	else
		self:UnregisterAllEvents()
		self:SetScript("OnEvent", nil)
		core:RunOutOfCombat("load", Load)
	end
end)

SLASH_FAWQOL1 = "/faw"
SLASH_FAWQOL2 = "/fawqol"
SlashCmdList.FAWQOL = function()
	if InCombatLockdown() then
		core:Print("Options are unavailable in combat.")
	elseif loaded then
		ns.OpenOptions()
	end
end
