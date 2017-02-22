# CleverMacro

*CleverMacro* is an attempt to bring WoW 2.0 macros back to vanilla.

#### Current features

* Conditionals and targets, like ```[mod:alt,@mouseover]```
* ```/cast```, ```/castsequence```, and more
* ```#showtooltip```
* Support for mouseover on unit frames
* Icons and tooltips are updated accordingly

#### Implemented conditionals

* mod, modifier, *shift*, *alt*, *ctrl*
* dead, *alive*
* form, stance
* combat

All conditionals can be prefixed with "no" to negate the result.

Conditionals in *italics* are implemented in *CleverMacro* only, and not valid in retail WoW.

#### Implemented or adapted commands

* /cast, /castsequence
* /cancelform
* /target

#### Other addons

*CleverMacro* might or might not work well with other addons.

If the addon you want to use provides other unit frames, then it's possible mouseover targeting won't work correctly. Likewise, if the addon provides an alternative action bar, the icons and tooltips might not update correctly.

In either case, *CleverMacro* aims to support the more popular addons out of the box.

The following addons is known to work:

* [Luna Unit Frames](https://github.com/Aviana/LunaUnitFrames)
* Bongos ActionBar
* XPerl
* pfUI
* Bartender

#### Examples

```
#showtooltip
/cast [nomod:alt] Rejuvenation; Healing Touch
```

```
#showtooltip Bear Form
/cast [mod:alt,noform] Rejuvenation; [mod:shift,noform] Healing Touch
```

#### Suggestions

If you you're missing features or have an addon you need *CleverMacro* to support, don't hesitate to open an issue.

I'm always open to improving *CleverMacro*.