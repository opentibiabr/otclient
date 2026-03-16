SpelllistSettings = {
    ['Default'] = {
        iconFile = '/images/game/spells/spell-icons-32x32',
        iconsForGameCooldown = '/images/game/spells/spell-icons-20x20',
        iconSize = {
            width = 32,
            height = 32
        },
        iconSizeCooldown = {
            width = 20,
            height = 22
        },
        spellListWidth = 210,
        spellWindowWidth = 550,
    } --[[,
['Custom'] =  {
  iconFile = '/images/game/spells/custom',
  iconSize = {width = 32, height = 32},
  spellOrder = {
    'Chain Lighting'
    ,'Chain Healing'
    ,'Divine Chain'
    ,'Berserk Chain'
    ,'Cheat death'
    ,'Brutal Charge'
    ,'Empower Summons'
    ,'Summon Doppelganger'
  }
}]]
}

-- check "/docs/generate_spell_data.py"
-- spells from canary
SpellInfo = {
    Default = {
        ['Lightest Magic Missile'] = {id = 0, name = 'Lightest Magic Missile', words = 'adori dis min vis', type = 'Conjure', level = 1, mana = 5, soul = 0, maglevel = 0, icon = '', clientId = 129, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {0}, special = false, source = 3147}, 
        ['Light Healing'] = {id = 1, name = 'Light Healing', words = 'exura', type = 'Instant', level = 8, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 5, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = false, vocations = {1, 2, 3, 5, 6, 7, 9, 10}, special = false, source = 0},
        ['Intense Healing'] = {id = 2, name = 'Intense Healing', words = 'exura gran', type = 'Instant', level = 20, mana = 70, soul = 0, maglevel = 0, icon = '', clientId = 6, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = false, vocations = {1, 2, 3, 5, 6, 7, 9, 10}, special = false, source = 0}, 
        ['Ultimate Healing'] = {id = 3, name = 'Ultimate Healing', words = 'exura vita', type = 'Instant', level = 30, mana = 160, soul = 0, maglevel = 0, icon = '', clientId = 0, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 0},
        ['Intense Healing Rune'] = {id = 4, name = 'Intense Healing Rune', words = 'adura gran', type = 'Conjure', level = 15, mana = 120, soul = 2, maglevel = 0, icon = '', clientId = 73, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {2, 6}, special = false, source = 3147}, 
        ['Ultimate Healing Rune'] = {id = 5, name = 'Ultimate Healing Rune', words = 'adura vita', type = 'Conjure', level = 24, mana = 400, soul = 3, maglevel = 0, icon = '', clientId = 61, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {2, 6}, special = false, source = 3147},
        ['Haste'] = {id = 6, name = 'Haste', words = 'utani hur', type = 'Instant', level = 14, mana = 60, soul = 0, maglevel = 0, icon = '', clientId = 100, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, special = false, source = 0}, 
        ['Light Magic Missile Rune'] = {id = 7, name = 'Light Magic Missile Rune', words = 'adori min vis', type = 'Conjure', level = 15, mana = 120, soul = 1, maglevel = 0, icon = '', clientId = 72, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147},
        ['Heavy Magic Missile Rune'] = {id = 8, name = 'Heavy Magic Missile Rune', words = 'adori vis', type = 'Conjure', level = 25, mana = 350, soul = 2, maglevel = 0, icon = '', clientId = 76, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147},
        ['Summon Creature'] = {id = 9, name = 'Summon Creature', words = 'utevo res', type = 'Instant', level = 25, mana = 0, soul = 0, maglevel = 0, icon = '', clientId = 117, group = {[3] = 2000}, needTarget = false, parameter = true, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 0},
        ['Light'] = {id = 10, name = 'Light', words = 'utevo lux', type = 'Instant', level = 8, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 116, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, special = false, source = 0},
        ['Great Light'] = {id = 11, name = 'Great Light', words = 'utevo gran lux', type = 'Instant', level = 13, mana = 60, soul = 0, maglevel = 0, icon = '', clientId = 115, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, special = false, source = 0},
        ['Convince Creature Rune'] = {id = 12, name = 'Convince Creature Rune', words = 'adeta sio', type = 'Conjure', level = 16, mana = 200, soul = 3, maglevel = 0, icon = '', clientId = 89, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {2, 6}, special = false, source = 3147}, 
        ['Energy Wave'] = {id = 13, name = 'Energy Wave', words = 'exevo vis hur', type = 'Instant', level = 38, mana = 170, soul = 0, maglevel = 0, icon = '', clientId = 42, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 8000, premium = false, vocations = {1, 5}, special = false, source = 0},
        ['Chameleon Rune'] = {id = 14, name = 'Chameleon Rune', words = 'adevo ina', type = 'Conjure', level = 27, mana = 600, soul = 2, maglevel = 0, icon = '', clientId = 90, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {2, 6}, special = false, source = 3147}, 
        ['Fireball Rune'] = {id = 15, name = 'Fireball Rune', words = 'adori flam', type = 'Conjure', level = 27, mana = 460, soul = 3, maglevel = 0, icon = '', clientId = 78, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 5}, special = false, source = 3147},
        ['Great Fireball Rune'] = {id = 16, name = 'Great Fireball Rune', words = 'adori mas flam', type = 'Conjure', level = 30, mana = 530, soul = 3, maglevel = 0, icon = '', clientId = 77, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 5}, special = false, source = 3147},
        ['Fire Bomb Rune'] = {id = 17, name = 'Fire Bomb Rune', words = 'adevo mas flam', type = 'Conjure', level = 27, mana = 600, soul = 4, maglevel = 0, icon = '', clientId = 81, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147},
        ['Explosion Rune'] = {id = 18, name = 'Explosion Rune', words = 'adevo mas hur', type = 'Conjure', level = 31, mana = 570, soul = 4, maglevel = 0, icon = '', clientId = 82, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147},
        ['Fire Wave'] = {id = 19, name = 'Fire Wave', words = 'exevo flam hur', type = 'Instant', level = 18, mana = 25, soul = 0, maglevel = 0, icon = '', clientId = 43, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Find Person'] = {id = 20, name = 'Find Person', words = 'exiva', type = 'Instant', level = 8, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 113, group = {[3] = 2000}, needTarget = false, parameter = true, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, special = false, source = 0},
        ['Sudden Death Rune'] = {id = 21, name = 'Sudden Death Rune', words = 'adori gran mort', type = 'Conjure', level = 45, mana = 985, soul = 5, maglevel = 0, icon = '', clientId = 63, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 5}, special = false, source = 3147}, 
        ['Energy Beam'] = {id = 22, name = 'Energy Beam', words = 'exevo vis lux', type = 'Instant', level = 23, mana = 40, soul = 0, maglevel = 0, icon = '', clientId = 40, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = false, vocations = {1, 5}, special = false, source = 0},
        ['Great Energy Beam'] = {id = 23, name = 'Great Energy Beam', words = 'exevo gran vis lux', type = 'Instant', level = 29, mana = 110, soul = 0, maglevel = 0, icon = '', clientId = 41, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 6000, premium = false, vocations = {1, 5}, special = false, source = 0}, 
        ["Hell's Core"] = {id = 24, name = "Hell's Core", words = 'exevo gran mas flam', type = 'Instant', level = 60, mana = 1100, soul = 0, maglevel = 0, icon = '', clientId = 48, group = {[1] = 4000}, needTarget = false, parameter = false, range = -1, exhaustion = 40000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Fire Field Rune'] = {id = 25, name = 'Fire Field Rune', words = 'adevo grav flam', type = 'Conjure', level = 15, mana = 240, soul = 1, maglevel = 0, icon = '', clientId = 80, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147}, 
        ['Poison Field Rune'] = {id = 26, name = 'Poison Field Rune', words = 'adevo grav pox', type = 'Conjure', level = 14, mana = 200, soul = 1, maglevel = 0, icon = '', clientId = 68, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147},
        ['Energy Field Rune'] = {id = 27, name = 'Energy Field Rune', words = 'adevo grav vis', type = 'Conjure', level = 18, mana = 320, soul = 2, maglevel = 0, icon = '', clientId = 84, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147},
        ['Fire Wall Rune'] = {id = 28, name = 'Fire Wall Rune', words = 'adevo mas grav flam', type = 'Conjure', level = 33, mana = 780, soul = 4, maglevel = 0, icon = '', clientId = 79, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147}, 
        ['Cure Poison'] = {id = 29, name = 'Cure Poison', words = 'exana pox', type = 'Instant', level = 10, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 9, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 6000, premium = false, vocations = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, special = false, source = 0},
        ['Destroy Field Rune'] = {id = 30, name = 'Destroy Field Rune', words = 'adito grav', type = 'Conjure', level = 17, mana = 120, soul = 2, maglevel = 0, icon = '', clientId = 86, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 3, 5, 6, 7}, special = false, source = 3147}, 
        ['Cure Poison Rune'] = {id = 31, name = 'Cure Poison Rune', words = 'adana pox', type = 'Conjure', level = 15, mana = 200, soul = 1, maglevel = 0, icon = '', clientId = 88, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {2, 6}, special = false, source = 3147},
        ['Poison Wall Rune'] = {id = 32, name = 'Poison Wall Rune', words = 'adevo mas grav pox', type = 'Conjure', level = 29, mana = 640, soul = 3, maglevel = 0, icon = '', clientId = 67, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147},
        ['Energy Wall Rune'] = {id = 33, name = 'Energy Wall Rune', words = 'adevo mas grav vis', type = 'Conjure', level = 41, mana = 1000, soul = 5, maglevel = 0, icon = '', clientId = 83, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147}, 
        -- id 34 -35 ?
        ['Salvation'] = {id = 36, name = 'Salvation', words = 'exura gran san', type = 'Instant', level = 60, mana = 210, soul = 0, maglevel = 0, icon = '', clientId = 59, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = true, vocations = {3, 7}, special = false, source = 0},
        -- id 37?
        ['Creature Illusion'] = {id = 38, name = 'Creature Illusion', words = 'utevo res ina', type = 'Instant', level = 23, mana = 100, soul = 0, maglevel = 0, icon = '', clientId = 99, group = {[3] = 2000}, needTarget = false, parameter = true, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 0}, 
        ['Strong Haste'] = {id = 39, name = 'Strong Haste', words = 'utani gran hur', type = 'Instant', level = 20, mana = 100, soul = 0, maglevel = 0, icon = '', clientId = 101, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 2, 5, 6, 9, 10}, special = false, source = 0},
        -- id 40 - 41 ?
        ['Food'] = {id = 42, name = 'Food', words = 'exevo pan', type = 'Instant', level = 14, mana = 120, soul = 1, maglevel = 0, icon = '', clientId = 98, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {2, 6}, special = false, source = 0}, 
        ['Strong Ice Wave'] = {id = 43, name = 'Strong Ice Wave', words = 'exevo gran frigo hur', type = 'Instant', level = 40, mana = 170, soul = 0, maglevel = 0, icon = '', clientId = 45, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 8000, premium = false, vocations = {2, 6}, special = false, source = 0},
        ['Magic Shield'] = {id = 44, name = 'Magic Shield', words = 'utamo vita', type = 'Instant', level = 14, mana = 50, soul = 0, maglevel = 0, icon = '', clientId = 123, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 14000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 0}, 
        ['Invisibility'] = {id = 45, name = 'Invisibility', words = 'utana vid', type = 'Instant', level = 35, mana = 440, soul = 0, maglevel = 0, icon = '', clientId = 93, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 0},
        -- id 46 - 47?
        ['Conjure Poisoned Arrow'] = {id = 48, name = 'Conjure Poisoned Arrow', words = 'exevo con pox', type = 'Conjure', level = 16, mana = 130, soul = 2, maglevel = 0, icon = '', clientId = 0, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {3, 7}, special = false, source = 0},
        ['Conjure Explosive Arrow'] = {id = 49, name = 'Conjure Explosive Arrow', words = 'exevo con flam', type = 'Conjure', level = 25, mana = 290, soul = 3, maglevel = 0, icon = '', clientId = 108, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {3, 7}, special = false, source = 0}, 
        ['Soulfire Rune'] = {id = 50, name = 'Soulfire Rune', words = 'adevo res flam', type = 'Conjure', level = 27, mana = 420, soul = 3, maglevel = 0, icon = '', clientId = 66, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 2, 5, 6}, special = false, source = 3147},
        ['Conjure Arrow'] = {id = 51, name = 'Conjure Arrow', words = 'exevo con', type = 'Conjure', level = 13, mana = 100, soul = 1, maglevel = 0, icon = '', clientId = 105, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {3, 7}, special = false, source = 0}, 
        -- id 52 - 53 ?
        ['Paralyze Rune'] = {id = 54, name = 'Paralyze Rune', words = 'adana ani', type = 'Conjure', level = 54, mana = 1400, soul = 3, maglevel = 0, icon = '', clientId = 70, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {2, 6}, special = false, source = 3147},
        ['Energy Bomb Rune'] = {id = 55, name = 'Energy Bomb Rune', words = 'adevo mas vis', type = 'Conjure', level = 37, mana = 880, soul = 5, maglevel = 0, icon = '', clientId = 85, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 5}, special = false, source = 3147}, 
        ['Wrath of Nature'] = {id = 56, name = 'Wrath of Nature', words = 'exevo gran mas tera', type = 'Instant', level = 55, mana = 700, soul = 0, maglevel = 0, icon = '', clientId = 47, group = {[1] = 4000}, needTarget = false, parameter = false, range = -1, exhaustion = 40000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Strong Ethereal Spear'] = {id = 57, name = 'Strong Ethereal Spear', words = 'exori gran con', type = 'Instant', level = 90, mana = 55, soul = 0, maglevel = 0, icon = '', clientId = 58, group = {[1] = 2000}, needTarget = true, parameter = false, range = 7, exhaustion = 8000, premium = true, vocations = {3, 7}, special = false, source = 0}, 
        -- id 58?
        ['Front Sweep'] = {id = 59, name = 'Front Sweep', words = 'exori min', type = 'Instant', level = 70, mana = 200, soul = 0, maglevel = 0, icon = '', clientId = 19, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 6000, premium = true, vocations = {4, 8}, special = false, source = 0},
        -- id 60?
        ['Brutal Strike'] = {id = 61, name = 'Brutal Strike', words = 'exori ico', type = 'Instant', level = 16, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 22, group = {[1] = 2000}, needTarget = true, parameter = false, range = 1, exhaustion = 6000, premium = false, vocations = {4, 8}, special = false, source = 0}, 
        ['Annihilation'] = {id = 62, name = 'Annihilation', words = 'exori gran ico', type = 'Instant', level = 110, mana = 300, soul = 0, maglevel = 0, icon = '', clientId = 23, group = {[1] = 2000}, needTarget = true, parameter = false, range = 1, exhaustion = 30000, premium = true, vocations = {4, 8}, special = false, source = 0},
        -- id 63 -> 74?
        ['Ultimate Light'] = {id = 75, name = 'Ultimate Light', words = 'utevo vis lux', type = 'Instant', level = 26, mana = 140, soul = 0, maglevel = 0, icon = '', clientId = 114, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 2, 5, 6}, special = false, source = 0},
        ['Magic Rope'] = {id = 76, name = 'Magic Rope', words = 'exani tera', type = 'Instant', level = 9, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 104, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, special = false, source = 0},
        ['Stalagmite Rune'] = {id = 77, name = 'Stalagmite Rune', words = 'adori tera', type = 'Conjure', level = 24, mana = 350, soul = 2, maglevel = 0, icon = '', clientId = 65, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 3147}, 
        ['Disintegrate Rune'] = {id = 78, name = 'Disintegrate Rune', words = 'adito tera', type = 'Conjure', level = 21, mana = 200, soul = 3, maglevel = 0, icon = '', clientId = 87, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 2, 3, 5, 6, 7}, special = false, source = 3147},
        ['Conjure Bolt'] = {id = 79, name = 'Conjure Bolt', words = 'exevo con mort', type = 'Conjure', level = 17, mana = 140, soul = 2, maglevel = 0, icon = '', clientId = 0, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {3, 7}, special = false, source = 0}, 
        ['Berserk'] = {id = 80, name = 'Berserk', words = 'exori', type = 'Instant', level = 35, mana = 115, soul = 0, maglevel = 0, icon = '', clientId = 20, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Levitate'] = {id = 81, name = 'Levitate', words = 'exani hur', type = 'Instant', level = 12, mana = 50, soul = 0, maglevel = 0, icon = '', clientId = 124, group = {[3] = 2000}, needTarget = false, parameter = true, range = -1, exhaustion = 2000, premium = true, vocations = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, special = false, source = 0}, 
        ['Mass Healing'] = {id = 82, name = 'Mass Healing', words = 'exura gran mas res', type = 'Instant', level = 36, mana = 150, soul = 0, maglevel = 0, icon = '', clientId = 8, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Animate Dead Rune'] = {id = 83, name = 'Animate Dead Rune', words = 'adana mort', type = 'Conjure', level = 27, mana = 600, soul = 5, maglevel = 0, icon = '', clientId = 92, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 2, 5, 6}, special = false, source = 3147}, 
        ['Heal Friend'] = {id = 84, name = 'Heal Friend', words = 'exura sio', type = 'Instant', level = 18, mana = 120, soul = 0, maglevel = 0, icon = '', clientId = 7, group = {[2] = 1000}, needTarget = true, parameter = true, range = -1, exhaustion = 1000, premium = true, vocations = {2, 6}, special = false, source = 0},
        -- id 85?
        ['Magic Wall Rune'] = {id = 86, name = 'Magic Wall Rune', words = 'adevo grav tera', type = 'Conjure', level = 32, mana = 750, soul = 5, maglevel = 0, icon = '', clientId = 71, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 5}, special = false, source = 3147},
        ['Death Strike'] = {id = 87, name = 'Death Strike', words = 'exori mort', type = 'Instant', level = 16, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 37, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 2000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Energy Strike'] = {id = 88, name = 'Energy Strike', words = 'exori vis', type = 'Instant', level = 12, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 28, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 2000, premium = true, vocations = {1, 2, 5, 6}, special = false, source = 0}, 
        ['Flame Strike'] = {id = 89, name = 'Flame Strike', words = 'exori flam', type = 'Instant', level = 14, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 25, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 2000, premium = true, vocations = {1, 2, 5, 6}, special = false, source = 0},
        ['Cancel Invisibility'] = {id = 90, name = 'Cancel Invisibility', words = 'exana ina', type = 'Instant', level = 26, mana = 200, soul = 0, maglevel = 0, icon = '', clientId = 94, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {3, 7}, special = false, source = 0},
        ['Poison Bomb Rune'] = {id = 91, name = 'Poison Bomb Rune', words = 'adevo mas pox', type = 'Conjure', level = 25, mana = 520, soul = 2, maglevel = 0, icon = '', clientId = 69, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {2, 6}, special = false, source = 3147},
        -- two id= 92?
        ['Conjure Wand of Darkness'] = {id = 92, name = 'Conjure Wand of Darkness', words = 'exevo gran mort', type = 'Conjure', level = 41, mana = 250, soul = 0, maglevel = 0, icon = '', clientId = 141, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 1800000, premium = true, vocations = {1, 5}, special = false, source = 0}, 
        ['Enchant Staff'] = {id = 92, name = 'Enchant Staff', words = 'exeta vis', type = 'Conjure', level = 41, mana = 80, soul = 0, maglevel = 0, icon = '', clientId = 141, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {5}, special = false, source = 3289},
        ['Challenge'] = {id = 93, name = 'Challenge', words = 'exeta res', type = 'Instant', level = 20, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 96, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {8}, special = false, source = 0},
        ['Wild Growth Rune'] = {id = 94, name = 'Wild Growth Rune', words = 'adevo grav vita', type = 'Conjure', level = 27, mana = 600, soul = 5, maglevel = 0, icon = '', clientId = 60, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {2, 6}, special = false, source = 3147},
        ['Conjure Power Bolt'] = {id = 95, name = 'Conjure Power Bolt', words = 'exevo con vis', type = 'Conjure', level = 59, mana = 700, soul = 4, maglevel = 0, icon = '', clientId = 89, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {7}, special = false, source = 0},
        -- id 96 -> 104?
        ['Fierce Berserk'] = {id = 105, name = 'Fierce Berserk', words = 'exori gran', type = 'Instant', level = 90, mana = 340, soul = 0, maglevel = 0, icon = '', clientId = 21, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 6000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Groundshaker'] = {id = 106, name = 'Groundshaker', words = 'exori mas', type = 'Instant', level = 33, mana = 160, soul = 0, maglevel = 0, icon = '', clientId = 24, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 8000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Whirlwind Throw'] = {id = 107, name = 'Whirlwind Throw', words = 'exori hur', type = 'Instant', level = 28, mana = 40, soul = 0, maglevel = 0, icon = '', clientId = 18, group = {[1] = 2000}, needTarget = true, parameter = false, range = 5, exhaustion = 6000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Conjure Sniper Arrow'] = {id = 108, name = 'Conjure Sniper Arrow', words = 'exevo con hur', type = 'Conjure', level = 24, mana = 160, soul = 3, maglevel = 0, icon = '', clientId = 240, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {3, 7}, special = false, source = 0},
        ['Conjure Piercing Bolt'] = {id = 109, name = 'Conjure Piercing Bolt', words = 'exevo con grav', type = 'Conjure', level = 33, mana = 180, soul = 3, maglevel = 0, icon = '', clientId = 48, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {3, 7}, special = false, source = 0},
        ['Enchant Spear'] = {id = 110, name = 'Enchant Spear', words = 'exeta con', type = 'Conjure', level = 45, mana = 350, soul = 3, maglevel = 0, icon = '', clientId = 103, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {3, 7}, special = false, source = 3277},
        ['Ethereal Spear'] = {id = 111, name = 'Ethereal Spear', words = 'exori con', type = 'Instant', level = 23, mana = 25, soul = 0, maglevel = 0, icon = '', clientId = 17, group = {[1] = 2000}, needTarget = true, parameter = false, range = 7, exhaustion = 2000, premium = true, vocations = {3, 7}, special = false, source = 0},
        ['Ice Strike'] = {id = 112, name = 'Ice Strike', words = 'exori frigo', type = 'Instant', level = 15, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 31, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 2000, premium = true, vocations = {1, 2, 5, 6}, special = false, source = 0},
        ['Terra Strike'] = {id = 113, name = 'Terra Strike', words = 'exori tera', type = 'Instant', level = 13, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 34, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 0},
        ['Icicle Rune'] = {id = 114, name = 'Icicle Rune', words = 'adori frigo', type = 'Conjure', level = 28, mana = 460, soul = 3, maglevel = 0, icon = '', clientId = 74, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {2, 6}, special = false, source = 3147},
        ['Avalanche Rune'] = {id = 115, name = 'Avalanche Rune', words = 'adori mas frigo', type = 'Conjure', level = 30, mana = 530, soul = 3, maglevel = 0, icon = '', clientId = 91, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {2, 6}, special = false, source = 3147},
        ['Stone Shower Rune'] = {id = 116, name = 'Stone Shower Rune', words = 'adori mas tera', type = 'Conjure', level = 28, mana = 430, soul = 3, maglevel = 0, icon = '', clientId = 64, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {2, 6}, special = false, source = 3147},
        ['Thunderstorm Rune'] = {id = 117, name = 'Thunderstorm Rune', words = 'adori mas vis', type = 'Conjure', level = 28, mana = 430, soul = 3, maglevel = 0, icon = '', clientId = 62, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 5}, special = false, source = 3147},
        ['Eternal Winter'] = {id = 118, name = 'Eternal Winter', words = 'exevo gran mas frigo', type = 'Instant', level = 60, mana = 1050, soul = 0, maglevel = 0, icon = '', clientId = 49, group = {[1] = 4000}, needTarget = false, parameter = false, range = 5, exhaustion = 40000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Rage of the Skies'] = {id = 119, name = 'Rage of the Skies', words = 'exevo gran mas vis', type = 'Instant', level = 55, mana = 600, soul = 0, maglevel = 0, icon = '', clientId = 51, group = {[1] = 4000}, needTarget = false, parameter = false, range = -1, exhaustion = 40000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Terra Wave'] = {id = 120, name = 'Terra Wave', words = 'exevo tera hur', type = 'Instant', level = 38, mana = 170, soul = 0, maglevel = 0, icon = '', clientId = 46, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Ice Wave'] = {id = 121, name = 'Ice Wave', words = 'exevo frigo hur', type = 'Instant', level = 18, mana = 25, soul = 0, maglevel = 0, icon = '', clientId = 44, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = false, vocations = {2, 6}, special = false, source = 0},
        ['Divine Missile'] = {id = 122, name = 'Divine Missile', words = 'exori san', type = 'Instant', level = 40, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 38, group = {[1] = 2000}, needTarget = false, parameter = false, range = 4, exhaustion = 2000, premium = true, vocations = {3, 7}, special = false, source = 0},
        ['Wound Cleansing'] = {id = 123, name = 'Wound Cleansing', words = 'exura ico', type = 'Instant', level = 8, mana = 40, soul = 0, maglevel = 0, icon = '', clientId = 2, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = false, vocations = {4, 8}, special = false, source = 0},
        ['Divine Caldera'] = {id = 124, name = 'Divine Caldera', words = 'exevo mas san', type = 'Instant', level = 50, mana = 160, soul = 0, maglevel = 0, icon = '', clientId = 39, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = true, vocations = {3, 7}, special = false, source = 0},
        ['Divine Healing'] = {id = 125, name = 'Divine Healing', words = 'exura san', type = 'Instant', level = 35, mana = 160, soul = 0, maglevel = 0, icon = '', clientId = 1, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = false, vocations = {3, 7}, special = false, source = 0},
        ['Train Party'] = {id = 126, name = 'Train Party', words = 'utito mas sio', type = 'Instant', level = 32, mana = 60, soul = 0, maglevel = 0, icon = '', clientId = 119, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Protect Party'] = {id = 127, name = 'Protect Party', words = 'utamo mas sio', type = 'Instant', level = 32, mana = 90, soul = 0, maglevel = 0, icon = '', clientId = 122, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {3, 7}, special = false, source = 0},
        ['Heal Party'] = {id = 128, name = 'Heal Party', words = 'utura mas sio', type = 'Instant', level = 32, mana = 120, soul = 0, maglevel = 0, icon = '', clientId = 125, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Enchant Party'] = {id = 129, name = 'Enchant Party', words = 'utori mas sio', type = 'Instant', level = 32, mana = 120, soul = 0, maglevel = 0, icon = '', clientId = 112, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Holy Missile Rune'] = {id = 130, name = 'Holy Missile Rune', words = 'adori san', type = 'Conjure', level = 27, mana = 300, soul = 3, maglevel = 0, icon = '', clientId = 75, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {3, 7}, special = false, source = 3147},
        ['Charge'] = {id = 131, name = 'Charge', words = 'utani tempo hur', type = 'Instant', level = 25, mana = 100, soul = 0, maglevel = 0, icon = '', clientId = 97, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Protector'] = {id = 132, name = 'Protector', words = 'utamo tempo', type = 'Instant', level = 55, mana = 200, soul = 0, maglevel = 0, icon = '', clientId = 121, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Blood Rage'] = {id = 133, name = 'Blood Rage', words = 'utito tempo', type = 'Instant', level = 60, mana = 290, soul = 0, maglevel = 0, icon = '', clientId = 95, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Swift Foot'] = {id = 134, name = 'Swift Foot', words = 'utamo tempo san', type = 'Instant', level = 55, mana = 400, soul = 0, maglevel = 0, icon = '', clientId = 118, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 10000, premium = true, vocations = {3, 7}, special = false, source = 0},
        ['Sharpshooter'] = {id = 135, name = 'Sharpshooter', words = 'utito tempo san', type = 'Instant', level = 60, mana = 450, soul = 0, maglevel = 0, icon = '', clientId = 120, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 10000, premium = false, vocations = {3, 7}, special = false, source = 0},
        -- 136->137?
        ['Ignite'] = {id = 138, name = 'Ignite', words = 'utori flam', type = 'Instant', level = 26, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 54, group = {[1] = 2000}, needTarget = true, parameter = false, range = 3, exhaustion = 30000, premium = false, vocations = {1, 5}, special = false, source = 0},
        ['Curse'] = {id = 139, name = 'Curse', words = 'utori mort', type = 'Instant', level = 75, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 53, group = {[1] = 2000}, needTarget = true, parameter = false, range = 3, exhaustion = 40000, premium = false, vocations = {1, 5}, special = false, source = 0},
        ['Electrify'] = {id = 140, name = 'Electrify', words = 'utori vis', type = 'Instant', level = 34, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 55, group = {[1] = 2000}, needTarget = true, parameter = false, range = 3, exhaustion = 30000, premium = false, vocations = {1, 5}, special = false, source = 0},
        ['Inflict Wound'] = {id = 141, name = 'Inflict Wound', words = 'utori kor', type = 'Instant', level = 40, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 56, group = {[1] = 2000}, needTarget = true, parameter = false, range = 1, exhaustion = 30000, premium = false, vocations = {4, 8, 9 , 10}, special = false, source = 0},
        ['Envenom'] = {id = 142, name = 'Envenom', words = 'utori pox', type = 'Instant', level = 50, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 57, group = {[1] = 2000}, needTarget = true, parameter = false, range = 3, exhaustion = 40000, premium = false, vocations = {2, 6}, special = false, source = 0},
        ['Holy Flash'] = {id = 143, name = 'Holy Flash', words = 'utori san', type = 'Instant', level = 70, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 52, group = {[1] = 2000}, needTarget = true, parameter = false, range = 3, exhaustion = 40000, premium = false, vocations = {3, 7}, special = false, source = 0},
        ['Cure Bleeding'] = {id = 144, name = 'Cure Bleeding', words = 'exana kor', type = 'Instant', level = 45, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 11, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 6000, premium = true, vocations = {2, 4, 6, 8}, special = false, source = 0},
        ['Cure Burning'] = {id = 145, name = 'Cure Burning', words = 'exana flam', type = 'Instant', level = 30, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 12, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 6000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Cure Electrification'] = {id = 146, name = 'Cure Electrification', words = 'exana vis', type = 'Instant', level = 22, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 13, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 6000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Cure Curse'] = {id = 147, name = 'Cure Curse', words = 'exana mort', type = 'Instant', level = 80, mana = 40, soul = 0, maglevel = 0, icon = '', clientId = 10, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 6000, premium = true, vocations = {3, 7}, special = false, source = 0},
        ['Physical Strike'] = {id = 148, name = 'Physical Strike', words = 'exori moe ico', type = 'Instant', level = 16, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 16, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 2000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Lightning'] = {id = 149, name = 'Lightning', words = 'exori amp vis', type = 'Instant', level = 55, mana = 60, soul = 0, maglevel = 0, icon = '', clientId = 50, group = {[1] = 2000}, needTarget = false, parameter = false, range = 4, exhaustion = 8000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Strong Flame Strike'] = {id = 150, name = 'Strong Flame Strike', words = 'exori gran flam', type = 'Instant', level = 70, mana = 60, soul = 0, maglevel = 0, icon = '', clientId = 26, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 8000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Strong Energy Strike'] = {id = 151, name = 'Strong Energy Strike', words = 'exori gran vis', type = 'Instant', level = 80, mana = 60, soul = 0, maglevel = 0, icon = '', clientId = 29, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 8000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Strong Ice Strike'] = {id = 152, name = 'Strong Ice Strike', words = 'exori gran frigo', type = 'Instant', level = 80, mana = 60, soul = 0, maglevel = 0, icon = '', clientId = 32, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 8000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Strong Terra Strike'] = {id = 153, name = 'Strong Terra Strike', words = 'exori gran tera', type = 'Instant', level = 70, mana = 60, soul = 0, maglevel = 0, icon = '', clientId = 35, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 8000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Ultimate Flame Strike'] = {id = 154, name = 'Ultimate Flame Strike', words = 'exori max flam', type = 'Instant', level = 90, mana = 100, soul = 0, maglevel = 0, icon = '', clientId = 27, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 30000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Ultimate Energy Strike'] = {id = 155, name = 'Ultimate Energy Strike', words = 'exori max vis', type = 'Instant', level = 100, mana = 100, soul = 0, maglevel = 0, icon = '', clientId = 30, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 30000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Ultimate Ice Strike'] = {id = 156, name = 'Ultimate Ice Strike', words = 'exori max frigo', type = 'Instant', level = 100, mana = 100, soul = 0, maglevel = 0, icon = '', clientId = 33, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 30000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Ultimate Terra Strike'] = {id = 157, name = 'Ultimate Terra Strike', words = 'exori max tera', type = 'Instant', level = 90, mana = 100, soul = 0, maglevel = 0, icon = '', clientId = 36, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 30000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Intense Wound Cleansing'] = {id = 158, name = 'Intense Wound Cleansing', words = 'exura gran ico', type = 'Instant', level = 80, mana = 200, soul = 0, maglevel = 0, icon = '', clientId = 3, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 600000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Recovery'] = {id = 159, name = 'Recovery', words = 'utura', type = 'Instant', level = 50, mana = 75, soul = 0, maglevel = 0, icon = '', clientId = 14, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 60000, premium = false, vocations = {3, 4, 7, 8}, special = false, source = 0},
        ['Intense Recovery'] = {id = 160, name = 'Intense Recovery', words = 'utura gran', type = 'Instant', level = 100, mana = 165, soul = 0, maglevel = 0, icon = '', clientId = 15, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = true, vocations = {3, 4, 7, 8}, special = false, source = 0},
        -- id 161 - 165?
        ['Practice Healing'] = {id = 166, name = 'Practice Healing', words = 'exura dis', type = 'Instant', level = 1, mana = 5, soul = 0, maglevel = 0, icon = '', clientId = 127, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = false, vocations = {0}, special = false, source = 0},
        ['Practise Fire Wave'] = {id = 167, name = 'Practise Fire Wave', words = 'exevo dis flam hur', type = 'Instant', level = 1, mana = 5, soul = 0, maglevel = 0, icon = '', clientId = 128, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = false, vocations = {0}, special = false, source = 0},
        ["Apprentice's Strike"] = {id = 169, name = "Apprentice's Strike", words = 'exori min flam', type = 'Instant', level = 8, mana = 6, soul = 0, maglevel = 0, icon = '', clientId = 126, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 0},
        ['Bruise Bane'] = {id = 170, name = 'Bruise Bane', words = 'exura infir ico', type = 'Instant', level = 1, mana = 10, soul = 0, maglevel = 0, icon = '', clientId = 134, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = false, vocations = {4, 8}, special = false, source = 0},
        -- id 171 - 172?
        ["Magic Patch"] = { id = 172, name = "Magic Patch", words = "exura infir", type = "Instant", level = 1, mana = 6, soul = 0, icon = "magicpatch", group = { [2] = 1000 }, needTarget = false, parameter = false, range = 0, exhaustion = 1000, premium = false, vocations = { 1, 2, 3, 5, 6, 7, 9, 10 } },
        ['Chill Out'] = {id = 173, name = 'Chill Out', words = 'exevo infir frigo hur', type = 'Instant', level = 1, mana = 8, soul = 0, maglevel = 0, icon = '', clientId = 135, group = {[1] = 2000}, needTarget = false, parameter = false, range = 1, exhaustion = 4000, premium = false, vocations = {2, 6}, special = false, source = 0},
        -- Two id 174?
        ['Magic Patch'] = {id = 174, name = 'Magic Patch', words = 'exura infir', type = 'Instant', level = 1, mana = 6, soul = 0, maglevel = 0, icon = '', clientId = 133, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = false, vocations = {1, 2, 3, 5, 6, 7, 9, 10}, special = false, source = 0},
        ['Mud Attack'] = {id = 174, name = 'Mud Attack', words = 'exori infir tera', type = 'Instant', level = 1, mana = 6, soul = 0, maglevel = 0, icon = '', clientId = 136, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 2000, premium = false, vocations = {2, 6}, special = false, source = 0},
        -- Two id 175?
        ['Arrow Call'] = {id = 176, name = 'Arrow Call', words = 'exevo infir con', type = 'Conjure', level = 1, mana = 10, soul = 1, maglevel = 0, icon = '', clientId = 137, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {3, 7}, special = false, source = 0},
        ['Buzz'] = {id = 177, name = 'Buzz', words = 'exori infir vis', type = 'Instant', level = 1, mana = 6, soul = 0, maglevel = 0, icon = '', clientId = 132, group = {[1] = 2000}, needTarget = false, parameter = false, range = 3, exhaustion = 2000, premium = false, vocations = {1, 5}, special = false, source = 0},
        ['Scorch'] = {id = 178, name = 'Scorch', words = 'exevo infir flam hur', type = 'Instant', level = 1, mana = 8, soul = 0, maglevel = 0, icon = '', clientId = 131, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = false, vocations = {1, 5}, special = false, source = 0},
        -- id 179 - 190?
        ['Conjure Royal Star'] = {id = 191, name = 'Conjure Royal Star', words = 'exevo gran con grav', type = 'Conjure', level = 150, mana = 1000, soul = 0, maglevel = 0, icon = '', clientId = 0, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {3, 7}, special = false, source = 0},
        -- id 192 - 193?
        ['Knight familiar'] = {id = 194, name = 'Knight familiar', words = 'utevo gran res eq', type = 'Instant', level = 200, mana = 1000, soul = 0, maglevel = 0, icon = '', clientId = 142, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 0, premium = false, vocations = {4, 8}, special = false, source = 0},
        ['Paladin familiar'] = {id = 195, name = 'Paladin familiar', words = 'utevo gran res sac', type = 'Instant', level = 200, mana = 2000, soul = 0, maglevel = 0, icon = '', clientId = 144, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 0, premium = false, vocations = {3, 7}, special = false, source = 0},
        ['Sorcerer familiar'] = {id = 196, name = 'Sorcerer familiar', words = 'utevo gran res ven', type = 'Instant', level = 200, mana = 3000, soul = 0, maglevel = 0, icon = '', clientId = 145, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 0, premium = false, vocations = {1, 5}, special = false, source = 0},
        ['Druid familiar'] = {id = 197, name = 'Druid familiar', words = 'utevo gran res dru', type = 'Instant', level = 200, mana = 3000, soul = 0, maglevel = 0, icon = '', clientId = 143, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 0, premium = false, vocations = {2, 6}, special = false, source = 0},
        -- id 198 - 236?
        ['Chivalrous Challenge'] = {id = 237, name = 'Chivalrous Challenge', words = 'exeta amp res', type = 'Instant', level = 150, mana = 80, soul = 0, maglevel = 0, icon = '', clientId = 111, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Divine Dazzle'] = {id = 238, name = 'Divine Dazzle', words = 'exana amp res', type = 'Instant', level = 250, mana = 80, soul = 0, maglevel = 0, icon = '', clientId = 138, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 16000, premium = true, vocations = {3, 7}, special = false, source = 0},
        ['Fair Wound Cleansing'] = {id = 239, name = 'Fair Wound Cleansing', words = 'exura med ico', type = 'Instant', level = 300, mana = 90, soul = 0, maglevel = 0, icon = '', clientId = 4, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = true, vocations = {4, 8}, special = false, source = 0},
        ['Great Fire Wave'] = {id = 240, name = 'Great Fire Wave', words = 'exevo gran flam hur', type = 'Instant', level = 38, mana = 120, soul = 0, maglevel = 0, icon = '', clientId = 102, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = true, vocations = {1, 5}, special = false, source = 0},
        ['Restoration'] = {id = 241, name = 'Restoration', words = 'exura max vita', type = 'Instant', level = 300, mana = 260, soul = 0, maglevel = 0, icon = '', clientId = 107, group = {[2] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 6000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 0},
        ["Nature's Embrace"] = {id = 242, name = "Nature's Embrace", words = 'exura gran sio', type = 'Instant', level = 300, mana = 400, soul = 0, maglevel = 0, icon = '', clientId = 106, group = {[2] = 1000}, needTarget = true, parameter = true, range = -1, exhaustion = 60000, premium = true, vocations = {2, 6}, special = false, source = 0},
        ['Expose Weakness'] = {id = 243, name = 'Expose Weakness', words = 'exori moe', type = 'Instant', level = 275, mana = 400, soul = 0, maglevel = 0, icon = '', clientId = 109, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 12000, premium = false, vocations = {1, 5}, special = false, source = 0},
        ['Sap Strength'] = {id = 244, name = 'Sap Strength', words = 'exori kor', type = 'Instant', level = 275, mana = 300, soul = 0, maglevel = 0, icon = '', clientId = 110, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 12000, premium = false, vocations = {1, 5}, special = false, source = 0},
        ['Cancel Magic Shield'] = {id = 245, name = 'Cancel Magic Shield', words = 'exana vita', type = 'Instant', level = 14, mana = 50, soul = 0, maglevel = 0, icon = '', clientId = 146, group = {[3] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {1, 2, 5, 6}, special = false, source = 0},
        -- 246 -> 259?
        ['Divine Grenade'] = {id = 258, name = 'Divine Grenade', words = 'exevo tempo mas san', type = 'Instant', level = 300, mana = 160, soul = 0, maglevel = 0, icon = '', clientId = 155, group = {[1] = 2000}, needTarget = true, parameter = false, range = 7, exhaustion = 1000, premium = true, vocations = {3, 7}, special = true, source = 0},
        ['Great Death Beam'] = {id = 260, name = 'Great Death Beam', words = 'exevo max mort', type = 'Instant', level = 300, mana = 140, soul = 0, maglevel = 0, icon = '', clientId = 157, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 10000, premium = false, vocations = {1, 5}, special = true, source = 0},
        ["Executioner's Throw"] = {id = 261, name = "Executioner's Throw", words = 'exori amp kor', type = 'Instant', level = 300, mana = 225, soul = 0, maglevel = 0, icon = '', clientId = 152, group = {[1] = 2000}, needTarget = true, parameter = false, range = 5, exhaustion = 18000, premium = true, vocations = {4, 8}, special = true, source = 0},
        ['Ice Burst'] = {id = 262, name = 'Ice Burst', words = 'exevo ulus frigo', type = 'Instant', level = 300, mana = 230, soul = 0, maglevel = 0, icon = '', clientId = 153, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 22000, premium = true, vocations = {2, 6}, special = true, source = 0},
        ['Terra Burst'] = {id = 263, name = 'Terra Burst', words = 'exevo ulus tera', type = 'Instant', level = 300, mana = 230, soul = 0, maglevel = 0, icon = '', clientId = 154, group = {[1] = 2000}, needTarget = false, parameter = false, range = -1, exhaustion = 22000, premium = true, vocations = {2, 6}, special = true, source = 0},
        ['Avatar of Steel'] = {id = 264, name = 'Avatar of Steel', words = 'uteta res eq', type = 'Instant', level = 300, mana = 800, soul = 0, maglevel = 0, icon = '', clientId = 148, group = {[3] = 2000}, needTarget = false, parameter = true, range = -1, exhaustion = 7200000, premium = true, vocations = {4, 8}, special = true, source = 0},
        ['Avatar of Light'] = {id = 265, name = 'Avatar of Light', words = 'uteta res sac', type = 'Instant', level = 300, mana = 1500, soul = 0, maglevel = 0, icon = '', clientId = 150, group = {[3] = 2000}, needTarget = false, parameter = true, range = -1, exhaustion = 7200000, premium = true, vocations = {3, 7}, special = true, source = 0},
        ['Avatar of Storm'] = {id = 266, name = 'Avatar of Storm', words = 'uteta res ven', type = 'Instant', level = 300, mana = 2200, soul = 0, maglevel = 0, icon = '', clientId = 151, group = {[3] = 2000}, needTarget = false, parameter = true, range = -1, exhaustion = 7200000, premium = true, vocations = {1, 5}, special = true, source = 0},
        ['Avatar of Nature'] = {id = 267, name = 'Avatar of Nature', words = 'uteta res dru', type = 'Instant', level = 300, mana = 2200, soul = 0, maglevel = 0, icon = '', clientId = 149, group = {[3] = 2000}, needTarget = false, parameter = true, range = -1, exhaustion = 7200000, premium = true, vocations = {2, 6}, special = true, source = 0},
        ['Divine Empowerment'] = {id = 268, name = 'Divine Empowerment', words = 'utevo grav san', type = 'Instant', level = 300, mana = 500, soul = 0, maglevel = 0, icon = '', clientId = 158, group = {[3] = 2000}, needTarget = false, parameter = false, range = 7, exhaustion = 32000, premium = true, vocations = {3, 7}, special = true, source = 0},
        -- 269 -> 272?
        ['Spirit Mend'] = { id = 273, name = 'Spirit Mend', words = 'exura gran tio', type = 'Instant', level = 80, mana = 210, soul = 0, maglevel = 0, icon = '', clientId = 161, group = { [2] = 1000 }, needTarget = false, parameter = false, range = -1, exhaustion = 1000, premium = true, vocations = {9, 10}, special = false, source = 0 },
        ['Virtue of Harmony'] = { id = 274, name = 'Virtue of Harmony', words = 'utori virtu', type = 'Instant', level = 20, mana = 210, soul = 0, maglevel = 0, icon = '', clientId = 162, group = { [3] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {9, 10}, special = false, source = 0, },
        ['Virtue of Justice'] = { id = 275, name = 'Virtue of Justice', words = 'utito virtu', type = 'Instant', level = 20, mana = 210, soul = 0, maglevel = 0, icon = '', clientId = 163, group = { [3] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 10000, premium = false, vocations = {9, 10}, special = false, source = 0, }, 
        ['Virtue of Sustain'] = { id = 276, name = 'Virtue of Sustain', words = 'utura tio', type = 'Instant', level = 20, mana = 210, soul = 0, maglevel = 0, icon = '', clientId = 164, group = { [3] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 2000, premium = false, vocations = {9, 10}, special = false, source = 0, },
        ['Mentor Other'] = { id = 277, name = 'Mentor Other', words = 'uteta tio', type = 'Instant', level = 150, mana = 110, soul = 0, maglevel = 0, icon = '', clientId = 165, group = { [3] = 2000 }, needTarget = true, parameter = true, range = -1, exhaustion = 2000, premium = false, vocations = {9, 10}, special = false, source = 0, }, 
        ['Enlighten Party'] = { id = 278, name = 'Enlighten Party', words = 'utevo mas sio', type = 'Instant', level = 32, mana = 75, soul = 0, maglevel = 0, icon = '', clientId = 166, group = { [3] = 1000 }, needTarget = false, parameter = false, range = -1, exhaustion = 300000, premium = false, vocations = {9, 10}, special = false, source = 0, }, 
        ['Focus Harmony'] = { id = 279, name = 'Focus Harmony', words = 'utevo nia', type = 'Instant', level = 275, mana = 500, soul = 0, maglevel = 0, icon = '', clientId = 167, group = { [3] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 120000, premium = false, vocations = {9, 10}, special = false, source = 0, }, 
        ['Balanced Brawl'] = { id = 280, name = 'Balanced Brawl', words = 'exori mas res', type = 'Instant', level = 175, mana = 80, soul = 0, maglevel = 0, icon = '', clientId = 168, group = { [3] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 10000, premium = true, vocations = {9, 10}, special = false, source = 0, }, 
        ['Focus Serenity'] = { id = 281, name = 'Focus Serenity', words = 'utamo tio', type = 'Instant', level = 150, mana = 500, soul = 0, maglevel = 0, icon = '', clientId = 169, group = { [3] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 600000, premium = false, vocations = {9, 10}, special = false, source = 0, },
        ['Summon Monk Familiar'] = { id = 282, name = 'Monk Familiar', words = 'utevo gran res tio', type = 'Instant', level = 200, mana = 1500, soul = 0, maglevel = 0, icon = '', clientId = 170, group = { [3] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 0, premium = false, vocations = {9, 10}, special = false, source = 0, },
        ['Avatar of Balance'] = { id = 283, name = 'Avatar of Balance', words = 'uteta res tio', type = 'Instant', level = 300, mana = 1200, soul = 0, maglevel = 0, icon = '', clientId = 171, group = { [3] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 7200000, premium = false, vocations = {9, 10}, special = false, source = 0, },
        ['Swift Jab'] = { id = 284, name = 'Swift Jab', words = 'exori infir pug', type = 'Instant', level = 1, mana = 3, soul = 0, maglevel = 0, icon = '', clientId = 172, group = { [1] = 2000 }, needTarget = true, parameter = false, range = 1, exhaustion = 2000, premium = false, vocations = {9, 10}, special = false, source = 0, },
        ['Double Jab'] = { id = 285, name = 'Double Jab', words = 'exori pug', type = 'Instant', level = 14, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 173, group = { [1] = 2000 }, needTarget = true, parameter = false, range = 1, exhaustion = 4000, premium = false, vocations = {9, 10}, special = false, source = 0, }, 
        ['Forceful Uppercut'] = { id = 286, name = 'Forceful Uppercut', words = 'exori gran pug', type = 'Instant', level = 110, mana = 325, soul = 0, maglevel = 0, icon = '', clientId = 174, group = { [1] = 2000 }, needTarget = true, parameter = false, range = 1, exhaustion = 40000, premium = true, vocations = {9, 10}, special = false, source = 0, },
        ['Flurry of Blows'] = { id = 287, name = 'Flurry of Blows', words = 'exori mas pug', type = 'Instant', level = 35, mana = 110, soul = 0, maglevel = 0, icon = '', clientId = 175, group = { [1] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = true, vocations = {9, 10}, special = false, source = 0, },
        ['Chained Penance'] = { id = 288, name = 'Chained Penance', words = 'exori med pug', type = 'Instant', level = 70, mana = 180, soul = 0, maglevel = 0, icon = '', clientId = 176, group = { [1] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 4000, premium = true, vocations = {9, 10}, special = false, source = 0, },
        ['Greater Flurry of Blows'] = { id = 289, name = 'Greater Flurry of Blows', words = 'exori gran mas pug', type = 'Instant', level = 90, mana = 300, soul = 0, maglevel = 0, icon = '', clientId = 177, group = { [1] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 10000, premium = true, vocations = {9, 10}, special = false, source = 0, },
        ['Mystic Repulse'] = { id = 290, name = 'Mystic Repulse', words = 'exori amp pug', type = 'Instant', level = 30, mana = 150, soul = 0, maglevel = 0, icon = '', clientId = 178, group = { [1] = 2000 }, needTarget = true, parameter = false, range = 7, exhaustion = 14000, premium = true, vocations = {9, 10}, special = false, source = 0, },
        ['Tiger Clash'] = { id = 291, name = 'Tiger Clash', words = 'exori infir nia', type = 'Instant', level = 1, mana = 18, soul = 0, maglevel = 0, icon = '', clientId = 179, group = { [1] = 2000 }, needTarget = true, parameter = false, range = 1, exhaustion = 8000, premium = false, vocations = {9, 10}, special = false, source = 0, },
        ['Greater Tiger Clash'] = { id = 292, name = 'Greater Tiger Clash', words = 'exori nia', type = 'Instant', level = 18, mana = 50, soul = 0, maglevel = 0, icon = '', clientId = 180, group = { [1] = 2000 }, needTarget = true, parameter = false, range = 1, exhaustion = 8000, premium = true, vocations = {9, 10}, special = false, source = 0, },
        ['Devastating Knockout'] = { id = 293, name = 'Devastating Knockout', words = 'exori gran nia', type = 'Instant', level = 125, mana = 210, soul = 0, maglevel = 0, icon = '', clientId = 181, group = { [1] = 2000 }, needTarget = true, parameter = false, range = 1, exhaustion = 24000, premium = true, vocations = {9, 10}, special = false, source = 0, },
        ['Sweeping Takedown'] = { id = 294, name = 'Sweeping Takedown', words = 'exori mas nia', type = 'Instant', level = 60, mana = 195, soul = 0, maglevel = 0, icon = '', clientId = 182, group = { [1] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 8000, premium = true, vocations = {9, 10}, special = false, source = 0, },
        ['Spiritual Outburst'] = { id = 295, name = 'Spiritual Outburst', words = 'exori gran mas nia', type = 'Instant', level = 300, mana = 425, soul = 0, maglevel = 0, icon = '', clientId = 183, group = { [1] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 60000, premium = true, vocations = {9, 10}, special = false, source = 0, },
        ['Mass Spirit Mend'] = { id = 296, name = 'Mass Spirit Mend', words = 'exura mas nia', type = 'Instant', level = 150, mana = 250, soul = 0, maglevel = 0, icon = '', clientId = 184, group = { [2] = 2000 }, needTarget = false, parameter = false, range = -1, exhaustion = 8000, premium = true, vocations = {9, 10}, special = false, source = 0, },
        ['Restore Balance'] = { id = 297, name = 'Restore Balance', words = 'exura tio sio', type = 'Instant', level = 18, mana = 120, soul = 0, maglevel = 0, icon = '', clientId = 185, group = { [2] = 1000 }, needTarget = true, parameter = true, range = -1, exhaustion = 2000, premium = true, vocations = {9, 10}, special = false, source = 0, },
    }
}

VocationNames = {
    [0] = 'None',
    [1] = 'Sorcerer',
    [2] = 'Druid',
    [3] = 'Paladin',
    [4] = 'Knight',
    [5] = 'Master Sorcerer',
    [6] = 'Elder Druid',
    [7] = 'Royal Paladin',
    [8] = 'Elite Knight',
    [9] = 'Monk',
    [10] = 'Exalted Monk'
}

SpellGroups = {
    [1] = 'Attack',
    [2] = 'Healing',
    [3] = 'Support',
    [4] = 'Special',
    [5] = 'Conjure',
    [6] = 'Crippling',
    [7] = 'Focus',
    [8] = 'UltimateStrikes',
    [9] = 'GreatBeams',
    [10] = 'BurstsOfNature',
    [11] = 'Virtue'
}

SpellRunesData = {
    [3148] = {id = 30, group = 3, name = 'destroy field rune', exhaustion = 2000},
    [3149] = {id = 55, group = 1, name = 'energybomb rune', exhaustion = 2000},
    [3152] = {id = 4, group = 2, name = 'intense healing rune', exhaustion = 1000},
    [3153] = {id = 31, group = 2, name = 'antidote rune', exhaustion = 1000},
    [3155] = {id = 21, group = 1, name = 'sudden death rune', exhaustion = 2000},
    [3156] = {id = 94, group = 1, name = 'Wild Growth Rune', exhaustion = 2000},
    [3158] = {id = 114, group = 1, name = 'icicle rune', exhaustion = 2000},
    [3160] = {id = 5, group = 2, name = 'ultimate healing rune', exhaustion = 1000},
    [3161] = {id = 115, group = 1, name = 'avalanche rune', exhaustion = 2000},
    [3164] = {id = 27, group = 1, name = 'energy field rune', exhaustion = 2000},
    [3165] = {id = 54, group = 3, name = 'paralyze rune', exhaustion = 6000},
    [3166] = {id = 33, group = 1, name = 'energy wall rune', exhaustion = 2000},
    [3172] = {id = 26, group = 1, name = 'poison field rune', exhaustion = 2000},
    [3173] = {id = 91, group = 1, name = 'poison bomb rune', exhaustion = 2000},
    [3174] = {id = 7, group = 1, name = 'light magic missile rune', exhaustion = 2000},
    [3175] = {id = 116, group = 1, name = 'stone shower rune', exhaustion = 2000},
    [3176] = {id = 32, group = 1, name = 'poison wall rune', exhaustion = 2000},
    [3177] = {id = 12, group = 3, name = 'convince creature rune', exhaustion = 2000},
    [3178] = {id = 14, group = 3, name = 'chameleon rune', exhaustion = 2000},
    [3179] = {id = 77, group = 1, name = 'stalagmite rune', exhaustion = 2000},
    [3180] = {id = 86, group = 1, name = 'Magic Wall Rune', exhaustion = 2000},
    [3182] = {id = 130, group = 1, name = 'holy missile rune', exhaustion = 2000},
    [3188] = {id = 25, group = 1, name = 'fire field rune', exhaustion = 2000},
    [3189] = {id = 15, group = 1, name = 'fireball rune', exhaustion = 2000},
    [3190] = {id = 28, group = 1, name = 'fire wall rune', exhaustion = 2000},
    [3191] = {id = 16, group = 1, name = 'great fireball rune', exhaustion = 2000},
    [3192] = {id = 17, group = 1, name = 'firebomb rune', exhaustion = 2000},
    [3195] = {id = 50, group = 1, name = 'soulfire rune', exhaustion = 2000},
    [3197] = {id = 78, group = 3, name = 'desintegrate rune', exhaustion = 2000},
    [3198] = {id = 8, group = 1, name = 'heavy magic missile rune', exhaustion = 2000},
    [3200] = {id = 18, group = 1, name = 'explosion rune', exhaustion = 2000},
    [3202] = {id = 117, group = 1, name = 'thunderstorm rune', exhaustion = 2000},
    [3203] = {id = 83, group = 3, name = 'animate dead rune', exhaustion = 2000},
    [17512] = {id = 7, group = 1, name = 'lightest magic missile rune', exhaustion = 2000},
    [21351] = {id = 116, group = 1, name = 'light stone shower rune', exhaustion = 2000},
    [21352] = {id = 7, group = 1, name = 'lightest missile rune', exhaustion = 2000}
}

Spells = {}

function Spells.getSpellList()
    local spells = {}
    for k, spell in pairs(SpellInfo["Default"]) do
        table.insert(spells, spell)
    end
    return spells
end

function Spells.getSpellByName(name)
    return SpellInfo[Spells.getSpellProfileByName(name)][name]
end

function Spells.getSpellByWords(words)
    local words = words:lower():trim()
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.words == words then
                return spell, profile, k
            end
        end
    end
    return nil
end

function Spells.getSpellByIcon(iconId)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.id == iconId then
                return spell, profile, k
            end
        end
    end
    return nil
end

function Spells.getSpellIconIds()
    local ids = {}
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            table.insert(ids, spell.id)
        end
    end
    return ids
end

function Spells.getSpellProfileById(id)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.id == id then
                return profile
            end
        end
    end
    return nil
end

function Spells.getSpellProfileByWords(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.words == words then
                return profile
            end
        end
    end
    return nil
end

function Spells.getSpellDataByWords(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.words == words then
                return spell
            end
        end
    end
    return nil
end

function Spells.getSpellDataByParamWords(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            local inputWords = words:lower()
            local spellWords = spell.words:lower()
            local quoteStartIndex = inputWords:find('%"')

            if not spell.parameter then
                if inputWords == spellWords then
                    return spell, nil
                end
            else
                if quoteStartIndex then
                    local spellPart = inputWords:sub(1, quoteStartIndex - 1):match("^%s*(.-)%s*$")
                    local parameter = inputWords:sub(quoteStartIndex + 1)
                    if spellPart == spellWords then
                        return spell, parameter
                    end
                else
                    if inputWords == spellWords then
                        return spell, nil
                    end
                end
            end
        end
    end
    return nil, nil
end

function Spells.getSpellFormatedName(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            local inputWords = words:lower()
            local spellWords = spell.words:lower()

            if not spell.parameter then
                if inputWords == spellWords then
                    return spellWords
                end
            else
                if string.sub(inputWords, 1, string.len(spellWords)) == spellWords then
                    local extraText = string.sub(inputWords, string.len(spellWords) + 1)
                    if extraText ~= "" then
                        if string.sub(extraText, 1, 1) == " " then
                            local firstChar = string.sub(extraText, 2, 2)
                            if firstChar == '"' then
                                local fomated = extraText:gsub('"', '')
                                fomated = "\"" .. string.sub(fomated, 2) .. "\""
                                return spellWords .. " " .. fomated
                            else
                                return spellWords .. extraText
                            end
                        end
                    else
                        return spellWords
                    end
                end
            end
        end
    end
    return words
end

function Spells.getSpellNameByWords(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.words == words then
                return k
            end
        end
    end
    return nil
end

function Spells.getSpellDataById(spellId)
    for _, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.id == spellId then
                return spell
            end
        end
    end
    return nil
end

function Spells.getRuneSpellByItem(itemId)
    local data = SpellRunesData[itemId]
    if data then
        return data
    end
    return nil
end

function Spells.isRuneSpell(spellId)
    for _, data in pairs(SpellRunesData) do
        if data.id == spellId then
            return true
        end
    end
    return false
end

function Spells.getSpellProfileByName(spellName)
    for profile, data in pairs(SpellInfo) do
        if table.findbykey(data, spellName:trim(), true) then
            return profile
        end
    end
    return nil
end

function Spells.getSpellsByVocationId(vocId)
    local spells = {}
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if table.contains(spell.vocations, vocId) then
                table.insert(spells, spell)
            end
        end
    end
    return spells
end

function Spells.filterSpellsByGroups(spells, groups)
    local filtered = {}
    for v, spell in pairs(spells) do
        local spellGroups = Spells.getGroupIds(spell)
        if table.equals(spellGroups, groups) then
            table.insert(filtered, spell)
        end
    end
    return filtered
end

function Spells.getCooldownByGroup(spellData, groupId)
    local keys = {}
    for k in pairs(spellData.group) do
        table.insert(keys, k)
    end
    table.sort(keys)
    local index = 1
    for _, k in ipairs(keys) do
        if index == 1 and k == groupId then
            return spellData.group[k]
        end
        index = index + 1
    end
    return nil
end

function Spells.getCooldownBySecondaryGroup(spellData, groupId)
    local keys = {}
    for k in pairs(spellData.group) do
        table.insert(keys, k)
    end
    table.sort(keys)
    local index = 1
    for _, k in ipairs(keys) do
        if index == 2 and k == groupId then
            return spellData.group[k]
        end
        index = index + 1
    end
    return nil
end

function Spells.getGroupIds(spell)
    local groups = {}
    for k, _ in pairs(spell.group) do
        table.insert(groups, k)
    end
    return groups
end

function Spells.getPrimaryGroup(spell)
    local indexes = {}
    for k in pairs(spell.group) do
        table.insert(indexes, k)
    end
    table.sort(indexes)
    return indexes[1] or -1
end

function Spells.getIconFileByProfile(profile)
    return SpelllistSettings[profile]['iconFile']
end

function Spells.getImageClip(indexClip, profile)
    if profile == nil then
        profile = "Default"
    end
    return indexClip * SpelllistSettings[profile].iconSize.width .. " 0 " .. SpelllistSettings[profile].iconSize.width .. " " .. SpelllistSettings[profile].iconSize.height
end

function Spells.getImageClipCooldown(indexClip, profile)
    if profile == nil then
        profile = "Default"
    end
    return indexClip * SpelllistSettings[profile].iconSizeCooldown.width .. " 0 " .. SpelllistSettings[profile].iconSizeCooldown.width .. " " .. SpelllistSettings[profile].iconSizeCooldown.height
end
