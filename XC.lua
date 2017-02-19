--------------------------------------------------------------------------------
-- eXtended Commands v1.01 (2017) by _brain                                    -
--------------------------------------------------------------------------------
XC = {}

--------------------------------------------------------------------------------
-- Variables                                                                   -
--------------------------------------------------------------------------------

XC.spellCache = {}
XC.currentMacro = nil
XC.actions = {}
XC.lastUpdate = 0
XC.currentAction = nil
XC._ = {}

--------------------------------------------------------------------------------
-- Misc                                                                        -
--------------------------------------------------------------------------------

function XC.Trim(s)
    if s == nil then return nil end
    local _, b = string.find(s, "^%s*")
    local e = string.find(s, "%s*$", b + 1)
    return string.sub(s, b + 1, e - 1)
end

function XC.Log(text)
    DEFAULT_CHAT_FRAME:AddMessage("XC :: " .. text)
end

function XC.Explode(s, p)
    local r, o = {}, 1
    repeat
        local b, e = string.find(s, p, o)
        if b == nil then
            table.insert(r, XC.Trim(string.sub(s, o)))
            return r
        end
        table.insert(r, XC.Trim(string.sub(s, o, e - 1)))
        o = e + 1
    until false
end

function XC.GetSpellInfo(spellSlot)
    XC.tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    XC.tip:SetSpell(spellSlot, "spell") 
    local _, _, cost = string.find(XC.tip.costFontString:GetText() or "", "^(%d+)")
    if cost ~= nil then cost = tonumber(cost) end
    return cost
end

function XC.GetSpellId(name)
    name = string.lower(name)
    
    local index = XC.spellCache[name]
    if index ~= nil and index < 0 then
        return nil
    end

    for tabIndex = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tabIndex)
        for index = offset + 1, offset + count do
            local spell, rank = GetSpellName(index, "spell")
            spell = string.lower(spell) rank = string.lower(rank)
            XC.spellCache[spell] = index
            XC.spellCache[spell .. "(" .. rank .. ")"] = index
        end
    end

    local index = XC.spellCache[name]
    if index == nil then XC.spellCache[name] = -1 end
    return index;
end

function XC.GetCurrentShapeshiftForm()
    for index = 1, GetNumShapeshiftForms() do 
        local _, _, active = GetShapeshiftFormInfo(index)
        if active then return index end
    end
    return nil
end

function XC.CancelShapeshiftForm(index)
    local index = XC.GetCurrentShapeshiftForm(index)
    if index ~= nil then CastShapeshiftForm(index) end
end

function XC.TestConditional(test, target)
    local neg = string.sub(test, 1, 2) == "no"
    if neg then test = string.sub(test, 3) end
    
    local b, e, k, v = string.find(test, "^(%w+):(.*)$");
    if k == nil then k = test end
    
    local result
    
    if k == "help" then 
        result = UnitCanAssist("player", target) 
    elseif k == "harm" then
        result = UnitCanAttack("player", target)
    elseif k == "dead" then
        result = UnitIsDead(target)
    elseif k == "exists" then
        result = UnitExists(target)
    elseif k == "mod" or k == "modifier" then
        if v == nil then
            result = IsAltKeyDown() or IsControlKeyDown() or IsShiftKeyDown()
        else
            result = false
            for _, mod in ipairs(XC.Explode(v, "/")) do
                if mod == "alt" then
                    result = result or IsAltKeyDown()
                elseif mod == "ctrl" then
                    result = result or IsControlKeyDown()
                elseif mod == "shift" then
                    result = result or IsShiftKeyDown()
                end
            end
        end
    elseif k == "form" or k == "stance" then
        local currentForm = XC.GetCurrentShapeshiftForm()
        if v ~= nil then
            result = false
            for _, form in ipairs(XC.Explode(v, "/")) do
                local index = tonumber(form)
                if index ~= nil then
                    result = result or (currentForm == index)
                end
            end
        else
            result = currentForm ~= nil
        end
    else
        result = neg
    end
    
    result = (neg and not result) or (not neg and result)
    return result
end

function XC.Fetch(cmd)
    for _, part in ipairs(XC.Explode(cmd, ";")) do
        local offset, match, target = 1, false, "target"
        
        repeat
            -- Fetch the next conditional.
            local _, e, condition = string.find(part, "%s*%[([^]]*)]%s*", offset)
            if condition == nil then 
                if match or offset == 1 then
                    return string.sub(part, offset), target
                end
                
                -- Didn't match, let's try the next part.
                break
            else
                offset = e + 1
                if not match then
                    target = "target"
                    match = true
                    if string.find(condition, "^%s*$") == nil then
                        for _, cond in ipairs(XC.Explode(condition, ",")) do
                            if string.sub(cond, 1, 1) == "@" then
                                target = string.sub(cond, 2)
                                if target == "mouseover" and currentUnit ~= nil then
                                    target = currentUnit
                                end
                            else 
                                match = XC.TestConditional(cond, target)
                                if not match then break end
                            end
                        end
                    end
                end
            end
        until false
    end
end

function XC.DetermineSpell(macroIndex)
    local _, _, body = GetMacroInfo(macroIndex)
    local _, _, arg = string.find(body, "^%s*#showtooltip([^\n]*)")
    if arg ~= nil then
        arg = XC.Trim(XC.Fetch(arg)) or ""
        if arg ~= "" then
            local spell = XC.Fetch(arg)
            if spell ~= nil and XC.Trim(spell) ~= "" then
                local spellId = XC.GetSpellId(spell)
                if spellId ~= nil then
                    return spellId
                end
            end
        else        
            -- We'll parse each /cast manually
            for _, line in XC.Explode(body, "\n") do
                local _, _, arg = string.find(line, "^%s*/cast%s+(.*)")
                if arg ~= nil then
                    local spell = XC.Fetch(arg)
                    if spell ~= nil and XC.Trim(spell) ~= "" then
                        local spellId = XC.GetSpellId(spell)
                        if spellId ~= nil then
                            return spellId
                        end
                        break
                    end
                end
            end
        end
    end
end

function XC.GetSpellFromAction(slot)
    local text = GetActionText(slot)
    if text ~= nil then
        return XC.DetermineSpell(text)
    end
end

function XC.ShowTooltip(name)
    local index = XC.DetermineSpell(name)

    if index ~= nil then
        XC.currentMacro = name
        if index > 0  then
            GameTooltip:SetSpell(index, "spell")
            local _, rank = GetSpellName(index, "spell")
            XC.tip:SetOwner(WorldFrame, 'ANCHOR_NONE')
            XC.tip:SetSpell(index, "spell")
            
            GameTooltipTextRight1:SetText("|cff808080" .. rank .."|r");
            GameTooltipTextRight1:Show();
            GameTooltip:Show()
        end
        return true
    end
    
    return false
end

XC.ActionButtonPrefixes = {
    "ActionButton", "MultiBarLeftButton", "MultiBarRightButton", 
    "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "BonusActionButton"
}

function XC.BroadcastEventForAction(slot, event, ...)
    local _this = this
    for _, name in ipairs(XC.ActionButtonPrefixes) do 
        for i = 1, 12 do
            local actionButton = getglobal(name .. i)
            if actionButton ~= nil then
                if ActionButton_GetPagedID(actionButton) == slot then
                    arg1, arg2, arg3, arg4, arg5, arg6, arg7 = unpack(arg)
                    this = actionButton
                    ActionButton_OnEvent(event)
                end
            end
        end
    end
    this = _this
end

function XC.LoadAction(slot)
    local text = GetActionText(slot)
    if text ~= nil then
        local macroIndex = GetMacroIndexByName(text)
        if macroIndex ~= nil then
            local action = {
                macroIndex = macroIndex,
                spellSlot = XC.DetermineSpell(macroIndex),
                usable = true
            }
            
            if action.spellSlot then
                action.cost = XC.GetSpellInfo(action.spellSlot)
            end
            
            action.usable = 
                (not action.cost) or (UnitMana("player") >= action.cost)
                
            XC.actions[slot] = action
            
            return action
        end
    end
end

function XC.LoadActions()
    XC.actions = {}
    for slot = 1, 120 do XC.LoadAction(slot) end
end

XC.LoadActions()

--------------------------------------------------------------------------------
-- Overrides                                                                   -
--------------------------------------------------------------------------------

XC._.SendChatMessage = SendChatMessage
function SendChatMessage(msg, ...)
    if XC.currentAction and string.find(msg, "^%s*#showtooltip") then
        return
    end
    XC._.SendChatMessage(msg, unpack(arg))
end

XC._.UseAction = UseAction
function UseAction(slot, checkCursor, onSelf)
    XC.currentAction = XC.actions[slot]
    XC._.UseAction(slot, checkCursor, onSelf)
    XC.currentAction = nil
end

XC._.GameTooltip = {}

XC._.GameTooltip.SetAction = GameTooltip.SetAction
function GameTooltip.SetAction(self, slot)
    local action = XC.actions[slot]
    if action ~= nil then
        if action.spellSlot then
            GameTooltip:SetSpell(action.spellSlot, "spell")
        end
    else
        XC.currentMacro = nil
        XC._.GameTooltip.SetAction(self, slot)
    end
end

XC._.GameTooltip.Hide = GameTooltip.Hide
function GameTooltip.Hide(self)
    currentMacroName = nil
    XC._.GameTooltip.Hide(self)
end

XC._.IsActionInRange = IsActionInRange
function IsActionInRange(slot, unit)
    return XC.actions[slot] and true or 
        XC._.IsActionInRange(slot, unit)
end

XC._.IsUsableAction = IsUsableAction
function IsUsableAction(slot, unit)
    local action = XC.actions[slot]
    if action then 
        if action.usable then
            return true, false
        else
            return false, true
        end
    end
    return XC._.IsUsableAction(slot, unit)
end

XC._.GetActionTexture = GetActionTexture
function GetActionTexture(slot)
    local action = XC.actions[slot]
    if action then
        return action.spellSlot and GetSpellTexture(action.spellSlot, "spell") or
            "Interface\\Icons\\INV_Misc_QuestionMark"
    else
        return XC._.GetActionTexture(slot)
    end
end

XC._.GetActionCooldown = GetActionCooldown
function GetActionCooldown(slot)
    local action = XC.actions[slot]
    if action then
        if action.spellSlot then
            return GetSpellCooldown(action.spellSlot, "spell")
        else
            return 0, 0, 0
        end
    else
        return XC._.GetActionCooldown(slot)
    end
end

XC._.GameTooltip.SetOwner = GameTooltip.SetOwner
function GameTooltip.SetOwner(self, a, b, c, d)
    currentMacroName = nil
    XC._.GameTooltip.SetOwner(self, a, b, c, d)
end

XC._.UnitFrame_OnEnter = UnitFrame_OnEnter
function UnitFrame_OnEnter()
    currentUnit = this.unit
    XC._.UnitFrame_OnEnter(this)
end

XC._.UnitFrame_OnLeave = UnitFrame_OnLeave
function UnitFrame_OnLeave()
    currentUnit = nil
    XC._.UnitFrame_OnLeave(this)
end    

--------------------------------------------------------------------------------
-- UI                                                                          -
--------------------------------------------------------------------------------

function XC.OnUpdate(self)
    local time = GetTime()

    -- Slow down a bit.
    if (time - XC.lastUpdate) < 0.1 then return end
    XC.lastUpdate = time

    for slot, action in pairs(XC.actions) do
        local spellSlot = action.spellSlot
        local usable = action.usable
        local action = XC.LoadAction(slot)

        if action then
            if spellSlot ~= action.spellSlot then
                XC.BroadcastEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
            elseif usable ~= action.usable then
                XC.BroadcastEventForAction(slot, "ACTIONBAR_UPDATE_USABLE")
            end
        end
    end
end
 
function XC.OnEvent()
    if event == "UPDATE_MACROS" then
        XC.LoadActions()
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        XC.LoadActions()
    end
        
end

XC.frame = CreateFrame("Frame", nil, UIParent)
XC.frame:SetScript("OnUpdate", XC.OnUpdate)
XC.frame:SetScript("OnEvent", XC.OnEvent)
XC.frame:RegisterEvent("UPDATE_MACROS")
XC.frame:RegisterEvent("ACTIONBAR_SHOWGRID");
XC.frame:RegisterEvent("ACTIONBAR_HIDEGRID");
XC.frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED");
XC.frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
XC.frame:RegisterEvent("ACTIONBAR_UPDATE_STATE");
XC.frame:RegisterEvent("ACTIONBAR_UPDATE_USABLE");
XC.frame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN");
XC.frame:RegisterEvent("SPELL_UPDATE_USABLE");

XC.tip = CreateFrame("GameTooltip")
XC.tip.costFontString = XC.tip:CreateFontString()
XC.tip.rangeFontString = XC.tip:CreateFontString()
XC.tip:AddFontStrings(XC.tip:CreateFontString(), XC.tip:CreateFontString())
XC.tip:AddFontStrings(XC.tip.costFontString, XC.tip.rangeFontString)

--------------------------------------------------------------------------------
-- Slash Commands                                                              -
--------------------------------------------------------------------------------

SlashCmdList["CAST"] = function(msg)
    local name, target = XC.Fetch(msg)
    if name ~= nil then
        local spellId = XC.GetSpellId(name)
        if spellId == nil then return end
        
        if target ~= "target" then TargetUnit(target) end
        CastSpell(spellId, "spell")
        if target ~= "target" then TargetLastTarget() end
    end
end

SlashCmdList["CANCELFORM"] = function(msg)
    local name, target = XC.Fetch(msg)
    if name ~= nil then
        XC.CancelShapeshiftForm()
    end
end

-- Not implemented yet. 
SlashCmdList["XFOCUS"] = function(msg)
    local _, target = process(msg)
    if target ~= nil then
        focus = GetUnitName(target)
        if focus ~= nil then
            log("New focus " .. focus)
        end
    end
end

SLASH_CANCELFORM1 = "/cancelform"

LL = XC.Log

XC.Log("eXtended Commands Loaded")
