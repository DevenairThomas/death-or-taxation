extends Battlefield_Unit

func _ready():
	super._ready()
	# Initial Animation
	$Animation.current_animation = "Idle"
	
	# Set this when the level loads but for now, this is just a test to simply things
	UnitStats.name = "Colm"
	
	# Unit Portrait
	unit_portrait_path = preload("res://assets/units/thief/colm portrait.png")
	
	# Unit Mugshot
	unit_mugshot = unit_portrait_path
	
	# Weapons and Inventory
	UnitInventory.usable_weapons.append(Item.WEAPON_TYPE.SWORD)
	UnitInventory.add_item(preload("res://scenes/items/Swords/Iron Sword.tscn").instantiate())
	UnitInventory.add_item(preload("res://scenes/items/Swords/Killing Edge.tscn").instantiate())
	
	# Set combat node
	combat_node = preload("res://scenes/units/Player_Units/AllyUnits/Ally Thief/Colm Combat.tscn")
	
	# Death sentence
	death_sentence = []
	death_sentence.append("Colm:\n\nLooks like my thieving days have come to an end...")
