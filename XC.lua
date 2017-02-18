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
XC.inAction = false
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
            for _, mod in ipairs(explode(v, "/")) do
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
            for _, form in ipairs(explode(v, "/")) do
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

function XC.ParseSpell(name)
    local _, e, info = string.find(name, "^%s*{([^}]+)}%s*")
    
    local cost = nil
    
    if info ~= nil then
        name = string.sub(name, e + 1)
        local parts = XC.Explode(info, ",")
        cost = tonumber(XC.Trim(parts[1]))
    end

    local spellId = XC.GetSpellId(name)
    if spellId == nil then return end
    
    return spellId, cost
end

function XC.DetermineSpell(name)
    local index = GetMacroIndexByName(name)
    local xtt = false
    if index > 0 then
        local _, _, body = GetMacroInfo(index)
        local _, _, arg = string.find(body, "^%s*#showtooltip([^\n]*)")
        if arg ~= nil then
            xtt = true
            if XC.Trim(arg) == "" then
                -- We'll parse each /cast manually
                for _, line in XC.Explode(body, "\n") do
                    local _, _, arg = string.find(line, "^%s*/cast%s+(.*)")
                    if arg ~= nil then
                        local spell = XC.Fetch(arg)
                        if spell ~= nil and XC.Trim(spell) ~= "" then
                            local spellId, cost = XC.ParseSpell(spell)
                            if spellId ~= nil then
                                return spellId, cost
                            end
                            break
                        end
                    end
                end
            else
                local spell = XC.Fetch(arg)
                if spell ~= nil and XC.Trim(spell) ~= "" then
                    local spellId, cost = XC.ParseSpell(spell)
                    if spellId ~= nil then
                        return spellId, cost
                    end
                end
            end
            
            return 0
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
        if index ~= nil then
            GameTooltip:SetSpell(index, "spell")
            local _, rank = GetSpellName(index, "spell")
            
            GameTooltipTextRight1:SetText("|cff808080" .. rank .."|r");
            GameTooltipTextRight1:Show();
            GameTooltip:Show()
        end
        return true
    end
    
    return false
end

--------------------------------------------------------------------------------
-- Overrides                                                                   -
--------------------------------------------------------------------------------

XC._.ActionButton_Update = ActionButton_Update
function ActionButton_Update()
    local slot = ActionButton_GetPagedID(this)
    XC.actions[this:GetName()] = nil
    if slot ~= nil then
        local text = GetActionText(slot)
        if text ~= nil then
            XC.actions[this:GetName()] = text
        end
    end
    XC._.ActionButton_Update(this)
end

XC._.SendChatMessage = SendChatMessage
function SendChatMessage(msg, ...)
    if XC.inAction and string.find(msg, "^%s*#showtooltip") then
        return
    end
    XC._.SendChatMessage(msg, unpack(arg))
end

XC._.UseAction = UseAction
function UseAction(slot, checkCursor, onSelf)
    XC.inAction = true
    XC._.UseAction(slot, checkCursor, onSelf)
    XC.inAction = false
end

XC._.GameTooltip = {}

XC._.GameTooltip.SetAction = GameTooltip.SetAction
function GameTooltip.SetAction(self, slot)
    local text = GetActionText(slot)
    if text ~= nil then
        if not XC.ShowTooltip(text) then
            XC.currentMacro = nil
            XC._.GameTooltip.SetAction(self, slot)
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

    if XC.currentMacro then
        XC.ShowTooltip(XC.currentMacro)
    end
    
    for k, v in pairs(XC.actions) do
        if v ~= nil then
            local icon = getglobal(k .. "Icon");
            local spell, cost = XC.DetermineSpell(v)
            local normalTexture = getglobal(k .. "NormalTexture");
            if spell ~= nil and spell > 0 then
                local texture = GetSpellTexture(spell, "spell")
                icon:SetTexture(texture)
                
                
                local cooldown = getglobal(k .. "Cooldown");
                local start, duration, enable = GetSpellCooldown(spell, "spell");
                CooldownFrame_SetTimer(cooldown, start, duration, enable);
                
                
                
                
                local notEnoughMana = UnitMana("player") < (cost or 0)
                local isUsable = not notEnoughMana
                
                if isUsable then
                    icon:SetVertexColor(1.0, 1.0, 1.0);
                    normalTexture:SetVertexColor(1.0, 1.0, 1.0);
                elseif notEnoughMana then
                    icon:SetVertexColor(0.5, 0.5, 1.0);
                    normalTexture:SetVertexColor(0.5, 0.5, 1.0);
                else
                    icon:SetVertexColor(0.4, 0.4, 0.4);
                    normalTexture:SetVertexColor(1.0, 1.0, 1.0);
                end
            elseif spell ~= nil and spell == 0 then
                icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end
    end
end
 
function XC.OnEvent()
    -- XC.Log("LE EVENT " .. event)
end

XC.frame = CreateFrame("Frame", nil, UIParent)
XC.frame:RegisterEvent("SPELL_UPDATE_USABLE")
XC.frame:SetScript("OnUpdate", XC.OnUpdate)
XC.frame:SetScript("OnEvent", XC.OnEvent)

--------------------------------------------------------------------------------
-- Slash Commands                                                              -
--------------------------------------------------------------------------------

SlashCmdList["CAST"] = function(msg)
    local name, target = XC.Fetch(msg)
    if name ~= nil then
        local spellId = XC.ParseSpell(name)
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
