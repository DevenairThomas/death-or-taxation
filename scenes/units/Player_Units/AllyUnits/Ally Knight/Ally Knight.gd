extends Battlefield_Unit

func _ready():
	# Initial Animation
	$Animation.current_animation = "Idle"
	
	# Set this when the level loads but for now, this is just a test to simply things
	UnitStats.name = "Gilliam"
	
	# Armor
	UnitStats.armor = true
	
	# Unit Portrait
	unit_portrait_path = preload("res://assets/units/knight/gilliam portrait.png")
	
	# Unit Mugshot
	unit_mugshot = preload("res://assets/units/knight/gilliam portrait.png")
	
	# Weapons and Inventory
	UnitInventory.usable_weapons.append(Item.WEAPON_TYPE.LANCE)
	UnitInventory.add_item(preload("res://scenes/items/Lance/Iron Lance.tscn").instantiate())
	
	# Set combat node -> Change when animation exist
	combat_node = preload("res://scenes/units/Player_Units/AllyUnits/Ally Knight/Gilliam Combat.tscn")
	
	# Death sentence
	death_sentence = []
	death_sentence.append("Gilliam:\n\nKnight Commander, please protect her for me...")
