# MuseumData.gd
# AutoLoad singleton con todos los artefactos culturales Bribri del juego.
# SETUP: Proyecto → Autoload → res://Museum/MuseumData.gd → nombre: MuseumData
#
# Cada reliquia tiene:
#   id:          identificador único (debe coincidir con relic_id del boss)
#   name:        nombre para mostrar
#   description: ficha cultural (texto educativo real sobre la cultura Bribri)
#   effect:      descripción del bonus de gameplay que activa en el lobby
#   bonus_type:  string que RunManager usa para aplicar el efecto
#   bonus_value: valor numérico del bonus
extends Node

const RELICS: Dictionary = {
	"sibö_mascara": {
		"name": "Máscara de Sibö",
		"description": "Sibö es el dios creador de la cosmovisión Bribri. Según la tradición oral, Sibö creó a los seres humanos a partir de semillas de maíz y les enseñó las normas del convivir. Su máscara ceremonial es usada por el Awá (chamán) en rituales de sanación.",
		"effect": "+20% de vida máxima al inicio de cada run",
		"bonus_type": "max_health_pct",
		"bonus_value": 0.20,
	},
	"vasija_cacao": {
		"name": "Vasija del Cacao Sagrado",
		"description": "El cacao (Theobroma cacao) tiene un papel central en los rituales Bribri. Es considerado el cuerpo de Sibö y se usa en ceremonias de muerte y renacimiento (el Sorbö). Las vasijas de cacao ceremoniales son elaboradas por las mujeres del clan Küskür.",
		"effect": "Las salas de descanso restauran 30% más de vida",
		"bonus_type": "rest_heal_pct",
		"bonus_value": 0.30,
	},
	"flecha_awa": {
		"name": "Flecha del Awá",
		"description": "El Awá es el médico-chamán tradicional Bribri, responsable de curar enfermedades y mediar entre el mundo humano y el espiritual. Sus flechas rituales, impregnadas con plantas medicinales de la selva de Talamanca, son uno de sus principales instrumentos de sanación.",
		"effect": "+15% de daño de proyectiles",
		"bonus_type": "projectile_dmg_pct",
		"bonus_value": 0.15,
	},
	"piedra_tsuru": {
		"name": "Piedra Tsuru",
		"description": "Las piedras Tsuru son amuletos de jade y piedra verde usados en la cultura Bribri como objetos de protección. Según la tradición, contienen el alma de los ancestros y protegen a su portador de los espíritus malignos del bosque (los Sula).",
		"effect": "15% de probabilidad de esquivar daño",
		"bonus_type": "dodge_chance",
		"bonus_value": 0.15,
	},
	"tambor_bribri": {
		"name": "Tambor Ceremonial",
		"description": "El tambor (kikékök) es central en las ceremonias Bribri, especialmente en el Sorbö, la celebración funeraria de varios días donde se canta, baila y bebe chicha de maíz. Los patrones rítmicos del tambor son transmitidos de generación en generación dentro de los clanes matrilineales.",
		"effect": "El dash se puede usar una vez más antes del cooldown",
		"bonus_type": "extra_dash",
		"bonus_value": 1.0,
	},
}


func get_relic(relic_id: String) -> Dictionary:
	return RELICS.get(relic_id, {})


func get_all_relic_ids() -> Array:
	return RELICS.keys()
