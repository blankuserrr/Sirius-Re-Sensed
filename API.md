# Sirius Re-Sensed API Documentation

Sirius Re-Sensed is a comprehensive and modernized ESP (Extra Sensory Perception) library for Roblox, designed to provide detailed visual information about players and instances in a game. It utilizes modern Roblox practices for performance and offers extensive customization options.

---

## 1. Usage

### Loading the ESP System

To initialize and start the ESP system, call the `Load` method on the `EspInterface`. This will begin tracking players and rendering ESP elements.

```lua
EspInterface.Load()
```

### Unloading the ESP System

To stop the ESP system and clean up all created elements, call the `Unload` method.

```lua
EspInterface.Unload()
```

---

## 2. Configuration

The `EspInterface` exposes configuration options through `sharedSettings` and `teamSettings`. These can be modified directly before loading the system.

### `EspInterface.sharedSettings` (table)

Global settings that apply to all players.

*   `textSize`: (`number`) Default font size for text labels (e.g., name, distance). Default: `13`.
*   `textFont`: (`Enum.Font`) Default font for text labels. Default: `Enum.Font.SourceSans` (represented as `2` in older Roblox APIs).
*   `limitDistance`: (`boolean`) If `true`, ESP elements will only render up to `maxDistance`. Default: `false`.
*   `maxDistance`: (`number`) The maximum distance in studs at which ESP elements will render, if `limitDistance` is `true`. Default: `150`.
*   `useTeamColor`: (`boolean`) If `true`, ESP elements will use the player's team color (if available) instead of the configured `boxColor`, `nameColor`, etc. Default: `false`.

### `EspInterface.teamSettings` (table)

Contains settings specific to "enemy" and "friendly" players. You can configure these independently.

**Example Structure:**

```lua
EspInterface.teamSettings = {
    enemy = { -- Settings for enemy players
        enabled = false,
        box = false,
        boxColor = { Color3.new(1,0,0), 1 }, -- {Color3, Transparency}
        visibleBoxColor = { Color3.new(1,1,0), 1 }, -- Color when visible (yellow example)
        boxOutline = true,
        boxOutlineColor = { Color3.new(), 1 },
        visibleBoxOutlineColor = { Color3.new(), 1 },
        boxFill = false,
        boxFillColor = { Color3.new(1,0,0), 0.5 },
        visibleBoxFillColor = { Color3.new(1,1,0), 0.5 },
        
        -- Health Bar
        healthBar = false,
        healthyColor = Color3.new(0,1,0), -- Green
        dyingColor = Color3.new(1,0,0),    -- Red
        healthBarOutline = true,
        healthBarOutlineColor = { Color3.new(), 0.5 },

        -- Health Text
        healthText = false,
        healthTextColor = { Color3.new(1,1,1), 1 },
        healthTextOutline = true,
        healthTextOutlineColor = Color3.new(),

        -- 3D Box
        box3d = false,
        box3dColor = { Color3.new(1,0,0), 1 },
        visibleBox3dColor = { Color3.new(1,1,0), 1 },

        -- Name Text
        name = false,
        nameColor = { Color3.new(1,1,1), 1 },
        nameOutline = true,
        nameOutlineColor = Color3.new(),

        -- Weapon Text
        weapon = false,
        weaponColor = { Color3.new(1,1,1), 1 },
        weaponOutline = true,
        weaponOutlineColor = Color3.new(),

        -- Distance Text
        distance = false,
        distanceColor = { Color3.new(1,1,1), 1 },
        distanceOutline = true,
        distanceOutlineColor = Color3.new(),

        -- Tracer (line from viewport origin to player)
        tracer = false,
        tracerOrigin = "Bottom", -- "Middle", "Top", "Bottom"
        tracerColor = { Color3.new(1,0,0), 1 },
        visibleTracerColor = { Color3.new(1,1,0), 1 },
        tracerOutline = true,
        tracerOutlineColor = { Color3.new(), 1 },

        -- Off-screen Arrow (points to off-screen players)
        offScreenArrow = false,
        offScreenArrowColor = { Color3.new(1,1,1), 1 },
        offScreenArrowSize = 15,
        offScreenArrowRadius = 150,
        offScreenArrowOutline = true,
        offScreenArrowOutlineColor = { Color3.new(), 1 },

        -- Chams (Highlights player model)
        chams = false,
        chamsVisibleOnly = false, -- If true, chams only render when player is visible
        chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
        visibleChamsFillColor = { Color3.new(1,1,0), 0.5 },
        chamsOutlineColor = { Color3.new(1,0,0), 0 },
        visibleChamsOutlineColor = { Color3.new(1,1,0), 0 },

        -- Skeleton (Draws lines between player joints)
        skeleton = false,
        skeletonColor = { Color3.new(1,1,1), 1 },
        visibleSkeletonColor = { Color3.new(1,1,0), 1 },
    },
    friendly = { -- Settings for friendly players (same structure as enemy)
        -- ...
    }
}
```

---

## 3. Custom Callbacks

The library allows you to override game-specific functions to integrate with your game's unique logic. This makes the ESP system truly game-agnostic.

### `EspInterface.RegisterCallbacks(callbacks: {[string]: any})`

Registers custom functions to be used by the ESP system. The `callbacks` table should contain key-value pairs where the key is the name of the function to override, and the value is your custom function.

**Available Callbacks (and their default signatures):**

*   `getWeapon(player: Player): string`
    *   **Default:** Returns `"Unknown"`.
    *   **Purpose:** Should return the name of the weapon the given `player` is currently holding.
*   `isFriendly(player: Player): boolean`
    *   **Default:** Returns `true` if `player.Team` is the same as `localPlayer.Team`.
    *   **Purpose:** Should return `true` if the `player` is considered an ally, `false` otherwise. This determines whether `enemy` or `friendly` settings are applied.
*   `getTeamColor(player: Player): Color3?`
    *   **Default:** Returns `player.Team.TeamColor.Color` if `player.Team` and `player.Team.TeamColor` exist.
    *   **Purpose:** Should return the `Color3` of the player's team. Used when `sharedSettings.useTeamColor` is `true`.
*   `getCharacter(player: Player): Model?`
    *   **Default:** Returns `player.Character`.
    *   **Purpose:** Should return the `Model` instance representing the `player`'s character.
*   `getHealth(player: Player): (number, number)`
    *   **Default:** Returns `humanoid.Health, humanoid.MaxHealth` if a `Humanoid` is found, otherwise `100, 100`.
    *   **Purpose:** Should return the current health and maximum health of the given `player`.

**Example Usage:**

```lua
EspInterface.RegisterCallbacks({
    getWeapon = function(player)
        local character = player.Character
        if character then
            local tool = character:FindFirstChildOfClass("Tool")
            if tool then
                return tool.Name
            end
        end
        return "Fists"
    end,
    isFriendly = function(player)
        -- Custom logic for team detection
        return player:GetAttribute("IsFriendly") == true
    end,
    -- ... other callbacks
})
```

---

## 4. Internal Objects

The following objects are used internally by the `EspInterface` to manage player-specific ESP elements. You typically won't interact with these directly.

### `EspObject`

Manages the 2D and 3D ESP elements (boxes, text, tracers, skeleton) for a single player.

### `ChamObject`

Manages the `Highlight` instance used for "chams" (player model outlines/fills) for a single player.
