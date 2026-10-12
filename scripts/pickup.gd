extends StaticBody3D
## Adada ya da deniz tabanında E ile toplanan nesne.

const Items = preload("res://scripts/items.gd")

var main
var item := "hindistan_cevizi"
var amount := 1


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	set_meta("target", self)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.45
	cs.shape = sh
	cs.position.y = 0.2
	add_child(cs)


func prompt(_player) -> String:
	return "E: Al (%s%s)" % [Items.name_of(item), " x%d" % amount if amount > 1 else ""]


func interact(player) -> void:
	player.give(item, amount)
	queue_free()
