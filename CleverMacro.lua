--------------------------------------------------------------------------------
-- CleverMacro v1.3.1 by _brain                                    -
--------------------------------------------------------------------------------

local VERSION = "1.3.1"

local spellCache = {}
local actions = {}    
local lastUpdate = 0    
local currentAction = nil    
local currentSequence = nil    
local mouseOverUnit = nil    
local macros = {}    
local castSequenceCache = {}   
 
local actionEventHandlers = {}
local mouseOverResolvers = {}

local frame

local function Trim(s)
    if s == nil then return nil end
    local _, b = string.find(s, "^%s*")
    local e = string.find(s, "%s*$", b + 1)
    return string.sub(s, b + 1, e - 1)
end

local function Log(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00CCCCCleverMacros ::|r " .. text)
end

local function Split(s, p)
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

local function GetSpellInfo(spellSlot)
    frame:SetOwner(WorldFrame, "ANCHOR_NONE")
    frame:SetSpell(spellSlot, "spell") 
    local _, _, cost = string.find(frame.costFontString:GetText() or "", "^(%d+)")
    if cost ~= nil then cost = tonumber(cost) end
    return cost
end

local function GetSpellSlotByName(name)
    name = string.lower(name)
    
    local index = spellCache[name]
    if index ~= nil and index < 0 then
        return nil
    end

    for tabIndex = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tabIndex)
        for index = offset + 1, offset + count do
            local spell, rank = GetSpellName(index, "spell")
            spell = string.lower(spell) rank = string.lower(rank)
            spellCache[spell] = index
            spellCache[spell .. "(" .. rank .. ")"] = index
        end
    end

    local index = spellCache[name]
    if index == nil then spellCache[name] = -1 end
    return index;
end

local function GetCurrentShapeshiftForm()
    for index = 1, GetNumShapeshiftForms() do 
        local _, _, active = GetShapeshiftFormInfo(index)
        if active then return index end
    end
    return nil
end    
    
local function CancelShapeshiftForm(index)
    local index =GetCurrentShapeshiftForm(index)
    if index ~= nil then CastShapeshiftForm(index) end
end

local UNITS = {
    "(mouseover)", "(player)", "(pet)", "(party)(%d)", "(partypet)(%d)",
    "(partypet)(%d)", "(raid)(%d+)", "(raidpet)(%d+)", "(target)" 
}

local function IsUnitValid(unit)
    local offset = 1
    repeat
        local b, e, name, n
        for _, p in ipairs(UNITS) do
            b, e, name, n = string.find(unit, "^" .. p, offset)
           if e then break end
        end
        if not e then return false end
        if offset > 1 and name ~= "target" then return false end
        if n and tonumber(n) == 0 then return false end

        if (name == "raid" or name == "raidpet") and tonumber(n) > 40 then
            return false
        end

        if (name == "partypet" or name == "party") and tonumber(n) > 4 then
            return false
        end
        
        offset = e + 1
    until offset > string.len(unit)
    return offset > 1
end

local function GetMouseOverUnit()
    local frame = GetMouseFocus()
    if not frame then return end

    if frame.unit then return frame.unit end

    for _, fn in ipairs(mouseOverResolvers) do
        local unit = fn(frame)
        if unit then return unit end
    end
end

local function TestConditions(conditions, target)
    local result = true

    if target == "mouseover" or target == "mo" then
        target = GetMouseOverUnit() or "mouseover"
    end

    if not IsUnitValid(target) then
        target = "target"
    end
    
    for k, v in pairs(conditions) do
        local _, no = string.find(k, "^no")
        local mod = no and string.sub(k, no + 1) or k
        
        if mod == "help" then 
            result = UnitCanAssist("player", target) 
        elseif mod == "exists" then
            result = UnitExists(target)
        elseif mod == "harm" then
            result = UnitCanAttack("player", target)
        elseif mod == "dead" then
            result = UnitIsDead(target) or UnitIsGhost()
        elseif mod == "combat" then
            result = UnitAffectingCombat("player")
        elseif mod == "mod" or mod == "modifier" then
            if v == true then
                result = IsAltKeyDown() or IsControlKeyDown() or IsShiftKeyDown()
            else
                result = IsAltKeyDown() and v.alt
                result = result or IsControlKeyDown() and v.ctrl
                result = result or IsShiftKeyDown() and v.shift
            end
        elseif mod == "form" or mod == "stance" then
            if v == true then
                result = GetCurrentShapeshiftForm() ~= nil
            else
                result = v[GetCurrentShapeshiftForm() or 0] 
            end

        -- Conditions that are NOT a part of the official implementation.
        elseif mod == "shift" then
             result = IsShiftKeyDown()
        elseif mod == "alt" then
            result = IsAltKeyDown()
        elseif mod == "ctrl" then
            result = IsControlKeyDown()
        elseif mod == "alive" then
             result = not (UnitIsDead(target) or UnitIsGhost())
             
        else
            return false
        end
        
        if no then result = not result end
        
        if not result then return false end
    end
    
    return true, target
end



local function ParseArguments(s)
    if Trim(s) == "" then return {} end
    
    local args = {}
    
    for _, sarg in ipairs(Split(s, ";")) do
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
            
            for _, scond in ipairs(Split(sconds, ",")) do
                local _, _, a, k, q, v = string.find(scond, "^%s*(@?)(%w+)(:?)([^%s]*)%s*$");      
                if a then
                    if a == "@" and q == "" and v == "" then
                        conditionGroup.target = k
                    elseif a == "" then
                        if q == ":" then
                            local conds = {}
                            for _, smod in ipairs(Split(v, "/")) do
                                if smod ~= "" then 
                                    conds[tonumber(smod) or string.lower(smod)] = true
                                end
                            end
                            conditionGroup.conditions[string.lower(k)] = conds
                        else
                            conditionGroup.conditions[string.lower(k)] = true
                        end
                    end
                end
            end

            offset = e + 1
        until false
        
        arg.text = Trim(string.sub(sarg, offset))

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

local function ParseArguments_Cast(s)
    local spells = ParseArguments(s)
    
    for _, spell in ipairs(spells) do
        spell.spellSlot = GetSpellSlotByName(Trim(spell.text))
    end

    return spells
end

local function ParseArguments_CastSequence(s)
    s = Trim(s)
    local sequence = castSequenceCache[s]
    if sequence then return sequence end

    sequence = ParseArguments(s)
    if not sequence then return sequence end

    sequence.index = 1
    sequence.reset = {}
    sequence.spells = {}
    sequence.status = 0
    
    castSequenceCache[s] = sequence
    
    local _, e, reset = string.find(sequence.text, "^%s*reset=([%w/]+)%s*")
    s = e and string.sub(sequence.text, e + 1) or sequence.text

    if reset then
        for _, rule in ipairs(Split(reset, "/")) do
            local secs = tonumber(rule)
            if secs and secs > 0 then
                if not sequence.reset.secs or secs < sequence.reset.secs then
                    sequence.reset.secs = secs
                end
            else
                sequence.reset[rule] = true
            end
        end
    end
    
    for _, name in ipairs(Split(s, ",")) do
        local spellSlot = GetSpellSlotByName(Trim(name))
        table.insert(sequence.spells, GetSpellSlotByName(Trim(name)))
    end
    
    return sequence
end

local function ParseMacro(name)
    local macroIndex = GetMacroIndexByName(name)
    if macroIndex == 0 then return nil end

    local name, iconTexture, body = GetMacroInfo(macroIndex)
    if not name then return nil end

    local macro = {
        name = name,
        iconTexture = iconTexture,
        commands = {}
    }
    
    for i, line in ipairs(Split(body, "\n")) do
        if i == 1 then
            local _, _, s = string.find(line, "^%s*#showtooltip(.*)$")
            if s and not string.find(s, "^%w") then
                macro.tooltips = {}
                for _, arg in ipairs(ParseArguments(s)) do
                    local tooltip = {
                        conditionGroups = arg.conditionGroups,
                        spellSlot = GetSpellSlotByName(Trim(arg.text))
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
                    command.spells = ParseArguments_Cast(s)
                elseif name == "castsequence" then
                    command.sequence = ParseArguments_CastSequence(s)
                end
            end
        end
    end
    
    return macro
end

local function GetMacroTooltipSpellSlot(macro)
    local spellSlot
    
    if macro.tooltips then
        for _, tooltip in ipairs(macro.tooltips) do
            for _, conditionGroup in ipairs(tooltip.conditionGroups) do
                if TestConditions(conditionGroup.conditions, conditionGroup.target) then
                    return tooltip.spellSlot
                end
            end
        end
    end

    for _, command in ipairs(macro.commands) do
        if command.name == "cast" then
            for _, spell in ipairs(command.spells) do
                for _, conditionGroup in ipairs(spell.conditionGroups) do
                    if TestConditions(conditionGroup.conditions, conditionGroup.target) then
                        return spell.spellSlot
                    end
                end
            end
        end
        if command.name == "castsequence" then
            for _, conditionGroup in ipairs(command.sequence.conditionGroups) do
                if TestConditions(conditionGroup.conditions, conditionGroup.target) then
                    if command.sequence.index > 1 then
                        local reset = false
                        reset = command.sequence.reset.shift and IsShiftKeyDown() 
                        reset = reset or (command.sequence.reset.alt and IsAltKeyDown())
                        reset = reset or (command.sequence.reset.ctrl and IsControlKeyDown())
                        return command.sequence.spells[reset and 1 or command.sequence.index]
                    else
                        return command.sequence.spells[command.sequence.index]
                    end
                end
            end
        end
    end
end

local function GetMacro(name)
    local macro = macros[name]
    if macro then return macro end
    macros[name] = ParseMacro(name)
    return macros[name]
end

local function GetAction(slot)
    local action = actions[slot]
    if action then return action end

    local text = GetActionText(slot)
    
    if text then
        local macro = GetMacro(text)
        if macro then
            action = {
                text = text,
                macro = macro,
                spellSlot = GetMacroTooltipSpellSlot(macro)
            }

            if action.spellSlot then
                action.cost = GetSpellInfo(action.spellSlot)
                action.usable = (not action.cost) or (UnitMana("player") >= action.cost)
            end
            
            actions[slot] = action 
            return action
        end
    end
end

local function SendEventForAction(slot, event, ...)
    local _this = this

    arg1, arg2, arg3, arg4, arg5, arg6, arg7 = unpack(arg)

    local page = floor((slot - 1) / NUM_ACTIONBAR_BUTTONS) + 1
    local pageSlot = slot - (page - 1) * NUM_ACTIONBAR_BUTTONS
    
    -- Classic support.
    
    if slot >= 73 then
        this = getglobal("BonusActionButton" .. pageSlot)
        if this then ActionButton_OnEvent(event) end
    else
        if slot >= 61 then
            this = getglobal("MultiBarBottomLeftButton" .. pageSlot)
        elseif slot >= 49 then
            this = getglobal("MultiBarBottomRightButton" .. pageSlot)
        elseif slot >= 37 then
            this = getglobal("MultiBarRightButton" .. pageSlot)
        elseif slot >= 25 then
            this = getglobal("MultiBarLeftButton" .. pageSlot)
        else
            this = nil
        end

        if this then ActionButton_OnEvent(event) end
        
        if page == CURRENT_ACTIONBAR_PAGE then
            this = getglobal("ActionButton" .. pageSlot)
            if this then ActionButton_OnEvent(event) end
        end
    end

    this = _this
    
    for _, fn in ipairs(actionEventHandlers) do
        fn(slot, event, unpack(arg))
    end
end

--------------------------------------------------------------------------------
-- Overrides                                                                   -
--------------------------------------------------------------------------------

local base = {}

base.SendChatMessage = SendChatMessage
function SendChatMessage(msg, ...)
    if currentAction and string.find(msg, "^%s*#showtooltip") then
        return
    end
    base.SendChatMessage(msg, unpack(arg))
end

base.UseAction = UseAction
function UseAction(slot, checkCursor, onSelf)
    currentAction = GetAction(slot)
    base.UseAction(slot, checkCursor, onSelf)
    currentAction = nil
end

base.GameTooltip = {}

base.GameTooltip.SetAction = GameTooltip.SetAction
function GameTooltip.SetAction(self, slot)
    local action = GetAction(slot)
    if action then
        if action.spellSlot then
            GameTooltip:SetSpell(action.spellSlot, "spell")
            local _, rank = GetSpellName(action.spellSlot, "spell")
            GameTooltipTextRight1:SetText("|cff808080" .. rank .."|r");
            GameTooltipTextRight1:Show();
            GameTooltip:Show()
        end
    else
        base.GameTooltip.SetAction(self, slot)
    end
end

base.IsActionInRange = IsActionInRange
function IsActionInRange(slot, unit)
    local action = GetAction(slot)
    if action and action.macro and action.macro.tooltips then
        return action.spellSlot and true 
    else
        return base.IsActionInRange(slot, unit)
    end
end

base.IsUsableAction = IsUsableAction
function IsUsableAction(slot, unit)
    local action = GetAction(slot)
    if action and action.macro and action.macro.tooltips then 
        if action.usable then
            return true, false
        else
            return false, true
        end
    else
        return base.IsUsableAction(slot, unit)
    end
end

base.GetActionTexture = GetActionTexture
function GetActionTexture(slot)
    local action = GetAction(slot)
    if action and action.macro then
        if not action.macro.tooltips then return action.macro.iconTexture end
        local spellSlot = GetMacroTooltipSpellSlot(action.macro)
        if spellSlot then return GetSpellTexture(spellSlot, "spell") end
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    else
        return base.GetActionTexture(slot)
    end
end

base.GetActionCooldown = GetActionCooldown
function GetActionCooldown(slot)
    local action = GetAction(slot)
    if action and action.macro then
        if action.spellSlot then
            return GetSpellCooldown(action.spellSlot, "spell")
        else
            return 0, 0, 0
        end
    else
        return base.GetActionCooldown(slot)
    end
end

--------------------------------------------------------------------------------
-- UI                                                                          -
--------------------------------------------------------------------------------

local function OnUpdate(self)
    local time = GetTime()

    local sequence = currentSequence
    
    if sequence and sequence.status >= 2 and 
            (time - sequence.lastUpdate) >= 0.2 then
        if sequence.status == 2 then
            if sequence.index >= table.getn(sequence.spells) then
                sequence.index = 1
            else
                sequence.index = sequence.index + 1
            end
        end
        currentSequence = nil
    end
    
    -- Slow down a bit.
    if (time - lastUpdate) < 0.1 then return end
    lastUpdate = time

    for cmd, sequence in pairs(castSequenceCache) do
        if currentSequence ~= sequence and sequence.index > 1 then
            if sequence.reset.secs and (time - sequence.lastUpdate) >= sequence.reset.secs then
                sequence.index = 1
            end
        end
    end
    
    for slot, action in pairs(actions) do
        local spellSlot = GetMacroTooltipSpellSlot(action.macro)
        
        if action.spellSlot ~= spellSlot then
            action.spellSlot = spellSlot
            action.cost = spellSlot and GetSpellInfo(spellSlot) or nil
            action.usable = (not action.cost) or (UnitMana("player") >= action.cost)
            SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
        else
            local usable = (not action.cost) or (UnitMana("player") >= action.cost)
            if usable ~= action.usable then
                action.usable = usable
                SendEventForAction(slot, "ACTIONBAR_UPDATE_USABLE")
            end
        end
    end
end

local function OnEvent()
    if event == "UPDATE_MACROS" or event == "SPELLS_CHANGED" then
        currentSequence = nil
        macros = {}
        actions = {}
        castSequenceCache = {}
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        actions[arg1] = nil
        SendEventForAction(arg1, "ACTIONBAR_SLOT_CHANGED", arg1)
    elseif event == "PLAYER_LEAVE_COMBAT" then
        for cmd, sequence in pairs(castSequenceCache) do
            if currentSequence ~= sequence and sequence.index > 1 and sequence.reset.combat then
                sequence.index = 1
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        for cmd, sequence in pairs(castSequenceCache) do
            if currentSequence ~= sequence and sequence.index > 1 and sequence.reset.target then
                sequence.index = 1
            end
        end
    elseif currentSequence then
        if event == "SPELLCAST_START" then
            currentSequence.status = 1
        elseif event == "SPELLCAST_STOP" then
            currentSequence.status = 2
            currentSequence.lastUpdate = GetTime()
        elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
            currentSequence.status = 3
        end
    end
   
end

frame = CreateFrame("GameTooltip")
frame:SetScript("OnUpdate", OnUpdate)
frame:SetScript("OnEvent", OnEvent)

frame.costFontString = frame:CreateFontString()
frame.rangeFontString = frame:CreateFontString()
frame:AddFontStrings(frame:CreateFontString(), frame:CreateFontString())
frame:AddFontStrings(frame.costFontString, frame.rangeFontString)

frame:RegisterEvent("UPDATE_MACROS")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("SPELLCAST_STOP")
frame:RegisterEvent("SPELLCAST_FAILED")
frame:RegisterEvent("SPELLCAST_INTERRUPTED")
frame:RegisterEvent("PLAYER_LEAVE_COMBAT")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("SPELLS_CHANGED")

--------------------------------------------------------------------------------
-- Slash Commands                                                              -
--------------------------------------------------------------------------------

SlashCmdList["CAST"] = function(msg)
    local spells = ParseArguments_Cast(msg)
    
    for _, spell in ipairs(spells) do
        for _, conditionGroup in ipairs(spell.conditionGroups) do
            local result, target = TestConditions(conditionGroup.conditions, conditionGroup.target)
            if result then
                local retarget = not UnitIsUnit(target, "target")
                if retarget then
                    TargetUnit(target)
                    if not UnitIsUnit(target, "target") then return end
                end            
            
                CastSpell(spell.spellSlot, "spell")
                if retarget then TargetLastTarget() end
                return
            end
        end
    end
end

SlashCmdList["CASTSEQUENCE"] = function(msg)
    local sequence = ParseArguments_CastSequence(msg)

    if currentSequence then return end
    
    for _, conditionGroup in ipairs(sequence.conditionGroups) do
        local result, target = TestConditions(conditionGroup.conditions, conditionGroup.target)
        if result then
            if sequence.index > 1 then
                local reset = false
                reset = sequence.reset.shift and IsShiftKeyDown() 
                reset = reset or (sequence.reset.alt and IsAltKeyDown())
                reset = reset or (sequence.reset.ctrl and IsControlKeyDown())
                if reset then sequence.index = 1 end
            end

            local spellSlot = sequence.spells[sequence.index]
            
            if spellSlot then
                currentSequence = sequence
                sequence.status = 0
                sequence.lastUpdate = GetTime()

                local retarget = not UnitIsUnit(target, "target")
                if retarget then
                    TargetUnit(target)
                    if not UnitIsUnit(target, "target") then return end
                end
                
                CastSpell(spellSlot, "spell")
                if retarget then TargetLastTarget() end
            end
            return
        end
        
    end
end

SlashCmdList["CANCELFORM"] = function(msg)
    local args = ParseArguments(msg)
    if args[1] then
        for _, conditionGroup in ipairs(args[1].conditionGroups) do
            local result = TestConditions(conditionGroup.conditions, conditionGroup.target)
            if result then 
                CancelShapeshiftForm()
                return
            end
        end
        return
    end
    
    CancelShapeshiftForm()
end

base.SlashCmdList = {}

base.SlashCmdList.TARGET = SlashCmdList["TARGET"]

SlashCmdList["TARGET"] = function(msg)
    local args = ParseArguments(msg)
    if args[1] then
        for _, conditionGroup in ipairs(args[1].conditionGroups) do
            local result, target = TestConditions(conditionGroup.conditions, conditionGroup.target)
            if result then
                if target ~= "target" then
                    TargetUnit(target)
                else
                    base.SlashCmdList.TARGET(args[1].text)
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

-- Exports

CleverMacro = {}

CleverMacro.RegisterActionEventHandler = function(fn)
    if type(fn) == "function" then
        table.insert(actionEventHandlers, fn)
    end
end

CleverMacro.RegisterMouseOverResolver = function(fn)
    if type(fn) == "function" then
        table.insert(mouseOverResolvers, fn)
    end
end

CleverMacro.Log = Log
     
DEFAULT_CHAT_FRAME:AddMessage("|cFF00CCCCCleverMacro |r" .. VERSION .. "|cFF00CCCC loaded|r")
