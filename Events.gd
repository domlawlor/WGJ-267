extends Node

signal sweep(pos, facingRight)
signal spawn_dust(pos, amount)
signal ladder_climbing_activate()
signal ladder_climbing_deactivate()
signal dust_amount_changed()
signal level_complete()
signal level_exited(num)

signal start_countdown_timer()
signal countdown_timer_end_hit()

signal debug_set_player_pos(pos)
