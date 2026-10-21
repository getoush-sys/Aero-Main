# Aero — Timing Builder Guide

Everything the in-game Timing Builder tab does, and how to write timings + modules.

A **timing** tells the auto-parry how to defend against one attack. When an attacker
plays an animation / spawns a part / plays a sound / replicates an effect, Aero looks
up a matching timing by its **id** and either runs its **static actions** or its
**module** to schedule a parry/dodge/block at the right moment.

The builder has four sub-tabs: **General**, **Create Timing**, **Edit Timing**, **Modules**.

> For the exact meaning of every field abbreviation (pfh, ihbc, duih, imxd, …) see
> **TIMING_FIELDS.txt** — this guide references it rather than repeating it.

## 1. Timing types

Every timing is one of four types, matched by a different id:

| Type       | Matches                          | id field | `self` object (in modules)      |
|------------|----------------------------------|----------|---------------------------------|
| Animation  | an attacker's animation          | `_id`    | `self.entity`, `self.track`     |
| Part       | a spawned part (projectile, AoE) | `pname`  | `self.part`                     |
| Sound      | a played sound                   | `_id`    | `self.owner`                    |
| Effect     | a replicated effect              | `ename`  | `self.owner`, `self.data`       |

Animation is by far the most common. Part/Sound/Effect are for attacks that are better
recognized by the projectile/sound/effect they create than by an animation.

---

## 2. General tab

Logger + data management.

- **Show Animation Visualizer** (+keybind) — draws attackers' animation info in-world so
  you can read animation IDs while testing.
- **Show Logger Window** (+keybind) — opens the on-screen logger that lists incoming
  attacks (their id, distance, and whether a timing already exists).
- **Log Known Timings** — also log attacks that already have a timing (off = only log
  missing ones).
- **Minimum / Maximum Logger Distance** — only log attackers within this distance band
- **Blacklisted Keys** + **Remove Selected Keys** — hide specific ids from the logger.
- **Export Timings** — copies ALL your custom timings + your user modules into one
  `LUMA1:...` line on your clipboard. Send that to a developer to share your work.
- **Reset Timing Data** (double-click) — wipes every custom timing and user module,
  reverting to the original baked-in set. Not reversible in-game, so it double-confirms.

---

## 3. Create Timing tab

Builds a brand-new timing.

1. **Timing Type** — Animation / Part / Sound / Effect (picks which id field + fields apply).
2. **Timing Name** — a readable label (shown in logs).
3. **Timing ID** — the id to match (`rbxassetid://…` for Animation/Sound, the part name
   for Part, the effect name for Effect).
4. **Behavior** — *Static* (use the Actions you define below) or *Module* (run a module
   script instead — pick it from the **Module** dropdown).
5. Fill in the fields (hitbox, distance band, flags, prediction, fallbacks — see
   TIMING_FIELDS.txt) and, for static timings, add **Actions** (see §5).
6. **Create Timing** — saves it into your config.

Type-specific fields show/hide automatically (e.g. prediction fields only for Animation).

---

## 4. Edit Timing tab

Edit an existing timing — yours OR a baked-in one.

- **Timing** dropdown (searchable) — one row per timing (your config overrides the
  baked-in one of the same id, so there are no duplicate rows).
- Every field from Create Timing is editable here, live.
- **Rename Timing** / **Delete Timing**.
- **Editing a baked-in timing is transparent**: the first change silently copies it into
  your config (so it saves and can be shared), and further edits go to that copy. Delete
  removes your copy and reverts to the baked-in original.

---

## 5. Actions (static timings)

An **action** is one scheduled reaction. A static timing can have several. In the builder
each action has: **Action Type** (Parry / Dodge / Start Block / …), **Action Delay (ms)**
(when to fire, measured from the start of the attack), **Hitbox** (L/W/H), **Ignore
Hitbox Check** (fire regardless of the hitbox), and **Action Name**. Use **Create /
Duplicate / Remove Action** to manage the list.

Action types: `Parry`, `Dodge`, `Forced Full Dodge`, `Jump`, `Start Block`, `End Block`,
`Teleport Up`, `Start Slide`, `End Slide`, `Start Crouch`, `End Crouch`.

---

## 6. Modules tab

For attacks too dynamic for static actions — a module is a Lua script that decides the
reaction at runtime (based on distance, weapon, mantra, sounds, projectiles, etc.).

- **Modules** dropdown (searchable) — pick a module to view/edit its source. Selecting one
  loads it into the editor (editable). Baked-in internal modules appear here too; saving an
  edit writes a filesystem module of the same name that overrides the internal one.
- **Code editor** — fully functional code editor
- **Refresh List** — reloads the module list + re-runs modules.
- **Save Code** — **validates before saving** (compiles it and checks it returns a
  function). If it fails, it shows the error and does NOT save, so a broken edit can't
  silently disable a timing.
- **Delete Module**.
- **New Module Name** + **Template** + **Create Module** — pick a template (its code
  previews in the editor **read-only**), name it, and create. The template's first line is
  a `-- Timing type:` comment telling you which type it's for. To edit a template's code,
  create a module from it first.

---

## ‼️ IMPORTANT — basic weapon attacks already have handlers

**Do NOT write your own module or a static timing for ordinary weapon attacks** (M1s,
uppercuts, running attacks, aerials, flourishes). Aero ships generic modules that already
handle every weapon type by reading the weapon's stats — reusing them is more accurate and
means you never re-solve the same attack per weapon. Point the timing's **Module** at the
matching one:

| Attack kind        | Use this module            |
|--------------------|----------------------------|
| M1 / basic swing   | **WeaponTest**             |
| Uppercut           | **WeaponUppercutTest**     |
| Running attack     | **WeaponRunningAttackTest**|
| Aerial attack      | **WeaponAerialAttackTest** |
| Flourish           | **WeaponFlourishTest**     |

How: in **Create Timing** (or Edit Timing), set **Behavior = Module** and choose the module
above for the attack's animation id — that's it, no code and no static actions. These modules
already branch on weapon type / swing speed / reach, so they cover new weapons automatically.
Only write a custom module when an attack is genuinely special (unique mechanic, projectile,
mantra, telegraph, etc.) — never for a plain weapon attack.

---

## 7. Writing a module

A module returns a function called when its timing triggers:

```lua
---@type Action
local Action = getfenv().Action

return function(self, timing)
    local action = Action.new()
    action._type = "Parry"
    action._when = 500                        -- ms into the attack
    action.hitbox = Vector3.new(40, 15, 40)
    action.name = "My Timing"
    return self:action(timing, action)        -- schedule it
end
```

### `self` — the live defender
Depends on the timing type:

- `self.entity` — the attacker Model (Animation timings).
- `self.track` — the attacker's AnimationTrack (Animation). `self.track.Speed`,
  `.TimePosition`, `.IsPlaying` are commonly read.
- `self.owner` — who produced the effect/sound (Effect / Sound timings).
- `self.data` — the replicated effect's data table (Effect timings).
- `self.part` — the spawned part (Part timings).
- `self.tasks` — the actions currently scheduled for this defender.
- `self.tmaid` — a Maid for connections you make (auto-cleaned).

### `self` methods
- `self:action(timing, action)` — schedule an action. The core call.
- `self:distance(inst)` — distance from you to an instance/model.
- `self:hook(name, fn)` — override a defender check (`"target"`, `"stopped"`, `"rc"`).
- `self:uid(n)` — a unique id (used with RepeatInfo).
- `self:srpue(entity, timing, info)` — start a repeat-parry-until-end loop.
- `self:notify(timing, fmt, ...)` — dev notification.
- `self:hc(...)` / `self:fpc(...)` / `self:fsecs(timing)` — hitbox / facing-prediction /
  timing-seconds helpers used inside advanced modules.

### Injected globals (via `getfenv()`)
Grab these at the top of a module, e.g. `local Action = getfenv().Action`:

**Core:** `Action`, `Timing`, `PartTiming`, `Defense`, `Task`, `Maid`, `Signal`,
`InputClient`, `TaskSpawner`, `Targeting`, `Finder`, `Logger`, `HitboxOptions`,
`RepeatInfo`, `StateListener`, `Latency`, `Configuration`.

**Global helper modules (Modules/Globals):** `Mantra`, `Weapon`, `Waiter`,
`ProjectileTracker`, `ProjectileListener`, `TerrainListener` — covered in full in §8.

### Latency
Real-world waits should subtract your ping: `task.wait(0.4 - Latency.rtt())`. Scheduling
via `self:action` already accounts for latency, so action `_when` is in raw animation time.

---

## 8. Helper modules in depth

These live in `Modules/Globals` and are injected into every module's environment. Grab one
with `local X = getfenv().X` at the top of your module.

### 8.1 Mantra — read the attacker's mantra investment

```lua
local Mantra = getfenv().Mantra
local data = Mantra.data(entity, "Mantra:StreamMetal{{Chain Pull}}")
```

`Mantra.data(entity, name)` looks up the mantra on the entity (by the exact backpack name,
form `Mantra:<InternalId>{{Display Name}}`) and parses its RichStats. **Always returns a
table** (all zero/false if the mantra or stats aren't found), so you can index it without
nil-checking. Fields:

| Field        | Type    | Meaning (ingredient)         |
|--------------|---------|---------------------------------------|
| `perfect`    | number  | Perfect Lens count                    |
| `crystal`    | number  | Crystal Lens count                    |
| `stratus`    | number  | Stratus Stone count                   |
| `cloud`      | number  | Cloudstone count                      |
| `glass`      | number  | Glass Stone count                     |
| `magnifying` | number  | Magnifying Stone count                |
| `drift`      | number  | Drift Shard count                     |
| `rush`       | number  | Rush Shard count                      |
| `blast`      | boolean | has the [Blast] modifier              |
| `spring`     | boolean | has the [Spring] modifier             |
| `tornado`    | boolean | has the [Tornado] modifier            |

**Use it to size the hitbox / timing by how much the attacker invested.** Bigger lenses =
bigger range, so scale the hitbox and/or the `_when`:

```lua
local Action = getfenv().Action
local Mantra = getfenv().Mantra

return function(self, timing)
    local dist = self:distance(self.entity)
    local data = Mantra.data(self.entity, "Mantra:BeamIce{{Ice Beam}}")
    local range = data.stratus * 2 + data.cloud * 1   -- extra studs from investment

    local action = Action.new()
    action._type = "Parry"
    action._when = math.min(570 + dist * 5, 1000)
    action.hitbox = Vector3.new(15 + range, 15 + range, 85)
    action.name = "Ice Beam"
    timing.hitbox = action.hitbox
    return self:action(timing, action)
end
```

> Finding the name string: the `Mantra:Id{{Display}}` key is exactly how it appears in the
> attacker's Backpack. Copy it from an existing mantra module of the same move, or read it
> off the backpack while testing.

### 8.2 Weapon — read the attacker's equipped weapon

```lua
local Weapon = getfenv().Weapon
```

Two functions:

- **`Weapon.data(entity)`** → a table, or **nil** if no weapon is found (always nil-check):

  | Field     | Type    | Meaning                                              |
  |-----------|---------|------------------------------------------------------|
  | `hw`      | Model   | the HandWeapon model                                 |
  | `ss`      | number  | current SwingSpeed                                   |
  | `oss`     | number  | original SwingSpeed (attribute "OldValue")           |
  | `length`  | number  | weapon Length (reach) — good for scaling the hitbox  |
  | `type`    | string  | weapon type: Sword, Dagger, Greatsword, Spear, …     |
  | `nemesis` | boolean | has the Nemesis particle                             |

- **`Weapon.handWeapon(entity)`** → just the HandWeapon `Model` (or nil). Use it for
  `hw:GetAttribute("WeaponName")` to tell specific weapons apart.

**Example:**

Branch on the exact weapon when several share one animation (e.g. relic axe and greataxe)

```lua
local hw = Weapon.handWeapon(self.entity)
if hw and hw:GetAttribute("WeaponName") == "Relic Axe" then ... end
```

### 8.3 Waiter — find / wait for animation tracks

```lua
local Waiter = getfenv().Waiter
```

- **`Waiter.ftrack(animId, animator)`** → the playing `AnimationTrack` whose
  `Animation.AnimationId` matches, or **nil** right now (non-blocking). Use to *gate* on an
  attacker actually playing an animation (e.g. confirm a Sound timing corresponds to the
  real move):
  ```lua
  if not Waiter.ftrack("rbxassetid://8172871094", animator) then return end
  ```
- **`Waiter.fet(animId, animator)`** → same, but **yields until** the track appears (blocks
  the module's task). Use when the track is expected momentarily (repeat-parry setups).
- **`Waiter.stw(defender, seconds, callback)`** → a ping-adjusted stepped wait: repeatedly
  `task.wait()` + calls `callback()` until `seconds - ping` elapse. For polling during a window.

Get the animator with: `local animator = entity:FindFirstChild("Humanoid")
:FindFirstChild("Animator")` (nil-check each step).

### 8.4 ProjectileTracker — claim ONE thrown projectile

```lua
local ProjectileTracker = getfenv().ProjectileTracker
```

`ProjectileTracker.new(filter)` registers a tracker; when a projectile spawns under
`workspace.Thrown`, the first waiting tracker whose `filter(child)` returns true **claims**
it (deduped so no two trackers take the same one). Retrieve with `tracker:wait()` (yields).

```lua
local PartTiming = getfenv().PartTiming
local Action = getfenv().Action
local ProjectileTracker = getfenv().ProjectileTracker
local Defense = getfenv().Defense
local Latency = getfenv().Latency

return function(self, timing)
    -- Register BEFORE the projectile spawns (must be armed in time).
    local tracker = ProjectileTracker.new(function(candidate)
        return candidate.Name == "MyProjectile_" .. self.entity.Name
    end)

    task.wait(0.05 - Latency.rtt())

    -- Close enough: just parry the throw, don't bother tracking.
    if self:distance(self.entity) <= 25 then
        local a = Action.new()
        a._type, a._when, a.ihbc, a.name = "Parry", 0, true, "Close"
        return self:action(timing, a)
    end

    -- Otherwise defend the projectile part itself.
    local a = Action.new()
    a._type, a._when, a.name = "Parry", 0, "Projectile"
    local pt = PartTiming.new()
    pt.uhc, pt.duih, pt.cbm = true, true, true
    pt.name = "Projectile"
    pt.hitbox = Vector3.new(50, 50, 100)
    pt.actions:push(a)
    Defense.cdpo(tracker:wait(), pt)   -- hand the claimed part + a part-timing to the defender
end
```

Key points: **create the tracker first** (before any `wait`), the filter usually matches
`"<Name>_" .. self.entity.Name`, and you finish by handing `tracker:wait()` to
`Defense.cdpo(part, partTiming)`. Best for single-projectile attacks.

### 8.5 ProjectileListener — react to EVERY thrown projectile

```lua
local ProjectileListener = getfenv().ProjectileListener
local listener = ProjectileListener.new("MyMove")   -- id keys the connection
listener:connect(function(child)
    -- fires for every child added to workspace.Thrown; filter + handle each yourself
end)
```

Unlike the tracker (one projectile, pulled via `:wait()`), the listener **pushes** every
projectile to your callback. Its `identifier` dedups at the listener level — creating a new
one with the same id replaces the old handler, so re-running the module doesn't stack
listeners. Best for barrages / clouds of many projectiles.

### 8.6 TerrainListener — react to things spawned under Terrain

```lua
local TerrainListener = getfenv().TerrainListener
local listener = TerrainListener.new("MyGroundMove")   -- make ONCE, outside the handler
```

Same shape as ProjectileListener but watches `workspace.Terrain.ChildAdded` — for ground
AoE / sludge / spikes that spawn as terrain children. Create the listener **once at module
load** (top level, not inside the returned function) so multiple runs share it, then
`:connect` inside the handler:

```lua
local Action = getfenv().Action
local TerrainListener = getfenv().TerrainListener
local listener = TerrainListener.new("ShadowSludge")

return function(self, timing)
    if self:distance(self.owner) >= 50 then return end
    local hrp = self.owner:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    listener:connect(function(child)
        if child.Name ~= "REP_EMIT" or not child:IsA("Attachment") then return end
        task.wait(0.02)
        if (child.Position - hrp.Position).Magnitude >= 5 then return end
        timing.fhb = false
        local a = Action.new()
        a._type, a._when, a.ihbc, a.name = "Parry", 0, true, "Terrain AoE"
        self:action(timing, a)
    end)
end
```

### 8.7 Choosing between them

- Attack **reaches / homes** at you → `Weapon` / `Mantra` to size it, plain Animation timing.
- One animation, **different weapons/variants** → `Weapon.handWeapon(...):GetAttribute(...)`.
- Move identified by a **sound** → gate with `Waiter.ftrack`.
- **One** projectile → `ProjectileTracker`.
- **Many** projectiles → `ProjectileListener`.
- **Ground** AoE → `TerrainListener`.

---

## 9. Templates

The Modules tab ships many starter templates, each a real archetype from the shipped
modules. Each opens with a `-- Timing type:` comment. Preview them read-only from the dropdown;
create a module to edit one.

---

## 10. Persistence, sharing, and reset

- **Auto-save** — edits save to your loaded config automatically. If none is loaded, a
  `MyTimings` config is created and set to autoload, so your work persists across sessions.
- **Export / Import** — Export Timings gives a `LUMA1:` line. A developer runs
  `ImportTimings.py` (in the source root), pastes the line, reviews the diff, confirms, and
  it merges your timings into `truth.txt` + your modules into `Modules/` (with a versioned
  backup under `TimingHistory/`).
- **Reset Timing Data** — wipes all custom timings + user modules back to the baked-in set.