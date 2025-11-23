
extends CanvasLayer

@export var lobby_scene_path: String = "res://menu/lobby/lobby.tscn"

const START_BUTTON_PATH = "CenterContainer/VBoxContainer/StartButton"
const EXIT_BUTTON_PATH = "CenterContainer/VBoxContainer/ExitButton"

@onready var start_button: Button = get_node(START_BUTTON_PATH)
@onready var exit_button: Button = get_node(EXIT_BUTTON_PATH)

func _ready():
	if start_button and exit_button:
		if not start_button.pressed.is_connected(_on_start_button_pressed):
			start_button.pressed.connect(_on_start_button_pressed)
		if not exit_button.pressed.is_connected(_on_exit_button_pressed):
			exit_button.pressed.connect(_on_exit_button_pressed)
		start_button.grab_focus()
	else:
		push_error("Не удалось найти одну или обе кнопки. Проверьте пути: %s и %s" % [START_BUTTON_PATH, EXIT_BUTTON_PATH])

func _on_start_button_pressed():
	print("Нажата кнопка Start. Загрузка лобби: ", lobby_scene_path)
	
	if ResourceLoader.exists(lobby_scene_path):
		get_tree().change_scene_to_file(lobby_scene_path)
	else:
		push_error("Неверный или пустой путь к лобби: ", lobby_scene_path)

func _on_exit_button_pressed():
	print("Нажата кнопка Exit. Выход из игры.")
	get_tree().quit()
