# ElvUI Midnight QoL

> A lightweight yet powerful Quality of Life (QoL) plugin for ElvUI, designed to enhance your World of Warcraft user interface. This add-on expands the core ElvUI functionality by introducing advanced distance tracking and aura customization tools.

---

## Core Features

### 1. Customizable Crosshair
A visual center-screen indicator that assists with positioning and melee distance management during combat. 

* **Extensive Customization:**
  * Adjust **size**, **thickness**, **gap**, and **opacity**.
  * Individually toggle specific elements: *Top, Bottom, Left, Right arms, Center Dot, and Outer Circle*.
  * Add a customizable outer border (`Outline`) with adjustable thickness.
* **Smart Visibility:**
  * **Combat Only:** Automatically hides the crosshair when out of combat.
  * **Hide While Mounted:** Keeps the screen clean by hiding the UI element while riding.
* **Melee Range Tracking:**
  * Dynamically changes the color of the crosshair (or specific parts of it) when your target leaves your melee attack range.
  * Accurately calculates distance based on your class's core melee abilities.
* **Audio Alerts:** Optional sound notifications when losing melee range, featuring customizable Sound IDs and trigger intervals.
* **Color Profiles:** Support for custom `RGB` colors or automatic adaptation to your character's **Class Color**.

### 2. Aura Stack Positioning (Center Stacks)
Advanced readability settings for ElvUI's default buff and debuff frames.

* **Precise Placement:** Independently anchor stack count numbers to the `TOP`, `CENTER`, or `BOTTOM` of the aura icon.
* **Coordinate Offsets:** Fine-tune the text positioning with `X` and `Y` axis sliders.
* **Independent Configurations:** Settings are applied and adjusted separately for **Buffs** and **Debuffs**.
* **Integration:** Safely hooks into ElvUI's core functions, applying your settings to all tracked auras without conflicting with the base user interface.

---

## System Requirements

| Requirement | Details |
| :--- | :--- | 
| **Game Client** | World of Warcraft |
| **Expansion** | Midnight |
| **Version** | `12.0` - `12.05` |
| **Dependency** | `ElvUI` (This is a required base add-on) |

---

## Installation Guide

1. Download the latest release archive of the add-on.
2. Extract the `ElvUI_QoL` folder into your World of Warcraft AddOns directory:
   > `World of Warcraft/_retail_/Interface/AddOns/`
3. Launch the game and ensure both **ElvUI** and **ElvUI_QoL** are enabled in the AddOns menu on the character selection screen.
4. Access the plugin settings via the new dedicated tab within the main ElvUI configuration window (`/ec`).
