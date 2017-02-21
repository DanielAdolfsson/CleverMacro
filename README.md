# CleverMacro

*CleverMacro* is an attempt to bring WoW 2.0 macros back to vanilla.

##### Current features

* Conditionals and targets, like ```[mod:alt,@mouseover]```
* ```/cast```, ```/castsequence```, and more
* ```#showtooltip```
* Support for mouseover on unit frames
* Icons and tooltips are updated accordingly

##### Implemented conditionals

* mod, modifier, *shift*, *alt*, *ctrl*
* dead, *alive*
* form, stance

All conditionals can be prefixed with "no" to negate the result.

Conditionals in *italics* are implemented in *CleverMacro* only, and not valid in retail WoW.

##### Implemented or adapted commands

* /cast, /castsequence
* /cancelform
* /target

##### Other addons

*CleverMacro* might not support ***mouseover*** targeting when used with unit frames other than the classic Blizzard ones. Additionally, the addon might not support updating tooltips and icons on custom actionbars.

The aim is for *CleverMacro* to support the more popular addons, so you don't have to use the classic interface in order to experience all of *CleverMacro*'s features.

Supported addons thus far:

* [Luna Unit Frames](https://github.com/Aviana/LunaUnitFrames)

##### Examples

```
#showtooltip
/cast [nomod:alt] Rejuvenation; Healing Touch
```

```
#showtooltip Bear Form
/cast [mod:alt,noform] Rejuvenation; [mod:shift,noform] Healing Touch
```

##### Suggestions

If you you're missing features or have an addon you need *CleverMacro* to support, don't hesitate to open an issue.

I'm always open to improving *CleverMacro*.