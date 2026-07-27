extends CanvasLayer

signal scene_changed

@onready var black_transition = $"Scene Changer/Black"
@onready var animation_player = $"Scene Changer/Animation"

var current_scene

# Call when you want to change the level
# Path = file location for the next scene
# Delay = time between each scene
func change_scene_to_file(path, delay = 0.1):
	# Create the delay for timeout
	await get_tree().create_timer(delay).timeout
	
	# Play fade animation
	animation_player.play("fade")
	
	# Load the animation and level when done
	await animation_player.animation_finished
	
	# Change scene
	get_tree().change_scene_to_file(path)
	
	# Change to new level
	animation_player.play_backwards("fade")
	
	# Scene change is done
	await animation_player.animation_finished
	
	emit_signal("scene_changed")

# `scene_node` is the persistent WorldMapScreen autoload (already in the tree),
# not a PackedScene: free the outgoing scene and let scene_changed drive
# WorldMapScreen.start(), which makes it visible and runs the queued event.
func change_scene_to_packed(scene_node, delay = 0.1):
	# Create the delay for timeout
	await get_tree().create_timer(delay).timeout

	# Play fade animation
	animation_player.play("fade")

	# Load the animation and level when done
	await animation_player.animation_finished

	# Retire the outgoing scene (e.g. the title screen or a finished battle)
	var outgoing = get_tree().current_scene
	if is_instance_valid(outgoing) and outgoing != scene_node:
		outgoing.queue_free()
	get_tree().current_scene = null

	# Reveal the world map (start() sets it visible and plays its own fade-in)
	emit_signal("scene_changed")

	# Fade the transition overlay back out
	animation_player.play_backwards("fade")

	# Scene change is done
	await animation_player.animation_finished

func manual_swap(path):
	call_deferred("deferred_next_level", path)

func deferred_next_level(path):
	# Anim
	animation_player.play("fade")
	
	# Yield for anim
	await animation_player.animation_finished
	
	# Load new scene
	var new_level = ResourceLoader.load(path)
	
	# Instance new scene
	current_scene = new_level.instantiate()
	
	# Set to active scene
	get_tree().get_root().add_child(current_scene)
	
	# Fade backwards
	animation_player.play_backwards("fade")
	
	# Wait until done
	await animation_player.animation_finished
	
	# Signal
	emit_signal("scene_changed")
	
	# Set current scene
	get_tree().set_current_scene(current_scene)
