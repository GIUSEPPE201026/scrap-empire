extends Node
## Twenty real minutes per day, no offline advance. Pausing freezes time.
const DAY_SECONDS: float = 1200.0
var _visual_elapsed: float = 0.0

func _ready() -> void:
	add_to_group("yard_clock")

static func duration() -> float:
	return float(GameState.logistics_def.get("day_seconds",DAY_SECONDS))

static func elapsed() -> float:
	return float(GameState.operations.get("world_seconds",0.0))

static func caption() -> String:
	var hour: float = fmod(8.0+elapsed()/duration()*24.0,24.0)
	return Localization.format_text("GIORNO %d · %02d:%02d", [1+int(elapsed()/duration()),int(hour),int(fmod(hour*60,60))])

func _process(delta: float) -> void:
	if GameState.mission_phase != "MISSIONE":
		return
	GameState.operations.world_seconds = elapsed()+delta
	_visual_elapsed+=delta
	if _visual_elapsed<0.25:
		return
	_visual_elapsed=0.0
	refresh_visuals()

func refresh_visuals() -> void:
	var sun = get_parent().get_node_or_null("DirectionalLight3D_Sun")
	var world = get_parent().get_node_or_null("WorldEnvironment")
	if sun == null or world == null:
		return
	var hour: float = fmod(8.0+elapsed()/duration()*24.0,24.0)
	var elevation: float = sin((hour-6.0)/24.0*TAU)
	sun.rotation_degrees.x = -elevation*75
	sun.light_energy = maxf(0,elevation)*0.95
	sun.light_color = Color("#ffbe88").lerp(Color("#fff1df"),clampf(elevation*2,0,1))
	world.environment.ambient_light_energy = lerpf(0.18,0.35,maxf(0,elevation))
	world.environment.background_color = Color("#172938").lerp(Color("#9eb8c4"),maxf(0,elevation))
	preload("res://scripts/gameplay/yard_sky.gd").update(world.environment,sun,elevation,elapsed())
