class Camping
	
	def self.resetAwakeness(pkmn)
		pkmn.campAwakeness = Graphics.frame_rate * 120 #two minutes
	end #def self.resetAwakeness(pkmn)
	
	def self.pkmnStartNap(pkmn)
		pkmn.campNapping = true
		#set move type to fixed so the pkmn stops roaming
		pkmn.campEvent.move_type = 0
		#turn off step animation
		pbMoveRoute(pkmn.campEvent, [PBMoveRoute::StepAnimeOff])
		self.showEventAnimation(pkmn.campEvent.id, animation_id=20)
		pbSEPlay("FollowEmote",100,80)
	end #def self.pkmnStartNap
	
	def self.pkmnStopNap(pkmn)
		self.resetAwakeness(pkmn)
		pkmn.campNapping = false
		#set move type to fixed so the pkmn starts roaming
		pkmn.campEvent.move_type = 1
		#turn on step animation
		pbMoveRoute(pkmn.campEvent, [PBMoveRoute::StepAnimeOn])
		#exclamation point emote
		self.showEventAnimation(pkmn.campEvent.id, animation_id=3)
	end #self.pkmnStopNap(pkmn)
	
	#####################################
	#####      Event Handlers       #####
	#####################################
	#show hunger or sleep emote
	EventHandlers.add(:on_frame_update, :pkmn_emote_in_camp, proc {
		next if !$PokemonGlobal.camping
		next if $PokemonGlobal.playingHideAndSeek
		
		#subtract from awakeness timer on each pkmn
		#pkmn should fall asleep after 2 minutes of no interaction with the player or other pkmn
		for i in 0...$PokemonGlobal.campers.length
			pkmn = $PokemonGlobal.campers[i]
			self.resetAwakeness(pkmn) if pkmn.campAwakeness.nil?
			next if pkmn.campAwakeness <= 0
			pkmn.campAwakeness -= 1
		end #for i in 0...$PokemonGlobal.campers.length
		
		#hunger emote
		for i in 0...$PokemonGlobal.campers.length
			pkmn = $PokemonGlobal.campers[i]
			#show hunger emote if hungry instead of showing sleep emote
			#can't go to bed hungry :)
			#check if each pkmn is hungry - pkmn.amie_fullness - range is 0 to 255
			next if pkmn.amie_fullness.nil?
			next if pkmn.campHungerEmoteTimer.nil?
			if pkmn.amie_fullness <= 0 && pkmn.campHungerEmoteTimer <= 0
				self.showEventAnimation(pkmn.campEvent.id, animation_id=19)
				next #don't show sleep timer if hungry. We don't want to show both hunger and sleep emotes within the emoteTimer window
			end #if pkmn.amie_fullness <= 0
		
			#pkmn starts napping if not already napping and awakeness is <= 0
			if pkmn.campAwakeness <= 0 && !pkmn.campNapping && pkmn.amie_fullness > 0
				self.pkmnStartNap(pkmn)
			end #if pkmn.campAwakeness <= 0
		end #for i in 0...$PokemonGlobal.campers.length
		
		#subtract from campHungerEmoteTimer
		for i in 0...$PokemonGlobal.campers.length
			pkmn = $PokemonGlobal.campers[i]
			next if pkmn.campHungerEmoteTimer.nil?
			#don't subtract from hunger timer if napping
			next if pkmn.campNapping
			#reset emote timer if <= 0
			pkmn.campHungerEmoteTimer = pkmn.campHungerEmoteTimerPermanent if pkmn.campHungerEmoteTimer.nil? || pkmn.campHungerEmoteTimer <= 0
			pkmn.campHungerEmoteTimer -= 1
		end #for i in 0...$PokemonGlobal.campers.length
		
		#subtract from campNappingEmoteTimer
		for i in 0...$PokemonGlobal.campers.length
			pkmn = $PokemonGlobal.campers[i]
			#don't subtract from napping emote timer if not napping
			next if !pkmn.campNapping
			#reset emote timer if <= 0
			pkmn.campNappingEmoteTimer = Graphics.frame_rate*15 if pkmn.campNappingEmoteTimer.nil? || pkmn.campNappingEmoteTimer <= 0
			pkmn.campNappingEmoteTimer -= 1
		end #for i in 0...$PokemonGlobal.campers.length
		
		#show sleep emote if napping
		for i in 0...$PokemonGlobal.campers.length
			pkmn = $PokemonGlobal.campers[i]
			next if !pkmn.campNapping
			next if pkmn.campNappingEmoteTimer.nil?
			self.showEventAnimation(pkmn.campEvent.id, animation_id=20) if pkmn.campNappingEmoteTimer <= 0			
		end #for i in 0...$PokemonGlobal.campers.length
	})

end #class Camping