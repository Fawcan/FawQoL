-- Ask before taking gold or items from mail sent by other players.
-- Reading the mail is never blocked. AH, NPC, GM, returned and whitelisted mail pass through.
local _, ns = ...

local M = {
	key = "mailguard",
	name = "Mail Guard",
	desc = "Asks for confirmation before taking gold or items from mail sent by other players. Open All skips those mails.",
	defaults = { enabled = true, trusted = {} },
}

local orig, confirmed = {}, {}
local hooked, events, skippedNote
local trusted, trustedFirst -- lookup sets built from the saved list

local function List() return ns.core:GetSettings(M.key).trusted end

local function Key(name)
	name = strlower(name):gsub("%-.*$", ""):gsub("%s+", " ")
	return strtrim(name)
end

local function Rebuild()
	trusted, trustedFirst = {}, {}
	for _, name in ipairs(List()) do
		local k = Key(name)
		trusted[k] = true
		trustedFirst[k:match("^%S+")] = true
	end
end

local function IsTrusted(sender)
	if not trusted then Rebuild() end
	local k = Key(sender)
	-- full name match, or first name if the game only gave us that
	return trusted[k] or (not k:find(" ") and trustedFirst[k])
end

local function Trust(name)
	name = strtrim((name:gsub("%s+", " ")))
	if not trusted then Rebuild() end
	if name == "" or trusted[Key(name)] then return false end
	local list = List()
	list[#list + 1] = name
	table.sort(list, function(a, b) return strlower(a) < strlower(b) end)
	Rebuild()
	return true
end

local function Untrust(name)
	local list, k = List(), Key(name)
	for i = #list, 1, -1 do
		if Key(list[i]) == k then table.remove(list, i) end
	end
	Rebuild()
end

-- sender and a key for this mail, or nil if it isn't player mail
local function PlayerMail(index)
	local _, _, sender, subject, _, _, _, _, _, returned, _, canReply, isGM = GetInboxHeaderInfo(index)
	if sender and canReply and not returned and not isGM then
		return sender, sender .. "\n" .. (subject or "")
	end
end

local function Guarded(index)
	local sender, key = PlayerMail(index)
	if sender and not confirmed[key] and not IsTrusted(sender) then
		return sender, key
	end
end

local function Take(d)
	-- inbox can shift while the popup is up, make sure it's still the same mail
	if select(2, PlayerMail(d.index)) ~= d.key then return end
	confirmed[d.key] = true
	d.fn(d.index, d.slot)
end

StaticPopupDialogs.FAWQOL_MAIL_CONFIRM = {
	text = "This mail is from |cffffd200%s|r.\n\nTake the %s anyway?",
	button1 = YES,
	button2 = NO,
	button3 = "Always trust",
	selectCallbackByIndex = true,
	OnButton1 = function(_, d) Take(d) end,
	OnButton2 = function() end,
	OnButton3 = function(_, d)
		if Trust(d.sender) then
			ns.core:Print(d.sender .. " added to the Mail Guard whitelist.")
		end
		Take(d)
	end,
	timeout = 0,
	hideOnEscape = 1,
	whileDead = 1,
}

local function Guard(name, what)
	local fn = _G[name]
	orig[name] = fn
	_G[name] = function(index, slot)
		if M.active then
			local sender, key = Guarded(index)
			if sender then
				StaticPopup_Show("FAWQOL_MAIL_CONFIRM", sender, what,
					{ fn = fn, index = index, slot = slot, key = key, sender = sender })
				return
			end
		end
		return fn(index, slot)
	end
end

local function Install()
	Guard("TakeInboxMoney", "gold")
	Guard("TakeInboxItem", "item")
	Guard("AutoLootMailItem", "gold and items")

	local skip = OpenAllMail.ShouldSkipCurrentMail
	OpenAllMail.ShouldSkipCurrentMail = function(self)
		if skip(self) then return true end
		if M.active and Guarded(self.mailIndex) then
			if not skippedNote then
				skippedNote = true
				ns.core:Print("Open All skipped mail from players. Open those yourself.")
			end
			return true
		end
		return false
	end

	events = CreateFrame("Frame")
	events:SetScript("OnEvent", function()
		wipe(confirmed)
		skippedNote = nil
		StaticPopup_Hide("FAWQOL_MAIL_CONFIRM")
	end)
end

function M:OnEnable()
	if not hooked then
		hooked = true
		EventUtil.ContinueOnAddOnLoaded("Blizzard_MailFrame", function()
			Install()
			if M.active then events:RegisterEvent("MAIL_CLOSED") end
		end)
	elseif events then
		events:RegisterEvent("MAIL_CLOSED")
	end
end

function M:OnDisable()
	if events then events:UnregisterAllEvents() end
	StaticPopup_Hide("FAWQOL_MAIL_CONFIRM")
end

-- Whitelist page, built the first time it's opened
local panel = CreateFrame("Frame")
local input, content, empty
local rows = {}

local function Refresh()
	local list = List()
	for i, name in ipairs(list) do
		local row = rows[i]
		if not row then
			row = CreateFrame("Frame", nil, content)
			row:SetSize(400, 24)
			row:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
			row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			row.text:SetPoint("LEFT", 4, 0)
			local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
			remove:SetSize(80, 20)
			remove:SetPoint("LEFT", 260, 0)
			remove:SetText(REMOVE)
			remove:SetScript("OnClick", function()
				Untrust(row.name)
				Refresh()
			end)
			rows[i] = row
		end
		row.name = name
		row.text:SetText(name)
		row:Show()
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	content:SetHeight(math.max(1, #list * 24))
	empty:SetShown(#list == 0)
end

local function Add()
	local name = input:GetText()
	if Trust(name) then
		input:SetText("")
		Refresh()
	elseif strtrim(name) ~= "" then
		ns.core:Print(strtrim(name) .. " is already on the whitelist.")
	end
	input:ClearFocus()
end

local function Build()
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Mail Guard whitelist")

	local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	help:SetWidth(520)
	help:SetJustifyH("LEFT")
	help:SetText("Gold and items from these characters are taken without asking. Enter the full name, First Last. Capitals don't matter.")

	input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	input:SetSize(220, 20)
	input:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 6, -16)
	input:SetAutoFocus(false)
	input:SetMaxLetters(48)
	input:SetScript("OnEnterPressed", Add)

	local add = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	add:SetSize(80, 22)
	add:SetPoint("LEFT", input, "RIGHT", 8, 0)
	add:SetText(ADD)
	add:SetScript("OnClick", Add)

	local scroll = CreateFrame("ScrollFrame", "FawQoLWhitelistScroll", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", input, "BOTTOMLEFT", -6, -14)
	scroll:SetPoint("BOTTOMRIGHT", -36, 16)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(400, 1)
	scroll:SetScrollChild(content)

	empty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 4, -4)
	empty:SetText("No names yet.")
end

panel:SetScript("OnShow", function()
	if not input then Build() end
	Refresh()
end)

function M:BuildOptions(opt, parent)
	opt:AddPanel(self, parent, "Mail Guard whitelist", panel, "Edit",
		"Characters whose mail is taken without asking, such as your alts.")
end

ns.core:RegisterModule(M)
