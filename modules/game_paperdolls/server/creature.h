public:
	// paperdolls
	void addPaperdoll(const Paperdoll_t& p);
	const std::vector<Paperdoll_t>& getPaperdolls() const {
		return m_paperdolls;
	}
	void setPaperdoll(const Paperdoll_t& p) {
		removePaperdollBySlot(p.slot);
		addPaperdoll(p);
	}
	bool hasPaperdollById(uint16_t id) const {
		for (const auto& p : m_paperdolls) {
			if (p.id == id)
				return true;
		}
		return false;
	}
	bool hasPaperdollBySlot(uint8_t slot) const {
		for (const auto& p : m_paperdolls) {
			if (p.slot == slot)
				return true;
		}
		return false;
	}

	Paperdoll_t getPaperdollById(uint16_t id)  const {
		const auto it = std::find_if(m_paperdolls.begin(), m_paperdolls.end(),
			[id](const Paperdoll_t& obj) { return obj.id == id; });

		if (it == m_paperdolls.end())
			return { UINT16_MAX };

		return *it;
	}
	Paperdoll_t getPaperdollBySlot(uint8_t slot) const {
		const auto it = std::find_if(m_paperdolls.begin(), m_paperdolls.end(),
			[slot](const Paperdoll_t& obj) { return obj.slot == slot; });

		if (it == m_paperdolls.end())
			return { UINT16_MAX };

		return *it;
	}

	bool removePaperdollById(uint16_t id);
	bool removePaperdollBySlot(uint8_t slot);
	
private:
	// paperdoll
	std::vector<Paperdoll_t> m_paperdolls;