extends RefCounted
class_name MatchContext

var base_color: int = 100                # e.g., Global.TileColor.RED (100)
var primary_color: int = 100             # Exact color ID or Exotic ID if pure exotic match
var match_count: int = 3                 # Total tiles matched (3, 4, 5+)
var shape_type: String = "LINE_3"        # "LINE_3", "LINE_4", "LINE_5", "L_SHAPE", "T_SHAPE"
var is_manual_swap: bool = false         # True ONLY on direct player swap
var is_exotic_blend: bool = false        # True if manual swap combined Base + Exotic
var exotic_count: int = 0                # Quantity of exotic tiles in match
var cascade_step: int = 0                # 0 for manual match, 1+ for subsequent cascades
var match_index_for_color_this_turn: int = 1 # Sequence counter for this specific color this turn
var lowest_row: int = 0                  # Normalized row index (0 = top of grid, grd_height - 1 = bottom of grid)
var total_fall_momentum: int = 0         # Summed fall_distance of all tiles in match
var hazards_cleared: Array[String] = []  # Identifiers of hazards cleared ("ice", "freeze", "rock", "flesh")

# Additional match metadata
var has_crit: bool = false               # True if any matched tile had critical proc
var gold_count: int = 0                  # Count of gold border tiles in match
var matched_positions: Array[Vector2] = [] # Board coordinates in this match
var potency_multiplier: float = 1.0      # Aggregated potency multiplier (momentum, exotic blend, etc.)
var lifesteal_bonus: float = 0.0         # Temporary lifesteal bonus (e.g., 0.25 from DARK_CRIMSON)

func get_momentum_multiplier() -> float:
	return 1.0 + (float(total_fall_momentum) * 0.05)

func is_in_bottom_half(grid_height: int = 8) -> bool:
	return lowest_row >= int(grid_height / 2)
