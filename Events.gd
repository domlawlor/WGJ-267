extends Node

signal sweep(pos, facingRight)
signal spawn_dust(pos, amount)
signal spawn_lava(pos, makeFlying, flyingVelocity)
signal ladder_climbing_activate()
signal ladder_climbing_deactivate()
signal player_using_ladder(usingLadder)

signal dust_amount_changed(amount)
signal level_complete()
signal level_exited(num)

signal start_game()
signal start_time_limit()
signal hit_time_limit()

signal player_death_animation()
signal show_death_screen()

signal fade_to_black()
signal fade_to_black_complete()
signal fade_to_transparent()
signal fade_to_transparent_complete()

signal debug_set_player_pos(pos)

# sfx
signal sfx_sweep()
signal sfx_janitorStart()
signal sfx_grunt()
