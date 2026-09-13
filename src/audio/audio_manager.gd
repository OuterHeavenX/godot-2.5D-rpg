extends Node
## AudioMan (autoload): pooled SFX players + region music with crossfades.
## PROCESS_MODE_ALWAYS so music keeps playing under the paused main menu.
## SFX are CC0 Kenney plus a few generated ones; music loops are generated.
##
## Regions: "village" (Emberfell and the southern wilds), "north" (past the
## north gate: cold wilds, Grimholt, the arena), "boss" (a living boss is
## close). The region is polled a few times a second from the player's
## position and the boss group; switching crossfades between two players.

const POOL_SIZE := 8
const MUSIC := {
	"village": "res://src/audio/music/village_ambient.wav",
	"north": "res://src/audio/music/north_wind.wav",
	"boss": "res://src/audio/music/boss_drums.wav",
}
const MUSIC_DB := {"village": -16.0, "north": -14.0, "boss": -13.0}
const CROSSFADE := 2.5
const BOSS_RANGE := 30.0
const NORTH_Z := -30.0
const SFX_NAMES := ["swing", "hit", "bone_hit", "bone_die", "dodge", "levelup", "click",
	"potion", "potion_drink", "cast", "heal", "step", "growl", "squish", "wisp", "laugh"]

var _sfx: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current: AudioStreamPlayer  # the player carrying the audible track
var _region := ""
var _poll := 0.0
var _fade_tween: Tween
var music_enabled := true
var sfx_enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for n in SFX_NAMES:
		var path := "res://src/audio/sfx/%s.ogg" % n
		if not ResourceLoader.exists(path):
			path = "res://src/audio/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)
	for key in MUSIC:
		if ResourceLoader.exists(MUSIC[key]):
			_streams[key] = load(MUSIC[key])
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_current = _music_a
	set_region("village", true)

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -80.0
	add_child(p)
	# Imports are set to loop; this keeps a track going even without loop points.
	p.finished.connect(p.play)
	return p

func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.3:
		return
	_poll = 0.0
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var pp := player.global_position
	var want := "village"
	for b in tree.get_nodes_in_group("boss"):
		var boss := b as Node3D
		if boss == null or bool(boss.get("dead")):
			continue
		var d := Vector2(boss.global_position.x - pp.x, boss.global_position.z - pp.z).length()
		if d < BOSS_RANGE:
			want = "boss"
			break
	if want != "boss" and pp.z < NORTH_Z and pp.x < 400.0:
		want = "north"
	set_region(want)

## Switch the music region with a crossfade (instant when `now` is true).
func set_region(region: String, now := false) -> void:
	if region == _region or not _streams.has(region):
		return
	_region = region
	var next: AudioStreamPlayer = _music_b if _current == _music_a else _music_a
	var prev: AudioStreamPlayer = _current
	_current = next
	next.stream = _streams[region]
	next.volume_db = -80.0 if not now else float(MUSIC_DB[region])
	next.stream_paused = not music_enabled
	next.play()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if now:
		prev.stop()
		return
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(next, "volume_db", float(MUSIC_DB[region]), CROSSFADE)
	_fade_tween.tween_property(prev, "volume_db", -80.0, CROSSFADE)
	_fade_tween.chain().tween_callback(prev.stop)

func current_region() -> String:
	return _region

func set_music_enabled(on: bool) -> void:
	music_enabled = on
	for p in [_music_a, _music_b]:
		if p != null:
			p.stream_paused = not on

func set_sfx_enabled(on: bool) -> void:
	sfx_enabled = on

func _load_settings() -> void:
	SaveGame.migrate_legacy()
	var cfg := ConfigFile.new()
	if cfg.load(SaveGame.SETTINGS_PATH) == OK:
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
