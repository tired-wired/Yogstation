#define TRAITOR_HUMAN "human"
#define TRAITOR_AI	  "AI"

/datum/antagonist/traitor
	name = "Traitor"
	roundend_category = "traitors"
	antagpanel_category = "Traitor"
	job_rank = ROLE_TRAITOR
	antag_hud_name = "traitor"
	antag_moodlet = /datum/mood_event/focused
	preview_outfit = /datum/outfit/traitor
	var/special_role = ROLE_TRAITOR
	var/employer = "The Syndicate"
	var/give_objectives = TRUE
	//var/should_give_codewords = TRUE
	var/should_equip = TRUE
	var/traitor_kind = TRAITOR_HUMAN //Set on initial assignment
	var/malf = FALSE //whether or not the AI is malf (in case it's a traitor)
	var/datum/contractor_hub/contractor_hub
	var/obj/item/uplink_holder
	can_hijack = HIJACK_HIJACKER
	/// If this specific traitor has codewords, varies by faction
	var/has_codewords = FALSE

/datum/antagonist/traitor/on_gain()
	if(owner.current && iscyborg(owner.current))
		var/mob/living/silicon/robot/robot = owner.current
		if(robot.shell)
			robot.undeploy()

	if(owner.current && isAI(owner.current))
		traitor_kind = TRAITOR_AI

	if(traitor_kind == TRAITOR_AI)
		company = /datum/corporation/self
	else if(!company)
		company = pick(subtypesof(/datum/corporation/traitor))
	owner.add_employee(company)

	SSticker.mode.traitors += owner
	owner.special_role = special_role
	if(give_objectives)
		forge_traitor_objectives()
	finalize_traitor()
	RegisterSignal(owner.current, COMSIG_MOVABLE_HEAR, PROC_REF(handle_hearing))
	..()


/datum/antagonist/traitor/apply_innate_effects(mob/living/mob_override)
	. = ..()
	var/mob/living/silicon/ai/A = mob_override || owner.current
	if(istype(A) && traitor_kind == TRAITOR_AI)
		A.hack_software = TRUE
	handle_clown_mutation(owner.current, "Your training has allowed you to overcome your clownish nature, allowing you to wield weapons without harming yourself.")

/datum/antagonist/traitor/remove_innate_effects(mob/living/mob_override)
	. = ..()
	var/mob/living/silicon/ai/A = mob_override || owner.current
	if(istype(A)  && traitor_kind == TRAITOR_AI)
		A.hack_software = FALSE

/datum/antagonist/traitor/on_removal()
	//Remove malf powers.
	if(traitor_kind == TRAITOR_AI && owner.current && isAI(owner.current))
		var/mob/living/silicon/ai/A = owner.current
		A.set_zeroth_law("")
		for(var/datum/action/innate/ai/ranged/cameragun/ai_action in A.actions)
			if(ai_action.from_traitor)
				ai_action.Remove(A)
		if(malf)
			remove_verb(A, /mob/living/silicon/ai/proc/choose_modules)
			A.malf_picker.remove_malf_verbs(A)
			qdel(A.malf_picker)
	owner.remove_employee(company)
	if(uplink_holder)
		var/datum/component/uplink/uplink = uplink_holder.GetComponent(/datum/component/uplink)
		if(uplink)//remove uplink so they can't keep using it if admin abuse happens
			qdel(uplink)
	UnregisterSignal(owner.current, COMSIG_MOVABLE_HEAR)
	SSticker.mode.traitors -= owner
	if(!silent && owner.current)
		to_chat(owner.current,span_userdanger(" You are no longer the [special_role]! "))
	owner.special_role = null
	..()

/datum/antagonist/traitor/proc/handle_hearing(datum/source, list/hearing_args)
	var/message = hearing_args[HEARING_MESSAGE]
	message = GLOB.syndicate_code_phrase_regex.Replace(message, span_blue("$1"))
	message = GLOB.syndicate_code_response_regex.Replace(message, span_red("$1"))
	hearing_args[HEARING_MESSAGE] = message

/datum/antagonist/traitor/proc/add_objective(datum/objective/O)
	objectives += O

/datum/antagonist/traitor/proc/remove_objective(datum/objective/O)
	objectives -= O

/datum/antagonist/traitor/proc/forge_traitor_objectives()
	switch(traitor_kind)
		if(TRAITOR_AI)
			forge_ai_objectives()
		else
			forge_human_objectives()

/datum/antagonist/traitor/greet()
	to_chat(owner.current, span_alertsyndie("You are the [owner.special_role]."))
	owner.announce_objectives()
	if(traitor_kind == TRAITOR_AI)
		has_codewords = TRUE
	if(has_codewords)
		give_codewords()
	to_chat(owner.current, span_notice("Use the 'Traitor Info and Backstory' action at the top left in order to select a backstory and review your objectives, uplink location, and codewords!"))

/datum/antagonist/traitor/proc/finalize_traitor()
	switch(traitor_kind)
		if(TRAITOR_AI)
			add_law_zero()
			owner.current.playsound_local(get_turf(owner.current), 'sound/ambience/antag/malf.ogg', 100, FALSE, pressure_affected = FALSE)
			owner.current.grant_language(/datum/language/codespeak, TRUE, TRUE, LANGUAGE_MALF)

			var/has_action = FALSE
			for(var/datum/action/innate/ai/ranged/cameragun/ai_action in owner.current.actions)
				has_action = TRUE
				break
			if(!has_action)
				var/datum/action/innate/ai/ranged/cameragun/ability = new
				ability.from_traitor = TRUE
				ability.Grant(owner.current)

		if(TRAITOR_HUMAN)
			ui_interact(owner.current)
			owner.current.playsound_local(get_turf(owner.current), 'sound/ambience/antag/tatoralert.ogg', 100, FALSE, pressure_affected = FALSE)

/datum/antagonist/traitor/proc/give_codewords()
	if(!owner.current)
		return
	var/mob/traitor_mob=owner.current

	var/phrases = jointext(GLOB.syndicate_code_phrase, ", ")
	var/responses = jointext(GLOB.syndicate_code_response, ", ")

	to_chat(traitor_mob, "<U><B>The Syndicate have provided you with the following codewords to identify fellow agents:</B></U>")
	to_chat(traitor_mob, "<B>Code Phrase</B>: [span_blue("[phrases]")]")
	to_chat(traitor_mob, "<B>Code Response</B>: [span_red("[responses]")]")

	antag_memory += "<b>Code Phrase</b>: [span_blue("[phrases]")]<br>"
	antag_memory += "<b>Code Response</b>: [span_red("[responses]")]<br>"

	to_chat(traitor_mob, "Use the codewords during regular conversation to identify other agents. Proceed with caution, however, as everyone is a potential foe.")
	to_chat(traitor_mob, span_alertwarning("You memorize the codewords, allowing you to recognise them when heard."))

/datum/antagonist/traitor/proc/equip(silent = FALSE)
	if(traitor_kind == TRAITOR_HUMAN)
		uplink_holder = owner.equip_traitor(employer, silent, src) //yogs - uplink_holder =

/datum/antagonist/traitor/proc/assign_exchange_role()
	//set faction
	var/faction = "red"
	if(owner == SSticker.mode.exchange_blue)
		faction = "blue"

	//Assign objectives
	var/datum/objective/steal/exchange/exchange_objective = new
	exchange_objective.set_faction(faction,((faction == "red") ? SSticker.mode.exchange_blue : SSticker.mode.exchange_red))
	exchange_objective.owner = owner
	add_objective(exchange_objective)

	if(prob(20))
		var/datum/objective/steal/exchange/backstab/backstab_objective = new
		backstab_objective.set_faction(faction)
		backstab_objective.owner = owner
		add_objective(backstab_objective)

	//Spawn and equip documents
	var/mob/living/carbon/human/mob = owner.current

	var/obj/item/folder/syndicate/folder
	if(owner == SSticker.mode.exchange_red)
		folder = new/obj/item/folder/syndicate/red(mob.loc)
	else
		folder = new/obj/item/folder/syndicate/blue(mob.loc)

	var/list/slots = list (
		"backpack" = ITEM_SLOT_BACKPACK,
		"left pocket" = ITEM_SLOT_LPOCKET,
		"right pocket" = ITEM_SLOT_RPOCKET
	)

	var/where = "At your feet"
	var/equipped_slot = mob.equip_in_one_of_slots(folder, slots)
	if (equipped_slot)
		where = "In your [equipped_slot]"
	to_chat(mob, "<BR><BR><span class='info'>[where] is a folder containing <b>secret documents</b> that another Syndicate group wants. We have set up a meeting with one of their agents on station to make an exchange. Exercise extreme caution as they cannot be trusted and may be hostile.</span><BR>")

/datum/antagonist/traitor/antag_panel_data()
	// Traitor Backstory
	var/backstory_text = "<b>Traitor Backstory:</b><br>"
	if(istype(faction))
		backstory_text += "<b>Faction:</b> <span class='tooltip' style=\"font-size: 12px\">\[ [faction.name]<span class='tooltiptext' style=\"width: 320px; padding: 5px;\">[faction.description]</span> \]</span><br>"
	else
		backstory_text += "<font color='red'>No faction selected!</font><br>"
	if(istype(backstory))
		backstory_text += "<b>Backstory:</b> <span class='tooltip' style=\"font-size: 12px\">\[ [backstory.name]<span class='tooltiptext' style=\"width: 320px; padding: 5px;\">[backstory.description]</span> \]</span><br>"
	else
		backstory_text += "<font color='red'>No backstory selected!</font><br>"
	return backstory_text

//TODO Collate
/datum/antagonist/traitor/roundend_report()
	var/list/result = list()

	var/traitorwin = TRUE

	result += printplayer(owner)

	var/TC_uses = 0
	var/uplink_true = FALSE
	var/purchases = ""
	LAZYINITLIST(GLOB.uplink_purchase_logs_by_key)
	var/datum/uplink_purchase_log/H = GLOB.uplink_purchase_logs_by_key[owner.key]
	if(H)
		TC_uses = H.total_spent
		uplink_true = TRUE
		purchases += H.generate_render(FALSE)

	var/objectives_text = ""
	if(objectives.len)//If the traitor had no objectives, don't need to process this.
		var/count = 1
		for(var/datum/objective/objective in objectives)
			if(objective.optional)
				objectives_text += "<br><B>Objective #[count]</B>: [objective.explanation_text] [span_greentext("Optional.")]"
			else if(objective.check_completion())
				objectives_text += "<br><B>Objective #[count]</B>: [objective.explanation_text] [span_greentext("Success!")]"
			else
				objectives_text += "<br><B>Objective #[count]</B>: [objective.explanation_text] [span_redtext("Fail.")]"
				traitorwin = FALSE
			count++

	if(uplink_true)
		var/uplink_text = "(used [TC_uses] TC) [purchases]"
		if(TC_uses==0 && traitorwin)
			var/static/icon/badass = icon('icons/badass.dmi', "badass")
			uplink_text += "<BIG>[icon2html(badass, world)]</BIG>"
			SSachievements.unlock_achievement(/datum/achievement/badass, owner.current.client)
		result += uplink_text

	result += objectives_text

	var/backstory_text = "<br>"
	if(istype(faction))
		backstory_text += "<b>Faction:</b> <span class='tooltip_container' style=\"font-size: 12px\">\[ [faction.name]<span class='tooltip_hover' style=\"width: 320px; padding: 5px;\">[faction.description]</span> \]</span><br>"
	if(istype(backstory))
		backstory_text += "<b>Backstory:</b> <span class='tooltip_container' style=\"font-size: 12px\">\[ [backstory.name]<span class='tooltip_hover' style=\"width: 320px; padding: 5px;\">[backstory.description]</span> \]</span><br>"
	else
		backstory_text += "<span class='redtext'>No backstory was selected!</span><br>"
	result += backstory_text

	var/special_role_text = lowertext(name)

	if (contractor_hub)
		result += contractor_round_end()

	if(traitorwin)
		result += span_greentext("The [special_role_text] was successful!")
	else
		result += span_redtext("The [special_role_text] has failed!")
		SEND_SOUND(owner.current, 'sound/ambience/ambifailure.ogg')

	return result.Join("<br>")

/// Proc detailing contract kit buys/completed contracts/additional info
/datum/antagonist/traitor/proc/contractor_round_end()
	var result = ""
	var total_spent_rep = 0

	var/completed_contracts = contractor_hub.contracts_completed
	var/tc_total = contractor_hub.contract_TC_payed_out + contractor_hub.contract_TC_to_redeem

	var/contractor_item_icons = "" // Icons of purchases
	var/contractor_support_unit = "" // Set if they had a support unit - and shows appended to their contracts completed

	/// Get all the icons/total cost for all our items bought
	for (var/datum/contractor_item/contractor_purchase in contractor_hub.purchased_items)
		contractor_item_icons += span_tooltip_container("\[ <i class=\"fas [contractor_purchase.item_icon]\"></i><span class='tooltip_hover'><b>[contractor_purchase.name] - [contractor_purchase.cost] Rep</b><br><br>[contractor_purchase.desc]</span> \]")

		total_spent_rep += contractor_purchase.cost

		/// Special case for reinforcements, we want to show their ckey and name on round end.
		if (istype(contractor_purchase, /datum/contractor_item/contractor_partner))
			var/datum/contractor_item/contractor_partner/partner = contractor_purchase
			contractor_support_unit += "<br><b>[partner.partner_mind.key]</b> played <b>[partner.partner_mind.current.name]</b>, their contractor support unit."

	if (contractor_hub.purchased_items.len)
		result += "<br>(used [total_spent_rep] Rep) "
		result += contractor_item_icons
	result += "<br>"
	if (completed_contracts > 0)
		var/pluralCheck = "contract"
		if (completed_contracts > 1)
			pluralCheck = "contracts"

		result += "Completed [span_greentext("[completed_contracts]")] [pluralCheck] for a total of \
					[span_greentext("[tc_total] TC")]![contractor_support_unit]<br>"

	return result

/datum/antagonist/traitor/roundend_report_footer()
	var/phrases = jointext(GLOB.syndicate_code_phrase, ", ")
	var/responses = jointext(GLOB.syndicate_code_response, ", ")

	var message = "<br><b>The code phrases were:</b> <span class='bluetext'>[phrases]</span><br>\
								<b>The code responses were:</b> <span class='redtext'>[responses]</span><br>"

	return message

/datum/antagonist/traitor/is_gamemode_hero()
	return SSticker.mode.name == "traitor"

/datum/outfit/traitor
	name = "Traitor (Preview only)"
	uniform = /obj/item/clothing/under/color/grey
	suit = /obj/item/clothing/suit/armor/laserproof
	gloves = /obj/item/clothing/gloves/color/yellow
	mask = /obj/item/clothing/mask/gas
	l_hand = /obj/item/melee/transforming/energy/sword
	r_hand = /obj/item/gun/energy/kinetic_accelerator/crossbow
	head = /obj/item/clothing/head/helmet

/datum/outfit/traitor/post_equip(mob/living/carbon/human/H, visualsOnly)
	var/obj/item/melee/transforming/energy/sword/sword = locate() in H.held_items
	sword.transform_weapon(H)
