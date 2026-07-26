extends Battlefield_Unit

# Called when the node enters the scene tree for the first time.
func _ready():
	$Animation.current_animation = "Idle"
	UnitMovementStats.is_ally = false
	
	# Portrait
	unit_portrait_path = preload("res://assets/units/enemyPortrait/Main Villain MugShot.png")
	
	# Mug shot
	unit_mugshot = preload("res://assets/units/enemyPortrait/Main Villain MugShot.png")
	
	# Inventory and Weapons
	UnitInventory.usable_weapons.append(Item.WEAPON_TYPE.AXE)
	UnitInventory.usable_weapons.append(Item.WEAPON_TYPE.LANCE)
	UnitInventory.add_item(preload("res://scenes/items/Axes/Gorehowl.tscn").instance())
	
	# Combat sprite
	combat_node = preload("res://scenes/units/Enemy_Units/Enemy General Black Combat.tscn")
