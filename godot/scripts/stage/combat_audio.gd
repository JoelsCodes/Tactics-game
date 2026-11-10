class_name CombatAudio
extends RefCounted
## Combat sound hooks. Every event is looked up by name under `res://assets/audio/sfx/<event>.ogg` (or `.wav`) and quietly skipped
## when the file is not there: combat never depends on a sound. The files that exist are synthesized placeholders
## (tools/audio/make_audio.py): drop a real recording with an event's name into that folder and it plays with no code change.
## `missing` lists the events asked for that have no file (HANDOFF.md keeps the full list of event names).

const DIR := "res://assets/audio/sfx/"
const POOL := 8  ## simultaneous voices; the oldest is reused

static var _streams := {}  ## event -> AudioStream, or null when there is no file
static var missing := {}  ## event -> true, every event asked for that has no file
static var played := []  ## the events actually started, newest last (tests read this; capped)
static var volume_db := -4.0
static var muted := false  ## no sound effects at all (saved by BattleMusic.save_settings)


## Starts `event` on a pooled player under `host`. Returns whether a sound was started.
static func play(host: Node, event: String, pitch := 1.0, gain_db := 0.0) -> bool:
	if event == "" or host == null or not host.is_inside_tree() or muted:
		return false
	var s := stream(event)
	if s == null:
		missing[event] = true
		return false
	var pool: Node = host.get_node_or_null("CombatAudioPool")
	if pool == null:
		pool = Node.new()
		pool.name = "CombatAudioPool"
		host.add_child(pool)
		for i in POOL:
			pool.add_child(AudioStreamPlayer.new())
	var voice: AudioStreamPlayer = null
	for p in pool.get_children():
		if not p.playing:
			voice = p
			break
	if voice == null:
		voice = pool.get_child(0)
	voice.stream = s
	voice.pitch_scale = pitch
	voice.volume_db = volume_db + gain_db
	voice.play()
	played.append(event)
	if played.size() > 64:
		played.pop_front()
	return true


## The stream for an event, or null when there is no file. Looked up once.
static func stream(event: String) -> AudioStream:
	if _streams.has(event):
		return _streams[event]
	var found: AudioStream = null
	for ext in ["ogg", "wav"]:
		var path := "%s%s.%s" % [DIR, event, ext]
		if ResourceLoader.exists(path):
			found = load(path)
			break
	_streams[event] = found
	return found
