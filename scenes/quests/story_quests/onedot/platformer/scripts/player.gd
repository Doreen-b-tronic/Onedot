@tool
class_name Player
extends CharacterBody2D

# =======================
# Actions helper (inner class)
# =======================
class Actions:
	static func lookup(player_enum: Global.Player, action_name: String) -> String:
		match player_enum:
			Global.Player.ONE:
				return "player1_" + action_name
			Global.Player.TWO:
				return "player2_" + action_name
			_:
				return action_name

# =======================
# Constants
# =======================
const GLIDE_TERMINAL_VELOCITY = 100
const TELEPORT_DISTANCE = 512
const JUMP_VELOCITY_SCALE_WHEN_SMALL = 0.85

# =======================
# Player configuration
# =======================
@export var player: Global.Player = Global.Player.ONE
@export var sprite_frames: SpriteFrames
@export_range(0, 1000, 10, "suffix:px/s") var speed: float = 500.0
@export_range(0, 5000, 1000, "suffix:px/s²") var acceleration: float = 5000.0
@export_range(0, 2000, 10, "suffix:px/s") var jump_velocity: float = 880.0
@export_range(0, 100, 5, "suffix:%") var jump_cut_factor: float = 20
@export_range(0, 0.5, 1/60.0, "suffix:s") var coyote_time: float = 5.0/60.0
@export_range(0, 0.5, 1/60.0, "suffix:s") var jump_buffer: float = 5.0/60.0
@export var double_jump: bool = false

# =======================
# Node references (assign in inspector)
# =======================
@export var _sprite: AnimatedSprite2D
@export var _double_jump_particles: CPUParticles2D
@export var _jump_sfx: AudioStreamPlayer
@export var _glide_sfx: AudioStreamPlayer
@export var _teleport_sfx: AudioStreamPlayer

# =======================
# Internal state
# =======================
var coyote_timer: float = 0
var jump_buffer_timer: float = 0
var double_jump_armed: bool = false
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var original_position: Vector2
var _is_shrunk := false

# =======================
# Ready
# =======================
func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
	else:
		Global.gravity_changed.connect(_on_gravity_changed)
		Global.lives_changed.connect(_on_lives_changed)

	original_position = position

	if _sprite and sprite_frames:
		_sprite.sprite_frames = sprite_frames
		_sprite.speed_scale = speed / 500

# =======================
# Gravity handler
# =======================
func _on_gravity_changed(new_gravity: float) -> void:
	gravity = new_gravity

# =======================
# Jump
# =======================
func _jump() -> void:
	velocity.y = -jump_velocity
	coyote_timer = 0
	jump_buffer_timer = 0

	if double_jump_armed:
		double_jump_armed = false
		if _double_jump_particles:
			_double_jump_particles.emitting = true
	elif double_jump:
		double_jump_armed = true

	if _jump_sfx:
		_jump_sfx.play()

func stomp() -> void:
	double_jump_armed = false
	_jump()

# =======================
# Glide
# =======================
func _glide() -> void:
	if not is_on_floor() and Input.is_action_pressed(Actions.lookup(player, "jump")):
		if velocity.y > GLIDE_TERMINAL_VELOCITY:
			velocity.y = GLIDE_TERMINAL_VELOCITY
		if velocity.y > 0 and _glide_sfx:
			if not _glide_sfx.playing:
				_glide_sfx.play()
	elif _glide_sfx and _glide_sfx.playing:
		_glide_sfx.stop()

# =======================
# Teleport
# =======================
func _teleport(input_direction: float) -> void:
	if Input.is_action_just_pressed(Actions.lookup(player, "teleport")) and not is_zero_approx(input_direction):
		global_position.x += TELEPORT_DISTANCE * input_direction
		if _teleport_sfx:
			_teleport_sfx.play()

# =======================
# Phase
# =======================
func _phase() -> void:
	if Input.is_action_just_pressed(Actions.lookup(player, "phase")):
		set_collision_layer_value(Global.PhysicsLayers.PLAYER, false)
		set_collision_mask_value(Global.PhysicsLayers.PLAYER, false)
		if _sprite:
			_sprite.modulate.a = 0.5
	elif Input.is_action_just_released(Actions.lookup(player, "phase")):
		set_collision_layer_value(Global.PhysicsLayers.PLAYER, true)
		set_collision_mask_value(Global.PhysicsLayers.PLAYER, true)
		if _sprite:
			_sprite.modulate.a = 1

# =======================
# Shrink
# =======================
func _shrink() -> void:
	if Input.is_action_just_pressed(Actions.lookup(player, "shrink")):
		_is_shrunk = not _is_shrunk
		scale = Vector2(0.5, 0.5) if _is_shrunk else Vector2(1, 1)

	if _is_shrunk and velocity.y < -jump_velocity * JUMP_VELOCITY_SCALE_WHEN_SMALL:
		velocity.y = -jump_velocity * JUMP_VELOCITY_SCALE_WHEN_SMALL

# =======================
# Physics
# =======================
func _physics_process(delta: float) -> void:
	if Global.lives <= 0:
		return

	# Jump timers
	if is_on_floor():
		coyote_timer = coyote_time + delta
		double_jump_armed = false

	if Input.is_action_just_pressed(Actions.lookup(player, "jump")):
		jump_buffer_timer = jump_buffer + delta

	if jump_buffer_timer > 0 and (double_jump_armed or coyote_timer > 0):
		_jump()

	if Input.is_action_just_released(Actions.lookup(player, "jump")) and velocity.y < 0:
		velocity.y *= (1 - jump_cut_factor / 100.0)

	if coyote_timer <= 0:
		velocity.y += gravity * delta

	# Horizontal movement
	var direction = Input.get_axis(Actions.lookup(player, "left"), Actions.lookup(player, "right"))
	if direction != 0:
		velocity.x = move_toward(velocity.x, sign(direction) * speed, abs(direction) * acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)

	# Animation
	if _sprite:
		if velocity == Vector2.ZERO:
			_sprite.play("idle")
		else:
			if not is_on_floor():
				_sprite.play("jump_down" if velocity.y > 0 else "jump_up")
			else:
				_sprite.play("walk")
			_sprite.flip_h = velocity.x < 0

	move_and_slide()

	coyote_timer -= delta
	jump_buffer_timer -= delta

# =======================
# Reset
# =======================
func reset() -> void:
	position = original_position
	velocity = Vector2.ZERO
	coyote_timer = 0
	jump_buffer_timer = 0

func _on_lives_changed() -> void:
	if Global.lives > 0:
		reset()
