-- @docclass Player
-- local index = math.log(bit) / math.log(2)
PlayerStates = {
	None = 0,	-- vbot
	Poison = 1,
	Burn = 2,
	Energy = 4,
	Drunk = 8,
	ManaShield = 16,
	Paralyze = 32,
	Haste = 64,
	Swords = 128,
	Drowning = 256,
	Freezing = 512,
	Dazzled = 1024,
	Cursed = 2048,
	PartyBuff = 4096,
	RedSwords = 8192,
	PzBlock = 8192,	-- vbot
	Pz = 16384,	-- vbot
	Pigeon = 16384,
	Bleeding = 32768,
	Hungry = 65536,	-- vbot
	LesserHex = 65536,
	IntenseHex = 131072,
	GreaterHex = 262144,
	Rooted = 524288,
	Feared = 1048576,
	GoshnarTaint1 = 2097152,
	GoshnarTaint2 = 4194304,
	GoshnarTaint3 = 8388608,
	GoshnarTaint4 = 16777216,
	GoshnarTaint5 = 33554432,
	NewManaShield = 67108864,
	Agony = 134217728,
    Powerless = 268435456,
    Mentored = 536870912,
-- force icons
	Rewards = 30
}

Icons = {}

ConditionIcons = {
    [1] = {
        state = PlayerStates.Poison,
        clip = 1,
        path = 'images/conditions/player-state-flags-00.png',
        name = "poisoned",
        id = 'condition_poisoned',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are poisoned'),
        tooltip = tr(
            'This condition of the earth damage type can be caused by spells or\ncertain monsters. The total damage dealt by poisons can vary\ngreatly, but any poisoning can be easily removed by using the\n"Cure Poison" spell or the "Cure Poison Rune".'
        )
    },
    [2] = {
        state = PlayerStates.Burn,
        clip = 2,
        name = "burning",
        path = 'images/conditions/player-state-flags-01.png',
        id = 'condition_burning',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are burning'),
        tooltip = tr(
            "This is a harmful effect of the fire damage type that causes your\ncharacter to lose hit points over an extended period of time. Until it\nends, a searing flame will appear on your character at regular\nintervals. The damage dealt by the fire depends on its source.\nDruids have the magical ability to cure any burning."
        )
    },
    [3] = {
        state = PlayerStates.Energy,
        clip = 3,
        name = "electrified",
        path = 'images/conditions/player-state-flags-02.png',
        id = 'condition_electrified',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are electrified'),
        tooltip = tr(
            'Electrified is a condition of the energy damage type that causes\nprolonged hit point loss, similar to the burning condition caused by\nfire. A flash of electrical energy will appear on your character at\nregular intervals, dealing damage each time it occurs. As with\nburning, only druids have the power to end this unpleasant\ncondition using the "Cure Electrification" spell.'
        )
    },
    [4] = {
        state = PlayerStates.Bleeding,
        clip = 16,
        name = "bleeding",
        path = 'images/conditions/player-state-flags-15.png',
        id = 'condition_Bleeding',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are bleeding'),
        tooltip = tr(
            'Sometimes, creatures inflict heavy wounds on your character that\nbleed for a certain period of time. While losing blood, your\ncharacter becomes increasingly weak and loses health points over\ntime. Those who know the "Cure Bleeding" spell are fortunate, as\nthey can instantly force the gaping wound to close.'
        )
    },
    [5] = {
        state = PlayerStates.Agony,
        clip = 28,
        name = "agony",
        path = 'images/conditions/player-state-flags-27.png',
        id = 'condition_Agony',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are in agony'),
        tooltip = tr(
            "If a character is afflicted with agony, they will continuously take\ndamage over time. There is no way to cure, block or resist this\neffect - the only option is to endure it until it fades."
        )
    },
    [6] = {
        state = PlayerStates.Powerless,
        clip = 33,
        name = "powerless",
        id = 'condition_powerless',
        path = 'images/conditions/player-state-flags-28.png',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are Powerless'),
        tooltip = tr(
            "If a character is affected by Powerless, they are unable to cast\nattack spells or use offensive runes."
        )
    },
    [7] = {
        state = PlayerStates.Rooted,
        clip = 20,
        name = "rooted",
        id = 'condition_Rooted',
        path = 'images/conditions/player-state-flags-19.png',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are rooted'),
        tooltip = tr(
            "If a monster casts this powerful spell on your character, your\ncharacter will be unable to move for a few seconds. This effect\ncannot be removed."
        )
    },
    [8] = {
        state = PlayerStates.Feared,
        clip = 21,
        name = "feared",
        id = 'condition_Feared',
        path = 'images/conditions/player-state-flags-20.png',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are feared'),
        tooltip = tr(
            "Feared is a condition that certain monsters can cast on you. If you\nare feared, you temporarily lose control of your character. During\nthis time, your character will run away from the creature that\ncaused the fear. In addition, you cannot cast spells or use any\nitems."
        )
    },
    [9] = {
        state = PlayerStates.Drunk,
        clip = 4,
        name = "drunk",
        path = 'images/conditions/player-state-flags-03.png',
        id = 'condition_drunk',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are drunk'),
        tooltip = tr(
            "Taverns in RubinOT are popular gathering places where many\nadventurers enjoy relaxing after their wearisome travels with a\npint of cool beer. However, RubinOT's beer is quite strong, so don't be\nsurprised if your character has trouble walking in a straight line for\na while."
        )
    },
    [10] = {
        state = PlayerStates.NewManaShield,
        clip = 27,
        name = "magic shield",
        id = 'condition_NewManaShield',
        path = 'images/conditions/player-state-flags-26.png',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are protected by a magic shield'),
        tooltip = tr(
            "Another positive spell effect, magic shields protect characters from\nlosing hit points while active by reducing their mana instead.\nHowever, if a character's mana is reduced to zero, any further\ndamage will be deducted from their hit points as usual."
        )
    },
    [11] = {
        state = PlayerStates.Paralyze,
        clip = 6,
        name = "slowed",
        path = 'images/conditions/player-state-flags-05.png',
        id = 'condition_slowed',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are paralysed'),
        tooltip = tr(
            "Some creatures or spells may slow your character down. Until the\neffect ends or is dispelled by healing magic, your character will\nmove much more slowly than usual. However, all other actions -\nsuch as casting spells - can still be performed normally."
        )
    },
    [12] = {
        state = PlayerStates.Haste,
        clip = 7,
        name = "haste",
        path = 'images/conditions/player-state-flags-06.png',
        id = 'condition_haste',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are hasted'),
        tooltip = tr(
            'This condition is the direct opposite of the "Slow" effect. While it is\nactive, your character will move significantly faster, although other\neffects - such as hit point regeneration or attack rate - will remain\nunaffected. Needless to say, this is a desirable condition.\nCharacters can be hasted by spells or special magical items.'
        )
    },
    [13] = {
        state = PlayerStates.Swords,
        clip = 8,
        name = "logout block",
        path = 'images/conditions/player-state-flags-07.png',
        id = 'condition_logout_block',
        visibleHud = false,
        visibleBar = true,
        tooltipBar = tr('You may not logout during a fight'),
        tooltip = tr(
            "Characters affected by a logout block cannot log out safely. It\noccurs when engaging in or being affected by combat actions like\nattacking, casting offensive spells, or taking damage. The block\nlasts 60 seconds from the last violent act. Killing another player\nextends the block to 15 minutes. Wait until the icon disappears\nbefore logging out to avoid leaving your character vulnerable."
        )
    },
    [14] = {
        state = PlayerStates.Drowning,
        clip = 9,
        name = "drowning",
        id = 'condition_drowning',
        path = 'images/conditions/player-state-flags-08.png',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are drowning'),
        tooltip = tr(
            "RubinOT features a special underwater area. Since no one can survive\nwithout fresh air, characters will take damage if they walk\nunderwater without the proper equipment. The only way to survive\nis to leave the water quickly or equip a life-saving diving helmet."
        )
    },
    [15] = {
        state = PlayerStates.Freezing,
        clip = 10,
        name = "freezing",
        path = 'images/conditions/player-state-flags-09.png',
        id = 'condition_freezing',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are freezing'),
        tooltip = tr(
            "This condition of the ice damage type is caused by the freezing\nbreath of certain monsters. It causes your character to lose hit\npoints at regular intervals over an extended period. There is no\nmedicine to cure it, but if you're near a priest, you can ask them to\nheal you."
        )
    },
    [16] = {
        state = PlayerStates.Dazzled,
        clip = 11,
        name = "dazzled",
        path = 'images/conditions/player-state-flags-10.png',
        id = 'condition_dazzled',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are dazzled'),
        tooltip = tr(
            "If your character is marked as dazzled, a holy light has just struck\nwith pitiless force. Similar to being electrified, your character will\nlose a decreasing amount of hit points a few times. This condition,\ncaused by the holy damage type, has no remedy - your only\noptions are to wait it out or seek healing from a nearby priest."
        )
    },
    [17] = {
        state = PlayerStates.Cursed,
        clip = 12,
        name = "cursed",
        path = 'images/conditions/player-state-flags-11.png',
        id = 'condition_cursed',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are cursed'),
        tooltip = tr(
            "Have your health potions and healing spells ready whenever a\ncreature curses you. If your character is affected by this special\ncondition of the death damage type, a black cloud will literally\nhang over their head. For a considerable time, they will lose an\nincreasing amount of hit points at regular intervals. Only paladins,\nas masters of holy magic, are able to cure a character of a curse."
        )
    },
    [18] = {
        state = PlayerStates.Mentored,
        clip = 34,
        name = "mentor other",
        path = 'images/conditions/player-state-flags-29.png',
        id = 'condition_mentored',
        visibleHud = false,
        visibleBar = true,
        tooltipBar = tr('You are empowered by Mentor Other'),
        tooltip = tr(
            "Mentor Other grants a shared buff to both the caster and the\ntarget. The effect adapts to the target's vocation, enhancing their\nprimary role - such as melee strength, ranged damage, elemental\nmagic or healing. Only one character can be mentored at a time."
        )
    },
    [19] = {
        state = PlayerStates.PartyBuff,
        clip = 13,
        name = "strengthened",
        path = 'images/conditions/player-state-flags-12.png',
        id = 'condition_strengthened',
        visibleHud = false,
        visibleBar = true,
        tooltipBar = tr('You are strengthened'),
        tooltip = tr(
            "This condition is caused by various spells. Whenever such a spell is\ncast, one or more of the character's skills are temporarily\nincreased. This condition is commonly found in parties where\ncharacters, depending on their vocation, can raise the magic level,\nhit point regeneration, weapon skills or shielding of party\nmembers."
        )
    },
    [20] = {
        state = PlayerStates.PzBlock,
        clip = 14,
        name = "protection zone block",
        path = 'images/conditions/player-state-flags-13.png',
        id = 'condition_RedSwords',
        visibleHud = false,
        visibleBar = true,
        tooltipBar = tr('You may not logout or enter a protection zone'),
        tooltip = tr(
            "A protection zone block is always accompanied by a logout block.\nIf your character attacks another character first, they will not only\nbe unable to log out but also unable to enter any protection zones.\nHowever, there is no protection zone block when you attack a\nmember of your own party."
        )
    },
    [21] = {
        state = PlayerStates.Pz,
        clip = 15,
        name = "in protection zone",
        path = 'images/conditions/player-state-flags-14.png',
        id = 'condition_Pigeon',
        visibleHud = false,
        visibleBar = true,
        tooltipBar = tr('You are within a protection zone'),
        tooltip = tr(
            "Whenever characters are standing in a protection zone, they\ncannot perform any aggressive actions. At the same time, they are\nsafe there, as creatures and other characters cannot attack them."
        )
    },
    [22] = {
        icon = "/images/game/states/28",
        name = "resting area",
        path = 'images/conditions/player-state-flags-client-00.png',
        id = "condition_restingarea",
        visibleHud = false,
        visibleBar = true,
        tooltipBar = tr(''),
        tooltip = tr(
            "Certain protection areas, such as houses, temples, or depots, are\nalso considered resting areas. When a character is in a resting\narea, one of these small symbols will be active. Just like in a\nprotection zone, characters cannot perform any aggressive\nactions. In addition, they are safe from attacks by creatures or\nother characters.\n\nCharacters who have reached at least daily reward streak 2 will\nbenefit from a resting bonus, such as mana or hit point\nregeneration, while in a resting area."
        )
    },
    [23] = {
        state = PlayerStates.LesserHex,
        clip = 17,
        name = "lesser hex",
        path = 'images/conditions/player-state-flags-16.png',
        id = 'condition_LesserHex',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are sufferring lesser hex'),
        tooltip = tr(
            "A character affected by a lesser hex receives reduced healing. This\nmakes it harder to recover hit points from spells, potions, or other\nsources."
        )
    },
    [24] = {
        state = PlayerStates.IntenseHex,
        clip = 18,
        name = "intenser hex",
        path = 'images/conditions/player-state-flags-17.png',
        id = 'condition_IntenseHex',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are sufferring intenser hex'),
        tooltip = tr(
            "An intense hex reduces the healing a character receives and also\nlowers the damage they deal. This weakens both survivability and\ncombat performance."
        )
    },
    [25] = {
        state = PlayerStates.GreaterHex,
        clip = 19,
        name = "greater hex",
        path = 'images/conditions/player-state-flags-18.png',
        id = 'condition_GreaterHex',
        visibleHud = true,
        visibleBar = true,
        tooltipBar = tr('You are sufferring greater hex'),
        tooltip = tr(
            "A greater hex significantly weakens a character by reducing their\nmaximum hit points, in addition to lowering healing received and\ndamage dealt, as with the lesser and intense hexes."
        )
    },
    [26] = {
        icon = "/images/game/states/cursev",
        name = "goshnar's taint",
        path = 'images/conditions/player-state-flags-25.png',
        id = "condition_curse",
        tooltipBar = tr('If you are in Goshnar\'s lairs, you are sufferring from the following penalty:\n- 10%% chance that a creature teleports near you\n 0.5%% chance that a new creature spawns near you if you hit another creature\n- received damage increased by 15%% \n - 10%% chance that a creature will fully heal itself instead of dying\n- loss of 10%% of your hit points and your mana every 10 seconds'),
        visibleHud = false,
        visibleBar = true,
        tooltip = tr(
            "Depending on how many bosses a character has defeated in\nGoshnar's Lair, they will suffer from one to five penalties:\n* There is a chance that a monster will teleport near you.\n* There is a small chance that a new creature will spawn near you\nwhen you hit another creature.\n* You receive increased damage.\n* There is a moderate chance that a creature will fully heal itself\ninstead of dying.\n* You lose 10%% of your hit points and mana every 5 seconds."
        )
    },
    [27] = {
        icon = "/images/game/states/39",
        name = "bakragore's taint",
        path = 'images/conditions/player-state-flags-rotten-blood-08.png',
        id = "condition_taints",
        tooltipBar = tr(''),
        visibleHud = false,
        visibleBar = true,
        tooltip = tr(
            "Depending on how many taints a character has in Bakragore's lairs,\nthey will suffer from up to four penalties:\n* Certain melee creatures may switch places with nearby\ncharacters.\n* Upon death, a monster may spawn a stronger foe from its\ncorpse.\n* Monsters gain additional abilities.\n* Characters take increased damage from all sources.\n\nA fifth taint can be gained by defeating Bakragore, granting\nenhanced experience and loot without penalties and enabling\nessence drops from his progeny.\n\nTaint level is based on the party member with the fewest taints. To\ngain a taint, a character must match this minimum, not yet have\nthe boss's taint and deal damage during the fight. Each taint also\nimproves loot and experience."
        )
    },
    [28] = {
        skull = SkullYellow,
        name = "yellow skull",
        path = 'images/conditions/player-state-playerkiller-flags-00.png',
        id = "skullyellow",
        tooltipBar = tr('You have a yellow skull'),
        visibleHud = true,
        visibleBar = true,
        tooltip = tr(
            'This skull is somewhat special because it is not visible to all\nplayers on the screen. You will only see it if your character was\nattacked or damaged by another character while your own\ncharacter was marked with a skull. This indicates your right to\ndefend yourself, even while being marked.\nKilling a character with a yellow skull does not count as a\n"unjustified" kill, just like any other kill of a marked character.\nSimilar to a white skull, a yellow skull remains active as long as the\nlogout block is in effect. If the character continues to perform\noffensive actions while marked with a yellow skull, the duration of\nthe skull, the logout block and the connected protection zone block\nwill be extended.'
        )
    },
    [29] = {
        skull = SkullGreen,
        name = "party mode",
        id = "skullgreen",
        tooltipBar = tr('You are a member of a party'),
        path = 'images/conditions/player-state-playerkiller-flags-01.png',
        visibleHud = true,
        visibleBar = true,
        tooltip = tr(
            "While in a party, your character cannot accidentally harm party\nmembers with any attacks, such as area spells. Party members can\nalso benefit from shared experience and access to certain party-\nexclusive spells."
        )
    },
    [30] = {
        skull = SkullWhite,
        name = "white skull",
        id = "skullwhite",
        tooltipBar = tr('You have attacked an unmarked player'),
        path = 'images/conditions/player-state-playerkiller-flags-02.png',
        visibleHud = true,
        visibleBar = true,
        tooltip = tr(
            "A character marked with a white skull has recently attacked or\nkilled an unmarked character. This mark is visible to all players\nand remains active as long as the logout block is in effect. If the\ncharacter continues to perform offensive actions while marked, the\nduration of the white skull, the logout block and the protection\nzone block will be extended."
        )
    },
    [31] = {
        skull = SkullRed,
        name = "red skull",
        id = "skullred",
        tooltipBar = tr('You have killed too many unmarked players'),
        path = 'images/conditions/player-state-playerkiller-flags-03.png',
        visibleHud = true,
        visibleBar = true,
        tooltip = tr(
            "A red skull marks a character who has killed or assisted in killing\ntoo many unmarked players. While marked, the character will drop\nall items upon death, even with blessings or an Amulet of Loss. The\nred skull lasts 30 days and resets if further unjustified kills occur\nduring this time."
        )
    },
    [32] = {
        skull = SkullBlack,
        icon = "/images/game/skulls/skull_black",
        name = "black skull",
        tooltipBar = tr(''),
        path = 'images/conditions/player-state-playerkiller-flags-04.png',
        id = "skullblack",
        visibleHud = true,
        visibleBar = true,
        tooltip = tr(
            "A character with a black skull has committed too many unjustified\nkills while already marked with a red skull. While marked, the\ncharacter drops all items upon death, cannot attack unmarked\ncharacters and cannot use the expert mode Red Fist. They receive\nfull damage in PvP and will revive with only 40 hit points and 0\nmana. The black skull lasts 45 days and is reset if the character\ncontinues to gain unjustified points during this time."
        )
    },
    [33] = {
        skull = SkullOrange,
        name = "orange skull",
        path = 'images/conditions/player-state-playerkiller-flags-05.png',
        id = "skullorange",
        tooltipBar = tr('You may suffer revenge from your former victim'),
        visibleHud = true,
        visibleBar = true,
        tooltip = tr(
            "An orange skull is only visible to the character who was killed\nunjustified and to the killer. It appears when your character has\nbeen killed unjustified by another player and lasts for 7 days. If\nyou kill a character marked with an orange skull, the kill does not\ncount as unjustified. However, attacking them still results in a\nyellow skull and a protection zone block. The orange skull\ndisappears either after 7 days or once you have taken revenge for\neach unjustified kill received within that time."
        )
    },
    [34] = {
        icon = "/images/game/emblems/emblem_green",
        path = "images/conditions/player-state-guildwar-flag",
        name = "in guild war",
        id = "emblem",
        visibleHud = false,
        visibleBar = true,
        tooltipBar = tr('You are in a guild war'),
        tooltip = tr(
            "If your character is part of an active guild war, they will receive a\nprotection zone block when attacking enemies. Kills against the\nsame enemy count up to five times within 24 hours. Characters not\ninvolved in the war cannot heal or buff your character if they were\nrecently damaged by a member of the opposing guild."
        )
    },
    [35] = {
        state = PlayerStates.Hungry,
        clip = 32,
        name = "hungry",
        path = 'images/conditions/player-state-flags-client-02.png',
        id = 'condition_hungry',
        visibleHud = false,
        visibleBar = true,
        tooltipBar = tr('You are hungry'),
        tooltip = tr(
            "Characters who are hungry do not regenerate mana or health. To\nfill up your character's stomach, look for something edible, such as\nan apple, bread, or ham. There are plenty of things in RubinOT that\nyour character can eat. Check out stores, search bushes, bake your\nown bread or cake, or defeat creatures to find some delicacies."
        )
    },
    -- Hidden entries for specific states not in top 35
    [36] = { state = PlayerStates.MagicShield, clip = 5, tooltip = tr('You are protected by a magic shield'),  id = 'condition_magic_shield', hidden = true },
    [37] = { state = PlayerStates.GoshnarTaint1, clip = 22, tooltip = tr('You are GoshnarTaint'),  id = 'condition_GoshnarTaint1', hidden = true },
    [38] = { state = PlayerStates.GoshnarTaint2, clip = 23, tooltip = tr('You are GoshnarTaint'),  id = 'condition_GoshnarTaint2', hidden = true },
    [39] = { state = PlayerStates.GoshnarTaint3, clip = 24, tooltip = tr('You are GoshnarTaint'),  id = 'condition_GoshnarTaint3', hidden = true },
    [40] = { state = PlayerStates.GoshnarTaint4, clip = 25, tooltip = tr('You are GoshnarTaint'),  id = 'condition_GoshnarTaint4', hidden = true },
    [41] = { state = PlayerStates.GoshnarTaint5, clip = 26, tooltip = tr('You are GoshnarTaint'),  id = 'condition_GoshnarTaint5', hidden = true },
    [42] = { state = PlayerStates.Rewards, clip = 30, tooltip = tr('Rewards'),  id = 'condition_Rewards', hidden = true },
}

for _, condition in ipairs(ConditionIcons) do
    if condition.state then
        Icons[condition.state] = condition
    end
end


local PLAYER_STATE_SEGMENT = 4294967296

local function isStateBitActive(states, mask)
    if not states or mask == 0 then
        return false
    end

    if mask < PLAYER_STATE_SEGMENT then
        local low = states % PLAYER_STATE_SEGMENT
        return math.floor(low / mask) % 2 == 1
    end

    local highMask = math.floor(mask / PLAYER_STATE_SEGMENT)
    local high = math.floor(states / PLAYER_STATE_SEGMENT)
    return highMask > 0 and math.floor(high / highMask) % 2 == 1
end

function Player.iterateChangedStates(now, old, callback)
    if now == old then
        return
    end

    local lowNow = now % PLAYER_STATE_SEGMENT
    local lowOld = old % PLAYER_STATE_SEGMENT
    local maxLow = math.max(lowNow, lowOld)
    local mask = 1

    while mask <= maxLow do
        local nowActive = math.floor(lowNow / mask) % 2 == 1
        local oldActive = math.floor(lowOld / mask) % 2 == 1
        if nowActive ~= oldActive then
            callback(mask)
        end
        mask = mask * 2
    end

    local highNow = math.floor(now / PLAYER_STATE_SEGMENT)
    local highOld = math.floor(old / PLAYER_STATE_SEGMENT)
    local maxHigh = math.max(highNow, highOld)
    mask = 1

    while mask <= maxHigh do
        local nowActive = math.floor(highNow / mask) % 2 == 1
        local oldActive = math.floor(highOld / mask) % 2 == 1
        if nowActive ~= oldActive then
            callback(mask * PLAYER_STATE_SEGMENT)
        end
        mask = mask * 2
    end
end

combatStates= {
	CLIENT_COMBAT_PHYSICAL = 0,
	CLIENT_COMBAT_FIRE = 1,
	CLIENT_COMBAT_EARTH = 2,
	CLIENT_COMBAT_ENERGY = 3,
	CLIENT_COMBAT_ICE = 4,
	CLIENT_COMBAT_HOLY = 5,
	CLIENT_COMBAT_DEATH = 6,
	CLIENT_COMBAT_HEALING = 7,
	CLIENT_COMBAT_DROWN = 8,
	CLIENT_COMBAT_LIFEDRAIN = 9,
	CLIENT_COMBAT_MANADRAIN = 10,
}
clientCombat ={}
clientCombat[combatStates.CLIENT_COMBAT_PHYSICAL] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-physical-resist', id = 'Physical' }
clientCombat[combatStates.CLIENT_COMBAT_FIRE] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-fire-resist', id = 'Fire' }
clientCombat[combatStates.CLIENT_COMBAT_EARTH] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-earth-resist', id = 'Earth' }
clientCombat[combatStates.CLIENT_COMBAT_ENERGY] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-energy-resist', id = 'Energy' }
clientCombat[combatStates.CLIENT_COMBAT_ICE] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-ice-resist', id = 'Ice' }
clientCombat[combatStates.CLIENT_COMBAT_HOLY] = {path = '/game_cyclopedia/images/bestiary/icons/monster-icon-holy-resist', id = 'Holy' }
clientCombat[combatStates.CLIENT_COMBAT_DEATH] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-death-resist', id = 'Death' }
clientCombat[combatStates.CLIENT_COMBAT_HEALING] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-healing-resist', id = 'Healing' }
clientCombat[combatStates.CLIENT_COMBAT_DROWN] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-drowning-resist', id = 'Drown' }
clientCombat[combatStates.CLIENT_COMBAT_LIFEDRAIN] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-lifedrain-resist', id = 'Lifedrain ' }
clientCombat[combatStates.CLIENT_COMBAT_MANADRAIN] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-manadrain-resist', id = 'Manadrain' }

InventorySlotOther = 0
InventorySlotHead = 1
InventorySlotNeck = 2
InventorySlotBack = 3
InventorySlotBody = 4
InventorySlotRight = 5
InventorySlotLeft = 6
InventorySlotLeg = 7
InventorySlotFeet = 8
InventorySlotFinger = 9
InventorySlotAmmo = 10
InventorySlotPurse = 11

InventorySlotFirst = 1
InventorySlotLast = 10

vocationNamesByClientId = {
    [0] = "No Vocation",
    [1] = "Knight",
    [2] = "Paladin",
    [3] = "Sorcerer",
    [4] = "Druid",
    [5] = "Monk",
    [11] = "Elite Knight",
    [12] = "Royal Paladin",
    [13] = "Master Sorcerer",
    [14] = "Elder Druid",
    [15] = "Exalted Monk",
}

function Player:isPartyLeader()
    local shield = self:getShield()
    return (shield == ShieldWhiteYellow or shield == ShieldYellow or shield == ShieldYellowSharedExp or shield ==
               ShieldYellowNoSharedExpBlink or shield == ShieldYellowNoSharedExp)
end

function Player:isPartyMember()
    local shield = self:getShield()
    return (shield == ShieldWhiteYellow or shield == ShieldYellow or shield == ShieldYellowSharedExp or shield ==
               ShieldYellowNoSharedExpBlink or shield == ShieldYellowNoSharedExp or shield == ShieldBlueSharedExp or
               shield == ShieldBlueNoSharedExpBlink or shield == ShieldBlueNoSharedExp or shield == ShieldBlue)
end

function Player:isPartySharedExperienceActive()
    local shield = self:getShield()
    return (shield == ShieldYellowSharedExp or shield == ShieldYellowNoSharedExpBlink or shield ==
               ShieldYellowNoSharedExp or shield == ShieldBlueSharedExp or shield == ShieldBlueNoSharedExpBlink or
               shield == ShieldBlueNoSharedExp)
end

function Player:hasVip(creatureName)
    for id, vip in pairs(g_game.getVips()) do
        if (vip[1] == creatureName) then
            return true
        end
    end
    return false
end

function Player:isMounted()
    local outfit = self:getOutfit()
    return outfit.mount ~= nil and outfit.mount > 0
end

function Player:toggleMount()
    if g_game.getFeature(GamePlayerMounts) then
        g_game.mount(not self:isMounted())
    end
end

function Player:mount()
    if g_game.getFeature(GamePlayerMounts) then
        g_game.mount(true)
    end
end

function Player:dismount()
    if g_game.getFeature(GamePlayerMounts) then
        g_game.mount(false)
    end
end

function Player:getItem(itemId, subType)
    return g_game.findPlayerItem(itemId, subType or -1)
end

function Player:getItems(itemId, subType)
    local subType = subType or -1

    local items = {}
    for i = InventorySlotFirst, InventorySlotLast do
        local item = self:getInventoryItem(i)
        if item and item:getId() == itemId and (subType == -1 or item:getSubType() == subType) then
            table.insert(items, item)
        end
    end

    for i, container in pairs(g_game.getContainers()) do
        for j, item in pairs(container:getItems()) do
            if item:getId() == itemId and (subType == -1 or item:getSubType() == subType) then
                item.container = container
                table.insert(items, item)
            end
        end
    end
    return items
end

function Player:getItemsCount(itemId)
    local items, count = self:getItems(itemId), 0
    for i = 1, #items do
        count = count + items[i]:getCount()
    end
    return count
end

function Player:hasState(state, states)
    return isStateBitActive(states or self:getStates(), state)
end

function Player.isStateActive(states, state)
    return isStateBitActive(states, state)
end

function Player:getVocationNameByClientId()
    return vocationNamesByClientId[self:getVocation()] or "Unknown Vocation"
end

if not LoadedPlayer then
  LoadedPlayer = {
    playerId = 0,
    playerName = "",
    playerVocation = 0,
  }
  LoadedPlayer.__index = LoadedPlayer
end

function LoadedPlayer:getId() return self.playerId end
function LoadedPlayer:getName() return self.playerName end
function LoadedPlayer:getVocation() return self.playerVocation end
function LoadedPlayer:isLoaded()
  return self.playerId > 0
end

function LoadedPlayer:setId(playerId)
  self.playerId = playerId
end

function LoadedPlayer:setName(playerName)
  self.playerName = playerName
end

function LoadedPlayer:setVocation(vocationId)
  self.playerVocation = vocationId
end