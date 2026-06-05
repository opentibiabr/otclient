// paperdolls
void Creature::addPaperdoll(const Paperdoll_t& p) {
	m_paperdolls.push_back(p);

	SpectatorVec spectators;
	g_game.map.getSpectators(spectators, position, true, true);

	for (const auto spectator : spectators) {
		spectator->getPlayer()->sendAttachedPaperdoll(this, p);
	}
}

bool Creature::removePaperdollById(uint16_t id) {
	const auto it = std::find_if(m_paperdolls.begin(), m_paperdolls.end(),
		[id](const Paperdoll_t& obj) { return obj.id == id; });

	if (it == m_paperdolls.end())
		return false;

	SpectatorVec spectators;
	g_game.map.getSpectators(spectators, position, true, true);

	for (const auto spectator : spectators) {
		spectator->getPlayer()->sendDetachPaperdoll(this, *it, false);
	}

	m_paperdolls.erase(it);
	return true;
}

bool Creature::removePaperdollBySlot(uint8_t slot) {
	const auto it = std::find_if(m_paperdolls.begin(), m_paperdolls.end(),
		[slot](const Paperdoll_t& obj) { return obj.slot == slot; });

	if (it == m_paperdolls.end())
		return false;

	SpectatorVec spectators;
	g_game.map.getSpectators(spectators, position, true, true);

	for (const auto spectator : spectators) {
		spectator->getPlayer()->sendDetachPaperdoll(this, *it, true);
	}

	m_paperdolls.erase(it);
	return true;
}
