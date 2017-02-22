-- CleverMacro for Vanilla WoW

-- Bongos
CleverMacro.RegisterActionEventHandler(function(slot, event) 
    local MAX_BUTTONS = 120

    if not BActionButton or not BActionBar then return end
    
    for i = 1, 100 do
        local bar = getglobal("BActionBar" .. i)
        if not bar then break end

        local start, stop = BActionBar.GetStart(i), BActionBar.GetEnd(i)
        
        local offset = 0
        
        local offset = BActionBar.GetPage(i);
		if offset == 0 then offset = BActionBar.GetStance(i) end
		if offset == 0 then offset = BActionBar.GetContext(i) end
        
        if slot >= start + offset and slot <= stop + offset then
            local button = getglobal("BActionButton" .. (slot - offset))
            if button then
                BActionButton.Update(button)
            end
        end
    end
end)

-- XPerl
CleverMacro.RegisterMouseOverResolver(function(frame)
    if not frame:GetName() then return end
    local _, _, name = string.find(frame:GetName(), "^XPerl_(.*)_CastClickOverlay")
    if name then
        if name == "Player" then return "player" 
        elseif name == "Target" then return "target" end
        return frame:GetParent().partyid
    end
end)

-- pfUI
CleverMacro.RegisterMouseOverResolver(function(frame)
    if frame:GetName() and string.find(frame:GetName(), "^pf") and frame.label and frame.id then
        return frame.label .. frame.id
    end
end)

-- CT

