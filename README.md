    eXtended Commands (XC) / Version 1.0 / by _brain
    https://github.com/DanielAdolfsson/xc
    
    XC is an attempt to port WoW retail macro syntax to vanilla WoW.
    This allows us to use slash commands with conditions.
    
    It's not aiming to be 100% compatible with retail-- 
    but we want it to be "close".

    1. Commands
    ---------------------------------------------------------------------------
        To commands have been implemented this far:
            /xcast and /xcancelform.
    
        The syntax of both should be similar to retail WoW 
            /cast and /cancelform.
    
        Example:
            /xcast [mod:alt] Healing Touch; Rejuvenation
            
    2. Conditions
    ---------------------------------------------------------------------------
        Implemented conditions so far:
            mod/modifier, dead, exists, help, harm, form and stance
            
        Note that they can be prefixed with "no" to invert the match.

        Example:
            nomod:alt,help
        
    2. #showtooltip
    ---------------------------------------------------------------------------
        While #showtooltip isn't supported, XC do have something similar.
        
        Put the following line at the top of your macro:
            /xtt
            
        It's also possible to use conditions with /xtt    
        
        Example
            /xtt
            /xtt [noform] Bear Form
        
        Note
            /xtt is eperimental and it's not certain it will work with other 
            action bars than the blizzard ones.
        
    3. Issues and limitations
    ---------------------------------------------------------------------------
        - Macros must have a unique name. If something bugs out, you should 
          first try to rename it and see if that solves the problem. 
