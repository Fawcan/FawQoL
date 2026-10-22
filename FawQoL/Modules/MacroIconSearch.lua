-- Icon ID search box in the macro icon picker.
local _, ns = ...

local M = {
	key = "macroicon",
	name = "Macro Icon Search",
	desc = "Adds an icon ID search box to the macro icon picker.",
	defaults = { enabled = true },
}

local box, timer, hooked

local function Search()
	timer = nil
	local id = tonumber(box:GetText())
	if not id then return end
	local p = MacroPopupFrame
	local all = IconSelectorPopupFrameIconFilterTypes.All
	local index = p:GetIndexOfIcon(id)
	if not index and p:GetIconFilter() ~= all then
		p:SetIconFilter(all)
		index = p:GetIndexOfIcon(id)
	end
	p.IconSelector:SetSelectedIndex(index)
	if index then p.IconSelector:ScrollToSelectedIndex() end
	-- ids that aren't in the picker still work as macro icons
	p.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(id)
	p:SetSelectedIconText()
end

local function OnTextChanged(_, userInput)
	if not userInput then return end
	if timer then timer:Cancel() end
	timer = C_Timer.NewTimer(0.4, Search)
end

local function OnEnterPressed()
	if timer then timer:Cancel() end
	Search()
end

local function OnPopupShow()
	if not M.active or InCombatLockdown() then return end
	if not box then
		local border = MacroPopupFrame.BorderBox
		box = CreateFrame("EditBox", nil, border, "SearchBoxTemplate")
		box:SetSize(100, 20)
		box:SetPoint("RIGHT", border.IconTypeDropdown, "LEFT", -12, 0)
		box:SetNumeric(true)
		box:SetMaxLetters(10)
		box.Instructions:SetText("Icon ID")
		box:HookScript("OnTextChanged", OnTextChanged)
		box:HookScript("OnEnterPressed", OnEnterPressed)
	end
	box:SetText("")
	box:Show()
end

function M:OnEnable()
	if not hooked then
		hooked = true
		EventUtil.ContinueOnAddOnLoaded("Blizzard_MacroUI", function()
			MacroPopupFrame:HookScript("OnShow", OnPopupShow)
			if MacroPopupFrame:IsShown() then OnPopupShow() end
		end)
	elseif MacroPopupFrame and MacroPopupFrame:IsShown() then
		OnPopupShow()
	end
end

function M:OnDisable()
	if timer then timer:Cancel() timer = nil end
	if box then box:Hide() end
end

ns.core:RegisterModule(M)
