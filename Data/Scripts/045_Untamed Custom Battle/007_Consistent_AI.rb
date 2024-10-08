class Battle::AI
	$AIMASTERLOG = false
	$AIGENERALLOG = true
	# need testing:
	# topsy turby, instruct, gastro acid, floral healing, frost breath
	$movesToTargetAllies = ["HitThreeTimesAlwaysCriticalHit", "AlwaysCriticalHit",
							"RaiseTargetAttack2ConfuseTarget", "RaiseTargetSpAtk1ConfuseTarget", 
							"RaiseTargetAtkSpAtk2", "InvertTargetStatStages",
							"TargetUsesItsLastUsedMoveAgain",
							"SetTargetAbilityToSimple", "SetTargetAbilityToUserAbility",
							"SetUserAbilityToTargetAbility", "SetTargetAbilityToInsomnia",
							"UserTargetSwapAbilities", "NegateTargetAbility", 
							"RedirectAllMovesToTarget", "HitOncePerUserTeamMember", 
							"HealTargetDependingOnGrassyTerrain", "CureTargetStatusHealUserHalfOfTotalHP",
							"HealTargetHalfOfTotalHP", "HealAllyOrDamageFoe"] 
	#=============================================================================
	# Main move-choosing method (moves with higher scores are more likely to be
	# chosen)
	#=============================================================================
	def pbChooseMoves(idxBattler)
		user        = @battle.battlers[idxBattler]
		wildBattler = user.wild? && !user.isBossPokemon?
		skill       = 100
		# if !wildBattler
		# 	skill     = @battle.pbGetOwnerFromBattlerIndex(user.index).skill_level || 0
		# end
		# Get scores and targets for each move
		# NOTE: A move is only added to the choices array if it has a non-zero
		#       score.
		choices     = []
		user.eachMoveWithIndex do |_m, i|
			next if !@battle.pbCanChooseMove?(idxBattler, i, false)
			if MEGA_EVO_MOVESET.key?(user.species) && $game_variables[MECHANICSVAR] >= 2
				oldmove = MEGA_EVO_MOVESET[user.species][0]
				newmove = MEGA_EVO_MOVESET[user.species][1]
				if _m.id == oldmove
					user.moves[i] = Battle::Move.from_pokemon_move(@battle, Pokemon::Move.new(newmove))
					user.moves[i].pp       = 5
					user.moves[i].total_pp = 5
				end
			end
			if wildBattler
				pbRegisterMoveWild(user, i, choices)
			else
				pbRegisterMoveTrainer(user, i, choices, skill)
			end
		end
		if $AIGENERALLOG
			echo("\nChoices and scores:\n") #for: "+user.name+"\n")
			Console.echo_h2(choices)
			echo("------------------------\n")#----------------\n")
		end
		# Figure out useful information about the choices
		totalScore = 0
		maxScore   = 0
		choices.each do |c|
			totalScore += c[1]
			echoln("#{c[3]} : #{c[1].to_s}") if !wildBattler && $AIGENERALLOG
			maxScore = c[1] if maxScore < c[1]
		end
		# Log the available choices
		if $INTERNAL || $AIGENERALLOG
			logMsg = "[AI] Move choices for #{user.pbThis(true)} (#{user.index}): "
			choices.each_with_index do |c, i|
				logMsg += "#{user.moves[c[0]].name}=#{c[1]}"
				logMsg += " (target #{c[2]})" if c[2] >= 0
				logMsg += ", " if i < choices.length - 1
			end
			PBDebug.log(logMsg)
		end
		if $AIMASTERLOG # master debug by JZ, ported #by low
			move_keys = GameData::Move.keys
			bestscore = [["Splash",0]]
			move_keys.each do |i|
				mirrored = Pokemon::Move.new(i)
				mirrmove = Battle::Move.from_pokemon_move(@battle, mirrored)
				next if mirrored==nil
				target = user.pbDirectOpposing
				case mirrmove.category
				when 0 then moveCateg = "Physical"
				when 1 then moveCateg = "Special"
				when 2 then moveCateg = "Status"
				end
				
				score = 50 # for damaging moves
				functionscore = pbGetMoveScoreFunctionCode(score, mirrmove, user, target, skill)
				bsdam = mirrmove.baseDamage
				bsdiv = 10.0/bsdam
				functionscore *= bsdiv if mirrmove.baseDamage>50
				score += functionscore
				accuracy = pbRoughAccuracy(mirrmove, user, target, skill)
				accuracy *= 1.15 if !user.pbOwnedByPlayer?
				accuracy = 100 if accuracy>100
				if mirrmove.damagingMove?
					dmgScore = pbGetMoveScoreDamage(score, mirrmove, user, target, skill)
					dmgScore -= 100-accuracy*1.33 if accuracy < 100
				else   # Status moves
					dmgScore = pbStatusDamage(mirrmove) # each status move now has a value tied to them #by low
					dmgScore = pbGetMoveScoreFunctionCode(dmgScore, mirrmove, user, target, skill)
					dmgScore *= accuracy / 100.0
				end
				File.open("AI_master_log.txt", "a") do |line|
					line.puts "Move " + mirrored.name.to_s + " ( Category: " + moveCateg + " ) " + " has final score " + dmgScore.to_s
				end
				bestscore.push([mirrored.name.to_s, dmgScore])
			end
			sortedscores = bestscore.sort { |a, b| b[1] <=> a[1] }
			File.open("AI_scoreboard.txt", "a") do |line|
				for i in 0..sortedscores.length
					next if sortedscores[i].nil?
					line.puts "Move " + sortedscores[i][0].to_s + " has the final score " + sortedscores[i][1].to_s
				end
			end
		end
		# Find any preferred moves and just choose from them
		if !wildBattler && maxScore > 100
			#stDev = pbStdDev(choices)
			#if stDev >= 40 && pbAIRandom(100) < 90
			# DemICE removing randomness of AI
			preferredMoves = []
			choices.each do |c|
				next if c[1] < 200 && c[1] < maxScore * 0.8
				#preferredMoves.push(c)
				# DemICE prefer ONLY the best move
				preferredMoves.push(c) if c[1] == maxScore   # Doubly prefer the best move
				echoln(preferredMoves)
			end
			if preferredMoves.length > 0
				m = preferredMoves[pbAIRandom(preferredMoves.length)]
				PBDebug.log("[AI] #{user.pbThis} (#{user.index}) prefers #{user.moves[m[0]].name}")
				@battle.pbRegisterMove(idxBattler, m[0], false)
				@battle.pbRegisterTarget(idxBattler, m[2]) if m[2] >= 0
				return
			end
			#end
		end
		# Decide whether all choices are bad, and if so, try switching instead
		if !wildBattler
			badMoves = false
			if ((maxScore <= 20 && user.turnCount >= 1) ||
				(maxScore <= 45 && user.turnCount > 3))
				badMoves = true
			end
			if !badMoves && totalScore < 100
				badMoves = true
				choices.each do |c|
					next if !user.moves[c[0]].damagingMove?
					badMoves = false
					break
				end
			end
			if badMoves && pbEnemyShouldWithdrawEx?(idxBattler, true)
				if $INTERNAL
					PBDebug.log("[AI] #{user.pbThis} (#{user.index}) will switch due to terrible moves")
				end
				return
			end
		end
		# If there are no calculated choices, pick one at random
		if choices.length == 0
			PBDebug.log("[AI] #{user.pbThis} (#{user.index}) doesn't want to use any moves; picking one at random")
			user.eachMoveWithIndex do |_m, i|
				next if !@battle.pbCanChooseMove?(idxBattler, i, false)
				choices.push([i, 100, -1])   # Move index, score, target
			end
			if choices.length == 0   # No moves are physically possible to use; use Struggle
				@battle.pbAutoChooseMove(user.index)
			end
		end
		bestScore = ["Splash",0]
		choices.each do |c|
			if bestScore[1] < c[1]
				bestScore[1] = c[1]
				bestScore[0] = c[0]
			end
		end
		if bestScore[1] <= 40
			# Randomly choose a move from the choices and register it (in case everything sucks)
			randNum = pbAIRandom(totalScore)
			choices.each do |c|
				randNum -= c[1]
				next if randNum >= 0
				@battle.pbRegisterMove(idxBattler, c[0], false)
				@battle.pbRegisterTarget(idxBattler, c[2]) if c[2] >= 0
				break
			end
		else
			# Choose the best move possible always (if one thing does not suck)
			choices.each do |c|
				next if bestScore[0] != c[0]
				@battle.pbRegisterMove(idxBattler, c[0], false)
				@battle.pbRegisterTarget(idxBattler, c[2]) if c[2] >= 0
			end
		end
		# Log the result
		if @battle.choices[idxBattler][2]
			PBDebug.log("[AI] #{user.pbThis} (#{user.index}) will use #{@battle.choices[idxBattler][2].name}")
		end
	end
  
	#=============================================================================
	# Get a score for the given move being used against the given target
	#=============================================================================
	def pbGetMoveScore(move, user, target, skill = 100, roughdamage = 10)
		skill = 100
		score = pbGetMoveScoreFunctionCode(50, move, user, target, skill)
		# A score of 0 here means it absolutely should not be used
		return 0 if score <= 0 && !$movesToTargetAllies.include?(move.function)
		# Adjust score based on how much damage it can deal
		#DemICE moved damage calculation to the beginning
		# Account for accuracy of move
		accuracy = pbRoughAccuracy(move, user, target, skill)
		accuracy *= 1.15 if !user.pbOwnedByPlayer?
		accuracy = 100 if accuracy>100
		if move.damagingMove?
			score = pbGetMoveScoreDamage(score, move, user, target, skill)
			score -= 100-accuracy*1.33 if accuracy < 100
		else # Status moves
			score = pbStatusDamage(move) # each status move now has a value tied to them #by low
			score = pbGetMoveScoreFunctionCode(score, move, user, target, skill)
			score *= accuracy / 100.0
		end
		aspeed = pbRoughStat(user,:SPEED,100)
		ospeed = pbRoughStat(target,:SPEED,100)
		if skill >= PBTrainerAI.mediumSkill
			# Converted all score alterations to multiplicative
			# Don't prefer attacking the target if they'd be semi-invulnerable
			if skill >= PBTrainerAI.highSkill && move.accuracy > 0 &&
				 (target.semiInvulnerable? || target.effects[PBEffects::SkyDrop] >= 0)
				miss = true
				miss = false if user.hasActiveAbility?(:NOGUARD) || target.hasActiveAbility?(:NOGUARD)
				miss = false if ((aspeed<=ospeed) ^ (@battle.field.effects[PBEffects::TrickRoom]>0)) && priorityAI(user,move)<1 # DemICE
				if miss && pbRoughStat(user, :SPEED, skill) > pbRoughStat(target, :SPEED, skill)
					# Knows what can get past semi-invulnerability
					if target.effects[PBEffects::SkyDrop] >= 0 ||
						 target.inTwoTurnAttack?("TwoTurnAttackInvulnerableInSky",
												 "TwoTurnAttackInvulnerableInSkyParalyzeTarget",
												 "TwoTurnAttackInvulnerableInSkyTargetCannotAct")
						miss = false if move.hitsFlyingTargets?
					elsif target.inTwoTurnAttack?("TwoTurnAttackInvulnerableUnderground")
						miss = false if move.hitsDiggingTargets?
					elsif target.inTwoTurnAttack?("TwoTurnAttackInvulnerableUnderwater")
						miss = false if move.hitsDivingTargets?
					end
				end
				score *= 0.2 if miss
			end
			# Pick a good move for the Choice items
			if user.hasActiveItem?([:CHOICEBAND, :CHOICESPECS, :CHOICESCARF]) ||
			   user.hasActiveAbility?(:GORILLATACTICS)
				if move.baseDamage >= 60
					score *= 1.2
				elsif move.damagingMove?
					score *= 1.2
				elsif move.function == "UserTargetSwapItems"
					score *= 1.2  # Trick
				else
					score *= 0.8
				end
			end
			# If user is asleep, prefer moves that are usable while asleep
			if user.status == :SLEEP && !move.usableWhenAsleep? && user.statusCount==1 # DemICE check if it'll wake up this turn
				user.eachMove do |m|
					next unless m.usableWhenAsleep?
					score *= 2
					break
				end
			end
			# truant can, in fact, do something when loafing around
			if user.hasActiveAbility?(:TRUANT) && user.effects[PBEffects::Truant]
				user.eachMove do |m|
					next unless m.healingMove?
					score *= 2
					break
				end
			end
		end
		# Don't prefer moves that are ineffective because of abilities or effects
		return 0 if pbCheckMoveImmunity(score, move, user, target, skill)
		score = score.to_i
		score = 0 if score < 0 && !$movesToTargetAllies.include?(move.function)
		return score
	end

	#=============================================================================
	# Add to a move's score based on how much damage it will deal (as a percentage
	# of the target's current HP)
	#=============================================================================
	def pbGetMoveScoreDamage(score, move, user, target, skill)
		return 0 if (score <= 0 && !($movesToTargetAllies.include?(move.function) && !user.opposes?(target)))
		# Calculate how much damage the move will do (roughly)
		baseDmg = pbMoveBaseDamage(move, user, target, skill)
		realDamage = pbRoughDamage(move, user, target, skill, baseDmg)
		# Account for accuracy of move
		accuracy = pbRoughAccuracy(move, user, target, skill)
		accuracy *= 1.15 if !user.pbOwnedByPlayer?
		accuracy = 100 if accuracy > 100
		realDamage *= accuracy / 100.0 # DemICE
		# Two-turn attacks waste 2 turns to deal one lot of damage
		if ((["TwoTurnAttackFlinchTarget", "TwoTurnAttackParalyzeTarget", 
			  "TwoTurnAttackBurnTarget", "TwoTurnAttackChargeRaiseUserDefense1", "TwoTurnAttack", 
			  "AttackTwoTurnsLater", "TwoTurnAttackChargeRaiseUserSpAtk1"].include?(move.function) ||
			  (move.function=="TwoTurnAttackOneTurnInSun" && user.effectiveWeather!=:Sun)) && !user.hasActiveItem?(:POWERHERB)) ||
			move.function == "AttackAndSkipNextTurn"
		  realDamage *= 2 / 3   # Not halved because semi-invulnerable during use or hits first turn
		end
		# Prefer flinching external effects (note that move effects which cause
		# flinching are dealt with in the function code part of score calculation)
		mold_broken=moldbroken(user,target,move)
		if skill >= PBTrainerAI.mediumSkill 
			# not a fan of randomness one bit, but i cant do much about this move
			if user.lastMoveUsed == :SUCKERPUNCH && move.function == "FailsIfTargetActed" # Sucker Punch
				if @battle.choices[target.index][0]!=:UseMove
					chance=80
					if pbAIRandom(100) < chance	
						# Try play "mind games" instead of just getting baited every time.
						echo("\n'Predicting' that opponent will not attack and sucker will fail")
						score=1
						realDamage=0
					end
				else
					if @battle.choices[target.index][1]
						if !@battle.choices[target.index][2].damagingMove? && pbAIRandom(100) < 50	
							# Try play "mind games" instead of just getting baited every time.
							echo("\n'Predicting' that opponent will not attack and sucker will fail")
							score=1
							realDamage=0 
						end
					end
				end
			end
			# Try make AI not trolled by disguise
			if !mold_broken && target.hasActiveAbility?(:DISGUISE) && target.turnCount==0	
				if ["HitTwoToFiveTimes", "HitTwoTimes", "HitThreeTimes" ,"HitTwoTimesFlinchTarget", 
						"HitThreeTimesPowersUpWithEachHit"].include?(move.function)
					realDamage*=2.2
				end
			end	
			if ((!target.hasActiveAbility?(:INNERFOCUS) && !target.hasActiveAbility?(:SHIELDDUST)) || 
				 mold_broken) && target.effects[PBEffects::Substitute]==0
				canFlinch = false
				if user.hasActiveItem?([:KINGSROCK,:RAZORFANG])
					canFlinch = true
				end
				if user.hasActiveAbility?(:STENCH) || move.flinchingMove?
					canFlinch = true
				end
				canFlinch = false if target.effects[PBEffects::NoFlinch] > 0
				bestmove=bestMoveVsTarget(user,target,skill) # [maxdam,maxmove,maxprio,physorspec]
				maxdam=bestmove[0] #* 0.9
				maxmove=bestmove[1]
				if targetSurvivesMove(maxmove,user,target) && canFlinch
					realDamage *= 1.2 if (realDamage *100.0 / maxdam) > 75
					realDamage *= 1.2 if move.function=="HitTwoTimesFlinchTarget"
					realDamage*=2 if user.hasActiveAbility?(:SERENEGRACE)
				end
			end
		end
		if $AIMASTERLOG
			File.open("AI_master_log.txt", "a") do |line|
				line.puts "Move " + move.name + " real damage on "+target.name+": "+realDamage.to_s
			end
		end
		# Convert damage to percentage of target's remaining HP
		damagePercentage = realDamage * 100.0 / target.hp
		# Don't prefer weak attacks
	    damagePercentage *= 0.5 if damagePercentage < 30
		# Prefer status moves if level difference is significantly high
		damagePercentage *= 0.5 if user.level - 3 > target.level
		if $AIGENERALLOG
			echo("\n-----------------------------")
			echo("\n#{move.name} real dmg = #{realDamage}")
			echo("\n#{move.name} dmg percent = #{damagePercentage}")
		end
		# Adjust score
		if damagePercentage > 100   # Treat all lethal moves the same   # DemICE
			damagePercentage = 110 
			if ["RaiseUserAttack3IfTargetFaints"].include?(move.function) # DemICE: Fell Stinger should be preferred among other moves that KO
				if user.hasActiveAbility?(:CONTRARY)
					damagePercentage-=90    
				else
					damagePercentage+=50    
				end
			end
			if ["HealUserByHalfOfDamageDone","HealUserByThreeQuartersOfDamageDone"].include?(move.function) ||
				(move.function == "HealUserByHalfOfDamageDoneIfTargetAsleep" && target.asleep?)
				missinghp = (user.totalhp-user.hp) *100.0 / user.totalhp
				damagePercentage += missinghp*0.5
			end
		end  
		damagePercentage -= 1 if accuracy < 100  # DemICE
		damagePercentage += 40 if damagePercentage > 100   # Prefer moves likely to be lethal  # DemICE
		score += damagePercentage.to_i
		echo("\n#{move.name} score = #{score}") if $AIGENERALLOG
		if $AIMASTERLOG
			File.open("AI_master_log.txt", "a") do |line|
				line.puts "Move " + move.name + " damage % on "+target.name+": "+damagePercentage.to_s
			end
		end
		return score
	end
end