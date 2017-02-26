--------------------------------------------------------------------------------
-- CleverMacro v1.3.1 by _brain                                    -
--------------------------------------------------------------------------------

local VERSION = "1.4"

local _G = getfenv(0)

local lastUpdate = 0    
local currentAction
local mouseOverUnit

local actions = {}    
local macros = {}    
local sequences = {}
local currentSequence

local actionEventHandlers = {}
local mouseOverResolvers = {}

local items = {}

local frame

local function Trim(s)
    if s == nil then return nil end
    local _, b = string.find(s, "^%s*")
    local e = string.find(s, "%s*$", b + 1)
    return string.sub(s, b + 1, e - 1)
end

local function Log(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00CCCCCleverMacro ::|r " .. text)
end

local function Seq(_, i)
    return (i or 0) + 1
end

local function Split(s, p, trim)
    local r, o = {}, 1
    repeat
        local b, e = string.find(s, p, o)
        if b == nil then
            local sub = string.sub(s, o)
            table.insert(r, trim and Trim(sub) or sub)
            return r
        end
        if b > 1 then
            local sub = string.sub(s, o, b - 1)
            table.insert(r, trim and Trim(sub) or sub)
        else
            table.insert(r, "")
        end
        o = e + 1
    until false
end

local function GetSpellInfo(spellSlot)
    frame:SetOwner(WorldFrame, "ANCHOR_NONE")
    frame:SetSpell(spellSlot, "spell") 
    local _, _, cost = string.find(frame.costFontString:GetText() or "", "^(%d+)")
    return tonumber(cost)
end

local function GetSpellSlotByName(name)
    name = string.lower(name)
    local b, _, rank = string.find(name, "%(%s*rank%s+(%d+)%s*%)");
    if b then name = (b > 1) and Trim(string.sub(name, 1, b - 1)) or "" end

    for tabIndex = GetNumSpellTabs(), 1, -1 do
        local _, _, offset, count = GetSpellTabInfo(tabIndex)
        for index = offset + count, offset + 1, -1 do
            local spell, subSpell = GetSpellName(index, "spell")
            spell = string.lower(spell) 
            if name == spell and (not rank or subSpell == "Rank " .. rank) then
                return index
            end
        end
    end
end

local function GetCurrentShapeshiftForm()
    for index = 1, GetNumShapeshiftForms() do 
        local _, _, active = GetShapeshiftFormInfo(index)
        if active then return index end
    end
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
            result = UnitIsDead(target) or UnitIsGhost(target)
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
    
    return true
end

local function GetArg(args)
    for _, arg in ipairs(args) do
        for _, conditionGroup in ipairs(arg.conditionGroups) do
            local target = conditionGroup.target

            local _, _, subTarget = string.find(target, "^mouseover(.*)")
            
            if not subTarget then
                _, _, subTarget = string.find(target, "^mo(.*)")
            end
            
            if subTarget then 
                target = (GetMouseOverUnit() or "mouseover") .. subTarget
            end
            
            if not IsUnitValid(target) then
                target = "target"
            end

            local result = TestConditions(conditionGroup.conditions, target)
            if result then return arg, target end
        end
    end
end

local function ParseArguments(s)
    local args = {}
    
    for _, sarg in ipairs(Split(s, ";")) do
        local arg = { 
            conditionGroups = {}
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



local COMMANDS = {
    ["/cast"] =  function(args) 
        for _, arg in ipairs(args) do
            arg.spellSlot = GetSpellSlotByName(arg.text)
        end
    end,
    
    ["/castsequence"] = function(args)
        sequence = args[1]
        if not sequence then return end
        
        sequence.index = 1
        sequence.reset = {}
        sequence.spells = {}
        sequence.status = 0
    
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
    end,

    ["/use"] = function(args)
        for itemID, item in pairs(items) do
            for _, arg in ipairs(args) do
                if string.lower(arg.text) == string.lower(item.name) then
                    arg.itemID = itemID
                end
            end
        end
    end,
    
    ["/target"] = true,
    
    ["/stopmacro"] = true
}

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

    for i, line in ipairs(Split(body, "\n", true)) do
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
            local _, e, name = string.find(line, "^(/%w+)%s*")
            if name then
                local command = {
                    name = name,
                    text = string.sub(line, e + 1)
                }
                
                table.insert(macro.commands, command)

                local cmd = COMMANDS[name]
                if cmd then
                    command.args = ParseArguments(command.text)
                    if type(cmd) == "function" then
                        cmd(command.args)
                    end
                    if name == "/castsequence" then
                        table.insert(sequences, command.args[1])
                    end
                end
                
                -- Search for a corresponding slash command.
                for cmd, fn in pairs(SlashCmdList) do
                    for i in Seq do
                        local cmdt = _G["SLASH_" .. cmd .. i]
                        if not cmdt then break end
                        if cmdt == name then
                            command.fn = fn
                            break
                        end
                    end
                    if command.fn then break end
                end

                -- Search for a corresponding emote.
                for i in Seq do
                    local n = 0
                    for j in Seq do
                        local cmdt = _G["EMOTE" .. i .. "_CMD" .. j]
                        if not cmdt then break end
                        n = n + 1
                        if cmdt == name then
                            command.emote = string.sub(name, 2)
                            break
                        end
                    end
                    if n == 0 or command.emote then break end
                end
            elseif line ~= "" then
                table.insert(macro.commands, { text = line })
            end
        end
    end
    
    return macro
end

local function GetMacroInfo(macro)
    if macro.tooltips then
        local arg = GetArg(macro.tooltips)
        if arg and arg.spellSlot then 
            return "spell", arg.spellSlot, 
                GetSpellTexture(arg.spellSlot, "spell")
        end
    end
    
    for _, command in ipairs(macro.commands) do
        if command.name == "/cast" then
            local arg = GetArg(command.args)
            if arg and arg.spellSlot then
                return "spell", arg.spellSlot,
                    GetSpellTexture(arg.spellSlot, "spell")
            end
        elseif command.name == "/castsequence" then
            local arg = GetArg(command.args)
            if arg then
                local reset = false
                reset = arg.reset.shift and IsShiftKeyDown() 
                reset = reset or (arg.reset.alt and IsAltKeyDown())
                reset = reset or (arg.reset.ctrl and IsControlKeyDown())
                    
                local spellSlot = arg.spells[reset and 1 or arg.index]
                
                if spellSlot then
                    return "spell", spellSlot,
                        GetSpellTexture(spellSlot, "spell")
                end
            end
        elseif command.name == "/stopmacro" then
            if GetArg(command.args) then break end
        elseif command.name == "/use" then
            local arg = GetArg(command.args)
            if arg and arg.itemID and items[arg.itemID]  then
                return "item", arg.itemID, items[arg.itemID].texture
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

local function RunMacro(macro)
    for _, command in ipairs(macro.commands) do
        if command.fn then 
            local r = command.fn(command.text, command)
            if r ~= nil and r == false then break end
        elseif command.emote then
            DoEmote(command.emote)
        else
            ChatFrameEditBox:SetText(command.text);
            ChatEdit_SendText(ChatFrameEditBox);
        end
    end
end

local function RefreshAction(action)
    local spellSlot, itemID = action.spellSlot, action.itemID
    local type, value, texture = GetMacroInfo(action.macro)
    
    action.texture = texture

    if type == "spell" then
        action.cost = GetSpellInfo(value)
        action.usable = (not action.cost) or (UnitMana("player") >= action.cost)
        action.itemID = nil
        action.spellSlot = value
    elseif type == "item" then
        action.cost = 0
        action.usable = true
        action.itemID = value
        action.spellSlot = nil
    else
        action.cost = 0
        action.usable = true
        action.itemID = nil
        action.spellSlot = nil
    end
    
    return usable ~= action.usable or spellSlot ~= action.spellSlot or itemID ~= action.itemID
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
                slot = slot
            }

            RefreshAction(action)
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
        this = _G["BonusActionButton" .. pageSlot]
        if this then ActionButton_OnEvent(event) end
    else
        if slot >= 61 then
            this = _G["MultiBarBottomLeftButton" .. pageSlot]
        elseif slot >= 49 then
            this = _G["MultiBarBottomRightButton" .. pageSlot]
        elseif slot >= 37 then
            this = _G["MultiBarLeftButton" .. pageSlot]
        elseif slot >= 25 then
            this = _G["MultiBarRightButton" .. pageSlot]
        else
            this = nil
        end

        if this then ActionButton_OnEvent(event) end
        
        if page == CURRENT_ACTIONBAR_PAGE then
            this = _G["ActionButton" .. pageSlot]
            if this then ActionButton_OnEvent(event) end
        end
    end

    this = _this
    
    for _, fn in ipairs(actionEventHandlers) do
        fn(slot, event, unpack(arg))
    end
end

local function IndexItems()
    items = {}
    for bagID = 0, NUM_BAG_SLOTS do
        for slot = GetContainerNumSlots(bagID), 1, -1 do
            local link = GetContainerItemLink(bagID, slot)
            if link then
                local _, _, itemID = string.find(link, "item:(%d+)")
                if itemID and not items[itemID] then
                    local name, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
                    local item = {
                        bagID = bagID,
                        slot = slot,
                        id = itemID,
                        name = name,
                        texture = texture
                    }
                    _, _, item.link = string.find(link, "|H([^|]+)|h")
                    items[itemID] = item
                end
            end
        end
    end
    
    for inventoryID = 0, 19 do
        local link = GetInventoryItemLink("player", inventoryID)
        if link then
            local _, _, itemID = string.find(link, "item:(%d+)")
            if itemID and not items[itemID] then
                local name, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
                local item = {
                    inventoryID = inventoryID,
                    id = itemID,
                    name = name,
                    texture = texture
                }
                _, _, item.link = string.find(link, "|H([^|]+)|h")
                items[itemID] = item
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Overrides                                                                   -
--------------------------------------------------------------------------------

local base = {}

base.UseAction = UseAction
function UseAction(slot, checkCursor, onSelf)
    local action = GetAction(slot)
    if action and action.macro then
        RunMacro(action.macro)
    else
        base.UseAction(slot, checkCursor, onSelf)
    end
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
        elseif action.itemLink then
            GameTooltip:SetHyperlink(action.itemLink)
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
    if action and action.macro and action.macro.tooltips then
        return action.texture or "Interface\\Icons\\INV_Misc_QuestionMark"
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
        elseif action.itemID then
            local item = items[action.itemID]
            if item then
                if item.bagID and item.slot then
                    return GetContainerItemCooldown(item.bagID, item.slot)
                elseif item.inventoryID then
                    return GetInventoryItemCooldown("player", item.inventoryID)
                end
            end
        end
        return 0, 0, 0
    else
        return base.GetActionCooldown(slot)
    end
end

base.SlashCmdList = {}

base.SlashCmdList.TARGET = SlashCmdList["TARGET"]
SlashCmdList["TARGET"] = function(msg)
    local arg, target = GetArg(command and command.args or ParseArguments(msg))
    if arg then
        if target ~= "target" then
            TargetUnit(target)
        else
            base.SlashCmdList.TARGET(arg.text)
        end
    end
end

--------------------------------------------------------------------------------
-- UI                                                                          -
--------------------------------------------------------------------------------

local function OnUpdate(self)
    local time = GetTime()

    -- Slow down a bit.
    if (time - lastUpdate) < 0.1 then return end
    lastUpdate = time

    if currentSequence and currentSequence.status >= 2 and 
            (time - currentSequence.lastUpdate) >= 0.2 then
        if currentSequence.status == 2 then
            if currentSequence.index >= table.getn(currentSequence.spells) then
                currentSequence.index = 1
            else
                currentSequence.index = currentSequence.index + 1
            end
        end

        for slot, action in pairs(actions) do
            for _, command in ipairs(action.macro.commands) do
                if command.name == "/castsequence" and command.args[1] == currentSequence then
                    SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
                end
            end
        end

        currentSequence = nil
    end

    for _, sequence in ipairs(sequences) do
        if sequence.index > 1 and sequence.reset.secs and (time - sequence.lastUpdate) >= sequence.reset.secs then
            sequence.index = 1
            
            for slot, action in pairs(actions) do
                for _, command in ipairs(action.macro.commands) do
                    if command.name == "/castsequence" and command.args[1] == sequence then
                        SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
                    end
                end
            end
        end
    end
    
    for slot, action in pairs(actions) do
        if RefreshAction(action) then
            SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
        end
    end
end

local function OnEvent()
    if event == "UPDATE_MACROS" or event == "SPELLS_CHANGED" then
        currentSequence = nil
        macros = {}
        actions = {}
        sequences = {}
        IndexItems()
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        actions[arg1] = nil
        SendEventForAction(arg1, "ACTIONBAR_SLOT_CHANGED", arg1)
    elseif event == "BAG_UPDATE" then
        IndexItems()
    elseif event == "PLAYER_LEAVE_COMBAT" then
        for _, sequence in pairs(sequences) do
            if currentSequence ~= sequence and sequence.index > 1 and sequence.reset.combat then
                sequence.index = 1
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        for _, sequence in pairs(sequences) do
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
frame:RegisterEvent("BAG_UPDATE")



--------------------------------------------------------------------------------
-- Slash Commands                                                              -
--------------------------------------------------------------------------------

SlashCmdList["CAST"] = function(msg, command)
    local args = command and command.args
    if not args then
        args = ParseArguments(msg)
        COMMANDS["/cast"](args)
    end

    local arg, target = GetArg(args)
    if not arg or not arg.spellSlot then return end

    local retarget = not UnitIsUnit(target, "target")
    if retarget then
        TargetUnit(target)
        -- if not UnitIsUnit(target, "target") then return end
    end            

    CastSpell(arg.spellSlot, "spell")
    if retarget then TargetLastTarget() end
end

SlashCmdList["USE"] = function(msg, command)
    local args = command and command.args
    if not args then
        args = ParseArguments(msg)
        COMMANDS["/use"](args)
    end

    local arg, target = GetArg(args)
    if not arg or not arg.itemID then return end

    local item = items[arg.itemID]
    if not item then return end
    
    local retarget = not UnitIsUnit(target, "target")
    if retarget then
        TargetUnit(target)
        -- if not UnitIsUnit(target, "target") then return end
    end            

    if item.bagID and item.slot then
        UseContainerItem(item.bagID, item.slot)
    elseif item.inventoryID then
        UseInventoryItem(item.inventoryID)
    end

    if retarget then TargetLastTarget() end
end

SlashCmdList["CASTSEQUENCE"] = function(msg, command)
    local args = command and command.args

    if currentSequence then return end

    if not args then
        args = ParseArguments(msg)
        COMMANDS["/castsequence"](args)
    end

    local arg, target = GetArg(args)
    if not arg then return end

    if arg.index > 1 then
        local reset = false
        reset = arg.reset.shift and IsShiftKeyDown() 
        reset = reset or (arg.reset.alt and IsAltKeyDown())
        reset = reset or (arg.reset.ctrl and IsControlKeyDown())
        if reset then arg.index = 1 end
    end

    local spellSlot = arg.spells[arg.index]
    
    if spellSlot then
        arg.status = 0
        arg.lastUpdate = GetTime()

        currentSequence = arg
        
        local retarget = not UnitIsUnit(target, "target")
        if retarget then
            TargetUnit(target)
            -- if not UnitIsUnit(target, "target") then return end
        end
        
        CastSpell(spellSlot, "spell")
        if retarget then TargetLastTarget() end
    end
end

SlashCmdList["STOPMACRO"] = function(msg, command)
    if command and GetArg(command.args) then 
        return false
    end
end

SlashCmdList["CANCELFORM"] = function(msg)
    local arg = GetArg(command and command.args or ParseArguments(msg))
    if arg then CancelShapeshiftForm() end
end

SLASH_CANCELFORM1 = "/cancelform"
SLASH_CASTSEQUENCE1 = "/castsequence"
SLASH_STOPMACRO1 = "/stopmacro"
SLASH_USE1 = "/use"

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
