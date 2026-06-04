	// paperdoll
private:
	void addPaperdoll(NetworkMessage& msg, const Paperdoll_t& paperdoll);
	void sendAttachedPaperdoll(const Creature* creature, const Paperdoll_t& paperdoll);
	void sendDetachPaperdoll(const Creature* creature, const Paperdoll_t& paperdoll, bool bySlot);