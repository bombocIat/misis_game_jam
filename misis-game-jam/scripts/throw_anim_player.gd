class_name ThrowAnimPlayer
extends AnimatedSprite2D
## Plays item throw spritesheets (currently paper).


const PAPER_SHEET: Texture2D = preload("res://assets/textures/paper_spritesheet.png")
const PAPER_FRAMES := 5
const PAPER_FPS := 12.0
const ANIM_PAPER := &"paper"


func _ready() -> void:
	visible = false
	z_index = 40
	centered = true
	_build_paper_frames()


func _build_paper_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(ANIM_PAPER)
	frames.set_animation_loop(ANIM_PAPER, false)
	frames.set_animation_speed(ANIM_PAPER, PAPER_FPS)
	var fw: int = int(PAPER_SHEET.get_width() / PAPER_FRAMES)
	var fh: int = PAPER_SHEET.get_height()
	for i: int in range(PAPER_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = PAPER_SHEET
		atlas.region = Rect2(i * fw, 0, fw, fh)
		frames.add_frame(ANIM_PAPER, atlas)
	sprite_frames = frames


## Play throw anim for item if a sheet exists. Returns true if something played.
func play_for_item(item: RuleEngine.Item) -> bool:
	match item:
		RuleEngine.Item.PAPER:
			await _play_anim(ANIM_PAPER)
			return true
		_:
			return false


func _play_anim(anim: StringName) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(anim):
		return
	visible = true
	frame = 0
	play(anim)
	await animation_finished
	visible = false
	stop()
