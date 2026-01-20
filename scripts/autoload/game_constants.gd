extends Node
## Global game constants for measurements and tuning

# === DISTANCE & MEASUREMENT ===
const TILE_WIDTH_PIXELS := 128.0
const TILE_HEIGHT_PIXELS := 64.0
const CHUNK_SIZE_TILES := 16
const METERS_PER_TILE := 1.0  # Display ratio: 1 tile = 1 meter

# === MOVEMENT SPEEDS (tiles/second) ===
const PLAYER_WALK_SPEED := 1.5
const PLAYER_RUN_SPEED := 3.0  # For future sprint mechanic

# === RANGES (tiles = meters for display) ===
const MELEE_RANGE := 1.0
const INTERACT_RANGE := 1.5
const BOW_RANGE := 8.0  # Typical ranged attack distance
const AURA_RADIUS := 5.0  # Typical aura effect radius

# === COLLISION RADII ===
const PLAYER_COLLISION_RADIUS := 16.0  # pixels (legacy)
const ENEMY_COLLISION_RADIUS := 14.0   # pixels (legacy)
const PUSH_FORCE := 50.0  # Gentle push between entities

# Tile-based radii for distance framework
const PLAYER_HURTBOX_RADIUS_TILES := 0.125   # 16 pixels
const ENEMY_HURTBOX_RADIUS_TILES := 0.109    # ~14 pixels
const DEFAULT_HURTBOX_RADIUS_TILES := 0.25   # Standard entity radius
