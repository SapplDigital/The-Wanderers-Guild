class_name Villager
extends StaticBody3D
## One NPC (`scenes/npcs/villager.tscn`). Everything that differs per NPC is set here on the
## instance root and pushed to the children in _ready. Why not override the children directly
## from the world scene: those overrides (on a child of an instanced scene) were dropped in the
## exported build (M15), which left every villager mute and in the default colours.

@export var dialogue: DialogueData ## what "Talk" starts
@export var body_material: Material ## empty = the scene's default shawl
@export var show_bucket := true


func _ready() -> void:
	($Dialogue as DialogueTrigger).dialogue = dialogue
	if body_material:
		($Visual/Body as MeshInstance3D).set_surface_override_material(0, body_material)
	($Visual/Bucket as Node3D).visible = show_bucket
