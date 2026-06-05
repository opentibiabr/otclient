
// find this method
void ProtocolGame::AddCreature(NetworkMessage& msg, const Creature* creature, bool known, uint32_t remove) {
	
	// .
	// .
	// .
	
	// Add after msg.addByte(player->canWalkthroughEx(creature) ? 0x00 : 0x01);
	
	// Paperdolls
	{
		msg.addByte(static_cast<uint8_t>(creature->getPaperdolls().size()));
		for (const auto& paperdoll : creature->getPaperdolls())
			addPaperdoll(msg, paperdoll);
	}
	
}

void ProtocolGame::addPaperdoll(NetworkMessage& msg, const Paperdoll_t& paperdoll) {
	msg.add<uint16_t>(paperdoll.id);
	msg.add<uint8_t>(paperdoll.slot);
	msg.add<uint8_t>(paperdoll.color);
	msg.add<uint8_t>(paperdoll.head);
	msg.add<uint8_t>(paperdoll.body);
	msg.add<uint8_t>(paperdoll.legs);
	msg.add<uint8_t>(paperdoll.feet);
	msg.addString(paperdoll.shader);
}

void ProtocolGame::sendAttachedPaperdoll(const Creature* creature, const Paperdoll_t& paperdoll) {
	NetworkMessage msg;
	msg.addByte(0x3C);
	msg.add<uint32_t>(creature->getID());
	addPaperdoll(msg, paperdoll);
	writeToOutputBuffer(msg);
}

void ProtocolGame::sendDetachPaperdoll(const Creature* creature, const Paperdoll_t& paperdoll, bool bySlot) {
	NetworkMessage msg;
	msg.addByte(0x3D);
	msg.add<uint32_t>(creature->getID());
	msg.add<uint8_t>(static_cast<uint8_t>(bySlot));
	msg.add<uint16_t>(bySlot ? paperdoll.slot : paperdoll.id);
	writeToOutputBuffer(msg);
}