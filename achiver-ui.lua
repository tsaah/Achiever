function GetAchievementCriteriaInfo(achievementID, criteriaIndex)
    local achievement = AI[achievementId]
    local criteriaId = achievement.criteria[criteriaIndex]
    local criteria = CI[criteriaId]

    local criteriaString = criteria.description
    local criteriaType = criteria.type
    local completed = false -- we should grab it from char db
    local quantity = criteria.quality
    local reqQuantity = 1 -- we should grab it from char db // current ammount?
    local charName = '' -- we should grab it from char db // The name of the character that completed this achievement.
    local flags = criteria.flags
    local assetID = criteria.assetId
    local quantityString = '10' -- stringified quantity
    local criteriaID = criteriaId
    local eligible = true --  True if the criteria is eligible to be completed; false otherwise. Used to determine whether to show the criteria line in the objectives tracker in red or not.
    return criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString, criteriaID, eligible
end

function GetAchievementInfo(arg1, arg2)
    local achievementId = arg1
    if arg2 then achievementId = ACat[atg1].achievements[arg2] end

    local achievement = AI[achievementId]

    local id = achievementId
    local name = achievement.name
    local points = achievements.points
    local completed = false -- we should grab it from char db
    local month = 1 -- we should grab it from char db
    local day = 1 -- we should grab it from char db
    local year = 1 -- we should grab it from char db
    local description = achievement.description
    local flags = 0 -- unused
    local icon = achievement.icon
    local rewardText = '' -- unused
    local isGuild = false -- unused
    local wasEarnedByMe = true -- somehow chek it
    local earnedBy = 'name of char who got it' -- we should grab it from char db

    return id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy
end

function addReachedLevelAchievements()
    local achievementId = 6
    local criteriaId = 6
    CI[criteriaId] = {
        id = criteriaId,
        achiement = achievementId,
        type = ECI['REACH_PLAYER_LVL'],
        assetId = 0,
        quantity = 10,
        startEvent = 0,
        startAsset = 0,
        failEvent = 0,
        failAsset = 0,
        description = 'Reach level 10',
        flags = 1, -- display flags: 1: shows progress bar (other flags I don't know)
        timerStartEvent = 0,
        timerAssetId = 0,
        timerTime = 0, -- Complete quest in %i seconds.
        uiOrder = 1 -- min value: 1
    }
    AI[achievementId] = {
        id = achievementId, -- Achievement ID
        faction = -1, -- -1: both, 0: Horde or 1: Alliance
        map = -1, -- Only set if achievement is related to a zone, otherwise set to -1
        previous = 0, -- If the Achievement belongs to a series, this is the ID of the previous one. 0 otherwise.
        name = 'Level 10',
        description = 'Reach Level 10', -- If Description is empty, it's not an Achievement but part of the statistics tab
        category = 1, -- category id
        points = 10, -- 0,5,10,15,20,25,30,50
        orderInGroup = 1, -- min value: 1
        icon = 'Interface\\AddOns\\Achiever\\textures\\achievement_level_10_resize', -- icon
        demands = 1, -- Number of things you have to get/fulfill to get this Achievement. For example if you have to get 25 tabards, there is a 25. TrinityCore: "need this count of completed criterias (own or referenced achievement criterias)"
        referencedAchievement = 0 --  TrinityCore: "referenced achievement (counting of all completed criterias)"
        criteria = [ criteriaId ]
    }
    achievementId = 7
    criteriaId = 7
    CI[criteriaId] = {
        id = criteriaId,
        achiement = achievementId,
        type = ECI['REACH_PLAYER_LVL'],
        assetId = 0,
        quantity = 20,
        startEvent = 0,
        startAsset = 0,
        failEvent = 0,
        failAsset = 0,
        description = 'Reach level 20',
        flags = 1, -- display flags: 1: shows progress bar (other flags I don't know)
        timerStartEvent = 0,
        timerAssetId = 0,
        timerTime = 0, -- Complete quest in %i seconds.
        uiOrder = 1 -- min value: 1
    }
    AI[achievementId] = {
        id = achievementId, -- Achievement ID
        faction = -1, -- -1: both, 0: Horde or 1: Alliance
        map = -1, -- Only set if achievement is related to a zone, otherwise set to -1
        previous = 6, -- If the Achievement belongs to a series, this is the ID of the previous one. 0 otherwise.
        name = 'Level 20',
        description = 'Reach Level 20', -- If Description is empty, it's not an Achievement but part of the statistics tab
        category = 1, -- category id
        points = 10, -- 0,5,10,15,20,25,30,50
        orderInGroup = 1, -- min value: 1
        icon = 'Interface\\AddOns\\Achiever\\textures\\achievement_level_20_resize', -- icon
        demands = 1, -- Number of things you have to get/fulfill to get this Achievement. For example if you have to get 25 tabards, there is a 25. TrinityCore: "need this count of completed criterias (own or referenced achievement criterias)"
        referencedAchievement = 0 --  TrinityCore: "referenced achievement (counting of all completed criterias)"
        criteria = [ criteriaId ]
    }

end

local achievementDB = {
    ['points'] = 10,
    ['achievements'] = {
        [6] = {
            completed = true,
            month = 7,
            day = 18,
            year = 2020,
            criteria = {
                [1] = {
                    completed = true,
                    month = 7,
                    day = 18,
                    year = 2020,
                    reqQuantity = 10
                },
            }
        }
    }
}

local AI = {
    [6] = {
        id = 6, -- Achievement ID
        faction = -1, -- -1: both, 0: Horde or 1: Alliance
        map = -1, -- Only set if achievement is related to a zone, otherwise set to -1
        previous = 0, -- If the Achievement belongs to a series, this is the ID of the previous one. 0 otherwise.
        name = 'Level 10',
        description = 'Reach Level 10', -- If Description is empty, it's not an Achievement but part of the statistics tab
        category = 1, -- category id
        points = 10, -- 0,5,10,15,20,25,30,50
        orderInGroup = 1, -- min value: 1
        icon = 'Interface\\AddOns\\Achiever\\textures\\achievement_level_10_resize', -- icon
        demands = 1, -- Number of things you have to get/fulfill to get this Achievement. For example if you have to get 25 tabards, there is a 25. TrinityCore: "need this count of completed criterias (own or referenced achievement criterias)"
        referencedAchievement = 0 --  TrinityCore: "referenced achievement (counting of all completed criterias)"
        criteria = [ 1 ]
    }
}
local CI = {
    [1] = {
        id = 1,
        achiement = 6,
        type = ECI['REACH_PLAYER_LVL'],
        assetId = 0,
        quantity = 10,
        startEvent = 0,
        startAsset = 0,
        failEvent = 0,
        failAsset = 0,
        description = 'Reach level 10',
        flags = 1, -- display flags: 1: shows progress bar (other flags I don't know)
        timerStartEvent = 0,
        timerAssetId = 0,
        timerTime = 0, -- Complete quest in %i seconds.
        uiOrder = 1 -- min value: 1
    }
}
local ACat = {
    [1] = {
        name = 'Character',
        parent = 0,
        flags = 0,
        achievements = [ 6 ]
    },

    [2] = {
        name = 'Quests',
        parent = 0,
        flags = 0,
        achievements = []
    },
        [3] = {
            name = 'Eastern Kingdoms',
            parent = 2,
            flags = 0,
            achievements = []
        },
        [4] = {
            name = 'Kalimdor',
            parent = 2,
            flags = 0,
            achievements = []
        },

    [5] = {
        name = 'Exploration',
        parent = 0,
        flags = 0,
        achievements = []
    },
        [6] = {
            name = 'Eastern Kingdoms',
            parent = 5,
            flags = 0,
            achievements = []
        },
        [7] = {
            name = 'Kalimdor',
            parent = 5,
            flags = 0,
            achievements = []
        },

    [8] = {
        name = 'Player vs. Player',
        parent = 0,
        flags = 0,
        achievements = []
    },
        [9] = {
            name = 'Honor',
            parent = 8,
            flags = 0,
            achievements = []
        },
        [10] = {
            name = 'Warsong Gulch',
            parent = 8,
            flags = 0,
            achievements = []
        },
        [11] = {
            name = 'Arathi Basin',
            parent = 8,
            flags = 0,
            achievements = []
        },
        [12] = {
            name = 'Alterac Valley',
            parent = 8,
            flags = 0,
            achievements = []
        },
        [13] = {
            name = 'Arena',
            parent = 8,
            flags = 0,
            achievements = []
        },
        [14] = {
            name = 'World',
            parent = 8,
            flags = 0,
            achievements = []
        },

    [15] = {
        name = 'Dungeons',
        parent = 0,
        flags = 0,
        achievements = []
    },
        [16] = {
            name = 'Ragefire Chasm',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [17] = {
            name = 'Deadmines',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [18] = {
            name = 'Blackfathom Deeps',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [19] = {
            name = 'Blackrock Depths',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [20] = {
            name = 'Gnomeregan',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [21] = {
            name = 'Dire Maul',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [22] = {
            name = 'Lower Blackrock Spire',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [23] = {
            name = 'Upper Blackrock Spire',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [24] = {
            name = 'Maraudon',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [25] = {
            name = 'Razorfen Downs',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [26] = {
            name = 'Razorfen Kraul',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [27] = {
            name = 'Scarlet Monastery',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [28] = {
            name = 'Scholomance',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [29] = {
            name = 'Stormwind Stockade',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [30] = {
            name = 'Stratholme',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [31] = {
            name = 'Sunken Temple',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [32] = {
            name = 'Uldaman',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [33] = {
            name = 'Wailing Caverns',
            parent = 15,
            flags = 0,
            achievements = []
        },
        [34] = {
            name = 'Zul\'Farrak',
            parent = 15,
            flags = 0,
            achievements = []
        },

    [35] = {
        name = 'Raids',
        parent = 0,
        flags = 0,
        achievements = []
    },
        [36] = {
            name = 'Molten Core',
            parent = 35,
            flags = 0,
            achievements = []
        },
        [37] = {
            name = 'Onixia',
            parent = 35,
            flags = 0,
            achievements = []
        },
        [38] = {
            name = 'Blackwing Lair',
            parent = 35,
            flags = 0,
            achievements = []
        },
        [39] = {
            name = 'Zul\'Gurub',
            parent = 35,
            flags = 0,
            achievements = []
        },
        [40] = {
            name = 'Ruins of Ahn\'Quiraj',
            parent = 35,
            flags = 0,
            achievements = []
        },
        [41] = {
            name = 'Temple of Ahn\'Quiraj',
            parent = 35,
            flags = 0,
            achievements = []
        },
        [42] = {
            name = 'Naxxramas',
            parent = 35,
            flags = 0,
            achievements = []
        },

    [43] = {
        name = 'Reputation',
        parent = 0,
        flags = 0,
        achievements = []
    },

    [44] = {
        name = 'World Events',
        parent = 0,
        flags = 0,
        achievements = []
    },
        [45] = {
            name = 'Love is in the Air',
            parent = 44,
            flags = 0,
            achievements = []
        },
        [46] = {
            name = 'Midsummer',
            parent = 44,
            flags = 0,
            achievements = []
        },
        [47] = {
            name = 'Brewfest',
            parent = 44,
            flags = 0,
            achievements = []
        },
        [48] = {
            name = 'Hallow\'s End',
            parent = 44,
            flags = 0,
            achievements = []
        },
        [49] = {
            name = 'Winter Veil',
            parent = 44,
            flags = 0,
            achievements = []
        },
        [50] = {
            name = 'Darkmoon Faire',
            parent = 44,
            flags = 0,
            achievements = []
        },

    [51] = {
        name = 'Pets',
        parent = 0,
        flags = 0,
        achievements = []
    },

    [52] = {
        name = 'Mounts',
        parent = 0,
        flags = 0,
        achievements = []
    },

    [53] = {
        name = 'War Effort',
        parent = 0,
        flags = 0,
        achievements = []
    },

    [54] = {
        name = 'Currencies',
        parent = 0,
        flags = 0,
        achievements = []
    },

    -- TODO: add Professions
    -- TODO: add Professions:Fishing
    -- TODO: add Professions:Cooking
    -- TODO: add Professions:First Aid
    -- TODO: add Professions: all other

    -- TODO: add WORLD BOSSES

    -- TODO: add STATISTICS
}


local ECI = { -- enumerated criteria info
    ['MONSTER_KILL'] = 0, -- monster ID
    ['WIN_PVP_OBJECTIVE'] = 1,
    ['REACH_PLAYER_LVL'] = 5, -- player level
    ['WEAPON_SKILL'] = 7, -- skill ID ?
    ['ANOTHER_ACHIEVEMENT'] = 8, -- achievement ID
    ['COMPLETING_QUESTS_GLOBALLY'] = 9,
    ['COMPLETING_DAIKY_QUEST_EVERY_DAY'] = 10,
    ['COMPLETING_QUESTS_IN_A_SPECIFIC_AREA'] = 11,
    ['COLLECTING_CURRENCY'] = 12, -- currency ID
    ['COMPLETING_DAIKY_QUESTS'] = 14,
    ['DYING_IN_SPECIFIC_LOCATIONS'] = 16, -- location ID?
    ['DEFEATING_A_BOSS_ENCOUNTER'] = 20, -- NPC ID
    ['COMPLETING_A_QUEST'] = 27, -- quest ID
    ['GETTING_A_SPELL_CAST_ON_YOU'] = 28, -- SPELL ID
    ['CASTING_A_SPELL'] = 29, -- SPELL ID often crafting
    ['PVP_OBJECTIVES'] = 30,
    ['PVP_KILLS_IN_BG'] = 31,
    ['WIN_ARENA_IN_SPECIFIC_LOCATIONS'] = 32, -- location ID?
    ['SQUASHLING_OR_SPECIFIC_PET'] = 34, -- SPELL ID owning specific pet
    ['PVP_KILLS_UNDER_INFLUENCE'] = 35, -- like with berserking
    ['ACQUIRING_ITEMS'] = 36, -- ITEM ID
    ['WINNING_ARENAS'] = 37,
    ['HIGHEST_ARENA_RATING'] = 38, -- team size
    ['ACHIEVING_ARENA_TEAM_RATING'] = 39, -- team size
    ['EATING_OR_DRINKING_SPECIFIC_ITEM'] = 41, -- item id
    ['FISHING_THINGS_UP'] = 42, -- ITEM ID
    ['EXPLORATION'] = 43, -- location ID
    ['REACHING_PVP_RANK'] = 44, -- RANK (vanilla)
    ['PURCHASING_7_BANK_SLOTS'] = 45,
    ['EXALTED_REP'] = 46, -- FACTION ID
    ['5_REPS_TO_EXALTED'] = 47,
    ['EQUIPPING_ITEMS'] = 49, -- SLOT ID (quality is presumably encoded into flags)
    ['KILLING_SPECIFIC_CLASSES_OF_PLAYER'] = 52, -- class ID?
    ['KILL_A_GIVEN_RACE'] = 53, -- race ID
    ['USING_EMOTES_ON_TARGETS'] = 54, -- emote ID?
    ['HAELING'] = 55,
    ['BEING_A_WRECKING_BALL_IN_AV'] = 56,
    ['HAVING_ITEMS'] = 57, -- ITEM ID (tabards and legendaries)
    ['GETTING_GOLD_FROM_VENDORS'] = 59,
    ['GETTING_GOLD_FROM_QUEST_REWARDS'] = 62,
    ['LOOTING_GOLD'] = 67,
    ['READING_BOOKS'] = 68, -- OBJECT ID,
    ['KILLING_PLAYERS_IN_WORLD_PVP_LOCATIONS'] = 70,
    ['FISHING_THINGS_FROM_SCHOOLS_OR_WRECKAGE'] = 72,
    ['KILLING_MALGANIS_ON_HEROIC'] = 73,
    ['EARNING_A_TITLE'] = 74,
    ['OBTAINING_MOUNTS'] = 75,
    ['OBTAINING_BATTLE_PETS'] = 96, -- pet id
    ['FISHING_IN_LOCATIONS'] = 109,
    ['CASTING_SPELL_ON_SPECIFIC_TARGET'] = 110, -- SPELL ID
    ['LEARNING_COOKING_RECIPES'] = 112,
    ['HONORABLE_KILLS'] = 113,
    ['SPENDING_GOLD_ON_REPAIRS'] = 124,
}