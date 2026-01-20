extends Node
## GameManager - Global game state management singleton

enum GameState { PLAYING, PAUSED, MENU }

signal game_state_changed(new_state: GameState)

var current_state: GameState = GameState.PLAYING


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func pause() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		game_state_changed.emit(current_state)


func resume() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		game_state_changed.emit(current_state)


func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		pause()
	elif current_state == GameState.PAUSED:
		resume()


func set_state(new_state: GameState) -> void:
	if current_state != new_state:
		current_state = new_state
		game_state_changed.emit(current_state)
