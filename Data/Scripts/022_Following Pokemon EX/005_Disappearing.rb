#-------------------------------------------------------------------------------
# These are used to define whether the follower should appear or disappear when
# refreshing it. "next true" will let it stay and "next false" will make it
# disappear
#-------------------------------------------------------------------------------
EventHandlers.add(:following_pkmn_appear, :vehicles, proc { |_pkmn|
  # Don't follow if on bicyle
  next false if $PokemonGlobal.bicycle
  # Don't follow if on Pokeride
  next false if $PokemonGlobal.respond_to?(:mount) && $PokemonGlobal.mount
})
#-------------------------------------------------------------------------------
EventHandlers.add(:following_pkmn_appear, :map_flag_keep, proc { |pkmn|
  metadata = $game_map.metadata
  # Always follow if map has the approriate flag to hide
  next true if metadata && metadata.has_flag?("ShowFollowingPkmn")
})
#-------------------------------------------------------------------------------
EventHandlers.add(:following_pkmn_appear, :height, proc { |pkmn|
  metadata = $game_map.metadata
  if metadata && metadata.outdoor_map != true
    # Don't follow if the Pokemon's height is greater than 3 meters and there are no encounters ie a building or something
    height =  GameData::Species.get_species_form(pkmn.species, pkmn.form).height
    next false if $PokemonEncounters.nil? #added by Gardenette to prevent a crash
    next false if (height / 10.0) > 3.0 && !$PokemonEncounters.encounter_possible_here?
  end
})
#-------------------------------------------------------------------------------
EventHandlers.add(:following_pkmn_appear, :map_flag_remove, proc { |pkmn|
  metadata = $game_map.metadata
  # Don't follow if map has the approriate flag to show
  next true if metadata && metadata.has_flag?("HideFollowingPkmn")
})
#-------------------------------------------------------------------------------
EventHandlers.add(:following_pkmn_appear, :map_flag_remove, proc { |pkmn|
  metadata = $game_map.metadata
  if metadata && metadata.outdoor_map != true
    # The Pokemon disappears if it's height is greater than 3 meters and there are no encounters ie a building or something
    height =  GameData::Species.get_species_form(pkmn.species, pkmn.form).height
    next false if (height / 10.0) > 3.0 && !$PokemonEncounters.encounter_possible_here?
  end
})
#-------------------------------------------------------------------------------
EventHandlers.add(:following_pkmn_appear, :surfing, proc { |pkmn|
  if $PokemonGlobal.surfing
    # Don't follow if this is the Pokemon currently being ridden
    next false if pkmn == $PokemonGlobal.current_surfing
    # Follow if the Pokemon is water type
    next true if pkmn.hasType?(:WATER)
    # Don't follow if the Pokemon is manually selected
    next false if FollowingPkmn::SURFING_FOLLOWERS_EXCEPTIONS.any? do |s|
                    s == pkmn.species || s.to_s == "#{pkmn.species}_#{pkmn.form}"
                  end
    # Follow if the Pokemon flies or levitates
    next true if FollowingPkmn.airborne_follower?
    # Don't Follow
    next false
  end
})
#-------------------------------------------------------------------------------
EventHandlers.add(:following_pkmn_appear, :diving, proc { |pkmn|
  if $PokemonGlobal.diving
    # Don't follow if this is the Pokemon currently being ridden
    next false if pkmn == $PokemonGlobal.current_diving
    # Follow if the Pokemon is water type
    next true if pkmn.hasType?(:WATER)
    # Don't Follow
    next false
  end
})
#-------------------------------------------------------------------------------