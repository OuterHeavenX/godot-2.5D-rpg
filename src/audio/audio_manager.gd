extends Node
## AudioMan (autoload): pooled SFX players + looping ambient music.
## PROCESS_MODE_ALWAYS so music keeps playing under the paused main menu.
## All SFX are CC0 Kenney; music is an original generated loop.

const POOL_SIZE := 8

var _sfx: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for n in ["swing", "hit", "bone_hit", "bone_die", "dodge", "levelup", "click"]:
		_sfx[n] = load("res://src/audio/sfx/%s.ogg" % n)
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://src/audio/music/village_ambient.wav")
	_music.volume_db = -16.0
	add_child(_music)
	_music.play()

## Play a named SFX. Pitch is randomized slightly for variety.
func play(sfx_name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not _sfx.has(sfx_name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sfx[sfx_name]
			p.pitch_scale = pitch * randf_range(0.96, 1.04)
			p.volume_db = vol_db
			p.play()
			return
