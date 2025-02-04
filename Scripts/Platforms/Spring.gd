extends KinematicBody2D

var spring_counter: float = 0

export var strength_modifier: float = 1

func _ready() -> void:
  add_collision_exception_with(Global.Mario)
  
func _process(delta: float) -> void:
  $Sprite.playing = $Sprite.frame < 4
  
  if Input.is_action_just_pressed('mario_jump'):
    spring_counter = 7
    
  if spring_counter > 0:
    spring_counter -= 1 * Global.get_delta(delta)
  
  if !Input.is_action_pressed('mario_jump'):
    spring_counter = 0
  
  if is_mario_collide('BottomDetector') and Global.Mario.velocity.y > 50:
    $Sound.play()
    $Sprite.frame = 0
    if spring_counter <= 0:
      Global.Mario.velocity.y = 0
      Global.Mario.velocity += Vector2(0, -550).rotated(rotation)
    else:
      Global.Mario.velocity.y = 0
      Global.Mario.velocity += Vector2(0, -1000 * strength_modifier).rotated(rotation)

func is_mario_collide(_detector_name: String) -> bool:
  var collisions = Global.Mario.get_node(_detector_name).get_overlapping_bodies()
  return collisions && collisions.has(self)
