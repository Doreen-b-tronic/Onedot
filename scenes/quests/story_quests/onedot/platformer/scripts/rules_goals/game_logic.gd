@tool
class_name GameLogic
extends Node

@export_group("Win Condition")
@export var win_by_collecting_coins: bool = false
@export_range(0, 100, 0.9, "or_greater") var coins_to_win: int = 0
@export var win_by_reaching_flag: bool = false
@export var flag_to_win: Flag = null

@export_group("Challenges")
@export_range(0, 60, 0.9, "or_greater", "suffix:s") var time_limit: int = 0
@export_range(1, 9) var lives: int = 3:
	set = _set_lives

@export_group("World Properties")
@export_range(-2000.0, 2000.0, 0.1, "suffix:px/s²") var gravity: float = 980.0

# --- Internal ---
var _coins_collected: int = 0

func _set_lives(new_lives):
	lives = new_lives
	Global.lives = lives

func _get_all_coins(node, accumulator = []):
	if node is Coin:
		accumulator.append(node)
	for child in node.get_children():
		_get_all_coins(child, accumulator)

func _ready():
	if Engine.is_editor_hint():
		return

	await get_parent().ready
	# Set runtime gravity
	PhysicsServer2D.area_set_param(
		get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, gravity
	)
	Global.gravity_changed.emit(gravity)

	if win_by_collecting_coins:
		Global.coin_collected.connect(_on_coin_collected)
		if coins_to_win == 0:
			var coins = []
			_get_all_coins(get_parent(), coins)
			coins_to_win = coins.size()
	if win_by_reaching_flag:
		Global.flag_raised.connect(_on_flag_raised)

	if time_limit > 0:
		Global.setup_timer(time_limit)

	_set_lives(lives)

	# --- Connect signal to handle scene change on win ---
	Global.game_ended.connect(_on_game_ended)


# --- Coin collection ---
func _on_coin_collected():
	_coins_collected += 1
	if _check_win_conditions(flag_to_win):
		Global.game_ended.emit(Global.Endings.WIN)


# --- Flag raised ---
func _on_flag_raised(flag: Flag):
	if _check_win_conditions(flag_to_win if flag_to_win else flag):
		Global.game_ended.emit(Global.Endings.WIN)
	elif flag_to_win == null or flag == flag_to_win:
		flag.flag_position = Flag.FlagPosition.DOWN


# --- Check if win conditions are met ---
func _check_win_conditions(flag: Flag) -> bool:
	if not win_by_collecting_coins and not win_by_reaching_flag:
		return false

	if win_by_collecting_coins and _coins_collected < coins_to_win:
		return false

	if win_by_reaching_flag and (flag == null or flag.flag_position == Flag.FlagPosition.DOWN):
		return false

	return true


# --- Handle game end and switch to outro (Godot 4) ---
func _on_game_ended(ending):
	if ending == Global.Endings.WIN:
		# Optional: play a sound or animation
		# Example: $WinSFX.play()
		# yield(get_tree().create_timer(1.0), "timeout")  # 1 second delay
		get_tree().change_scene_to_file("res://scenes/quests/story_quests/onedot/outro/onedot_outro.tscn")
