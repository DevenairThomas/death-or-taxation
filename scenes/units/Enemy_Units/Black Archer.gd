extends Battlefield_Unit

func _ready():
	# Initial Animation
	$Animation.current_animation = "Idle"
	
	# Unit Portrait
	unit_portrait_path = preload("res://assets/units/enemyPortrait/red soldier portrait.png")
	unit_mugshot = unit_portrait_path
	
	# Unit Mugshot
	unit_mugshot = unit_portrait_path
	
	# Weapons and Inventory
	UnitInventory.usable_weapons.append(Item.WEAPON_TYPE.BOW)
	UnitInventory.add_item(preload("res://scenes/items/Lance/Iron Lance.tscn").instance())
	UnitInventory.add_item(preload("res://scenes/items/Swords/Iron Sword.tscn").instance())
	UnitInventory.add_item(preload("res://scenes/items/Bows/Iron Bow.tscn").instance())
	
	# Set combat node
	combat_node = preload("res://scenes/units/Enemy_Units/Black Archer Combat.tscn")
