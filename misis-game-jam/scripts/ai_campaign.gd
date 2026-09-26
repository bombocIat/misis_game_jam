class_name AiCampaign
extends RefCounted
## Unlock ladder: Каменщик → Ботаник → Шулер.


const SAVE_NAME := "ai_campaign_v2.cfg"
const MAX_TIER := 2

## Highest unlocked opponent index (0..2).
var unlocked_tier: int = 0
## Opponent currently fought.
var current_tier: int = 0


func _init() -> void:
	load_progress()


## Editor → project root; export → next to the .exe.
func _save_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://" + SAVE_NAME)
	return OS.get_executable_path().get_base_dir().path_join(SAVE_NAME)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_save_path()) != OK:
		unlocked_tier = 0
		current_tier = 0
		return
	unlocked_tier = clampi(int(cfg.get_value("campaign", "unlocked_tier", 0)), 0, MAX_TIER)
	current_tier = clampi(int(cfg.get_value("campaign", "current_tier", 0)), 0, unlocked_tier)


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "unlocked_tier", unlocked_tier)
	cfg.set_value("campaign", "current_tier", current_tier)
	cfg.save(_save_path())


func persona_for_tier(tier: int) -> AiOpponent.Persona:
	match clampi(tier, 0, MAX_TIER):
		0:
			return AiOpponent.Persona.MASON
		1:
			return AiOpponent.Persona.BOTANIST
		_:
			return AiOpponent.Persona.CHEATER


func name_for_tier(tier: int) -> String:
	return str(AiOpponent.PERSONA_NAMES[persona_for_tier(tier)])


## Call when the player beats the current opponent.
## Returns true if a new opponent was unlocked.
func on_player_won() -> bool:
	var unlocked_new := false
	if current_tier >= unlocked_tier and unlocked_tier < MAX_TIER:
		unlocked_tier += 1
		unlocked_new = true
	if current_tier < unlocked_tier:
		current_tier += 1
	save_progress()
	return unlocked_new


func retry_current() -> void:
	save_progress()
