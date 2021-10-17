extends Brain

var appearing: bool = true
var appear_counter: float = 0

var initial_pos: Vector2
var offset_pos: Vector2 = Vector2.ZERO

func _ready_mixin():
  owner.death_type = AliveObject.DEATH_TYPE.NONE
  owner.z_index = -99
  owner.velocity_enabled = false
  initial_pos = owner.position
  
  # Replacing with mushroom if mario is small and state is provided
  if 'set state' in owner.vars and 'from bonus' in owner.vars and Global.state == 0 and owner.vars['set state'] > 1:
    var mushroom = load('res://Objects/Bonuses/Powerups/Mushroom.tscn').instance()
    mushroom.position = owner.position
    owner.get_parent().add_child(mushroom)
    owner.queue_free()
  
func _ai_process(delta: float) -> void:
  ._ai_process(delta)
  
  if !appearing:
    if !owner.is_on_floor():
      owner.velocity.y += Global.gravity * owner.gravity_scale * Global.get_delta(delta)
    owner.velocity.x = owner.vars['speed'] * owner.dir
    if owner.is_on_wall():
      owner.turn()
  
  if appearing and appear_counter < 32:
    offset_pos -= Vector2(0, owner.vars['grow speed']).rotated(owner.rotation) * Global.get_delta(delta)
    appear_counter += owner.vars['grow speed'] * Global.get_delta(delta)
  elif appear_counter >= 32 and appear_counter < 100:
    offset_pos = Vector2(0, -32).rotated(owner.rotation)
    owner.position = initial_pos + offset_pos
    appearing = false
    appear_counter = 100
    owner.z_index = 1
    owner.velocity_enabled = true
    
  if appearing:
    owner.position = initial_pos + offset_pos
    
  if on_mario_collide('InsideDetector'):
    if 'set state' in owner.vars:
      Global.Mario.appear_counter = 60
      Global.add_score(owner.score)
      owner.get_parent().add_child(ScoreText.new(1000, owner.position))
      if Global.state >= 1:
        Global.state = owner.vars['set state']
      else:
        Global.state = 1
      Global.play_base_sound('MAIN_Powerup')
      owner.queue_free()
    elif 'custom action' in owner.vars:
      var action_class = owner.vars['custom action'].new()
      action_class.do_action(self)
