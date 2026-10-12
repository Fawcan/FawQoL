local _, ns = ...
local core = ns.core
local opt = {}
local category

local function Register(m, key, label, varType, setter)
	local s = core:GetSettings(m.key)
	return Settings.RegisterProxySetting(category, "FAWQOL_" .. m.key:upper() .. "_" .. key:upper(),
		varType, label, m.defaults[key],
		function() return s[key] end,
		setter or function(v)
			s[key] = v
			core:ApplySettings(m.key)
		end)
end

-- indent under the module checkbox, greyed out while the module is off
local function Attach(init, parent, m)
	local s = core:GetSettings(m.key)
	init:SetParentInitializer(parent, function() return s.enabled end)
end

function opt:AddCheckbox(m, parent, key, label, tip)
	Attach(Settings.CreateCheckbox(category, Register(m, key, label, Settings.VarType.Boolean), tip), parent, m)
end

local function Round(v) return tostring(math.floor(v + 0.5)) end

function opt:AddSlider(m, parent, key, label, min, max, step, tip)
	local s = core:GetSettings(m.key)
	local setting = Register(m, key, label, Settings.VarType.Number, function(v)
		s[key] = math.floor(v + 0.5)
		core:ApplySettings(m.key)
	end)
	local o = Settings.CreateSliderOptions(min, max, step)
	o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, Round)
	Attach(Settings.CreateSlider(category, setting, o, tip), parent, m)
end

function opt:AddDropdown(m, parent, key, label, list, tip)
	local function Options()
		local c = Settings.CreateControlTextContainer()
		for i, name in ipairs(list) do c:Add(i, name) end
		return c:GetData()
	end
	Attach(Settings.CreateDropdown(category, Register(m, key, label, Settings.VarType.Number), Options, tip), parent, m)
end

function ns.BuildOptions()
	if category then return end
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory("FawQoL")
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Modules"))
	for _, m in ipairs(core:GetModules()) do
		local toggle = Register(m, "enabled", m.name, Settings.VarType.Boolean, function(v)
			core:SetModuleEnabled(m.key, v)
		end)
		local init = Settings.CreateCheckbox(category, toggle, m.desc .. "\n\nChanges made in combat apply when combat ends.")
		if m.BuildOptions then m:BuildOptions(opt, init) end
	end
	Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
	Settings.OpenToCategory(category:GetID())
end
