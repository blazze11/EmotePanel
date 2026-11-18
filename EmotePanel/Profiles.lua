local AddonName, ns = ...
local Profiles = {}
ns.Profiles = Profiles
ns.panel.Profiles = Profiles
local Entries, Widgets = ns.Entries, ns.Widgets

local FORMAT = "!EmotePanel:1!"
local MAX_TEXT, MAX_OPS = 500000, 10000
StaticPopupDialogs["EMOTEPANEL_PROFILE_CONFIRM"] = {
    text = "%s", button1 = "Confirm", button2 = "Cancel",
    OnAccept = function(_, apply) apply() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
local modes = {
    categories = "Category Wheel", favorites = "Favorites", macros = "Actions", pet = "Pet Wheel",
    emotes = "Emotes", voicedEmotes = "Voiced Emotes", chat = "Say Chat", party = "Party Chat",
    commands = "Commands", panels = "Game Panels", interactions = "Player Interactions",
    professions = "Professions", targetMarkers = "Target Marker", pings = "Ping System",
}
local modeOrder = {"categories", "emotes", "voicedEmotes", "chat", "party", "commands", "interactions",
    "panels", "professions", "macros", "pet", "targetMarkers", "pings"}
local actionLabels = {spell = "Abilities", item = "Items", macro = "Macros", mount = "Mounts", companion = "Companion Pets", toy = "Toys"}
local fields = {name = "Name", action = "Message / Command", icon = "Icon"}
local overrideFields = {name = "customButtonNames", action = "customMessages", icon = "customIcons"}
local settings = {
    {"categoryWheel", "Category Wheel", "Open on Category Wheel", "boolean", true},
    {"closePanelAfterAction", "Wheel Behavior", "Close panel after action", "boolean", true},
    {"rememberLastAction", "Wheel Behavior", "Remember last action", "boolean", false},
    {"lockMovementStick", "Wheel Behavior", "Lock movement stick", "boolean", true},
    {"repeatWheelSegments", "Wheel Behavior/Segment repeat", "Enabled", "boolean", true},
    {"wheelRepeatDelay", "Wheel Behavior/Segment repeat", "Initial delay", "number", 300, 100, 1000},
    {"wheelRepeatInterval", "Wheel Behavior/Segment repeat", "Repeat interval", "number", 130, 50, 500},
    {"stopAtSegmentEnds", "Wheel Behavior/Segment repeat", "Stop at ends", "boolean", false},
    {"repeatWheelPaging", "Wheel Behavior/Page repeat", "Enabled", "boolean", true},
    {"wheelPageRepeatDelay", "Wheel Behavior/Page repeat", "Initial delay", "number", 300, 100, 1000},
    {"wheelPageRepeatInterval", "Wheel Behavior/Page repeat", "Repeat interval", "number", 130, 50, 500},
    {"stopAtPageEnds", "Wheel Behavior/Page repeat", "Stop at ends", "boolean", false},
    {"showKeybindLegend", "Appearance", "Keybind legend", "boolean", true},
    {"showLegendHint", "Appearance", "Legend hint", "boolean", true},
    {"showWheelTooltips", "Appearance", "Wheel tooltips", "boolean", false},
    {"macroCooldowns", "Appearance", "Action cooldowns", "boolean", true},
    {"wheelSounds", "Appearance", "Wheel sounds", "boolean", true},
    {"wheelVibration", "Appearance", "Vibration", "boolean", false},
    {"controllerGlyphs", "Appearance", "Controller glyphs", "string", "auto"},
    {"automaticWheelActions", "Wheel Entry List/Actions", "Automatic quest items and abilities", "boolean", true},
    {"highestSpellRankOnly", "Wheel Entry List/Actions", "Highest learned rank only", "boolean", true},
    {"minimapAngle", "Appearance", "Minimap button angle", "number", math.rad(225), -math.pi, 2 * math.pi},
    {"followCursorCenter", "Wheel Position", "Cursor Center Position", "boolean", true},
}
local settingByKey = {}
for _, spec in ipairs(settings) do settingByKey[spec[1]] = spec end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end

local function Store()
    local saved = EmotePanelSavedVars
    if type(saved.profiles) ~= "table" then saved.profiles = {} end
    return saved.profiles
end

local function Text(value, limit)
    return type(value) == "string" and #value <= (limit or 4096)
end

local function PlayerGUID()
    local guid = UnitGUID("player")
    if not issecretvalue(guid) and type(guid) == "string" and guid ~= "" then return guid end
end

local function NewID()
    local saved = EmotePanelSavedVars
    saved.profileSequence = (saved.profileSequence or 0) + 1
    return PlayerGUID() .. ":" .. time() .. ":" .. saved.profileSequence
end

local function Ref(mode, key)
    if mode == "macros" then
        if type(key) ~= "string" then return end
        local data = Entries.GetEntryData(mode, key)
        if data and data.actionType ~= "macro" and actionLabels[data.actionType] then
            local ref = {mode = mode, kind = data.actionType, id = data.actionID,
                name = data.name, icon = data.icon}
            if ref.kind == "companion" then
                ref.species = data.profileSpecies or C_PetJournal.GetPetInfoByPetID(ref.id)
            end
            return ref
        end
        local account = key:match("^account:(.+)$")
        local guid = PlayerGUID()
        local character = guid and key:sub(1, #guid + 1) == guid .. ":" and key:sub(#guid + 2) or nil
        if account or character then
            return {mode = mode, kind = "macro", name = data and data.name or account or character, scope = account and "account" or "character"}
        end
        return
    end
    if type(key) == "number" and key < 0 then
        local entry = Entries.GetEntryData(mode, key)
        if not entry or not entry.custom then return end
        entry.profileID = entry.profileID or NewID()
        return {mode = mode, custom = entry.profileID, label = entry.name, definition = {
            name = entry.name, action = entry.action, icon = entry.icon,
        }}
    end
    return {mode = mode, key = key}
end

local function RefID(ref)
    if ref.kind == "macro" then return ref.mode .. ":" .. ref.scope .. ":" .. ref.name:lower() end
    return ref.mode .. ":" .. tostring(ref.custom or ref.key or ((ref.kind or "") .. ":" .. tostring(ref.id or ref.name)))
end

local function RefName(ref)
    if ref.custom then return ref.label or ref.definition and ref.definition.name or "Custom entry" end
    if ref.mode == "macros" then return ref.name end
    local data = Entries.GetEntryData(ref.mode, ref.key)
    return data and Entries.GetEntryName(ref.mode, ref.key, data) or tostring(ref.key)
end

local function Group(ref)
    if ref.mode == "categories" then return "Category Wheel" end
    if ref.mode == "pet" then return "Pet Wheel" end
    if ref.mode == "commands" and Entries.IsPlayerInteraction(ref.mode, ref.key) then
        return "Wheel Entry List/Player Interactions"
    end
    return "Wheel Entry List/" .. modes[ref.mode]
end

function Profiles.Capture(name)
    if not PlayerGUID() then return nil, "Wait until your character has loaded." end
    local doc = {version = 1, name = name or Profiles.ActiveName(), operations = {}}
    local saved = EmotePanelSavedVars
    local function Add(kind, ref, field, value)
        doc.operations[#doc.operations + 1] = {kind = kind, ref = ref, field = field, value = Copy(value)}
    end
    for _, spec in ipairs(settings) do
        local value = saved[spec[1]]
        if value == nil then
            if spec[1] == "followCursorCenter" then value = false else value = spec[5] end
        end
        Add("setting", nil, spec[1], value)
    end
    local visibilitySeen = {}
    local function AddVisibility(mode, key)
        local ref = Ref(mode, key)
        if ref and not visibilitySeen[RefID(ref)] then
            visibilitySeen[RefID(ref)] = true
            Add("visibility", ref, nil, not Entries.IsEntryHidden(mode, key))
        end
    end
    for _, category in ipairs(Entries.categoryEntries) do
        AddVisibility("categories", category.category)
    end
    Add("actionSet", nil, nil, true)
    Add("favoriteSet", nil, nil, true)
    for mode, list in pairs(saved.entries or {}) do
        if Entries.customEntryTypes[mode] then
            for index, entry in ipairs(list) do
                if entry then
                    local ref = Ref(mode, -index)
                    for field in pairs(fields) do Add("definition", ref, field, entry[field]) end
                end
            end
        end
    end
    for _, mode in ipairs(modeOrder) do
        if mode ~= "categories" and mode ~= "macros" and mode ~= "targetMarkers" and mode ~= "pings" then
            for _, key in ipairs(Entries.GetOrderedEntryIDs(mode, true)) do
                AddVisibility(Entries.GetStorageMode(mode), key)
            end
        end
    end
    for mode, stored in pairs(saved.hiddenEntries or {}) do
        if modes[mode] and mode ~= "favorites" and mode ~= "macros" then
            for key in pairs(stored) do AddVisibility(mode, key) end
        end
    end
    for key, selected in pairs(saved.selectedMacros or {}) do
        if selected then
            local ref = Ref("macros", key)
            if ref then Add("action", ref, nil, true) end
        end
    end
    for field, storage in pairs(overrideFields) do
        for mode, overrides in pairs(saved[storage] or {}) do
            if modes[mode] then
                for key, value in pairs(overrides) do
                    local ref = Ref(mode, key)
                    if ref then Add("override", ref, field, value) end
                end
            end
        end
    end
    for _, mode in ipairs(modeOrder) do
        if mode ~= "targetMarkers" and mode ~= "pings" then
            local order = {}
            for _, key in ipairs(Entries.GetOrderedEntryIDs(mode, true)) do
                local storage = Entries.GetStorageMode(mode)
                local ref = Ref(storage, key)
                if ref then order[#order + 1] = ref end
            end
            if #order > 0 then Add("order", {mode = mode}, nil, order) end
        end
    end
    local favorites = {}
    for _, entry in ipairs(saved.favorites or {}) do
        local ref = Ref(entry.mode, entry.index)
        if ref then
            favorites[#favorites + 1] = ref
            Add("favorite", ref, nil, true)
        end
    end
    Add("favoritesOrder", nil, nil, favorites)
    Add("position", nil, nil, saved.positions and saved.positions.emotePanel or {point = "CENTER", relativePoint = "CENTER", x = 0, y = 0})
    for _, pet in ipairs({false, true}) do
        for slot = 1, 2 do
            Add("binding", nil, (pet and "pet" or "main") .. slot, ns.panel:GetWheelBinding(slot, pet) or "")
        end
    end
    if saved.profileBindingsPending and saved.profileLiveCharacter == PlayerGUID() then
        local stored = Store()[Profiles.ActiveName()]
        local keys = {}
        for _, op in ipairs(stored and stored.operations or {}) do
            if op.kind == "binding" then keys[op.field] = op.value end
        end
        for _, op in ipairs(doc.operations) do
            if op.kind == "binding" and keys[op.field] then op.value = keys[op.field] end
        end
    end
    return doc
end

local function ValidIcon(icon)
    return type(icon) == "number" and icon > 0 and icon < 1000000000
        or Text(icon, 512) and icon ~= ""
end

local function OnlyKeys(value, allowed)
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
end

local function Array(value, limit)
    if type(value) ~= "table" or #value > limit then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > #value or key % 1 ~= 0 then return false end
        count = count + 1
    end
    return count == #value
end

local function ValidRef(ref, group)
    if type(ref) ~= "table" or not modes[ref.mode] or ref.mode == "favorites" then return false end
    if group then return OnlyKeys(ref, {mode = true}) end
    if ref.mode == "macros" then
        if not actionLabels[ref.kind] or not Text(ref.name, 200) or ref.name == "" then return false end
        if ref.kind == "macro" then
            return OnlyKeys(ref, {mode = true, kind = true, scope = true, name = true})
                and (ref.scope == "account" or ref.scope == "character")
        end
        if not OnlyKeys(ref, {mode = true, kind = true, id = true, name = true, icon = true, species = ref.kind == "companion"}) then return false end
        if ref.species ~= nil and (type(ref.species) ~= "number" or ref.species < 1 or ref.species % 1 ~= 0) then return false end
        return ValidIcon(ref.icon) and (ref.kind == "companion" and Text(ref.id, 100) and ref.id ~= ""
            or ref.kind ~= "companion" and type(ref.id) == "number" and ref.id > 0 and ref.id % 1 == 0 and ref.id < 1000000000)
    end
    if ref.custom then
        if not OnlyKeys(ref, {mode = true, custom = true, definition = true, label = true})
            or not Entries.customEntryTypes[ref.mode] or not Text(ref.custom, 200) or ref.custom == ""
            or ref.label ~= nil and not Text(ref.label, 200) or type(ref.definition) ~= "table" then return false end
        for field, value in pairs(ref.definition) do
            if not fields[field] or (field == "icon" and not ValidIcon(value))
                or (field ~= "icon" and not Text(value, field == "name" and 200 or 4096)) then return false end
        end
        return true
    end
    if not OnlyKeys(ref, {mode = true, key = true}) then return false end
    return (type(ref.key) == "number" and ref.key > 0 and ref.key % 1 == 0 and ref.key < 1000000)
        or Text(ref.key, 200) and ref.key ~= ""
end

local function ValidRefs(list)
    if not Array(list, 2000) then return false end
    for _, ref in ipairs(list) do if not ValidRef(ref) then return false end end
    return true
end

local anchors = {CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true}

local function ValidOperation(op)
    if type(op) ~= "table" then return false end
    local kind = op.kind
    local hasRef = kind == "order" or kind == "definition" or kind == "override" or kind == "customPresence"
        or kind == "visibility" or kind == "favorite" or kind == "action"
    local hasField = kind == "setting" or kind == "binding" or kind == "definition" or kind == "override"
    if not OnlyKeys(op, {kind = true, value = true, ref = hasRef, field = hasField}) then return false end
    local value = op.value
    if op.kind == "setting" then
        local spec = settingByKey[op.field]
        if not spec or type(value) ~= spec[4] then return false end
        if spec[4] == "number" then return value >= spec[6] and value <= spec[7] and (op.field == "minimapAngle" or value % 10 == 0) end
        if spec[4] == "string" then return value == "auto" or Widgets.GLYPH_STYLES[value] ~= nil end
        return true
    elseif op.kind == "position" then
        return type(value) == "table" and OnlyKeys(value, {point = true, relativePoint = true, x = true, y = true}) and anchors[value.point] and anchors[value.relativePoint]
            and type(value.x) == "number" and math.abs(value.x) < 10000
            and type(value.y) == "number" and math.abs(value.y) < 10000
    elseif op.kind == "binding" then
        return (op.field == "main1" or op.field == "main2" or op.field == "pet1" or op.field == "pet2")
            and Text(value, 100) and not value:find("[%s%c]")
    elseif op.kind == "favoritesOrder" then
        return ValidRefs(value)
    elseif op.kind == "actionSet" or op.kind == "favoriteSet" then
        return value == true
    elseif op.kind == "order" then
        if not ValidRef(op.ref, true) or not ValidRefs(value) then return false end
        for _, ref in ipairs(value) do if ref.mode ~= Entries.GetStorageMode(op.ref.mode) then return false end end
        return true
    end
    if not ValidRef(op.ref) then return false end
    if op.kind == "definition" then
        return op.ref.custom and fields[op.field] ~= nil and
            (op.field == "icon" and ValidIcon(value) or op.field ~= "icon" and value ~= "" and Text(value, op.field == "name" and 200 or 4096))
    elseif op.kind == "override" then
        return fields[op.field] ~= nil and
            (value == false or op.field == "icon" and ValidIcon(value) or op.field ~= "icon" and Text(value, op.field == "name" and 200 or 4096))
    elseif op.kind == "customPresence" then
        return op.ref.custom ~= nil and value == false
    elseif op.kind == "visibility" or op.kind == "favorite" or op.kind == "action" then
        return type(value) == "boolean" and (op.kind ~= "action" or op.ref.mode == "macros")
    end
    return false
end

function Profiles.Validate(doc)
    local visited, nodes, bytes = {}, 0, 0
    local function Plain(value, depth)
        if type(value) == "string" then bytes = bytes + #value end
        if bytes > MAX_TEXT * 4 then return false end
        nodes = nodes + 1
        if nodes > 100000 or depth > 16 then return false end
        if type(value) == "table" then
            if getmetatable(value) or visited[value] then return false end
            visited[value] = true
            for key, child in pairs(value) do
                if type(key) == "string" then bytes = bytes + #key end
                if (type(key) ~= "string" and type(key) ~= "number") or not Plain(child, depth + 1) then return false end
            end
            visited[value] = nil
            return true
        end
        return type(value) == "boolean" or Text(value, MAX_TEXT)
            or type(value) == "number" and value == value and math.abs(value) < 1000000000000
    end
    if not Plain(doc, 0) then return nil, "The profile contains invalid or excessive data." end
    if type(doc) ~= "table" or doc.version ~= 1 or not Text(doc.name, 100)
        or doc.name:find("[%c]") or not OnlyKeys(doc, {version = true, name = true, operations = true}) or not Array(doc.operations, MAX_OPS) then
        return nil, "This is not a supported EmotePanel profile."
    end
    local seen = {}
    for key, op in pairs(doc.operations) do
        if type(key) ~= "number" or key < 1 or key > #doc.operations or key % 1 ~= 0 or not ValidOperation(op) then
            return nil, "The profile contains invalid settings."
        end
        local id = op.kind .. ":" .. (op.ref and RefID(op.ref) or "") .. ":" .. tostring(op.field)
        if seen[id] then return nil, "The profile contains duplicate settings." end
        seen[id] = true
    end
    return true
end

function Profiles.Encode(doc)
    assert(Profiles.Validate(doc))
    local bytes = C_EncodingUtil.SerializeCBOR(doc)
    local packed = C_EncodingUtil.CompressString(bytes, Enum.CompressionMethod.Deflate, Enum.CompressionLevel.OptimizeForSize)
    return FORMAT .. C_EncodingUtil.EncodeBase64(packed, Enum.Base64Variant.StandardUrlSafe)
end

function Profiles.Decode(text)
    if not Text(text, MAX_TEXT) then return nil, "The import text is too long." end
    text = text:gsub("%s", "")
    if text:sub(1, #FORMAT) ~= FORMAT then return nil, "Paste an EmotePanel profile export." end
    local ok, doc = pcall(function()
        local packed = C_EncodingUtil.DecodeBase64(text:sub(#FORMAT + 1), Enum.Base64Variant.StandardUrlSafe)
        local bytes = packed and C_EncodingUtil.DecompressString(packed, Enum.CompressionMethod.Deflate)
        if not bytes or #bytes > MAX_TEXT * 4 then return end
        return C_EncodingUtil.DeserializeCBOR(bytes)
    end)
    if not ok then return nil, "The profile could not be read." end
    local checked, valid, reason = pcall(Profiles.Validate, doc)
    if not checked then return nil, "The profile contains invalid settings." end
    if not valid then return nil, reason end
    return doc
end

local function FindCompanion(ref)
    return Entries.GetCompanionID(ref.id, ref.species)
end

local function CurrentAction(ref)
    if ref.kind == "macro" then
        local guid = PlayerGUID()
        if ref.scope ~= "account" and not guid then return false end
        local prefix = ref.scope == "account" and "account:" or guid .. ":"
        local data = Entries.GetEntryData("macros", prefix .. ref.name:lower())
        return data and not data.profileMacro
    elseif ref.kind == "spell" then
        local known = C_SpellBook.IsSpellKnown(ref.id)
        return not issecretvalue(known) and known
    elseif ref.kind == "item" then
        local count = C_Item.GetItemCount(ref.id)
        return not issecretvalue(count) and count and count > 0
    elseif ref.kind == "toy" then
        local owned = PlayerHasToy(ref.id)
        return not issecretvalue(owned) and owned
    elseif ref.kind == "mount" then
        local owned = select(11, C_MountJournal.GetMountInfoByID(ref.id))
        return not issecretvalue(owned) and owned == true
    elseif ref.kind == "companion" then
        return FindCompanion(ref) ~= nil
    end
end

function Profiles.Unavailable(ref)
    if ref.mode ~= "macros" or CurrentAction(ref) then return end
    local reasons = {spell = "Not learned", item = "Not carried", toy = "Not collected",
        mount = "Not collected", companion = "Not collected", macro = "Macro not found"}
    return reasons[ref.kind]
end

local function OperationLabel(op)
    local ref = op.ref
    if op.kind == "setting" then
        local spec = settingByKey[op.field]
        if op.field == "minimapAngle" then return spec[2], ("%s — %.0f°"):format(spec[3], math.deg(op.value) % 360) end
        local value = type(op.value) == "boolean" and (op.value and "On" or "Off") or tostring(op.value)
        return spec[2], spec[3] .. " — " .. value
    elseif op.kind == "binding" then
        local key = op.value:gsub("|", "||")
        return "Wheel Keybinds", (op.field:find("pet") and "Pet Wheel " or "Main Wheel ") .. op.field:sub(-1) .. " — " .. (key ~= "" and GetBindingText(key) or "Not bound")
    elseif op.kind == "position" then return "Wheel Position", "Placement"
    elseif op.kind == "favoritesOrder" then return "Favorites", "Entry order"
    elseif op.kind == "actionSet" then return "Wheel Entry List/Actions/Selected actions", "Use checked actions only"
    elseif op.kind == "favoriteSet" then return "Favorites/Favorite entries", "Use checked Favorites only"
    elseif op.kind == "favorite" then return "Favorites/Favorite entries", (op.value and "" or "Remove ") .. RefName(ref)
    elseif op.kind == "order" then
        return Group({mode = ref.mode}), "Entry order"
    elseif op.kind == "action" then
        return "Wheel Entry List/Actions/Selected actions/" .. actionLabels[ref.kind], (op.value and "" or "Remove ") .. RefName(ref)
    elseif op.kind == "customPresence" then
        return Group(ref) .. "/Custom entries", "Remove " .. RefName(ref)
    elseif op.kind == "definition" then
        return Group(ref) .. "/Custom entries/" .. RefName(ref), fields[op.field] .. " — " .. tostring(op.value)
    elseif op.kind == "override" then
        return Group(ref) .. "/Edited entries/" .. RefName(ref), fields[op.field] .. " — " .. (op.value == false and "Default" or tostring(op.value))
    end
    local value = op.value and "Shown" or "Hidden"
    return Group(ref) .. "/Enabled and hidden entries", RefName(ref) .. " — " .. value
end

function Profiles.Tree(doc)
    local root = {label = "Everything", children = {}, expanded = true}
    for index, op in ipairs(doc.operations) do
        local path, label = OperationLabel(op)
        local parent = root
        for part in path:gmatch("[^/]+") do
            local child
            for _, candidate in ipairs(parent.children) do
                if candidate.children and candidate.label == part then child = candidate; break end
            end
            if not child then
                child = {label = part, children = {}, parent = parent}
                parent.children[#parent.children + 1] = child
            end
            parent = child
        end
        local reason = op.ref and op.ref.mode == "macros" and op.ref.kind and Profiles.Unavailable(op.ref)
        parent.children[#parent.children + 1] = {label = label, operation = index, parent = parent,
            checked = true,
            reason = reason, icon = op.ref and op.ref.icon, bindingMarkup = op.kind == "binding"}
    end
    local topOrder = {["Category Wheel"] = 1, ["Wheel Entry List"] = 2, Favorites = 3,
        ["Pet Wheel"] = 4, ["Wheel Behavior"] = 5, Appearance = 6, ["Wheel Position"] = 7, ["Wheel Keybinds"] = 8}
    table.sort(root.children, function(a, b) return topOrder[a.label] < topOrder[b.label] end)
    return root
end

function Profiles.Toggle(node, checked)
    if node.children then
        for _, child in ipairs(node.children) do Profiles.Toggle(child, checked) end
    else node.checked = checked end
end

function Profiles.State(node)
    if not node.children then return node.checked and 1 or 0 end
    local checked, unchecked = false, false
    for _, child in ipairs(node.children) do
        local state = Profiles.State(child)
        checked = checked or state ~= 0
        unchecked = unchecked or state ~= 1
    end
    return checked and (unchecked and 2 or 1) or 0
end

function Profiles.Selected(doc, root)
    local result = {version = 1, name = doc.name, operations = {}}
    local function Visit(node)
        if node.children then
            for _, child in ipairs(node.children) do Visit(child) end
        elseif node.checked then result.operations[#result.operations + 1] = Copy(doc.operations[node.operation]) end
    end
    Visit(root)
    -- Definitions are represented exclusively by checked operations. Every
    -- occurrence, including order and Favorite lists, crosses the export boundary.
    local names = {}
    for _, op in ipairs(result.operations) do
        if op.kind == "definition" and op.field == "name" then names[RefID(op.ref)] = op.value end
    end
    local function Strip(ref)
        if ref.custom then ref.definition, ref.label = {}, names[RefID(ref)] end
    end
    for _, op in ipairs(result.operations) do
        if op.ref then Strip(op.ref) end
        if op.kind == "order" or op.kind == "favoritesOrder" then
            for _, ref in ipairs(op.value) do Strip(ref) end
        end
    end
    return result
end

-- Build the complete result first. Reload only after settings and bindings succeed.
function Profiles.Prepare(doc, skipUnavailable, base)
    local valid, reason = Profiles.Validate(doc)
    if not valid then return nil, reason end
    if InCombatLockdown() then return nil, "Load profiles outside combat." end
    local guid = PlayerGUID()
    if not guid then return nil, "Wait until your character has loaded." end
    local saved = Copy(base or EmotePanelSavedVars)
    local mapped, definitions = {}, {}
    local function Ensure(parent, key)
        parent[key] = parent[key] or {}
        return parent[key]
    end
    for _, op in ipairs(doc.operations) do
        if op.kind == "actionSet" then
            for key in pairs(Ensure(saved, "selectedMacros")) do
                if type(key) == "string" and (key:sub(1, 8) == "account:" or key:sub(1, #guid + 1) == guid .. ":"
                    or key:find(":" .. guid .. ":", 1, true)) then
                    saved.selectedMacros[key] = nil
                end
            end
        elseif op.kind == "favoriteSet" then saved.favorites, saved.sitFavoriteAdded = {}, true end
    end
    for _, op in ipairs(doc.operations) do
        if op.kind == "definition" then
            local id = RefID(op.ref)
            definitions[id] = definitions[id] or {}
            definitions[id][op.field] = op.value
        end
    end
    local function Resolve(ref, existingOnly)
        local id = RefID(ref)
        if mapped[id] then return mapped[id] end
        local key = ref.key
        if ref.custom then
            local entries = Ensure(Ensure(saved, "entries"), ref.mode)
            local entry
            for position, candidate in ipairs(entries) do
                if candidate and candidate.profileID == ref.custom then entry, key = candidate, -position; break end
            end
            local parts = definitions[id]
            if not entry then
                if existingOnly then return end
                local definition = parts or ref.definition
                if not next(definition) then return end
                if not definition.name or definition.name == "" or not definition.action or definition.action == "" then
                    error("The new entry " .. RefName(ref) .. " needs both its name and message or command.", 0)
                end
                entry = {custom = true, profileID = ref.custom, name = definition.name, action = definition.action,
                    icon = definition.icon or Entries.customEntryTypes[ref.mode].icon,
                    actionType = Entries.customEntryTypes[ref.mode].actionType}
                entries[#entries + 1] = entry
                key = -#entries
            end
            for field, value in pairs(parts or {}) do entry[field] = value end
        elseif ref.mode == "macros" then
            if skipUnavailable and Profiles.Unavailable(ref) then return end
            if existingOnly then
                if ref.kind == "macro" then
                    return (ref.scope == "account" and "account:" or guid .. ":") .. ref.name:lower()
                end
                local actionID = ref.kind == "companion" and FindCompanion(ref) or ref.id
                return ref.kind .. ":" .. guid .. ":" .. (actionID or ref.id)
            end
            if ref.kind == "macro" then
                key = (ref.scope == "account" and "account:" or guid .. ":") .. ref.name:lower()
                if not CurrentAction(ref) then
                    Ensure(saved, "profileMissingMacros")[key] = ref.name
                end
            else
                local actionID = ref.id
                if ref.kind == "companion" then actionID = FindCompanion(ref) or ref.id end
                key = ref.kind .. ":" .. guid .. ":" .. actionID
                local actions = Ensure(Ensure(saved, "directActions"), guid)
                local exists
                for _, action in ipairs(actions) do
                    if action.actionType == ref.kind and action.actionID == actionID then exists = true end
                end
                if not exists then
                    actions[#actions + 1] = {actionType = ref.kind, actionID = actionID, name = ref.name, icon = ref.icon,
                        preview = actionLabels[ref.kind], profileImported = true,
                        profileSpecies = ref.species,
                        outOfCombat = ref.kind == "mount" or ref.kind == "companion" or nil}
                end
            end
        end
        mapped[id] = key
        return key
    end
    local function ResolveOrder(refs, mode)
        local result, seen = {}, {}
        for _, ref in ipairs(refs) do
            if ref.mode ~= mode then error("The profile has an invalid order.", 0) end
            local key = Resolve(ref)
            if key and not seen[key] then result[#result + 1], seen[key] = key, true end
        end
        return result
    end
    local bindings = {}
    local ok, failure = pcall(function()
        for _, op in ipairs(doc.operations) do
            local ref, kind = op.ref, op.kind
            if kind == "actionSet" or kind == "favoriteSet" then
                -- Selection sets are cleared before applying the individual entries.
            elseif kind == "setting" then saved[op.field] = op.value
            elseif kind == "position" then Ensure(saved, "positions").emotePanel = Copy(op.value)
            elseif kind == "binding" then bindings[op.field] = op.value
            elseif kind == "order" then
                Ensure(saved, "entryOrder")[ref.mode] = ResolveOrder(op.value, Entries.GetStorageMode(ref.mode))
            elseif kind == "customPresence" then
                local entries = Ensure(Ensure(saved, "entries"), ref.mode)
                for position, entry in ipairs(entries) do
                    if entry and entry.profileID == ref.custom then
                        entries[position] = false
                        for _, storage in pairs(overrideFields) do
                            local overrides = saved[storage] and saved[storage][ref.mode]
                            if overrides then overrides[-position] = nil end
                        end
                        local hidden = saved.hiddenEntries and saved.hiddenEntries[ref.mode]
                        if hidden then hidden[-position] = nil end
                    end
                end
            elseif kind == "favoritesOrder" then
                local favorites, seen = {}, {}
                for _, entry in ipairs(op.value) do
                    local key = Resolve(entry, true)
                    local exists
                    for _, favorite in ipairs(saved.favorites or {}) do
                        if favorite.mode == entry.mode and favorite.index == key then exists = true end
                    end
                    if key and exists and not seen[RefID(entry)] then
                        favorites[#favorites + 1] = {mode = entry.mode, index = key}
                        seen[RefID(entry)] = true
                    end
                end
                -- Reordering alone keeps existing Favorites that were not in the imported order.
                for _, entry in ipairs(saved.favorites or {}) do
                    local found
                    for _, candidate in ipairs(favorites) do
                        if candidate.mode == entry.mode and candidate.index == entry.index then found = true end
                    end
                    if not found then favorites[#favorites + 1] = entry end
                end
                saved.favorites = favorites
            else
                local key = Resolve(ref, op.value == false)
                if key then
                    if kind == "action" then Ensure(saved, "selectedMacros")[key] = op.value or nil
                    elseif kind == "visibility" then
                        Ensure(Ensure(saved, "hiddenEntries"), ref.mode)[key] = not op.value
                    elseif kind == "override" then
                        Ensure(Ensure(saved, overrideFields[op.field]), ref.mode)[key] = op.value ~= false and op.value or nil
                    elseif kind == "favorite" then
                        local favorites = Ensure(saved, "favorites")
                        local found
                        for _, entry in ipairs(favorites) do
                            if entry.mode == ref.mode and entry.index == key then found = true end
                        end
                        if op.value and not found then favorites[#favorites + 1] = {mode = ref.mode, index = key} end
                        if not op.value then
                            for position = #favorites, 1, -1 do
                                if favorites[position].mode == ref.mode and favorites[position].index == key then
                                    table.remove(favorites, position)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    if not ok then return nil, tostring(failure) end
    local categoryCount = 0
    for _, entry in ipairs(Entries.categoryEntries) do
        local hidden = saved.hiddenEntries and saved.hiddenEntries.categories
        local value = hidden and hidden[entry.category]
        if value == nil then value = entry.defaultHidden end
        if not value then categoryCount = categoryCount + 1 end
    end
    if categoryCount > ns.SECTOR_COUNT then return nil, "The result would enable more than eight categories. Include the category visibility settings together." end
    local keys = {}
    for _, key in pairs(bindings) do
        if key ~= "" then
            if keys[key] then return nil, "The same key is assigned to more than one wheel slot in this import." end
            keys[key] = true
        end
    end
    return saved, bindings
end

function Profiles.Save(name, doc)
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 100 or name:find("[%c]") then return nil, "Enter a profile name of up to 100 characters on one line." end
    if name == "Default" then return nil, "Default is the fresh-install preset. Create a named profile to save changes." end
    local valid, reason = Profiles.Validate(doc)
    if not valid then return nil, reason end
    Store()[name] = Copy(doc)
    Store()[name].name = name
    return true, name
end

function Profiles.List()
    local names = {}
    for name, doc in pairs(Store()) do
        if Text(name, 100) and Profiles.Validate(doc) then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

function Profiles.Get(name)
    local doc = Store()[name]
    if Profiles.Validate(doc) then return Copy(doc) end
end
function Profiles.Delete(name) Store()[name] = nil end

local function BindingConflicts(doc)
    local conflicts, lines = {}, {}
    for _, op in ipairs(doc.operations) do
        if op.kind == "binding" and op.value ~= "" then
            local action = GetBindingAction(op.value)
            if action and action ~= "" and not ns.Bindings.IsWheelOpener(op.value) then
                conflicts[op.value] = action
                lines[#lines + 1] = op.value .. " replaces " .. (GetBindingName(action) or action)
            end
        end
    end
    return {set = GetCurrentBindingSet(), actions = conflicts}, table.concat(lines, "\n")
end

function Profiles.Apply(doc, skipUnavailable, base, approval, deferConflicts)
    if InCombatLockdown() then return nil, "Load profiles outside combat." end
    local result, bindings = Profiles.Prepare(doc, skipUnavailable, base)
    if not result then return nil, bindings end
    local set = GetCurrentBindingSet()
    if set ~= 1 and set ~= 2 then return nil, "Wait until WoW has loaded your keybindings." end
    if approval and approval.set ~= set then return nil, "The active WoW binding set changed. Review the profile again." end
    local conflicts, descriptions = BindingConflicts(doc)
    local deferred
    for key, action in pairs(conflicts.actions) do
        if not approval or approval.actions[key] ~= action then
            if not deferConflicts then return nil, "Review these keybind changes first:\n" .. descriptions end
            bindings, deferred = {}, true
            break
        end
    end
    local applied, reason = ns.Bindings.ApplyProfile(bindings)
    if not applied then return nil, reason end
    result.profiles = Copy(Store())
    EmotePanelSavedVars = result
    if deferred then Widgets.ShowError("Profile keys are pending. Select the profile to review:\n" .. descriptions) end
    return true, nil, deferred
end

-- The live setup is the active profile's working copy. Checkpoint it before
-- switching, exporting, and logout; WoW writes SavedVariables at logout/reload.
function Profiles.ActiveName()
    local saved, guid = EmotePanelSavedVars, PlayerGUID()
    return saved.profileCharacters and saved.profileCharacters[guid] or "Default"
end

local defaultBaseline
local function Equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not Equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

function Profiles.CharacterName()
    -- Forever/Camelot returns first name and surname, not name and realm.
    local first, surname = UnitNameUnmodified("player")
    if issecretvalue(first) or issecretvalue(surname) or type(first) ~= "string" or first == "" then return end
    if type(surname) == "string" and surname ~= "" then return first .. " " .. surname end
    return first
end

local function WorkingState()
    local saved, state, guid = EmotePanelSavedVars, {}, PlayerGUID()
    for _, spec in ipairs(settings) do state[spec[1]] = saved[spec[1]] end
    for _, field in ipairs({"customIcons", "customButtonNames", "customMessages", "entries", "hiddenEntries", "entryOrder", "favorites"}) do
        state[field] = Copy(saved[field])
    end
    state.position = Copy(saved.positions and saved.positions.emotePanel)
    state.directActions = Copy(saved.directActions and saved.directActions[guid])
    state.selectedMacros = {}
    for key, value in pairs(saved.selectedMacros or {}) do
        if key:sub(1, 8) == "account:" or key:sub(1, #guid + 1) == guid .. ":" or key:find(":" .. guid .. ":", 1, true) then
            state.selectedMacros[key] = value
        end
    end
    state.bindings = {}
    for _, field in ipairs({"main1", "main2", "pet1", "pet2"}) do
        state.bindings[field] = ns.panel:GetWheelBinding(tonumber(field:sub(-1)), field:sub(1, 3) == "pet") or ""
    end
    return state
end

function Profiles.IsReady()
    local set = GetCurrentBindingSet()
    return Profiles.ready and PlayerGUID() ~= nil and EmotePanelSavedVars.profileLiveCharacter == PlayerGUID()
        and (set == 1 or set == 2)
end

local function RefreshSettingsTitle()
    local window = ns.panel.settingsWindow
    if window then window:RefreshTitle() end
end

function Profiles.SaveActive()
    local saved, guid = EmotePanelSavedVars, PlayerGUID()
    if not Profiles.IsReady() then return end
    local name = Profiles.ActiveName()
    if name == "Default" then
        if not defaultBaseline or Equal(WorkingState(), defaultBaseline) then return end
        local character = Profiles.CharacterName()
        if not character then return end
        -- Preserve the clean preset and any previous character profile.
        name = Profiles.SuggestName(character)
        saved.profileCharacters[guid] = name
        saved.profileCharacterProfiles = saved.profileCharacterProfiles or {}
        saved.profileCharacterProfiles[guid] = name
        RefreshSettingsTitle()
    end
    local doc = Profiles.Capture(name)
    Store()[name] = doc
end

local function FreshBase()
    local saved = Copy(EmotePanelSavedVars)
    for _, spec in ipairs(settings) do saved[spec[1]] = spec[5] end
    for _, key in ipairs({"customIcons", "customButtonNames", "customMessages", "entries", "hiddenEntries", "entryOrder"}) do
        saved[key] = {}
    end
    saved.positions = saved.positions or {}
    saved.positions.emotePanel = nil
    saved.favorites, saved.sitFavoriteAdded = {}, nil
    local guid = PlayerGUID()
    saved.directActions = saved.directActions or {}
    saved.directActions[guid] = {}
    for _, field in ipairs({"selectedMacros", "profileMissingMacros"}) do
        saved[field] = saved[field] or {}
        for key in pairs(saved[field]) do
            if key:sub(1, 8) == "account:" or key:sub(1, #guid + 1) == guid .. ":" or key:find(":" .. guid .. ":", 1, true) then
                saved[field][key] = nil
            end
        end
    end
    return saved
end

function Profiles.DefaultDocument(name)
    local doc = {version = 1, name = name or "Default", operations = {}}
    local function Add(kind, ref, field, value)
        doc.operations[#doc.operations + 1] = {kind = kind, ref = ref, field = field, value = Copy(value)}
    end
    for _, spec in ipairs(settings) do Add("setting", nil, spec[1], spec[5]) end
    for _, category in ipairs(Entries.categoryEntries) do
        Add("visibility", {mode = "categories", key = category.category}, nil, not category.defaultHidden)
    end
    Add("actionSet", nil, nil, true)
    Add("favoriteSet", nil, nil, true)
    Add("favorite", {mode = "emotes", key = Entries.SIT_INDEX}, nil, true)
    Add("position", nil, nil, {point = "CENTER", relativePoint = "CENTER", x = 0, y = 0})
    for _, field in ipairs({"main1", "main2", "pet1", "pet2"}) do Add("binding", nil, field, "") end
    return doc
end

function Profiles.CompleteImport(doc)
    local valid, reason = Profiles.Validate(doc)
    if not valid then return nil, reason end
    local result = Profiles.DefaultDocument(doc.name)
    local replacements, replaceFavorites = {}, false
    local function Key(op) return op.kind .. ":" .. (op.ref and RefID(op.ref) or "") .. ":" .. tostring(op.field) end
    for _, op in ipairs(doc.operations) do
        replacements[Key(op)] = true
        if op.kind == "favoriteSet" then replaceFavorites = true end
    end
    for index = #result.operations, 1, -1 do
        local op = result.operations[index]
        if replacements[Key(op)] or replaceFavorites and op.kind == "favorite" then table.remove(result.operations, index) end
    end
    for _, op in ipairs(doc.operations) do result.operations[#result.operations + 1] = Copy(op) end
    return result
end

local function RefreshLive()
    Entries.InitializeSavedEntries()
    ns.Input.InitializeRepeatTiming()
    ns.Pages.Initialize()
    local panel = ns.panel
    if panel.frame then
        panel.frame:Hide()
        panel:RefreshWheel()
        panel:LoadPosition()
        if panel.RefreshMinimapPosition then panel:RefreshMinimapPosition() end
        panel:SyncCombatWheel(true)
        panel:RefreshControllerPrompts()
    end
end

function Profiles.Switch(name, initializing, approval)
    if InCombatLockdown() then return nil, "Switch profiles outside combat." end
    if not initializing and not Profiles.IsReady() then return nil, "Wait until your profile has finished loading." end
    if not initializing then Profiles.SaveActive() end
    if not initializing and not EmotePanelSavedVars.profileBindingsPending and name == Profiles.ActiveName() and EmotePanelSavedVars.profileLiveCharacter == PlayerGUID() then return true end
    local target = Profiles.Get(name)
    if not target then return nil, "That profile no longer exists." end
    local success, reason, deferred = Profiles.Apply(target, false, FreshBase(), approval, initializing)
    if not success then return nil, reason end
    local saved = EmotePanelSavedVars
    saved.profileCharacters = saved.profileCharacters or {}
    saved.profileCharacters[PlayerGUID()] = name
    saved.profileLiveCharacter = PlayerGUID()
    saved.profileBindingsPending = deferred or nil
    RefreshLive()
    defaultBaseline = name == "Default" and WorkingState() or nil
    Profiles.SaveActive()
    RefreshSettingsTitle()
    if not initializing then ns.SettingsUI.WarnMissingWheelBinding() end
    return true
end

-- Keep one copy of the original shared setup until every identifiable legacy
-- character has logged in. Their actions and selection keys are GUID-scoped.
local legacyFields = {"customIcons", "customButtonNames", "customMessages", "entries", "hiddenEntries",
    "entryOrder", "positions", "favorites", "sitFavoriteAdded", "selectedMacros", "profileMissingMacros"}

local function KnownLegacyCharacters(saved)
    local known = {}
    for guid in pairs(saved.directActions or {}) do known[guid] = true end
    local function Inspect(key)
        if type(key) ~= "string" then return end
        local guid = key:match("^(Player%-[^:]+):") or key:match("^[^:]+:(Player%-[^:]+):")
        if guid then known[guid] = true end
    end
    for _, field in ipairs({"selectedMacros", "profileMissingMacros"}) do
        for key in pairs(saved[field] or {}) do Inspect(key) end
    end
    for _, item in ipairs(saved.favorites or {}) do if item.mode == "macros" then Inspect(item.index) end end
    for _, key in ipairs(saved.entryOrder and saved.entryOrder.macros or {}) do Inspect(key) end
    return known
end

local function PreserveLegacy(saved, guid)
    local known = KnownLegacyCharacters(saved)
    known[guid] = nil
    if not next(known) then return end
    local shared = {}
    for _, key in ipairs(legacyFields) do shared[key] = Copy(saved[key]) end
    for _, spec in ipairs(settings) do shared[spec[1]] = saved[spec[1]] end
    saved.profileLegacy = {characters = known, shared = shared}
end

local function LoadLegacy(saved, guid, shared)
    local base = FreshBase()
    base.profileBindingsPending = nil
    base.directActions[guid] = Copy(saved.directActions[guid] or {})
    for _, field in ipairs(legacyFields) do
        if field == "selectedMacros" or field == "profileMissingMacros" then
            for key, value in pairs((shared or saved)[field] or {}) do
                if (shared and key:sub(1, 8) == "account:") or key:sub(1, #guid + 1) == guid .. ":"
                    or key:find(":" .. guid .. ":", 1, true) then base[field][key] = value end
            end
        elseif shared then base[field] = Copy(shared[field]) end
    end
    if shared then
        for _, spec in ipairs(settings) do base[spec[1]] = shared[spec[1]] end
    end
    EmotePanelSavedVars = base
    RefreshLive()
    return base
end

function Profiles.Initialize()
    local bindingSet = GetCurrentBindingSet()
    if bindingSet ~= 1 and bindingSet ~= 2 then return false end
    local saved, guid = EmotePanelSavedVars, PlayerGUID()
    if not guid then return false end
    local character = Profiles.CharacterName()
    if not character then return false end
    if not Entries.HasCharacter() then Entries.ReadActions() end
    local legacy = type(saved.profileCharacters) ~= "table"
    local upgrading = saved.profileDefaultsVersion ~= 1
    local liveHere = not saved.profileLiveCharacter or saved.profileLiveCharacter == guid
    saved.profileCharacters = legacy and {} or saved.profileCharacters
    saved.profileCharacterProfiles = saved.profileCharacterProfiles or {}
    -- Minimap placement used to be shared across all existing named profiles.
    if not saved.profileMinimapMigrated then
        local placement = {kind = "setting", field = "minimapAngle", value = saved.minimapAngle}
        if ValidOperation(placement) then
            for name, doc in pairs(Store()) do
                if name ~= "Default" and Profiles.Validate(doc) then
                    local found
                    for _, op in ipairs(doc.operations) do
                        if op.kind == "setting" and op.field == "minimapAngle" then found = true; break end
                    end
                    if not found then doc.operations[#doc.operations + 1] = Copy(placement) end
                end
            end
        end
        saved.profileMinimapMigrated = true
    end
    local selected = saved.profileCharacters[guid]
    local selectedDoc = selected and Profiles.Get(selected)
    local oldDefault = Profiles.Get("Default")
    if upgrading and oldDefault and not Equal(oldDefault, Profiles.DefaultDocument()) then
        local name = Profiles.SuggestName("Default")
        Profiles.Save(name, oldDefault)
        saved.profilePreviousDefault = name
    end
    if legacy and Store()["Before Import"] then
        Profiles.Save(Profiles.SuggestName("Previous setup"), Store()["Before Import"])
        Store()["Before Import"] = nil
    end
    Store().Default = Profiles.DefaultDocument()
    saved.profileDefaultsVersion = 1
    if legacy and not saved.profileLegacy then PreserveLegacy(saved, guid) end
    local pending = saved.profileLegacy
    if not liveHere and not selectedDoc and not saved.profileCharacterProfiles[guid] then
        if pending and pending.characters[guid] then
            saved, liveHere = LoadLegacy(saved, guid, pending.shared), true
        elseif KnownLegacyCharacters(saved)[guid] then
            -- Older profile builds may already have migrated the first character.
            -- Recover remaining per-character records even without the shared snapshot.
            saved, liveHere = LoadLegacy(saved, guid), true
        end
    end
    local capturedLive = false
    if not saved.profileCharacterProfiles[guid] then
        local name, doc = Profiles.SuggestName(character)
        if liveHere then
            doc, capturedLive = Profiles.Capture(name), true
        elseif selectedDoc then
            -- Preserve a pre-existing choice rather than copying another
            -- character's currently loaded setup.
            doc = selected ~= "Default" and selectedDoc
                or (Profiles.Get(saved.profilePreviousDefault or "") or Profiles.Get("Default"))
        else
            doc = Profiles.DefaultDocument(name)
            -- Existing WoW account/character binds are not addon defaults.
            for _, op in ipairs(doc.operations) do
                if op.kind == "binding" then
                    op.value = ns.panel:GetWheelBinding(tonumber(op.field:sub(-1)), op.field:sub(1, 3) == "pet") or ""
                end
            end
        end
        local success, reason = Profiles.Save(name, doc)
        if not success then Widgets.ShowError(reason); return false end
        saved.profileCharacterProfiles[guid] = name
        if not selectedDoc or selected == "Default" then selected = name end
    elseif not selectedDoc then
        local own = saved.profileCharacterProfiles[guid]
        selected = Profiles.Get(own) and own or "Default"
    end
    if saved.profileBindingsPending or not liveHere or not capturedLive and saved.profileCharacters[guid] ~= selected then
        local success, reason = Profiles.Switch(selected, true)
        if not success then Widgets.ShowError(reason); return false end
    else
        saved.profileCharacters[guid], saved.profileLiveCharacter = selected, guid
        defaultBaseline = selected == "Default" and WorkingState() or nil
        Profiles.SaveActive()
    end
    pending = EmotePanelSavedVars.profileLegacy
    if pending then
        pending.characters[guid] = nil
        if not next(pending.characters) then EmotePanelSavedVars.profileLegacy = nil end
    end
    return true
end

local initializing
function Profiles.InitializeWhenReady()
    if Profiles.ready or initializing then return Profiles.ready end
    if InCombatLockdown() then return false end
    initializing = true
    local ok, ready = pcall(Profiles.Initialize)
    initializing = false
    if not ok then Widgets.ShowError("Profile loading failed: " .. tostring(ready)); return false end
    Profiles.ready = ready
    if ready then
        Profiles.SaveActive()
        RefreshSettingsTitle()
    end
    return Profiles.ready
end

function Profiles.SuggestName(name)
    name = (name or "Profile"):sub(1, 90)
    local result, suffix = name, 2
    while Store()[result] ~= nil do result, suffix = name .. " " .. suffix, suffix + 1 end
    return result
end

function Profiles.CreateNamed(name, imported, approval)
    if not Profiles.IsReady() then return nil, "Wait until your profile has finished loading." end
    if InCombatLockdown() then return nil, "Create profiles outside combat." end
    name = (name or ""):match("^%s*(.-)%s*$")
    if Store()[name] ~= nil then return nil, "That profile name is already used." end
    Profiles.SaveActive()
    local doc, reason
    if imported then doc, reason = Profiles.CompleteImport(imported) else doc = Profiles.Capture(name) end
    if not doc then return nil, reason end
    local result, failure = Profiles.Prepare(doc, false, FreshBase())
    if not result then return nil, failure end
    local success, message = Profiles.Save(name, doc)
    if not success then return nil, message end
    success, message = Profiles.Switch(name, false, approval)
    if not success then Store()[name] = nil; return nil, message end
    return true, name
end

function Profiles.DeleteNamed(name)
    if not Profiles.IsReady() then return nil, "Wait until your profile has finished loading." end
    if name == "Default" then return nil, "Default cannot be deleted." end
    if InCombatLockdown() then return nil, "Delete profiles outside combat." end
    if Profiles.ActiveName() == name then
        local success, reason = Profiles.Switch("Default")
        if not success then return nil, reason end
    end
    for guid, selected in pairs(EmotePanelSavedVars.profileCharacters or {}) do
        if selected == name then EmotePanelSavedVars.profileCharacters[guid] = "Default" end
    end
    Profiles.Delete(name)
    return true
end

function Profiles.ResetActive()
    if not Profiles.IsReady() then return nil, "Wait until your profile has finished loading." end
    local doc = Profiles.DefaultDocument(Profiles.ActiveName())
    -- Reset addon settings without removing the player's assigned WoW bindings.
    for _, op in ipairs(doc.operations) do
        if op.kind == "binding" then op.value = ns.panel:GetWheelBinding(tonumber(op.field:sub(-1)), op.field:sub(1, 3) == "pet") or "" end
    end
    local success, reason = Profiles.Apply(doc, false, FreshBase())
    if not success then return nil, reason end
    EmotePanelSavedVars.profileBindingsPending = nil
    RefreshLive()
    if Profiles.ActiveName() == "Default" then defaultBaseline = WorkingState() end
    Profiles.SaveActive()
    ns.SettingsUI.WarnMissingWheelBinding()
    return true
end

function Profiles.Create(parent)
    local panel = CreateFrame("Frame", AddonName .. "ProfilesPanel", parent)
    ns.panel.profilesPanel = panel
    local body = CreateFrame("Frame", nil, panel)
    body:SetAllPoints(panel)
    body:Show()
    local title = body:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Profiles")

    local home = CreateFrame("Frame", nil, body)
    home:SetAllPoints(body)
    home:Show()
    local reviewBar = CreateFrame("Frame", nil, body)
    reviewBar:SetAllPoints(body)
    reviewBar:Hide()
    local reviewMode
    local doc, root
    local rows = {}
    local scroll = CreateFrame("ScrollFrame", nil, body, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -124)
    scroll:SetPoint("BOTTOMRIGHT", -28, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(490, 1)
    scroll:SetScrollChild(content)
    content:Show()
    scroll:Hide()
    panel.scrollFrame = scroll

    local function Button(owner, label, x, y, width, callback, description)
        local button = Widgets.CreateRedButton(owner, label)
        button:SetSize(width, 24)
        button:SetPoint("TOPLEFT", x, y)
        button:SetScript("OnClick", callback)
        Widgets.AddSettingsTooltip(button, label, description or label)
        return button
    end

    local selector, deleteProfile, reviewContinue, autoSave
    local function VisibleNodes()
        local visible = {}
        local function Visit(node, depth)
            visible[#visible + 1] = {node = node, depth = depth}
            if node.children and node.expanded then
                for _, child in ipairs(node.children) do Visit(child, depth + 1) end
            end
        end
        Visit(root, 0)
        return visible
    end

    local RefreshTree
    RefreshTree = function(focus)
        local visible = VisibleNodes()
        content:SetSize(math.max(200, scroll:GetWidth()), math.max(28, #visible * 28))
        for index, item in ipairs(visible) do
            local row = rows[index]
            if not row then
                row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
                row:SetSize(24, 24)
                row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.label:SetPoint("LEFT", row, "RIGHT", 4, 0)
                row.label:SetJustifyH("LEFT")
                row.label:SetWordWrap(false)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(20, 20)
                row.icon:SetPoint("LEFT", row, "RIGHT", 4, 0)
                row.mixed = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.mixed:SetPoint("CENTER")
                row.mixed:SetText("–")
                row.expander = CreateFrame("Button", nil, row)
                row.expander:SetSize(20, 24)
                row.expander:SetPoint("RIGHT", row, "LEFT")
                row.expander.text = row.expander:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                row.expander.text:SetPoint("CENTER")
                row.expander:SetScript("OnClick", function()
                    row.node.expanded = not row.node.expanded
                    RefreshTree(row.node)
                end)
                row:SetScript("OnClick", function()
                    Profiles.Toggle(row.node, Profiles.State(row.node) ~= 1)
                    RefreshTree(row.node)
                end)
                function row:MoveSetting(direction)
                    local node = self.node
                    if node.children and direction > 0 and not node.expanded then
                        node.expanded = true
                        RefreshTree(node)
                    elseif node.children and direction < 0 and node.expanded then
                        node.expanded = false
                        RefreshTree(node)
                    elseif direction < 0 and node.parent then
                        RefreshTree(node.parent)
                    else return false end
                    return true
                end
                rows[index] = row
            end
            local node, depth = item.node, item.depth
            row.settingsMoveLabel = "Expand / Collapse"
            row.node, row.orderY = node, (index - 1) * 28
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 20 + depth * 16, -row.orderY)
            row:SetHitRectInsets(0, -math.max(0, content:GetWidth() - 58 - depth * 16), 0, 0)
            local state = Profiles.State(node)
            row:SetChecked(state == 1)
            row.mixed:SetShown(state == 2)
            row.expander:SetShown(node.children ~= nil)
            row.expander.text:SetText(node.expanded and "v" or ">")
            row.icon:SetShown(node.icon ~= nil)
            if node.icon then Widgets.SetIconTexture(row.icon, node.icon) end
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row, "RIGHT", node.icon and 28 or 4, 0)
            local label = node.bindingMarkup and node.label or node.label:gsub("|", "||")
            label = label .. (node.reason and "  |cffffa060(" .. node.reason .. ")|r" or "")
            row.label:SetText(label)
            row.label:SetWidth(math.max(80, content:GetWidth() - 62 - depth * 16))
            row.settingsFocusLabel = node.label
            row.settingsFocusText = row.label
            row.settingsFocusDescription = node.reason
                and (node.reason .. ". This action stays saved and appears when your character can use it.")
                or node.children and "Select this group to include its contents. Use left and right to collapse or expand."
                or "Include this field. Unchecked import fields use addon defaults in the new profile."
            row:Show()
            if node == focus then ns.panel.settingsWindow:FocusEntry(panel, row) end
        end
        for index = #visible + 1, #rows do rows[index]:Hide() end
        panel.document, panel.tree = doc, root
    end

    local function SetDocument(data, name, mode)
        local valid, reason = Profiles.Validate(data)
        if not valid then Widgets.ShowError(reason); return end
        doc, root = data, Profiles.Tree(data)
        Profiles.Toggle(root, true)
        reviewMode = mode or "export"
        title:SetText(reviewMode == "import" and "Choose What to Import" or "Choose What to Export")
        home:Hide()
        reviewBar:Show()
        scroll:Show()
        scroll:SetVerticalScroll(0)
        RefreshTree()
        ns.panel.settingsWindow:FocusEntry(panel, rows[1])
    end
    selector = CreateFrame("DropdownButton", "EmotePanelProfileSelector", home, "WowStyle1DropdownTemplate")
    selector:SetSize(300, 24)
    selector:SetPoint("TOPLEFT", 16, -44)
    Widgets.AddSettingsTooltip(selector, "Active profile", "Choose a named profile to save changes automatically. Default is the fresh-install preset; editing it creates a character copy.")
    local function ShowHome()
        Profiles.SaveActive()
        doc, root, reviewMode = nil, nil, nil
        panel.document, panel.tree = nil, nil
        title:SetText("Profiles")
        selector:SetText(Profiles.ActiveName())
        selector.settingsFocusLabel = "Active profile: " .. Profiles.ActiveName()
        if deleteProfile then deleteProfile:SetEnabled(Profiles.ActiveName() ~= "Default") end
        if autoSave then
            autoSave:SetText(EmotePanelSavedVars.profileBindingsPending and "Keybind changes are pending. Select this profile to review them."
                or Profiles.ActiveName() == "Default"
                and "Default is a fresh-install preset. Changes create a character copy."
                or "Changes save automatically.")
        end
        home:Show()
        reviewBar:Hide()
        scroll:Hide()
        ns.panel.settingsWindow:FocusEntry(panel, selector)
    end
    local menuFrames, menuNames, menuIndex = {}, {}, 1
    local function ChooseProfile(index)
        local name = menuNames[index]
        selector:CloseMenu()
        local target = Profiles.Get(name)
        if not target then return end
        local approval, changes = BindingConflicts(target)
        local function Switch()
            local success, reason = Profiles.Switch(name, false, approval)
            if not success then Widgets.ShowError(reason) end
            ShowHome()
        end
        if changes ~= "" then
            Widgets.ShowConfirmation("EMOTEPANEL_PROFILE_CONFIRM", "Switch to " .. name .. "?\n" .. changes, Switch)
        else Switch() end
    end
    selector:SetupMenu(function(_, menu)
        menuFrames, menuNames, menuIndex = {}, Profiles.List(), 1
        for index, name in ipairs(menuNames) do
            if name == "Default" then table.remove(menuNames, index); break end
        end
        table.insert(menuNames, 1, "Default")
        menu:SetScrollMode(360)
        for index, name in ipairs(menuNames) do
            if name == Profiles.ActiveName() then menuIndex = index end
            local radio = menu:CreateRadio(name, function()
                return Profiles.ActiveName() == name
            end, function() ChooseProfile(index) end)
            radio:AddInitializer(function(frame)
                menuFrames[index] = frame
                frame.settingsFocusLabel = name
                frame.settingsFocusDescription = "Switch to this profile. Changes save automatically to the selected profile."
            end)
        end
    end)
    local function FocusMenuEntry()
        local frame = menuFrames[menuIndex]
        if not frame or not selector.menu then return end
        if selector.menu.ScrollBox and selector.menu.ScrollBox:IsShown() then
            selector.menu.ScrollBox:ScrollToElementData(frame, ScrollBoxConstants.AlignNearest)
        end
        ns.panel.settingsWindow:FocusEntry(panel, frame)
    end
    selector.settingsActivate = function()
        selector:OpenMenu()
        FocusMenuEntry()
    end
    selector:RegisterCallback("OnMenuClose", function()
        ns.panel.settingsWindow:FocusEntry(panel, selector)
    end)
    function panel:HandleSettingsMenu(key)
        if not selector:IsMenuOpen() then return nil end
        if key == "PADDUP" or key == "PADDDOWN" then
            local nextIndex = math.max(1, math.min(#menuNames, menuIndex + (key == "PADDUP" and -1 or 1)))
            if nextIndex == menuIndex then return false end
            menuIndex = nextIndex
            FocusMenuEntry()
            Widgets.PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_HIGHLIGHT)
        elseif key == "PAD1" then
            ChooseProfile(menuIndex)
        elseif key == "PAD2" then
            selector:CloseMenu()
        elseif key == "PADLSHOULDER" or key == "PADRSHOULDER" then
            selector:CloseMenu()
            return nil
        end
        return true
    end

    local modal = CreateFrame("Frame", nil, panel)
    modal:SetAllPoints(panel)
    modal:Hide()
    local modalTitle = modal:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    modalTitle:SetPoint("TOPLEFT", 16, -16)
    local instruction = modal:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instruction:SetPoint("TOPLEFT", 16, -46)
    instruction:SetWidth(490)
    instruction:SetJustifyH("LEFT")
    local fieldLabel = modal:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fieldLabel:SetPoint("TOPLEFT", 20, -90)
    local textPane = CreateFrame("Frame", nil, modal, "InsetFrameTemplate")
    textPane:SetPoint("TOPLEFT", 16, -110)
    textPane:SetPoint("BOTTOMRIGHT", -16, 58)
    textPane.Bg:SetColorTexture(0.06, 0.043, 0.03, 0.94)
    local editScroll = CreateFrame("ScrollFrame", nil, textPane, "ScrollFrameTemplate")
    editScroll:SetPoint("TOPLEFT", 10, -10)
    editScroll:SetPoint("BOTTOMRIGHT", -28, 10)
    local textEdit = CreateFrame("EditBox", nil, editScroll)
    textEdit:SetFontObject(GameFontHighlight)
    textEdit:SetMultiLine(true)
    textEdit:SetAutoFocus(false)
    textEdit:SetWidth(450)
    textEdit:SetHeight(270)
    textEdit:SetMaxLetters(MAX_TEXT)
    editScroll:SetScrollChild(textEdit)
    editScroll:SetScript("OnSizeChanged", function(self, width)
        textEdit:SetWidth(math.max(1, width))
    end)
    editScroll:Show()
    textEdit:Show()
    local nameEdit = CreateFrame("EditBox", nil, modal, "LargeInputBoxTemplate")
    nameEdit:SetPoint("TOPLEFT", 20, -112)
    nameEdit:SetSize(466, 30)
    nameEdit:SetFontObject(GameFontHighlight)
    nameEdit:SetTextInsets(10, 10, 0, 0)
    nameEdit:SetMultiLine(false)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(100)
    local edit = textEdit
    local modalAccept
    local readOnlyText
    local editFocus = Button(modal, "Edit text", 16, -78, 110, function()
        edit:SetFocus()
        if readOnlyText then edit:HighlightText() end
    end, "Select to enter text. Use your keyboard to paste an import or copy an export.")
    editFocus:ClearAllPoints()
    editFocus:SetPoint("BOTTOMLEFT", 16, 16)
    textEdit:SetScript("OnTextChanged", function(self)
        if readOnlyText and self:GetText() ~= readOnlyText then self:SetText(readOnlyText) end
    end)
    local function CloseModal()
        edit:ClearFocus()
        modal:Hide()
        body:Show()
        ns.panel.settingsWindow:FocusEntry(panel, reviewMode and reviewContinue or selector)
    end
    local back = Button(modal, "Back", 394, -78, 96, CloseModal)
    back:ClearAllPoints()
    back:SetPoint("BOTTOMRIGHT", -16, 16)
    local accept = Button(modal, "Continue", 126, -78, 120, function() modalAccept(edit:GetText()) end)
    accept:ClearAllPoints()
    accept:SetPoint("LEFT", editFocus, "RIGHT", 12, 0)
    for _, box in ipairs({textEdit, nameEdit}) do
        box:SetScript("OnEscapePressed", CloseModal)
        box:SetScript("OnEnterPressed", function() modalAccept(edit:GetText()) end)
    end
    modal:HookScript("OnHide", function() edit:ClearFocus() end)
    local function OpenText(titleText, text, description, callback, readOnly, isName)
        edit:ClearFocus()
        edit = isName and nameEdit or textEdit
        body:Hide()
        modalTitle:SetText(titleText)
        instruction:SetText(description)
        fieldLabel:SetText(isName and "Profile name" or readOnly and "Export string" or "Import string")
        nameEdit:SetShown(isName == true)
        textPane:SetShown(not isName)
        modalAccept = callback
        accept:SetText("Continue")
        accept.settingsFocusLabel = "Continue"
        accept:SetShown(not readOnly)
        editFocus:SetText(readOnly and "Select text" or isName and "Edit name" or "Paste text")
        editFocus.settingsFocusLabel = editFocus:GetText()
        readOnlyText = readOnly and text or nil
        edit:SetText(text or "")
        edit:SetCursorPosition(0)
        editScroll:SetVerticalScroll(0)
        modal:Show()
        ns.panel.settingsWindow:FocusEntry(panel, editFocus)
        edit:SetFocus()
        edit:HighlightText()
    end
    local function Confirm(text, callback)
        Widgets.ShowConfirmation("EMOTEPANEL_PROFILE_CONFIRM", text, callback)
    end
    local function Selected()
        local selection = Profiles.Selected(doc, root)
        if #selection.operations == 0 then Widgets.ShowError("Select at least one setting."); return end
        return selection
    end

    autoSave = home:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    autoSave:SetPoint("TOPLEFT", 16, -80)
    autoSave:SetWidth(480)
    autoSave:SetJustifyH("LEFT")
    autoSave:SetWordWrap(true)
    autoSave:SetText("Changes save automatically.")
    local explanation = home:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    explanation:SetPoint("TOPLEFT", 16, -212)
    explanation:SetWidth(480)
    explanation:SetJustifyH("LEFT")
    explanation:SetText("Your character profile is created automatically using your full name. Default contains fresh-install settings.\n\nCharacters using the same named profile share their changes. Save As copies your setup. Import lets you choose what to include before naming a new profile.\n\nUnavailable actions stay saved and appear when your character can use them.")
    local function AskName(imported)
        if not Profiles.IsReady() then Widgets.ShowError("Wait until your profile has finished loading."); return end
        OpenText(imported and "Name Imported Profile" or "Save Profile As",
            Profiles.SuggestName(imported and imported.name or (Profiles.ActiveName() .. " Copy")),
            imported and "Enter a name. Create Profile saves your choices and selects the new profile."
                or ("Enter a new name for a copy of " .. Profiles.ActiveName() .. "."), function(name)
                local approval
                local function Create()
                    local success, reason = Profiles.CreateNamed(name, imported, approval)
                    if not success then Widgets.ShowError(reason); return end
                    CloseModal()
                    ShowHome()
                end
                name = (name or ""):match("^%s*(.-)%s*$")
                if name == "" or #name > 100 or name:find("[%c]") then
                    Widgets.ShowError("Enter a profile name of up to 100 characters on one line."); return
                end
                if Store()[name] ~= nil then Widgets.ShowError("That profile name is already used."); return end
                if imported then
                    local text = "Create and switch to profile " .. name .. "?\n\nChecked fields will be imported. Unchecked fields use addon defaults."
                    local changes
                    approval, changes = BindingConflicts(imported)
                    if changes ~= "" then text = text .. "\n" .. changes end
                    Confirm(text, Create)
                else Create() end
            end, false, true)
        accept:SetText(imported and "Create Profile" or "Save As")
        accept.settingsFocusLabel = accept:GetText()
    end
    Button(home, "Save As", 16, -118, 142, function() AskName() end,
        "Copy your current setup into a new profile and select it.")
    deleteProfile = Button(home, "Delete Profile", 176, -118, 142, function()
        local name = Profiles.ActiveName()
        if name == "Default" then Widgets.ShowError("Default cannot be deleted."); return end
        Confirm("Delete profile " .. name .. "?\n\nCharacters using it will switch to Default.", function()
            local success, reason = Profiles.DeleteNamed(name)
            if not success then Widgets.ShowError(reason); return end
            ShowHome()
        end)
    end, "Delete the selected profile. Default is kept.")
    Button(home, "Import", 16, -160, 142, function()
        OpenText("Import Profile", "", "Paste an EmotePanel export, then select Continue to choose what to import.", function(text)
            local data, reason = Profiles.Decode(text)
            if not data then Widgets.ShowError(reason); return end
            CloseModal()
            SetDocument(data, nil, "import")
        end)
        accept:SetText("Continue")
    end)
    Button(home, "Export", 176, -160, 142, function()
        if not Profiles.IsReady() then Widgets.ShowError("Wait until your profile has finished loading."); return end
        Profiles.SaveActive()
        SetDocument(Profiles.Capture(Profiles.ActiveName()), Profiles.ActiveName(), "export")
    end, "Choose which settings from your active profile to share.")
    reviewContinue = Button(reviewBar, "Continue", 16, -78, 142, function()
        if not Profiles.IsReady() then Widgets.ShowError("Wait until your profile has finished loading."); return end
        local selection = Selected()
        if not selection then return end
        if reviewMode == "import" then
            local completed, reason = Profiles.CompleteImport(selection)
            if not completed then Widgets.ShowError(reason); return end
            local prepared, failure = Profiles.Prepare(completed, false, FreshBase())
            if not prepared then Widgets.ShowError(failure); return end
            AskName(selection)
        else
            local ok, text = pcall(Profiles.Encode, selection)
            if not ok then Widgets.ShowError("The export could not be created."); return end
            OpenText("Export Profile", text, "Select the text and press Ctrl+C to copy it.", CloseModal, true)
        end
    end, "Continue with the checked fields. Import will ask for a new profile name.")
    Button(reviewBar, "Back", 176, -78, 96, ShowHome)
    panel:SetScript("OnShow", ShowHome)
    panel:SetScript("OnHide", function()
        edit:ClearFocus()
        selector:CloseMenu()
        modal:Hide()
        body:Show()
        doc = nil
    end)
    panel.RefreshTree = RefreshTree
    function panel:SetDocument(data, name) SetDocument(data, name) end
    function panel:Back()
        if modal:IsShown() then CloseModal(); return true end
        if reviewMode then ShowHome(); return true end
        return false
    end
    return panel
end
