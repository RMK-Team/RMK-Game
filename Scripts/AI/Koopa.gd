extends Brain

var shell_counter: float = 0
var score_mp: int

func _ready_mixin():
  owner.death_type = AliveObject.DEATH_TYPE.NONE
  if owner.vars['is shell']:
# warning-ignore:standalone_ternary
    to_stopped_shell() if owner.vars['stopped'] else to_moving_shell()

func _setup(b)-> void:
  ._setup(b)
# warning-ignore:return_value_discarded
  owner.get_node(owner.vars['kill zone']).connect('body_entered',self,"_on_kill_zone_enter")

func _ai_process(delta: float) -> void:
  ._ai_process(delta)
  
  if !owner.is_on_floor():
    owner.velocity.y += Global.gravity * owner.gravity_scale * Global.get_delta(delta)
  
  if !owner.alive:
    owner.get_node(owner.vars['kill zone']).get_child(0).set_deferred("disabled", false)
    return
  
  if !owner.frozen:
    owner.velocity.x = (owner.vars['speed'] if !owner.vars['is shell'] else 0 if owner.vars['stopped'] else owner.vars['shell speed']) * owner.dir
  else:
    owner.velocity.x = 0
    if !owner.vars['is shell']:
      owner.get_node('Collision2').set_deferred("disabled", false)
      owner.get_node('Collision').set_deferred("disabled", true)
      owner.frozen_sprite.animation = 'medium'
      owner.frozen_sprite.position.y = -32
    return
  
  if owner.is_on_wall(): #and ((owner.vars['is shell'] && owner.vars['stopped']) || !owner.vars['is shell']):  ### this check is shit, need to remake it
    owner.turn()

  if shell_counter < 41:
    shell_counter += 1 * Global.get_delta(delta)
    
  if is_mario_collide('BottomDetector') and Global.Mario.velocity.y > 0 && shell_counter >= 11: 
    if !owner.vars['is shell']:
      owner.get_parent().add_child(ScoreText.new(100, owner.position))
      to_stopped_shell()
    
      owner.sound.play()
      if Input.is_action_pressed('mario_jump'):
        Global.Mario.velocity.y = -(owner.vars['bounce'] + 5) * 25
      else:
        Global.Mario.velocity.y = -owner.vars['bounce'] * 25
    elif owner.vars['is shell'] && !owner.vars['stopped']: #Stops the shell
      owner.get_parent().add_child(ScoreText.new(100, owner.position))
      to_stopped_shell()
    
      owner.sound.play()
      if Input.is_action_pressed('mario_jump'):
        Global.Mario.velocity.y = -(owner.vars['bounce'] + 5) * 25
      else:
        Global.Mario.velocity.y = -owner.vars['bounce'] * 25
  elif is_mario_collide('InsideDetector') and !owner.vars['stopped'] and shell_counter >= 31:
    if Global.Mario.shield_counter == 0: print(Global.Mario.position.x - owner.position.x)
    Global._ppd(1, int(clamp(Global.Mario.position.x - owner.position.x, 0, 1)))
    
  if is_mario_collide('InsideDetector'):
    if owner.vars['stopped'] && owner.vars['is shell'] && shell_counter >= 11:
      to_moving_shell()
      owner.dir = -1 if Global.Mario.position.x > owner.position.x else 1
      owner.alt_sound.play()
    
  var g_overlaps = owner.get_node('KillDetector').get_overlapping_bodies()
  for i in range(len(g_overlaps)):
    if 'triggered' in g_overlaps[i] and g_overlaps[i].triggered:
      owner.kill(AliveObject.DEATH_TYPE.FALL, 0)

func to_stopped_shell() -> void:
  owner.get_node(owner.vars['kill zone']).get_child(0).set_deferred("disabled", false)
  shell_counter = 0
  owner.vars['is shell'] = true
  score_mp = 0
  owner.vars['stopped'] = true
  owner.animated_sprite.animation = 'shell stopped'
  owner.animated_sprite.offset.y = -8

func to_moving_shell() -> void:
  owner.vars['is shell'] = true
  owner.vars['stopped'] = false
  owner.animated_sprite.animation = 'shell moving'
  shell_counter = 0
  owner.animated_sprite.offset.y = -8

func _on_kill_zone_enter(b:Node) -> void:
  if owner.vars['is shell'] && !owner.vars['stopped'] && abs(owner.velocity.x) > 0 && b.is_class('KinematicBody2D') && b != owner && b.has_method('kill'):
    b.kill(AliveObject.DEATH_TYPE.FALL, score_mp)
    #AudioServer.get_bus_effect(1,0).pitch_scale = AliveObject.pitch_md[score_mp]
    #print(AudioServer.get_bus_effect(1,0).pitch_scale)
    if score_mp < 6:
      score_mp += 1
    else:
      score_mp = 0
