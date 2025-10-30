extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -500.0

var _anim: AnimatedSprite2D
var can_jump: bool = false

func _ready() -> void:
	if has_node("PetAnimatedSprite"):
		_anim = $PetAnimatedSprite
		_anim.play("default")

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump (only during active gameplay)
	if Input.is_action_just_pressed("jump") and is_on_floor() and can_jump:
		velocity.y = JUMP_VELOCITY
		if _anim:
			_anim.play("jump")

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	# Return to default anim when landed
	if is_on_floor() and _anim and _anim.animation != "default" and velocity.y == 0:
		_anim.play("default")

func set_can_jump(allowed: bool) -> void:
	can_jump = allowed
	if not can_jump and _anim and is_on_floor():
		_anim.play("default")
