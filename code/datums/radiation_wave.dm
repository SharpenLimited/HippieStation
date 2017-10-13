/datum/radiation_wave
	var/turf/master_turf //The center of the wave
	var/steps=0 //How far we've moved
	var/intensity //How strong it was originaly
	var/range_modifier //Higher than 1 makes it drop off faster, 0.5 makes it drop off half etc
	var/move_dir //The direction of movement
	var/list/__dirs //The directions to the side of the wave, stored for easy looping
	var/can_contaminate

/datum/radiation_wave/New(turf/place, dir, _intensity=0, _range_modifier=RAD_DISTANCE_COEFFICIENT, _can_contaminate=TRUE)
	master_turf = place

	move_dir = dir
	__dirs = list()
	__dirs+=turn(dir, 90)
	__dirs+=turn(dir, -90)

	intensity = _intensity
	range_modifier = _range_modifier
	can_contaminate = _can_contaminate

	START_PROCESSING(SSradiation, src)

/datum/radiation_wave/Destroy()
	STOP_PROCESSING(SSradiation, src)
	return ..()

/datum/radiation_wave/process()
	master_turf = get_step(master_turf, move_dir)
	steps++
	var/list/atoms = get_rad_atoms()

	var/strength
	if(steps>1)
		strength = InverseSquareLaw(intensity, max(range_modifier*steps, 1), 1)
	else
		strength = intensity

	if(strength<RAD_BACKGROUND_RADIATION)
		qdel(src)
		return

	radiate(atoms, Floor(strength))

	check_obstructions(atoms) // reduce our overall strength if there are radiation insulators

/datum/radiation_wave/proc/get_rad_atoms()
	var/list/atoms = list()
	var/distance = steps
	var/cmove_dir = move_dir
	var/cmaster_turf = master_turf

	if(cmove_dir == NORTH || cmove_dir == SOUTH)
		distance-- //otherwise corners overlap

	atoms += get_rad_contents(cmaster_turf)

	var/turf/place
	for(var/dir in __dirs) //There should be just 2 dirs in here, left and right of the direction of movement
		place = cmaster_turf
		for(var/i in 1 to distance)
			place = get_step(place, dir)
			atoms += get_rad_contents(place)

	return atoms

/datum/radiation_wave/proc/check_obstructions(list/atoms)
	var/width = steps
	var/cmove_dir = move_dir
	if(cmove_dir == NORTH || cmove_dir == SOUTH)
		width--
	width = 1+(2*width)

	for(var/k in 1 to atoms.len)
		var/atom/thing = atoms[k]
		if(!thing)
			continue
		var/datum/component/rad_insulation/insulation = thing.GetComponent(/datum/component/rad_insulation)
		if(!insulation)
			continue
		intensity = intensity*(1-((1-insulation.amount)/width)) // The further out the rad wave goes the less it's affected by insulation

/datum/radiation_wave/proc/radiate(list/atoms, strength)
	for(var/k in 1 to atoms.len)
		var/atom/thing = atoms[k]
		if(!thing)
			continue
		thing.rad_act(strength)

		var/static/list/blacklisted = typecacheof(list(/turf))
		if(!can_contaminate || blacklisted[thing.type])
			continue
		if(prob((strength-RAD_MINIMUM_CONTAMINATION) * RAD_CONTAMINATION_CHANCE_COEFFICIENT * min(1/(steps*range_modifier), 1))) // Only stronk rads get to have little baby rads
			var/datum/component/rad_insulation/insulation = thing.GetComponent(/datum/component/rad_insulation)
			if(insulation && insulation.contamination_proof)
				continue
			else
				thing.AddComponent(/datum/component/radioactive, (strength-RAD_MINIMUM_CONTAMINATION) * RAD_CONTAMINATION_STR_COEFFICIENT * min(1/(steps*range_modifier), 1))