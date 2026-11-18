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
    if changed then
        SaveBindings(bindingSet)
        -- An explicit edit takes ownership of the current profile's wheel keys.
        EmotePanelSavedVars.profileBindingsPending = nil
    end
    self.migratingWheelBinding = nil
    self:SyncCombatWheel(true)
    if changed then return true end
    return false, "WoW could not save that keybind."
end
-- Apply a profile as one transaction in the currently active WoW binding set.
-- Capture slots for displaced actions as well as the two wheel actions.
function Bindings.ApplyProfile(values)
    local set = GetCurrentBindingSet()
    if set ~= 1 and set ~= 2 then return nil, "Wait until WoW has loaded your keybindings." end
    local snapshots, actions, desired = {}, {}, {}
    local function Snapshot(action)
        if action and action ~= "" and not snapshots[action] then
            snapshots[action] = {GetBindingKey(action)}
            actions[#actions + 1] = action
        end
    end
    local used = {}
    for _, action in ipairs({WHEEL_BINDING, PET_BINDING}) do
        local keys = {GetBindingKey(action)}
        local changed = false
        for slot = 1, 2 do
            local value = values[(action == PET_BINDING and "pet" or "main") .. slot]
            if value ~= nil and value ~= (keys[slot] or "") then
                keys[slot], changed = value, true
            end
        end
        -- Slot one can be empty while slot two is requested. WoW compacts slots.
        for slot = 1, math.max(2, #keys) do
            local key = keys[slot]
            if key and key ~= "" then
                if used[key] then return nil, "The same key is assigned to more than one wheel slot." end
                used[key] = true
            end
        end
        if changed then
            Snapshot(action)
            desired[action] = keys
            for slot = 1, math.max(2, #keys) do
                local key = keys[slot]
                if key and key ~= "" then Snapshot(GetBindingAction(key)) end
            end
        end
    end
    if not next(desired) then return true end
    local function Editable() return not InCombatLockdown() and GetCurrentBindingSet() == set end
    local function Clear(action)
        for _, key in ipairs({GetBindingKey(action)}) do
            if not Editable() or not SetBinding(key, nil) then return false end
        end
        return true
    end
    local function Apply()
        for _, action in ipairs(actions) do if desired[action] and not Clear(action) then return false end end
        for _, action in ipairs(actions) do
            local keys = desired[action]
            if keys then
                for slot = 1, math.max(2, #keys) do
                    local key = keys[slot]
                    if key and key ~= "" then
                        if not Editable() or (GetBindingAction(key) ~= "" and not SetBinding(key, nil))
                            or not SetBindingClick(key, INPUT_NAME, action == PET_BINDING and "TogglePet" or "Toggle") then return false end
                    end
                end
            end
        end
        if not Editable() then return false end
        SaveBindings(set)
        return true
    end
    EmotePanel.migratingWheelBinding = true
    local ok, applied = pcall(Apply)
    local restored = true
    if not ok or not applied then
        for _, action in ipairs(actions) do if not Clear(action) then restored = false end end
        for _, action in ipairs(actions) do
            for _, key in ipairs(snapshots[action]) do
                if not Editable() or not SetBinding(key, action) then restored = false end
            end
        end
    end
    EmotePanel.migratingWheelBinding = nil
    EmotePanel:SyncCombatWheel(true)
    if not restored then return nil, "WoW could not restore all binding slots. Check your active binding set." end
    if not ok or not applied then return nil, "WoW could not apply the profile keybinds." end
    return true
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
