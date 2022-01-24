extends Sprite
class_name ScoreText

var counter = 0
var move_to_y

func _init(score: int, pos: Vector2 = Vector2.ZERO):
  texture = preload('res://GFX/Texts/Score.png')
  position = pos
  position.y -= 16
  move_to_y = pos.y - 48
  vframes = 10
  z_index = 50
  match score:
    1:
      frame = 9
    100:
      frame = 0
    200:
      frame = 1
    300:
      frame = 2
    400:
      frame = 3
    500:
      frame = 4
    600:
      frame = 5
    700:
      frame = 6
    800:
      frame = 7
    900:
      frame = 8
  
  if score >= 100:
    Global.add_score(score)

func _process(delta) -> void:
  counter += 1 * Global.get_delta(delta)
  position.y += (move_to_y - position.y) * 0.075 * Global.get_delta(delta)
  #if counter < 36:
  #  position.y -= 1 * Global.get_delta(delta)
  if counter > 100:
    queue_free()
