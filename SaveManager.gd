# SaveManager.gd — Autoload singleton
# 5 slots en disco (user://saves/):
#   - manual_1, manual_2, manual_3: el jugador elige en cuál guardar,
#     desde el menú de pausa o el menú del Lobby.
#   - autosave_start: se sobreescribe automáticamente al INICIAR un run.
#   - autosave_end:   se sobreescribe automáticamente al TERMINAR un run.

extends Node

const SAVE_DIR := "user://saves/"

const MANUAL_SLOT_META := [
	{"slot": "manual_1", "label": "Partida 1"},
	{"slot": "manual_2", "label": "Partida 2"},
	{"slot": "manual_3", "label": "Partida 3"},
]

const AUTOSAVE_SLOT_META := [
	{"slot": "autosave_start", "label": "Autoguardado — Inicio de Run"},
	{"slot": "autosave_end",   "label": "Autoguardado — Fin de Run"},
]

const SLOT_AUTOSAVE_START := "autosave_start"
const SLOT_AUTOSAVE_END   := "autosave_end"


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Guarda el estado persistente actual de RunManager en el slot indicado.
func save_slot(slot_name: String) -> bool:
	var data := {
		"gold":                   RunManager.gold,
		"unlocked_areas":         RunManager.unlocked_areas,
		"unlocked_relics":        RunManager.unlocked_relics,
		"equipped_relics":        RunManager.equipped_relics,
		"tutorial_done":          RunManager.tutorial_done,
		"tutorial_sibu_revealed": RunManager.tutorial_sibu_revealed,
		"saved_at_unix":          Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(_path_for(slot_name), FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: no se pudo abrir el slot '%s' para escribir." % slot_name)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## Carga un slot y aplica los datos a RunManager. false si no existe o está corrupto.
func load_slot(slot_name: String) -> bool:
	var path := _path_for(slot_name)
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: slot '%s' corrupto o con formato inválido." % slot_name)
		return false

	RunManager.gold                   = int(parsed.get("gold", 0))
	RunManager.unlocked_areas         = parsed.get("unlocked_areas", ["bribri"])
	RunManager.unlocked_relics        = parsed.get("unlocked_relics", [])
	RunManager.equipped_relics        = parsed.get("equipped_relics", [])
	RunManager.tutorial_done          = bool(parsed.get("tutorial_done", false))
	RunManager.tutorial_sibu_revealed = bool(parsed.get("tutorial_sibu_revealed", false))
	return true


func slot_exists(slot_name: String) -> bool:
	return FileAccess.file_exists(_path_for(slot_name))


## Devuelve {} si el slot no existe o está corrupto.
func get_slot_info(slot_name: String) -> Dictionary:
	var path := _path_for(slot_name)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return {"saved_at_unix": int(parsed.get("saved_at_unix", 0))}


func _path_for(slot_name: String) -> String:
	return SAVE_DIR + slot_name + ".json"
