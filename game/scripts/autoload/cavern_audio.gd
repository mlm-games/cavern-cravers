extends Node

var _sfx_library := {}

var haptic_supported := false

const SFX_PATHS := {
	hit = "res://game/assets/audio/sfx/hit.wav",
	pickup = "res://game/assets/audio/sfx/pickup.wav",
	explosion = "res://game/assets/audio/sfx/explosion.wav",
	heal = "res://game/assets/audio/sfx/heal.wav",
	death = "res://game/assets/audio/sfx/death.wav",
	jewel = "res://game/assets/audio/sfx/jewel.wav",
	shield = "res://game/assets/audio/sfx/shield.wav",
	move = "res://game/assets/audio/sfx/move.wav",
	button = "res://game/assets/audio/sfx/button.wav",
	undo = "res://game/assets/audio/sfx/undo.wav",
}

var _settings := {
	"sound_enabled": true,
	"haptics_enabled": true
}


func _ready() -> void:
	_check_haptic_support()
	_load_sfx_library()
	if SettingsManager:
		SettingsManager.profile_changed.connect(_on_settings_changed)
	_on_settings_changed()


func _check_haptic_support() -> void:
	haptic_supported = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _load_sfx_library() -> void:
	for key in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStream:
				_sfx_library[key] = stream


## SFX Playback

func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	if not _settings.sound_enabled:
		return
	
	if not _sfx_library.has(sfx_name):
		if SFX_PATHS.has(sfx_name) and ResourceLoader.exists(SFX_PATHS[sfx_name]):
			_sfx_library[sfx_name] = load(SFX_PATHS[sfx_name])
		else:
			push_warning("CavernAudio: SFX not found: " + sfx_name)
			return
	
	var stream: AudioStream = _sfx_library[sfx_name]
	AudioM.play_sound_varied(stream, 0.05, volume_db, &"SFX")


func play_random_sfx(sfx_names: Array[String], volume_db: float = 0.0) -> void:
	if sfx_names.is_empty():
		return
	play_sfx(sfx_names.pick_random(), volume_db)


func has_sfx(sfx_name: String) -> bool:
	return _sfx_library.has(sfx_name)


func vibrate(duration_ms: int = 50) -> void:
	if not _settings.haptics_enabled or not haptic_supported:
		return
	
	Input.vibrate_handheld(duration_ms)


func vibrate_damage() -> void:
	vibrate(100)


func vibrate_kill() -> void:
	vibrate(50)


func vibrate_explosion() -> void:
	vibrate(200)


func vibrate_collect() -> void:
	vibrate(30)


## Settings

func _load_settings() -> void:
	_settings.sound_enabled = SettingsManager.get_setting("accessibility", "sound_enabled", true)
	_settings.haptics_enabled = SettingsManager.get_setting("accessibility", "haptics_enabled", true)

func _on_settings_changed() -> void:
	_load_settings()


func _save_settings() -> void:
	SettingsManager.set_setting("accessibility", "sound_enabled", _settings.sound_enabled)
	SettingsManager.set_setting("accessibility", "haptics_enabled", _settings.haptics_enabled)
	SettingsManager.save_profile()


func set_sound_enabled(enabled: bool) -> void:
	_settings.sound_enabled = enabled
	_save_settings()


func set_haptics_enabled(enabled: bool) -> void:
	_settings.haptics_enabled = enabled
	_save_settings()


func is_sound_enabled() -> bool:
	return _settings.sound_enabled


func is_haptics_enabled() -> bool:
	return _settings.haptics_enabled
