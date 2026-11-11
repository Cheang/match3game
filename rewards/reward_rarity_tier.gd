extends Resource
class_name RewardRarityTier

## Defines which rarity tier this configuration applies to.
## 0 = COMMON, 1 = UNCOMMON, 2 = RARE, 3 = EPIC, 4 = LEGENDARY, 5 = GODLY
enum Rarity {
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,
	LEGENDARY = 4,
	GODLY = 5
}

# ==============================================================================
# 1. TIER IDENTITY & OVERRIDE MODE
# ==============================================================================
@export_group("Tier Identity")
## The rarity tier this resource configures.
@export var rarity: Rarity = Rarity.UNCOMMON
## Optional custom name at this rarity tier (leave blank to keep base Reward name).
@export var custom_name: String = ""
## Optional custom narrative description for this tier. If blank, auto-generates from stats and effects.
@export_multiline var custom_description: String = ""
## Optional custom icon at this rarity tier (leave null to keep base Reward icon).
@export var custom_icon: Texture2D
## If true (default), non-zero stat values below OVERRIDE the base Reward's stats at this rarity
## (e.g., Base max_health = 10 -> Uncommon max_health = 12 -> Rare max_health = 16 + heal_hp = 5).
## If false, values below are ADDED to the base Reward's stats.
@export var is_stat_override: bool = true

# ==============================================================================
# 2. STAT OVERRIDES / BONUSES
# ==============================================================================
@export_group("Stats & Consumables at This Rarity")
## Might granted at this rarity tier.
@export var might: float = 0.0
## Grit granted at this rarity tier.
@export var grit: float = 0.0
## Spirit granted at this rarity tier.
@export var spirit: float = 0.0
## Agility granted at this rarity tier.
@export var agility: float = 0.0
## Maximum Health granted at this rarity tier.
@export var max_health: float = 0.0
## Critical Strike chance percentage granted at this rarity tier.
@export var crit_chance: int = 0
## Immediate HP healed when picked at this rarity tier (can be added even if base reward had 0 heal!).
@export var heal_hp: float = 0.0
## Immediate Gold awarded when picked at this rarity tier.
@export var gold: int = 0
## Immediate Rerolls awarded when picked at this rarity tier.
@export var rerolls: int = 0

# ==============================================================================
# 3. EQUIPMENT OVERRIDES / BONUSES
# ==============================================================================
@export_group("Equipment at This Rarity")
## If non-empty, completely replaces the base Reward's `equipment_to_grant` at this rarity tier.
@export var equipment_override: Array[Equipment] = []
## Optional extra copies of the primary equipment to grant at this rarity tier (when equipment_override is empty).
@export var extra_equipment_copies: int = 0

# ==============================================================================
# 4. MECHANIC & FLAG OVERRIDES / BONUSES
# ==============================================================================
@export_group("Mechanics & Flags at This Rarity")
## Additional custom flags unlocked when claimed (or equipped as a passive) at this rarity tier.
@export var extra_custom_flags: Array[String] = []
## Optional override for slot_expansion_amount when mechanic_type == EXPAND_TRACK_SLOTS (0 = keep base).
@export var slot_expansion_override: int = 0
