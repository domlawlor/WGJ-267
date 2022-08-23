extends Node

signal sweep(pos, facingRight)
signal spawn_dust(pos, amount)
signal ladder_climbing_activate()
signal ladder_climbing_deactivate()
signal dust_amount_changed(amount)
signal level_complete()
signal level_exited(num)

signal start_time_limit()
signal hit_time_limit()

signal player_death_animation()
signal show_death_screen()

signal debug_set_player_pos(pos)
