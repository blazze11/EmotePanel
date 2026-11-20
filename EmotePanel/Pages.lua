local _, ns = ...
local EmotePanel = ns.panel

local Entries = ns.Entries
local Bindings = ns.Bindings
local Pages = ns.Pages
local SettingsUI = ns.SettingsUI
local ActionPicker = ns.ActionPicker

local ACTIONS_TITLE = "Actions"
local PET_TITLE = "Pet"
local categoryOrder = { "emotes", "voicedEmotes", "chat", "party", "commands", "interactions", "panels" }
local categoryPages = {}
local petPages = {}
local TARGET_MARKER_START = "target-markers"
local targetMarkerPage = {
    mode = "targetMarkers", title = "Target Marker", count = 8,
    entries = {8, 7, 6, 5, 4, 3, 2, 1},
}
local pingPage = {
    mode = "pings", title = Entries.categoryByID.pings.name, count = 6,
    entries = {1, 2, 3, 4, 5, 6},
}
local markerOrigin
local professionPage = { mode = "professions", title = "Professions", count = 0, entries = {} }
local grouped
local visibleFavorites

local function IsCategoryWheelEnabled()
    return EmotePanelSavedVars.categoryWheel ~= false
end

local function BuildPetPages()
    if not EmotePanel.supportsPetWheel then return end
    -- Secure actions target native slots, which can change even when the visible keys match.
    EmotePanel.combatLayoutDirty = true
    local entries = Entries.GetVisibleEntryIDs("pet")
    local previous = petPages[1] and petPages[1].entries
    if previous and #previous == #entries then
        for index, key in ipairs(entries) do
            if previous[index] ~= key then
                previous = nil
                break
            end
        end
        -- Status changes should leave presses on the current page intact.
        if previous then return end
    end
    wipe(petPages)
    -- Pet pages use negative IDs so main-wheel paging never visits them.
    local count = math.max(1, math.ceil(#entries / ns.SECTOR_COUNT))
    for page = 1, count do
        local first = (page - 1) * ns.SECTOR_COUNT + 1
        petPages[page] = {
            mode = "pet", first = first, entries = entries, count = math.min(ns.SECTOR_COUNT, #entries - first + 1),
            title = count == 1 and PET_TITLE or ("%s  %d / %d"):format(PET_TITLE, page, count),
            left = page > 1 and 1 - page or nil,
            right = page < count and -page - 1 or nil,
        }
    end
end

local function BuildCategoryPages()
    wipe(categoryPages)
    local function AddPages(category, title)
        local mode = Entries.GetStorageMode(category)
        local entries, leaveGroup
        if mode == "macros" then
            entries, leaveGroup = Entries.GetWheelActionIDs()
        else
            entries = Entries.GetVisibleEntryIDs(category)
        end
        local pageCount = math.ceil(#entries / ns.SECTOR_COUNT)
        if leaveGroup then pageCount = pageCount + 1 end
        for page = 1, pageCount do
            -- Actions advance left from the opening page.
            local number = mode == "macros" and pageCount - page + 1 or page
            local first = (number - 1) * ns.SECTOR_COUNT + 1
            local pageIndex = mode == "panels" and number or #categoryPages + 1
            local dedicatedPage = leaveGroup and number == pageCount
            table.insert(categoryPages, pageIndex, {
                mode = mode,
                category = category,
                number = number,
                first = dedicatedPage and 1 or first,
                entries = dedicatedPage and {leaveGroup} or entries,
                count = dedicatedPage and 1 or math.min(ns.SECTOR_COUNT, #entries - first + 1),
                title = ("%s  %d / %d"):format(title, number, pageCount),
            })
        end
    end
    for _, category in ipairs(categoryOrder) do
        AddPages(category, category == "voicedEmotes" and Entries.voicedEmoteTitle or Entries.PANEL_MODES[category].title)
    end
    table.insert(categoryPages, professionPage)
    if Entries.GetPingCommand() then table.insert(categoryPages, pingPage) end
    AddPages("macros", ACTIONS_TITLE)
end

local function RefreshVisibleFavorites()
    -- The favorite count offsets every other main-wheel page ID.
    EmotePanel.combatLayoutDirty = true
    visibleFavorites = {}
    for _, entry in ipairs(Entries.GetFavorites()) do
        if Entries.IsEntryVisible(entry.mode, entry.index) then
            table.insert(visibleFavorites, entry)
        end
    end
end

local function RefreshProfessionPage()
    professionPage.entries = Entries.GetVisibleEntryIDs("professions")
    professionPage.count = #professionPage.entries
end

local function RefreshProfessions()
    Entries.ReadProfessions()
    RefreshProfessionPage()
    RefreshVisibleFavorites()
end

local function FavoritePageCount()
    return math.max(1, math.ceil(#visibleFavorites / ns.SECTOR_COUNT))
end

local function GetPage(index)
    if index == TARGET_MARKER_START then return targetMarkerPage end
    if index < 0 then return petPages[-index] end
    local count = FavoritePageCount()
    if index > count then return categoryPages[index - count] end
    local first = (index - 1) * ns.SECTOR_COUNT + 1
    return {
        mode = "favorites",
        first = first,
        count = math.min(ns.SECTOR_COUNT, #visibleFavorites - first + 1),
        title = count == 1 and "Favorites" or ("Favorites  %d / %d"):format(index, count),
    }
end

local function GetCategoryPageRange(category)
    local offset = FavoritePageCount()
    if category == "favorites" then return 1, offset end
    local first, last
    for index, page in ipairs(categoryPages) do
        if (page.category or page.mode) == category then
            first = first or index + offset
            last = index + offset
        end
    end
    return first, last
end

local function GetMainPageCount()
    return FavoritePageCount() + #categoryPages
end

local function GetPetPageCount()
    return #petPages
end

local function GetScrollPages(index, page, nested)
    if page.mode == "pet" then return page.right, page.left end
    if page.mode == "targetMarkers" then return end
    if page.mode == "categories" then
        local _, firstActions = GetCategoryPageRange("macros")
        return firstActions, nil
    end
    if not index then return end

    if page.mode == "macros" then
        -- Actions are stored in reverse order for the controller's left shortcut.
        local last, first = GetCategoryPageRange("macros")
        local previous = index < first and index + 1 or (nested and 0 or last - 1)
        return index > last and index - 1 or nil, previous
    end
    if nested then
        local first, last = GetCategoryPageRange(page.category or page.mode)
        return index < last and index + 1 or nil, index > first and index - 1 or nil
    end
    -- Favorites-first is a single list. Scroll through Actions in page-number order at its end.
    local lastActions, firstActions = GetCategoryPageRange("macros")
    local last = lastActions and lastActions - 1 or GetMainPageCount()
    return index < last and index + 1 or firstActions, index > 1 and index - 1 or nil
end

-- Page 0 is the Categories destination. Pet pages use negative IDs.
-- Mouse scroll is bounded independently of the controller's wrap and Actions shortcut.
local function GetPageNavigation(index, page)
    local nested = IsCategoryWheelEnabled()
    local stop = EmotePanelSavedVars.stopAtPageEnds
    local scrollUp, scrollDown = GetScrollPages(index, page, nested)
    local nav = { scrollUp = scrollUp, scrollDown = scrollDown }
    if page.mode == "pet" then
        nav.left, nav.right = page.left, page.right
    elseif page.mode == "targetMarkers" then
        nav.back = true
    elseif page.mode == "categories" then
        local _, firstActions = GetCategoryPageRange("macros")
        nav.left = firstActions
    elseif not nested then
        local last = GetMainPageCount()
        if index > 1 or not stop then nav.left = (index - 2) % last + 1 end
        if index < last or not stop then nav.right = index % last + 1 end
    else
        local first, last = GetCategoryPageRange(page.category or page.mode)
        if page.mode ~= "pings" then nav.back = 0 end
        if page.mode == "macros" then
            if index > first then nav.left = index - 1 end
            if index < last then nav.right = index + 1
            elseif not stop then nav.right = 0 end
        elseif index and first ~= last then
            if index > first or not stop then nav.left = index > first and index - 1 or last end
            if index < last or not stop then nav.right = index < last and index + 1 or first end
        end
    end
    return nav
end

local function GetCategoryDestination(data)
    if data.category == "targetMarkers" then return TARGET_MARKER_START end
    local first = GetCategoryPageRange(data.category)
    if first then return first end
    return nil, { mode = data.category, title = data.name, count = 0 }
end

local function GetSectorEntry(sector, page, forCombatLayout)
    page = page or Pages.currentPage
    if not sector or sector < 1 or sector > page.count then return end
    if page.mode == "pet" and page.actions then
        -- Keep the secure mapping to native slots and show what each slot currently does.
        local slot = page.actions[sector].value
        local data = slot and Entries.GetPetAction(slot)
        if data then return "pet", data.key, data end
        return
    end
    if page.snapshot then
        local mode, index, data = unpack(page.snapshot[sector])
        if data and Entries.IsInviteHidden(mode, index, data) then return mode, index end
        return mode, index, data
    end
    local mode = page.mode
    if mode == "categories" then
        local id = page.entries[sector]
        return mode, id, Entries.GetEntryData(mode, id)
    end
    local index = (page.first or 1) + sector - 1
    if mode == "favorites" then
        local entry = visibleFavorites[index]
        mode, index = entry.mode, entry.index
    else
        index = page.entries[index]
    end
    if not index then return end
    local data = Entries.GetEntryData(mode, index)
    if data and data.fixedSector and not data.available() then return mode, index end
    if data and not forCombatLayout and Entries.IsInviteHidden(mode, index, data) then return mode, index end
    return mode, index, data
end

function EmotePanel:RememberAction(sector)
    if not EmotePanelSavedVars.rememberLastAction or Pages.currentPage.mode == "targetMarkers"
        or Pages.currentPage.mode == "pings" then return end
    local mode, key, data = GetSectorEntry(sector)
    if not data then return end
    local last = { pageMode = Pages.currentPage.mode, mode = mode, key = key }
    if mode == "pet" then
        self.lastPetAction = last
    else
        self.lastAction = last
    end
    if not self.combatView then self:SyncCombatResume() end
end

function EmotePanel:FindRememberedSector(page)
    local last = page.mode == "pet" and self.lastPetAction or self.lastAction
    if not last or last.pageMode ~= page.mode then return end
    for sector = 1, page.count do
        local mode, key, data = GetSectorEntry(sector, page)
        if mode == last.mode and key == last.key and data
            and not (InCombatLockdown() and Entries.IsOutOfCombat(mode, key, data)) then
            return sector
        end
    end
end

local function SetDisplayedPage(index, page)
    -- Rendering and input read the same displayed page, including during combat.
    Pages.currentPageIndex, Pages.currentPage = index, page
end

function EmotePanel:DisplayPage(index, page, selection, navigation)
    if self.combatView then return end
    local changedPage = index ~= Pages.currentPageIndex or page.mode ~= Pages.currentPage.mode
    SetDisplayedPage(index, page)
    local nav = GetPageNavigation(index, page)
    self.canPageLeft = nav.left ~= nil
    self.canPageRight = nav.right ~= nil
    self.canGoBack = nav.back ~= nil
    if changedPage then self.wheelTooltip:Hide() end
    self:RefreshWheel(selection)
    if changedPage then
        self:AnimateWheelPage(navigation)
        if self.frame:IsShown() then self:ShowWheelEntryTooltip(self.selected) end
    end
end

function EmotePanel:ShowPage(index, selection, navigation)
    self:DisplayPage(index, GetPage(index), selection, navigation)
end

function EmotePanel:RefreshNavigationLimits()
    self.combatLayoutDirty = true
    if self.combatView then return end
    self:DisplayPage(Pages.currentPageIndex, Pages.currentPage, self.selected)
end

local function MakeCategoryWheel()
    local entries = Entries.GetVisibleEntryIDs("categories")
    return { mode = "categories", title = "Categories", entries = entries, count = #entries }
end

local function FindSector(page, mode, key)
    if key == nil then return end
    for sector = 1, page.count do
        local entryMode, entryKey, data = GetSectorEntry(sector, page)
        if data and entryMode == mode and entryKey == key then return sector end
    end
end

function EmotePanel:RestoreCombatPage(selection, origin)
    local previous = Pages.currentPage
    local category = previous.category or previous.mode
    local mode, key = GetSectorEntry(selection, previous)
    local offset = previous.number and previous.number - 1 or math.floor(((previous.first or 1) - 1) / ns.SECTOR_COUNT)

    Entries.ReadPetActions()
    Entries.RefreshCarriedActionItems()
    Entries.ReadAutomaticActions()
    BuildPetPages()
    BuildCategoryPages()
    RefreshProfessionPage()
    RefreshVisibleFavorites()
    if IsCategoryWheelEnabled() then Pages.categoryWheel = MakeCategoryWheel() end
    markerOrigin = origin and origin.mode

    if category == "categories" then
        self:DisplayPage(nil, Pages.categoryWheel, FindSector(Pages.categoryWheel, mode, key))
    elseif category == "targetMarkers" then
        self:ShowPage(TARGET_MARKER_START, FindSector(targetMarkerPage, mode, key))
    else
        local first, last = GetCategoryPageRange(category)
        if category == "pet" then first, last = -#petPages, -1 end
        if first then
            if key ~= nil then
                for index = first, last do
                    local sector = FindSector(GetPage(index), mode, key)
                    if sector then
                        self:ShowPage(index, sector)
                        return
                    end
                end
            end
            local reverse = category == "macros" or category == "pet"
            self:ShowPage(reverse and math.max(first, last - offset) or math.min(last, first + offset))
        elseif IsCategoryWheelEnabled() and Entries.categoryByID[category] then
            local _, empty = GetCategoryDestination(Entries.categoryByID[category])
            self:DisplayPage(nil, empty)
        else
            self:ShowStartPage()
        end
    end
end

function EmotePanel:ShowStartPage(resume, navigation)
    if self.combatView then return end
    markerOrigin = nil
    self.combatLayoutDirty = true
    if IsCategoryWheelEnabled() then
        Pages.categoryWheel = MakeCategoryWheel()
    end
    if resume and EmotePanelSavedVars.rememberLastAction and self.lastAction then
        for index = 1, GetMainPageCount() do
            local page = GetPage(index)
            local sector = self:FindRememberedSector(page)
            if sector then
                self:DisplayPage(index, page, sector)
                return
            end
        end
    end
    if IsCategoryWheelEnabled() then
        self:DisplayPage(nil, Pages.categoryWheel, 1, navigation)
    else
        self:ShowPage(1, 1)
    end
end

function EmotePanel:ShowPetStartPage()
    self.combatLayoutDirty = true
    if EmotePanelSavedVars.rememberLastAction and self.lastPetAction then
        for index, page in ipairs(petPages) do
            local sector = self:FindRememberedSector(page)
            if sector then
                self:ShowPage(-index, sector)
                return
            end
        end
    end
    self:ShowPage(-1, 1)
end

function EmotePanel:ShowTargetMarkers()
    markerOrigin = Pages.currentPage.mode
    self:ShowPage(TARGET_MARKER_START, 1, true)
end

function EmotePanel:BackOrClose()
    if Pages.currentPage.mode == "pings" then
        self.frame:Hide()
        return
    end
    if Pages.currentPage.mode == "targetMarkers" then
        if markerOrigin == "categories" then
            for sector, id in ipairs(Pages.categoryWheel.entries) do
                if id == "targetMarkers" then
                    markerOrigin = nil
                    self:DisplayPage(nil, Pages.categoryWheel, sector, true)
                    return
                end
            end
        end
        local first, last = GetCategoryPageRange(markerOrigin)
        markerOrigin = nil
        if first then
            for index = first, last do
                local page = GetPage(index)
                for sector = 1, page.count do
                    local _, _, data = GetSectorEntry(sector, page)
                    if data and data.actionType == "submenu" then
                        self:ShowPage(index, sector, true)
                        return
                    end
                end
            end
            self:ShowPage(first, 1, true)
        else
            self:ShowStartPage(nil, true)
        end
        return
    end
    if IsCategoryWheelEnabled() and Pages.currentPage ~= Pages.categoryWheel and Pages.currentPage.mode ~= "pet" then
        local category = Pages.currentPage.category or Pages.currentPage.mode
        for index, id in ipairs(Pages.categoryWheel.entries) do
            if id == category then
                self:DisplayPage(nil, Pages.categoryWheel, index, true)
                return
            end
        end
        self:ShowStartPage(nil, true)
        return
    end
    self.frame:Hide()
end

function EmotePanel:RefreshEntryPages()
    Entries.RefreshCarriedActionItems()
    BuildCategoryPages()
    BuildPetPages()
    RefreshProfessionPage()
    RefreshVisibleFavorites()
    if Pages.currentPage.mode == "pet" then
        self:RefreshPetPage()
    else
        self:ShowStartPage()
    end
end

function EmotePanel:RefreshPetPage()
    if self.combatView then
        self:RefreshWheel()
    else
        self:ShowPage(math.max(Pages.currentPageIndex, -#petPages), self.selected)
    end
end

function EmotePanel:RefreshCurrentEntryPages()
    if self.combatView or Pages.currentPage.mode == "pet" then
        BuildCategoryPages()
        RefreshVisibleFavorites()
        self:RefreshWheel()
        return
    end
    local category = Pages.currentPage.category or Pages.currentPage.mode
    local first, last = GetCategoryPageRange(category)
    local actions = category == "macros"
    local pageOffset = Pages.currentPageIndex and first
        and (actions and last - Pages.currentPageIndex or Pages.currentPageIndex - first) or 0
    BuildCategoryPages()
    RefreshVisibleFavorites()

    local newFirst, newLast = GetCategoryPageRange(category)
    if newFirst then
        local page = actions and math.max(newFirst, newLast - pageOffset) or math.min(newFirst + pageOffset, newLast)
        self:ShowPage(page, self.selected)
    elseif first and IsCategoryWheelEnabled() and not actions then
        self:DisplayPage(nil, { mode = category, title = Entries.PANEL_MODES[category].title, count = 0 })
    elseif first then
        self:ShowStartPage()
    elseif Pages.currentPage == Pages.categoryWheel or category == "targetMarkers" then
        self:DisplayPage(Pages.currentPageIndex, Pages.currentPage, self.selected)
    end
end

function EmotePanel:RefreshGroupEntries()
    local inGroup = not not IsInGroup()
    if inGroup == grouped then return end
    grouped = inGroup
    if not InCombatLockdown() and not self.combatView then Entries.ReadAutomaticActions() end
    self:RefreshCurrentEntryPages()
end

function EmotePanel:CycleMode(direction)
    local nav = GetPageNavigation(Pages.currentPageIndex, Pages.currentPage)
    local destination = direction < 0 and nav.left or direction > 0 and nav.right
    if destination == 0 then
        self:ShowStartPage(nil, true)
    elseif destination then
        self:ShowPage(destination, 1, true)
    end
end

function EmotePanel:GetRemovableWheelAction()
    if self.combatView or InCombatLockdown() then return end
    local mode, key, data = GetSectorEntry(self.selected)
    if mode == "macros" and data and not data.automatic and not Bindings.IsWheelOpener("PADBACK") then return key, data end
end

function EmotePanel:ToggleFavorite()
    if Pages.currentPage == Pages.categoryWheel or Pages.currentPage.mode == "pet"
        or Pages.currentPage.mode == "targetMarkers" or Pages.currentPage.mode == "pings" then return end
    local mode, slot, data = GetSectorEntry(self.selected)
    if not data or data.automatic then return end
    local previousPageCount = FavoritePageCount()
    Entries.ToggleFavorite(mode, slot)
    RefreshVisibleFavorites()

    local newPageCount = FavoritePageCount()
    local page = Pages.currentPageIndex
    if Pages.currentPage.mode == "favorites" then
        page = math.min(page, newPageCount)
    else
        page = page + newPageCount - previousPageCount
    end
    self:ShowPage(page, self.selected)
    SettingsUI.RefreshEntryList()
end

local function Initialize()
    Entries.ReadPetActions()
    BuildPetPages()
    Entries.ReadActions()
    if not InCombatLockdown() then Entries.ReadAutomaticActions() end
    Entries.RefreshCarriedActionItems()
    Entries.LoadFavorites()
    grouped = not not IsInGroup()
    RefreshProfessions()
    BuildCategoryPages()
    SetDisplayedPage(1, GetPage(1))
end

local function HandleAutomaticActionsChanged()
    if InCombatLockdown() or EmotePanel.combatView then return end
    if Entries.ReadAutomaticActions() then EmotePanel:RefreshCurrentEntryPages() end
end

local function HandleCarriedItemsChanged()
    if Entries.RefreshCarriedActionItems() then
        EmotePanel:RefreshCurrentEntryPages()
    elseif EmotePanel.frame:IsShown() then
        EmotePanel:RefreshActionCooldowns()
    end
    ActionPicker.Refresh("item")
end

local function HandlePetActionsChanged()
    Entries.ReadPetActions()
    BuildPetPages()
    if EmotePanel.frame:IsShown() and Pages.currentPage.mode == "pet" then
        if not EmotePanel.combatView and not InCombatLockdown() then
            local dead = UnitIsDead("pet")
            if not Entries.HasSummonedPet() or (not issecretvalue(dead) and dead) then
                EmotePanel.frame:Hide()
            end
        end
        if EmotePanel.frame:IsShown() then EmotePanel:RefreshPetPage() else EmotePanel:SyncCombatWheel() end
    elseif EmotePanel.frame:IsShown() and not EmotePanel.combatView then
        EmotePanel:RefreshWheel()
    else
        EmotePanel:SyncCombatWheel()
    end
    SettingsUI.RefreshEntryList()
end

local function HandleProfessionsChanged()
    local helpPanel = SettingsUI.GetVisibleEntryList()
    if EmotePanel.combatView then
        RefreshProfessions()
        if helpPanel then helpPanel:refresh() end
        return
    end
    if EmotePanel.frame:IsShown() then
        local mode, slot = GetSectorEntry(EmotePanel.selected)
        local previousPageCount = FavoritePageCount()
        local wasFavoritePage = Pages.currentPage.mode == "favorites"
        RefreshProfessions()
        if helpPanel then helpPanel:refresh() end
        if not Pages.currentPageIndex or Pages.currentPage.mode == "pet" or Pages.currentPage.mode == "targetMarkers" then return end
        local pageCount = FavoritePageCount()
        local page = Pages.currentPageIndex + pageCount - previousPageCount
        if wasFavoritePage then
            page = math.min(Pages.currentPageIndex, pageCount)
            for position, entry in ipairs(visibleFavorites) do
                if entry.mode == mode and entry.index == slot then
                    EmotePanel:ShowPage(math.floor((position - 1) / ns.SECTOR_COUNT) + 1, (position - 1) % ns.SECTOR_COUNT + 1)
                    return
                end
            end
        elseif Pages.currentPage == professionPage then
            for sector, skillLine in ipairs(professionPage.entries) do
                if skillLine == slot then
                    EmotePanel:ShowPage(page, sector)
                    return
                end
            end
        end
        EmotePanel:ShowPage(page)
    elseif helpPanel then
        RefreshProfessions()
        helpPanel:refresh()
    end
end

Pages.ACTIONS_TITLE = ACTIONS_TITLE
Pages.TARGET_MARKER_START = TARGET_MARKER_START
Pages.BuildCategoryPages = BuildCategoryPages
Pages.BuildPetPages = BuildPetPages
Pages.GetCategoryPageRange = GetCategoryPageRange
Pages.GetPage = GetPage
Pages.GetScrollPages = GetScrollPages
Pages.GetSectorEntry = GetSectorEntry
Pages.IsCategoryWheelEnabled = IsCategoryWheelEnabled
Pages.MakeCategoryWheel = MakeCategoryWheel
Pages.PET_TITLE = PET_TITLE
Pages.RefreshProfessions = RefreshProfessions
Pages.RefreshVisibleFavorites = RefreshVisibleFavorites
Pages.categoryOrder = categoryOrder
Pages.professionPage = professionPage

Pages.GetPageNavigation = GetPageNavigation
Pages.GetCategoryDestination = GetCategoryDestination
Pages.GetMainPageCount = GetMainPageCount
Pages.GetPetPageCount = GetPetPageCount
Pages.Initialize = Initialize
Pages.HandleCarriedItemsChanged = HandleCarriedItemsChanged
Pages.HandleAutomaticActionsChanged = HandleAutomaticActionsChanged
Pages.HandlePetActionsChanged = HandlePetActionsChanged
Pages.HandleProfessionsChanged = HandleProfessionsChanged
Pages.SetDisplayedPage = SetDisplayedPage
