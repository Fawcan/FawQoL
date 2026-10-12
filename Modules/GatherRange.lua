-- Ring on the minimap at gathering node range.
-- Redraws on zoom / indoor-outdoor / tracking changes only, no OnUpdate.
local _, ns = ...

local SEGMENTS = 48
local RED = { "Red", 1, 0.25, 0.25 }
local COLORS = {
	{ "Green",  0.2, 1, 0.4 },
	{ "Yellow", 1, 0.82, 0 },
	{ "Cyan",   0.2, 0.8, 1 },
	{ "White",  1, 1, 1 },
	{ "Purple", 0.7, 0.4, 1 },
	{ "Orange", 1, 0.5, 0.1 },
}
-- Find Herbs / Find Minerals (same ids as Blizzard's Minimap.lua)
local TRACKING = { [2383] = true, [8387] = true, [2580] = true, [8388] = true }

local M = {
	key = "gather",
	name = "Gather Range",
	desc = "Ring on the minimap showing how far away gathering nodes show up.",
	defaults = { enabled = true, onlyWhenTracking = true, range = 185, thickness = 1, color = 2, opacity = 80 },
}

local s, ring, events, hooked, queued, tracking, names
local lines = {}
local lastR, lastEdge
local cos, sin, pi = math.cos, math.sin, math.pi

local function TrackingNames()
	if not names then
		local t = {}
		for id in pairs(TRACKING) do
			local n = C_Spell.GetSpellName(id)
			if not n then return end
			t[n] = true
		end
		names = t
	end
	return names
end

local function IsTracking()
	local n = TrackingNames()
	for i = 1, C_Minimap.GetNumTrackingTypes() do
		local info = C_Minimap.GetTrackingInfo(i)
		if info and info.active and (TRACKING[info.spellID] or n and n[info.name]) then
			return true
		end
	end
	return false
end

local function Style(edge)
	local c = edge and RED or COLORS[s.color] or COLORS[1]
	local a = s.opacity / 100
	for i = 1, SEGMENTS do
		lines[i]:SetColorTexture(c[2], c[3], c[4], a)
		lines[i]:SetThickness(s.thickness)
	end
end

local function Draw(r)
	local step = 2 * pi / SEGMENTS
	for i = 1, SEGMENTS do
		local a1, a2 = (i - 1) * step, i * step
		lines[i]:SetStartPoint("CENTER", ring, r * cos(a1), r * sin(a1))
		lines[i]:SetEndPoint("CENTER", ring, r * cos(a2), r * sin(a2))
	end
end

local function Update(force)
	if not M.active then return end
	local view = C_Minimap.GetViewRadius()
	if not view or view <= 0 or (s.onlyWhenTracking and not tracking) then
		ring:Hide()
		lastR, lastEdge = nil, nil
		return
	end
	ring:Show()
	local max = Minimap:GetWidth() / 2
	local r = max * s.range / view
	local edge = r > max
	if edge then r = max - s.thickness / 2 end
	if force or edge ~= lastEdge then
		Style(edge)
		lastEdge = edge
	end
	if force or not lastR or math.abs(r - lastR) > 0.01 then
		Draw(r)
		lastR = r
	end
end

-- view radius can lag a frame behind SetZoom, so check again next frame
local function Delayed()
	queued = nil
	Update()
end

local function Request()
	Update()
	if not queued then
		queued = true
		C_Timer.After(0, Delayed)
	end
end

local function OnEvent(_, event)
	if event ~= "MINIMAP_UPDATE_ZOOM" then
		tracking = IsTracking()
	end
	Request()
end

function M:OnEnable(settings)
	s = settings
	if not ring then
		ring = CreateFrame("Frame", nil, Minimap)
		ring:SetAllPoints()
		ring:SetFrameLevel(Minimap:GetFrameLevel() + 2)
		ring:EnableMouse(false)
		for i = 1, SEGMENTS do lines[i] = ring:CreateLine(nil, "ARTWORK") end
		events = CreateFrame("Frame")
		events:SetScript("OnEvent", OnEvent)
	end
	if not hooked then
		hooked = true
		hooksecurefunc(Minimap, "SetZoom", Request)
		Minimap:HookScript("OnSizeChanged", Request)
	end
	events:RegisterEvent("MINIMAP_UPDATE_ZOOM")
	events:RegisterEvent("MINIMAP_UPDATE_TRACKING")
	events:RegisterEvent("SPELLS_CHANGED")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	tracking = IsTracking()
	Update(true)
end

function M:OnUpdateSettings(settings)
	s = settings
	Update(true)
end

function M:OnDisable()
	events:UnregisterAllEvents()
	ring:Hide()
	lastR, lastEdge = nil, nil
end

function M:BuildOptions(opt, parent)
	opt:AddCheckbox(self, parent, "onlyWhenTracking", "Only when tracking herbs or minerals",
		"Hide the ring unless Find Herbs or Find Minerals is active.")
	opt:AddSlider(self, parent, "range", "Range (yards)", 10, 300, 5,
		"Adjust if nodes pop up inside or outside the ring.")
	opt:AddSlider(self, parent, "thickness", "Line thickness", 1, 8, 1)
	local list = {}
	for i, c in ipairs(COLORS) do list[i] = c[1] end
	opt:AddDropdown(self, parent, "color", "Colour", list, "Turns red when the range is past the minimap edge.")
	opt:AddSlider(self, parent, "opacity", "Opacity (%)", 10, 100, 5)
end

ns.core:RegisterModule(M)
