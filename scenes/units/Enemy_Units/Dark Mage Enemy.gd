extends Battlefield_Unit

# Called when the node enters the scene tree for the first time.
func _ready():
	super._ready()
	$Animation.current_animation = "Idle"
	UnitMovementStats.is_ally = false
	
	# Portrait
	unit_portrait_path = preload("res://assets/units/enemyPortrait/red soldier portrait.png")
	
	# Mug shot
	unit_mugshot = preload("res://assets/units/enemyPortrait/red soldier portrait.png")
	
	# Inventory and Weapons
	UnitInventory.usable_weapons.append(Item.WEAPON_TYPE.DARK)
	UnitInventory.add_item(preload("res://scenes/items/Tomes/Flux.tscn").instantiate())
	
	# Combat sprite
	combat_node = preload("res://scenes/units/Enemy_Units/Dark Mage Enemy Combat.tscn")
