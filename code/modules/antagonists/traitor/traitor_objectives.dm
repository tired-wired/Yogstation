/datum/antagonist/traitor/proc/forge_human_objectives()
	var/is_hijacker = FALSE
	if (GLOB.joined_player_list.len >= 30) // Less murderboning on lowpop thanks
		is_hijacker = prob(10)
	var/martyr_chance = prob(20)
	var/objective_count = is_hijacker 			//Hijacking counts towards number of objectives
	if(!SSticker.mode.exchange_blue && SSticker.mode.traitors.len >= 6) 	//Set up an exchange if there are enough traitors. YOGSTATION CHANGE: 8 TO 6.
		if(!SSticker.mode.exchange_red)
			SSticker.mode.exchange_red = owner
		else
			SSticker.mode.exchange_blue = owner
			assign_exchange_role(SSticker.mode.exchange_red)
			assign_exchange_role(SSticker.mode.exchange_blue)
		objective_count += 1					//Exchange counts towards number of objectives
	var/toa = CONFIG_GET(number/traitor_objectives_amount)
	for(var/i = objective_count, i < toa, i++)
		forge_single_human_objective()

	forge_single_human_optional()

	if(is_hijacker && objective_count <= toa) //Don't assign hijack if it would exceed the number of objectives set in config.traitor_objectives_amount
		//Start of Yogstation change: adds /datum/objective/sole_survivor
		if(!(locate(/datum/objective/hijack) in objectives) && !(locate(/datum/objective/hijack/sole_survivor) in objectives))
			if(SSticker.mode.has_hijackers)
				var/datum/objective/hijack/sole_survivor/survive_objective = new
				survive_objective.owner = owner
				add_objective(survive_objective)
			else
				var/datum/objective/hijack/hijack_objective = new
				hijack_objective.owner = owner
				add_objective(hijack_objective)
			SSticker.mode.has_hijackers = TRUE
			return
		//End of yogstation change.

	var/martyr_compatibility = 1 //You can't succeed in stealing if you're dead.
	for(var/datum/objective/O in objectives)
		if(!O.martyr_compatible)
			martyr_compatibility = 0
			break

	if(martyr_compatibility && martyr_chance)
		var/datum/objective/martyr/martyr_objective = new
		martyr_objective.owner = owner
		add_objective(martyr_objective)
		return

	else
		if(prob(50))
			//Give them a minor flavour objective
			var/list/datum/objective/minor/minorObjectives = subtypesof(/datum/objective/minor)
			var/datum/objective/minor/minorObjective
			while(!minorObjective && minorObjectives.len)
				var/typePath = pick_n_take(minorObjectives)
				minorObjective = new typePath
				minorObjective.owner = owner
				if(!minorObjective.finalize())
					qdel(minorObjective)
					minorObjective = null
			if(minorObjective)
				add_objective(minorObjective)
		if(!(locate(/datum/objective/escape) in objectives))
			if(prob(70)) //doesn't always need to escape
				var/datum/objective/escape/escape_objective = new
				escape_objective.owner = owner
				add_objective(escape_objective)
			else
				forge_single_human_objective()

/datum/antagonist/traitor/proc/forge_single_human_optional() //adds this for if/when soft-tracked objectives are added, so they can be a 50/50
	var/datum/objective/gimmick/gimmick_objective = new
	gimmick_objective.owner = owner
	gimmick_objective.find_target()
	add_objective(gimmick_objective) //Does not count towards the number of objectives, to allow hijacking as well

/datum/antagonist/traitor/proc/forge_single_human_objective() //Returns how many objectives are added
	.=1
	if(prob(50))
		var/list/active_ais = active_ais()
		if(active_ais.len && prob(100/GLOB.joined_player_list.len))
			var/datum/objective/destroy/destroy_objective = new
			destroy_objective.owner = owner
			destroy_objective.find_target()
			add_objective(destroy_objective)
		else
			var/N = pick(/datum/objective/assassinate/cloned, /datum/objective/assassinate/once, /datum/objective/assassinate, /datum/objective/maroon, /datum/objective/maroon_organ)
			var/datum/objective/kill_objective = new N
			kill_objective.owner = owner
			kill_objective.find_target()
			add_objective(kill_objective)
	else
		if(prob(50))
			var/datum/objective/steal/steal_objective = new
			steal_objective.owner = owner
			steal_objective.find_target()
			add_objective(steal_objective)
		else
			var/datum/objective/break_machinery/break_objective = new
			break_objective.owner = owner
			if(break_objective.finalize())
				add_objective(break_objective)
			else
				forge_single_human_objective()
