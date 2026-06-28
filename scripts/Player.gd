extends CharacterBody2D

## Horizontal movement speed in pixels per second.
@export var speed: float = 300.0
## How quickly the player decelerates when no input is held, in px/s².
@export var deceleration: float = 1200.0
## Upward impulse applied when the player jumps (negative = up in Godot).
@export var jump_velocity: float = -600.0
## Downward acceleration applied each second when airborne.
@export var gravity: float = 980.0

func _physics_process(delta: float) -> void:
	# Apply gravity while the player is not on the floor.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Jump when the action is pressed and the player is grounded.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Read horizontal input and move accordingly; smoothly decelerate when idle.
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

	move_and_slide()
