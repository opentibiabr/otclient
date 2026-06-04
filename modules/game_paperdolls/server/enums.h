// paperdoll
struct Paperdoll_t
{
	uint16_t id{ 0 };
	uint8_t slot{ 255 };
	uint8_t color{ 0 };
	uint8_t head{ 0 };
	uint8_t body{ 0 };
	uint8_t legs{ 0 };
	uint8_t feet{ 0 };
	std::string shader;
};
