extends Control

# No text background
var no_text_background = preload("res://assets/intro screen/intro background no text.jpg")

enum {INTRO, GAME_SELECT, WAIT}
var current_state = INTRO

var options = ["New Game", "Load Game", "Options Screen"]
var current_option
var current_option_number = 0


# --- TEMPORARY input debug overlay ---
var _dbg: Label
var _dbg_count := 0
var _dbg_last := "-"

func _make_debug():
	var cl := CanvasLayer.new()
	cl.layer = 128
	var lbl := Label.new()
	lbl.add_theme_color_override("font_color", Color(1, 1, 0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = Vector2(3, 3)
	cl.add_child(lbl)
	add_child(cl)
	_dbg = lbl

func _update_debug():
	if _dbg:
		_dbg.text = "state=%d  keys=%d  last=%s" % [current_state, _dbg_count, _dbg_last]

func _ready():
	# Start music
	$"Intro Song".play(0)

	current_state = INTRO

	current_option = options[current_option_number]

	# Anim signal
	$"Anim".connect("animation_finished", Callable(self, "allow_selection"))

	# No 3 houses
	$"Intro Background".texture = no_text_background
	_make_debug()

func _input(event):
	# TEMPORARY: count every key event so we can see if input is reaching the intro
	if event is InputEventKey and event.pressed:
		_dbg_count += 1
		_dbg_last = str(event.keycode)
	match current_state:
		INTRO:
			# Any key
			if event is InputEventKey and event.is_pressed():
				$"Anim".play("Options Fade In")
				current_state = WAIT
		GAME_SELECT:
			# Use the event itself (not Input.is_action_just_pressed) since this is
			# _input(event): the global "just pressed" state is frame-based and can
			# miss/duplicate here, whereas event.is_action_pressed tests this event.
			if event.is_action_pressed("ui_up"):
				current_option_number -= 1
				$"Options/Hand Selector".position.y -= 18
				if current_option_number < 0:
					current_option_number = 0
					current_option = options[current_option_number]
					$"Options/Hand Selector".position.y += 18
				current_option = options[current_option_number]
				$"Options/Hand Selector/Move".play(0)
			if event.is_action_pressed("ui_down"):
				current_option_number += 1
				$"Options/Hand Selector".position.y += 18
				if current_option_number > options.size() - 1:
					current_option_number = options.size() - 1
					current_option = options[current_option_number]
					$"Options/Hand Selector".position.y -= 18
				current_option = options[current_option_number]
				$"Options/Hand Selector/Move".play(0)
			if event.is_action_pressed("ui_accept"):
				$"Options/Hand Selector/Accept".play(0)
				process_selection()
				

func _process(_delta):
	_update_debug()

func allow_selection(_anim_name):
	current_state = GAME_SELECT

func process_selection():
	match current_option:
		"New Game":
			$"Anim".play("music fade out")
			set_process_input(false)
			
			# Reset game over status
			BattlefieldInfo.turn_manager.set_process(true)
			BattlefieldInfo.game_over = false
			
			# Scene change
			WorldMapScreen.current_event = Level1_WM_Event_Part10.new()
			WorldMapScreen.connect_to_scene_changer()
			SceneTransition.change_scene_to_packed(WorldMapScreen, 0.1)
		"Load Game":
			# Stop song and fade to black
			$"Anim".play("music fade out")
			set_process_input(false)
			await $Anim.animation_finished
			$"Intro Song".stop()
			
			# Make screen go dark
			$Anim.play("Fade ")
			await $Anim.animation_finished
			
			# Load the game
			BattlefieldInfo.save_load_system.is_loading_level = true
			BattlefieldInfo.save_load_system.load_game()
