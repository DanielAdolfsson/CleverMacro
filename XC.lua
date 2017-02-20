--------------------------------------------------------------------------------
-- eXtended Commands v1.01 (2017) by _brain                                    -
--------------------------------------------------------------------------------
XC = {}

--------------------------------------------------------------------------------
-- Variables                                                                   -
--------------------------------------------------------------------------------

XC.spellCache = {}
XC.actions = {}
XC.lastUpdate = 0
XC.currentAction = nil
XC.currentSequence = nil
XC.mouseOverUnit = nil
XC.macros = {}
XC.castSequenceCache = {}

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

function XC.Split(s, p)
    local r, o = {}, 1
    repeat
        local b, e = string.find(s, p, o)
        if b == nil then
            table.insert(r, string.sub(s, o))
            return r
        end
        table.insert(r, string.sub(s, o, e - 1))
        o = e + 1
    until false
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

function XC.GetSpellSlotByName(name)
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

function XC.ShouldSequenceReset(reset)
    
end

function XC.TestConditions(conditions, target)
    local result = true

    if target == "mouseover" then
        local focus = GetMouseFocus()
        if focus and focus.unit then
            target = focus.unit
        end
    end
    
    for k, v in pairs(conditions) do
        local _, no = string.find(k, "^no")
        local mod = no and string.sub(k, no + 1) or k
        
        if mod == "help" then 
            result = UnitCanAssist("player", target) 
        elseif mod == "harm" then
            result = UnitCanAttack("player", target)
        elseif mod == "dead" then
            result = UnitIsDead(target)
        elseif mod == "exists" then
            result = UnitExists(target)
        elseif mod == "mod" or mod == "modifier" then
            if v == "" then
                result = IsAltKeyDown() or IsControlKeyDown() or IsShiftKeyDown()
            else
                result = false
                for _, mod in ipairs(XC.Split(v, "/")) do
                    if mod == "alt" then
                        result = result or IsAltKeyDown()
                    elseif mod == "ctrl" then
                        result = result or IsControlKeyDown()
                    elseif mod == "shift" then
                        result = result or IsShiftKeyDown()
                    end
                end
            end
        elseif mod == "form" or mod == "stance" then
            local currentForm = XC.GetCurrentShapeshiftForm()
            if v ~= "" then
                result = false
                for _, form in ipairs(XC.Split(v, "/")) do
                    local index = tonumber(form)
                    if index ~= nil then
                        result = result or (currentForm == index)
                    end
                end
            else
                result = currentForm ~= nil
            end
        else
            return false
        end
        
        if no then result = not result end
        
        if not result then return false end
    end
    
    return true, target
end

function XC.ParseArguments(s)
    if XC.Trim(s) == "" then return {} end
    
    local args = {}
    
    for _, sarg in ipairs(XC.Split(s, ";")) do
        local arg = { 
            conditionGroups = {}, 
            text = nil
        }
        table.insert(args, arg)
        
        local offset = 1
        repeat
            local _, e, sconds = string.find(sarg, "%s*%[([^]]*)]%s*", offset)
            if not sconds then break end

            local conditionGroup = {
                target = "target",
                conditions = {}
            }
            table.insert(arg.conditionGroups, conditionGroup)
            
            for _, scond in ipairs(XC.Split(sconds, ",")) do
                local _, _, a, k, q, v = string.find(scond, "^%s*(@?)(%w+)(:?)([^%s]*)%s*$");        
                if a then
                    if a == "@" and q == "" and v == "" then
                        conditionGroup.target = k
                    elseif a == "" and ((q == "" and v == "") or q == ":") then
                        conditionGroup.conditions[string.lower(k)] = string.lower(XC.Trim(v))
                    end
                end
            end

            offset = e + 1
        until false
        
        arg.text = XC.Trim(string.sub(sarg, offset))

        if table.getn(arg.conditionGroups) == 0 then
            local conditionGroup = {
                target = "target",
                conditions = {}
            }
            table.insert(arg.conditionGroups, conditionGroup)
        end
    end
    
    
    return args
end

function XC.ParseArguments_Cast(s)
    local spells = {}
    
    for _, arg in ipairs(XC.ParseArguments(s)) do
        local spell = {
            conditionGroups = arg.conditionGroups,
            spellSlot = XC.GetSpellSlotByName(XC.Trim(arg.text))
        }
        table.insert(spells, spell)
    end

    return spells
end

function XC.ParseArguments_CastSequence(s)
    s = XC.Trim(s)
    local sequence = XC.castSequenceCache[s]
    if sequence then return sequence end

    local args = XC.ParseArguments(s)
    if not args[1] then return sequence end

    sequence = {
        conditionGroups = {},
        spells = {},
        index = 1,
        reset = {},
        status = 0
    }
    XC.castSequenceCache[s] = sequence
    
    sequence.conditionGroups = args[1].conditionGroups
    
    local _, e, reset = string.find(args[1].text, "^%s*reset=([%w/]+)%s*")
    s = e and string.sub(args[1].text, e + 1) or args[1].text

    if reset then
        
    
    end
    
    for _, name in ipairs(XC.Split(s, ",")) do
        local spellSlot = XC.GetSpellSlotByName(XC.Trim(name))
        table.insert(sequence.spells, XC.GetSpellSlotByName(XC.Trim(name)))
    end
    
    return sequence
end

function XC.ParseMacro(name)
    local macroIndex = GetMacroIndexByName(name)
    if macroIndex == 0 then return nil end

    local name, iconTexture, body = GetMacroInfo(macroIndex)
    if not name then return nil end

    local macro = {
        name = name,
        iconTexture = iconTexture,
        commands = {}
    }
    
    for i, line in ipairs(XC.Split(body, "\n")) do
        if i == 1 then
            local _, _, s = string.find(line, "^%s*#showtooltip(.*)$")
            if s and not string.find(s, "^%w") then
                macro.tooltips = {}
                for _, arg in ipairs(XC.ParseArguments(s)) do
                    local tooltip = {
                        conditionGroups = arg.conditionGroups,
                        spellSlot = XC.GetSpellSlotByName(XC.Trim(arg.text))
                    }
                    table.insert(macro.tooltips, tooltip)
                end
            end
        end  

        if i > 1 or not macro.tooltips then
            local _, _, name, s = string.find(line, "^%s*/(%w+)(.*)$")
            if s and not string.find(s, "^%w") then
                local command = {
                    name = name,
                    args = s
                }
                table.insert(macro.commands, command)
                if name == "cast" then
                    command.spells = XC.ParseArguments_Cast(s)
                elseif name == "castsequence" then
                    command.sequence = XC.ParseArguments_CastSequence(s)
                end
            end
        end
    end
    
    return macro
end

function XC.GetMacroTooltipSpellSlot(macro)
    local spellSlot
    
    if macro.tooltips then
        for _, tooltip in ipairs(macro.tooltips) do
            for _, conditionGroup in ipairs(tooltip.conditionGroups) do
                if XC.TestConditions(conditionGroup.conditions, conditionGroup.target) then
                    return tooltip.spellSlot
                end
            end
        end
    end

    for _, command in ipairs(macro.commands) do
        if command.name == "cast" then
            for _, spell in ipairs(command.spells) do
                for _, conditionGroup in ipairs(spell.conditionGroups) do
                    if XC.TestConditions(conditionGroup.conditions, conditionGroup.target) then
                        return spell.spellSlot
                    end
                end
            end
        end
        if command.name == "castsequence" then
            for _, conditionGroup in ipairs(command.sequence.conditionGroups) do
                if XC.TestConditions(conditionGroup.conditions, conditionGroup.target) then
                    return command.sequence.spells[command.sequence.index]
                end
            end
        end
    end
end

function XC.GetMacro(name)
    -- name = string.lower(name)
    local macro = XC.macros[name]
    if macro then return macro end
    XC.macros[name] = XC.ParseMacro(name)
    return XC.macros[name]
end

function XC.GetAction(slot)
    local action = XC.actions[slot]
    if action then return action end

    local text = GetActionText(slot)
    
    if text then
        local macro = XC.GetMacro(text)
        if macro then
            action = {
                text = text,
                macro = macro,
                spellSlot = XC.GetMacroTooltipSpellSlot(macro)
            }

            if action.spellSlot then
                action.cost = XC.GetSpellInfo(action.spellSlot)
                action.usable = (not action.cost) or (UnitMana("player") >= action.cost)
            end
            
            XC.actions[slot] = action 
            return action
        end
    end
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
    XC.currentAction = XC.GetAction(slot)
    XC._.UseAction(slot, checkCursor, onSelf)
    XC.currentAction = nil
end

XC._.GameTooltip = {}

XC._.GameTooltip.SetAction = GameTooltip.SetAction
function GameTooltip.SetAction(self, slot)
    local action = XC.GetAction(slot)
    if action then
        if action.spellSlot then
            GameTooltip:SetSpell(action.spellSlot, "spell")
        end
    else
        XC._.GameTooltip.SetAction(self, slot)
    end
end

XC._.IsActionInRange = IsActionInRange
function IsActionInRange(slot, unit)
    local action = XC.GetAction(slot)
    if action and action.macro and action.macro.tooltips then
        return action.spellSlot and true 
    else
        return XC._.IsActionInRange(slot, unit)
    end
end

XC._.IsUsableAction = IsUsableAction
function IsUsableAction(slot, unit)
    local action = XC.GetAction(slot)
    if action and action.macro and action.macro.tooltips then 
        if action.usable then
            return true, false
        else
            return false, true
        end
    else
        return XC._.IsUsableAction(slot, unit)
    end
end

XC._.GetActionTexture = GetActionTexture
function GetActionTexture(slot)
    local action = XC.GetAction(slot)
    if action and action.macro then
        local spellSlot = XC.GetMacroTooltipSpellSlot(action.macro)
        if spellSlot then return GetSpellTexture(spellSlot, "spell") end
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    else
        return XC._.GetActionTexture(slot)
    end
end

XC._.GetActionCooldown = GetActionCooldown
function GetActionCooldown(slot)
    local action = XC.GetAction(slot)
    if action and action.macro then
        if action.spellSlot then
            return GetSpellCooldown(action.spellSlot, "spell")
        else
            return 0, 0, 0
        end
    else
        return XC._.GetActionCooldown(slot)
    end
end

--------------------------------------------------------------------------------
-- UI                                                                          -
--------------------------------------------------------------------------------

function XC.OnUpdate(self)
    local time = GetTime()

    local sequence = XC.currentSequence
    
    if sequence and sequence.status >= 2 and 
            (time - sequence.lastUpdate) >= 0.2 then
        if sequence.status == 2 then
            if sequence.index >= table.getn(sequence.spells) then
                sequence.index = 1
            else
                sequence.index = sequence.index + 1
            end
        end
        XC.currentSequence = nil
    end
    
    -- Slow down a bit.
    if (time - XC.lastUpdate) < 0.1 then return end
    XC.lastUpdate = time

    for slot, action in pairs(XC.actions) do
        local spellSlot = XC.GetMacroTooltipSpellSlot(action.macro)
        
        if action.spellSlot ~= spellSlot then
            action.spellSlot = spellSlot
            action.cost = spellSlot and XC.GetSpellInfo(spellSlot) or nil
            action.usable = (not action.cost) or (UnitMana("player") >= action.cost)
            XC.BroadcastEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
        else
            local usable = (not action.cost) or (UnitMana("player") >= action.cost)
            if usable ~= action.usable then
                action.usable = usable
                XC.BroadcastEventForAction(slot, "ACTIONBAR_UPDATE_USABLE")
            end
        end
    end
end
 
function XC.LogEvent()
    local s = "event = " .. event
    for i = 1, 16 do
        local arg = getglobal("arg" .. i)
        if arg ~= nil then s = s .. ", arg" .. i .. " = " .. arg end
    end
    XC.Log(s)
end
 
function XC.OnEvent()
    if event == "UPDATE_MACROS" then
        XC.currentSequence = nil
        XC.macros = {}
        XC.action = {}
        XC.castSequenceCache = {}
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        XC.actions[arg1] = nil
        XC.BroadcastEventForAction(arg1, "ACTIONBAR_SLOT_CHANGED", arg1)
    elseif XC.currentSequence then
        if event == "SPELLCAST_START" then
            XC.currentSequence.status = 1
        elseif event == "SPELLCAST_STOP" then
            XC.currentSequence.status = 2
            XC.currentSequence.lastUpdate = GetTime()
        elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
            XC.currentSequence.status = 3
        end
    end
end

XC.frame = CreateFrame("Frame", nil, UIParent)
XC.frame:SetScript("OnUpdate", XC.OnUpdate)
XC.frame:SetScript("OnEvent", XC.OnEvent)

XC.frame:RegisterEvent("UPDATE_MACROS")
XC.frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
XC.frame:RegisterEvent("SPELLCAST_START")
XC.frame:RegisterEvent("SPELLCAST_STOP")
XC.frame:RegisterEvent("SPELLCAST_FAILED")
XC.frame:RegisterEvent("SPELLCAST_INTERRUPTED")

XC.tip = CreateFrame("GameTooltip")
XC.tip.costFontString = XC.tip:CreateFontString()
XC.tip.rangeFontString = XC.tip:CreateFontString()
XC.tip:AddFontStrings(XC.tip:CreateFontString(), XC.tip:CreateFontString())
XC.tip:AddFontStrings(XC.tip.costFontString, XC.tip.rangeFontString)

--------------------------------------------------------------------------------
-- Slash Commands                                                              -
--------------------------------------------------------------------------------

SlashCmdList["CAST"] = function(msg)
    local spells = XC.ParseArguments_Cast(msg)
    
    for _, spell in ipairs(spells) do
        for _, conditionGroup in ipairs(spell.conditionGroups) do
            local result, target = XC.TestConditions(conditionGroup.conditions, conditionGroup.target)
            if result then
                if target ~= "target" then TargetUnit(target) end
                CastSpell(spell.spellSlot, "spell")
                if target ~= "target" then TargetLastTarget() end
                return
            end
        end
    end
end

SlashCmdList["CASTSEQUENCE"] = function(msg)
    local sequence = XC.ParseArguments_CastSequence(msg)

    if XC.currentSequence then return end
    
    for _, conditionGroup in ipairs(sequence.conditionGroups) do
        local result, target = XC.TestConditions(conditionGroup.conditions, conditionGroup.target)
        if result then
            local spellSlot = sequence.spells[sequence.index]
            if spellSlot then
                XC.currentSequence = sequence
                sequence.status = 0
                sequence.lastUpdate = GetTime()
            
                if targettarget ~= "target" then TargetUnit(target) end
                CastSpell(spellSlot, "spell")
                if targettarget ~= "target" then TargetLastTarget() end
            end
            return
        end
        
    end
end

SlashCmdList["CANCELFORM"] = function(msg)
    local args = XC.ParseArguments(msg)
    if args[1] then
        for _, conditionGroup in ipairs(args[1].conditionGroups) do
            local result = XC.TestConditions(conditionGroup.conditions, conditionGroup.target)
            if result then 
                XC.CancelShapeshiftForm()
                return
            end
        end
        return
    end
    
    XC.CancelShapeshiftForm()
end

XC._.SlashCmdList = {}

XC._.SlashCmdList.TARGET = SlashCmdList["TARGET"]

SlashCmdList["TARGET"] = function(msg)
    local args = XC.ParseArguments(msg)
    if args[1] then
        for _, conditionGroup in ipairs(args[1].conditionGroups) do
            local result, target = XC.TestConditions(conditionGroup.conditions, conditionGroup.target)
            if result then
                if target ~= "target" then
                    TargetUnit(target)
                else
                    XC._.SlashCmdList.TARGET(args[1].text)
                end
                return
            end
        end
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
SLASH_CASTSEQUENCE1 = "/castsequence"

LL = XC.Log

XC.Log("eXtended Commands Loaded")
