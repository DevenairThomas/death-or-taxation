extends "res://scenes/units/Unit_Scripts/Combat Unit.gd"

signal play_enemy_dodge_anim

func play_miss_sound():
	var random = int(randf_range(1,3))
	BattlefieldInfo.battle_sounds.get_node(str("Attack Miss ", random)).play(0)
	# Play Miss anim
	emit_signal("play_enemy_dodge_anim")

func play_death_sound():
	BattlefieldInfo.battle_sounds.get_node("Death").play(0)

func death_anim_signal():
	emit_signal("death_anim_done")
