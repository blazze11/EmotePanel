local _, ns = ...
local EmotePanel = ns.panel

local Bindings = ns.Bindings

local INPUT_NAME = "EmotePanelCombatInput"
local WHEEL_BINDING = "CLICK " .. INPUT_NAME .. ":Toggle"
local PET_BINDING = "CLICK " .. INPUT_NAME .. ":TogglePet"
local LEGACY_BINDING = "Open Emote Panel"

BINDING_HEADER_EMOTEPANEL = "Emote Panel"
_G["BINDING_NAME_" .. LEGACY_BINDING] = "Open or Close Emote Panel"
_G["BINDING_NAME_" .. WHEEL_BINDING] = "Open or Close Emote Panel"
_G["BINDING_NAME_" .. PET_BINDING] = "Open or Close Pet Wheel"

function EmotePanel:GetWheelBinding(slot, pet)
    local primary, secondary = GetBindingKey(pet and PET_BINDING or WHEEL_BINDING)
    if slot == 1 then return primary end
    return secondary
end

function EmotePanel:HasWheelBinding(pet)
    return self:GetWheelBinding(1, pet) ~= nil
end

function EmotePanel:SetWheelBinding(slot, key, pet)
    if InCombatLockdown() then return false, "Set the wheel keybind outside combat." end
    local bindingSet = GetCurrentBindingSet()
    if bindingSet ~= 1 and bindingSet ~= 2 then return false, "No editable binding set is active." end
    local previous = self:GetWheelBinding(slot, pet)
    local action = key and GetBindingAction(key)
    if previous == key or action == (pet and PET_BINDING or WHEEL_BINDING) then return true end
    if action == "" then action = nil end

    self.migratingWheelBinding = true
    local changed = not previous or SetBinding(previous, nil)
    local opener = pet and "TogglePet" or "Toggle"
    if changed and key then
        local cleared = not action or SetBinding(key, nil)
        changed = cleared and SetBindingClick(key, INPUT_NAME, opener)
        if not changed then
            if cleared and action then SetBinding(key, action) end
            if previous then SetBindingClick(previous, INPUT_NAME, opener) end
        end
    end
    if changed then SaveBindings(bindingSet) end
    self.migratingWheelBinding = nil
    self:SyncCombatWheel(true)
    if changed then return true end
    return false, "WoW could not save that keybind."
end
local function GetLegacyWheelKeys()
    return { GetBindingKey(LEGACY_BINDING) }
end

local function IsWheelOpener(key)
    local action = GetBindingAction(key)
    return action == WHEEL_BINDING or action == PET_BINDING or action == LEGACY_BINDING
end

local function MigrateWheelBindings(self, legacyKeys)
    local bindingSet = GetCurrentBindingSet()
    if #legacyKeys > 0 and (bindingSet == 1 or bindingSet == 2) then
        -- Move only keys assigned to the previous opener. Keep the same keys
        -- in the player's active account or character binding set.
        self.migratingWheelBinding = true
        local changed = false
        for _, key in ipairs(legacyKeys) do
            if SetBindingClick(key, INPUT_NAME, "Toggle") then changed = true end
        end
        if changed then SaveBindings(bindingSet) end
        self.migratingWheelBinding = nil
    end
end

Bindings.GetLegacyWheelKeys = GetLegacyWheelKeys
Bindings.IsWheelOpener = IsWheelOpener
Bindings.INPUT_NAME = INPUT_NAME
Bindings.MigrateWheelBindings = MigrateWheelBindings
