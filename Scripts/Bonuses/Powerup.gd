extends GenericEnemyMovement
class_name Powerup, "res://GFX/Editor/Powerup.png"

enum POWERUP_TYPE {
  MUSHROOM,
  FLOWER,
  BEETROOT,
  LUI,
  POISON
}

export(POWERUP_TYPE) var type: int = POWERUP_TYPE.MUSHROOM

func _ready() -> void:
  z_index = -99

  if Global.state == 0 and appearing:
    speed = 100
    type = POWERUP_TYPE.MUSHROOM
    $Sprite.set_animation('Mushroom')

  if type == POWERUP_TYPE.FLOWER:
    old_speed = 0
    $Sprite.set_animation('Flower')

  if type == POWERUP_TYPE.BEETROOT:
    old_speed = 0
    $Sprite.set_animation('Beetroot')

func _process(delta) -> void:
  if appearing and appear_counter < 32:
    if type != POWERUP_TYPE.MUSHROOM:
      $CollisionCollectable.disabled = true
  else:
    $CollisionCollectable.disabled = true

  if type != POWERUP_TYPE.MUSHROOM:
    $Sprite.flip_h = false

  var mario = get_parent().get_node('Mario')
  var pd_overlaps = mario.get_node('PrimaryDetector').get_overlapping_bodies()

  if pd_overlaps and pd_overlaps.has(self):
    Global.play_base_sound('MAIN_Powerup')
    var score_text = ScoreText.new(1000, position)
    get_parent().add_child(score_text)
    queue_free()
    match type:
      POWERUP_TYPE.MUSHROOM:
        if Global.state == 0:
          Global.state = 1
          mario.appear_counter = 60
      POWERUP_TYPE.FLOWER:
        if Global.state != 2:
          mario.appear_counter = 60
        if Global.state >= 1:
          Global.state = 2
        else:
          Global.state = 1
      POWERUP_TYPE.BEETROOT:
        if Global.state != 2:
          mario.appear_counter = 60
        if Global.state >= 1:
          Global.state = 3
        else:
          Global.state = 1

