# Astronaut with a Pen - Planetary Gravity Platformer

A 2D side-scrolling platformer built in Godot 4.5 featuring dynamic planetary gravity where the player rotates and is pulled toward nearby planets. The camera intelligently follows and rotates to keep gameplay intuitive.

## Features

### Core Mechanics
- **Dynamic Planetary Gravity**: Multiple planets with configurable gravity fields that pull the player
- **Smooth Player Rotation**: Character aligns with gravity direction for natural orientation
- **Surface-Locked Movement**: When grounded, movement is constrained to be tangent to the planetary surface (no flying)
- **Intelligent Camera**: Rotates with gravity to maintain orientation
- **Stable Animations**: Walk/jump/idle animations with coyote time to prevent flickering
- **Edge Case Handling**: Robust handling of multiple overlapping gravity sources

### Implemented Systems
1. **Player Controller** (Scripts/player.gd)
   - Screen-relative WASD movement that adapts to camera rotation
   - Movement projected onto surface tangent when grounded (stays glued to planets)
   - Spacebar to jump perpendicular to surface with adaptive force based on gravity strength
   - Ground detection using collision normals from move_and_slide()
   - Ground stick force (5000) keeps player firmly on curved surfaces
   - Jump grace period (0.5s) with reduced gravity for smooth jump arcs
   - Coyote time (210ms) prevents animation flickering during fast movement
   - Proper friction when standing still to prevent pole drift

2. **Gravity System** (Scripts/planet.gd)
   - Configurable gravity strength and radius per planet
   - Multiple falloff types (Linear, Quadratic, Inverse Square)
   - Overlapping gravity field support with weighted averaging
   - Sticky gravity to prevent jittering between equal sources

3. **Camera Controller** (Scripts/camera_controller.gd)
   - Smooth position following
   - Rotation aligned with gravity for intuitive screen-relative controls
   - Optional dynamic zoom based on velocity

## Controls

- **WASD**: Move (screen-relative, automatically projects onto surface when grounded)
- **Spacebar**: Jump (perpendicular to current surface, adaptive to gravity strength)

## Project Structure

```
astronautwithapen/
├── Scenes/
│   ├── main.tscn          # Main test level with 4 planets
│   ├── player.tscn        # Player character prefab
│   └── planet.tscn        # Planet prefab
├── Scripts/
│   ├── player.gd          # Player controller with gravity logic
│   ├── planet.gd          # Planet with gravity field
│   └── camera_controller.gd  # Camera follow and rotation
├── Assets/
│   └── Sprites/           # (Add custom sprites here)
└── project.godot
```

## How It Works

### Gravity Calculation
The player calculates net gravity from all overlapping planet gravity fields:

1. Each planet contributes gravity based on distance
2. Falloff curves determine gravity strength at distance
3. Weighted average prevents jittering between equal sources
4. "Sticky gravity" gives bonus weight to current primary planet

### Edge Cases Handled

**Multiple Equal Planets**
- Weighted average based on distance
- Hysteresis prevents rapid switching
- Sticky gravity favors current grounded planet

**Transitioning Between Planets**
- 20% threshold before switching primary planet
- Smooth rotation transitions via lerp_angle
- Maintains stable orientation during transition

**Gravity Cancellation**
- When opposing forces nearly cancel, maintains last stable orientation
- Prevents disorienting spinning

**No Gravity Sources**
- Defaults to downward (-Y) gravity
- Gradual return to default orientation

## Configuration

### Player Parameters (player.gd)
```gdscript
@export var move_speed: float = 500.0  # Base movement speed
@export var jump_force: float = 7000.0  # Base jump force
@export var jump_gravity_multiplier: float = 4.0  # Jump scales with gravity
@export var jump_grace_period: float = 0.5  # Reduced gravity after jump
@export var jump_grace_gravity_reduction: float = 0.1  # 90% gravity reduction
@export var air_control: float = 0.9  # Movement control while airborne
@export var max_speed: float = 1000.0  # Maximum velocity cap
@export var default_gravity: float = 400.0
@export var rotation_speed: float = 5.0
@export var gravity_cancel_threshold: float = 50.0
@export var primary_planet_switch_threshold: float = 1.2  # 20% stronger
@export var ground_detection_distance: float = 5.0
@export var ground_stick_force: float = 5000.0  # Keeps player on curved surfaces
```

**Important Implementation Details:**
- Movement uses actual collision normals (not gravity direction) to prevent pole drift
- When grounded, velocity is projected to be purely tangent to surface
- Ground stick force is applied then immediately re-projected to prevent tangential drift
- Friction applies strong dampening (0.3) to tangent velocity when standing still
- Coyote time (210ms) maintains ground state briefly after losing contact
- Animation only switches when target differs from current to prevent restarting

### Planet Parameters (planet.gd)
```gdscript
@export var gravity_strength: float = 980.0
@export var gravity_radius: float = 500.0
@export var planet_radius: float = 64.0
@export_enum("Linear", "Quadratic", "Inverse Square") var falloff_type: String
```

### Camera Parameters (camera_controller.gd)
```gdscript
@export var follow_speed: float = 5.0
@export var rotation_speed: float = 3.0
@export var enable_rotation: bool = true
@export var dynamic_zoom: bool = false
```

## Testing Scenarios

The main.tscn scene includes a test level with 8 planets of varying sizes and colors arranged in a constellation. Features:
- Dark space blue background (RGB: 0.05, 0.05, 0.2)
- Planets with different gravity strengths (200-280) and radii (220-280)
- Tests transitions between planets, orbital jumps, and overlapping gravity fields
- Player starts at position (576, 200)

## Development

### Opening the Project
1. Install [Godot 4.5](https://godotengine.org/download)
2. Open Godot and import this project
3. Open `Scenes/main.tscn`
4. Press F5 to run

### Creating New Planets
1. Instance `Scenes/planet.tscn`
2. Adjust exported parameters in Inspector:
   - Gravity Strength (force magnitude)
   - Gravity Radius (influence zone)
   - Planet Radius (visual/collision size)
   - Falloff Type (gravity curve)

### Debugging Tips
Common issues and solutions:
- **Animation flickering**: Adjust `ground_coyote_time` (currently 210ms) in player.gd
- **Pole drift**: Ensure movement uses `ground_normal` (collision normal) not `gravity_direction`
- **Flying off planets**: Check that movement is projected onto surface tangent when grounded
- **Can't jump**: Ensure `jump_grace_timer` disables stick force during jump grace period
- **Sliding on planets**: Increase friction dampening in the no-input else block (currently 0.3)

## Technical Notes

### Performance
- Gravity calculations run every physics frame (60 FPS)
- Optimized for multiple overlapping fields
- Physics raycasts for ground detection

### Physics Layers
- Player: CharacterBody2D
- Planets: StaticBody2D with Area2D gravity fields
- Gravity fields use Area2D body_entered/exited signals

### Smooth Transitions
- `lerp()` for position smoothing
- `lerp_angle()` for rotation (handles angle wrapping)
- Configurable smoothing speeds for tweaking feel

## Known Limitations & Future Enhancements

### Current State
- Player has idle, walk (2 frames), and jump animations
- Movement speed: 500 base, 1000 max cap
- 8 test planets in main scene with circular collision shapes
- CharacterBody2D with safe_margin = 0.08 for reliable collision detection

### Potential Additions
- [ ] Visual effects for gravity fields
- [ ] Sound effects for movement/jumping/landing
- [ ] Different planet types (ice, lava, bouncy)
- [ ] Collectibles and objectives
- [ ] Level progression system
- [ ] More player sprite animations
- [ ] Particle effects for thrust/movement
- [ ] Background parallax scrolling with stars
- [ ] Trail effects when jumping between planets

## Credits

Built with Godot 4.5 following the design specification for a planetary gravity platformer with robust edge case handling and smooth player experience.

## License

This project is provided as-is for educational and experimental purposes.
