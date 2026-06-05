// paperdolls
public:
	void sendAttachedPaperdoll(const Creature* creature, const Paperdoll_t& paperdoll) {
		if (client) {
			client->sendAttachedPaperdoll(creature, paperdoll);
		}
	}

	void sendDetachPaperdoll(const Creature* creature, const Paperdoll_t& paperdoll, bool bySlot) {
		if (client) {
			client->sendDetachPaperdoll(creature, paperdoll, bySlot);
		}
	}