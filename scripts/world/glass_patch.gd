extends Area2D

@export_range(0.25, 5.0, 0.05) var retrigger_delay: float = 1.25
var cooldown_remaining: float = 0.0

func _ready() -> void:
	set_physics_process(false)

func can_crunch() -> bool:
	return cooldown_remaining <= 0.0

func start_cooldown() -> void:
	# This belongs to the patch, so every actor shares the same retrigger delay.
	cooldown_remaining = retrigger_delay
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if cooldown_remaining <= 0.0:
		set_physics_process(false)
