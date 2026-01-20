# Project Context: Isometric 2D RPG (Godot 4)

## 1. Tech Stack & Constraints

| Component | Choice |
|-----------|--------|
| Engine | Godot 4.x (Standard 2D render pipeline) |
| Language | GDScript (Strongly typed preferred) |
| Visual Style | Isometric 2D |
| Camera | Fixed Isometric angle (16:9 Aspect Ratio) |
| Input | Mouse-only (Point & Click) |

### Tile & Grid Specifications
- **Tile Size:** 128×64 pixels (2:1 isometric ratio)
- **Chunk Size:** 16×16 tiles (2048×1024 pixels per chunk)
- **Active Chunks:** 3×3 grid around player (9 chunks loaded max)
- **Unload Distance:** Chunks beyond 2-chunk radius are queued for cleanup

---

## 2. Core Architectural Rules

### The "Golden Rule" of Isometric Coordinates

| Domain | Coordinate Type | Used For |
|--------|-----------------|----------|
| Logic | `Vector2i` (Grid) | Pathfinding, chunk generation, game state |
| Visuals | `Vector2` (Screen) | Sprites, tweens, rendering |

**Conversion Functions:**
```gdscript
# Grid → Screen
var screen_pos: Vector2 = tilemap.map_to_local(grid_pos)

# Screen → Grid
var grid_pos: Vector2i = tilemap.local_to_map(screen_pos)
```

> ⚠️ **Never write manual isometric math formulas** unless absolutely necessary. Trust the TileMap conversion functions.

### Y-Sorting & Depth

1. **Root Node:** All rendering nodes must be children of a `Node2D` with **Y-Sort Enabled**.
2. **Sprite Offsets:** All sprites (Player, Enemies, Trees, Props) must have their `Offset` set so the **feet/base of the object is at (0,0)** local position.

> ⚠️ **Why this matters:** If the sprite center is at (0,0), Y-sorting will glitch and characters will clip through walls/objects.

### Pathfinding (AStarGrid2D)

- **Use:** `AStarGrid2D` for all movement
- **Avoid:** `NavigationAgent2D` (unless physics-based movement is required)
- **Heuristic:** `HEURISTIC_MANHATTAN` or `HEURISTIC_OCTILE` for isometric grids
- **Diagonal Mode:** `DIAGONAL_MODE_IF_AT_LEAST_ONE_WALKABLE`
- **Updates:** When a chunk is generated/deleted, update the `AStarGrid2D` region **immediately**

```gdscript
# When updating pathfinding grid
func update_astar_region(chunk_origin: Vector2i, chunk_size: Vector2i, walkable: bool) -> void:
    for x in range(chunk_size.x):
        for y in range(chunk_size.y):
            var cell := chunk_origin + Vector2i(x, y)
            astar.set_point_solid(cell, not walkable)
```

---

## 3. Collision & Interaction Layers

### TileMap Layers
| Layer Index | Name | Purpose |
|-------------|------|---------|
| 0 | Ground | Base terrain (always walkable) |
| 1 | Obstacles | Walls, rocks, water (blocks pathfinding) |
| 2 | Decoration | Visual-only elements (no collision) |

### Physics Layers (if needed)
| Bit | Name | Used By |
|-----|------|---------|
| 1 | World | Static environment colliders |
| 2 | Player | Player character |
| 3 | Enemies | Enemy characters |
| 4 | Interactables | Chests, doors, NPCs |

### Hitbox/Hurtbox Detection (No Physics Layers)
Hitboxes and Hurtboxes use Area2D overlap detection, NOT physics layers:
- Both have `collision_layer = 0` and `collision_mask = 0`
- Detection via `monitoring`/`monitorable` flags
- `HitboxComponent` actively monitors for `HurtboxComponent` entries

### Interaction System
- **Detection:** `Area2D` with `input_pickable = true` for clickable objects
- **Highlight:** Shader-based outline or modulate on hover
- **Priority:** Interactables > Enemies > Ground (for click targeting)

---

## 4. Player Controller (8-Way Movement)

### Direction System
Separate **Physics Position** from **Visual Direction**.

```gdscript
enum Direction { N, NE, E, SE, S, SW, W, NW }

# Map normalized vector to direction
func vector_to_direction(dir: Vector2) -> Direction:
    var angle := snappedf(dir.angle(), PI / 4)
    # ... mapping logic
```

### Animation Direction Mapping
| Direction | Angle Range | Sprite Facing |
|-----------|-------------|---------------|
| E | -22.5° to 22.5° | Right |
| SE | 22.5° to 67.5° | Down-Right |
| S | 67.5° to 112.5° | Down |
| ... | ... | ... |

### Hysteresis Buffer
Add a **±5° buffer** to direction changes to prevent sprite flickering at boundary angles:

```gdscript
const DIRECTION_HYSTERESIS := deg_to_rad(5.0)
var current_direction: Direction
var direction_angle_cache: float

func update_direction(new_dir: Vector2) -> void:
    var new_angle := new_dir.angle()
    if absf(new_angle - direction_angle_cache) > DIRECTION_HYSTERESIS:
        direction_angle_cache = new_angle
        current_direction = vector_to_direction(new_dir)
```

---

## 5. Infinite World (Chunking)

### Chunk Management
```gdscript
var loaded_chunks: Dictionary = {}  # { Vector2i: ChunkData }

func get_chunk_coord(world_pos: Vector2) -> Vector2i:
    var grid_pos := tilemap.local_to_map(world_pos)
    return Vector2i(
        floori(float(grid_pos.x) / CHUNK_SIZE),
        floori(float(grid_pos.y) / CHUNK_SIZE)
    )
```

### Loading Strategy
1. Calculate player's current chunk coordinate
2. Load all chunks in 3×3 radius (if not already loaded)
3. `queue_free()` chunks outside the active radius
4. Update `AStarGrid2D` region for each chunk change

### Chunk Data Structure
```gdscript
class_name ChunkData
var coord: Vector2i
var tiles: Array[int]
var entities: Array[EntityData]
var is_generated: bool = false
```

---

## 6. Combat & Distance System

### Distance Check Types

| Check Type | Method | Use Case |
|------------|--------|----------|
| AOE/Aura | Shape intersection (`Area2D.get_overlapping_areas()`) | Persistent effects, ground AOE |
| Melee | Shape intersection (arcs, cones, lines) | Sword swings, stabs |
| Ranged | Edge-to-edge math | Bows, spells, aggro range |

**Ranged Formula:** `distance <= range + attacker_radius + target_radius`

### Display Units
- **Internal:** Tiles (logic), Pixels (visuals)
- **External (UI):** Meters (1 tile = 1 meter)
- **Speed:** Displayed as "X m/s"

### Area Scaling (AOE Effects)
Stats increase **Area**, not Radius:
```gdscript
NewRadius = BaseRadius * sqrt(1.0 + percent_area_bonus)
```
Visual ring must scale 1:1 with collision shape.

### Hitbox/Hurtbox System

| Component | Role | Area2D Config |
|-----------|------|---------------|
| `HurtboxComponent` | Entity collision radius (passive target) | `monitorable=true`, `monitoring=false` |
| `HitboxComponent` | Attack/damage source (active detector) | `monitorable=false`, `monitoring=true` |

**Key Classes:**
- `RangeChecker` - Unified range check API
- `ShapeFactory` - Generate melee attack shapes
- `AreaScaler` - Area-based stat scaling
- `DistanceConverter` - Unit conversion and display formatting

### Combat Model (TBD)

| Aspect | Planned Approach |
|--------|------------------|
| Combat Type | TBD (Real-time / Turn-based / Hybrid) |
| Targeting | Click-to-target with visual indicator |
| Health System | Component-based (`HealthComponent`) |
| Damage | Signal-driven (`damage_received(amount, type, source)`) |

---

## 7. Project Structure

```
res://
├── assets/
│   ├── sprites/
│   │   ├── characters/
│   │   ├── tiles/
│   │   └── ui/
│   ├── audio/
│   └── shaders/
├── scenes/
│   ├── main/
│   │   └── game.tscn
│   ├── player/
│   │   └── player.tscn
│   ├── world/
│   │   ├── chunk.tscn
│   │   └── tilemap.tscn
│   ├── enemies/
│   ├── interactables/
│   └── ui/
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd
│   │   ├── game_constants.gd
│   │   ├── pathfinding_manager.gd
│   │   └── world_manager.gd
│   ├── player/
│   │   ├── player_controller.gd
│   │   └── player_input.gd
│   ├── world/
│   │   ├── chunk_generator.gd
│   │   └── tile_texture_generator.gd
│   ├── components/
│   │   ├── entity_controller.gd
│   │   ├── hurtbox_component.gd
│   │   └── hitbox_component.gd
│   ├── utils/
│   │   ├── distance_converter.gd
│   │   ├── area_scaler.gd
│   │   ├── shape_factory.gd
│   │   └── range_checker.gd
│   ├── effects/
│   │   ├── click_marker.gd
│   │   └── range_indicator.gd
│   └── resources/
│       ├── entity_data.gd
│       └── chunk_data.gd
└── resources/
    ├── tilesets/
    └── data/
```

---

## 8. Coding Conventions (GDScript)

### Typing
```gdscript
# ✅ Good - Static typing
func move_to(target: Vector2) -> void:
    pass

func get_health() -> int:
    return _health

# ❌ Avoid - Untyped
func move_to(target):
    pass
```

### Signals
**Pattern:** `signal <noun>_<past_tense_verb>(params)`

```gdscript
# ✅ Good signal names
signal health_changed(new_value: int, old_value: int)
signal chunk_loaded(coord: Vector2i)
signal path_completed()
signal enemy_died(enemy: Enemy)

# ❌ Avoid
signal on_health_change  # Don't use "on_" prefix
signal doSomething       # Don't use camelCase
```

### Signal Flow
> **"Signal up, call down"**

- Children emit signals to notify parents
- Parents call methods on children to command them

```gdscript
# Parent (GameManager)
func _ready() -> void:
    player.health_changed.connect(_on_player_health_changed)
    enemy_spawner.spawn_enemy(enemy_type)  # Call down

# Child (Player)
func take_damage(amount: int) -> void:
    _health -= amount
    health_changed.emit(_health, _health + amount)  # Signal up
```

### Async Patterns
```gdscript
# ✅ Use await for sequences
func move_along_path(path: Array[Vector2]) -> void:
    for point in path:
        var tween := create_tween()
        tween.tween_property(self, "position", point, 0.3)
        await tween.finished
    path_completed.emit()

# ❌ Avoid complex timer chains
```

### Naming Conventions
| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `PlayerController` |
| Functions | snake_case | `get_chunk_coord()` |
| Variables | snake_case | `loaded_chunks` |
| Constants | SCREAMING_SNAKE | `CHUNK_SIZE` |
| Private | Leading underscore | `_health`, `_update_grid()` |
| Signals | snake_case (past tense) | `health_changed` |
| Enums | PascalCase.SCREAMING | `Direction.NORTH_EAST` |

---

## 9. Common Pitfalls & Solutions

| Problem | Cause | Solution |
|---------|-------|----------|
| Character clips through walls | Sprite center at (0,0) | Set sprite offset so feet are at (0,0) |
| Diagonal movement looks "zigzag" | Wrong A* heuristic | Use `HEURISTIC_OCTILE` |
| Click position is wrong | Using global coords | Convert with `tilemap.local_to_map(tilemap.get_local_mouse_position())` |
| Chunks don't unload | Missing cleanup | Check chunk distance every frame, use `queue_free()` |
| Pathfinding ignores new obstacles | Stale A* grid | Call `set_point_solid()` when chunks load/unload |
| Sprite flickers between directions | No hysteresis | Add ±5° buffer before changing direction |

---

## 10. Performance Targets

| Metric | Target |
|--------|--------|
| Active Chunks | ≤9 (3×3 grid) |
| Entities per Chunk | ≤50 |
| Pathfinding Updates | ≤1 per frame |
| Draw Calls | Monitor with debugger |
| Target FPS | 60 (stable) |
