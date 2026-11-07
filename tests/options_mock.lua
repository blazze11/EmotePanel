widgets = {}
function Widget()
    local w = { scripts = {}, enabled = true, events = {} }
    table.insert(widgets, w)
    function w:SetFrameStrata(value) self.strata = value end
    function w:SetToplevel(value) self.toplevel = value end
    function w:EnableMouseWheel(value) self.mouseWheel = value end
    function w:SetHideIfUnscrollable(value) self.hideIfUnscrollable = value end
    function w:SetHideTrackIfThumbExceedsTrack(value) self.hideTrackIfThumbExceedsTrack = value end
    function w:Update() self.updated = true end
    function w:EnableMouse(value) self.mouse = value end
    function w:SetMovable(value) self.movable = value end
    function w:SetClampedToScreen(value) self.clamped = value end
    function w:RegisterForDrag(...) self.dragButtons = {...} end
    function w:StartMoving() self.moving = true end
    function w:StopMovingOrSizing() self.moving = false end
    function w:Raise() self.raised = true end
    function w:SetAllPoints(target) self.allPoints = target end
    function w:RegisterEvent(event) self.events[event] = true end
    function w:RegisterUnitEvent(event, unit) self.events[event] = unit end
    function w:GetWidth() return self.width or 550 end
    function w:GetHeight() return self.height or 240 end
    function w:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent.GetEffectiveScale and self.parent:GetEffectiveScale() or 1) end
    function w:GetParent() return self.parent end
    function w:SetFocus() self.focus = true end
    function w:Click() if self.enabled and self.scripts.OnClick then self.scripts.OnClick(self) end end
    function w:SetParent(value) self.parent = value end
    function w:CloseMenu() self.menuClosed = true end
    function w:SetupMenu(generator) self.menuGenerator = generator end
    function w:GenerateMenu()
        self.choices = {}
        self.choiceOrder = {}
        local root = { CreateRadio = function(_, text, selected, action, value)
            table.insert(self.choiceOrder,value)
            self.choices[value] = { text = text, selected = selected(value), select = function() action(value) end }
        end }
        self.menuGenerator(self, root)
        if self.steppers then self.steppers:UpdateSteppers() end
    end
    function w:SetHeight(value) self.height = value end
    function w:SetClipsChildren(value) self.clips = value end
    function w:SetBackdropColor(...) self.bgColor = {...} end
    function w:SetBackdropBorderColor(...) self.borderColor = {...} end
    function w:SetShown(value) if value then self:Show() else self:Hide() end end
    function w:GetStringWidth() return #(self.text or '')*(self.fontSize or 12)*0.55 end
    function w:SetScale(value) self.scale = value end
    function w:SetFont(path, size, flags) self.fontPath, self.fontSize, self.fontFlags = path, size, flags end
    function w:ClearAllPoints() self.point = nil; self.points = {} end
    function w:SetButtonState(state, locked) self.buttonState, self.locked = state, locked end
    function w:SetSize(x, y) self.width, self.height = x, y end
    function w:SetFrameLevel(value) self.frameLevel = value end
    function w:GetFrameLevel() return self.frameLevel or 1 end
    function w:SetWordWrap(value) self.wordWrap = value end
    function w:SetAlpha(value) self.alpha = value end
    function w:GetAlpha() return self.alpha or 1 end
    function w:SetWidth(x) self.width = x end
    function w:SetPoint(...) self.point = {...}; self.points = self.points or {}; self.points[self.point[1]] = self.point end
    function w:SetJustifyH(value) self.justify = value end
    function w:SetJustifyV(value) self.justifyV = value end
    function w:SetFontString(value) self.fontString = value end
    function w:SetHighlightTexture(value) self.highlight = value end
    function w:SetText(value) self.text = value end
    function w:GetText() return self.text end
    function w:SetFormattedText(format, ...)
        self.formattedValues = {...}
        self.format = format
        for _, value in ipairs(self.formattedValues) do
            if type(value) == 'table' then self.text = '<secret>'; return end
        end
        self.text = string.format(format, ...)
    end
    function w:SetTextColor(...) self.color = {...} end
    function w:SetScript(name, callback) self.scripts[name] = callback end
    function w:HookScript(name, callback)
        local previous = self.scripts[name]
        self.scripts[name] = function(...) if previous then previous(...) end;callback(...) end
    end
    function w:IsShown() return self.shown end
    function w:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function w:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function w:CreateAnimationGroup()
        local group = {scripts={}}
        function group:CreateAnimation()
            local alpha={}
            function alpha:SetDuration(v) self.duration=v end
            function alpha:SetFromAlpha(v) self.from=v end
            function alpha:SetToAlpha(v) self.to=v end
            self.alpha=alpha;return alpha
        end
        function group:SetToFinalAlpha(v) self.finalAlpha=v end
        function group:SetScript(k,v) self.scripts[k]=v end
        function group:Play() self.playing=true end
        function group:Stop() self.playing=false end
        function group:Finish() self.playing=false;self.scripts.OnFinished() end
        return group
    end
    function w:CreateFontString() return Widget() end
    function w:CreateTexture()
        local texture = AddTextureMethods(Widget())
        texture.parent = self
        return texture
    end
    function w:SetColorTexture(...) self.color = {...} end
    function w:SetChecked(value) self.checked = value end
    function w:GetChecked() return self.checked end
    function w:SetEnabled(value) self.enabled = value end
    function w:Enable() self.enabled = true end
    function w:Disable() self.enabled = false end
    function w:SetScrollChild(value) self.child = value end
    function w:SetMultiLine(value) self.multiLine = value end
    function w:SetFontObject(value) self.fontObject = value end
    function w:GetVerticalScroll() return self.verticalScroll or 0 end
    function w:SetVerticalScroll(value) self.verticalScroll = value end
    function w:UpdateScrollChildRect() self.scrollChildUpdated = true end
    function w:SetAutoFocus(value) self.autoFocus = value end
    function w:SetMaxLetters(value) self.maxLetters = value end
    function w:ClearFocus()
        local hadFocus = self.focus
        self.focus = false
        if hadFocus and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
    end
    function w:HighlightText() self.highlighted = true end
    function w:SetOrientation(value) self.orientation = value end
    function w:SetMinMaxValues(a,b) self.min,self.max = a,b end
    function w:GetValue() return self.value end
    function w:GetValueStep() return self.step end
    function w:GetMinMaxValues() return self.min,self.max end
    function w:SetValueStep(value) self.step = value end
    function w:SetObeyStepOnDrag(value) self.obeyStep = value end
    function w:SetBackdrop(value) self.backdrop = value end
    function w:SetThumbTexture(value) self.thumbPath = value end
    function w:GetThumbTexture() self.thumb = self.thumb or Widget(); return self.thumb end
    function w:SetValue(value)
        self.value = value
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
    end
    return w
end
CreateFrame = function(frameType, name, parent, template)
    local w = Widget()
    if template == 'SettingsFrameTemplate' then
        w.NineSlice = {Text = Widget()}
        w.ClosePanelButton = Widget()
        w.ClosePanelButton:SetScript('OnClick',function() w:Hide() end)
    elseif template == 'BasicFrameTemplateWithInset' then
        w.TitleText,w.CloseButton = Widget(),Widget()
        w.CloseButton:SetScript('OnClick',function() w:Hide() end)
    elseif template == 'MinimalSliderWithSteppersTemplate' then
        w.Slider,w.Back,w.Forward = Widget(),Widget(),Widget()
        function w:UpdateStepperStates()
            self.Back:SetEnabled(self.enabled and self.Slider.value > self.Slider.min)
            self.Forward:SetEnabled(self.enabled and self.Slider.value < self.Slider.max)
        end
        function w:Init(value,low,high,steps)
            local slider = self.Slider
            slider:SetMinMaxValues(low,high);slider:SetValueStep((high-low)/steps);slider:SetValue(value)
            local setValue = slider.SetValue
            slider.SetValue = function(o,v) setValue(o,math.max(o.min,math.min(o.max,v))) end
            slider:SetScript('OnValueChanged',function(_,v)
                self:UpdateStepperStates()
                if self.callback then self.callback(self.callbackOwner,v) end
            end)
            self:UpdateStepperStates()
        end
        function w:RegisterCallback(event,callback,owner) self.callback,self.callbackOwner = callback,owner end
        function w:SetEnabled(value) self.enabled=value;self.Slider:SetEnabled(value);self:UpdateStepperStates() end
        w.Back:SetScript('OnClick',function() if w.Back.enabled then w.Slider:SetValue(w.Slider.value-w.Slider.step) end end)
        w.Forward:SetScript('OnClick',function() if w.Forward.enabled then w.Slider:SetValue(w.Slider.value+w.Slider.step) end end)
    elseif template == 'SettingsDropdownWithButtonsTemplate' then
        w.Dropdown,w.DecrementButton,w.IncrementButton = Widget(),Widget(),Widget()
        w.Dropdown.frameType = 'DropdownButton'
        function w:UpdateSteppers()
            local d,index = self.Dropdown,nil
            for i,v in ipairs(d.choiceOrder) do if d.choices[v].selected then index=i end end
            self.DecrementButton:SetEnabled(d.enabled and index ~= nil and index>1)
            self.IncrementButton:SetEnabled(d.enabled and index ~= nil and index<#d.choiceOrder)
        end
        local function step(delta)
            local d = w.Dropdown
            for i,v in ipairs(d.choiceOrder) do
                if d.choices[v].selected then
                    local nextValue=d.choiceOrder[i+delta]
                    if nextValue ~= nil then d.choices[nextValue].select() end
                    return
                end
            end
        end
        w.DecrementButton:SetScript('OnClick',function() if w.DecrementButton.enabled then step(-1) end end)
        w.IncrementButton:SetScript('OnClick',function() if w.IncrementButton.enabled then step(1) end end)
    elseif template == 'ColorSwatchTemplate' then
        w.Color = AddTextureMethods(Widget())
        function w:SetColorRGB(r,g,b) self.Color:SetVertexColor(r,g,b) end
    end
    w.frameType, w.name, w.parent, w.template = frameType, name, parent, template
    return w
end
UISpecialFrames = {}
local nextCategoryID = 123
Settings = {
    subcategoryRegistrations = 0,
    RegisterCanvasLayoutCategory = function(panel, name)
        return { GetID = function() return 123 end, name = name, panel = panel }
    end,
    RegisterCanvasLayoutSubcategory = function(parent, panel, name)
        Settings.subcategoryRegistrations = Settings.subcategoryRegistrations + 1
        nextCategoryID = nextCategoryID + 1
        local id = nextCategoryID
        return { GetID = function() return id end, parent = parent, panel = panel, name = name }
    end,
    RegisterAddOnCategory = function(category) Settings.registered = category end,
    OpenToCategory = function(id) Settings.opened = id end,
}
SettingsPanel = Widget()
HideUIPanel = function(panel) panel:Hide() end

function AddTextureMethods(texture)
    function texture:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
    function texture:SetAtlas(name, useAtlasSize)
        self.atlas = name
        if useAtlasSize then self:SetSize(20,20) end
    end
    function texture:SetDesaturated(value) self.desaturated = value end
    function texture:SetRadialProgressBarStartOffset(value) self.radialStart = value end
    function texture:SetRadialProgressBarEndOffset(value) self.radialEnd = value end
    function texture:SetRadialProgressBarReverse(value) self.radialReverse = value end
    function texture:SetRadialProgressBarPercent(value) self.radialPercent = value end
    function texture:SetRotation(value) self.rotation = value end
    -- Native texture vertex alpha and SetAlpha share one value. Keep this
    -- coupled so a later count-alpha write cannot silently bypass opacity tests.
    function texture:SetAlpha(value)
        self.alpha = value
        if self.color then self.color[4] = value end
    end
    function texture:SetVertexColor(r,g,b,a)
        self.color = {r,g,b}
        self:SetAlpha(a or 1)
    end
    function texture:SetTexture(path, h, v, filter) self.path = path; self.filter = filter end
    function texture:SetSnapToPixelGrid(value) self.snap = value end
    function texture:SetTexelSnappingBias(value) self.bias = value end
    return texture
end

Enum = Enum or {}
C_CurveUtil = { CreateCurve = function()
    local curve = { points = {} }
    function curve:SetType(kind) self.kind = kind end
    function curve:AddPoint(x,y) table.insert(self.points, {x,y}) end
    function curve:Evaluate(x)
        if issecretvalue and issecretvalue(x) then return x end
        if x <= self.points[1][1] then return self.points[1][2] end
        for i=2,#self.points do
            local a,b = self.points[i-1],self.points[i]
            if x < b[1] then
                if self.kind == Enum.LuaCurveType.Step then return a[2] end
                return a[2] + (b[2]-a[2])*(x-a[1])/(b[1]-a[1])
            end
        end
        return self.points[#self.points][2]
    end
    curve.Eval = curve.Evaluate
    return curve
end }

GameFontHighlightSmall = { GetFont = function() return 'Fonts\\FRIZQT__.TTF', 10, '' end }

Mixin = function(target, source) for key,value in pairs(source) do target[key] = value end end

MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = "OnValueChanged" } }

-- Native ScrollUtil owns scrolling; this mock records the integration only.
ScrollUtil = { InitScrollFrameWithScrollBar = function(scroll, bar)
    scroll.boundScrollBar = bar
end }

StaticPopupDialogs = {}
local function AcceptPopup(popup)
    assert(popup and popup.shown)
    if not popup:GetButton1().enabled then return end
    local keepOpen = StaticPopupDialogs[popup.which].OnAccept(popup, popup.data)
    if not keepOpen then popup:Hide() end
end
StaticPopup_Show = function(which, arg1, arg2, data)
    StaticPopup_Hide(which)
    local dialog = StaticPopupDialogs[which]
    local popup = Widget()
    popup.which, popup.data, popup.text = which, data, string.format(dialog.text, arg1, arg2)
    popup.SubText, popup.edit, popup.acceptButton = Widget(), Widget(), Widget()
    popup.edit.parent = popup
    function popup:GetEditBox() return self.edit end
    function popup:GetButton1() return self.acceptButton end
    function popup:Resize() self.resized = true end
    popup.acceptButton:SetScript('OnClick',function() AcceptPopup(popup) end)
    if dialog.hasEditBox then
        local setText = popup.edit.SetText
        function popup.edit:SetText(text)
            setText(self,text)
            if dialog.EditBoxOnTextChanged then dialog.EditBoxOnTextChanged(self,popup.data) end
        end
    end
    popup:SetScript('OnShow',function() if dialog.OnShow then dialog.OnShow(popup,popup.data) end end)
    popup:SetScript('OnHide',function()
        if dialog.OnHide then dialog.OnHide(popup,popup.data) end
        popup.edit:SetText('')
    end)
    activeStaticPopup = popup
    popup:Show()
    return popup
end
StaticPopup_Hide = function(which)
    local popup = activeStaticPopup
    if popup and popup.which == which then popup:Hide() end
end
function AcceptStaticPopup() AcceptPopup(activeStaticPopup) end
function CancelStaticPopup()
    local popup = activeStaticPopup
    assert(popup and popup.shown)
    StaticPopupDialogs[popup.which].OnCancel(popup, popup.data)
    popup:Hide()
end
