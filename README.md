    eXtended Commands (XC) / Version 1.0 / by _brain
    https://github.com/DanielAdolfsson/xc
    
    XC is an attempt to port WoW retail macro syntax to vanilla WoW.
    This allows us to use slash commands with conditions.
    
    It's not aiming to be 100% compatible with retail-- 
    but we want it to be "close".

    1. Commands
    ---------------------------------------------------------------------------
        To commands have been implemented this far:
            /cast and /cancelform.
    
        Example:
            /cast [mod:alt] Healing Touch; Rejuvenation
            
    2. Conditions
    ---------------------------------------------------------------------------
        Implemented conditions so far:
            mod/modifier, dead, exists, help, harm, form and stance
            
        Note that they can be prefixed with "no" to invert the match.

        Example:
            nomod:alt,help
        
    3. #showtooltip
    ---------------------------------------------------------------------------
        In order to dynamically change the icon and tooltip, you need to
        place #showtooltip at the top of your macro.
        
        
    4. Issues and limitations
    ---------------------------------------------------------------------------
        - Macros must have a unique name. If something bugs out, you should 
          first try to rename it and see if that solves the problem. 
