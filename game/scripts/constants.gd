class_name C extends Node # Constants

enum BusNames { # Use get string from enum fn
	Master,
	Music,
	Sfx,
}

const SCREENS = {
	CREDITS = "uid://bq0gelfcjnqvg",
	SETTINGS = "uid://dp42fom7cc3n0",
	MENU = "res://game/scenes/ui/main_menu.tscn",
	END = "res://game/scenes/ui/game_over.tscn",
	
	GAME = "res://game/scenes/ui/game.tscn",
	TUTORIAL = "res://game/scenes/ui/tutorial.tscn",
}

const RESOURCES = {
	SHADERS = {
		CIRCULAR_ENGULF = preload("res://game/assets/resources/shaders/circletransition.gdshader")
	}
}

const PATHS = {
	CAVERN_ASSETS = {
		SPRITES = "res://game/assets/sprites/",
		AUDIO = "res://game/assets/audio/",
		MUSIC = "res://game/assets/audio/music/",
		SFX = "res://game/assets/audio/sfx/",
	}
}
