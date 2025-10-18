# Astronaut with a Pen - Planetary Gravity Platformer

A 2D side-scrolling platformer built in Godot 4.5 featuring dynamic planetary gravity where the player rotates and is pulled toward nearby planets. The camera intelligently follows and rotates to keep gameplay intuitive.

## Features

### Core Mechanics
- **Dynamic Planetary Gravity**: Multiple planets with configurable gravity fields
- **Smooth Player Rotation**: Character aligns with gravity direction
- **Intelligent Camera**: Rotates with gravity to maintain orientation
- **Edge Case Handling**: Robust handling of multiple overlapping gravity sources

### Implemented Systems
1. **Player Controller** (Scripts/player.gd)
   - WASD movement relative to gravity
   - Spacebar to jump perpendicular to surface
   - Smooth rotation matching gravity direction
   - Ground detection using raycasts

2. **Gravity System** (Scripts/planet.gd)
   - Configurable gravity strength and radius
   - Multiple falloff types (Linear, Quadratic, Inverse Square)
   - Overlapping gravity field support
   - Sticky gravity to prevent jittering

3. **Camera Controller** (Scripts/camera_controller.gd)
   - Smooth position following
   - Rotation aligned with gravity
   - Optional dynamic zoom based on velocity

## Controls

- **WASD** or **Arrow Keys**: Move left/right (relative to gravity)
- **Spacebar**: Jump (perpendicular to current surface)

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
@export var move_speed: float = 200.0
@export var jump_force: float = 400.0
@export var default_gravity: float = 980.0
@export var rotation_speed: float = 5.0
@export var gravity_cancel_threshold: float = 50.0
@export var primary_planet_switch_threshold: float = 1.2  # 20% stronger
```

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

The main.tscn scene includes a test level with 4 planets designed to test:

1. **Planet 1** (Center, Large): Primary gravity source
2. **Planet 2** (Left): Transition from main planet
3. **Planet 3** (Right): Transition from main planet
4. **Planet 4** (Top): Testing multiple overlapping fields

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

### Debugging
In debug builds, the player draws:
- **Red line**: Current gravity direction
- **Green/Yellow line**: Ground detection ray (green = grounded)

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

## Future Enhancements

Potential additions:
- [ ] Visual effects for gravity fields
- [ ] Sound effects for movement/jumping/landing
- [ ] Different planet types (ice, lava, bouncy)
- [ ] Collectibles and objectives
- [ ] Level progression system
- [ ] Custom player sprites and animations
- [ ] Particle effects for thrust/movement
- [ ] Background parallax scrolling

## Credits

Built with Godot 4.5 following the design specification for a planetary gravity platformer with robust edge case handling and smooth player experience.

## License

This project is provided as-is for educational and experimental purposes.
