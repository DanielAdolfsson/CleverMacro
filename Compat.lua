-- CleverMacro for Vanilla WoW

-- Support for Bongos
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

