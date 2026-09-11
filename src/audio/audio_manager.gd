extends Node
## AudioMan (autoload): pooled SFX players + looping ambient music.
## PROCESS_MODE_ALWAYS so music keeps playing under the paused main menu.
## All SFX are CC0 Kenney; music is an original generated loop.

const POOL_SIZE := 8

var _sfx: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var music_enabled := true
var sfx_enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
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
	_music.stream_paused = not music_enabled
	_music.play()

func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if _music != null:
		_music.stream_paused = not on

func set_sfx_enabled(on: bool) -> void:
	sfx_enabled = on

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SaveGame.SAVE_PATH) == OK:
		music_enabled = bool(cfg.get_value("settings", "music", true))
		sfx_enabled = bool(cfg.get_value("settings", "sfx", true))

## Play a named SFX. Pitch is randomized slightly for variety.
func play(sfx_name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not sfx_enabled:
		return
	if not _sfx.has(sfx_name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sfx[sfx_name]
			p.pitch_scale = pitch * randf_range(0.96, 1.04)
			p.volume_db = vol_db
			p.play()
			return
