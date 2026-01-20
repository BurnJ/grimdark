**Role:** Tools Programmer / Gameplay Engineer **Context:** We are developing an Isometric ARPG in Godot 4.5.1. The game relies heavily on precise "Distance/Reach" stats (1 Tile \= 1 Meter), invisible physics shapes (Arc vs. Line), and Chunk-based spawning. Currently, it is difficult to verify if a weapon has a "1.2m range" or if an enemy is in "Chase State" just by looking at the screen. We need visual debugging tools to "see" the math.

**Objective:** Create a global **Debug Overlay System**. This should be an Autoload (Singleton) named `DebugOverlay.gd` that sits on a `CanvasLayer` (z-index max) to draw debug shapes and text over the game world. It should toggle on/off with a hotkey (e.g., F3).

**Why:**

1. **Verify Physics:** We need to see if `Attack Range` matches the visual sprite reach.  
2. **Debug AI:** We need to see what the Enemy AI is "thinking" (State Machine) without spamming the Output console.  
3. **Validate Chunks:** We need to see chunk borders to ensure spawning/despawning logic is triggering correctly.  
4. For any future reason added

**Implementation Requirements (The Feature List):**

Please implement the following visualization modules inside `_draw()`:

1. **Spatial Tools (Navigation & Map):**  
   * **Mouse Ruler:** Draw a dotted line from the Player to the Mouse Cursor. Display the distance in **Meters** (e.g., "3.5m") at the midpoint. Use `GameConstants.METERS_PER_TILE` for conversion.  
   * **Chunk Borders:** Draw thick rectangular outlines around the active 16x16 Chunks so we can visualize the "World Manager" loading logic.  
   * **Player Coordinate Label:** Display the player's Global Position (Pixels) and Map Position (Grid Coordinates) in the corner, include current player movement speed. Lastly, track “active” chunks so I can confirm new chunks are being generated but also deleted.  
2. **Combat Visualization (Hitboxes):**  
   * **Weapon Shapes:** When `BasicStrike` fires, draw the actual collision shape (Line or Arc) in **Red** for 0.1s so we can see the hit area.  
   * **Entity Radii:** Draw a **Green Circle** around the Player and **Red Circles** around Enemies representing their `HurtboxComponent` radius (Collision Size).  
3. **AI & Logic Debug:**  
   * **State Tags:** Draw text above every Enemy's head showing their current State (e.g., `[IDLE]`, `[CHASE]`, `[ATTACK]`).  
   * **Targeting Lasers:** Draw a thin line from an Enemy to their current target (if they have one).  
   * **Aggro Ranges:** Draw a thin **Yellow Circle** around enemies representing their `aggro_range` to verify detection logic.

**Technical Constraints:**

* Use `_draw()` in the `_process()` loop (or `queue_redraw()`) to keep lines attached to moving targets.  
* Ensure text scales correctly with the camera zoom (or use `Control` nodes for labels).  
* Must check `if not is_visible(): return` for performance when toggled off.

4\. If you have any questions, concerns, OR additional feature requests for this dev tool, use the plan mode’s follow up questions.

