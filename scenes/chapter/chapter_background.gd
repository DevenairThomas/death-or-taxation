extends CanvasLayer

func start(chapter_number, chapter_name, _next_chapter_path, _delay):
	# Change Text
	$"Container/Chapter Number".text = str("Chapter ", chapter_number)
	$"Container/Chapter Name".text = chapter_name
	
	# Play Animation
	$Container/Anim.play("Fade ")

	await $Container/Anim.animation_finished
	
	# Play Sound
	#$"Container/Chapter Start".play(0)
	
	# Wait 2 seconds then move on
	await get_tree().create_timer(2.0).timeout
	
	# Remove World Map
	get_node("/root/WorldMapScreen").visible = false

	# Reference build boundary:
	# The battle levels (chapter_2.tscn -> Level*.tscn) instance Tiled ".tmx" maps
	# that Godot 4 cannot import. Per the project decision, the map/battle system is
	# built fresh in Death or Taxation rather than converting the Tiled pipeline, so
	# there is nothing to load here. We deliberately do NOT call load() on that
	# broken scene chain (that is what produced the wall of resource-load errors) —
	# we just show a clean boundary message and stop.
	$"Container/Chapter Name".text = str(chapter_name, "\n\n[ reference build ]\nbattle maps are built fresh in Death or Taxation")

func set_fog_color(color):
	$Container/Fog.modulate = color
