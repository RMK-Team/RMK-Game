extends KinematicBody2D

var gameover_music: Resource = preload('res://Music/1-music-gameover.ogg')

export var powerup_animations: Dictionary = {}
export var powerup_scripts: Dictionary = {}
export var target_gravity_angle: float = 0
export var sections_scroll: bool = true
export var camera_addon: Script
export var die_music: Resource = preload('res://Music/1-music-die.ogg')
export var custom_die_stream: Resource

var inited_camera_addon

var ready_powerup_scripts: Dictionary = {}

var velocity: Vector2
var jump_counter: int = 0
var jump_internal_counter: float = 100
var can_jump: bool = false
var crouch: bool = false
var prelanding: bool = false

enum Movement {
  DEFAULT,
  SWIMMING,
  CLIMBING
 }

var top_collider_counter: float = 0

var position_altered: bool = false
var selected_state: int = -1

onready var movement_type: int = Movement.DEFAULT
onready var dead: bool = false
onready var dead_hasJumped: bool = false
onready var dead_gameover: bool = false
onready var dead_counter: float = 0

onready var appear_counter: float = 0
onready var hurt_counter: float = 0
onready var shield_star: bool = false
onready var shield_counter: float = 0
onready var star_kill_count: int = 0
onready var launch_counter: float = 0

onready var controls_enabled: bool = true
onready var animation_enabled: bool = true
onready var allow_custom_animation: bool = false

var skid: bool = 0
# For star music
var faded: bool = false

const pause_menu = preload('res://Objects/Tools/PopupMenu.tscn')
var popup: CanvasLayer = null

func _ready() -> void:
  gameover_music.loop = false
  die_music.loop = false
  Global.Mario = self
# warning-ignore:return_value_discarded
  Global.connect('OnPlayerLoseLife', self, 'kill')
  $DebugText.visible = false
  $Sprite.material.set_shader_param('mixing', false)
  
  if camera_addon:
    inited_camera_addon = camera_addon.new()
    if inited_camera_addon.has_method('_ready_camera'):
      inited_camera_addon._ready_camera(self)
  
  # Creating working instances of provided scripts
  var p_keys = powerup_scripts.keys()
  for i in range(len(p_keys)):
    ready_powerup_scripts[p_keys[i]] = powerup_scripts[p_keys[i]].new()

func is_over_backdrop(obj, ignore_hidden) -> bool:
  var overlaps = obj.get_overlapping_bodies()

  if overlaps.size() > 0 && (overlaps[0] is TileMap or overlaps[0].is_in_group('Solid')) and (overlaps[0].visible or ignore_hidden):
    return true

  return false

func is_over_platform() -> bool:
  if get_slide_count() > 0:
    var collider = get_slide_collision(0).collider
    return collider.is_in_group('Platform')
  else:
    return false

func _process(delta) -> void:
  if get_node_or_null('Camera'):
    _process_camera(delta)
  
  var target_gravity_enabled: bool = true
  var overlaps = $InsideDetector.get_overlapping_areas()
  for i in overlaps:
    if 'gravity_point' in i and i.gravity_point:
      target_gravity_enabled = false
      
  if target_gravity_enabled:
    rotation = lerp_angle(rotation, deg2rad(target_gravity_angle), 0.15)
  else:
    target_gravity_angle = rotation_degrees
    
  #$Sprite.modulate.a = 0.5 if Global.debug_fly else 1
  
  $BottomDetector/CollisionBottom.position.y = 5 + velocity.y / 100 * Global.get_delta(delta)
  
  appear_logic(delta)

  if not dead:
    if not Global.debug_fly:
      if not get_tree().paused:
        _process_alive(delta)
    else:
      _process_debug_fly(delta)
  else:
    _process_dead(delta)

  if velocity.y > 250:
    velocity.y = 250

  if jump_internal_counter < 100:
    jump_internal_counter += 1 * Global.get_delta(delta)

func _process_alive(delta) -> void:
  var danimate: bool = false
  if movement_type == Movement.SWIMMING:  # Faster than match
    movement_swimming(delta)
  elif movement_type == Movement.CLIMBING:
    movement_climbing(delta)
  else:
    danimate = true
    movement_default(delta)
  
  if Global.state in ready_powerup_scripts and ready_powerup_scripts[Global.state].has_method('_process_mixin'):
    ready_powerup_scripts[Global.state]._process_mixin(self, delta)
    
  if not Global.state == 6: # Fix for propeller powerup animation
    allow_custom_animation = false
    $BottomDetector/CollisionBottom.scale.y = 0.5
  
  
  if shield_star:
    star_logic()
    $BottomDetector/CollisionBottom.disabled = true
    $BottomDetector/CollisionBottom2.disabled = true
    $Sprite.material.set_shader_param('mixing', true)
    # Starman music Fade out
    
    if shield_counter <= 125 and Global.musicBar > -100 and !faded:
      MusicPlayer.fade_out(MusicPlayer.get_node('Star'), 3.0)
      faded = true
    if shield_counter <= 0:
      MusicPlayer.get_node('Star').stop()
      MusicPlayer.get_node('Main').play()
      $BottomDetector/CollisionBottom.disabled = false
      $BottomDetector/CollisionBottom2.disabled = false
      $Sprite.material.set_shader_param('mixing', false)
      if Global.musicBar > -100:
        AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'), round(Global.musicBar / 5))
      if Global.musicBar == -100:
        AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'), -1000)
      shield_star = false
      star_kill_count = 0
  
  if controls_enabled:
    controls(delta)
  
  if position.y > $Camera.limit_bottom + 32 and controls_enabled:
    if get_parent().no_cliff:
      position.y -= 260
    else:
      if !get_parent().sgr_scroll:
        Global._pll()
      else:
        get_parent().get_node('StartWarp').active = true
        get_parent().get_node('StartWarp').counter = 61
      
  if position.y < $Camera.limit_top - 64 and controls_enabled and get_parent().no_cliff:
    position.y += 270

#  if is_on_floor() and velocity.y > -14 or is_on_ceiling():
#    velocity.y = 1
#    prelanding = true
#    if is_on_floor():
#      standing = true
  if top_collider_counter > 0:
    top_collider_counter -= 1 * Global.get_delta(delta)

  if is_on_ceiling():
    top_collider_counter = 3

  if top_collider_counter > 0:
    var collisions = $TopDetector.get_overlapping_bodies()
    for i in range(len(collisions)):
      var collider = collisions[i]
      if collider.has_method('hit'):
        collider.hit(delta)
        
  var bottom_collisions = $BottomDetector.get_overlapping_bodies()
  if is_on_floor():
    for i in range(len(bottom_collisions)):
      var collider = bottom_collisions[i]
      if collider.has_method('_standing_on'):
        collider._standing_on()

  velocity = move_and_slide_with_snap(velocity.rotated(rotation), Vector2(0, 1).rotated(rotation), Vector2(0, -1).rotated(rotation), true, 4, 0.785398, false).rotated(-rotation)

  if animation_enabled and danimate: animate_default(delta)
  update_collisions()
  debug()
  
  $Sprite.offset.y = 0 - $Sprite.frames.get_frame($Sprite.animation, $Sprite.frame).get_size().y
  $Sprite.offset.x = 0 - $Sprite.frames.get_frame($Sprite.animation, $Sprite.frame).get_size().x / 2

func _process_dead(delta) -> void:
  if dead_counter == 0:
    animate_default(delta)
  
  var colDisabled
  if not colDisabled:
    $TopDetector/CollisionTop.disabled = true
    $Collision.disabled = true
    $CollisionBig.disabled = true
    $BottomDetector/CollisionBottom.disabled = true
    $BottomDetector/CollisionBottom2.disabled = true
    $InsideDetector.collision_layer = 0
    $InsideDetector.collision_mask = 0
    $Sprite.material.set_shader_param('mixing', false)
    colDisabled = true

  dead_counter += 1 * Global.get_delta(delta)
  velocity.x = 0
  
  velocity.y += 12.5 * Global.get_delta(delta)

  if dead_counter < 24:
    velocity.y = 0
    $Sprite.set_animation('Death')
    $Sprite.speed_scale = 1
  elif not dead_hasJumped:
    dead_hasJumped = true
    velocity.y = -275
  else:
    $Sprite.set_animation('DeathLoop')
    
  $Sprite.position += Vector2(0, velocity.y * delta)

  #$BottomDetector/CollisionBottom.shape = null
  #$TopDetector/CollisionTop.shape = null

  if dead_counter > 180:
    if Global.lives > 0:
      get_tree().paused = false
      Global._reset()
    elif not dead_gameover:
      MusicPlayer.get_node('Main').stream = gameover_music
      MusicPlayer.get_node('Main').play()
      get_parent().get_node('HUD').get_node('GameoverSprite').visible = true
      dead_gameover = true
      yield(get_tree().create_timer( 5.0 ), 'timeout')
      if popup == null:
        popup = pause_menu.instance()
        for node in popup.get_children():
          if node.get_class() == 'Node' and not node.get_name() == 'GameOver':
            node.queue_free()
        get_parent().add_child(popup)

        get_parent().get_node('WorldEnvironment').environment.dof_blur_near_quality = 2
        get_parent().get_node('WorldEnvironment').environment.dof_blur_near_enabled = true
        get_parent().get_tree().paused = true
      
func movement_default(delta) -> void:
  #if animation_enabled: animate_default(delta)
  
  if velocity.y < 275 and not is_on_floor():
    if Input.is_action_pressed('mario_jump') and velocity.y < 0:
      if abs(velocity.x) < 1:
        velocity.y -= 9.75 * Global.get_delta(delta)
      elif abs(velocity.x) >= 135 and not crouch:
        velocity.y -= 12.5 * Global.get_delta(delta)
      else:
        velocity.y -= 11 * Global.get_delta(delta)
    velocity.y += 25 * Global.get_delta(delta)
  
  if velocity.x > 0:
    velocity.x -= 2.5 * Global.get_delta(delta)
  if velocity.x < 0:
    velocity.x += 2.5 * Global.get_delta(delta)

  if velocity.x > -5 * Global.get_delta(delta) and velocity.x < 5 * Global.get_delta(delta):
    velocity.x = 0

  if velocity.y > 0:
    jump_counter = 1

  if is_on_floor() and jump_internal_counter > 3:
    jump_counter = 0
  
  # Start climbing
  if Input.is_action_pressed('mario_up') || (Input.is_action_pressed('mario_crouch') && !is_on_floor()):
    if crouch || !is_over_vine(): return
    if movement_type == Movement.CLIMBING: return
    controls_enabled = false
    movement_type = Movement.CLIMBING

func movement_swimming(delta) -> void:
  if animation_enabled: animate_swimming(delta)
  pass # TODO

func movement_climbing(delta) -> void:
  if animation_enabled: animate_climbing(delta)
  
  if !is_over_vine():
    movement_type = Movement.DEFAULT
    controls_enabled = true
  
  if Input.is_action_pressed('mario_crouch'):
    if is_on_floor():
      movement_type = Movement.DEFAULT
      controls_enabled = true
    else:
      velocity.y = 90
  if Input.is_action_pressed('mario_up'):
    velocity.y = -90
  if Input.is_action_pressed('mario_left'):
    velocity.x = -75
  if Input.is_action_pressed('mario_right'):
    velocity.x = 75
  
  if !Input.is_action_pressed('mario_crouch') and !Input.is_action_pressed('mario_up'):
    velocity.y = 0
  if !Input.is_action_pressed('mario_left') and !Input.is_action_pressed('mario_right'):
    velocity.x = 0
    
func is_over_vine() -> bool:
  var overlaps = get_node('InsideDetector').get_overlapping_areas()
  for c in overlaps:
    if c.is_in_group('Climbable'):
      return true
  return false

func controls(delta) -> void:
  if Input.is_action_just_pressed('mario_jump'):
    can_jump = true
  if not Input.is_action_pressed('mario_jump'):
    can_jump = false

  if jump_counter == 0 and can_jump:
    prelanding = false
    velocity.y = -350
    jump_counter = 1
    can_jump = false
    $BaseSounds/MAIN_Jump.play()
    jump_internal_counter = 0

  if velocity.y > 0.5 and not is_over_backdrop($BottomDetector, false):
    prelanding = false

  if Input.is_action_pressed('mario_crouch') and is_on_floor() and Global.state > 0:
    crouch = true
    #velocity.y = 1
    if velocity.x > 0:
      velocity.x -= 2.5 * Global.get_delta(delta)
    if velocity.x < 0:
      velocity.x += 2.5 * Global.get_delta(delta)
  if not Input.is_action_pressed('mario_crouch') and is_on_floor() and not is_over_backdrop($TopDetector, false):
    crouch = false

  if Input.is_action_pressed('mario_right') and not Input.is_action_pressed('mario_left') and ((crouch && !is_on_floor()) || !crouch):
    $Sprite.flip_h = false
    if velocity.x > -10 and velocity.x < 10:
      velocity.x += 20
      if skid:
        skid = false
    elif velocity.x <= -10:
      velocity.x += 10 * Global.get_delta(delta)
    elif velocity.x < 87.5 and (not Input.is_action_pressed('mario_fire') or crouch):
      velocity.x += 6.25 * Global.get_delta(delta)
    elif velocity.x < 175 and Input.is_action_pressed('mario_fire') and not crouch:
      velocity.x += 6.25 * Global.get_delta(delta)
    
    if velocity.x > 10:
      skid = false

  if Input.is_action_pressed('mario_left') and not Input.is_action_pressed('mario_right') and ((crouch && !is_on_floor()) || !crouch):
    $Sprite.flip_h = true
    if velocity.x > -10 and velocity.x < 10:
      velocity.x = -20
      if skid:
        skid = false
    elif velocity.x >= 10:
      velocity.x -= 10 * Global.get_delta(delta)
    elif velocity.x > -87.5 and (not Input.is_action_pressed('mario_fire') or crouch):
      velocity.x -= 6.25 * Global.get_delta(delta)
    elif velocity.x > -175 and Input.is_action_pressed('mario_fire') and not crouch:
      velocity.x -= 6.25 * Global.get_delta(delta)

    if velocity.x < -10:
      skid = false

  if Input.is_action_just_pressed('mario_fire') and not crouch and Global.state > 1:
    if Global.state in ready_powerup_scripts and ready_powerup_scripts[Global.state].has_method('do_action'):
      ready_powerup_scripts[Global.state].do_action(self)

func appear_logic(delta) -> void:
  if appear_counter > 0:
    get_tree().paused = true
    if not allow_custom_animation:
      if not $Sprite.animation == 'Appearing':
        animate_sprite('Appearing')
      $Sprite.speed_scale = 1
      
    appear_counter -= 1.5001 * Global.get_delta(delta)
    if not shield_star: return
  if appear_counter < 0:
    get_tree().paused = false
    appear_counter = 0

func animate_default(delta) -> void:
  if selected_state != Global.state:
    selected_state = Global.state
    if not Global.state in powerup_animations:
      printerr('[CE ERROR] Mario: Animations for state ' + str(Global.state) + ' don\'t exist!')
      return
    if Global.state in ready_powerup_scripts and ready_powerup_scripts[Global.state].has_method('_ready_mixin'):
      ready_powerup_scripts[Global.state]._ready_mixin(self)
    $Sprite.frames = powerup_animations[Global.state]
    
  if shield_counter > 0 and hurt_counter == 0:
    shield_counter -= 1.5 * Global.get_delta(delta)
    if appear_counter == 0 and not shield_star:
      $Sprite.visible = int(shield_counter / 2) % 2 == 0
    if appear_counter > 0: return
  if shield_counter < 0:
    shield_counter = 0
    $Sprite.visible = true

  if hurt_counter > 0:
    if velocity.x < 0.08:
      skid = false
      $Sprite.speed_scale = 1
      
    hurt_counter -= 1.5001 * Global.get_delta(delta)
    return
  if hurt_counter < 0:
    controls_enabled = true
    $BottomDetector/CollisionBottom.disabled = false
    $BottomDetector/CollisionBottom2.disabled = false
    allow_custom_animation = false
    hurt_counter = 0
    
  if allow_custom_animation: return

  if launch_counter > 0:
    animate_sprite('Launching')
    launch_counter -= 1.01 * Global.get_delta(delta)
    $Sprite.speed_scale = 1
    return

  if crouch:
    if Global.state > 0:
      animate_sprite('Crouching')
    else:
      animate_sprite('Stopped')
      crouch = false
    return

  if not is_on_floor() and not is_over_platform():
    if velocity.y < 0.08:
      animate_sprite('Jumping')
    else:
      animate_sprite('Falling')
  elif abs(velocity.x) < 0.08 and is_on_floor():
    if Input.is_action_pressed('mario_up'):
      animate_sprite('LookUp')
    else:
      animate_sprite('Stopped')

  if $Sprite.animation == 'Walking' or $Sprite.animation == 'Running':
    $Sprite.speed_scale = abs(velocity.x / 25) * 2.5 + 4
  else:
    $Sprite.speed_scale = 1

  if !is_on_floor(): 
    skid = false
    return
  
  if velocity.x <= -100 and not $Sprite.flip_h:
    $Sprite.speed_scale = 1
    skid = true
  elif velocity.x >= 100 and $Sprite.flip_h:
    $Sprite.speed_scale = 1
    skid = true
  
  if abs(velocity.x) > 130:
    animate_sprite('Skid' if skid else 'Running')
    return
  
  if velocity.x <= -0.16 * Global.get_delta(delta):
    animate_sprite('Skid' if skid else 'Walking')
  if velocity.x >= 0.16 * Global.get_delta(delta):
    animate_sprite('Skid' if skid else 'Walking')

func animate_swimming(delta) -> void:
  pass # TODO

func animate_climbing(delta) -> void:
  if selected_state != Global.state:
    selected_state = Global.state
    if not Global.state in powerup_animations:
      printerr('[CE ERROR] Mario: Animations for state ' + str(Global.state) + ' don\'t exist!')
      return
    if Global.state in ready_powerup_scripts and ready_powerup_scripts[Global.state].has_method('_ready_mixin'):
      ready_powerup_scripts[Global.state]._ready_mixin(self)
    $Sprite.frames = powerup_animations[Global.state]

  if velocity.x <= -8 * Global.get_delta(delta):
    $Sprite.flip_h = true
  if velocity.x >= 8 * Global.get_delta(delta):
    $Sprite.flip_h = false

  if appear_counter > 0:
    get_tree().paused = true
    if not allow_custom_animation:
      if not $Sprite.animation == 'Appearing':
        animate_sprite('Appearing')
      $Sprite.speed_scale = 1
      
    appear_counter -= 1.5001 * Global.get_delta(delta)
    return
  if appear_counter < 0:
#    if position_altered:
#      $Sprite.position.y += 14
#      position_altered = false
    appear_counter = 0
    get_tree().paused = false

  if shield_counter > 0:
    shield_counter -= 1.5 * Global.get_delta(delta)
    if appear_counter == 0:
      $Sprite.visible = int(shield_counter / 2) % 2 == 0
  if shield_counter < 0:
    shield_counter = 0
    $Sprite.visible = true
#  $Sprite.offset.y = $Sprite.texture.get_size()

  if allow_custom_animation: return

  if launch_counter > 0:
    launch_counter -= 1.01 * Global.get_delta(delta)
  
  if $Sprite.animation == 'Climbing':
    $Sprite.speed_scale = 2 if abs(velocity.y + velocity.x) > 5 else 0
  else:
    animate_sprite('Climbing')

func animate_sprite(anim_name) -> void:
  $Sprite.set_animation(anim_name)

func update_collisions() -> void:
  $Collision.disabled = not (Global.state == 0 or crouch)
  $TopDetector/CollisionTop.disabled = not (Global.state == 0 or crouch)
  $InsideDetector/CollisionSmall.disabled = not (Global.state == 0 or crouch)
  
  $CollisionBig.disabled = not (Global.state > 0 and not crouch)
  $TopDetector/CollisionTopBig.disabled = not (Global.state > 0 and not crouch)
  $InsideDetector/CollisionBig.disabled = not (Global.state > 0 and not crouch)

func kill() -> void:
  dead = true
  $Sprite.visible = true

func unkill() -> void:
  dead = false
  $Collision.disabled = false
  $CollisionBig.disabled = false
  $BottomDetector/CollisionBottom.disabled = false
  $BottomDetector/CollisionBottom2.disabled = false
  $InsideDetector.collision_layer = 3
  $InsideDetector.collision_mask = 3
  dead_counter = 0
  dead_hasJumped = false
  appear_counter = 0
  shield_counter = 0
  $TopDetector/CollisionTop.disabled = false
  $Sprite.position = Vector2.ZERO
  animate_sprite('Stopped')

func star_logic() -> void:
  var overlaps = $InsideDetector.get_overlapping_bodies()

  if overlaps.size() > 0:
    for i in range(overlaps.size()):
      if overlaps[i].is_in_group('Enemy') and overlaps[i].has_method('kill'):
        if overlaps[i].force_death_type == false:
          overlaps[i].kill(AliveObject.DEATH_TYPE.FALL, star_kill_count)
        else:
          overlaps[i].kill(overlaps[i].death_type, star_kill_count)
        if star_kill_count < 6:
          star_kill_count += 1
        else:
          star_kill_count = 0

func debug() -> void:
  if Input.is_action_just_pressed('mouse_middle'):
    $DebugText.visible = !$DebugText.visible

  $DebugText.text = 'x speed = ' + str(velocity.x) + '\ny speed = ' + str(velocity.y) + '\nanimation: ' + str($Sprite.animation).to_lower() + '\nmovement: ' + str(Movement.keys()[movement_type].to_lower()) + '\nfps: ' + str(Engine.get_frames_per_second())

func _process_debug_fly(delta: float) -> void:
  var debugspeed: int = 10 + (int(Input.is_action_pressed('mario_fire')) * 10)
  if Input.is_action_pressed('mario_right'):
    position.x += debugspeed * Global.get_delta(delta)
  if Input.is_action_pressed('mario_left'):
    position.x -= debugspeed * Global.get_delta(delta)
  
  if Input.is_action_pressed('mario_up'):
    position.y -= debugspeed * Global.get_delta(delta)
  if Input.is_action_pressed('mario_crouch'):
    position.y += debugspeed * Global.get_delta(delta)
    
  if Input.is_action_just_pressed('debug_rotate_right'):
    target_gravity_angle += 45
    
  if Input.is_action_just_pressed('debug_rotate_left'):
    target_gravity_angle -= 45

func _process_camera(delta: float) -> void:
  if dead: return
  
  if sections_scroll:
    var base_y = floor((position.y + 112) / 448) * 448
    $Camera.limit_top = base_y
    $Camera.limit_bottom = base_y + 224
  
  if inited_camera_addon and inited_camera_addon.has_method('_process_camera'):
    inited_camera_addon._process_camera(self, delta)
  
  if get_parent().sgr_scroll:
    var base_x = floor(position.x / 384) * 384
    $Camera.limit_left = base_x
    $Camera.limit_right = base_x + 384
    
func _physics_process(_delta: float) -> void:
  if inited_camera_addon and inited_camera_addon.has_method('_process_physics_camera'):
    inited_camera_addon._process_physics_camera(self, _delta)
  if Global.state in ready_powerup_scripts and ready_powerup_scripts[Global.state].has_method('_process_mixin_physics') and not dead:
    ready_powerup_scripts[Global.state]._process_mixin_physics(self, _delta)
