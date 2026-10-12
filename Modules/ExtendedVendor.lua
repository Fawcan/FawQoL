-- Wider merchant frame. Sizes taken from Blizzard's MerchantFrame.xml.
local _, ns = ...

local SLOT_W, SLOT_H, GAP_X, GAP_Y = 153, 44, 12, 8
local LEFT, TOP, RIGHT, BOTTOM = 11, -69, 7, 123
local BUYBACK, STOCK = 12, 12 -- buyback items, MerchantItem1-12 from the xml

local M = {
	key = "vendor",
	name = "Extended Vendor UI",
	desc = "Shows more items on each vendor page.",
	defaults = { enabled = true, columns = 4, rows = 6 },
}

local s, orig, hooked
local maxSlot = STOCK

local function Slot(i) return _G["MerchantItem" .. i] end

local function GetPoints(f)
	local t = {}
	for i = 1, f:GetNumPoints() do t[i] = { f:GetPoint(i) } end
	return t
end

local function SetPoints(f, t)
	f:ClearAllPoints()
	for i = 1, #t do f:SetPoint(unpack(t[i])) end
end

local function Layout(count)
	local cols = s.columns
	for i = 1, count do
		local slot = Slot(i)
		slot:ClearAllPoints()
		slot:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT",
			LEFT + (i - 1) % cols * (SLOT_W + GAP_X),
			TOP - math.floor((i - 1) / cols) * (SLOT_H + GAP_Y))
	end
	for i = 1, maxSlot do Slot(i):SetShown(i <= count) end
end

local function Refresh()
	if MerchantFrame:IsShown() then
		MerchantFrame.page = 1
		MerchantFrame_Update()
	end
end

local function Apply()
	local perPage = s.columns * s.rows
	local w = LEFT + s.columns * (SLOT_W + GAP_X) - GAP_X + RIGHT
	MERCHANT_ITEMS_PER_PAGE = perPage
	for i = maxSlot + 1, perPage do
		CreateFrame("Frame", "MerchantItem" .. i, MerchantFrame, "MerchantItemTemplate"):Hide()
		maxSlot = i
	end
	MerchantFrame:SetSize(w, -TOP + s.rows * (SLOT_H + GAP_Y) - GAP_Y + BOTTOM)
	MerchantFrameBottomLeftBorder:SetWidth(w - 2)
	MerchantNextPageButton:ClearAllPoints()
	MerchantNextPageButton:SetPoint("CENTER", MerchantFrame, "BOTTOMRIGHT", -26, 96)
	MerchantBuyBackItem:ClearAllPoints()
	MerchantBuyBackItem:SetPoint("TOPLEFT", MerchantFrame, "BOTTOMRIGHT", -130, 70)
	Refresh()
end

function M:OnEnable(settings)
	s = settings
	if not orig then
		orig = {
			perPage = MERCHANT_ITEMS_PER_PAGE,
			w = MerchantFrame:GetWidth(), h = MerchantFrame:GetHeight(),
			border = MerchantFrameBottomLeftBorder:GetWidth(),
			next = GetPoints(MerchantNextPageButton),
			buyback = GetPoints(MerchantBuyBackItem),
		}
		for i = 1, STOCK do orig[i] = GetPoints(Slot(i)) end
	end
	if not hooked then
		hooked = true
		hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
			if M.active then Layout(s.columns * s.rows) end
		end)
		hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
			if M.active then Layout(BUYBACK) end
		end)
	end
	Apply()
end

function M:OnUpdateSettings(settings)
	s = settings
	Apply()
end

function M:OnDisable()
	MERCHANT_ITEMS_PER_PAGE = orig.perPage
	MerchantFrame:SetSize(orig.w, orig.h)
	MerchantFrameBottomLeftBorder:SetWidth(orig.border)
	SetPoints(MerchantNextPageButton, orig.next)
	SetPoints(MerchantBuyBackItem, orig.buyback)
	for i = 1, STOCK do SetPoints(Slot(i), orig[i]) end
	for i = STOCK + 1, maxSlot do Slot(i):Hide() end
	Refresh()
end

function M:BuildOptions(opt, parent)
	opt:AddSlider(self, parent, "columns", "Columns", 2, 6, 1, "Default UI has 2.")
	opt:AddSlider(self, parent, "rows", "Rows", 5, 10, 1, "Default UI has 5.")
end

ns.core:RegisterModule(M)
