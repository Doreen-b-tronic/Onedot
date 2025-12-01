# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name Cinematic
extends Node2D

signal cinematic_finished

## Dialogue for cinematic scene.
@export var dialogue: DialogueResource = preload("uid://b7ad8nar1hmfs")

## Optional animation player.
@export var animation_player: AnimationPlayer

## Optional scene to switch to afterwards.
@export_file("*.tscn") var next_scene: String

## Optional player spawn point.
@export var spawn_point_path: String

## 🔥 NEW: Drag your GameLogic node here in the editor.
@export var game_logic_path: NodePath


func _ready() -> void:
	if not GameState.intro_dialogue_shown:
		DialogueManager.show_dialogue_balloon(dialogue, "", [self])
		await DialogueManager.dialogue_ended

		# 🔥 Start the minigame (if assigned)
		if game_logic_path != NodePath():
			var game_logic = get_node(game_logic_path)
			if game_logic:
				game_logic.game_can_start.emit()

		cinematic_finished.emit()
		GameState.intro_dialogue_shown = true

	if next_scene:
		SceneSwitcher.change_to_file_with_transition(
			next_scene,
			spawn_point_path,
			Transition.Effect.FADE,
			Transition.Effect.FADE,
		)
