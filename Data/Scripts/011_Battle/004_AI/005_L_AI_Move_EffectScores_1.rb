class Battle::AI
# added the new status nerf if $game_variables[MECHANICSVAR] is above or equal to 3 #by low
  #=============================================================================
  # Get a score for the given move based on its effect
  #=============================================================================
  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
	mold_broken = moldbroken(user,target,move)
	globalArray = pbGetMidTurnGlobalChanges
	aspeed = pbRoughStat(user,:SPEED,skill)
	ospeed = pbRoughStat(target,:SPEED,skill)
	userFasterThanTarget = ((aspeed>ospeed) ^ (@battle.field.effects[PBEffects::TrickRoom]>0))
	pbAIPrioSpeedCheck(user,target,move,score,globalArray,aspeed,ospeed)
    case move.function
    #---------------------------------------------------------------------------
    when "Struggle"
    #---------------------------------------------------------------------------
    when "None"   # No extra effect
    #---------------------------------------------------------------------------
    when "DoesNothingCongratulations", "DoesNothingFailsIfNoAlly", # Hold Hands, Celebrate
         "DoesNothingUnusableInGravity","AddMoneyGainedFromBattle", # Splash, Pay Day
		 "DoubleMoneyGainedFromBattle" # Happy Hour
      score = 0
    #---------------------------------------------------------------------------
    when "FailsIfNotUserFirstTurn" # first impression
		if user.turnCount > 0
			score = 0
		else
			if !targetSurvivesMove(move,user,target)
				score*=1.5
			end
		end
    #---------------------------------------------------------------------------
    when "FailsIfUserHasUnusedMove" # Last Resort
		hasThisMove = false
		hasOtherMoves = false
		hasUnusedMoves = false
		user.eachMove do |m|
			hasThisMove    = true if m.id == @id
			hasOtherMoves  = true if m.id != @id
			hasUnusedMoves = true if m.id != @id && !user.movesUsed.include?(m.id)
		end
		if !hasThisMove || !hasOtherMoves || hasUnusedMoves
			score=0
		end
    #---------------------------------------------------------------------------
    when "FailsIfUserNotConsumedBerry" # Belch
      score = 0 if !user.belched?
    #---------------------------------------------------------------------------
    when "FailsIfTargetHasNoItem" # poltergeist
		if !target.item || !target.itemActive?
			score = 0
		else
			score *= 1.3
		end
    #---------------------------------------------------------------------------
    when "FailsUnlessTargetSharesTypeWithUser" # synchronoise
      if !(user.types[0] && target.pbHasType?(user.types[0], true)) &&
         !(user.types[1] && target.pbHasType?(user.types[1], true))
        score = 0
      end
    #---------------------------------------------------------------------------
    when "FailsIfUserDamagedThisTurn" # focus punch
		startscore=score
		soundcheck=false
		multicheck=false
		for m in target.moves
			soundcheck = true if m.ignoresSubstitute?(target) # includes infiltrator
			multicheck = true if m.multiHitMove?
		end
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			if multicheck || soundcheck
				score*=0.9
			else
				score*=1.3
			end
		else
			score *= 0.8
		end
		if target.asleep? && (target.statusCount>=1 || !target.hasActiveAbility?(:EARLYBIRD)) && !target.hasActiveAbility?(:SHEDSKIN)
			score*=1.2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			score *= 0.5
		end
		if target.effects[PBEffects::HyperBeam]>0
			score*=1.5
		end
		if score<=startscore
			score*=0.3
		end
    #---------------------------------------------------------------------------
    when "FailsIfTargetActed" # sucker punch
		alldam = true
		pricheck = false
		healcheck = false
		for m in target.moves
			alldam = false if m.baseDamage<=0
			pricheck = true if m.priority>0
			healcheck = true if m.healingMove?
		end
		setupcheck = false
		setupcheck = true if pbHasSetupMove?(target, false)
		alldam = false if setupcheck
		if alldam && !pricheck
			score*=1.3
		else
			if healcheck
				score*=0.6
			end
			if setupcheck
				score*=0.8
			end
			if @battle.choices[target.index][0] == :UseMove &&
				!@battle.choices[target.index][2].statusMove?
				score*=1.5
			else
				score=0
			end
			if user.lastMoveUsed == :SUCKERPUNCH # Sucker Punch last turn
				if setupvar
					score*=0.5
				end
			end
			if userFasterThanTarget
				score*=0.8
			else
				if pricheck
					score*=0.5
				else
					score*=1.3
				end
			end
		end
    #---------------------------------------------------------------------------
    when "CrashDamageIfFailsUnusableInGravity" # high jump kick
		if score < 100 
			score * 0.8
		end
		protectmove = false
		protectmove = true if pbHasSingleTargetProtectMove?(target)
		score*=0.5 if protectmove
		ministat=user.stages[:ACCURACY]
		ministat=0 if user.stages[:ACCURACY]<0
		ministat*=(10)
		ministat+=100
		ministat/=100.0
		score*=ministat
		if target.hasActiveItem?([:LAXINCENSE, :BRIGHTPOWDER])
			score*=0.7
		end
		if @battle.field.effects[PBEffects::Gravity] > 0 && !user.hasActiveItem?(:FLOATSTONE)
			score = 0
		end
    #---------------------------------------------------------------------------
    when "StartSunWeather" # sunny day
		if @battle.pbCheckGlobalAbility(:AIRLOCK) ||
		   @battle.pbCheckGlobalAbility(:CLOUDNINE) ||
		   @battle.field.weather == :Sun ||
		   globalArray.include?("sun weather")
			score = 0
		else
			score*=1.6 if user.pbOpposingSide.effects[PBEffects::AuroraVeil] > 0
			score*=0.6 if user.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
			if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
			   !user.takesHailDamage? && !user.takesSandstormDamage?)
				score*=1.3
			end
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Lead")
				score*=1.2
			end
			if user.hasActiveItem?(:HEATROCK)
				score*=1.3
			end
			if user.pbHasMove?(:WEATHERBALL)
				score*=2
			end
			if @battle.field.weather != :None && @battle.field.weather != :Sun
				score*=1.5
			end
			if user.pbHasMove?(:MOONLIGHT) || user.pbHasMove?(:SYNTHESIS) || user.pbHasMove?(:MORNINGSUN) ||
			   user.pbHasMove?(:GROWTH) || user.pbHasMove?(:SOLARBEAM) || user.pbHasMove?(:SOLARBLADE)
				score*=1.5
			end
			if user.pbHasType?(:FIRE, true)
				score*=1.5
			end
			if user.hasActiveAbility?([:CHLOROPHYLL, :FLOWERGIFT])
				score*=2
				if user.hasActiveItem?(:FOCUSASH)
					score*=2
				end
				# ???? i dont get what this thing does
				if user.effects[PBEffects::Protect] ||
					user.effects[PBEffects::Obstruct] ||
					user.effects[PBEffects::KingsShield] || 
					user.effects[PBEffects::BanefulBunker] ||
					user.effects[PBEffects::SpikyShield]
					score *=3
				end
			end
			if user.hasActiveAbility?([:SOLARPOWER, :LEAFGUARD, :HEALINGSUN, :COOLHEADED])
				score*=1.3
			end
			watervar=false
			@battle.pbParty(user.index).each_with_index do |m, i|
				next if m.fainted?
				next if [:XOLSMOL, :AMPHIBARK, :PEROXOTAL].include?(m.species)
				watervar=true if m.hasType?(:WATER)
			end
			if watervar
				score*=0.5
			end 
			if user.pbHasMove?(:THUNDER) || user.pbHasMove?(:HURRICANE)
				score*=0.7
			end
			if user.hasActiveAbility?(:DRYSKIN)
				score*=0.5
			end
			if user.hasActiveAbility?(:HARVEST)
				score*=1.5
			end
			# check how good the current/mega ability weather is for the opponent
			score*=(1 + (checkWeatherBenefit(target, globalArray, true)) / 100.0)
			# check how good the potential weather change is for us
			score*=(1 + (checkWeatherBenefit(user, globalArray, true, :Sun) / 100.0))
		end
    #---------------------------------------------------------------------------
    when "StartRainWeather" # rain dance
		if @battle.pbCheckGlobalAbility(:AIRLOCK) ||
		   @battle.pbCheckGlobalAbility(:CLOUDNINE) ||
		   @battle.field.weather == :Rain ||
		   globalArray.include?("rain weather")
			score = 0
		else
			score*=1.6 if user.pbOpposingSide.effects[PBEffects::AuroraVeil] > 0
			score*=0.6 if user.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
			if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
					!user.takesHailDamage? && !user.takesSandstormDamage?)
				score*=1.3
			end
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Lead")
				score*=1.2
			end
			if user.hasActiveItem?(:DAMPROCK)
				score*=1.3
			end
			if user.pbHasMove?(:WEATHERBALL)
				score*=2
			end
			if @battle.field.weather != :None && @battle.field.weather != :Rain
				score*=1.5
			end
			if user.pbHasMove?(:THUNDER) || user.pbHasMove?(:HURRICANE) || user.pbHasMove?(:STEAMBURST)
				score*=1.5
			end
			if user.pbHasType?(:WATER, true)
				score*=1.5
			end
			if user.hasActiveAbility?(:SWIFTSWIM)
				score*=2
				if user.hasActiveItem?(:FOCUSASH)
					score*=2
				end
				# ???? i dont get what this thing does
				if user.effects[PBEffects::Protect] ||
				   user.effects[PBEffects::Obstruct] ||
				   user.effects[PBEffects::KingsShield] || 
				   user.effects[PBEffects::BanefulBunker] ||
				   user.effects[PBEffects::SpikyShield]
					score *=3
				end
			end
			if user.hasActiveAbility?(:DRYSKIN)
				score*=1.3
			end
			firevar=false
			@battle.pbParty(user.index).each_with_index do |m, i|
				next if m.fainted?
				next if [:XOLSMOL, :AMPHIBARK, :PEROXOTAL].include?(m.species)
				firevar=true if m.hasType?(:FIRE)
			end
			if firevar
				score*=0.5
			end 
			if user.pbHasMove?(:MOONLIGHT) || user.pbHasMove?(:SYNTHESIS) || user.pbHasMove?(:MORNINGSUN) ||
			   user.pbHasMove?(:GROWTH) || user.pbHasMove?(:SOLARBEAM) || user.pbHasMove?(:SOLARBLADE)
				score*=0.5
			end
			if user.hasActiveAbility?(:HYDRATION)
				score*=1.5
			end
			score*=(1 + (checkWeatherBenefit(target, globalArray, true)) / 100.0)
			score*=(1 + (checkWeatherBenefit(user, globalArray, true, :Rain) / 100.0))
		end
    #---------------------------------------------------------------------------
    when "StartSandstormWeather" # sandstorm
		if @battle.pbCheckGlobalAbility(:AIRLOCK) ||
		   @battle.pbCheckGlobalAbility(:CLOUDNINE) ||
		   @battle.field.weather == :Sandstorm ||
		   globalArray.include?("sand weather")
			score = 0
		else
			score*=1.6 if user.pbOpposingSide.effects[PBEffects::AuroraVeil] > 0
			score*=0.6 if user.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
			if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
			   !user.takesHailDamage? && !user.takesSandstormDamage?)
				score*=1.3
			end
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Lead")
				score*=1.2
			end
			if user.hasActiveItem?(:SMOOTHROCK)
				score*=1.3
			end
			if user.pbHasMove?(:WEATHERBALL)
				score*=2
			end
			if @battle.field.weather != :None && 
			  !(@battle.field.weather == :Sandstorm || globalArray.include?("sand weather"))
				score*=1.5
			end
			if user.takesSandstormDamage?
				score*=0.7
			else
				score*=1.3
			end
			if user.pbHasType?(:ROCK, true)
				score*=1.5
			end
			if user.hasActiveAbility?(:SANDRUSH)
				score*=2
				if user.hasActiveItem?(:FOCUSASH)
					score*=2
				end
				# ???? i dont get what this thing does
				if user.effects[PBEffects::Protect] ||
				   user.effects[PBEffects::Obstruct] ||
				   user.effects[PBEffects::KingsShield] || 
				   user.effects[PBEffects::BanefulBunker] ||
				   user.effects[PBEffects::SpikyShield]
					score *=3
				end
			end
			if user.hasActiveAbility?(:SANDVEIL)
				score*=1.3
			end
			if user.pbHasMove?(:MOONLIGHT) || user.pbHasMove?(:SYNTHESIS) || user.pbHasMove?(:MORNINGSUN) ||
			   user.pbHasMove?(:GROWTH) || user.pbHasMove?(:SOLARBEAM) || user.pbHasMove?(:SOLARBLADE)
				score*=0.5
			end
			if user.pbHasMove?(:SHOREUP)
				score*=1.5
			end
			if user.hasActiveAbility?(:SANDFORCE)
				score*=1.5
			end
			score*=(1 + (checkWeatherBenefit(target, globalArray, true) / 100.0))
			score*=(1 + (checkWeatherBenefit(user, globalArray, true, :Sandstorm) / 100.0))
		end
    #---------------------------------------------------------------------------
    when "StartHailWeather" # hail
		if @battle.pbCheckGlobalAbility(:AIRLOCK) ||
		   @battle.pbCheckGlobalAbility(:CLOUDNINE) ||
		   @battle.field.weather == :Hail ||
		   globalArray.include?("hail weather")
			score = 0
		else
			score*=1.6 if user.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
			if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
			   !user.takesHailDamage? && !user.takesSandstormDamage?)
				score*=1.3
			end
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Lead")
				score*=1.2
			end
			if user.hasActiveItem?(:ICYROCK)
				score*=1.3
			end
			if user.pbHasMove?(:WEATHERBALL)
				score*=2
			end
			if @battle.field.weather != :None && @battle.field.weather != :Hail
				score*=1.5
			end
			if user.takesHailDamage?
				score*=0.7
			else
				score*=1.3
			end
			if user.pbHasType?(:ICE, true)
				score*=5 # jeez thats a fat boost
			end
			if user.hasActiveAbility?(:SLUSHRUSH)
				score*=2
				if user.hasActiveItem?(:FOCUSASH)
					score*=2
				end
				# ???? i dont get what this thing does
				if user.effects[PBEffects::Protect] ||
				   user.effects[PBEffects::Obstruct] ||
				   user.effects[PBEffects::KingsShield] || 
				   user.effects[PBEffects::BanefulBunker] ||
				   user.effects[PBEffects::SpikyShield]
					score *=3
				end
			end
			if user.hasActiveAbility?([:SNOWCLOAK, :ICEBODY, :HOTHEADED])
				score*=1.3
			end
			if user.pbHasMove?(:MOONLIGHT) || user.pbHasMove?(:SYNTHESIS) || user.pbHasMove?(:MORNINGSUN) ||
			   user.pbHasMove?(:GROWTH) || user.pbHasMove?(:SOLARBEAM) || user.pbHasMove?(:SOLARBLADE)
				score*=0.5
			end
			if user.pbHasMove?(:AURORAVEIL)
				score*=2
			end
			if user.pbHasMove?(:BLIZZARD)
				score*=1.3
			end
			score*=(1 + (checkWeatherBenefit(target, globalArray, true) / 100.0))
			score*=(1 + (checkWeatherBenefit(user, globalArray, true, :Hail) / 100.0))
		end
    #---------------------------------------------------------------------------
    when "StartElectricTerrain" # Electric Terrain
		sleepvar=false
		sleepvar=true if target.pbHasMoveFunction?("SleepTarget","SleepTargetIfUserDarkrai")
		if @battle.field.terrain == :Electric || globalArray.include?("electric terrain")
			score=0
		else
			miniscore = getFieldDisruptScore(user,target,globalArray,skill)
			if user.hasActiveAbility?(:SURGESURFER)
				miniscore*=1.5
			end
			if user.pbHasType?(:ELECTRIC, true)
				miniscore*=1.5
			end
			elecvar=false
			@battle.pbParty(user.index).each_with_index do |m, i|
				next if m.fainted?
				elecvar=true if m.hasType?(:ELECTRIC)
			end
			if elecvar
				miniscore*=2
			end
			if target.pbHasType?(:ELECTRIC, true)
				miniscore*=0.5
			end
			miniscore*=0.5 if user.pbHasMoveFunction?("SleepTarget","SleepTargetIfUserDarkrai")
			if sleepvar
				miniscore*=2
			end
			if user.hasActiveItem?(:TERRAINEXTENDER)
				miniscore*=2
			end
			score*=miniscore
			score*=(1 + (checkWeatherBenefit(target, globalArray, false, nil, true) / 100.0))
			score*=(1 + (checkWeatherBenefit(user, globalArray, false, nil, true, :Electric) / 100.0))
		end
    #---------------------------------------------------------------------------
    when "StartGrassyTerrain" # grassy terrain
		if @battle.field.terrain == :Grassy || globalArray.include?("grassy terrain")
			score=0
		else
			healvar=false
			for j in target.moves
				healvar=true if j.healingMove?
			end
			grassvar=false
			@battle.pbParty(user.index).each_with_index do |m, i|
				next if m.fainted?
				grassvar=true if m.hasType?(:GRASS)
			end
			roles = pbGetPokemonRole(user, target)
			miniscore = getFieldDisruptScore(user,target,globalArray,skill)
			if roles.include?("Physical Wall") || roles.include?("Special Wall")
				miniscore*=1.5
			end
			if healvar
				miniscore*=0.5
			end
			if user.pbHasType?(:GRASS, true)
				miniscore*=2
			end
			if grassvar
				miniscore*=2
			end
			if user.hasActiveAbility?(:GRASSPELT)
				miniscore*=1.5
			end
			if user.hasActiveItem?(:TERRAINEXTENDER)
				miniscore*=2
			end
			score*=miniscore
			score*=(1 + (checkWeatherBenefit(target, globalArray, false, nil, true) / 100.0))
			score*=(1 + (checkWeatherBenefit(user, globalArray, false, nil, true, :Grassy) / 100.0))
		end
    #---------------------------------------------------------------------------
    when "StartMistyTerrain" # misty terrain
		if @battle.field.terrain == :Misty || globalArray.include?("misty terrain")
			score=0
		else
			healvar=false
			for j in target.moves
				healvar=true if j.healingMove?
			end
			fairyvar=false
			dragovar=false
			@battle.pbParty(user.index).each_with_index do |m, i|
				next if m.fainted?
				fairyvar=true if m.hasType?(:FAIRY)
				dragovar=true if m.hasType?(:DRAGON)
			end
			roles = pbGetPokemonRole(user, target)
			miniscore = getFieldDisruptScore(user,target,globalArray,skill)
			if fairyvar
				miniscore*=2
			end
			if !user.pbHasType?(:FAIRY, true) && target.pbHasType?(:DRAGON, true)
				miniscore*=2
			end
			if user.pbHasType?(:DRAGON, true)
				miniscore*=0.5
			end
			if target.pbHasType?(:FAIRY, true)
				miniscore*=0.5
			end
			if user.pbHasType?(:FAIRY, true) && target.spatk>target.attack
				miniscore*=2
			end
			if user.hasActiveItem?(:TERRAINEXTENDER)
				miniscore*=2
			end
			score*=miniscore
			score*=(1 + (checkWeatherBenefit(target, globalArray, false, nil, true) / 100.0))
			score*=(1 + (checkWeatherBenefit(user, globalArray, false, nil, true, :Misty) / 100.0))
		end
    #---------------------------------------------------------------------------
    when "StartPsychicTerrain" # psychic terrain
		if @battle.field.terrain == :Psychic || globalArray.include?("psychic terrain")
			score=0
		else
			privar=false
			for j in target.moves
				privar=true if j.priority>0
			end
			pricheck=false
			for j in user.moves
				pricheck=true if j.priority>0
			end
			psyvar=false
			@battle.pbParty(user.index).each_with_index do |m, i|
				next if m.fainted?
				psyvar=true if m.hasType?(:PSYCHIC)
			end
			roles = pbGetPokemonRole(user, target)
			miniscore = getFieldDisruptScore(user,target,globalArray,skill)
			if user.hasActiveAbility?(:TELEPATHY)
				miniscore*=1.5
			end  
			if user.pbHasType?(:PSYCHIC, true)
				miniscore*=1.5
			end  
			if psyvar
				miniscore*=2
			end
			if pricheck
				miniscore*=0.7
			end
			if privar
				miniscore*=1.3
			end  
			if user.hasActiveItem?(:TERRAINEXTENDER)
				miniscore*=2
			end
			score*=miniscore
			score*=(1 + (checkWeatherBenefit(target, globalArray, false, nil, true) / 100.0))
			score*=(1 + (checkWeatherBenefit(user, globalArray, false, nil, true, :Psychic) / 100.0))
		end
    #---------------------------------------------------------------------------
    when "RemoveTerrain" # Steel Roller
		miniscore = 100 + getFieldDisruptScore(user,target,globalArray,skill)
		case @battle.field.terrain
		when :None
			score = 0 if globalArray.none? { |element| element.include?("terrain") }
		when :Electric
			if target.hasActiveAbility?(:SURGESURFER)
				miniscore*=1.5
			end
			if target.pbHasType?(:ELECTRIC, true)
				miniscore*=1.5
			end
			elecvar=false
			@battle.pbParty(target.index).each_with_index do |m, i|
				next if m.fainted?
				elecvar=true if m.hasType?(:ELECTRIC)
			end
			if elecvar
				miniscore*=2
			end
			if user.pbHasType?(:ELECTRIC, true)
				miniscore*=0.5
			end
			miniscore*=0.5 if target.pbHasMoveFunction?("SleepTarget","SleepTargetIfUserDarkrai")
			miniscore*=2 if user.pbHasMoveFunction?("SleepTarget","SleepTargetIfUserDarkrai")
			if target.hasActiveItem?(:TERRAINEXTENDER)
				miniscore*=1.2
			end
			score*=miniscore
		when :Grassy
			healvar=false
			for j in target.moves
				healvar=true if j.healingMove?
			end
			grassvar=false
			@battle.pbParty(target.index).each_with_index do |m, i|
				next if m.fainted?
				grassvar=true if m.hasType?(:GRASS)
			end
			oroles = pbGetPokemonRole(target, user)
			if oroles.include?("Physical Wall") || oroles.include?("Special Wall")
				miniscore*=1.5
			end
			if healvar
				miniscore*=0.5
			end
			if target.pbHasType?(:GRASS, true)
				miniscore*=2
			end
			if grassvar
				miniscore*=2
			end
			if target.hasActiveAbility?(:GRASSPELT)
				miniscore*=1.5
			end
			if target.hasActiveItem?(:TERRAINEXTENDER)
				miniscore*=1.2
			end
			score*=miniscore
		when :Misty
			healvar=false
			for j in user.moves
				healvar=true if j.healingMove?
			end
			fairyvar=false
			dragovar=false
			@battle.pbParty(target.index).each_with_index do |m, i|
				next if m.fainted?
				fairyvar=true if m.hasType?(:FAIRY)
				dragovar=true if m.hasType?(:DRAGON)
			end
			if fairyvar
				miniscore*=2
			end
			if !target.pbHasType?(:FAIRY, true) && user.pbHasType?(:DRAGON, true)
				miniscore*=2
			end
			if target.pbHasType?(:DRAGON, true)
				miniscore*=0.5
			end
			if user.pbHasType?(:FAIRY, true)
				miniscore*=0.5
			end
			if target.pbHasType?(:FAIRY, true) && user.spatk>user.attack
				miniscore*=2
			end
			if target.hasActiveItem?(:TERRAINEXTENDER)
				miniscore*=1.2
			end
			score*=miniscore
		when :Psychic
			privar=false
			for j in user.moves
				privar=true if j.priority>0
			end
			pricheck=false
			for j in target.moves
				pricheck=true if j.priority>0
			end
			psyvar=false
			@battle.pbParty(target.index).each_with_index do |m, i|
				next if m.fainted?
				psyvar=true if m.hasType?(:PSYCHIC)
			end
			if target.hasActiveAbility?(:TELEPATHY)
				miniscore*=1.5
			end  
			if target.pbHasType?(:PSYCHIC, true)
				miniscore*=1.5
			end  
			if psyvar
				miniscore*=2
			end
			if pricheck
				miniscore*=0.7
			end
			if privar
				miniscore*=1.3
			end  
			if target.hasActiveItem?(:TERRAINEXTENDER)
				miniscore*=1.2
			end
		end
		miniscore/=100.0
		score*=miniscore
    #---------------------------------------------------------------------------
    when "AddSpikesToFoeSide" # spikes
		if user.pbOpposingSide.effects[PBEffects::Spikes] >= 3
			score = 0
		else
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Lead")
				score*=1.1
			end
			if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
			   !user.takesHailDamage? && !user.takesSandstormDamage?)
				score*=1.1
			end
			if user.turnCount<2
				score*=1.2
			end
			userlivecount   = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			targetlivecount = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if targetlivecount>3
				miniscore=(targetlivecount-1)
				miniscore*=0.2
				score*=miniscore
			else
				score*=0.1
			end
			if user.pbOpposingSide.effects[PBEffects::Spikes]>0
				score*=0.9
			end
			score*=0.3 if pbHasHazardCleaningMove?(target)
		end
	#---------------------------------------------------------------------------
    when "AddToxicSpikesToFoeSide" # toxic spikes
		if user.pbOpposingSide.effects[PBEffects::ToxicSpikes] >= 2
			score = 0
		else
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Lead")
				score*=1.1
			end
			if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
			   !user.takesHailDamage? && !user.takesSandstormDamage?)
				score*=1.1
			end
			if user.turnCount<2
				score*=1.2
			end
			userlivecount   = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			targetlivecount = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if targetlivecount>3
				miniscore=(targetlivecount-1)
				miniscore*=0.2
				score*=miniscore
			else
				score*=0.1
			end
			if user.pbOpposingSide.effects[PBEffects::ToxicSpikes]>0
				score*=0.9
			end
			score*=0.7 if pbHasHazardCleaningMove?(target)
		end
    #---------------------------------------------------------------------------
    when "AddStealthRocksToFoeSide" # stealth rock
		if user.pbOpposingSide.effects[PBEffects::StealthRock]
			score = 0
		else
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Lead")
				score*=1.1
			end
			if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
			   !user.takesHailDamage? && !user.takesSandstormDamage?)
				score*=1.1
			end
			if user.turnCount<2
				score*=1.2
			end
			userlivecount   = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			targetlivecount = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if targetlivecount>3
				miniscore=(targetlivecount-1)
				miniscore*=0.2
				score*=miniscore
			else
				score*=0.1
			end
			score*=0.7 if pbHasHazardCleaningMove?(target)
		end
    #---------------------------------------------------------------------------
    when "AddStickyWebToFoeSide" # Sticky Web
		if user.pbOpposingSide.effects[PBEffects::StickyWeb] > 1
			score = 0
		else
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Lead")
				score*=1.1
			end
			if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
			   !user.takesHailDamage? && !user.takesSandstormDamage?)
				score*=1.1
			end
			if user.turnCount<2
				score*=1.2
			end
			userlivecount   = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			targetlivecount = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if targetlivecount>3
				miniscore=(targetlivecount-1)
				miniscore*=0.2
				score*=miniscore
			else
				score*=0.1
			end
			if user.pbOpposingSide.effects[PBEffects::StickyWeb]>0
				score*=0.9
			end
			score*=0.7 if pbHasHazardCleaningMove?(target)
		end
    #---------------------------------------------------------------------------
    when "SwapSideEffects"
      if skill >= PBTrainerAI.mediumSkill
        good_effects = [:Reflect, :LightScreen, :AuroraVeil, :SeaOfFire,
                        :Swamp, :Rainbow, :Mist, :Safeguard,
                        :Tailwind].map! { |e| PBEffects.const_get(e) }
        bad_effects = [:Spikes, :StickyWeb, :ToxicSpikes, :StealthRock].map! { |e| PBEffects.const_get(e) }
        bad_effects.each do |e|
          score += 10 if ![0, false, nil].include?(user.pbOwnSide.effects[e])
          score -= 10 if ![0, 1, false, nil].include?(user.pbOpposingSide.effects[e])
        end
        if skill >= PBTrainerAI.highSkill
          good_effects.each do |e|
            score += 10 if ![0, 1, false, nil].include?(user.pbOpposingSide.effects[e])
            score -= 10 if ![0, false, nil].include?(user.pbOwnSide.effects[e])
          end
        end
      end
    #---------------------------------------------------------------------------
    when "UserMakeSubstitute" # substitute
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam = bestmove[0]
		maxprio = bestmove[2]
		if user.hp*4 > user.totalhp && maxprio < user.hp
			if user.effects[PBEffects::Substitute] > 0	
				if userFasterThanTarget
					score = 0
				else
					if target.effects[PBEffects::LeechSeed]<0
						score=0
					end
				end
			else
				if user.hp==user.totalhp
					score*=1.1
				else
					score*= (user.hp*(1.0/user.totalhp))
				end
				if target.effects[PBEffects::LeechSeed]>=0
					score*=1.2
				end
				if user.hasActiveItem?(:LEFTOVERS)
					score*=1.2
				end 
				for j in user.moves
					if j.healingMove?
						score*=1.2
						break
					end
				end
				if target.pbHasMove?(:SPORE) || target.pbHasMove?(:SLEEPPOWDER)
					score*=1.2
				end
				if user.pbHasMove?(:FOCUSPUNCH)
					score*=1.5
				end
				if target.asleep?
					score*=1.5
				end
				if target.hasActiveAbility?(:INFILTRATOR)
					score*=0.3
				end
				movecheck=false
				for m in target.moves
					movecheck=true if m.ignoresSubstitute?(target)
				end
				score*=0.3 if movecheck
				if maxdam*4<user.totalhp
					score*=2
				end
				if target.effects[PBEffects::Confusion]>0
					score*=1.3
				end
				if target.paralyzed?
					score*=1.3
				end            
				if target.effects[PBEffects::Attract]>=0
					score*=1.3
				end 
				if user.pbHasMove?(:BATONPASS)
					score*=1.2
				end
				if user.hasActiveAbility?(:SPEEDBOOST)
					score*=1.1
				end
				hasAlly = !target.allAllies.empty?
				if hasAlly
					score*=0.7
				end
			end
		else
			score = 0
		end
    #---------------------------------------------------------------------------
    when "RemoveUserBindingAndEntryHazards" # rapid spin
		score *= 1.2 if user.effects[PBEffects::Trapping] > 0
		score *= 1.2 if user.effects[PBEffects::LeechSeed] >= 0
		if @battle.pbAbleNonActiveCount(user.idxOwnSide) > 0
			score *= 1.2 if user.pbOwnSide.effects[PBEffects::Spikes] > 0
			score *= 1.7 if user.pbOwnSide.effects[PBEffects::StickyWeb] > 0
			score *= 1.3 if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
			score *= 1.3 if user.pbOwnSide.effects[PBEffects::StealthRock]
		end
		if (user.effects[PBEffects::Trapping] > 0 || 
		   user.effects[PBEffects::LeechSeed] >= 0 ||
		   user.pbOwnSide.effects[PBEffects::Spikes] > 0 || 
		   user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0 ||
		   user.pbOwnSide.effects[PBEffects::StealthRock] || 
		   user.pbOwnSide.effects[PBEffects::StickyWeb] > 0) && !user.SetupMovesUsed.include?(move.id)
			miniscore = 100
			miniscore*=2 if user.hasActiveAbility?(:SIMPLE)
			if user.attack<user.spatk
				if user.stages[:SPECIAL_ATTACK]<0            
					ministat=user.stages[:SPECIAL_ATTACK]
					minimini=5*ministat
					minimini+=100
					minimini/=100.0
					miniscore*=minimini
				end
			else
				if user.stages[:ATTACK]<0            
					ministat=user.stages[:ATTACK]
					minimini=5*ministat
					minimini+=100
					minimini/=100.0
					miniscore*=minimini
				end
			end
			ministat=0
			ministat+=target.stages[:DEFENSE]
			ministat+=target.stages[:SPECIAL_DEFENSE]
			if ministat>0
				minimini=(-5)*ministat
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
			if userFasterThanTarget
				miniscore*=0.3
				targetlivecount=@battle.pbAbleNonActiveCount(user.idxOpposingSide)
				if targetlivecount==1
					miniscore*=0.1
				end          
			end
			sweepvar = false
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Sweeper")
				sweepvar = true
			end
			score*=1.5 if sweepvar
			if @battle.field.effects[PBEffects::TrickRoom]!=0
				miniscore*=0.2
			else
				@battle.pbParty(target.index).each do |i|
					next if i.nil?
					next if i.fainted?
					for z in i.moves
						if z.id == :TRICKROOM
							miniscore*=0.5
						end
					end
				end
				for i in target.moves
					miniscore*=0.2 if i.id == :TRICKROOM
				end
        	end
			if user.paralyzed?
				miniscore*=0.2
			end
			privar = false
			for i in target.moves
				if i.priority>0
					privar=true
					break
				end
			end
			miniscore*=0.6 if privar
			if target.hasActiveAbility?(:SPEEDBOOST)
				miniscore*=0.6
			end
			if user.hasActiveAbility?(:MOXIE)
				miniscore*=1.3
			end
			miniscore*=0.3 if target.pbHasMoveFunction?("ResetAllBattlersStatStages","ResetTargetStatStages")
			miniscore/=100.0
			miniscore=0 if user.statStageAtMax?(:SPEED)
			miniscore=0 if user.hasActiveAbility?(:CONTRARY)
			miniscore=1 if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			score*=miniscore 
		end
    #---------------------------------------------------------------------------
    when "AttackTwoTurnsLater" # future sight
		if @battle.positions[target.index].effects[PBEffects::FutureSightCounter]>0
			score*=0
		else
			score*=0.7
			hasAlly = !target.allAllies.empty?
			if hasAlly
				score*=0.7
			end          
			if @battle.pbAbleNonActiveCount(user.idxOwnSide)==0
				score*=0.7
			end
			if user.effects[PBEffects::Substitute]>0
				score*=1.2
			end
			if pbHasSingleTargetProtectMove?(user)
				score*=1.2
			end
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Physical Wall") || roles.include?("Special Wall")
				score*=1.1
			end
			if user.hasActiveAbility?(:MOODY) || user.pbHasMove?(:QUIVERDANCE) || 
			   user.pbHasMove?(:NASTYPLOT) || user.pbHasMove?(:TAILGLOW)
				score*=1.2
			end
		end
    #---------------------------------------------------------------------------
    when "UserSwapsPositionsWithAlly" # ally switch
		userlivecount   = @battle.pbAbleNonActiveCount(user.idxOwnSide)
		hasAlly = !user.allAllies.empty?
		bestmove = bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam = bestmove[0]
		if maxdam<user.hp && userlivecount!=0 && hasAlly
			score*=1.3
			sweepvar = false
			count=0
			@battle.pbParty(user.index).each do |i|
				next if i.nil?
				count+=1
				temproles = pbGetPokemonRole(i, target, count, @battle.pbParty(user.index))
				if temproles.include?("Sweeper")
					sweepvar = true
				end
			end
			score*=2 if sweepvar
			score*=2 if userlivecount<3
		else
			score*=0
		end
    #---------------------------------------------------------------------------
    when "BurnAttackerBeforeUserActs" # beak blast
		startscore = score
		maxdam = 0
		contactcheck = false
		facadecheck = false
		restcheck = false
		for m in target.moves
			tempdam = pbRoughDamage(m, user, target, skill, m.baseDamage)
			if tempdam > maxdam
				maxdam = tempdam
				if m.pbContactMove?(user)
					contactcheck=true
				else
					contactcheck=false
				end
			end
			facadecheck = true if m.id == :FACADE
			restcheck = true if m.id == :REST
		end
		if user.pbCanBurn?(target, false)
			miniscore = pbTargetBenefitsFromStatus?(user, target, :BURN, 100, move, globalArray, skill)
			miniscore *= 1.2
			ministat=0
			ministat+=target.stages[:ATTACK]
			ministat+=target.stages[:SPECIAL_ATTACK]
			ministat+=target.stages[:SPEED]
			if ministat>0
				minimini=5*ministat
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end 
			if move.baseDamage>0
				if target.hasActiveAbility?(:STURDY)
					miniscore*=1.1
				end
			end
			miniscore-=100
			miniscore*=(move.addlEffect.to_f/100.0)
			if user.hasActiveAbility?(:SERENEGRACE) && 
				((@battle.field.terrain == :Misty || globalArray.include?("misty terrain")) && 
					!target.affectedByTerrain?)
				miniscore*=2
			end
			miniscore+=100
			miniscore/=100.0
			if startscore==110
				miniscore*=0.8
			end
			minimini = 100
			if contactcheck
				minimini*=1.5
			else
				if target.attack>target.spatk
					minimini*=1.3
				else
					minimini*=0.3
				end
			end
			minimini/=100.0
			miniscore*=minimini
			score*=miniscore
		end
		if userFasterThanTarget
			score*=0.7
		end
    #---------------------------------------------------------------------------
    when "RaiseUserAttack1", "RaiseUserAttack2", "RaiseUserAttack3", "RaiseTargetAttack1" # Howl
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end    
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		if hasAlly && move.baseDamage == 0
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.burned?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :FOULPLAY
		end
		miniscore*=0.3 if movecheck
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end
			end   
			miniscore+=100
			miniscore/=100.0          
			if user.statStageAtMax?(:ATTACK) 
				miniscore=1
			end       
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
		else
			miniscore*=0.5 if (move.function == "RaiseUserAttack1" || move.function == "RaiseTargetAttack1") && 
							   user.level >= 20
			miniscore/=100.0
			if user.statStageAtMax?(:ATTACK)
				miniscore=0
			end
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end            
		end
		miniscore=1 if move.baseDamage>0 && move.addlEffect.to_f == 100 && 
					   user.SetupMovesUsed.include?(move.id)
		score*=miniscore
		if move.baseDamage==0
			physmove=false
			for j in user.moves
				if j.physicalMove?(j.type)
					physmove=true
				end
			end    
			score=0 if !physmove
		end
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
	#---------------------------------------------------------------------------
    when "MaxUserAttackLoseHalfOfTotalHP" # Belly Drum
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end  
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.burned?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :FOULPLAY
		end
		miniscore*=0.3 if movecheck
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
		   !user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.1 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		miniscore/=100.0
		if user.statStageAtMax?(:ATTACK)
			miniscore=0
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end
		score*=miniscore
		if move.baseDamage==0
			physmove=false
			for j in user.moves
				if j.physicalMove?(j.type)
					physmove=true
				end
			end    
			score=0 if !physmove
		end
		score *= 0.2 if user.SetupMovesUsed.include?(move.id)
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserDefense1", "RaiseUserDefense1CurlUpUser" # Harden
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:DEFENSE]>0
			ministat=user.stages[:DEFENSE]
			minimini=-15*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		if pbRoughStat(target,:ATTACK,skill)>pbRoughStat(target,:SPECIAL_ATTACK,skill)
			miniscore*=1.3
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if (maxdam.to_f/user.hp)<0.12
			miniscore*=0.3
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Physical Wall") || roles.include?("Special Wall")
			miniscore*=1.3
		end
		if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
			miniscore*=1.2
		end
		healmove=false
		for j in user.moves
			healmove=true if j.healingMove?
		end
		miniscore*=1.3 if healmove
		if user.pbHasMove?(:LEECHSEED)
			miniscore*=1.3
		end
		if user.pbHasMove?(:PAINSPLIT)
			miniscore*=1.2
		end        
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end    
			miniscore+=100
			miniscore/=100.0          
			if user.statStageAtMax?(:DEFENSE) 
				miniscore=1
			end       
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
		else
			miniscore/=100.0
			if user.statStageAtMax?(:DEFENSE)
				miniscore=0
			end
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end
		end
		score*=miniscore
		mechanicver = ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
		if move.function == "RaiseUserDefense1CurlUpUser"
			if !user.effects[PBEffects::DefenseCurl]
				movecheck = user.moves.any? { |m| [:ROLLOUT, :ICEBALL].include?(m.id) }
				if movecheck && miniscore>10
					score *= 1.2
					score *= 1.2 if userFasterThanTarget
				end
			else
				score = 0 if mechanicver
			end
		else
			score = 0 if mechanicver
		end
    #---------------------------------------------------------------------------
    when "RaiseUserDefense2", "RaiseUserDefense3" # Iron Defense
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.1
		end
		if target.pbHasAnyStatus?
			miniscore*=1.1
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.5
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.3
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.2
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.5
		end
		if user.stages[:DEFENSE]>0
			ministat=user.stages[:DEFENSE]
			minimini=-15*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		if pbRoughStat(target,:ATTACK,skill)>pbRoughStat(target,:SPECIAL_ATTACK,skill)
			miniscore*=1.3
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if (maxdam.to_f/user.hp)<0.12
			miniscore*=0.3
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Physical Wall") || roles.include?("Special Wall")
			miniscore*=1.3
		end
		if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
			miniscore*=1.2
		end
		healmove=false
		for j in user.moves
			healmove=true if j.healingMove?
		end
		miniscore*=1.3 if healmove
		if user.pbHasMove?(:LEECHSEED)
			miniscore*=1.3
		end
		if user.pbHasMove?(:PAINSPLIT)
			miniscore*=1.2
		end        
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end    
			miniscore+=100
			miniscore/=100.0          
			if user.statStageAtMax?(:DEFENSE) 
				miniscore=1
			end       
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
		else
			miniscore/=100.0
			if user.statStageAtMax?(:DEFENSE)
				miniscore=0
			end
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end
		end
		score*=miniscore
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserSpAtk1" # Charge Beam
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly && move.baseDamage == 0
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.frozen?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST,false,mold_broken)
			miniscore*=0.6
		end
		miniscore*=0.5 if user.level >= 20 && move.statusMove?
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end   
			miniscore+=100
			miniscore/=100.0          
			if user.statStageAtMax?(:SPECIAL_ATTACK) 
				miniscore=1
			end       
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
		else
			miniscore/=100.0
			if user.statStageAtMax?(:SPECIAL_ATTACK)
				miniscore=0
			end
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end            
		end
		miniscore=1 if move.baseDamage>0 && move.addlEffect.to_f == 100 && 
					   user.SetupMovesUsed.include?(move.id)
		score*=miniscore
		if move.baseDamage==0
			specmove=false
			for j in user.moves
				if j.specialMove?(j.type)
					specmove=true
				end
			end    
			score=0 if !specmove
		end
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserSpAtk2", "RaiseUserSpAtk3" # Nasty Plot
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.frozen?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		miniscore/=100.0
		if user.statStageAtMax?(:SPECIAL_ATTACK)
			miniscore=0
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end
		score*=miniscore
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserSpDef1", "RaiseUserSpDef1PowerUpElectricMove" # Charge
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPECIAL_DEFENSE]>0
			ministat=user.stages[:SPECIAL_DEFENSE]
			minimini=-15*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		if pbRoughStat(target,:ATTACK,skill)<pbRoughStat(target,:SPECIAL_ATTACK,skill)
			miniscore*=1.3
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if (maxdam.to_f/user.hp)<0.12
			miniscore*=0.3
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Physical Wall") || roles.include?("Special Wall")
			miniscore*=1.3
		end
		if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
			miniscore*=1.2
		end
		healmove=false
		for j in user.moves
			healmove=true if j.healingMove?
		end
		miniscore*=1.3 if healmove
		if user.pbHasMove?(:LEECHSEED)
			miniscore*=1.3
		end
		if user.pbHasMove?(:PAINSPLIT)
			miniscore*=1.2
		end        
		if move.function == "RaiseUserSpDef1PowerUpElectricMove"
			elecmove=false
			for j in user.moves
				if j.type == :ELECTRIC
					if j.baseDamage>0
						elecmove=true
					end            
				end
			end
			if elecmove && user.effects[PBEffects::Charge]==0
				miniscore*=1.5
			end
		end
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end    
			miniscore+=100
			miniscore/=100.0          
			if user.statStageAtMax?(:SPECIAL_DEFENSE) 
				miniscore=1
			end       
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
		else
			miniscore/=100.0
			if user.statStageAtMax?(:SPECIAL_DEFENSE)
				miniscore=0
			end
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end
		end
		score*=miniscore
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
	when "RaiseUserSpDef2", "RaiseUserSpDef3" # Amnesia
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPECIAL_DEFENSE]>0
			ministat=user.stages[:SPECIAL_DEFENSE]
			minimini=-15*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		if pbRoughStat(target,:ATTACK,skill)<pbRoughStat(target,:SPECIAL_ATTACK,skill)
			miniscore*=1.3
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if (maxdam.to_f/user.hp)<0.12
			miniscore*=0.3
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Physical Wall") || roles.include?("Special Wall")
			miniscore*=1.3
		end
		if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
			miniscore*=1.2
		end
		healmove=false
		for j in user.moves
			healmove=true if j.healingMove?
		end
		miniscore*=1.3 if healmove
		if user.pbHasMove?(:LEECHSEED)
			miniscore*=1.3
		end
		if user.pbHasMove?(:PAINSPLIT)
			miniscore*=1.2
		end        
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end    
			miniscore+=100
			miniscore/=100.0          
			if user.statStageAtMax?(:SPECIAL_DEFENSE) 
				miniscore=1
			end       
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
		else
			miniscore/=100.0
			if user.statStageAtMax?(:SPECIAL_DEFENSE)
				miniscore=0
			end
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end
		end
		score*=miniscore
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserSpeed1", "TypeDependsOnUserMorpekoFormRaiseUserSpeed1" # Flame Charge
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.attack<user.spatk
			if user.stages[:SPECIAL_ATTACK]<0            
				ministat=user.stages[:SPECIAL_ATTACK]
				minimini=5*ministat
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
		else
			if user.stages[:ATTACK]<0            
				ministat=user.stages[:ATTACK]
				minimini=5*ministat
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
		end
		ministat=0
		ministat+=target.stages[:DEFENSE]
		ministat+=target.stages[:SPECIAL_DEFENSE]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if @battle.field.effects[PBEffects::TrickRoom]!=0
			miniscore*=0.1
		else
			trickrooom = false
			for j in target.moves
				if j.id == :TRICKROOM
					trickrooom = true
					break
				end
			end
			miniscore*=0.1 if trickrooom
		end
		if user.paralyzed?
			miniscore*=0.2
		end      
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)  
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end  
		miniscore*=0.6 if movecheck    
		if user.hasActiveAbility?(:MOXIE)
			miniscore*=1.3
		end        
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end   
			miniscore+=100
			miniscore/=100.0          
			if user.statStageAtMax?(:SPEED) 
				miniscore=1
			end       
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
		else          
			if target.hasActiveAbility?(:SPEEDBOOST)
				miniscore*=0.6
			end
			miniscore/=100.0
			if user.statStageAtMax?(:SPEED)
				miniscore=0
			end
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end
		end
		score*=miniscore
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserSpeed2", "RaiseUserSpeed2LowerUserWeight", "RaiseUserSpeed3" # Agility
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.attack<user.spatk
			if user.stages[:SPECIAL_ATTACK]<0            
				ministat=user.stages[:SPECIAL_ATTACK]
				minimini=5*ministat
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
		else
			if user.stages[:ATTACK]<0            
				ministat=user.stages[:ATTACK]
				minimini=5*ministat
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
		end
		ministat=0
		ministat+=target.stages[:DEFENSE]
		ministat+=target.stages[:SPECIAL_DEFENSE]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		if userFasterThanTarget
			miniscore*=0.3
			targetlivecount=@battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if targetlivecount<=1
				miniscore*=0.1
			end          
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if @battle.field.effects[PBEffects::TrickRoom]!=0
			miniscore*=0.1
		else
			trickrooom = false
			for j in target.moves
				if j.id == :TRICKROOM
					trickrooom = true
					break
				end
			end
			miniscore*=0.1 if trickrooom
		end
		if user.paralyzed?
			miniscore*=0.2
		end      
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)  
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end  
		miniscore*=0.6 if movecheck    
		if user.hasActiveAbility?(:MOXIE)
			miniscore*=1.3
		end        
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end   
			miniscore+=100
			miniscore/=100.0          
			if user.statStageAtMax?(:SPEED) 
				miniscore=1
			end       
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
		else          
			if target.hasActiveAbility?(:SPEEDBOOST)
				miniscore*=0.6
			end
			miniscore/=100.0
			if user.statStageAtMax?(:SPEED)
				miniscore=0
			end
			if move.function == "RaiseUserSpeed2LowerUserWeight" # Autotomize
				movecheck=false
				for m in target.moves
					movecheck=true if m.id == :LOWKICK || m.id == :GRASSKNOT 
				end
				miniscore*=1.5 if movecheck
				movecheck=false
				for m in target.moves
					movecheck=true if m.id == :HEATCRASH || m.id == :HEAVYSLAM 
				end
				miniscore*=0.5 if movecheck
				if user.pbHasMove?(:HEATCRASH) || user.pbHasMove?(:HEAVYSLAM)
					miniscore*=0.8
				end
			end
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end
		end
		score*=miniscore
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserAccuracy1", "RaiseUserAccuracy2", "RaiseUserAccuracy3"
		if move.statusMove?
			if user.statStageAtMax?(:ACCURACY) || ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
				score -= 90
			else
				score += 40 if user.turnCount == 0
				score -= user.stages[:ACCURACY] * 20
			end
		else
			score += 10 if user.turnCount == 0
			score += 20 if user.stages[:ACCURACY] < 0
		end
    #---------------------------------------------------------------------------
    when "RaiseUserEvasion1", "RaiseUserEvasion2", "RaiseUserEvasion2MinimizeUser", "RaiseUserEvasion3"
		score = 0
    #---------------------------------------------------------------------------
    when "RaiseUserCriticalHitRate2" # Focus Energy
		if user.effects[PBEffects::FocusEnergy] < 2
			miniscore=100        
			if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
				miniscore*=1.3
			end
			hasAlly = !target.allAllies.empty?
			if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
				miniscore*=2
			end
			if (user.hp.to_f)/user.totalhp>0.75
				miniscore*=1.2
			end
			if (user.hp.to_f)/user.totalhp<0.33
				miniscore*=0.3
			end
			if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
				miniscore*=0.3
			end
			if target.effects[PBEffects::HyperBeam]>0
				miniscore*=1.3
			end
			if target.effects[PBEffects::Yawn]>0
				miniscore*=1.7
			end
			bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
			maxdam=bestmove[0]
			if maxdam<(user.hp/4.0)
				miniscore*=1.2
			else
				if move.baseDamage==0 
					miniscore*=0.8
					if maxdam>user.hp
						miniscore*=0.1
					end
				end              
			end
			if user.turnCount<2
				miniscore*=1.2
			end
			if target.pbHasAnyStatus?
				miniscore*=1.2
			end
			if target.asleep?
				miniscore*=1.3
			end
			if target.effects[PBEffects::Encore]>0
				if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
					miniscore*=1.5
				end          
			end
			if user.effects[PBEffects::Confusion]>0
				miniscore*=0.2
			end
			if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
				miniscore*=0.6
			end
			if pbHasPhazingMove?(target)
				miniscore*=0.5
			end
			hasAlly = !target.allAllies.empty?
			if hasAlly
				miniscore*=0.7
			end
			if user.hasActiveAbility?([:SUPERLUCK, :SNIPER])
				miniscore*=2
			end
			if user.hasActiveItem?([:SCOPELENS, :RAZORCLAW]) #|| (user.hasActiveItem?(:STICK) && user.species==83) || (user.hasActiveItem?(:LUCKYPUNCH) && user.species==113)
				miniscore*=1.2
			end
			if user.hasActiveItem?(:LANSATBERRY)
				miniscore*=1.3
			end
			if target.hasActiveAbility?([:ANGERPOINT, :SHELLARMOR, :BATTLEARMOR],false,mold_broken)
				miniscore*=0.2
			end
			if user.pbHasMoveFunction?("AlwaysCriticalHit","HitThreeTimesAlwaysCriticalHit","EnsureNextCriticalHit")
				miniscore*=0.5
			end
			for j in user.moves
				if j.highCriticalRate?
					miniscore*=2
				end
			end
			miniscore/=100.0
			score*=miniscore
		else
			score = 0
		end
    #---------------------------------------------------------------------------
    when "RaiseUserAtkDef1" # Bulk Up
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.burned?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :FOULPLAY
		end
		miniscore*=0.3 if movecheck
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
		   !user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end   
			miniscore+=100
			miniscore/=100.0
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
			if !user.statStageAtMax?(:ATTACK)
				miniscore/=100.0
				score*=miniscore
			end
		else
			miniscore/=100.0
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end            
			physmove=false
			for j in user.moves
				if j.physicalMove?(j.type)
					physmove=true
				end
			end    
			if physmove && !user.statStageAtMax?(:ATTACK)
				miniscore/=100.0
				score*=miniscore
			end
		end
		roles = pbGetPokemonRole(user, target)
		if pbRoughStat(target,:SPECIAL_ATTACK,skill)<pbRoughStat(target,:ATTACK,skill)
			if !(roles.include?("Physical Wall") || roles.include?("Special Wall"))
				if userFasterThanTarget && (user.hp.to_f)/user.totalhp>0.75
					miniscore*=1.3
				elsif !userFasterThanTarget
					miniscore*=0.7
				end
			end
			miniscore*=1.3
		end
		if roles.include?("Physical Wall") || roles.include?("Special Wall")
			miniscore*=1.3
		end
		if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
			miniscore*=1.2
		end
		healmove=false
		for j in user.moves
			healmove=true if j.healingMove?
		end
		miniscore*=1.3 if healmove
		if user.pbHasMove?(:LEECHSEED)
			miniscore*=1.3
		end
		if user.pbHasMove?(:PAINSPLIT)
			miniscore*=1.2
		end        
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end    
			miniscore+=100
			miniscore/=100.0
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
		else
			miniscore/=100.0
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end
		end
		if !user.statStageAtMax?(:DEFENSE)
			score*=miniscore
		end
		score =0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserAtkDefAcc1" # Coil
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.burned?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :FOULPLAY
		end
		miniscore*=0.3 if movecheck
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end   
			miniscore+=100
			miniscore/=100.0
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
			if !user.statStageAtMax?(:ATTACK)
				score*=miniscore
			end
		else
			miniscore/=100.0
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end            
			physmove=false
			for j in user.moves
				if j.physicalMove?(j.type)
					physmove=true
				end
			end    
			if physmove && !user.statStageAtMax?(:ATTACK)
				score*=miniscore
			end
		end
		roles = pbGetPokemonRole(user, target)
		if pbRoughStat(target,:SPECIAL_ATTACK,skill)<pbRoughStat(target,:ATTACK,skill)
			if !(roles.include?("Physical Wall") || roles.include?("Special Wall"))
				if userFasterThanTarget && (user.hp.to_f)/user.totalhp>0.75
					miniscore*=1.3
				elsif !userFasterThanTarget
					miniscore*=0.7
				end
			end
			miniscore*=1.3
		end
		if roles.include?("Physical Wall") || roles.include?("Special Wall")
			miniscore*=1.3
		end
		if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
			miniscore*=1.2
		end
		healmove=false
		for j in user.moves
			healmove=true if j.healingMove?
		end
		miniscore*=1.3 if healmove
		if user.pbHasMove?(:LEECHSEED)
			miniscore*=1.3
		end
		if user.pbHasMove?(:PAINSPLIT)
			miniscore*=1.2
		end
		weakermove=false
		for j in user.moves
			if j.baseDamage<95
				weakermove=true
			end
		end
		if weakermove
			miniscore*=1.1
		end       
		if target.stages[:EVASION]>0
			ministat=target.stages[:EVASION]
			minimini=5*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		#if target.hasActiveItem?(:BRIGHTPOWDER) || target.hasActiveItem?(:LAXINCENSE) || 
		#	(target.hasActiveAbility?(:SANDVEIL) && target.effectiveWeather == :Sandstorm) ||
		#	(target.hasActiveAbility?(:SNOWCLOAK) && target.effectiveWeather == :Hail)
		#	miniscore*=1.1
		#end
		if move.baseDamage>0
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end    
			miniscore+=100
			miniscore/=100.0
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0.5
			end          
		else
			miniscore/=100.0
			movecheck=false
			for m in target.moves
				movecheck=true if m.id == :CLEARSMOG
				movecheck=true if m.id == :HAZE
			end
			miniscore*=0 if movecheck
			if user.hasActiveAbility?(:CONTRARY)
				miniscore*=0
			end            
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end
		end
		if !user.statStageAtMax?(:ACCURACY)
			score*=miniscore
		end
		score = 0 if user.statStageAtMax?(:ACCURACY) && user.statStageAtMax?(:ATTACK) && user.statStageAtMax?(:DEFENSE)
		score = 0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserAtkSpAtk1" # Work Up
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.burned? || user.frozen?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :FOULPLAY
		end
		miniscore*=0.3 if movecheck
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		miniscore*=0.5 if user.level >= 26
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end
		physmove=false
		specmove=false
		for j in user.moves
			if j.physicalMove?(j.type)
				physmove=true
			end
			if j.specialMove?(j.type)
				specmove=true
			end
		end    
		if (physmove && !user.statStageAtMax?(:ATTACK)) ||
		   (specmove && !user.statStageAtMax?(:SPECIAL_ATTACK))
			miniscore/=100.0
			score*=miniscore
		end
		score = 0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
	when "RaiseUserAtkSpAtk1Or2InSun" # Growth
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end     
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep? || target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.burned? || user.frozen?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :FOULPLAY
		end
		miniscore*=0.3 if movecheck
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0.7 if movecheck
		if ([:Sun, :HarshSun].include?(user.effectiveWeather) || 
			 globalArray.include?("sun weather") || 
			 user.hasActiveAbility?(:PRESAGE))
			miniscore*=2
		else
			miniscore*=0.5
		end
		miniscore/=100.0
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end
		physmove=false
		specmove=false
		for j in user.moves
			if j.physicalMove?(j.type)
				physmove=true
			end
			if j.specialMove?(j.type)
				specmove=true
			end
		end
		if (physmove && !user.statStageAtMax?(:ATTACK)) ||
		   (specmove && !user.statStageAtMax?(:SPECIAL_ATTACK))
			score*=miniscore
		end
		score = 0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "LowerUserDefSpDef1RaiseUserAtkSpAtkSpd2" # shell smash
		miniscore=100
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.3
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.3
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.5
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0      
				miniscore*=1.5
			end          
		end  
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.1
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.3
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		movecheck=false
		for j in target.moves
			movecheck=true if j.healingMove?
		end  
		miniscore*=1.3 if movecheck    
		if (aspeed<=ospeed && @battle.field.effects[PBEffects::TrickRoom]!=0) 
			miniscore*=1.3
		end    
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.5
		end
		specmove=false
		for j in user.moves
			if j.specialMove?(j.type)
				specmove=true
			end
		end    
		if user.burned? && !specmove
			miniscore*=0.5
		end
		if user.frozen? && specmove
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.5
		end
		privar = false
		for m in target.moves
			privar = true if m.priority > 0
		end
		miniscore*=0.2 if privar
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		miniscore/=100.0
		score*=miniscore
		miniscore=100
		if user.hasActiveItem?(:WHITEHERB)
			miniscore * 1.5
		else
			if userFasterThanTarget
				miniscore*=0.1
			end 
		end
		if @battle.field.effects[PBEffects::TrickRoom]!=0
			miniscore*=0.1
		else
			trickrooom = false
			for j in target.moves
				if j.id == :TRICKROOM
					trickrooom = true
					break
				end
			end
			miniscore*=0.1 if trickrooom
		end
		if user.hasActiveAbility?(:MOXIE)
			miniscore*=1.3
		end
		if user.hasActiveItem?(:WHITEHERB)
			miniscore*=1.5
		end  
		if !user.statStageAtMax?(:SPEED)          
			miniscore/=100.0
			score*=miniscore
		end
		healmove=false
		for j in user.moves
			if j.healingMove?
				healmove=true
			end
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY) && !healmove  
			score=0
		end      
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			score=0
		end
		score/=2.0 if user.SetupMovesUsed.include?(move.id)
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserAtkSpd1" # Dragon Dance
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if (aspeed<=ospeed && @battle.field.effects[PBEffects::TrickRoom]!=0)
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.burned?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :FOULPLAY
		end
		miniscore*=0.3 if movecheck
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		if move.baseDamage==0
			physmove=false
			for j in user.moves
				if j.physicalMove?(j.type)
					physmove=true
				end
			end    
			if physmove && !user.statStageAtMax?(:ATTACK)
				miniscore/=100.0
				score*=miniscore
			end
		else
			if !user.statStageAtMax?(:ATTACK)
				miniscore/=100.0
				score*=miniscore
			end
		end
		miniscore=100
		if user.stages[:ATTACK]<0
			ministat=user.stages[:ATTACK]
			minimini=5*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if @battle.field.effects[PBEffects::TrickRoom]!=0
			miniscore*=0.1
		else
			trickrooom = false
			for j in target.moves
				if j.id == :TRICKROOM
					trickrooom = true
					break
				end
			end
			miniscore*=0.1 if trickrooom
		end
		if user.hasActiveAbility?(:MOXIE)
			miniscore*=1.3
		end        
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end
		if !user.statStageAtMax?(:SPEED)
			miniscore/=100.0
			score*=miniscore
		end
		score=0 if user.statStageAtMax?(:SPEED) && user.statStageAtMax?(:ATTACK)
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserAtk1Spd2" # Shift Gear
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.5
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if (aspeed<=ospeed && @battle.field.effects[PBEffects::TrickRoom]!=0)
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.burned?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :FOULPLAY
		end
		miniscore*=0.3 if movecheck
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		if move.baseDamage==0
			physmove=false
			for j in user.moves
				if j.physicalMove?(j.type)
					physmove=true
				end
			end    
			if physmove && !user.statStageAtMax?(:ATTACK)
				miniscore/=100.0
				score*=miniscore
			end
		else
			if !user.statStageAtMax?(:ATTACK)
				miniscore/=100.0
				score*=miniscore
			end
		end
		miniscore=100
		if user.stages[:ATTACK]<0
			ministat=user.stages[:ATTACK]
			minimini=5*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if @battle.field.effects[PBEffects::TrickRoom]!=0
			miniscore*=0.1
		else
			trickrooom = false
			for j in target.moves
				if j.id == :TRICKROOM
					trickrooom = true
					break
				end
			end
			miniscore*=0.1 if trickrooom
		end
		if user.hasActiveAbility?(:MOXIE)
			miniscore*=1.3
		end        
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end
		if !user.statStageAtMax?(:SPEED)
			miniscore/=100.0
			score*=miniscore
		end
		score=0 if user.statStageAtMax?(:SPEED) && user.statStageAtMax?(:ATTACK)
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserAtkAcc1" # Hone Claws
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.burned?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :FOULPLAY
		end
		miniscore*=0.3 if movecheck
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end    
		if move.baseDamage==0
			physmove=false
			for j in user.moves
				if j.physicalMove?(j.type)
					physmove=true
				end
			end    
			if physmove && !user.statStageAtMax?(:ATTACK)
				miniscore/=100.0
				score*=miniscore
			end
		else
			if !user.statStageAtMax?(:ATTACK)
				miniscore/=100.0
				score*=miniscore
			end
		end
		miniscore=100
		weakermove=false
		for j in user.moves
			if j.baseDamage<95
				weakermove=true
			end
		end
		if weakermove
			miniscore*=1.1
		end       
		if target.stages[:EVASION]>0
			ministat=target.stages[:EVASION]
			minimini=5*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		#if target.hasActiveItem?(:BRIGHTPOWDER) || target.hasActiveItem?(:LAXINCENSE) || 
		#	(target.hasActiveAbility?(:SANDVEIL) && target.effectiveWeather == :Sandstorm) ||
		#	(target.hasActiveAbility?(:SNOWCLOAK) && target.effectiveWeather == :Hail)
		#	miniscore*=1.1
		#end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end
		if user.statStageAtMax?(:ACCURACY)
			miniscore/=100.0
			score*=miniscore
		end
		score = 0 if user.statStageAtMax?(:ACCURACY) && user.statStageAtMax?(:ATTACK)
		score = 0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserDefSpDef1" # Cosmic Power
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:DEFENSE]>0 || user.stages[:SPECIAL_DEFENSE]>0
			ministat=user.stages[:DEFENSE]
			ministat+=user.stages[:SPECIAL_DEFENSE]
			minimini=-15*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if (maxdam.to_f/user.hp)<0.12
			miniscore*=0.3
		end
		if !user.statStageAtMax?(:DEFENSE)
			miniscore/=100.0
			score*=miniscore
		end

		miniscore=100
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Physical Wall") || roles.include?("Special Wall")
			miniscore*=1.3
		end
		if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
			miniscore*=1.2
		end
		healmove=false
		for j in user.moves
			healmove=true if j.healingMove?
		end
		miniscore*=2 if healmove
		if user.pbHasMove?(:STOREDPOWER)
			miniscore*=1.5
		end
		if user.pbHasMove?(:LEECHSEED)
			miniscore*=1.3
		end
		if user.pbHasMove?(:PAINSPLIT)
			miniscore*=1.2
		end       
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end
		if !user.statStageAtMax?(:SPECIAL_DEFENSE)
			miniscore/=100.0
			score*=miniscore
		end
		score=0 if user.statStageAtMax?(:DEFENSE) && user.statStageAtMax?(:SPECIAL_DEFENSE)
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserSpAtkSpDef1" # calm mind
		miniscore=100        
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			miniscore*=0.8
			if maxdam>user.hp
				miniscore*=0.1
			end         
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		specmove=false
		for j in user.moves
			if j.specialMove?(j.type)
				specmove=true
			end
		end
		if specmove && !user.statStageAtMax?(:SPECIAL_ATTACK)
			miniscore/=100.0
			score*=miniscore
		end

		miniscore=100
		if user.frozen?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		roles = pbGetPokemonRole(user, target)
		if pbRoughStat(target,:SPECIAL_ATTACK,skill)<pbRoughStat(target,:ATTACK,skill)
			if !(roles.include?("Physical Wall") || roles.include?("Special Wall"))
				if userFasterThanTarget && (user.hp.to_f)/user.totalhp>0.75
					miniscore*=1.3
				elsif !userFasterThanTarget
					miniscore*=0.7
				end
			end
			miniscore*=1.3
		end
		if roles.include?("Physical Wall") || roles.include?("Special Wall")
			miniscore*=1.3
		end
		if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
			miniscore*=1.2
		end
		healmove=false
		for j in user.moves
			healmove=true if j.healingMove?
		end
		miniscore*=1.3 if healmove
		if user.pbHasMove?(:LEECHSEED)
			miniscore*=1.3
		end
		if user.pbHasMove?(:PAINSPLIT)
			miniscore*=1.2
		end 
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY)
			miniscore=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end
		if !user.statStageAtMax?(:SPECIAL_DEFENSE)
			miniscore/=100.0
			score*=miniscore
		end
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserSpAtkSpDefSpd1" # Quiver Dance
		#spatk
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			if move.baseDamage==0 
				miniscore*=0.8
				if maxdam>user.hp
					miniscore*=0.1
				end
			end              
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		if user.stages[:SPEED]<0
			ministat=user.stages[:SPEED]
			minimini=5*ministat
			minimini+=100          
			minimini/=100.0          
			miniscore*=minimini
		end
		ministat=0
		ministat+=target.stages[:ATTACK]
		ministat+=target.stages[:SPECIAL_ATTACK]
		ministat+=target.stages[:SPEED]
		if ministat>0
			minimini=(-5)*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.healingMove?
		end
		miniscore*=1.3 if movecheck
		if userFasterThanTarget
			miniscore*=1.5
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Sweeper")
			miniscore*=1.3
		end
		if user.frozen?
			miniscore*=0.5
		end
		if user.paralyzed?
			miniscore*=0.5
		end
		if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && 
				!user.takesHailDamage? && !user.takesSandstormDamage?)
			miniscore*=1.4
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.priority>0
		end
		miniscore*=0.6 if movecheck
		if target.hasActiveAbility?(:SPEEDBOOST)
			miniscore*=0.6
		end
		specmove=false
		for j in user.moves
			if j.specialMove?(j.type)
				specmove=true
			end
		end
		if specmove && !user.statStageAtMax?(:SPECIAL_ATTACK)
			miniscore/=100.0
			score*=miniscore
		end

		#spdef
		miniscore=100
		roles = pbGetPokemonRole(user, target)
		if pbRoughStat(target,:SPECIAL_ATTACK,skill)<pbRoughStat(target,:ATTACK,skill)
			if !(roles.include?("Physical Wall") || roles.include?("Special Wall"))
				if userFasterThanTarget && (user.hp.to_f)/user.totalhp>0.75
					miniscore*=1.3
				elsif !userFasterThanTarget
					miniscore*=0.7
				end
			end
			miniscore*=1.3
		end
		if roles.include?("Physical Wall") || roles.include?("Special Wall")
			miniscore*=1.3
		end
		if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
			miniscore*=1.2
		end
		healmove=false
		for j in user.moves
			healmove=true if j.healingMove?
		end
		miniscore*=1.3 if healmove
		if user.pbHasMove?(:LEECHSEED)
			miniscore*=1.3
		end
		if user.pbHasMove?(:PAINSPLIT)
			miniscore*=1.2
		end 
		if !user.statStageAtMax?(:SPECIAL_DEFENSE)
			miniscore/=100.0
			score*=miniscore
		end

		#speed
		miniscore=100
		if user.stages[:SPECIAL_ATTACK]<0
			ministat=user.stages[:SPECIAL_ATTACK]
			minimini=5*ministat
			minimini+=100
			minimini/=100.0
			miniscore*=minimini
		end
		if userFasterThanTarget
			miniscore*=0.8
		end
		if @battle.field.effects[PBEffects::TrickRoom]!=0
			miniscore*=0.1
		else
			trickrooom = false
			for j in target.moves
				if j.id == :TRICKROOM
					trickrooom = true
					break
				end
			end
			miniscore*=0.1 if trickrooom
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end
		if !user.statStageAtMax?(:SPEED)
			miniscore/=100.0
			score*=miniscore
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			score*=3
		end
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseUserMainStats1" # Ancient Power
		miniscore=100
		miniscore*=2 
		miniscore*=2 if user.hasActiveAbility?(:SIMPLE)
		miniscore-=100
		miniscore*=(move.addlEffect.to_f/100.0)
		miniscore*=2 if user.hasActiveAbility?(:SERENEGRACE)
		miniscore+=100
		miniscore/=100.0   
		miniscore=0.1 if user.hasActiveAbility?(:CONTRARY)
		score*=miniscore if !user.hasActiveAbility?(:SHEERFORCE)
    #---------------------------------------------------------------------------
    when "RaiseUserMainStats1LoseThirdOfTotalHP"
      if (user.hp <= user.totalhp / 2) || ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
        score = 0
      elsif user.hasActiveAbility?(:CONTRARY)
        score = 0
      else
        stats_maxed = true
        GameData::Stat.each_main_battle do |s|
          next if user.statStageAtMax?(s.id)
          stats_maxed = false
          break
        end
        if stats_maxed
          score = 0
        else
          if user.hp >= user.totalhp * 0.75
            score *= 1.3
          end
          GameData::Stat.each_main_battle { |s| score *= 1.1 if user.stages[s.id] <= 0 }
          if skill >= PBTrainerAI.mediumSkill
            hasDamagingAttack = user.moves.any? { |m| next m&.damagingMove? }
            score *= 1.2 if hasDamagingAttack
          end
        end
      end
    #---------------------------------------------------------------------------
    when "RaiseUserMainStats1TrapUserInBattle"
      if user.effects[PBEffects::NoRetreat]
        score = 0
      elsif user.hasActiveAbility?(:CONTRARY)
        score = 0
      else
        stats_maxed = true
        GameData::Stat.each_main_battle do |s|
          next if user.statStageAtMax?(s.id)
          stats_maxed = false
          break
        end
        if stats_maxed
          score = 0
        else
          if skill >= PBTrainerAI.highSkill
            score *= 0.5 if user.hp <= user.totalhp / 2
            score *= 1.3 if user.trappedInBattle?
          end
          GameData::Stat.each_main_battle { |s| score += 10 if user.stages[s.id] <= 0 }
          if skill >= PBTrainerAI.mediumSkill
            hasDamagingAttack = user.moves.any? { |m| next m&.damagingMove? }
            score *= 1.2 if hasDamagingAttack
          end
        end
      end
    #---------------------------------------------------------------------------
    when "StartRaiseUserAtk1WhenDamaged" # rage
		if user.attack>user.spatk
			score*=1.2
		end
		if user.hp==user.totalhp
			score*=1.3
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam = bestmove[0]
		if maxdam<(user.hp/4.0)
			score*=1.3
		end
    #---------------------------------------------------------------------------
    when "LowerUserAttack1", "LowerUserAttack2"
      score += user.stages[:ATTACK] * 10
    #---------------------------------------------------------------------------
    when "LowerUserDefense1", "LowerUserDefense2" # Clanging Scales
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam = bestmove[0]
		maxmove = bestmove[1]
		maxphys = (bestmove[3]=="physical")
		healvar = false
		privar = false
		for m in target.moves
			healvar = true if m.healingMove?
			privar = true if m.priority > 0
		end
		if user.hasActiveAbility?(:CONTRARY) || user.pbOwnSide.effects[PBEffects::StatDropImmunity]
			score*=1.5
		else
			if score<100
				score*=0.8
				if !userFasterThanTarget
					score*=1.3
				else
					if privar
						score*=1.2
					end
				end  
				if healvar
					score*=0.5
				end
			end
			userlivecount 	= @battle.pbAbleNonActiveCount(user.idxOwnSide)
			targetlivecount = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			miniscore=100
			if targetlivecount > 0 
				miniscore*=@battle.pbParty(target.index).length
				miniscore/=100.0
				miniscore*=0.05
				miniscore = 1-miniscore
				score*=miniscore
			end
			if userlivecount == 0 && targetlivecount > 0 
				score*=0.7
			end
			if target.attack>target.spatk
				score*=0.7
			end
			if maxphys
				score*=0.7
			end
		end
    #---------------------------------------------------------------------------
    when "LowerUserSpAtk1", "LowerUserSpAtk2" # Overheat
		if user.hasActiveAbility?(:CONTRARY) || user.pbOwnSide.effects[PBEffects::StatDropImmunity]
			score*=1.7
		else
			if targetSurvivesMove(move,user,target)
				score*=0.9
				healingmove = false
				for m in target.moves
					if m.healingMove?
						healingmove = true
						break
					end
				end
				miniscore=100
				miniscore*=0.5 if healingmove
				targetlivecount=@battle.pbAbleNonActiveCount(user.idxOpposingSide)
				if targetlivecount>1
					miniscore*=(targetlivecount-1)
					miniscore/=100.0
					miniscore*=0.05
					miniscore=(1-miniscore)
					score*=miniscore
				end
				userlivecount=-1
				pivotvar = false
				@battle.pbParty(user.index).each do |m|
					next if m.fainted?
					userlivecount+=1
					if pbHasPivotMove?(m)
						pivotvar = true
					end
				end
				doubleTarget = !user.allAllies.empty?
				if pivotvar && doubleTarget
					score*=1.2
				end
				if targetlivecount>1 && userlivecount==1
					score*=0.8
				end
				if user.hasActiveAbility?(:SOULHEART)
					score*=1.3
				end
			end
		end
    #---------------------------------------------------------------------------
    when "LowerUserSpDef1", "LowerUserSpDef2"
    	score += user.stages[:SPECIAL_DEFENSE] * 10
    #---------------------------------------------------------------------------
    when "LowerUserSpeed1", "LowerUserSpeed2" # Hammer Arm
		if user.hasActiveAbility?(:CONTRARY) || user.pbOwnSide.effects[PBEffects::StatDropImmunity]
			score*=1.3
		else
			if targetSurvivesMove(move,user,target)
				score*=0.9
			end
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			pivotvar = false
			@battle.pbParty(user.index).each do |m|
				if pbHasPivotMove?(m)
					pivotvar = true
				end
			end
			if userFasterThanTarget
				score*=0.8
				if livecounttarget>1 && livecountuser==1
					score*=0.8
				end         
			else
				score*=1.1
			end
			miniscore=100
			if livecounttarget>1
				miniscore*=(livecounttarget-3)
				miniscore/=100.0
				miniscore*=0.05
				miniscore=(1-miniscore)
				score*=miniscore
			end
			doubleTarget = !user.allAllies.empty?
			if pivotvar && doubleTarget
				score*=1.2
			end
		end
    #---------------------------------------------------------------------------
    when "LowerUserAtkDef1" # Superpower
		if user.hasActiveAbility?(:CONTRARY) || user.pbOwnSide.effects[PBEffects::StatDropImmunity]
			score*=1.7
		else
			if targetSurvivesMove(move,user,target)
				score*=0.9
				if !userFasterThanTarget
					score*=1.2
				else
					privar = false
					healvar = false
					for m in target.moves
						privar = true if m.priority > 0
						healvar = true if m.healingMove?
					end
					score*=0.8 if privar
					score*=0.5 if healvar
				end
			end
			miniscore=100
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget>1
				miniscore*=(livecounttarget-3)
				miniscore/=100.0
				miniscore*=0.05
				miniscore=(1-miniscore)
				score*=miniscore
			end
			pivotvar = false
			@battle.pbParty(user.index).each do |m|
				if pbHasPivotMove?(m)
					pivotvar = true
				end
			end
			doubleTarget = !user.allAllies.empty?
			if pivotvar && doubleTarget
				score*=1.2
			end
			if livecounttarget>1 && livecountuser==1
				score*=0.8
			end
			if user.hasActiveAbility?(:MOXIE)
				score*=1.5
			end
		end
    #---------------------------------------------------------------------------
    when "LowerUserDefSpDef1" # close combat
		if user.hasActiveAbility?(:CONTRARY) || user.pbOwnSide.effects[PBEffects::StatDropImmunity]
			score*=1.5
		else
			if targetSurvivesMove(move,user,target)
				score*=0.9
				if !userFasterThanTarget
					score*=1.2
				else
					privar = false
					healvar = false
					for m in target.moves
						privar = true if m.priority > 0
						healvar = true if m.healingMove?
					end
					score*=0.7 if privar
					score*=0.7 if healvar
				end
				miniscore=100
				livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
				livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
				if livecounttarget>1
					miniscore*=(livecounttarget-3)
					miniscore/=100.0
					miniscore*=0.05
					miniscore=(1-miniscore)
					score*=miniscore
				end
				pivotvar = false
				@battle.pbParty(user.index).each do |m|
					if pbHasPivotMove?(m)
						pivotvar = true
					end
				end
				doubleTarget = !user.allAllies.empty?
				if pivotvar && doubleTarget
					score*=1.2
				end
				if livecounttarget>1 && livecountuser==1
					score*=0.8
				end
			end
		end
    #---------------------------------------------------------------------------
    when "LowerUserDefSpDefSpd1" # V-Create
		if user.hasActiveAbility?(:CONTRARY) || user.pbOwnSide.effects[PBEffects::StatDropImmunity]
			score*=1.7
		else
			if targetSurvivesMove(move,user,target)
				score*=0.8
				if !userFasterThanTarget
					score*=1.3
				else
					privar = false
					for m in target.moves
						privar = true if m.priority > 0
					end
					score*=0.7 if privar
				end
				miniscore=100
				livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
				livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
				if livecounttarget>1
					miniscore*=(livecounttarget-3)
					miniscore/=100.0
					miniscore*=0.05
					miniscore=(1-miniscore)
					score*=miniscore
				end
				pivotvar = false
				@battle.pbParty(user.index).each do |m|
					if pbHasPivotMove?(m)
						pivotvar = true
					end
				end
				doubleTarget = !user.allAllies.empty?
				if pivotvar && doubleTarget
					score*=1.2
				end
				if livecounttarget>1 && livecountuser==1
					score*=0.7
				end
			end
		end
    #---------------------------------------------------------------------------
    when "RaiseTargetAttack2ConfuseTarget" # swagger
		if target.opposes?(user) # is enemy
			if target.pbCanConfuse?(user, false)
				if $game_variables[MECHANICSVAR] >= 3
					miniscore = pbTargetBenefitsFromStatus?(user, target, :DIZZY, 100, move, globalArray, skill)
				else
					miniscore = 100
					if target.paralyzed?
						miniscore*=1.3
					end
				end
				if target.effects[PBEffects::Attract]>=0
					miniscore*=1.3
				end
				if target.effects[PBEffects::Yawn]>0 || target.asleep?
					miniscore*=0.4
				end
				if target.hasActiveAbility?(:TANGLEDFEET)
					miniscore*=0.7
				end          
				if target.hasActiveAbility?(:CONTRARY)
					miniscore*=1.5
				end
				if user.pbHasMove?(:SUBSTITUTE)
					miniscore*=1.2
					if user.effects[PBEffects::Substitute]>0
						miniscore*=1.3
					end
				end
				miniscore/=100.0
				score*=miniscore
			else
				score = 0
			end
		else # is ally
			miniscore = -100 # neg due to being ally
			if target.pbCanConfuse?(user, false)
				miniscore*=0.5
			else
				miniscore*=1.5
			end          
			if target.attack>target.spatk
				miniscore*=1.5
			end
			if (1.0/target.totalhp)*target.hp < 0.6
				miniscore*=0.3
			end
			if target.effects[PBEffects::Attract]>=0 || target.paralyzed? || target.effects[PBEffects::Yawn]>0 || target.asleep?
				miniscore*=0.3
			end    
			if $game_variables[MECHANICSVAR] >= 3
				minimi = getAbilityDisruptScore(move,user,target,skill)
				minimi = 1.0 / minimi
				miniscore*=minimi
			else
				if target.hasActiveAbility?(:CONTRARY)
					miniscore = 0
				end
			end
			if target.hasActiveItem?([:PERSIMBERRY, :LUMBERRY])
				miniscore*=1.2
			end
			if target.effects[PBEffects::Substitute]>0
				miniscore = 0
			end
			targetAlly = []
			user.allOpposing.each do |b|
				next if !b.near?(user.index)
				targetAlly.push(b.index)
			end
			if targetAlly.length > 0
				if ospeed > pbRoughStat(@battle.battlers[targetAlly[0]],:SPEED,skill) && 
				   ospeed > pbRoughStat(@battle.battlers[targetAlly[1]],:SPEED,skill)
					miniscore*=1.3
				else
					miniscore*=0.7
				end
				if @battle.battlers[targetAlly[0]].pbHasMove?(:FOULPLAY) || 
					@battle.battlers[targetAlly[1]].pbHasMove?(:FOULPLAY)
					miniscore*=0.3
				end
			end
			miniscore/=100.0
			score *= miniscore
		end
    #---------------------------------------------------------------------------
    when "RaiseTargetSpAtk1ConfuseTarget" # flatter
		if target.opposes?(user) # is enemy
			if target.pbCanConfuse?(user, false)
				if $game_variables[MECHANICSVAR] >= 3
					miniscore = pbTargetBenefitsFromStatus?(user, target, :DIZZY, 100, move, globalArray, skill)
				else
					miniscore = 100
				end
				ministat=0
				ministat+=target.stages[:ATTACK]
				if ministat>0
					minimini=10*ministat
					minimini+=100
					minimini/=100.0
					miniscore*=minimini
				end      
				if target.attack>target.spatk
					miniscore*=1.5
				else
					miniscore*=0.3
				end
				if target.effects[PBEffects::Attract]>=0
					miniscore*=1.1
				end
				if target.paralyzed?
					miniscore*=1.1
				end
				if target.effects[PBEffects::Yawn]>0 || target.asleep?
					miniscore*=0.4
				end
				if target.hasActiveAbility?(:TANGLEDFEET)
					miniscore*=0.7
				end          
				if target.hasActiveAbility?(:CONTRARY)
					miniscore*=1.5
				end
				if user.pbHasMove?(:SUBSTITUTE)
					miniscore*=1.2
					if user.effects[PBEffects::Substitute]>0
						miniscore*=1.3
					end
				end
				miniscore/=100.0
				score*=miniscore
			else
				score = 0
			end
		else # is ally
			miniscore = -100 # neg due to being ally
			if target.pbCanConfuse?(user, false)
				miniscore*=0.5
			else
				miniscore*=1.5
			end          
			if target.attack<target.spatk
				miniscore*=1.5
			end
			if (1.0/target.totalhp)*target.hp < 0.6
				miniscore*=0.3
			end
			if target.effects[PBEffects::Attract]>=0 || target.paralyzed? || target.effects[PBEffects::Yawn]>0 || target.asleep?
				miniscore*=0.3
			end    
			if $game_variables[MECHANICSVAR] >= 3
				minimi = getAbilityDisruptScore(move,user,target,skill)
				minimi = 1.0 / minimi
				miniscore*=minimi
			else
				if target.hasActiveAbility?(:CONTRARY)
					miniscore = 0
				end
			end
			if target.hasActiveItem?([:PERSIMBERRY, :LUMBERRY])
				miniscore*=1.2
			end
			if target.effects[PBEffects::Substitute]>0
				miniscore = 0
			end
			targetAlly = []
			user.allOpposing.each do |b|
				next if !b.near?(user.index)
				targetAlly.push(b.index)
			end
			if targetAlly.length > 0
				if ospeed > pbRoughStat(@battle.battlers[targetAlly[0]],:SPEED,skill) && 
				   ospeed > pbRoughStat(@battle.battlers[targetAlly[1]],:SPEED,skill)
					miniscore*=1.3
				else
					miniscore*=0.7
				end
			end
			miniscore/=100.0
			score *= miniscore
		end
    #---------------------------------------------------------------------------
    when "RaiseTargetSpDef1" # Aromatic Mist
		hasAlly = !user.allAllies.empty?
		if hasAlly && !target.opposes?(user) && !target.statStageAtMax?(:SPECIAL_DEFENSE)
			t_hasAlly = !target.allAllies.empty?
			if !t_hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
				miniscore*=2
			end
			if target.hp*(1.0/target.totalhp)>0.75
				score*=1.1
			end
			if target.effects[PBEffects::Yawn]>0 || target.effects[PBEffects::LeechSeed]>=0 || 
					target..effects[PBEffects::Attract]>=0 || target.pbHasAnyStatus?
				score*=0.3
			end
			if movecheck
				score*=0.2
			end
			if target.hasActiveAbility?(:SIMPLE)
				score*=2
			end
			if target.hasActiveItem?(:LEFTOVERS) || (target.hasActiveItem?(:BLACKSLUDGE) && target.pbHasType?(:POISON, true))
				score*=1.2
			end
			if target.hasActiveAbility?(:CONTRARY)
				score=0
			end
			score=0 if $game_variables[MECHANICSVAR] >= 3 && target.SetupMovesUsed.include?(move.id)
		else
			score=0
		end
    #---------------------------------------------------------------------------
    when "RaiseTargetRandomStat2" # Acupressure
		miniscore=100        
		if (target.hasActiveAbility?(:DISGUISE,false,mold_broken) && target.form == 0) || target.effects[PBEffects::Substitute]>0
			miniscore*=1.3
		end
		hasAlly = !target.allAllies.empty?
		if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
			miniscore*=2
		end
		if (user.hp.to_f)/user.totalhp>0.75
			miniscore*=1.2
		end
		if (user.hp.to_f)/user.totalhp<0.33
			miniscore*=0.3
		end
		if (user.hp.to_f)/user.totalhp<0.75 && (user.hasActiveAbility?(:EMERGENCYEXIT) || user.hasActiveAbility?(:WIMPOUT) || user.hasActiveItem?(:EJECTBUTTON))
			miniscore*=0.3
		end
		if target.effects[PBEffects::HyperBeam]>0
			miniscore*=1.3
		end
		if target.effects[PBEffects::Yawn]>0
			miniscore*=1.7
		end
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam=bestmove[0]
		if maxdam<(user.hp/4.0)
			miniscore*=1.2
		else
			miniscore*=0.8
			if maxdam>user.hp
				miniscore*=0.1
			end
		end
		if user.turnCount<2
			miniscore*=1.2
		end
		if target.pbHasAnyStatus?
			miniscore*=1.2
		end
		if target.asleep?
			miniscore*=1.3
		end
		if target.effects[PBEffects::Encore]>0
			if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0
				miniscore*=1.5
			end          
		end
		if user.effects[PBEffects::Confusion]>0
			miniscore*=0.2
		end
		if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
			miniscore*=0.6
		end
		if pbHasPhazingMove?(target)
			miniscore*=0.5
		end
		if user.hasActiveAbility?(:SIMPLE)
			miniscore*=2
		end
		hasAlly = !target.allAllies.empty?
		if hasAlly
			miniscore*=0.7
		end
		roles = pbGetPokemonRole(user, target)
		if roles.include?("Physical Wall") || roles.include?("Special Wall")
			miniscore*=1.3
		end
		if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
			miniscore*=1.2
		end
		healmove=false
		for j in user.moves
			healmove=true if j.healingMove?
		end
		miniscore*=1.3 if healmove
		if user.pbHasMove?(:LEECHSEED)
			miniscore*=1.3
		end
		if user.pbHasMove?(:PAINSPLIT)
			miniscore*=1.2
		end
		miniscore/=100.0
		maxstat=0
		maxstat+=1 if user.statStageAtMax?(:ATTACK)        
		maxstat+=1 if user.statStageAtMax?(:DEFENSE)        
		maxstat+=1 if user.statStageAtMax?(:SPECIAL_ATTACK)        
		maxstat+=1 if user.statStageAtMax?(:SPECIAL_DEFENSE)        
		maxstat+=1 if user.statStageAtMax?(:SPEED)        
		maxstat+=1 if user.statStageAtMax?(:ACCURACY)        
		maxstat+=1 if user.statStageAtMax?(:EVASION)        
		if maxstat>1
			miniscore=0
		end
		movecheck=false
		for m in target.moves
			movecheck=true if m.id == :CLEARSMOG
			movecheck=true if m.id == :HAZE
		end
		miniscore*=0 if movecheck
		if user.hasActiveAbility?(:CONTRARY)
			miniscore*=0
		end            
		if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
			miniscore=1
		end
		score*=miniscore
		score=0 if ($game_variables[MECHANICSVAR] >= 3 && user.SetupMovesUsed.include?(move.id) && move.statusMove?)
    #---------------------------------------------------------------------------
    when "RaiseTargetAtkSpAtk2"
		if target.hasActiveAbility?(:CONTRARY)
			if target.opposes?(user) && target.battle.choices[target.index][0] != :SwitchOut
				score -= target.stages[:ATTACK] * 20
				score -= target.stages[:SPECIAL_ATTACK] * 20
			else
				score -= 100
			end
		elsif target.opposes?(user) || ($game_variables[MECHANICSVAR] >= 3 && target.SetupMovesUsed.include?(move.id))
			score -= 100
		else
			score -= target.stages[:ATTACK] * 20
			score -= target.stages[:SPECIAL_ATTACK] * 20
			score *= -1
		end
    #---------------------------------------------------------------------------
    when "LowerTargetAttack1" # growl
		if (pbRoughStat(target,:SPECIAL_ATTACK,skill)>pbRoughStat(target,:ATTACK,skill)) || 
				target.stages[:ATTACK]>0 || !target.pbCanLowerStatStage?(:ATTACK)
			if move.baseDamage==0
				score=0
			end
		else
			miniscore=100
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?(:SHADOWTAG) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.poisoned?
				miniscore*=1.2
			end
			if target.stages[:ATTACK]<0
				minimini = 5*target.stages[:ATTACK]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
			if user.pbHasMove?(:FOULPLAY)
				miniscore*=0.5
			end  
			if target.burned? && !target.hasActiveAbility?(:GUTS)
				miniscore*=0.5
			end       
			if target.hasActiveAbility?([:UNAWARE, :COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if move.baseDamage>0
				miniscore-=100
				if move.addlEffect.to_f != 100
					miniscore*=(move.addlEffect.to_f/100.0)
					if user.hasActiveAbility?(:SERENEGRACE)
						miniscore*=2
					end     
				end 
				miniscore+=100
			else
				if livecounttarget==1
					miniscore*=0.5
				end
			end
			miniscore/=100.0    
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerTargetAttack1BypassSubstitute", "LowerTargetAttack2", "LowerTargetAttack3" # feather dance
		if (pbRoughStat(target,:SPECIAL_ATTACK,skill)>pbRoughStat(target,:ATTACK,skill)) || 
				target.stages[:ATTACK]>1 || !target.pbCanLowerStatStage?(:ATTACK)
			if move.baseDamage==0
				score=0
			end
		else
			miniscore=100
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?(:SHADOWTAG) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.poisoned?
				miniscore*=1.2
			end
			if target.stages[:ATTACK]<0
				minimini = 5*target.stages[:ATTACK]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
			if user.pbHasMove?(:FOULPLAY)
				miniscore*=0.5
			end  
			if target.burned? && !target.hasActiveAbility?(:GUTS)
				miniscore*=0.5
			end       
			if target.hasActiveAbility?([:UNAWARE, :COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if move.baseDamage>0
				miniscore-=100
				if move.addlEffect.to_f != 100
					miniscore*=(move.addlEffect.to_f/100.0)
					if user.hasActiveAbility?(:SERENEGRACE)
						miniscore*=2
					end     
				end 
				miniscore+=100
			else
				if livecounttarget==1
					miniscore*=0.5
				end
			end
			miniscore/=100.0    
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerTargetDefense1", "LowerTargetDefense1PowersUpInGravity" # Tail Whip
		physmove=false
		for j in user.moves
			if j.physicalMove?(j.type)
				physmove=true
			end  
		end
		if !physmove || target.stages[:DEFENSE]>0 || !target.pbCanLowerStatStage?(:DEFENSE)
			if move.baseDamage==0
				score=0
			end
		else
			miniscore=100
			healingmove = false
			for m in target.moves
				if m.healingMove?
					healingmove = true
					break
				end
			end
			miniscore*=1.5 if healingmove
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?(:SHADOWTAG) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.poisoned? || target.burned?
				miniscore*=1.2
			end
			if target.stages[:DEFENSE]<0
				minimini = 5*target.stages[:DEFENSE]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end     
			if target.hasActiveAbility?([:UNAWARE,:COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if user.burned?
				miniscore*=0.7
			end
			if move.baseDamage>0
				miniscore-=100
				if move.addlEffect.to_f != 100
					miniscore*=(move.addlEffect.to_f/100.0)
					if user.hasActiveAbility?(:SERENEGRACE)
						miniscore*=2
					end     
				end
				miniscore+=100
			else
				if livecounttarget==1
					miniscore*=0.5
				end
				if user.pbHasAnyStatus?
					miniscore*=0.7
				end
			end
			miniscore/=100.0    
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerTargetDefense2", "LowerTargetDefense3" # screech
		physmove=false
		for j in user.moves
			if j.physicalMove?(j.type)
				physmove=true
			end  
		end
		if !physmove || target.stages[:DEFENSE]>1 || !target.pbCanLowerStatStage?(:DEFENSE)
			if move.baseDamage==0
				score=0
			end
		else
			miniscore=100
			healingmove = false
			for m in target.moves
				if m.healingMove?
					healingmove = true
					break
				end
			end
			miniscore*=1.5 if healingmove
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?(:SHADOWTAG) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.poisoned? || target.burned?
				miniscore*=1.2
			end
			if target.stages[:DEFENSE]<0
				minimini = 5*target.stages[:DEFENSE]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
			if livecounttarget==1
				miniscore*=0.5
			end
			if target.hasActiveAbility?([:UNAWARE,:COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if user.pbHasAnyStatus?
				miniscore*=0.7
			end
			if user.burned?
				miniscore*=0.7
			end
			miniscore/=100.0    
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerTargetSpAtk1" # snarl
		if (pbRoughStat(target,:SPECIAL_ATTACK,skill)<pbRoughStat(target,:ATTACK,skill)) || 
				target.stages[:SPECIAL_ATTACK]>0 || !target.pbCanLowerStatStage?(:SPECIAL_ATTACK)
			if move.baseDamage==0
				score=0
			end
		else
			miniscore=100
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?(:SHADOWTAG) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.poisoned? || target.burned? || target.frozen?
				miniscore*=1.2
			end
			if target.stages[:SPECIAL_ATTACK]<0
				minimini = 5*target.stages[:SPECIAL_ATTACK]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end     
			if target.hasActiveAbility?([:UNAWARE,:COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if user.frozen?
				miniscore*=0.7
			end
			if move.baseDamage>0
				miniscore-=100
				if move.addlEffect.to_f != 100
					miniscore*=(move.addlEffect.to_f/100.0)
					if user.hasActiveAbility?(:SERENEGRACE)
						miniscore*=2
					end     
				end
				miniscore+=100
			else
				if livecounttarget==1
					miniscore*=0.5
				end
			end       
			miniscore/=100.0    
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerTargetSpAtk2", "LowerTargetSpAtk3" # eerie impulse
		if (pbRoughStat(target,:SPECIAL_ATTACK,skill)<pbRoughStat(target,:ATTACK,skill)) || 
				target.stages[:SPECIAL_ATTACK]>1 || !target.pbCanLowerStatStage?(:SPECIAL_ATTACK)
			if move.baseDamage==0
				score=0
			end
		else
			miniscore=100
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Physical Wall") || roles.include?("Special Wall")
				miniscore*=1.3
			end
			sweepvar = false
			count=0
			@battle.pbParty(user.index).each do |i|
				next if i.nil?
				count+=1
				temproles = pbGetPokemonRole(i, target, count, @battle.pbParty(user.index))
				if temproles.include?("Sweeper")
					sweepvar = true
				end
			end
			if sweepvar
				miniscore*=1.1
			end
			userlivecount 	= @battle.pbAbleNonActiveCount(user.idxOwnSide)
			targetlivecount = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if targetlivecount==1 || user.hasActiveAbility?([:SHADOWTAG, :ARENATRAP]) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.poisoned? || target.burned? || target.frozen?
				miniscore*=1.2
			end
			if target.stages[:SPECIAL_ATTACK]<0
				minimini = 5*target.stages[:SPECIAL_ATTACK]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end       
			if userlivecount==1
				miniscore*=0.5
			end
			if target.hasActiveAbility?([:UNAWARE,:COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end         
			miniscore/=100.0    
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerTargetSpAtk2IfCanAttract"
		if (pbRoughStat(target,:SPECIAL_ATTACK,skill)<pbRoughStat(target,:ATTACK,skill)) || 
		   target.stages[:SPECIAL_ATTACK]>1 || !target.pbCanLowerStatStage?(:SPECIAL_ATTACK)
			if move.baseDamage==0
				score=0
			end
		else
			miniscore=100
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?(:SHADOWTAG) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.poisoned? || target.burned? || target.frozen?
				miniscore*=1.2
			end
			if target.stages[:SPECIAL_ATTACK]<0
				minimini = 5*target.stages[:SPECIAL_ATTACK]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end     
			if target.hasActiveAbility?([:UNAWARE,:COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if user.frozen?
				miniscore*=0.7
			end
			if move.baseDamage>0
				miniscore-=100
				if move.addlEffect.to_f != 100
					miniscore*=(move.addlEffect.to_f/100.0)
					if user.hasActiveAbility?(:SERENEGRACE)
						miniscore*=2
					end     
				end
				miniscore+=100
			else
				if livecounttarget==1
					miniscore*=0.5
				end
			end       
			miniscore/=100.0    
			score*=miniscore
		end
		if user.gender == 2 || target.gender == 2 || user.gender == target.gender ||
		   target.hasActiveAbility?(:OBLIVIOUS,false,mold_broken)
			score = 0
		end
    #---------------------------------------------------------------------------
    when "LowerTargetSpDef1" # psychic
		specmove=false
		for j in user.moves
			if j.specialMove?(j.type)
				specmove=true
			end  
		end
		if !specmove || target.stages[:SPECIAL_DEFENSE]>0 || !target.pbCanLowerStatStage?(:SPECIAL_DEFENSE)
			if move.baseDamage==0
				score=0
			end
		else
			miniscore=100
			healingmove = false
			for m in target.moves
				if m.healingMove?
					healingmove = true
					break
				end
			end
			miniscore*=1.5 if healingmove
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?([:SHADOWTAG, :ARENATRAP]) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.poisoned? || target.burned?
				miniscore*=1.2
			end
			if target.stages[:SPECIAL_DEFENSE]<0
				minimini = 5*target.stages[:SPECIAL_DEFENSE]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
			if user.frozen?
				miniscore*=0.5
			end
			if target.hasActiveAbility?([:UNAWARE, :COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if move.baseDamage>0
				miniscore-=100
				if move.addlEffect.to_f != 100
					miniscore*=(move.addlEffect.to_f/100.0)
					if user.hasActiveAbility?(:SERENEGRACE)
						miniscore*=2
					end     
				end
				miniscore+=100
			else
				if livecountuser==1
					miniscore*=0.5
				end
				if user.pbHasAnyStatus?
					miniscore*=0.7
				end
			end
			miniscore/=100.0    
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerTargetSpDef2", "LowerTargetSpDef3" # acid spray
		specmove=false
		for j in user.moves
			if j.specialMove?(j.type)
				specmove=true
			end  
		end
		if !specmove || target.stages[:SPECIAL_DEFENSE]>1 || !target.pbCanLowerStatStage?(:SPECIAL_DEFENSE)
			if move.baseDamage==0
				score=0
			end
		else
			miniscore=100
			healingmove = false
			for m in target.moves
				if m.healingMove?
					healingmove = true
					break
				end
			end
			miniscore*=1.3 if healingmove
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?([:SHADOWTAG, :ARENATRAP]) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.poisoned? || target.burned?
				miniscore*=1.2
			end
			if target.stages[:SPECIAL_DEFENSE]<0
				minimini = 5*target.stages[:SPECIAL_DEFENSE]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
			if user.frozen?
				miniscore*=0.5
			end
			if target.hasActiveAbility?([:UNAWARE, :COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if move.baseDamage>0
				miniscore-=100
				if move.addlEffect.to_f != 100
					miniscore*=(move.addlEffect.to_f/100.0)
					if user.hasActiveAbility?(:SERENEGRACE)
						miniscore*=2
					end     
				end
				miniscore+=100
			else
				if livecountuser==1
					miniscore*=0.5
				end
				if user.pbHasAnyStatus?
					miniscore*=0.9
				end
			end
			miniscore/=100.0    
			score*=miniscore
		end
    #---------------------------------------------------------------------------
	when "LowerTargetSpeed1", "LowerTargetSpeed1WeakerInGrassyTerrain", "LowerTargetSpeed1MakeTargetWeakerToFire" # Rock Tomb
		if userFasterThanTarget || target.stages[:SPEED]>0 || !target.pbCanLowerStatStage?(:SPEED)
			score=0 if move.baseDamage==0
		else
			miniscore=100
			if (ospeed*0.66)>aspeed      
				miniscore*=1.1
			end
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?([:SHADOWTAG, :ARENATRAP]) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.stages[:SPEED]<0
				minimini = 5*target.stages[:SPEED]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
			if target.hasActiveAbility?([:COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if user.pbHasMove?(:ELECTROBALL)
				miniscore*=1.5
			end  
			if user.pbHasMove?(:GYROBALL)
				miniscore*=0.5
			end
			if @battle.field.effects[PBEffects::TrickRoom]!=0
				miniscore*=0.1
			else
				trickrooom = false
				for j in target.moves
					if j.id == :TRICKROOM
						trickrooom = true
						break
					end
				end
				miniscore*=0.1 if trickrooom
			end
			if target.hasActiveItem?([:LAGGINGTAIL, :IRONBALL])
				miniscore*=0.1
			end
			electroballin = false
			for j in target.moves
				if j.id == :ELECTROBALL
					electroballin = true
					break
				end
			end
			miniscore*=1.3 if electroballin
			gyroballin = false
			for j in target.moves
				if j.id == :GYROBALL
					gyroballin = true
					break
				end
			end
			miniscore*=0.5 if gyroballin
			
			miniscore*=0.7 if move.function == "LowerTargetSpeed1WeakerInGrassyTerrain" && 
							 (@battle.field.terrain == :Grassy || globalArray.include?("grassy terrain"))
			
			miniscore-=100
			if move.addlEffect.to_f != 100
				miniscore*=(move.addlEffect.to_f/100.0)
				if user.hasActiveAbility?(:SERENEGRACE)
					miniscore*=2
				end     
			end
			miniscore+=100
			miniscore/=100.0    
			if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
				miniscore=1
			end
			if target.hasActiveAbility?(:SPEEDBOOST)
				miniscore=1
			end
			if move.function == "LowerTargetSpeed1MakeTargetWeakerToFire"
				miniscore *= 1.2 if user.moves.any? { |m| m.damagingMove? && m.pbCalcType(user) == :FIRE }
			end
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerTargetSpeed2", "LowerTargetSpeed3" # scary face
		if userFasterThanTarget || !target.pbCanLowerStatStage?(:SPEED)
			score=0 if move.baseDamage==0
		else
			miniscore=100
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?([:SHADOWTAG, :ARENATRAP]) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.3
			end
			if target.stages[:SPEED]<0
				minimini = 5*target.stages[:SPEED]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
			if target.hasActiveAbility?([:COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if target.hasActiveAbility?(:SPEEDBOOST)
				miniscore*=0.5
			end
			if user.pbHasMove?(:ELECTROBALL)
				miniscore*=1.5
			end  
			if user.pbHasMove?(:GYROBALL)
				miniscore*=0.5
			end
			if @battle.field.effects[PBEffects::TrickRoom]!=0
				miniscore*=0.1
			else
				trickrooom = false
				for j in target.moves
					if j.id == :TRICKROOM
						trickrooom = true
						break
					end
				end
				miniscore*=0.1 if trickrooom
			end
			if target.hasActiveItem?([:LAGGINGTAIL, :IRONBALL])
				miniscore*=0.1
			end
			electroballin = false
			for j in target.moves
				if j.id == :ELECTROBALL
					electroballin = true
					break
				end
			end
			miniscore*=1.3 if electroballin
			gyroballin = false
			for j in target.moves
				if j.id == :GYROBALL
					gyroballin = true
					break
				end
			end
			miniscore*=0.5 if gyroballin
			miniscore/=100.0
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerTargetAccuracy1", "LowerTargetAccuracy2", "LowerTargetAccuracy3"
    	score = 0 if move.statusMove? # they do jackshit
    #---------------------------------------------------------------------------
    when "LowerTargetEvasion1"
		if move.statusMove?
			if target.pbCanLowerStatStage?(:EVASION, user)
				score += target.stages[:EVASION] * 10
			else
				score -= 90
			end
		elsif target.stages[:EVASION] > 0
			score += 20
		end
    #---------------------------------------------------------------------------
    when "LowerTargetEvasion1RemoveSideEffects" # defog
		miniscore=100
		livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
		livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
		if livecounttarget>1
			miniscore*=2 if user.pbOwnSide.effects[PBEffects::StealthRock]
			miniscore*=(1.8**user.pbOwnSide.effects[PBEffects::StickyWeb])
			miniscore*=(1.5**user.pbOwnSide.effects[PBEffects::Spikes])
			miniscore*=(1.7**user.pbOwnSide.effects[PBEffects::ToxicSpikes])
		end
		miniscore-=100
		miniscore*=(livecounttarget-1) if livecounttarget>1
		minimini=100
		if livecountuser>1
			minimini*=0.5 if user.pbOwnSide.effects[PBEffects::StealthRock]
			minimini*=(0.3**user.pbOwnSide.effects[PBEffects::StickyWeb])
			minimini*=(0.7**user.pbOwnSide.effects[PBEffects::Spikes])
			minimini*=(0.6**user.pbOwnSide.effects[PBEffects::ToxicSpikes])
		end
		minimini-=100
		minimini*=(livecountuser-1) if livecountuser>1
		miniscore+=minimini
		miniscore+=100
		if miniscore<0
			miniscore=0
		end
		miniscore/=100.0
		score*=miniscore
		if target.pbOwnSide.effects[PBEffects::AuroraVeil]>0
			score*=1.8
		end
		if target.pbOwnSide.effects[PBEffects::Reflect]>0
			score*=2
		end
		if target.pbOwnSide.effects[PBEffects::LightScreen]>0
			score*=2
		end
		if target.pbOwnSide.effects[PBEffects::Mist]>0
			score*=1.3
		end
		if target.pbOwnSide.effects[PBEffects::Safeguard]>0
			score*=1.3
		end
    #---------------------------------------------------------------------------
    when "LowerTargetEvasion2", "LowerTargetEvasion3"
		if move.statusMove?
			if target.pbCanLowerStatStage?(:EVASION, user)
				score += target.stages[:EVASION] * 10
			else
				score -= 90
			end
		elsif target.stages[:EVASION] > 0
			score += 20
		end
    #---------------------------------------------------------------------------
    when "LowerTargetAtkDef1" # tickle
		if (pbRoughStat(target,:SPECIAL_ATTACK,skill)>pbRoughStat(target,:ATTACK,skill)) || 
				target.stages[:ATTACK]>0 || !target.pbCanLowerStatStage?(:ATTACK)
			if move.baseDamage==0
				score*=0.5
			end
		else
			miniscore=100
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?([:SHADOWTAG, :ARENATRAP]) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if target.poisoned?
				miniscore*=1.2
			end
			if target.stages[:ATTACK]+target.stages[:DEFENSE]<0
				minimini = 5*target.stages[:ATTACK]
				minimini+= 5*target.stages[:DEFENSE]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end
			if user.pbHasMove?(:FOULPLAY)
				miniscore*=0.5
			end  
			if livecounttarget==1
				miniscore*=0.5
			end
			if target.burned? && !target.hasActiveAbility?(:GUTS)
				miniscore*=0.5
			end       
			if target.hasActiveAbility?([:UNAWARE, :COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if move.baseDamage>0
				miniscore-=100
				if move.addlEffect.to_f != 100
					miniscore*=(move.addlEffect.to_f/100.0)
					if user.hasActiveAbility?(:SERENEGRACE)
						miniscore*=2
					end     
				end 
				miniscore+=100
			else
				if livecountuser==1
					miniscore*=0.5
				end
			end
			miniscore/=100.0    
			score*=miniscore
		end
		miniscore=100
		physmove=false
		for j in user.moves
			if j.physicalMove?(j.type)
				physmove=true
			end  
		end
		if !physmove || target.stages[:DEFENSE]>0 || !target.pbCanLowerStatStage?(:DEFENSE)
			if move.baseDamage==0
				score*=0.5
			end
		else
			healingmove = false
			for m in target.moves
				if m.healingMove?
					healingmove = true
					break
				end
			end
			miniscore*=1.3 if healingmove
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?([:SHADOWTAG, :ARENATRAP]) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			if livecountuser==1
				miniscore*=0.5
			end
			if target.poisoned?
				miniscore*=1.2
			end
			if target.stages[:DEFENSE]<0
				minimini = 5*target.stages[:DEFENSE]
				minimini+=100
				minimini/=100.0
				miniscore*=minimini
			end     
			if target.hasActiveAbility?([:UNAWARE,:COMPETITIVE, :DEFIANT, :CONTRARY])
				miniscore*=0.1
			end
			if user.pbHasAnyStatus?
				miniscore*=0.7
			end
			if user.burned?
				miniscore*=0.7
			end
			if move.baseDamage>0
				miniscore-=100
				if move.addlEffect.to_f != 100
					miniscore*=(move.addlEffect.to_f/100.0)
					if user.hasActiveAbility?(:SERENEGRACE)
						miniscore*=2
					end     
				end
				miniscore+=100
			end
			miniscore/=100.0    
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerTargetAtkSpAtk1" # noble roar
		if (!target.pbCanLowerStatStage?(:ATTACK) && !target.pbCanLowerStatStage?(:SPECIAL_ATTACK)) || 
				(target.stages[:ATTACK]==-6 && target.stages[:SPECIAL_ATTACK]==-6) || 
				(target.stages[:ATTACK]>0 && target.stages[:SPECIAL_ATTACK]>0)
			score*=0
		else
			miniscore=100
			roles = pbGetPokemonRole(user, target)
			if roles.include?("Physical Wall") || roles.include?("Special Wall")
				miniscore=1.3
			end
			sweepvar = false
			count=0
			@battle.pbParty(user.index).each do |i|
				next if i.nil?
				count+=1
				temproles = pbGetPokemonRole(i, target, count, @battle.pbParty(user.index))
				if temproles.include?("Sweeper")
					sweepvar = true
				end
			end
			if sweepvar 
				miniscore*=1.1
			end
			livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
			livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
			if livecounttarget==1 || user.hasActiveAbility?([:SHADOWTAG, :ARENATRAP]) || target.effects[PBEffects::MeanLook]>0
				miniscore*=1.4
			end
			ministat=0          
			ministat+=target.stages[:ATTACK] if target.stages[:ATTACK]<0
			ministat+=target.stages[:DEFENSE] if target.stages[:DEFENSE]<0
			ministat+=target.stages[:SPEED] if target.stages[:SPEED]<0
			ministat+=target.stages[:SPECIAL_ATTACK] if target.stages[:SPECIAL_ATTACK]<0
			ministat+=target.stages[:SPECIAL_DEFENSE] if target.stages[:SPECIAL_DEFENSE]<0
			ministat+=target.stages[:EVASION] if target.stages[:EVASION]<0
			ministat*=(5)
			ministat+=100
			ministat/=100.0
			miniscore*=ministat  
			if user.pbHasMove?(:FOULPLAY)
				miniscore*=0.5
			end
			if livecountuser == 0
				miniscore*=0.5
			end
			if target.hasActiveAbility?([:UNAWARE, :DEFIANT, :COMPETITIVE, :CONTRARY])
				miniscore*=0.1
			end
			miniscore/=100.0
			score*=miniscore
		end
    #---------------------------------------------------------------------------
    when "LowerPoisonedTargetAtkSpAtkSpd1" # Venom Drench
		if target.poisoned?
			if (!target.pbCanLowerStatStage?(:ATTACK) && !target.pbCanLowerStatStage?(:SPECIAL_ATTACK)) ||
					(target.stages[:ATTACK]==-6 && target.stages[:SPECIAL_ATTACK]==-6) || 
					(target.stages[:ATTACK]>0 && target.stages[:SPECIAL_ATTACK]>0)
				score=0
			else
				miniscore=100
				roles = pbGetPokemonRole(user, target)
				if roles.include?("Physical Wall") || roles.include?("Special Wall")
					miniscore=1.4
				end
				sweepvar = false
				count=0
				@battle.pbParty(user.index).each do |i|
					next if i.nil?
					count+=1
					temproles = pbGetPokemonRole(i, target, count, @battle.pbParty(user.index))
					if temproles.include?("Sweeper")
						sweepvar = true
					end
				end
				if sweepvar 
					miniscore*=1.1
				end
				livecountuser 	 = @battle.pbAbleNonActiveCount(user.idxOwnSide)
				livecounttarget  = @battle.pbAbleNonActiveCount(user.idxOpposingSide)
				if livecounttarget==1 || user.hasActiveAbility?([:SHADOWTAG, :ARENATRAP]) || target.effects[PBEffects::MeanLook]>0
					miniscore*=1.4
				end
				ministat=0          
				ministat+=target.stages[:ATTACK] if target.stages[:ATTACK]<0
				ministat+=target.stages[:DEFENSE] if target.stages[:DEFENSE]<0
				ministat+=target.stages[:SPEED] if target.stages[:SPEED]<0
				ministat+=target.stages[:SPECIAL_ATTACK] if target.stages[:SPECIAL_ATTACK]<0
				ministat+=target.stages[:SPECIAL_DEFENSE] if target.stages[:SPECIAL_DEFENSE]<0
				ministat+=target.stages[:EVASION] if target.stages[:EVASION]<0
				ministat*=(5)
				ministat+=100
				ministat/=100.0
				miniscore*=ministat  
				if user.pbHasMove?(:FOULPLAY)
					miniscore*=0.5
				end
				if livecountuser == 0
					miniscore*=0.5
				end
				if target.hasActiveAbility?([:UNAWARE, :DEFIANT, :COMPETITIVE, :CONTRARY])
					miniscore*=0.1
				end
				miniscore/=100.0
				score*=miniscore
			end  
			if userFasterThanTarget || target.stages[:SPEED]>1 || !target.pbCanLowerStatStage?(:SPEED)
				miniscore=0
			else
				miniscore=100            
				if target.hasActiveAbility?(:SPEEDBOOST)
					miniscore*=0.9
				end
				if user.pbHasMove?(:ELECTROBALL)
					miniscore*=1.5
				end  
				if target.pbHasMove?(:GYROBALL)
					miniscore*=1.5
				end   
				if @battle.field.effects[PBEffects::TrickRoom]!=0
					miniscore*=0.1
				else
					movechecktrickroom=false
					for j in target.moves
						movechecktrickroom=true if j.id == :TRICKROOM
					end
					miniscore*=0.1 if movechecktrickroom
				end   
				if target.hasActiveItem?(:LAGGINGTAIL) || target.hasActiveItem?(:IRONBALL)
					miniscore*=0.8
				end
				movecheckelectroball	= false
				movecheckgyroball		= false
				for j in target.moves
					movecheckelectroball = true if j.id == :ELECTROBALL
					movecheckgyroball	 = true if j.id == :GYROBALL
				end
				miniscore*=1.3 if movecheckelectroball
				miniscore*=0.5 if movecheckgyroball
				miniscore/=100.0    
				score*=miniscore
				if @battle.pbAbleNonActiveCount(user.idxOwnSide)==0
					score*=0.5
				end
				if target.hasActiveAbility?([:UNAWARE, :COMPETITIVE, :DEFIANT, :CONTRARY])
					score*=0
				end
			end
		else
			score*=0
		end
    #---------------------------------------------------------------------------
    when "RaiseUserAndAlliesAtkDef1"
      has_ally = false
      user.allAllies.each do |b|
        next if !b.pbCanLowerStatStage?(:ATTACK, user) &&
                !b.pbCanLowerStatStage?(:SPECIAL_ATTACK, user)
		next if  $game_variables[MECHANICSVAR] >= 3 && b.SetupMovesUsed.include?(move.id)
        has_ally = true
        if skill >= PBTrainerAI.mediumSkill && b.hasActiveAbility?(:CONTRARY)
          score -= 90
        else
          score += 40
          score -= b.stages[:ATTACK] * 20
          score -= b.stages[:SPECIAL_ATTACK] * 20
        end
      end
      score = 0 if !has_ally
    #---------------------------------------------------------------------------
    when "RaisePlusMinusUserAndAlliesAtkSpAtk1"
		hasEffect = user.statStageAtMax?(:ATTACK) &&
					user.statStageAtMax?(:SPECIAL_ATTACK)
		user.allAllies.each do |b|
			next if b.statStageAtMax?(:ATTACK) && b.statStageAtMax?(:SPECIAL_ATTACK)
					next if $game_variables[MECHANICSVAR] >= 3 && b.SetupMovesUsed.include?(move.id)
			hasEffect = true
			score -= b.stages[:ATTACK] * 10
			score -= b.stages[:SPECIAL_ATTACK] * 10
		end
		if hasEffect
			score -= user.stages[:ATTACK] * 10
			score -= user.stages[:SPECIAL_ATTACK] * 10
		else
			score -= 90
		end
    #---------------------------------------------------------------------------
    when "RaisePlusMinusUserAndAlliesDefSpDef1"
		bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
		maxdam = bestmove[0]
		movecheck = false
		movecheck = true if pbHasPhazingMove?(target)
		plusminus = false
		user.allAllies.each do |b|
			plusminus = true if b.hasActiveAbility?([:PLUS, :MINUS])
		end
		hasAlly = !target.allAllies.empty?
		if !(user.hasActiveAbility?([:PLUS, :MINUS]) || plusminus)
			score*=0
		else
			if user.hasActiveAbility?([:PLUS, :MINUS])
				miniscore=100
				if user.effects[PBEffects::Substitute]>0
					miniscore*=1.3
				end
				if !hasAlly && move.statusMove? && target.battle.choices[target.index][0] == :SwitchOut
					miniscore*=2
				end
				if (user.hp.to_f)/user.totalhp>0.75
					miniscore*=1.1
				end 
				if target.effects[PBEffects::HyperBeam]>0
					miniscore*=1.2
				end
				if target.effects[PBEffects::Yawn]>0
					miniscore*=1.3
				end
				if maxdam < 0.3*user.hp
					miniscore*=1.1
				end            
				if user.turnCount<2
					miniscore*=1.1
				end
				if target.pbHasAnyStatus?
					miniscore*=1.1
				end
				if target.asleep?
					miniscore*=1.3
				end
				if target.effects[PBEffects::Encore]>0
					if GameData::Move.get(target.effects[PBEffects::EncoreMove]).base_damage==0        
						miniscore*=1.3
					end          
				end  
				if user.effects[PBEffects::Confusion]>0
					miniscore*=0.5
				end
				if user.effects[PBEffects::LeechSeed]>=0 || user.effects[PBEffects::Attract]>=0
					miniscore*=0.3
				end
				if user.effects[PBEffects::Toxic]>0
					miniscore*=0.2
				end
				if movecheck
					miniscore*=0.2
				end            
				if target.hasActiveAbility?(:UNAWARE,false,mold_broken)
					miniscore*=0.5
				end
				if maxdam<0.12*user.hp
					miniscore*=0.2
				end
				score*=miniscore
				miniscore=100
				roles = pbGetPokemonRole(user, target)
				if roles.include?("Physical Wall") || roles.include?("Special Wall")
					miniscore*=1.5
				end
				if user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON, true))
					miniscore*=1.2
				end
				healmove=false
				for j in user.moves
						healmove=true if j.healingMove?
				end
				if healmove
					miniscore*=1.7
				end
				if user.pbHasMove?(:LEECHSEED)
					miniscore*=1.3
				end
				if user.pbHasMove?(:PAINSPLIT)
					miniscore*=1.2
				end        
				if user.stages[:SPECIAL_DEFENSE]!=6 && user.stages[:DEFENSE]!=6
					score*=miniscore   
				end
			else
				score*=0
			end          
		end
    #---------------------------------------------------------------------------
    when "RaiseGroundedGrassBattlersAtkSpAtk1" # Rototiller
		movecheck = false
		movecheck = true if pbHasPhazingMove?(target)
		count = 0
		@battle.allBattlers.each do |b|
			mold_bonkers=moldbroken(user,b,move)
			if b.pbHasType?(:GRASS, true) && !b.airborneAI(mold_bonkers) &&
			   (!b.statStageAtMax?(:ATTACK) || !b.statStageAtMax?(:SPECIAL_ATTACK)) && ($game_variables[MECHANICSVAR] >= 3 && !b.SetupMovesUsed.include?(move.id))
				count += 1
				if user.opposes?(b)
					score *= 0.5
				else
					if (b.hp.to_f)/b.totalhp>0.75
						score*=1.1
					end          
					if b.effects[PBEffects::LeechSeed]>=0 || b.effects[PBEffects::Attract]>=0 || 
							b.pbHasAnyStatus? || b.effects[PBEffects::Yawn]>0            
						score*=0.3
					end   
					if movecheck
						score*=0.2
					end          
					if b.hasActiveAbility?(:SIMPLE)
						score*=2
					end
					if b.hasActiveAbility?(:CONTRARY)
						score*=0
					end 
				end
			end
		end
      	score = 0 if count == 0
    #---------------------------------------------------------------------------
    when "RaiseGrassBattlersDef1" # flower shield
		movecheck = false
		movecheck = true if pbHasPhazingMove?(target)
		count = 0
		@battle.allBattlers.each do |b|
			if b.pbHasType?(:GRASS, true) && !b.statStageAtMax?(:DEFENSE) && ($game_variables[MECHANICSVAR] >= 3 && !b.SetupMovesUsed.include?(move.id))
				count += 1
				if user.opposes?(b)
					score *= 0.5
				else
					if (b.hp.to_f)/b.totalhp>0.75
						score*=1.1
					end          
					if b.effects[PBEffects::LeechSeed]>=0 || b.effects[PBEffects::Attract]>=0 || 
						b.pbHasAnyStatus? || b.effects[PBEffects::Yawn]>0            
						score*=0.3
					end   
					if movecheck
						score*=0.2
					end          
					if b.hasActiveAbility?(:SIMPLE)
						score*=2
					end
					if b.hasActiveAbility?(:CONTRARY)
						score*=0
					end 
				end
			end
		end
     	score = 0 if count == 0
    #---------------------------------------------------------------------------
    when "UserTargetSwapAtkSpAtkStages" # power swap
		stages=0
		stages+=user.stages[:ATTACK]       
		stages+=user.stages[:SPECIAL_ATTACK]
		miniscore = (-10)*stages
		if user.attack > user.spatk
			if user.stages[:ATTACK]!=0
				miniscore*=2
			end
		else
			if user.stages[:SPECIAL_ATTACK]!=0
				miniscore*=2
			end
		end
		stages=0
		stages+=target.stages[:ATTACK]       
		stages+=target.stages[:SPECIAL_ATTACK]
		minimini = (10)*stages
		if target.attack > target.spatk
			if target.stages[:ATTACK]!=0
				minimini*=2
			end
		else
			if target.stages[:SPECIAL_ATTACK]!=0
				minimini*=2
			end
		end
		if miniscore==0 && minimini==0
			score*=0
		else
			miniscore+=minimini
			miniscore+=100
			miniscore/=100.0
			score*=miniscore
			doubleTarget = !user.allAllies.empty?
			if doubleTarget
				score*=0.8
			end
		end
    #---------------------------------------------------------------------------
    when "UserTargetSwapDefSpDefStages" # guard swap
		stages=0
		stages+=user.stages[:DEFENSE]       
		stages+=user.stages[:SPECIAL_DEFENSE]
		miniscore = (-10)*stages
		if user.defense > user.spdef
			if user.stages[:DEFENSE]!=0
				miniscore*=2
			end
		else
			if user.stages[:SPECIAL_DEFENSE]!=0
				miniscore*=2
			end
		end
		stages=0
		stages+=target.stages[:DEFENSE]       
		stages+=target.stages[:SPECIAL_DEFENSE]
		minimini = (10)*stages
		if target.defense > target.spdef
			if target.stages[:DEFENSE]!=0
				minimini*=2
			end
		else
			if target.stages[:SPECIAL_DEFENSE]!=0
				minimini*=2
			end
		end
		if miniscore==0 && minimini==0
			score*=0
		else
			miniscore+=minimini
			miniscore+=100
			miniscore/=100.0
			score*=miniscore
			doubleTarget = !user.allAllies.empty?
			if doubleTarget
				score*=0.8
			end
		end
    #---------------------------------------------------------------------------
    when "UserTargetSwapStatStages" # heart swap
		stages=0
		stages+=user.stages[:ATTACK] unless user.attack<user.spatk
		stages+=user.stages[:DEFENSE] unless target.attack<target.spatk
		stages+=user.stages[:SPEED]
		stages+=user.stages[:SPECIAL_ATTACK] unless user.attack>user.spatk
		stages+=user.stages[:SPECIAL_DEFENSE] unless target.attack>target.spatk
		stages+=user.stages[:EVASION]
		stages+=user.stages[:ACCURACY]
		miniscore = (-10)*stages
		stages=0
		stages+=target.stages[:ATTACK] unless target.attack<target.spatk
		stages+=target.stages[:DEFENSE] unless user.attack<user.spatk
		stages+=target.stages[:SPEED]
		stages+=target.stages[:SPECIAL_ATTACK] unless target.attack>target.spatk
		stages+=target.stages[:SPECIAL_DEFENSE] unless user.attack>user.spatk
		stages+=target.stages[:EVASION]
		stages+=target.stages[:ACCURACY]
		minimini = (10)*stages        
		if !(miniscore==0 && minimini==0)         
			miniscore+=minimini
			miniscore+=100
			miniscore/=100.0
			score*=miniscore
			hasAlly = !target.allAllies.empty?
			if hasAlly
				score*=0.8
			end
		else
			score=0
		end
    #---------------------------------------------------------------------------
    when "UserCopyTargetStatStages" # Psych Up
		stages=0
		stages+=user.stages[:ATTACK] unless user.attack<user.spatk
		stages+=user.stages[:DEFENSE] unless target.attack<target.spatk
		stages+=user.stages[:SPEED]
		stages+=user.stages[:SPECIAL_ATTACK] unless user.attack>user.spatk
		stages+=user.stages[:SPECIAL_DEFENSE] unless target.attack>target.spatk
		stages+=user.stages[:EVASION]
		stages+=user.stages[:ACCURACY]
		miniscore = (-10)*stages
		stages=0
		stages+=target.stages[:ATTACK] unless user.attack<user.spatk
		stages+=target.stages[:DEFENSE] unless target.attack<target.spatk
		stages+=target.stages[:SPEED]
		stages+=target.stages[:SPECIAL_ATTACK] unless user.attack>user.spatk
		stages+=target.stages[:SPECIAL_DEFENSE] unless target.attack>target.spatk
		stages+=target.stages[:EVASION]
		stages+=target.stages[:ACCURACY]
		minimini = (10)*stages       
		if !(miniscore==0 && minimini==0)
			miniscore+=minimini
			miniscore+=100
			miniscore/=100.0
			score*=miniscore
		else
			score=0
		end
    #---------------------------------------------------------------------------
    when "UserStealTargetPositiveStatStages" # Spectral Thief
		if target.effects[PBEffects::Substitute]<=0
			ministat = 0
			GameData::Stat.each_battle do |s|
				next if target.stages[s.id] <= 0
				ministat += target.stages[s.id]
			end
			ministat*=(10)
			if user.hasActiveAbility?(:CONTRARY)
				ministat*=(-1)
			end
			if user.hasActiveAbility?(:SIMPLE)
				ministat*=2
			end        
			ministat+=100
			ministat/=100.0
			score*=ministat
		end
    #---------------------------------------------------------------------------
    when "InvertTargetStatStages" # Topsy-Turvy
		if target.effects[PBEffects::Substitute]<=0
			ministat=0
			ministat+=target.stages[:ATTACK] 
			ministat+=target.stages[:DEFENSE]
			ministat+=target.stages[:SPEED] 
			ministat+=target.stages[:SPECIAL_ATTACK] 
			ministat+=target.stages[:SPECIAL_DEFENSE] 
			ministat+=target.stages[:EVASION]
			ministat*=10
			# if ally,  higher score so it inverts negative stat changes
			# if enemy, higher score so it inverts positive stat changes
			if ministat>0
				ministat = 0   if !user.opposes?(target) # ally
				ministat+= 100 if user.opposes?(target) # enemy
			else
				ministat-= 100 if !user.opposes?(target) # ally
				ministat = 0   if user.opposes?(target) # enemy
			end
			ministat/=100.0
			score*=ministat
		else
			score = 0
		end
    #---------------------------------------------------------------------------
    when "ResetTargetStatStages" # clear smog
		if target.effects[PBEffects::Substitute]<=0
			miniscore=0
			miniscore+= 5*target.stages[:ATTACK] if target.stages[:ATTACK]>0
			miniscore+= 5*target.stages[:DEFENSE] if target.stages[:DEFENSE]>0
			miniscore+= 5*target.stages[:SPECIAL_ATTACK] if target.stages[:SPECIAL_ATTACK]>0
			miniscore+= 5*target.stages[:SPECIAL_DEFENSE] if target.stages[:SPECIAL_DEFENSE]>0
			miniscore+= 5*target.stages[:SPEED] if target.stages[:SPEED]>0
			miniscore+= 5*target.stages[:EVASION] if target.stages[:EVASION]>0
			minimini=0
			minimini+= 5*target.stages[:ATTACK] if target.stages[:ATTACK]<0
			minimini+= 5*target.stages[:DEFENSE] if target.stages[:DEFENSE]<0
			minimini+= 5*target.stages[:SPECIAL_ATTACK] if target.stages[:SPECIAL_ATTACK]<0
			minimini+= 5*target.stages[:SPECIAL_DEFENSE] if target.stages[:SPECIAL_DEFENSE]<0
			minimini+= 5*target.stages[:SPEED] if target.stages[:SPEED]<0
			minimini+= 5*target.stages[:ACCURACY] if target.stages[:ACCURACY]<0
			miniscore+=minimini
			miniscore+=100
			miniscore/=100.0
			score*=miniscore
			score*=1.1 if target.hasActiveAbility?([:SPEEDBOOST, :MOODY])
		end
    #---------------------------------------------------------------------------
    when "ResetAllBattlersStatStages" # haze
		miniscore = minimini = 0
		@battle.allBattlers.each do |b|
			if b.opposes?(user)
				stages=0
				GameData::Stat.each_battle do |s|
					stages+=b.stages[s.id]
				end
				minimini+= (10)*stages
			else
				stages=0
				GameData::Stat.each_battle do |s|
					stages+=b.stages[s.id]
				end
				minimini+= (-10)*stages
			end
		end
		if (miniscore==0 && minimini==0)
			if move.baseDamage <= 0
				score*=0
			end
		else
			miniscore+=minimini
			miniscore+=100
			miniscore/=100.0
			score*=miniscore
		end
		movecheck = false
		@battle.allBattlers.each do |b|
			if pbHasSetupMove?(b) && b.opposes?(user)
				movecheck = true
				break
			end
		end
		score*=0.8 if target.hasActiveAbility?([:SPEEDBOOST, :MOODY]) || movecheck
    #---------------------------------------------------------------------------
    when "StartUserSideImmunityToStatStageLowering" # mist
		minimini = 1
		if user.pbOwnSide.effects[PBEffects::Mist]==0 && !user.pbOwnSide.effects[PBEffects::StatDropImmunity]
			minimini*=1.1
			# check target for stat decreasing moves
			minimini*=1.3 if pbHasDebuffMove?(target)
		end
		score*=minimini
    #---------------------------------------------------------------------------
    when "UserSwapBaseAtkDef" # power trick
		if user.attack - user.defense >= 100
			if aspeed>ospeed || !userFasterThanTarget
				score*=1.5
			end
			if pbRoughStat(target,:ATTACK,skill)>pbRoughStat(target,:SPECIAL_ATTACK,skill)
				score*=2
			end
			healmove=false
			for j in user.moves
				if j.healingMove?
					healmove=true
				end
			end
			score*=2 if healmove
		elsif user.defense - user.attack >= 100
			if aspeed>ospeed || !userFasterThanTarget
				score*=1.5
				if user.hp==user.totalhp && ((user.hasActiveItem?(:FOCUSSASH) || user.hasActiveAbility?(:STURDY)) && !user.takesHailDamage? && !user.takesSandstormDamage?)
					score*=2
				end
			else
				score*=0
			end
		else
			score*=0.1
		end
		if user.effects[PBEffects::PowerTrick]
			score*=0.1
		end
    #---------------------------------------------------------------------------
    when "UserTargetSwapBaseSpeed" # speed swap
		if !userFasterThanTarget
			miniscore= (10)*target.stages[:SPEED]
			minimini= (-10)*user.stages[:SPEED]
			if miniscore==0 && minimini==0
				score*=0
			else
				miniscore+=minimini
				miniscore+=100
				miniscore/=100.0
				score*=miniscore
				hasAlly = !target.allAllies.empty?
				if hasAlly
					score*=0.8
				end
			end
		else
			score*=0
		end
    #---------------------------------------------------------------------------
    when "UserTargetAverageBaseAtkSpAtk" # Power Split
		if pbRoughStat(target,:ATTACK,skill) > pbRoughStat(target,:SPECIAL_ATTACK,skill)
			if user.attack > pbRoughStat(target,:ATTACK,skill)
				score*=0
			else
				miniscore = pbRoughStat(target,:ATTACK,skill) - user.attack
				miniscore+=100
				miniscore/=100.0
				if user.attack>user.spatk
					miniscore*=2
				else
					miniscore*=0.5
				end
				score*=miniscore
			end
		else
			if user.spatk > pbRoughStat(target,:SPECIAL_ATTACK,skill)
				score*=0
			else
				miniscore = pbRoughStat(target,:SPECIAL_ATTACK,skill) - user.spatk
				miniscore+=100
				miniscore/=100.0
				if user.attack<user.spatk
					miniscore*=2
				else
					miniscore*=0.5
				end
				score*=miniscore
			end
		end
    #---------------------------------------------------------------------------
    when "UserTargetAverageBaseDefSpDef" # Guard Split
		if pbRoughStat(target,:ATTACK,skill) > pbRoughStat(target,:SPECIAL_ATTACK,skill)
			if user.defense > pbRoughStat(target,:DEFENSE,skill)
				score*=0
			else
				miniscore = pbRoughStat(target,:DEFENSE,skill) - user.defense
				miniscore+=100
				miniscore/=100.0
				if user.attack>user.spatk
					miniscore*=2
				else
					miniscore*=0.5
				end
				score*=miniscore
			end
		else
			if user.spdef > pbRoughStat(target,:SPECIAL_DEFENSE,skill)
				score*=0
			else
				miniscore = pbRoughStat(target,:SPECIAL_DEFENSE,skill) - user.spdef
				miniscore+=100
				miniscore/=100.0
				if user.attack<user.spatk
					miniscore*=2
				else
					miniscore*=0.5
				end
				score*=miniscore
			end
		end
    #---------------------------------------------------------------------------
    when "UserTargetAverageHP" # pain split
		if target.effects[PBEffects::Substitute] > 0
			score = 0
		else
			ministat = target.hp + (user.hp/2.0)
			bestmove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
			maxdam = bestmove[0]
			if maxdam>ministat
				score*=0
			elsif maxdam>user.hp
				if userFasterThanTarget
					score*=2
				else
					score*=0
				end 
			else
				miniscore=(target.hp/(user.hp).to_f)
				score*=miniscore
			end
		end
    #---------------------------------------------------------------------------
    when "StartUserSideDoubleSpeed" # Tailwind
		if user.pbOwnSide.effects[PBEffects::Tailwind]>0
			score = 0
		else 
			roles = pbGetPokemonRole(user, target)
			score*=1.5
			if userFasterThanTarget && 
					!roles.include?("Lead")
				score*=0.9
				userlivecount = @battle.pbAbleNonActiveCount(user.idxOwnSide)
				if userlivecount==1
					score*=0.4
				end          
			end
			if target.hasActiveAbility?(:SPEEDBOOST)
				score*=0.5
			end
			if @battle.field.effects[PBEffects::TrickRoom]!=0
				miniscore*=0.1
			else
				movechecktrickroom=false
				for j in target.moves
					movechecktrickroom=true if j.id == :TRICKROOM
				end
				miniscore*=0.1 if movechecktrickroom
			end
			if roles.include?("Lead")
				score*=1.4
			end
		end
    #---------------------------------------------------------------------------
    when "StartSwapAllBattlersBaseDefensiveStats" # wonder room
		if @battle.field.effects[PBEffects::WonderRoom]!=0
			score=0
		else
			if user.hasActiveAbility?(:TRICKSTER)
				score*=1.3
			end
			if pbRoughStat(target,:ATTACK,skill)>pbRoughStat(target,:SPECIAL_ATTACK,skill)
				if user.defense>user.spdef
					score*=0.5
				else
					score*=2
				end
			else
				if user.defense<user.spdef
					score*=0.5
				else
					score*=2
				end
			end
			if user.attack>user.spatk
				if pbRoughStat(target,:DEFENSE,skill)>pbRoughStat(target,:SPECIAL_DEFENSE,skill)
					score*=2
				else
					score*=0.5
				end
			else
				if pbRoughStat(target,:DEFENSE,skill)<pbRoughStat(target,:SPECIAL_DEFENSE,skill)
					score*=2
				else
					score*=0.5
				end
			end
		end
    #---------------------------------------------------------------------------
    when "RaiseUserAttack2IfTargetFaints", "RaiseUserAttack3IfTargetFaints" # Fell Stinger
		if !user.statStageAtMax?(:ATTACK)
			if !targetSurvivesMove(move,user,target) && 
			   target.battle.choices[target.index][0] != :SwitchOut
				if userFasterThanTarget
					score*=30
				else
					bestTargetMove=bestMoveVsTarget(target,user,skill) # [maxdam,maxmove,maxprio,physorspec]
					maxdamTarget = bestTargetMove[0]
					if maxdamTarget>user.hp
						score*=0.5
					else
						score*=15
						bestmove=bestMoveVsTarget(user,target,skill) # [maxdam,maxmove,maxprio,physorspec]
						maxpriodam = bestmove[2]
						score*=5 if maxpriodam > 0
					end
				end
			end
		end
    #---------------------------------------------------------------------------
    end
    return score
  end
end
