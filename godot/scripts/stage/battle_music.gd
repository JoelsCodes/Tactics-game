class_name BattleMusic
extends Node
## The battle's music: one track at a time from `res://assets/audio/music/<name>.ogg`, faded in and out. A missing file is silence
## (like CombatAudio). The tracks that exist are synthesized placeholders (tools/audio/make_audio.py): drop a real recording with
## the same name in the folder and it plays instead.
##
##   battle_theme     loops through the fight
##   victory_fanfare  once, at a win; then results_loop under the results screen
##   defeat_sting     once, at a loss
##
## `muted` (the M key in battle) and the volume are saved with the other settings (user://settings.cfg, section "audio").

const DIR := "res://assets/audio/music/"
const SETTINGS_PATH := "user://settings.cfg"

static var muted := false
static var volume_db := -12.0
static var _loaded := false

var current := ""  ## the track asked for last ("" when stopped)
var _player: AudioStreamPlayer
var _fade: Tween
var _next := ""  ## the loop that follows a one-shot


func _ready() -> void:
	load_settings()
	_player = AudioStreamPlayer.new()
	_player.volume_db = -60.0
	add_child(_player)
	_player.finished.connect(_on_finished)
	process_mode = Node.PROCESS_MODE_ALWAYS


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		muted = bool(cf.get_value("audio", "music_muted", false))
		CombatAudio.muted = bool(cf.get_value("audio", "sfx_muted", false))


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("audio", "music_muted", muted)
	cf.set_value("audio", "sfx_muted", CombatAudio.muted)
	cf.save(SETTINGS_PATH)


static func stream(track: String) -> AudioStream:
	var path := DIR + track + ".ogg"
	return load(path) if ResourceLoader.exists(path) else null


## Starts `track` (looping or once), fading out whatever plays. `then` is a loop to start when a one-shot ends.
## Returns whether there was a file to play.
func play(track: String, loop := true, then := "", fade_in := 0.5) -> bool:
	current = track
	_next = then
	var s := stream(track)
	if _fade:
		_fade.kill()
	if s == null:
		_player.stop()
		return false
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	_player.stream = s
	_player.volume_db = -60.0 if fade_in > 0.0 else _level()
	_player.play()
	if fade_in > 0.0:
		_fade = create_tween()
		_fade.tween_property(_player, "volume_db", _level(), fade_in)
	return true


func stop(fade_out := 0.6) -> void:
	current = ""
	_next = ""
	if _fade:
		_fade.kill()
	if not _player.playing:
		return
	if fade_out <= 0.0:
		_player.stop()
		return
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -60.0, fade_out)
	_fade.tween_callback(_player.stop)


func set_muted(on: bool) -> void:
	muted = on
	save_settings()
	if _fade:
		_fade.kill()
	_player.volume_db = _level()


func _level() -> float:
	return -80.0 if muted else volume_db


func _on_finished() -> void:
	if _next != "":
		var n := _next
		play(n, true, "", 0.8)
