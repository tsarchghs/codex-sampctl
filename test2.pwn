// Simple MySQL (BlueG R41-4) account system with skin selection and position saving.
#include <a_samp>
#include <a_mysql>

#define MYSQL_HOST "127.0.0.1"
#define MYSQL_USER "root"
#define MYSQL_PASS "11112222"
#define MYSQL_DB   "samp"
#define MYSQL_PORT 3306

#define DIALOG_LOGIN          1
#define DIALOG_REGISTER       2
#define DIALOG_INVENTORY      3
#define DIALOG_ITEM_ACTIONS   4
#define DIALOG_ITEM_AMOUNT    5
#define DIALOG_ITEM_GIVE      6
#define DIALOG_VEHICLE_ITEMS  7
#define DIALOG_VEHICLE_AMOUNT 8
#define DIALOG_DMV            9
#define DIALOG_DMV_PAY        10
#define DIALOG_GARAGE_INFO    11
#define DIALOG_GARAGE_HELP    12
#define DIALOG_SETSTATION     13
#define DIALOG_LOGIN_CANCEL   14
#define DIALOG_REGISTER_CANCEL 15
#define DIALOG_HELP           16
#define DIALOG_TUTORIAL       17
#define DIALOG_PHONE          18
#define DIALOG_STATUS         19
#define DIALOG_ITEM_SHORTCUT  20
#define DIALOG_MAP            2300
#define DIALOG_GPS            2301

#define PASSWORD_LEN 64
#define MIN_PASSWORD_LEN 6
#define MAX_LOGIN_ATTEMPTS 3
#define ACCOUNT_VERSION 1
#define STARTER_CASH 5000
#define AUTO_SAVE_INTERVAL_MS 300000
#define REPAIR_COST_PER_DAMAGE 2
#define REPAIR_BASE_COST 50
#define INVALID_ACCOUNT_ID 0
#define DRUG_EFFECT_INTERVAL 60000
#define ADDICTION_DECAY_INTERVAL (3 * 60 * 60 * 1000)
#define BASE_CARRY_LIMIT_KG 50
#define MAX_CARRY_LIMIT_KG 70
#define NEED_MAX 100
#define NEED_WARN 25
#define ECON_TICK_MS 300000
#define FACTION_SALARY_TICK_MS (15 * 60 * 1000)
#define ECON_INCOME_TAX_RATE 0.05
#define VEHICLE_TRUNK_CAPACITY_KG 120

#define MINIGAME_NONE     0
#define MINIGAME_LOCKPICK 1
#define MINIGAME_HOTWIRE  2

#define MINIGAME_KEYS 3

#define PREVIEW_X 1958.3783
#define PREVIEW_Y 1343.1572
#define PREVIEW_Z 15.3746
#define PREVIEW_A 270.0
#define MAX_PLATE_LEN 32
#define MAX_STOLEN_PLATES 256
#define ALPR_SCAN_INTERVAL 4000
#define ALPR_RANGE 20.0
#define MAX_STATIONS 3

#define DMV_VEHICLE_VALUE 50000
#define DMV_REGISTRATION_RATE 0.20
#define DMV_TAX_RATE 0.05
#define DMV_INSURANCE_RATE 0.05
#define DMV_BILLING_INTERVAL 3600000

#define GARAGE_X 1422.3159
#define GARAGE_Y -1324.9280
#define GARAGE_Z 13.5547
#define CHOP_X 2154.9868
#define CHOP_Y -1970.0945
#define CHOP_Z 13.5469

#define GARAGE_RADIUS 8.0
#define CHOP_RADIUS 8.0

#define PARTS_PER_CHOP 3
#define PARTS_FOR_METAL 5

#define TELEPORT_RADIUS 1.5
#define TELEPORT_COOLDOWN_MS 1500
#define TELEPORT_LABEL_DISTANCE 15.0

#define TAXI_DEFAULT_FARE 10
#define TAXI_MIN_FARE 1
#define TAXI_MAX_FARE 100
#define TAXI_RENTAL_MINUTES 30
#define TAXI_RENTAL_COST 300
#define TAXI_RENTAL_EXTEND_MINUTES 30
#define TAXI_RENTAL_REMINDER_FIVE 5
#define TAXI_RENTAL_REMINDER_ONE 1
#define TAXI_TOW_FEE 300
#define TAXI_DAMAGE_FEE 250
#define TAXI_METER_RATE_MS 60000

#define MAX_ITEMS 25
#define MAX_DROPS 100
#define MAX_ITEM_NAME 24
#define STORE_PRICE_NONE -1
#define ACTIVITY_JOB (1 << 0)
#define ACTIVITY_TAXI (1 << 1)
#define ACTIVITY_DELIVERY (1 << 2)
#define ACTIVITY_DMV (1 << 3)
#define ACTIVITY_BONUS_AMOUNT 500

#define MAX_ITEM_SHORTCUTS 5

#define CINEMA_SCREEN_MODEL 18880
#define CINEMA_SEAT_MODEL_1 1723
#define CINEMA_SEAT_MODEL_2 1724
#define CINEMA_SEAT_MODEL_3 1671

#define CINEMA_POINT_X  1115.0
#define CINEMA_POINT_Y  -1450.0
#define CINEMA_POINT_Z  15.0

#define CINEMA_RADIUS 3.0

#define FISH_VENDOR_X 392.8
#define FISH_VENDOR_Y -2074.5
#define FISH_VENDOR_Z 7.83

#define PET_UPDATE_MS 1000
#define PET_WANDER_RADIUS 50.0
#define PET_FOLLOW_DISTANCE 2.0

#define PET_TASK_NONE 0
#define PET_TASK_FOLLOW 1
#define PET_TASK_STAY 2
#define PET_TASK_WANDER 3

new const gPetSkins[] =
{
	70, 71, 72, 73, 105, 147
};

new const gPetNames[][] =
{
	"dog1",
	"dog2",
	"dog3",
	"dog4",
	"dog5",
	"cat"
};

new gStorePrices[MAX_ITEMS];
new Text3D:FishingVendorLabel;

#define MAX_BUSINESSES 6
#define BUSINESS_BUY_RADIUS 3.0
#define BUSINESS_COMPONENTS_DEFAULT 50
#define COMPONENT_CRATE_COST 500
#define BUSINESS_LABEL_DISTANCE 20.0

#define COMPONENT_WAREHOUSE_X 2172.8499
#define COMPONENT_WAREHOUSE_Y -2265.4827
#define COMPONENT_WAREHOUSE_Z 13.3047

new Text3D:BusinessLabels[MAX_BUSINESSES];
new Text3D:WarehouseLabel;
new bool:gCheckpointActive[MAX_PLAYERS];
new Float:gCheckpointX[MAX_PLAYERS];
new Float:gCheckpointY[MAX_PLAYERS];
new Float:gCheckpointZ[MAX_PLAYERS];
new Text3D:GarageLabel;
new Text3D:ChopLabel;
new const gAmmuWeaponIds[] = {22, 25, 28, 29, 31};
new const gAmmuWeaponPrices[] = {600, 1800, 3500, 4800, 7500};
new const gAmmuWeaponAmmo[] = {80, 25, 150, 200, 220};
new const gAmmuWeaponNames[][] =
{
	"9mm",
	"Shotgun",
	"Uzi",
	"MP5",
	"M4"
};

enum BusinessType
{
	BUSINESS_AMMUNATION,
	BUSINESS_CLOTHING,
	BUSINESS_247,
	BUSINESS_BARBERSHOP,
	BUSINESS_BEAUTY_SALON,
	BUSINESS_PLASTIC_SURGEON
};

new const gBusinessTypeNames[][24] =
{
	"Ammunation",
	"Clothing shop",
	"24/7",
	"Barbershop",
	"Beauty salon",
	"Plastic surgeon"
};

enum bInfo
{
	Float:bX,
	Float:bY,
	Float:bZ,
	bPrice,
	BusinessType:bType,
	bOwner,
	bComponents,
	bComponentPrice,
	bEarnings
};

new BusinessData[MAX_BUSINESSES][bInfo] =
{
	{1368.5737, -1279.0925, 13.5469, 120000, BUSINESS_AMMUNATION, INVALID_PLAYER_ID, 0, 0, 0},
	{2106.7893, -1795.8391, 13.5547, 90000, BUSINESS_CLOTHING, INVALID_PLAYER_ID, 0, 0, 0},
	{1836.5348, -1682.5930, 13.3281, 60000, BUSINESS_247, INVALID_PLAYER_ID, 0, 0, 0},
	{2037.5316, -1320.1406, 20.0469, 80000, BUSINESS_BARBERSHOP, INVALID_PLAYER_ID, 0, 0, 0},
	{1041.9856, -1025.7467, 32.1016, 85000, BUSINESS_BEAUTY_SALON, INVALID_PLAYER_ID, 0, 0, 0},
	{1154.5022, -1461.0933, 15.7969, 110000, BUSINESS_PLASTIC_SURGEON, INVALID_PLAYER_ID, 0, 0, 0}
};

new const gSkinList[] =
{
	0, 2, 7, 15, 20, 21, 23, 24, 28, 29,
	46, 50, 60, 61, 70, 71, 72, 73, 105, 107,
	120, 124, 125, 129, 147, 170, 180, 187, 200, 210
};

enum eCinemaSeat
{
	Float:seatX,
	Float:seatY,
	Float:seatZ,
	Float:seatA,
	seatModel
};

new const gCinemaSeats[][eCinemaSeat] =
{
	{1113.0, -1452.0, 15.0, 0.0, CINEMA_SEAT_MODEL_1},
	{1115.0, -1452.0, 15.0, 0.0, CINEMA_SEAT_MODEL_2},
	{1117.0, -1452.0, 15.0, 0.0, CINEMA_SEAT_MODEL_3},
	{1113.0, -1450.0, 15.0, 0.0, CINEMA_SEAT_MODEL_1},
	{1115.0, -1450.0, 15.0, 0.0, CINEMA_SEAT_MODEL_2},
	{1117.0, -1450.0, 15.0, 0.0, CINEMA_SEAT_MODEL_3}
};

new gCinemaScreenObject = INVALID_OBJECT_ID;
new gCinemaSeatObjects[sizeof(gCinemaSeats)];
new bool:gCinemaActive = false;
new gCinemaVideo[96];
new gCinemaStartTick = 0;
new bool:gCinemaWatching[MAX_PLAYERS];

enum pInfo
{
	bool:pLogged,
	bool:pRegistering,
	bool:pAuthChecked,
	pAccountId,
	bool:pTutorialDone,
	pAuthStartTick,
	pAuthRetries,
	bool:pGarageInside,
	bool:pGarageLocked,
	pSkin,
	pMoney,
	pSelectedItem,
	invAction:pSelectedAction,
	Float:pX,
	Float:pY,
	Float:pZ,
	Float:pA,
	pInterior,
	pWorld,
	pParts,
	pLastTeleportTick,
	pCrates,
	pDeliveryBiz,
	bool:pHasDelivery,
	pAddiction,
	pHunger,
	pThirst,
	pFatigue,
	pLastAddictionTick,
	pDrugEffectEndTick,
	pCarryLimit,
	bool:pVehicleRegistered,
	bool:pTaxesPaid,
	bool:pInsured,
	pNextBilling,
	bool:pRadioVisible,
	pRadioStation,
	pPetActor,
	pPetTask,
	pPetTimer,
	pMiniGame,
	pMiniVehicle,
	pMiniStep,
	pMiniKeySequence[MINIGAME_KEYS],
	pMiniTimer,
	pJobDailyCount,
	pJobDailyDay,
	pJobDailyMonth,
	pJobDailyYear,
	pActivityFlags,
	bool:pActivityBonusClaimed,
	pActivityDay,
	pActivityMonth,
	pActivityYear,
	bool:pWarehouseWaypoint,
	pLoginAttempts,
	pPassHash[PASSWORD_LEN + 1]
};
new PlayerData[MAX_PLAYERS][pInfo];

new MySQL:g_SQL;
new bool:gDatabaseReady = false;
new bool:gVehicleAlarmOn[MAX_VEHICLES];
new bool:gAlprEnabled[MAX_PLAYERS];
new gAlprTimer[MAX_PLAYERS];
new bool:gHasLicense[MAX_PLAYERS];
new bool:gTaxDue[MAX_PLAYERS];
new bool:gLspdDuty[MAX_PLAYERS];
new gVehicleOwner[MAX_VEHICLES];
new gEconomyHeat = 0;
new gCrimeHeat[MAX_PLAYERS];
new gStolenPlateCount;
new gStolenPlates[MAX_STOLEN_PLATES][MAX_PLATE_LEN];


new gVehicleLockLevel[MAX_VEHICLES];
new gVehicleAlarmLevel[MAX_VEHICLES];
new gVehicleMarketPrice[MAX_VEHICLES];
new gVehicleManufacturer[MAX_VEHICLES];
new gVehiclePlates[MAX_VEHICLES][MAX_PLATE_LEN];

new const gMiniKeys[] =
{
	KEY_LEFT,
	KEY_RIGHT,
	KEY_JUMP,
	KEY_SPRINT,
	KEY_CROUCH
};

new const gMiniKeyNames[][] =
{
	"LEFT",
	"RIGHT",
	"JUMP",
	"SPRINT",
	"CROUCH"
};

new bool:gTaxiOnDuty[MAX_PLAYERS];
new bool:gTaxiRequesting[MAX_PLAYERS];
new TaxiDriverForCustomer[MAX_PLAYERS];
new TaxiCustomerForDriver[MAX_PLAYERS];
new TaxiFare[MAX_PLAYERS];
new TaxiRentalEndTick[MAX_PLAYERS];
new TaxiRentalNotifiedFive[MAX_PLAYERS];
new TaxiRentalNotifiedOne[MAX_PLAYERS];
new TaxiRentalVehicle[MAX_PLAYERS];
new bool:TaxiMeterActive[MAX_PLAYERS];
new TaxiMeterFareTotal[MAX_PLAYERS];
new TaxiMeterElapsed[MAX_PLAYERS];

new const gWantedList[] =
{
	411, 415, 451, 541, 560
};

new const gStationUrls[MAX_STATIONS][] =
{
	"https://streams.ilovemusic.de/iloveradio1.mp3",
	"https://ice1.somafm.com/groovesalad-128-mp3",
	"https://ice2.somafm.com/dronezone-128-mp3"
};

forward OnAccountCheck(playerid);
forward OnAccountCreated(playerid);
forward OnInventoryLoad(playerid);
forward AutoSaveTick();
forward OnStolenPlatesLoad();
forward AuthTimeoutCheck(playerid);
forward bool:HandleLspdCommand(playerid, const cmd[], const params[]);
forward OnMiniGameTimeout(playerid);
forward AlprScan(playerid);
forward TaxiRentalTick();
forward TaxiMeterTick();
forward PetUpdate(playerid);
forward OnAddictionTick();
forward NeedsTick();
forward EconomyTick();
forward FactionSalaryTick();
forward CrimeTick();
stock bool:CanAccessVehicleTrunk(playerid, vehicleid);
stock bool:CanVehicleCarryItem(vehicleid, itemid, amount);

stock bool:HasCommandPrefix(const cmd[], const prefix[])
{
	return !strcmp(cmd, prefix, true, strlen(prefix));
}

stock LogAuthEvent(playerid, const event[], const detail[] = "")
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	if (detail[0] != '\0')
	{
		printf("[AUTH] %s(%d) %s: %s", name, playerid, event, detail);
		return 1;
	}
	printf("[AUTH] %s(%d) %s", name, playerid, event);
	return 1;
}

stock LogEconomyEvent(playerid, amount, const reason[])
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	printf("[ECON] %s(%d) %d: %s", name, playerid, amount, reason);
	return 1;
}

stock bool:RunSchemaQuery(const query[], const label[])
{
	mysql_query(g_SQL, query, false);
	new err = mysql_errno(g_SQL);
	if (err == 0)
	{
		return true;
	}
	if (err == 1060 || err == 1061 || err == 1091)
	{
		return true;
	}
	new errMsg[128];
	mysql_error(errMsg, sizeof(errMsg), g_SQL);
	printf("[MySQL] Schema error (%s): %d %s", label, err, errMsg);
	return false;
}

stock bool:EnsureDatabaseSchema()
{
	new ok = 1;
	ok = ok && RunSchemaQuery(
		"CREATE TABLE IF NOT EXISTS `accounts` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`name` VARCHAR(24) NOT NULL,`password` CHAR(64) NOT NULL,`salt` CHAR(24) NOT NULL DEFAULT '',`version` INT NOT NULL DEFAULT 1,`created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,`last_login` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,`money` INT NOT NULL DEFAULT 0,`skin` INT NOT NULL DEFAULT 0,`x` FLOAT NOT NULL DEFAULT 1958.3783,`y` FLOAT NOT NULL DEFAULT 1343.1572,`z` FLOAT NOT NULL DEFAULT 15.3746,`a` FLOAT NOT NULL DEFAULT 270.0,`interior` INT NOT NULL DEFAULT 0,`world` INT NOT NULL DEFAULT 0,`vehicle_registered` TINYINT(1) NOT NULL DEFAULT 0,`taxes_paid` TINYINT(1) NOT NULL DEFAULT 0,`insured` TINYINT(1) NOT NULL DEFAULT 0,`addiction` INT NOT NULL DEFAULT 0,`hunger` INT NOT NULL DEFAULT 100,`thirst` INT NOT NULL DEFAULT 100,`fatigue` INT NOT NULL DEFAULT 0,`carry_limit` INT NOT NULL DEFAULT 50,`tutorial_done` TINYINT(1) NOT NULL DEFAULT 0,PRIMARY KEY (`id`),UNIQUE KEY `name` (`name`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
		"create_accounts"
	);
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `salt` CHAR(24) NOT NULL DEFAULT ''", "add_salt");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `version` INT NOT NULL DEFAULT 1", "add_version");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP", "add_created_at");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `last_login` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP", "add_last_login");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `money` INT NOT NULL DEFAULT 0", "add_money");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `carry_limit` INT NOT NULL DEFAULT 50", "add_carry_limit");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `tutorial_done` TINYINT(1) NOT NULL DEFAULT 0", "add_tutorial_done");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `vehicle_registered` TINYINT(1) NOT NULL DEFAULT 0", "add_vehicle_registered");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `taxes_paid` TINYINT(1) NOT NULL DEFAULT 0", "add_taxes_paid");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `insured` TINYINT(1) NOT NULL DEFAULT 0", "add_insured");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `addiction` INT NOT NULL DEFAULT 0", "add_addiction");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `hunger` INT NOT NULL DEFAULT 100", "add_hunger");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `thirst` INT NOT NULL DEFAULT 100", "add_thirst");
	ok = ok && RunSchemaQuery("ALTER TABLE `accounts` ADD COLUMN `fatigue` INT NOT NULL DEFAULT 0", "add_fatigue");

	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `inventory` (`account_id` INT NOT NULL,`item_id` INT NOT NULL,`amount` INT NOT NULL DEFAULT 0,PRIMARY KEY (`account_id`,`item_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_inventory");
	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `job_progress` (`account_id` INT NOT NULL,`job_id` INT NOT NULL,`xp` INT NOT NULL DEFAULT 0,`level` INT NOT NULL DEFAULT 0,PRIMARY KEY (`account_id`,`job_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_job_progress");
	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `faction_members` (`account_id` INT NOT NULL,`faction_id` INT NOT NULL DEFAULT -1,`rank` INT NOT NULL DEFAULT 0,PRIMARY KEY (`account_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_faction_members");
	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `faction_storage` (`faction_id` INT NOT NULL,`item_id` INT NOT NULL,`amount` INT NOT NULL DEFAULT 0,PRIMARY KEY (`faction_id`,`item_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_faction_storage");
	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `vehicle_storage` (`plate` VARCHAR(32) NOT NULL,`item_id` INT NOT NULL,`amount` INT NOT NULL DEFAULT 0,PRIMARY KEY (`plate`,`item_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_vehicle_storage");
	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `economy_ledger` (`id` INT NOT NULL AUTO_INCREMENT,`account_id` INT NOT NULL,`amount` INT NOT NULL,`reason` VARCHAR(64) NOT NULL,`created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_economy_ledger");
	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `law_records` (`id` INT NOT NULL AUTO_INCREMENT,`officer_id` INT NOT NULL,`target_id` INT NOT NULL,`event` VARCHAR(32) NOT NULL,`detail` VARCHAR(128) NOT NULL DEFAULT '',`created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_law_records");
	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `businesses` (`id` INT NOT NULL,`owner_id` INT NOT NULL DEFAULT 0,`components` INT NOT NULL DEFAULT 0,`component_price` INT NOT NULL DEFAULT 0,`earnings` INT NOT NULL DEFAULT 0,PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_businesses");
	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `properties` (`id` INT NOT NULL,`owner_id` INT NOT NULL DEFAULT 0,`locked` TINYINT(1) NOT NULL DEFAULT 0,`rentable` TINYINT(1) NOT NULL DEFAULT 0,`rent_price` INT NOT NULL DEFAULT 0,`tenant_id` INT NOT NULL DEFAULT 0,`entry_x` FLOAT NOT NULL DEFAULT 0,`entry_y` FLOAT NOT NULL DEFAULT 0,`entry_z` FLOAT NOT NULL DEFAULT 0,`entry_a` FLOAT NOT NULL DEFAULT 0,`entry_interior` INT NOT NULL DEFAULT 0,`entry_world` INT NOT NULL DEFAULT 0,`exit_x` FLOAT NOT NULL DEFAULT 0,`exit_y` FLOAT NOT NULL DEFAULT 0,`exit_z` FLOAT NOT NULL DEFAULT 0,`exit_a` FLOAT NOT NULL DEFAULT 0,`exit_interior` INT NOT NULL DEFAULT 0,`exit_world` INT NOT NULL DEFAULT 0,PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_properties");
	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `vehicles` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`owner_id` INT NOT NULL DEFAULT 0,`model` INT NOT NULL DEFAULT 0,`x` FLOAT NOT NULL DEFAULT 0,`y` FLOAT NOT NULL DEFAULT 0,`z` FLOAT NOT NULL DEFAULT 0,`a` FLOAT NOT NULL DEFAULT 0,`color1` INT NOT NULL DEFAULT 0,`color2` INT NOT NULL DEFAULT 0,`health` FLOAT NOT NULL DEFAULT 1000,`plate` VARCHAR(32) NOT NULL DEFAULT '',`registered` TINYINT(1) NOT NULL DEFAULT 0,`taxes_paid` TINYINT(1) NOT NULL DEFAULT 0,`insured` TINYINT(1) NOT NULL DEFAULT 0,PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_vehicles");
	ok = ok && RunSchemaQuery("CREATE TABLE IF NOT EXISTS `stolen_plates` (`plate` VARCHAR(32) NOT NULL,PRIMARY KEY (`plate`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "create_stolen_plates");
	return ok != 0;
}

stock StartAccountCheck(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return 0;
	}
	PlayerData[playerid][pAuthChecked] = false;
	PlayerData[playerid][pAuthStartTick] = GetTickCount();

	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));

	new query[256];
	mysql_format(g_SQL, query, sizeof(query),
		"SELECT `id`,`password`,`skin`,`x`,`y`,`z`,`a`,`interior`,`world`,`vehicle_registered`,`taxes_paid`,`insured`,`addiction`,`hunger`,`thirst`,`fatigue`,`money`,`carry_limit`,`tutorial_done` FROM `accounts` WHERE `name`='%e' LIMIT 1",
		name
	);
	mysql_tquery(g_SQL, query, "OnAccountCheck", "i", playerid);
	LogAuthEvent(playerid, "account_check_sent");
	return 1;
}

stock bool:ParseTwoInts(const input[], &first, &second)
{
	new length = strlen(input);
	new idx = 0;

	while (idx < length && input[idx] <= ' ')
	{
		idx++;
	}

	if (idx >= length)
	{
		return false;
	}

	first = strval(input[idx]);
	while (idx < length && input[idx] > ' ')
	{
		idx++;
	}

	while (idx < length && input[idx] <= ' ')
	{
		idx++;
	}

	if (idx >= length)
	{
		second = 0;
		return true;
	}

	second = strval(input[idx]);
	return true;
}

stock Float:floatmin(Float:a, Float:b)
{
	return (a < b) ? a : b;
}

stock Float:GetPlayerDistanceFromPlayer(playerid, targetid)
{
	new Float:px, Float:py, Float:pz;
	new Float:tx, Float:ty, Float:tz;
	GetPlayerPos(playerid, px, py, pz);
	GetPlayerPos(targetid, tx, ty, tz);
	return floatsqroot((px - tx) * (px - tx) + (py - ty) * (py - ty) + (pz - tz) * (pz - tz));
}

#define ITEM_WATER 0
#define ITEM_SANDWICH 1
#define ITEM_BANDAGE 2
#define ITEM_MEDKIT 3
#define ITEM_PHONE 4
#define ITEM_RADIO 5
#define ITEM_FLASHLIGHT 6
#define ITEM_REPAIR_KIT 7
#define ITEM_LOCKPICK 8
#define ITEM_NOTEBOOK 9
#define ITEM_PISTOL_AMMO 10
#define ITEM_ROPE 11
#define ITEM_PICKAXE 12
#define ITEM_FISHING_ROD 13
#define ITEM_WOOD_STACK 14
#define ITEM_IRON_ORE 15
#define ITEM_FISH_CRATE 16
#define ITEM_TOOLKIT 17
#define ITEM_FUEL_CAN 18
#define ITEM_COPPER_WIRE 19
#define ITEM_CRATE 20
#define ITEM_CHARCOAL 21
#define ITEM_IRON_INGOT 22
#define ITEM_BAUXITE_INGOT 23
#define ITEM_OIL_BARREL 24

enum itemInfo
{
	itemLabel[MAX_ITEM_NAME],
	bool:itemConsumable,
	itemWeightKg,
	bool:itemIllegalFlag
};

new const gItems[MAX_ITEMS][itemInfo] =
{
	{"Wasserflasche", true, 1, false},
	{"Sandwich", true, 1, false},
	{"Verband", true, 1, false},
	{"Medikit", true, 2, false},
	{"Handy", false, 1, false},
	{"Radio", false, 1, false},
	{"Taschenlampe", false, 1, false},
	{"Reparaturset", false, 3, false},
	{"Dietrich", false, 1, true},
	{"Notizbuch", false, 1, false},
	{"Pistolenmunition", false, 1, true},
	{"Seil", false, 2, false},
	{"Spitzhacke", false, 4, false},
	{"Angel", false, 2, false},
	{"Holzstapel", false, 5, false},
	{"Eisenerz", false, 4, false},
	{"Fischkiste", false, 3, false},
	{"Werkzeugkoffer", false, 3, false},
	{"Kraftstoffkanister", false, 4, false},
	{"Kupferkabel", false, 2, true},
	{"Kiste", false, 1, false},
	{"Kohle", false, 2, false},
	{"Eisenbarren", false, 4, false},
	{"Bauxitbarren", false, 4, false},
	{"Oelfass", false, 6, false}
};

new PlayerItems[MAX_PLAYERS][MAX_ITEMS];
new VehicleItems[MAX_VEHICLES][MAX_ITEMS];
new gItemShortcuts[MAX_PLAYERS][MAX_ITEM_SHORTCUTS];

enum dropInfo
{
	bool:dropActive,
	dropItemId,
	dropAmount,
	dropPickupId,
	Float:dropX,
	Float:dropY,
	Float:dropZ,
	dropInterior,
	dropWorld
};

new Drops[MAX_DROPS][dropInfo];

enum invAction
{
	ACTION_NONE,
	ACTION_USE,
	ACTION_DROP,
	ACTION_DELETE,
	ACTION_GIVE,
	ACTION_VEH_TAKE,
	ACTION_SHORTCUT
};

stock GetItemName(itemid, name[], size = MAX_ITEM_NAME)
{
	if (itemid < 0 || itemid >= MAX_ITEMS)
	{
		format(name, size, "Unknown");
		return 0;
	}
	format(name, size, "%s", gItems[itemid][itemLabel]);
	return 1;
}

stock GetItemWeight(itemid)
{
	if (itemid < 0 || itemid >= MAX_ITEMS)
	{
		return 0;
	}
	return gItems[itemid][itemWeightKg];
}

stock bool:IsItemIllegal(itemid)
{
	if (itemid < 0 || itemid >= MAX_ITEMS)
	{
		return false;
	}
	return gItems[itemid][itemIllegalFlag];
}

stock GetIllegalItemValue(itemid)
{
	switch (itemid)
	{
		case 8: return 120; // Dietrich
		case 10: return 80; // Pistolenmunition
		case 19: return 200; // Kupferkabel
	}
	return 0;
}

stock GetPlayerInventoryWeight(playerid)
{
	new weight = 0;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (PlayerItems[playerid][i] < 1)
		{
			continue;
		}
		weight += gItems[i][itemWeightKg] * PlayerItems[playerid][i];
	}
	return weight;
}

stock bool:CanPlayerCarryItem(playerid, itemid, amount)
{
	if (!IsValidItem(itemid) || amount < 1)
	{
		return false;
	}
	new weightKg = gItems[itemid][itemWeightKg];
	if (weightKg < 1)
	{
		return false;
	}
	new total = GetPlayerInventoryWeight(playerid) + (weightKg * amount);
	return total <= PlayerData[playerid][pCarryLimit];
}

stock ShowInventoryFullMessage(playerid, itemid, amount)
{
	new currentWeight = GetPlayerInventoryWeight(playerid);
	new maxWeight = PlayerData[playerid][pCarryLimit];
	new needed = GetItemWeight(itemid) * amount;
	new message[96];
	format(message, sizeof(message), "Inventar voll (%d/%dkg). Bedarf: %dkg.", currentWeight, maxWeight, needed);
	SendClientMessage(playerid, -1, message);
	return 1;
}

stock IsValidItem(itemid)
{
	return (itemid >= 0 && itemid < MAX_ITEMS);
}

stock Activity_ResetIfNeeded(playerid)
{
	new year, month, day;
	getdate(year, month, day);
	if (PlayerData[playerid][pActivityDay] != day || PlayerData[playerid][pActivityMonth] != month || PlayerData[playerid][pActivityYear] != year)
	{
		PlayerData[playerid][pActivityDay] = day;
		PlayerData[playerid][pActivityMonth] = month;
		PlayerData[playerid][pActivityYear] = year;
		PlayerData[playerid][pActivityFlags] = 0;
		PlayerData[playerid][pActivityBonusClaimed] = false;
	}
	return 1;
}

stock Activity_CountFlags(flags)
{
	new count = 0;
	for (new i = 0; i < 8; i++)
	{
		if (flags & (1 << i))
		{
			count++;
		}
	}
	return count;
}

stock bool:Activity_Mark(playerid, flag)
{
	if (!PlayerData[playerid][pLogged])
	{
		return false;
	}
	Activity_ResetIfNeeded(playerid);
	new bool:hadFlag = (PlayerData[playerid][pActivityFlags] & flag) != 0;
	PlayerData[playerid][pActivityFlags] |= flag;
	if (!PlayerData[playerid][pActivityBonusClaimed] && Activity_CountFlags(PlayerData[playerid][pActivityFlags]) >= 3)
	{
		PlayerData[playerid][pActivityBonusClaimed] = true;
		Economy_Payout(playerid, ACTIVITY_BONUS_AMOUNT, "activity_bonus");
		SendClientMessage(playerid, -1, "Vielfalt-Bonus: $500. Naechster Schritt: /gps fuer neue Jobs.");
	}
	return !hadFlag;
}

stock SetPlayerCheckpointEx(playerid, Float:x, Float:y, Float:z, Float:size)
{
	SetPlayerCheckpoint(playerid, x, y, z, size);
	gCheckpointActive[playerid] = true;
	gCheckpointX[playerid] = x;
	gCheckpointY[playerid] = y;
	gCheckpointZ[playerid] = z;
	return 1;
}

stock ClearPlayerCheckpointEx(playerid)
{
	if (gCheckpointActive[playerid])
	{
		DisablePlayerCheckpoint(playerid);
	}
	gCheckpointActive[playerid] = false;
	return 1;
}

stock bool:CanStoreSellItem(itemid)
{
	return (IsValidItem(itemid) && gStorePrices[itemid] > 0);
}

stock bool:BuyStoreItem(playerid, itemid, count)
{
	if (!CanStoreSellItem(itemid) || count < 1)
	{
		SendClientMessage(playerid, -1, "Dieser Artikel ist hier nicht verfuegbar.");
		return false;
	}
	new cost = gStorePrices[itemid] * count;
	if (GetPlayerMoney(playerid) < cost)
	{
		SendClientMessage(playerid, -1, "Du hast nicht genug Geld.");
		return false;
	}
	if (!CanPlayerCarryItem(playerid, itemid, count))
	{
		ShowInventoryFullMessage(playerid, itemid, count);
		return false;
	}
	GivePlayerMoneyLogged(playerid, -cost, "store_buy");
	AddPlayerItem(playerid, itemid, count);
	new itemName[MAX_ITEM_NAME];
	GetItemName(itemid, itemName, sizeof(itemName));
	new msg[96];
	format(msg, sizeof(msg), "Gekauft: %s x%d fuer $%d.", itemName, count, cost);
	SendClientMessage(playerid, -1, msg);
	return true;
}

stock bool:IsPlayerNearFishingVendor(playerid)
{
	return bool:(IsPlayerInRangeOfPoint(playerid, 3.0, FISH_VENDOR_X, FISH_VENDOR_Y, FISH_VENDOR_Z));
}

stock AddPlayerItem(playerid, itemid, amount)
{
	if (!IsValidItem(itemid) || amount < 1)
	{
		return 0;
	}
	if (!CanPlayerCarryItem(playerid, itemid, amount))
	{
		return 0;
	}
	PlayerItems[playerid][itemid] += amount;
	return 1;
}

stock RemovePlayerItem(playerid, itemid, amount)
{
	if (!IsValidItem(itemid) || amount < 1)
	{
		return 0;
	}
	if (PlayerItems[playerid][itemid] < amount)
	{
		return 0;
	}
	PlayerItems[playerid][itemid] -= amount;
	return 1;
}

stock AddVehicleItem(vehicleid, itemid, amount)
{
	if (!IsValidItem(itemid) || amount < 1)
	{
		return 0;
	}
	if (!CanVehicleCarryItem(vehicleid, itemid, amount))
	{
		return 0;
	}
	VehicleItems[vehicleid][itemid] += amount;
	return 1;
}

stock RemoveVehicleItem(vehicleid, itemid, amount)
{
	if (!IsValidItem(itemid) || amount < 1)
	{
		return 0;
	}
	if (VehicleItems[vehicleid][itemid] < amount)
	{
		return 0;
	}
	VehicleItems[vehicleid][itemid] -= amount;
	return 1;
}

stock GetNearestActiveDrop(playerid, Float:range = 2.0)
{
	new interior = GetPlayerInterior(playerid);
	new world = GetPlayerVirtualWorld(playerid);
	for (new i = 0; i < MAX_DROPS; i++)
	{
		if (!Drops[i][dropActive])
		{
			continue;
		}
		if (Drops[i][dropInterior] != interior || Drops[i][dropWorld] != world)
		{
			continue;
		}

		if (GetPlayerDistanceFromPoint(playerid, Drops[i][dropX], Drops[i][dropY], Drops[i][dropZ]) <= range)
		{
			return i;
		}
	}
	return -1;
}

stock CreateDrop(playerid, itemid, amount)
{
	for (new i = 0; i < MAX_DROPS; i++)
	{
		if (Drops[i][dropActive])
		{
			continue;
		}

		new Float:px, Float:py, Float:pz;
		GetPlayerPos(playerid, px, py, pz);

		Drops[i][dropActive] = true;
		Drops[i][dropItemId] = itemid;
		Drops[i][dropAmount] = amount;
		Drops[i][dropInterior] = GetPlayerInterior(playerid);
		Drops[i][dropWorld] = GetPlayerVirtualWorld(playerid);
		Drops[i][dropX] = px;
		Drops[i][dropY] = py;
		Drops[i][dropZ] = pz;
		Drops[i][dropPickupId] = CreatePickup(1273, 1, px, py, pz, Drops[i][dropWorld]);
		return i;
	}
	return -1;
}

stock ClearDrop(dropid)
{
	if (dropid < 0 || dropid >= MAX_DROPS)
	{
		return 0;
	}
	if (!Drops[dropid][dropActive])
	{
		return 0;
	}
	DestroyPickup(Drops[dropid][dropPickupId]);
	Drops[dropid][dropActive] = false;
	Drops[dropid][dropItemId] = 0;
	Drops[dropid][dropAmount] = 0;
	Drops[dropid][dropPickupId] = -1;
	Drops[dropid][dropX] = 0.0;
	Drops[dropid][dropY] = 0.0;
	Drops[dropid][dropZ] = 0.0;
	Drops[dropid][dropInterior] = 0;
	Drops[dropid][dropWorld] = 0;
	return 1;
}

stock strtok(const string[], &index)
{
	new length = strlen(string);
	while ((index < length) && (string[index] <= ' '))
	{
		index++;
	}
	new offset = index;
	new result[64];
	while ((index < length) && (string[index] > ' ') && ((index - offset) < sizeof(result) - 1))
	{
		result[index - offset] = string[index];
		index++;
	}
	result[index - offset] = EOS;
	return result;
}

stock GetTargetPlayerId(const name[])
{
	new playerid = INVALID_PLAYER_ID;
	if (!strlen(name))
	{
		return playerid;
	}
	playerid = strval(name);
	if (IsPlayerConnected(playerid))
	{
		return playerid;
	}
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i))
		{
			continue;
		}
		new playerName[MAX_PLAYER_NAME];
		GetPlayerName(i, playerName, sizeof(playerName));
		if (!strcmp(playerName, name, true))
		{
			return i;
		}
	}
	return INVALID_PLAYER_ID;
}

stock SendInventoryList(playerid, targetid, const title[])
{
	new message[128];
	format(message, sizeof(message), "%s", title);
	SendClientMessage(targetid, -1, message);

	new itemName[MAX_ITEM_NAME];
	new bool:hasItems = false;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (PlayerItems[playerid][i] < 1)
		{
			continue;
		}
		hasItems = true;
		GetItemName(i, itemName, sizeof(itemName));
		format(message, sizeof(message), "  [%d] %s x%d (%dkg)", i, itemName, PlayerItems[playerid][i],
			gItems[i][itemWeightKg] * PlayerItems[playerid][i]);
		SendClientMessage(targetid, -1, message);
	}
	if (!hasItems)
	{
		SendClientMessage(targetid, -1, "  (keine Gegenstaende)");
	}
	return 1;
}

stock SendVehicleInventoryList(playerid, vehicleid, const title[])
{
	new message[128];
	format(message, sizeof(message), "%s", title);
	SendClientMessage(playerid, -1, message);

	new itemName[MAX_ITEM_NAME];
	new bool:hasItems = false;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (VehicleItems[vehicleid][i] < 1)
		{
			continue;
		}
		hasItems = true;
		GetItemName(i, itemName, sizeof(itemName));
		format(message, sizeof(message), "  [%d] %s x%d (%dkg)", i, itemName, VehicleItems[vehicleid][i],
			gItems[i][itemWeightKg] * VehicleItems[vehicleid][i]);
		SendClientMessage(playerid, -1, message);
	}
	if (!hasItems)
	{
		SendClientMessage(playerid, -1, "  (leer)");
	}
	return 1;
}

stock GetItemIdFromList(playerid, listitem)
{
	new idx = 0;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (PlayerItems[playerid][i] < 1)
		{
			continue;
		}
		if (idx == listitem)
		{
			return i;
		}
		idx++;
	}
	return -1;
}

stock GetVehicleItemIdFromList(vehicleid, listitem)
{
	new idx = 0;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (VehicleItems[vehicleid][i] < 1)
		{
			continue;
		}
		if (idx == listitem)
		{
			return i;
		}
		idx++;
	}
	return -1;
}

stock ShowInventoryDialog(playerid)
{
	new list[768];
	list[0] = EOS;
	new itemName[MAX_ITEM_NAME];
	new hasItems = 0;
	new weight = GetPlayerInventoryWeight(playerid);
	new maxWeight = PlayerData[playerid][pCarryLimit];
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (PlayerItems[playerid][i] < 1)
		{
			continue;
		}
		hasItems = 1;
		GetItemName(i, itemName, sizeof(itemName));
		new line[64];
		format(line, sizeof(line), "%s x%d (%dkg)\n", itemName, PlayerItems[playerid][i],
			gItems[i][itemWeightKg] * PlayerItems[playerid][i]);
		strcat(list, line);
	}
	if (!hasItems)
	{
		strcat(list, "(keine Gegenstaende)\n");
	}
	new title[64];
	format(title, sizeof(title), "Inventar (%d/%dkg)", weight, maxWeight);
	ShowPlayerDialog(playerid, DIALOG_INVENTORY, DIALOG_STYLE_LIST, title, list, "Waehlen", "Schliessen");
	return 1;
}

stock ShowVehicleItemsDialog(playerid, vehicleid)
{
	new list[768];
	list[0] = EOS;
	new itemName[MAX_ITEM_NAME];
	new hasItems = 0;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (VehicleItems[vehicleid][i] < 1)
		{
			continue;
		}
		hasItems = 1;
		GetItemName(i, itemName, sizeof(itemName));
		new line[64];
		format(line, sizeof(line), "%s x%d (%dkg)\n", itemName, VehicleItems[vehicleid][i],
			gItems[i][itemWeightKg] * VehicleItems[vehicleid][i]);
		strcat(list, line);
	}
	if (!hasItems)
	{
		strcat(list, "(leer)\n");
	}
	ShowPlayerDialog(playerid, DIALOG_VEHICLE_ITEMS, DIALOG_STYLE_LIST, "Kofferraum", list, "Nehmen", "Schliessen");
	return 1;
}

stock Law_BuildIllegalListPlayer(playerid, list[], size)
{
	new count = 0;
	list[0] = '\0';
	new itemName[MAX_ITEM_NAME];
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (PlayerItems[playerid][i] < 1 || !IsItemIllegal(i))
		{
			continue;
		}
		GetItemName(i, itemName, sizeof(itemName));
		new line[64];
		format(line, sizeof(line), "%s x%d\n", itemName, PlayerItems[playerid][i]);
		strcat(list, line, size);
		count++;
	}
	return count;
}

stock Law_BuildIllegalListVehicle(vehicleid, list[], size)
{
	new count = 0;
	list[0] = '\0';
	new itemName[MAX_ITEM_NAME];
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (VehicleItems[vehicleid][i] < 1 || !IsItemIllegal(i))
		{
			continue;
		}
		GetItemName(i, itemName, sizeof(itemName));
		new line[64];
		format(line, sizeof(line), "%s x%d\n", itemName, VehicleItems[vehicleid][i]);
		strcat(list, line, size);
		count++;
	}
	return count;
}

stock LogLawEvent(const event[], playerid, targetid, const detail[] = "")
{
	new name[MAX_PLAYER_NAME];
	new target[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	if (IsPlayerConnected(targetid))
	{
		GetPlayerName(targetid, target, sizeof(target));
	}
	else
	{
		format(target, sizeof(target), "id=%d", targetid);
	}
	if (detail[0] != '\0')
	{
		printf("[LAW] %s by %s on %s: %s", event, name, target, detail);
		Law_LogRecord(playerid, targetid, event, detail);
		if (!strcmp(event, "search_hit", true) || !strcmp(event, "searchveh_hit", true))
		{
			gEconomyHeat += 1;
			if (targetid >= 0 && targetid < MAX_PLAYERS)
			{
				gCrimeHeat[targetid] += 1;
			}
		}
		return 1;
	}
	printf("[LAW] %s by %s on %s", event, name, target);
	Law_LogRecord(playerid, targetid, event, "");
	return 1;
}

stock GetNearestBusiness(playerid, Float:radius = BUSINESS_BUY_RADIUS)
{
	new Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid, px, py, pz);

	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		if (GetPlayerDistanceFromPoint(playerid, BusinessData[i][bX], BusinessData[i][bY], BusinessData[i][bZ]) <= radius)
		{
			return i;
		}
	}
	return -1;
}

stock UpdateBusinessLabel(businessId)
{
	if (businessId < 0 || businessId >= MAX_BUSINESSES)
	{
		return 0;
	}

	new label[192];
	new ownerName[MAX_PLAYER_NAME] = "For Sale";
	if (BusinessData[businessId][bOwner] != INVALID_PLAYER_ID && IsPlayerConnected(BusinessData[businessId][bOwner]))
	{
		GetPlayerName(BusinessData[businessId][bOwner], ownerName, sizeof(ownerName));
	}

	if (BusinessData[businessId][bOwner] == INVALID_PLAYER_ID)
	{
		format(label, sizeof(label),
			"%s\nPrice: $%d\nPress Y for details",
			gBusinessTypeNames[_:BusinessData[businessId][bType]],
			BusinessData[businessId][bPrice]
		);
	}
	else
	{
		format(label, sizeof(label),
			"%s\nOwner: %s\nComponents: %d",
			gBusinessTypeNames[_:BusinessData[businessId][bType]],
			ownerName,
			BusinessData[businessId][bComponents]
		);
	}

	if (BusinessLabels[businessId] != Text3D:0)
	{
		Delete3DTextLabel(BusinessLabels[businessId]);
	}
	BusinessLabels[businessId] = Create3DTextLabel(label, 0xF5E76AFF, BusinessData[businessId][bX], BusinessData[businessId][bY], BusinessData[businessId][bZ] + 0.8, BUSINESS_LABEL_DISTANCE, 0, 0);
	return 1;
}

stock ShowBusinessStatus(playerid, businessId)
{
	if (businessId < 0 || businessId >= MAX_BUSINESSES)
	{
		SendClientMessage(playerid, -1, "Invalid business.");
		return 1;
	}

	new owner = BusinessData[businessId][bOwner];
	new ownerName[MAX_PLAYER_NAME] = "None";
	if (owner != INVALID_PLAYER_ID && IsPlayerConnected(owner))
	{
		GetPlayerName(owner, ownerName, sizeof(ownerName));
	}

	new message[144];
	format(message, sizeof(message),
		"Business %d (%s) | Owner: %s | Components: %d | Component price: $%d | Earnings: $%d",
		businessId + 1,
		gBusinessTypeNames[_:BusinessData[businessId][bType]],
		ownerName,
		BusinessData[businessId][bComponents],
		BusinessData[businessId][bComponentPrice],
		BusinessData[businessId][bEarnings]
	);
	SendClientMessage(playerid, -1, message);
	return 1;
}

stock ClearDeliveryCheckpoint(playerid)
{
	if (PlayerData[playerid][pHasDelivery])
	{
		ClearPlayerCheckpointEx(playerid);
		PlayerData[playerid][pHasDelivery] = false;
		PlayerData[playerid][pDeliveryBiz] = -1;
	}
	return 1;
}

stock bool:IsNearComponentWarehouse(playerid, Float:radius = 4.0)
{
	return GetPlayerDistanceFromPoint(playerid, COMPONENT_WAREHOUSE_X, COMPONENT_WAREHOUSE_Y, COMPONENT_WAREHOUSE_Z) <= radius;
}

stock DeliverComponents(playerid, businessId)
{
	if (businessId < 0 || businessId >= MAX_BUSINESSES)
	{
		SendClientMessage(playerid, -1, "Usage: /deliverbiz [businessId]");
		return 1;
	}

	new crateCount = PlayerItems[playerid][ITEM_CRATE];
	if (crateCount < 1)
	{
		SendClientMessage(playerid, -1, "You have no crates to deliver.");
		return 1;
	}

	if (!PlayerData[playerid][pHasDelivery] &&
		GetPlayerDistanceFromPoint(playerid, BusinessData[businessId][bX], BusinessData[businessId][bY], BusinessData[businessId][bZ]) > BUSINESS_BUY_RADIUS)
	{
		SendClientMessage(playerid, -1, "You must be at the business to deliver.");
		return 1;
	}

	new delivered = crateCount;
	new payout = delivered * BusinessData[businessId][bComponentPrice];
	BusinessData[businessId][bComponents] += delivered;
	RemovePlayerItem(playerid, ITEM_CRATE, delivered);

	if (payout > 0)
	{
		GivePlayerMoney(playerid, payout);
	}

	new message[128];
	format(message, sizeof(message), "Lieferung abgeschlossen: %d Kisten, $%d verdient. Lagerbestand: %d.",
		delivered, payout, BusinessData[businessId][bComponents]);
	SendClientMessage(playerid, -1, message);
	ShowBusinessStatus(playerid, businessId);
	UpdateBusinessLabel(businessId);
	Activity_Mark(playerid, ACTIVITY_DELIVERY);
	return 1;
}

stock ReleasePlayerBusinesses(playerid)
{
	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		if (BusinessData[i][bOwner] == playerid)
		{
			BusinessData[i][bOwner] = INVALID_PLAYER_ID;
			BusinessData[i][bComponents] = 0;
			BusinessData[i][bEarnings] = 0;
			UpdateBusinessLabel(i);
		}
	}
	return 1;
}

enum eTeleportPoint
{
	Float:tX,
	Float:tY,
	Float:tZ,
	Float:tA,
	tInterior,
	tWorld
};

enum eTeleport
{
	tEntry,
	tExit
};

new const gTeleports[][eTeleport][eTeleportPoint] =
{
	{
		{ 269.1355, -1002.5511, 29.3317, 90.0, 0, 0 },
		{ -1152.1948, -1520.1556, 10.6328, 180.0, 0, 0 }
	},
	{
		{ 372.0581, -1004.3589, 29.4138, 270.0, 0, 0 },
		{ -769.2115, 323.9313, 211.3962, 90.0, 0, 0 }
	},
	{
		{ -561.9644, 286.7379, 82.1764, 0.0, 0, 0 },
		{ -176.4835, 502.6943, 137.4201, 270.0, 0, 0 }
	}
};

new Text3D:gTeleportLabels[sizeof(gTeleports)][eTeleport];

stock ResetPlayerData(playerid)
{
	PlayerData[playerid][pLogged] = false;
	PlayerData[playerid][pRegistering] = false;
	PlayerData[playerid][pAuthChecked] = false;
	PlayerData[playerid][pAccountId] = INVALID_ACCOUNT_ID;
	PlayerData[playerid][pTutorialDone] = false;
	PlayerData[playerid][pAuthStartTick] = 0;
	PlayerData[playerid][pAuthRetries] = 0;
	PlayerData[playerid][pGarageInside] = false;
	PlayerData[playerid][pGarageLocked] = false;
	PlayerData[playerid][pSkin] = 0;
	PlayerData[playerid][pMoney] = 0;
	PlayerData[playerid][pSelectedItem] = -1;
	PlayerData[playerid][pSelectedAction] = ACTION_NONE;
	PlayerData[playerid][pX] = PREVIEW_X;
	PlayerData[playerid][pY] = PREVIEW_Y;
	PlayerData[playerid][pZ] = PREVIEW_Z;
	PlayerData[playerid][pA] = PREVIEW_A;
	PlayerData[playerid][pInterior] = 0;
	PlayerData[playerid][pWorld] = 0;
	PlayerData[playerid][pParts] = 0;
	PlayerData[playerid][pLastTeleportTick] = 0;
	PlayerData[playerid][pCrates] = 0;
	PlayerData[playerid][pDeliveryBiz] = -1;
	PlayerData[playerid][pHasDelivery] = false;
	PlayerData[playerid][pAddiction] = 0;
	PlayerData[playerid][pHunger] = 100;
	PlayerData[playerid][pThirst] = 100;
	PlayerData[playerid][pFatigue] = 0;
	PlayerData[playerid][pLastAddictionTick] = GetTickCount();
	PlayerData[playerid][pDrugEffectEndTick] = 0;
	PlayerData[playerid][pCarryLimit] = BASE_CARRY_LIMIT_KG;
	PlayerData[playerid][pVehicleRegistered] = false;
	PlayerData[playerid][pTaxesPaid] = false;
	PlayerData[playerid][pInsured] = false;
	PlayerData[playerid][pNextBilling] = 0;
	PlayerData[playerid][pRadioVisible] = true;
	PlayerData[playerid][pRadioStation] = 0;
	PlayerData[playerid][pPetActor] = INVALID_ACTOR_ID;
	PlayerData[playerid][pPetTask] = PET_TASK_NONE;
	PlayerData[playerid][pPetTimer] = 0;
	PlayerData[playerid][pMiniGame] = MINIGAME_NONE;
	PlayerData[playerid][pMiniVehicle] = INVALID_VEHICLE_ID;
	PlayerData[playerid][pMiniStep] = 0;
	PlayerData[playerid][pMiniTimer] = 0;
	PlayerData[playerid][pJobDailyCount] = 0;
	PlayerData[playerid][pJobDailyDay] = 0;
	PlayerData[playerid][pJobDailyMonth] = 0;
	PlayerData[playerid][pJobDailyYear] = 0;
	PlayerData[playerid][pActivityFlags] = 0;
	PlayerData[playerid][pActivityBonusClaimed] = false;
	PlayerData[playerid][pActivityDay] = 0;
	PlayerData[playerid][pActivityMonth] = 0;
	PlayerData[playerid][pActivityYear] = 0;
	PlayerData[playerid][pWarehouseWaypoint] = false;
	for (new i = 0; i < MINIGAME_KEYS; i++)
	{
		PlayerData[playerid][pMiniKeySequence][i] = 0;
	}
	PlayerData[playerid][pPassHash][0] = '\0';
	PlayerData[playerid][pLoginAttempts] = 0;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		PlayerItems[playerid][i] = 0;
	}
	for (new i = 0; i < MAX_ITEM_SHORTCUTS; i++)
	{
		gItemShortcuts[playerid][i] = -1;
	}
	gAlprEnabled[playerid] = false;
	gHasLicense[playerid] = true;
	gTaxDue[playerid] = false;
	gLspdDuty[playerid] = false;
	gCrimeHeat[playerid] = 0;
	Faction_ResetPlayer(playerid);
	Map_ResetPlayer(playerid);
	if (gAlprTimer[playerid] != 0)
	{
		KillTimer(gAlprTimer[playerid]);
		gAlprTimer[playerid] = 0;
	}
	Job_ResetPlayer(playerid);
	gCinemaWatching[playerid] = false;
	gTaxiOnDuty[playerid] = false;
	gTaxiRequesting[playerid] = false;
	TaxiDriverForCustomer[playerid] = INVALID_PLAYER_ID;
	TaxiCustomerForDriver[playerid] = INVALID_PLAYER_ID;
	TaxiFare[playerid] = TAXI_DEFAULT_FARE;
	TaxiRentalEndTick[playerid] = 0;
	TaxiRentalNotifiedFive[playerid] = false;
	TaxiRentalNotifiedOne[playerid] = false;
	TaxiRentalVehicle[playerid] = INVALID_VEHICLE_ID;
	TaxiMeterActive[playerid] = false;
	TaxiMeterFareTotal[playerid] = 0;
	TaxiMeterElapsed[playerid] = 0;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		PlayerItems[playerid][i] = 0;
	}
	return 1;
}

stock CancelMiniGame(playerid)
{
	if (PlayerData[playerid][pMiniTimer] != 0)
	{
		KillTimer(PlayerData[playerid][pMiniTimer]);
		PlayerData[playerid][pMiniTimer] = 0;
	}

	PlayerData[playerid][pMiniGame] = MINIGAME_NONE;
	PlayerData[playerid][pMiniVehicle] = INVALID_VEHICLE_ID;
	PlayerData[playerid][pMiniStep] = 0;
	return 1;
}

stock GetMiniGameDifficulty(vehicleid)
{
	new difficulty = gVehicleLockLevel[vehicleid] + gVehicleAlarmLevel[vehicleid];
	difficulty += gVehicleMarketPrice[vehicleid] / 20000;
	difficulty += gVehicleManufacturer[vehicleid];
	if (difficulty < 1)
	{
		difficulty = 1;
	}
	return difficulty;
}

stock GetNearestVehicle(playerid, Float:radius)
{
	new Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid, px, py, pz);

	new Float:bestDistance = radius;
	new vehicleid = INVALID_VEHICLE_ID;

	for (new i = 1; i < MAX_VEHICLES; i++)
	{
		if (!IsValidVehicle(i))
		{
			continue;
		}

		new Float:vx, Float:vy, Float:vz;
		GetVehiclePos(i, vx, vy, vz);
		new Float:distance = floatsqroot((vx - px) * (vx - px) + (vy - py) * (vy - py) + (vz - pz) * (vz - pz));
		if (distance <= bestDistance)
		{
			bestDistance = distance;
			vehicleid = i;
		}
	}
	return vehicleid;
}

stock ShowMiniGameHelp(playerid)
{
	if (PlayerData[playerid][pMiniGame] == MINIGAME_LOCKPICK)
	{
		SendClientMessage(playerid, -1, "Lockpick: press the shown key sequence in order. Press H to repeat this help.");
		SendClientMessage(playerid, -1, "Higher lock/alarm levels give you less time.");
	}
	else if (PlayerData[playerid][pMiniGame] == MINIGAME_HOTWIRE)
	{
		SendClientMessage(playerid, -1, "Hotwire: match the key sequence before the timer runs out.");
		SendClientMessage(playerid, -1, "Quick success starts the engine. Failure can trigger the alarm.");
	}
	return 1;
}

stock ShowMiniGamePrompt(playerid)
{
	new step = PlayerData[playerid][pMiniStep];
	new keyIndex = PlayerData[playerid][pMiniKeySequence][step];

	new message[96];
	format(message, sizeof(message), "~w~Press ~y~%s~w~ (%d/%d)~n~~b~Press H for help", gMiniKeyNames[keyIndex], step + 1, MINIGAME_KEYS);
	GameTextForPlayer(playerid, message, 3000, 3);
	return 1;
}

stock StartMiniGame(playerid, vehicleid, minigameType)
{
	CancelMiniGame(playerid);

	PlayerData[playerid][pMiniGame] = minigameType;
	PlayerData[playerid][pMiniVehicle] = vehicleid;
	PlayerData[playerid][pMiniStep] = 0;

	for (new i = 0; i < MINIGAME_KEYS; i++)
	{
		PlayerData[playerid][pMiniKeySequence][i] = random(sizeof(gMiniKeys));
	}

	new difficulty = GetMiniGameDifficulty(vehicleid);
	new timeLimit = 6500 - (difficulty * 400);
	if (timeLimit < 2500)
	{
		timeLimit = 2500;
	}
	if (timeLimit > 9000)
	{
		timeLimit = 9000;
	}

	PlayerData[playerid][pMiniTimer] = SetTimerEx("OnMiniGameTimeout", timeLimit, false, "i", playerid);
	ShowMiniGamePrompt(playerid);
	new info[96];
	format(info, sizeof(info), "Difficulty %d: lock %d, alarm %d.", difficulty, gVehicleLockLevel[vehicleid], gVehicleAlarmLevel[vehicleid]);
	SendClientMessage(playerid, -1, info);
	return 1;
}

stock FailMiniGame(playerid, const reason[])
{
	new vehicleid = PlayerData[playerid][pMiniVehicle];
	if (vehicleid != INVALID_VEHICLE_ID && IsValidVehicle(vehicleid))
	{
		new engine, lights, alarm, doors, bonnet, boot, objective;
		GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
		SetVehicleParamsEx(vehicleid, engine, lights, 1, doors, bonnet, boot, objective);
	}

	SendClientMessage(playerid, -1, reason);
	CancelMiniGame(playerid);
	return 1;
}

stock CompleteMiniGame(playerid)
{
	new vehicleid = PlayerData[playerid][pMiniVehicle];
	if (PlayerData[playerid][pMiniGame] == MINIGAME_LOCKPICK)
	{
		if (vehicleid != INVALID_VEHICLE_ID && IsValidVehicle(vehicleid))
		{
			new engine, lights, alarm, doors, bonnet, boot, objective;
			GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
			SetVehicleParamsEx(vehicleid, engine, lights, 0, 0, bonnet, boot, objective);
			GameTextForPlayer(playerid, "~g~Vehicle unlocked!", 2000, 3);
		}
	}
	else if (PlayerData[playerid][pMiniGame] == MINIGAME_HOTWIRE)
	{
		if (vehicleid != INVALID_VEHICLE_ID && IsValidVehicle(vehicleid))
		{
			new engine, lights, alarm, doors, bonnet, boot, objective;
			GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
			SetVehicleParamsEx(vehicleid, 1, lights, 0, doors, bonnet, boot, objective);
			GameTextForPlayer(playerid, "~g~Engine started!", 2000, 3);
		}
	}

	CancelMiniGame(playerid);
	return 1;
}

stock DestroyPet(playerid)
{
	if (PlayerData[playerid][pPetTimer] != 0)
	{
		KillTimer(PlayerData[playerid][pPetTimer]);
		PlayerData[playerid][pPetTimer] = 0;
	}

	if (PlayerData[playerid][pPetActor] != INVALID_ACTOR_ID)
	{
		DestroyActor(PlayerData[playerid][pPetActor]);
		PlayerData[playerid][pPetActor] = INVALID_ACTOR_ID;
	}

	PlayerData[playerid][pPetTask] = PET_TASK_NONE;
	return 1;
}

stock CreatePet(playerid, petIndex)
{
	if (petIndex < 0 || petIndex >= sizeof(gPetSkins))
	{
		return 0;
	}

	DestroyPet(playerid);

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid, x, y, z);

	PlayerData[playerid][pPetActor] = CreateActor(gPetSkins[petIndex], x + 1.0, y, z, 0.0);
	if (PlayerData[playerid][pPetActor] == INVALID_ACTOR_ID)
	{
		return 0;
	}

	SetActorVirtualWorld(PlayerData[playerid][pPetActor], GetPlayerVirtualWorld(playerid));
	SetActorInvulnerable(PlayerData[playerid][pPetActor], true);

	PlayerData[playerid][pPetTask] = PET_TASK_STAY;
	PlayerData[playerid][pPetTimer] = SetTimerEx("PetUpdate", PET_UPDATE_MS, true, "i", playerid);
	return 1;
}

stock SetPetTask(playerid, task)
{
	PlayerData[playerid][pPetTask] = task;
	return 1;
}

stock ApplyPetAnimation(playerid, const animLib[], const animName[], Float:delta = 4.1, loop = 0, lockX = 1, lockY = 1, freeze = 0, time = 0)
{
	if (PlayerData[playerid][pPetActor] == INVALID_ACTOR_ID)
	{
		return 0;
	}
	ApplyActorAnimation(PlayerData[playerid][pPetActor], animLib, animName, delta, loop, lockX, lockY, freeze, time);
	return 1;
}

stock PetExists(playerid)
{
	return PlayerData[playerid][pPetActor] != INVALID_ACTOR_ID;
}

stock GetPetIndex(const petName[])
{
	for (new i = 0; i < sizeof(gPetNames); i++)
	{
		if (!strcmp(petName, gPetNames[i], true))
		{
			return i;
		}
	}
	return -1;
}

stock ApplyScreenEffect(playerid, bool:strong)
{
	if (strong)
	{
		SetPlayerDrunkLevel(playerid, 30000);
	}
	else
	{
		SetPlayerDrunkLevel(playerid, 15000);
	}
	PlayerData[playerid][pDrugEffectEndTick] = GetTickCount() + (3 * 60 * 1000);
	return 1;
}

stock Float:GetAddictionMultiplier(playerid)
{
	new Float:multiplier = 1.0 - (float(PlayerData[playerid][pAddiction]) * 0.01);
	if (multiplier < 0.2)
	{
		multiplier = 0.2;
	}
	return multiplier;
}

stock IncreaseAddiction(playerid, bool:skipChance)
{
	if (skipChance && random(5) == 0)
	{
		return 1;
	}
	PlayerData[playerid][pAddiction] += 1;
	if (PlayerData[playerid][pAddiction] > 100)
	{
		PlayerData[playerid][pAddiction] = 100;
	}
	return 1;
}

stock UseMarijuana(playerid)
{
	new Float:health;
	GetPlayerHealth(playerid, health);

	new Float:multiplier = GetAddictionMultiplier(playerid);
	new Float:target = 115.0;
	new Float:bonus = (target - health) * multiplier;
	if (bonus < 0.0)
	{
		bonus = 0.0;
	}
	SetPlayerHealth(playerid, floatmin(200.0, health + bonus));
	ApplyScreenEffect(playerid, false);
	IncreaseAddiction(playerid, true);
	return 1;
}

stock UseCocaine(playerid)
{
	new Float:health;
	GetPlayerHealth(playerid, health);
	new Float:multiplier = GetAddictionMultiplier(playerid);
	new Float:bonus = 50.0 * multiplier;
	SetPlayerHealth(playerid, floatmin(200.0, health + bonus));
	ApplyScreenEffect(playerid, true);
	IncreaseAddiction(playerid, false);
	return 1;
}

stock UseHeroin(playerid)
{
	new Float:multiplier = GetAddictionMultiplier(playerid);
	new Float:carryBonus = floatround(5.0 * multiplier, floatround_floor);
	if (carryBonus < 1)
	{
		carryBonus = 1;
	}
	PlayerData[playerid][pCarryLimit] += carryBonus;
	if (PlayerData[playerid][pCarryLimit] > MAX_CARRY_LIMIT_KG)
	{
		PlayerData[playerid][pCarryLimit] = MAX_CARRY_LIMIT_KG;
	}
	ApplyScreenEffect(playerid, true);
	IncreaseAddiction(playerid, false);
	return 1;
}

stock UseMethadone(playerid)
{
	PlayerData[playerid][pAddiction] -= 5;
	if (PlayerData[playerid][pAddiction] < 0)
	{
		PlayerData[playerid][pAddiction] = 0;
	}
	return 1;
}

stock ApplyNeedClamp(playerid)
{
	if (PlayerData[playerid][pHunger] < 0) PlayerData[playerid][pHunger] = 0;
	if (PlayerData[playerid][pThirst] < 0) PlayerData[playerid][pThirst] = 0;
	if (PlayerData[playerid][pFatigue] < 0) PlayerData[playerid][pFatigue] = 0;
	if (PlayerData[playerid][pHunger] > NEED_MAX) PlayerData[playerid][pHunger] = NEED_MAX;
	if (PlayerData[playerid][pThirst] > NEED_MAX) PlayerData[playerid][pThirst] = NEED_MAX;
	if (PlayerData[playerid][pFatigue] > NEED_MAX) PlayerData[playerid][pFatigue] = NEED_MAX;
	return 1;
}

stock ApplyNeedDecay(playerid)
{
	if (!PlayerData[playerid][pLogged])
	{
		return 0;
	}
	PlayerData[playerid][pHunger] -= 2;
	PlayerData[playerid][pThirst] -= 3;
	PlayerData[playerid][pFatigue] += 2;
	ApplyNeedClamp(playerid);

	if (PlayerData[playerid][pHunger] <= 0 || PlayerData[playerid][pThirst] <= 0)
	{
		new Float:health;
		GetPlayerHealth(playerid, health);
		SetPlayerHealth(playerid, floatmin(200.0, health - 2.0));
	}

	if (PlayerData[playerid][pHunger] <= NEED_WARN || PlayerData[playerid][pThirst] <= NEED_WARN)
	{
		SendClientMessage(playerid, -1, "Du fuehlst dich schwaecher. Iss und trink etwas.");
	}
	return 1;
}

stock UseInventoryItem(playerid, itemid)
{
	if (!IsValidItem(itemid))
	{
		return 0;
	}

	switch (itemid)
	{
		case 0: // Wasserflasche
		{
			PlayerData[playerid][pThirst] += 25;
		}
		case 1: // Sandwich
		{
			PlayerData[playerid][pHunger] += 25;
		}
		case 2: // Verband
		{
			new Float:health;
			GetPlayerHealth(playerid, health);
			SetPlayerHealth(playerid, floatmin(200.0, health + 10.0));
		}
		case 3: // Medikit
		{
			new Float:health;
			GetPlayerHealth(playerid, health);
			SetPlayerHealth(playerid, floatmin(200.0, health + 35.0));
		}
		default:
		{
			return 0;
		}
	}
	ApplyNeedClamp(playerid);
	return 1;
}

public NeedsTick()
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (IsPlayerConnected(i) && PlayerData[i][pLogged])
		{
			ApplyNeedDecay(i);
		}
	}
	return 1;
}

stock bool:HasIllegalItemsPlayer(playerid)
{
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (PlayerItems[playerid][i] > 0 && IsItemIllegal(i))
		{
			return true;
		}
	}
	return false;
}

public CrimeTick()
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i) || !PlayerData[i][pLogged])
		{
			continue;
		}
		if (HasIllegalItemsPlayer(i))
		{
			gCrimeHeat[i] += 1;
		}
		else if (gCrimeHeat[i] > 0)
		{
			gCrimeHeat[i] -= 1;
		}
	}
	if (gEconomyHeat > 0)
	{
		gEconomyHeat -= 1;
	}
	return 1;
}

public EconomyTick()
{
	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		new stockCount = BusinessData[i][bComponents];
		new base = 650;
		if (stockCount < 20) base += 200;
		if (stockCount > 80) base -= 100;
		base += (gEconomyHeat * 10);
		if (base < 300) base = 300;
		if (base > 1200) base = 1200;
		BusinessData[i][bComponentPrice] = base;
		UpdateBusinessLabel(i);
	}
	return 1;
}

stock ToUpperStr(str[])
{
	for (new i = 0; str[i] != '\0'; i++)
	{
		if (str[i] >= 'a' && str[i] <= 'z')
		{
			str[i] -= 32;
		}
	}
	return 1;
}

stock GetVehicleNumberPlate(vehicleid, plate[], size = MAX_PLATE_LEN)
{
	if (vehicleid == INVALID_VEHICLE_ID)
	{
		plate[0] = '\0';
		return 0;
	}
	if (gVehiclePlates[vehicleid][0] != '\0')
	{
		format(plate, size, "%s", gVehiclePlates[vehicleid]);
		return 1;
	}
	format(plate, size, "VEH%04d", vehicleid);
	return 1;
}

stock SetVehiclePlate(vehicleid, const plate[])
{
	if (vehicleid == INVALID_VEHICLE_ID)
	{
		return 0;
	}
	format(gVehiclePlates[vehicleid], sizeof(gVehiclePlates[]), "%s", plate);
	SetVehicleNumberPlate(vehicleid, plate);
	return 1;
}

stock GenerateVehiclePlate(vehicleid, plate[], size = MAX_PLATE_LEN)
{
	new randomSeed = random(9999);
	format(plate, size, "SA%02d%02d", vehicleid % 100, randomSeed % 100);
	return 1;
}

stock InitVehiclePlate(vehicleid)
{
	new plate[MAX_PLATE_LEN];
	GenerateVehiclePlate(vehicleid, plate, sizeof(plate));
	SetVehiclePlate(vehicleid, plate);
	return 1;
}

stock GetVehicleOccupant(vehicleid, seat)
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i))
		{
			continue;
		}
		if (GetPlayerVehicleID(i) != vehicleid)
		{
			continue;
		}
		if (GetPlayerVehicleSeat(i) != seat)
		{
			continue;
		}
		return i;
	}
	return INVALID_PLAYER_ID;
}

stock IsPoliceVehicle(vehicleid)
{
	switch (GetVehicleModel(vehicleid))
	{
		case 596, 597, 598, 599, 601, 427, 528:
		{
			return 1;
		}
	}
	return 0;
}

stock ParseCommand(const cmdtext[], cmd[], cmdlen, params[], paramslen)
{
	new i = 0;
	while (cmdtext[i] != '\0' && cmdtext[i] != ' ' && i < cmdlen - 1)
	{
		cmd[i] = cmdtext[i];
		i++;
	}
	cmd[i] = '\0';

	while (cmdtext[i] == ' ')
	{
		i++;
	}

	new j = 0;
	while (cmdtext[i] != '\0' && j < paramslen - 1)
	{
		params[j] = cmdtext[i];
		i++;
		j++;
	}
	params[j] = '\0';
	return 1;
}

stock GetCommandToken(const cmdtext[], &index, token[], size)
{
	new len = strlen(cmdtext);
	while (index < len && cmdtext[index] == ' ')
	{
		index++;
	}

	new i = 0;
	while (index < len && cmdtext[index] != ' ' && i < size - 1)
	{
		token[i++] = cmdtext[index++];
	}
	token[i] = '\0';
	return i;
}

stock bool:IsPlateStolen(const plate[])
{
	for (new i = 0; i < gStolenPlateCount; i++)
	{
		if (!strcmp(gStolenPlates[i], plate, false))
		{
			return true;
		}
	}
	return false;
}

stock StartAlpr(playerid)
{
	if (gAlprTimer[playerid] != 0)
	{
		KillTimer(gAlprTimer[playerid]);
	}
	gAlprTimer[playerid] = SetTimerEx("AlprScan", ALPR_SCAN_INTERVAL, true, "i", playerid);
	return 1;
}

stock StopAlpr(playerid, bool:notify = true)
{
	gAlprEnabled[playerid] = false;
	if (gAlprTimer[playerid] != 0)
	{
		KillTimer(gAlprTimer[playerid]);
		gAlprTimer[playerid] = 0;
	}
	if (notify)
	{
		SendClientMessage(playerid, -1, "ALPR disabled.");
	}
	return 1;
}

stock AddStolenPlate(const plate[])
{
	if (gStolenPlateCount >= MAX_STOLEN_PLATES)
	{
		return 0;
	}

	if (IsPlateStolen(plate))
	{
		return 0;
	}

	format(gStolenPlates[gStolenPlateCount], MAX_PLATE_LEN, "%s", plate);
	gStolenPlateCount++;
	if (gDatabaseReady)
	{
		new query[128];
		mysql_format(g_SQL, query, sizeof(query),
			"INSERT IGNORE INTO `stolen_plates` (`plate`) VALUES ('%e')",
			plate
		);
		mysql_tquery(g_SQL, query);
	}
	return 1;
}

stock RemoveStolenPlate(const plate[])
{
	for (new i = 0; i < gStolenPlateCount; i++)
	{
		if (!strcmp(gStolenPlates[i], plate, false))
		{
			for (new j = i; j < gStolenPlateCount - 1; j++)
			{
				format(gStolenPlates[j], MAX_PLATE_LEN, "%s", gStolenPlates[j + 1]);
			}
			gStolenPlateCount--;
			if (gDatabaseReady)
			{
				new query[128];
				mysql_format(g_SQL, query, sizeof(query),
					"DELETE FROM `stolen_plates` WHERE `plate`='%e'",
					plate
				);
				mysql_tquery(g_SQL, query);
			}
			return 1;
		}
	}
	return 0;
}

stock LoadStolenPlates()
{
	if (!gDatabaseReady)
	{
		return 0;
	}
	mysql_tquery(g_SQL, "SELECT `plate` FROM `stolen_plates`", "OnStolenPlatesLoad", "");
	return 1;
}

stock bool:TaxiIsVehicleTaxi(vehicleid)
{
	if (vehicleid == INVALID_VEHICLE_ID)
	{
		return false;
	}
	new model = GetVehicleModel(vehicleid);
	return (model == 420 || model == 438);
}

stock TaxiResetRequestForCustomer(customerid)
{
	new driverid = TaxiDriverForCustomer[customerid];
	if (driverid != INVALID_PLAYER_ID)
	{
		TaxiCustomerForDriver[driverid] = INVALID_PLAYER_ID;
		ClearPlayerCheckpointEx(driverid);
	}
	gTaxiRequesting[customerid] = false;
	TaxiDriverForCustomer[customerid] = INVALID_PLAYER_ID;
	return 1;
}

stock TaxiResetRequestForDriver(driverid)
{
	new customerid = TaxiCustomerForDriver[driverid];
	if (customerid != INVALID_PLAYER_ID)
	{
		TaxiDriverForCustomer[customerid] = INVALID_PLAYER_ID;
		gTaxiRequesting[customerid] = false;
	}
	TaxiCustomerForDriver[driverid] = INVALID_PLAYER_ID;
	ClearPlayerCheckpointEx(driverid);
	return 1;
}

stock TaxiSendToOnDuty(const message[])
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (IsPlayerConnected(i) && gTaxiOnDuty[i])
		{
			SendClientMessage(i, -1, message);
		}
	}
	return 1;
}

stock TaxiMinutesRemaining(playerid)
{
	if (TaxiRentalEndTick[playerid] == 0)
	{
		return 0;
	}

	new remaining = TaxiRentalEndTick[playerid] - GetTickCount();
	if (remaining <= 0)
	{
		return 0;
	}
	return (remaining + 59999) / 60000;
}

stock TaxiStartMeter(driverid)
{
	TaxiMeterActive[driverid] = true;
	TaxiMeterFareTotal[driverid] = 0;
	TaxiMeterElapsed[driverid] = 0;
	SendClientMessage(driverid, -1, "Taxi meter started.");
	return 1;
}

stock TaxiStopMeter(driverid)
{
	if (!TaxiMeterActive[driverid])
	{
		return 1;
	}
	TaxiMeterActive[driverid] = false;
	TaxiMeterElapsed[driverid] = 0;
	new message[64];
	format(message, sizeof(message), "Taxi meter stopped. Total fare: $%d.", TaxiMeterFareTotal[driverid]);
	SendClientMessage(driverid, -1, message);
	return 1;
}

stock PlayStationForPlayer(playerid, station)
{
	if (station < 1 || station > MAX_STATIONS)
	{
		new message[64];
		format(message, sizeof(message), "Station must be between 1 and %d.", MAX_STATIONS);
		SendClientMessage(playerid, -1, message);
		return 0;
	}

	if (gStationUrls[station - 1][0] == '\0')
	{
		SendClientMessage(playerid, -1, "Station unavailable.");
		return 0;
	}

	PlayAudioStreamForPlayer(playerid, gStationUrls[station - 1]);
	PlayerData[playerid][pRadioStation] = station;
	return 1;
}

stock StopStationForPlayer(playerid)
{
	StopAudioStreamForPlayer(playerid);
	PlayerData[playerid][pRadioStation] = 0;
	return 1;
}

stock GetCommandArg(const cmdtext[], argIndex, arg[], argSize)
{
	new idx = 0;
	new start = 0;
	new len = strlen(cmdtext);
	new currentArg = -1;

	while (idx <= len)
	{
		if (cmdtext[idx] == ' ' || cmdtext[idx] == '\0')
		{
			if (idx > start)
			{
				currentArg++;
				if (currentArg == argIndex)
				{
					new copyLen = idx - start;
					if (copyLen >= argSize)
					{
						copyLen = argSize - 1;
					}
					strmid(arg, cmdtext, start, start + copyLen, argSize);
					return 1;
				}
			}
			start = idx + 1;
		}
		idx++;
	}

	arg[0] = '\0';
	return 0;
}

stock ShowLoginDialog(playerid, const message[] = "Enter your password:")
{
	ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", message, "Login", "Quit");
	return 1;
}

stock ShowRegisterDialog(playerid, const message[] = "Create a password for this account:")
{
	ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register", message, "Register", "Quit");
	return 1;
}

stock ShowGarageInfoDialog(playerid)
{
	new info[512];
	info[0] = EOS;
	strcat(info, "Garages are owned by players or organizations.\n");
	strcat(info, "A mechanic can repair, mod, or paint vehicles, plus install locks and alarms.\n");
	strcat(info, "\n");
	strcat(info, "Commands:\n");
	strcat(info, "/repair /paint /lock /alarm /mod\n");
	strcat(info, "/chop /wanted /craft\n");
	strcat(info, "\n");
	strcat(info, "Illegal garage features:\n");
	strcat(info, "- Chop a vehicle to receive car parts.\n");
	strcat(info, "- View the wanted cars list.");
	ShowPlayerDialog(
		playerid,
		DIALOG_GARAGE_INFO,
		DIALOG_STYLE_MSGBOX,
		"Garage & Chop Shops",
		info,
		"Close",
		""
	);
	return 1;
}

stock ShowGarageHelp(playerid)
{
	new message[768];
	strcat(message, "Residential garages commands:\n\n");
	strcat(message, "Press Y - Enter/exit an unlocked garage while on foot.\n");
	strcat(message, "Press K - Enter/exit an unlocked garage while on foot or in a vehicle.\n");
	strcat(message, "/plock - Lock or unlock a garage (tenants only).\n");
	strcat(message, "/pentrance - Change the inside entrance to your position.\n");
	strcat(message, "/pinv - Inventar pruefen (nur Mieter).\n");
	strcat(message, "/ptitem(s) - Remove items; add S for as many as possible.\n");
	strcat(message, "/ppitem(s) - Place items; add S for as many as possible.\n");
	strcat(message, "/outfit - Open saved outfit menu (tenants only).\n");
	strcat(message, "/pmenu - Info, Inventar, Bau-Rechte.\n");
	strcat(message, "/pinfo - Show garage info (owner only).\n");
	strcat(message, "/setrentable - Make garage rentable; blank to stop.\n");
	strcat(message, "/rent - Rent a garage.\n");
	strcat(message, "/stoprent - Stop renting (use outside door).\n");
	strcat(message, "/tenants - Check tenants (owner only).\n");
	strcat(message, "/kicktenant - Remove a tenant (owner only).\n");
	strcat(message, "/evictall - Remove all tenants (owner only).\n");
	strcat(message, "/pdeposit - Deposit money (owner only).\n");
	strcat(message, "/pwithdrawl - Withdraw money (owner only).\n");
	strcat(message, "/sellproperty - Sell garage back to market (owner only).\n");
	strcat(message, "/playersellproperty - Sell garage to a player (owner only).\n");
	ShowPlayerDialog(playerid, DIALOG_GARAGE_HELP, DIALOG_STYLE_MSGBOX, "Garage Help", message, "Close", "");
	return 1;
}

stock ShowHelpDialog(playerid)
{
	new message[768];
	message[0] = EOS;
	strcat(message, "Quick commands:\n");
	strcat(message, "/login /register\n");
	strcat(message, "/inv - inventar\n");
	strcat(message, "/arbeit - job info am punkt\n");
	strcat(message, "/status - uebersicht\n");
	strcat(message, "/stats - beduerfnisse\n");
	strcat(message, "/phone - handy\n");
	strcat(message, "/map - map filter\n");
	strcat(message, "/gps - route zu POI\n");
	strcat(message, "/taxirent - rent a taxi\n");
	strcat(message, "/taxistart /fare /taximeter /taxidone\n");
	strcat(message, "/buycrates /deliverbiz - delivery work\n");
	strcat(message, "/dmv - registration & insurance\n");
	strcat(message, "/businesses - list businesses\n");
	strcat(message, "/garagehelp - garage info\n");
	strcat(message, "/todo - nearest activity\n");
	strcat(message, "/warehouse - warehouse checkpoint\n");
	strcat(message, "/enter /exit - property teleports\n");
	strcat(message, "\nNext step:\n");
	strcat(message, "Try /taxirent or visit the warehouse marker.");
	ShowPlayerDialog(playerid, DIALOG_HELP, DIALOG_STYLE_MSGBOX, "Help & Next Steps", message, "Close", "");
	return 1;
}

stock ShowTutorialDialog(playerid)
{
	new message[512];
	message[0] = EOS;
	strcat(message, "Welcome! Here's how to get started:\n\n");
	strcat(message, "1) Use /help for the command list.\n");
	strcat(message, "2) Use /taxirent to rent a taxi and /taxistart to go on duty.\n");
	strcat(message, "3) Use /buycrates at the warehouse and /deliverbiz to earn money.\n\n");
	strcat(message, "Use /todo anytime to see the nearest activity.");
	ShowPlayerDialog(playerid, DIALOG_TUTORIAL, DIALOG_STYLE_MSGBOX, "Getting Started", message, "Got it", "");
	return 1;
}

stock GiveStarterKit(playerid)
{
	AddPlayerItem(playerid, 0, 2);
	AddPlayerItem(playerid, 1, 1);
	AddPlayerItem(playerid, 4, 1);
	if (GetPlayerMoney(playerid) < STARTER_CASH)
	{
		GivePlayerMoney(playerid, STARTER_CASH - GetPlayerMoney(playerid));
	}
	PlayerData[playerid][pTutorialDone] = true;
	if (PlayerData[playerid][pAccountId] != INVALID_ACCOUNT_ID)
	{
		SavePlayerState(playerid);
	}
	return 1;
}

stock ShowNextStepHint(playerid)
{
	if (!PlayerData[playerid][pLogged])
	{
		SendClientMessage(playerid, -1, "Log in first with /login or /register.");
		return 1;
	}

	new Float:nearestDist = 999999.0;
	new nearestLabel[64];
	new Float:dist;

	format(nearestLabel, sizeof(nearestLabel), "component warehouse");
	dist = GetPlayerDistanceFromPoint(playerid, COMPONENT_WAREHOUSE_X, COMPONENT_WAREHOUSE_Y, COMPONENT_WAREHOUSE_Z);
	if (dist < nearestDist)
	{
		nearestDist = dist;
		format(nearestLabel, sizeof(nearestLabel), "component warehouse");
	}

	dist = GetPlayerDistanceFromPoint(playerid, GARAGE_X, GARAGE_Y, GARAGE_Z);
	if (dist < nearestDist)
	{
		nearestDist = dist;
		format(nearestLabel, sizeof(nearestLabel), "garage");
	}

	dist = GetPlayerDistanceFromPoint(playerid, CHOP_X, CHOP_Y, CHOP_Z);
	if (dist < nearestDist)
	{
		nearestDist = dist;
		format(nearestLabel, sizeof(nearestLabel), "chop shop");
	}

	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		dist = GetPlayerDistanceFromPoint(playerid, BusinessData[i][bX], BusinessData[i][bY], BusinessData[i][bZ]);
		if (dist < nearestDist)
		{
			nearestDist = dist;
			format(nearestLabel, sizeof(nearestLabel), "business %d (%s)", i + 1, gBusinessTypeNames[_:BusinessData[i][bType]]);
		}
	}

	new message[128];
	format(message, sizeof(message), "Nearest activity: %s (%.0fm).", nearestLabel, nearestDist);
	SendClientMessage(playerid, -1, message);
	SendClientMessage(playerid, -1, "Try /taxirent for taxi work or /buycrates at the warehouse.");
	return 1;
}

stock bool:IsPlayerAtGarage(playerid)
{
	return bool:(IsPlayerInRangeOfPoint(playerid, GARAGE_RADIUS, GARAGE_X, GARAGE_Y, GARAGE_Z));
}

stock bool:IsPlayerAtChopShop(playerid)
{
	return bool:(IsPlayerInRangeOfPoint(playerid, CHOP_RADIUS, CHOP_X, CHOP_Y, CHOP_Z));
}

stock bool:EnsureVehicleAccess(playerid)
{
	if (!IsPlayerInAnyVehicle(playerid))
	{
		SendClientMessage(playerid, -1, "You need to be in a vehicle.");
		return false;
	}
	new vehicleid = GetPlayerVehicleID(playerid);
	if (vehicleid != 0 && !CanAccessVehicleTrunk(playerid, vehicleid))
	{
		SendClientMessage(playerid, -1, "Fahrzeug ist abgeschlossen.");
		return false;
	}
	return true;
}

stock bool:EnsureGarageAccess(playerid)
{
	if (!IsPlayerAtGarage(playerid))
	{
		SendClientMessage(playerid, -1, "You need to be at a garage to use this.");
		return false;
	}
	return true;
}

stock bool:EnsureChopAccess(playerid)
{
	if (!IsPlayerAtChopShop(playerid))
	{
		SendClientMessage(playerid, -1, "You need to be at a chop shop to use this.");
		return false;
	}
	return true;
}

stock ToggleVehicleLock(vehicleid, bool:locked)
{
	new engine, lights, alarm, doors, bonnet, boot, objective;
	GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
	SetVehicleParamsEx(vehicleid, engine, lights, alarm, locked, bonnet, boot, objective);
	return 1;
}

stock bool:IsVehicleLocked(vehicleid)
{
	new engine, lights, alarm, doors, bonnet, boot, objective;
	GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
	return (doors != 0);
}

stock bool:HasVehicleKey(playerid, vehicleid)
{
	return (gVehicleOwner[vehicleid] == playerid);
}

stock bool:CanAccessVehicleTrunk(playerid, vehicleid)
{
	if (vehicleid == INVALID_VEHICLE_ID)
	{
		return false;
	}
	if (!IsVehicleLocked(vehicleid))
	{
		return true;
	}
	return HasVehicleKey(playerid, vehicleid);
}

stock GetVehicleTrunkCapacity(vehicleid)
{
	new model = GetVehicleModel(vehicleid);
	switch (model)
	{
		case 414, 422, 440, 456, 498, 609: return 200; // vans/trucks
		case 403, 514, 515: return 300; // big rigs
	}
	return VEHICLE_TRUNK_CAPACITY_KG;
}

stock GetVehicleInventoryWeight(vehicleid)
{
	new weight = 0;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (VehicleItems[vehicleid][i] < 1)
		{
			continue;
		}
		weight += gItems[i][itemWeightKg] * VehicleItems[vehicleid][i];
	}
	return weight;
}

stock bool:CanVehicleCarryItem(vehicleid, itemid, amount)
{
	if (!IsValidItem(itemid) || amount < 1)
	{
		return false;
	}
	new weightKg = gItems[itemid][itemWeightKg];
	if (weightKg < 1)
	{
		return false;
	}
	new total = GetVehicleInventoryWeight(vehicleid) + (weightKg * amount);
	return total <= GetVehicleTrunkCapacity(vehicleid);
}

stock SaveVehicleStorage(vehicleid)
{
	if (!gDatabaseReady || g_SQL == MYSQL_INVALID_HANDLE)
	{
		return 0;
	}
	new plate[MAX_PLATE_LEN];
	GetVehicleNumberPlate(vehicleid, plate, sizeof(plate));
	if (plate[0] == '\0')
	{
		return 0;
	}
	new query[512];
	new len = format(query, sizeof(query), "DELETE FROM `vehicle_storage` WHERE `plate`='%e';", plate);
	mysql_tquery(g_SQL, query);
	len = format(query, sizeof(query), "INSERT INTO `vehicle_storage` (`plate`,`item_id`,`amount`) VALUES ");
	new added = 0;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (VehicleItems[vehicleid][i] < 1)
		{
			continue;
		}
		len += format(query[len], sizeof(query) - len, "%s('%e',%d,%d)",
			added == 0 ? "" : ",", plate, i, VehicleItems[vehicleid][i]
		);
		added = 1;
	}
	if (added)
	{
		mysql_tquery(g_SQL, query);
	}
	return 1;
}

stock LoadVehicleStorage(vehicleid)
{
	if (!gDatabaseReady || g_SQL == MYSQL_INVALID_HANDLE)
	{
		return 0;
	}
	new plate[MAX_PLATE_LEN];
	GetVehicleNumberPlate(vehicleid, plate, sizeof(plate));
	if (plate[0] == '\0')
	{
		return 0;
	}
	new query[160];
	mysql_format(g_SQL, query, sizeof(query),
		"SELECT `item_id`,`amount` FROM `vehicle_storage` WHERE `plate`='%e'",
		plate
	);
	mysql_tquery(g_SQL, query, "OnVehicleStorageLoad", "i", vehicleid);
	return 1;
}

forward OnVehicleStorageLoad(vehicleid);
public OnVehicleStorageLoad(vehicleid)
{
	new rows;
	cache_get_row_count(rows);
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		VehicleItems[vehicleid][i] = 0;
	}
	for (new row = 0; row < rows; row++)
	{
		new itemid;
		new amount;
		cache_get_value_name_int(row, "item_id", itemid);
		cache_get_value_name_int(row, "amount", amount);
		if (itemid >= 0 && itemid < MAX_ITEMS && amount > 0)
		{
			VehicleItems[vehicleid][itemid] = amount;
		}
	}
	return 1;
}

stock Economy_Log(playerid, amount, const reason[])
{
	if (!gDatabaseReady || g_SQL == MYSQL_INVALID_HANDLE || PlayerData[playerid][pAccountId] == INVALID_ACCOUNT_ID)
	{
		return 0;
	}
	new query[256];
	mysql_format(g_SQL, query, sizeof(query),
		"INSERT INTO `economy_ledger` (`account_id`,`amount`,`reason`) VALUES (%d,%d,'%e')",
		PlayerData[playerid][pAccountId], amount, reason
	);
	mysql_tquery(g_SQL, query);
	return 1;
}

stock GivePlayerMoneyLogged(playerid, amount, const reason[])
{
	GivePlayerMoney(playerid, amount);
	Economy_Log(playerid, amount, reason);
	return 1;
}

stock Economy_Payout(playerid, amount, const reason[])
{
	new tax = floatround(float(amount) * ECON_INCOME_TAX_RATE, floatround_floor);
	new payout = amount - tax;
	if (tax > 0)
	{
		Economy_Log(playerid, -tax, "income_tax");
	}
	GivePlayerMoneyLogged(playerid, payout, reason);
	return payout;
}

stock Law_LogRecord(officerid, targetid, const event[], const detail[])
{
	if (!gDatabaseReady || g_SQL == MYSQL_INVALID_HANDLE)
	{
		return 0;
	}
	new query[256];
	mysql_format(g_SQL, query, sizeof(query),
		"INSERT INTO `law_records` (`officer_id`,`target_id`,`event`,`detail`) VALUES (%d,%d,'%e','%e')",
		officerid, targetid, event, detail
	);
	mysql_tquery(g_SQL, query);
	return 1;
}

#include "include/rp_jobs.inc"
#include "include/rp_factions.inc"
#include "include/rp_map.inc"

stock ShowStatusDialog(playerid)
{
	Activity_ResetIfNeeded(playerid);
	new money = GetPlayerMoney(playerid);
	new bestJob = 0;
	for (new i = 1; i < MAX_JOBS; i++)
	{
		if (gJobLevel[playerid][i] > gJobLevel[playerid][bestJob])
		{
			bestJob = i;
		}
	}
	new jobLevel = gJobLevel[playerid][bestJob];
	new factionName[32] = "Keine";
	new factionRank = 0;
	if (gFactionId[playerid] >= 0 && gFactionId[playerid] < MAX_FACTIONS)
	{
		format(factionName, sizeof(factionName), "%s", gFactions[gFactionId[playerid]][fName]);
		factionRank = gFactionRank[playerid];
	}
	new regStatus[16];
	new taxStatus[16];
	new insStatus[16];
	format(regStatus, sizeof(regStatus), "%s", PlayerData[playerid][pVehicleRegistered] ? "Ja" : "Nein");
	format(taxStatus, sizeof(taxStatus), "%s", PlayerData[playerid][pTaxesPaid] ? "Ja" : "Nein");
	format(insStatus, sizeof(insStatus), "%s", PlayerData[playerid][pInsured] ? "Ja" : "Nein");
	new activityCount = Activity_CountFlags(PlayerData[playerid][pActivityFlags]);
	new jobFlag[4];
	new taxiFlag[4];
	new deliveryFlag[4];
	new dmvFlag[4];
	format(jobFlag, sizeof(jobFlag), "%s", (PlayerData[playerid][pActivityFlags] & ACTIVITY_JOB) ? "Ja" : "Nein");
	format(taxiFlag, sizeof(taxiFlag), "%s", (PlayerData[playerid][pActivityFlags] & ACTIVITY_TAXI) ? "Ja" : "Nein");
	format(deliveryFlag, sizeof(deliveryFlag), "%s", (PlayerData[playerid][pActivityFlags] & ACTIVITY_DELIVERY) ? "Ja" : "Nein");
	format(dmvFlag, sizeof(dmvFlag), "%s", (PlayerData[playerid][pActivityFlags] & ACTIVITY_DMV) ? "Ja" : "Nein");
	new message[256];
	format(message, sizeof(message),
		"Geld: $%d\nJob: %s L%d\nFraktion: %s (Rang %d)\nDMV: Registriert %s | Steuer %s | Versichert %s\nInventar: %d/%dkg\nVielfalt: %d/3\nAktivitaeten: Job %s | Taxi %s | Lieferung %s | DMV %s\nNaechster Schritt: /gps",
		money,
		gJobs[bestJob][jobName],
		jobLevel,
		factionName,
		factionRank,
		regStatus,
		taxStatus,
		insStatus,
		GetPlayerInventoryWeight(playerid),
		PlayerData[playerid][pCarryLimit],
		activityCount,
		jobFlag,
		taxiFlag,
		deliveryFlag,
		dmvFlag
	);
	ShowPlayerDialog(playerid, DIALOG_STATUS, DIALOG_STYLE_MSGBOX, "Status", message, "OK", "");
	return 1;
}

stock SetupPreviewCamera(playerid)
{
	SetPlayerInterior(playerid, 0);
	SetPlayerVirtualWorld(playerid, 0);
	SetPlayerPos(playerid, PREVIEW_X, PREVIEW_Y, PREVIEW_Z);
	SetPlayerFacingAngle(playerid, PREVIEW_A);
	SetPlayerCameraPos(playerid, PREVIEW_X + 4.0, PREVIEW_Y, PREVIEW_Z + 1.0);
	SetPlayerCameraLookAt(playerid, PREVIEW_X, PREVIEW_Y, PREVIEW_Z + 1.0);
	return 1;
}

stock SetupCinemaInterior()
{
	if (gCinemaScreenObject != INVALID_OBJECT_ID)
	{
		DestroyObject(gCinemaScreenObject);
		gCinemaScreenObject = INVALID_OBJECT_ID;
	}

	for (new i = 0; i < sizeof(gCinemaSeatObjects); i++)
	{
		if (gCinemaSeatObjects[i] != INVALID_OBJECT_ID)
		{
			DestroyObject(gCinemaSeatObjects[i]);
			gCinemaSeatObjects[i] = INVALID_OBJECT_ID;
		}
	}

	gCinemaScreenObject = CreateObject(CINEMA_SCREEN_MODEL, 1115.0, -1456.0, 17.0, 0.0, 0.0, 180.0);

	for (new i = 0; i < sizeof(gCinemaSeats); i++)
	{
		gCinemaSeatObjects[i] = CreateObject(
			gCinemaSeats[i][seatModel],
			gCinemaSeats[i][seatX],
			gCinemaSeats[i][seatY],
			gCinemaSeats[i][seatZ],
			0.0,
			0.0,
			gCinemaSeats[i][seatA]
		);
	}

	return 1;
}

stock CleanupCinemaInterior()
{
	if (gCinemaScreenObject != INVALID_OBJECT_ID)
	{
		DestroyObject(gCinemaScreenObject);
		gCinemaScreenObject = INVALID_OBJECT_ID;
	}

	for (new i = 0; i < sizeof(gCinemaSeatObjects); i++)
	{
		if (gCinemaSeatObjects[i] != INVALID_OBJECT_ID)
		{
			DestroyObject(gCinemaSeatObjects[i]);
			gCinemaSeatObjects[i] = INVALID_OBJECT_ID;
		}
	}
	return 1;
}

stock InitCinemaObjects()
{
	gCinemaScreenObject = INVALID_OBJECT_ID;
	for (new i = 0; i < sizeof(gCinemaSeatObjects); i++)
	{
		gCinemaSeatObjects[i] = INVALID_OBJECT_ID;
	}
	return 1;
}

stock StartCinemaBroadcast(const video[])
{
	format(gCinemaVideo, sizeof(gCinemaVideo), "%s", video);
	gCinemaActive = true;
	gCinemaStartTick = GetTickCount();

	new message[144];
	format(message, sizeof(message), "Cinema broadcast started: %s", gCinemaVideo);
	SendClientMessageToAll(0x1E90FFFF, message);
	return 1;
}

stock StopCinemaBroadcast()
{
	gCinemaActive = false;
	gCinemaVideo[0] = '\0';
	gCinemaStartTick = 0;

	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		gCinemaWatching[i] = false;
	}

	SendClientMessageToAll(0x1E90FFFF, "Cinema broadcast stopped.");
	return 1;
}

stock bool:IsPlayerAtCinema(playerid)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid, x, y, z);

	new Float:dx = x - CINEMA_POINT_X;
	new Float:dy = y - CINEMA_POINT_Y;
	return (dx * dx + dy * dy) <= (CINEMA_RADIUS * CINEMA_RADIUS);
}

stock ShowCinemaStatus(playerid)
{
	if (!gCinemaActive)
	{
		SendClientMessage(playerid, -1, "There is no active cinema broadcast right now.");
		return 1;
	}

	new elapsed = (GetTickCount() - gCinemaStartTick) / 1000;
	new message[160];
	format(message, sizeof(message), "Now watching: %s (at %d seconds).", gCinemaVideo, elapsed);
	SendClientMessage(playerid, 0x1E90FFFF, message);
	return 1;
}

stock ShowDmvDialog(playerid)
{
	new body[256];
	format(body, sizeof(body),
		"Vehicle registration: %s\nRoad taxes: %s\nInsurance: %s\n\nSelect an option:",
		PlayerData[playerid][pVehicleRegistered] ? ("Registered") : ("Not registered"),
		PlayerData[playerid][pTaxesPaid] ? ("Paid") : ("Unpaid"),
		PlayerData[playerid][pInsured] ? ("Insured") : ("Uninsured")
	);
	ShowPlayerDialog(playerid, DIALOG_DMV, DIALOG_STYLE_LIST, "Department of Motor Vehicles", body,
		"Select", "Close");
	return 1;
}

stock ShowDmvPaymentDialog(playerid, const actionLabel[], cost)
{
	new body[128];
	format(body, sizeof(body), "%s\nCost: $%d\n\nProceed with payment?", actionLabel, cost);
	ShowPlayerDialog(playerid, DIALOG_DMV_PAY, DIALOG_STYLE_MSGBOX, "DMV Payment", body,
		"Pay", "Back");
	return 1;
}

stock SavePlayerDmvStatus(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));

	new query[256];
	if (PlayerData[playerid][pAccountId] != INVALID_ACCOUNT_ID)
	{
		mysql_format(g_SQL, query, sizeof(query),
			"UPDATE `accounts` SET `vehicle_registered`=%d, `taxes_paid`=%d, `insured`=%d WHERE `id`=%d LIMIT 1",
			PlayerData[playerid][pVehicleRegistered],
			PlayerData[playerid][pTaxesPaid],
			PlayerData[playerid][pInsured],
			PlayerData[playerid][pAccountId]
		);
	}
	else
	{
		mysql_format(g_SQL, query, sizeof(query),
			"UPDATE `accounts` SET `vehicle_registered`=%d, `taxes_paid`=%d, `insured`=%d WHERE `name`='%e' LIMIT 1",
			PlayerData[playerid][pVehicleRegistered],
			PlayerData[playerid][pTaxesPaid],
			PlayerData[playerid][pInsured],
			name
		);
	}
	mysql_tquery(g_SQL, query);
	return 1;
}

stock ChargePlayer(playerid, amount)
{
	if (GetPlayerMoney(playerid) < amount)
	{
		SendClientMessage(playerid, -1, "You don't have enough cash for this payment.");
		return 0;
	}
	GivePlayerMoney(playerid, -amount);
	return 1;
}

stock GetRegistrationCost()
{
	return floatround(DMV_VEHICLE_VALUE * DMV_REGISTRATION_RATE);
}

stock GetTaxCost()
{
	return floatround(DMV_VEHICLE_VALUE * DMV_TAX_RATE);
}

stock GetInsuranceCost()
{
	return floatround(DMV_VEHICLE_VALUE * DMV_INSURANCE_RATE);
}

stock HandleDmvBilling(playerid)
{
	if (!PlayerData[playerid][pLogged])
	{
		return 1;
	}

	if (PlayerData[playerid][pInsured])
	{
		new insuranceFee = floatround(DMV_VEHICLE_VALUE * 0.01);
		if (!ChargePlayer(playerid, insuranceFee))
		{
			PlayerData[playerid][pInsured] = false;
			SendClientMessage(playerid, -1, "Insurance payment failed; your insurance lapsed.");
		}
	}

	if (PlayerData[playerid][pTaxesPaid])
	{
		new taxBill = GetTaxCost();
		if (!ChargePlayer(playerid, taxBill))
		{
			PlayerData[playerid][pTaxesPaid] = false;
			SendClientMessage(playerid, -1, "Road taxes unpaid; your vehicle is now flagged.");
		}
	}

	SavePlayerDmvStatus(playerid);
	PlayerData[playerid][pNextBilling] = SetTimerEx("OnDmvBilling", DMV_BILLING_INTERVAL, false, "i", playerid);
	return 1;
}

forward OnDmvBilling(playerid);

public OnDmvBilling(playerid)
{
	return HandleDmvBilling(playerid);
}

stock RegisterPlayer(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));

	new query[512];
	mysql_format(g_SQL, query, sizeof(query),
		"INSERT INTO `accounts` (`name`,`password`,`version`,`created_at`,`last_login`,`money`,`skin`,`x`,`y`,`z`,`a`,`interior`,`world`,`vehicle_registered`,`taxes_paid`,`insured`,`addiction`,`hunger`,`thirst`,`fatigue`,`carry_limit`,`tutorial_done`) VALUES ('%e','%e',%d,NOW(),NOW(),%d,%d,%.4f,%.4f,%.4f,%.4f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)",
		name,
		PlayerData[playerid][pPassHash],
		ACCOUNT_VERSION,
		STARTER_CASH,
		PlayerData[playerid][pSkin],
		PREVIEW_X, PREVIEW_Y, PREVIEW_Z, PREVIEW_A,
		0, 0,
		PlayerData[playerid][pVehicleRegistered],
		PlayerData[playerid][pTaxesPaid],
		PlayerData[playerid][pInsured],
		PlayerData[playerid][pAddiction],
		PlayerData[playerid][pHunger],
		PlayerData[playerid][pThirst],
		PlayerData[playerid][pFatigue],
		PlayerData[playerid][pCarryLimit],
		0
	);
	mysql_tquery(g_SQL, query, "OnAccountCreated", "i", playerid);
	LogAuthEvent(playerid, "register_insert");
	return 1;
}

stock SavePlayerPosition(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));

	new Float:x, Float:y, Float:z, Float:a;
	GetPlayerPos(playerid, x, y, z);
	GetPlayerFacingAngle(playerid, a);

	new interior = GetPlayerInterior(playerid);
	new world = GetPlayerVirtualWorld(playerid);
	new skin = GetPlayerSkin(playerid);
	new money = GetPlayerMoney(playerid);
	PlayerData[playerid][pMoney] = money;

	new query[512];
	if (PlayerData[playerid][pAccountId] != INVALID_ACCOUNT_ID)
	{
		mysql_format(g_SQL, query, sizeof(query),
			"UPDATE `accounts` SET `skin`=%d, `x`=%.4f, `y`=%.4f, `z`=%.4f, `a`=%.4f, `interior`=%d, `world`=%d, `vehicle_registered`=%d, `taxes_paid`=%d, `insured`=%d, `addiction`=%d, `hunger`=%d, `thirst`=%d, `fatigue`=%d, `money`=%d, `carry_limit`=%d, `tutorial_done`=%d WHERE `id`=%d LIMIT 1",
			skin, x, y, z, a, interior, world,
			PlayerData[playerid][pVehicleRegistered],
			PlayerData[playerid][pTaxesPaid],
			PlayerData[playerid][pInsured],
			PlayerData[playerid][pAddiction],
			PlayerData[playerid][pHunger],
			PlayerData[playerid][pThirst],
			PlayerData[playerid][pFatigue],
			money,
			PlayerData[playerid][pCarryLimit],
			PlayerData[playerid][pTutorialDone],
			PlayerData[playerid][pAccountId]
		);
	}
	else
	{
		mysql_format(g_SQL, query, sizeof(query),
			"UPDATE `accounts` SET `skin`=%d, `x`=%.4f, `y`=%.4f, `z`=%.4f, `a`=%.4f, `interior`=%d, `world`=%d, `vehicle_registered`=%d, `taxes_paid`=%d, `insured`=%d, `addiction`=%d, `hunger`=%d, `thirst`=%d, `fatigue`=%d, `money`=%d, `carry_limit`=%d, `tutorial_done`=%d WHERE `name`='%e' LIMIT 1",
			skin, x, y, z, a, interior, world,
			PlayerData[playerid][pVehicleRegistered],
			PlayerData[playerid][pTaxesPaid],
			PlayerData[playerid][pInsured],
			PlayerData[playerid][pAddiction],
			PlayerData[playerid][pHunger],
			PlayerData[playerid][pThirst],
			PlayerData[playerid][pFatigue],
			money,
			PlayerData[playerid][pCarryLimit],
			PlayerData[playerid][pTutorialDone],
			name
		);
	}
	mysql_tquery(g_SQL, query);
	LogAuthEvent(playerid, "save_position");
	return 1;
}

stock UpdateLastLogin(playerid)
{
	if (PlayerData[playerid][pAccountId] == INVALID_ACCOUNT_ID)
	{
		return 0;
	}
	new query[128];
	mysql_format(g_SQL, query, sizeof(query),
		"UPDATE `accounts` SET `last_login`=NOW() WHERE `id`=%d LIMIT 1",
		PlayerData[playerid][pAccountId]
	);
	mysql_tquery(g_SQL, query);
	LogAuthEvent(playerid, "last_login_update");
	return 1;
}

stock SavePlayerInventory(playerid)
{
	if (PlayerData[playerid][pAccountId] == INVALID_ACCOUNT_ID)
	{
		return 0;
	}

	new query[512];
	mysql_format(g_SQL, query, sizeof(query),
		"DELETE FROM `inventory` WHERE `account_id`=%d",
		PlayerData[playerid][pAccountId]
	);
	mysql_tquery(g_SQL, query);

	new insert[512];
	insert[0] = EOS;
	new added = 0;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (PlayerItems[playerid][i] < 1)
		{
			continue;
		}
		new line[64];
		format(line, sizeof(line), "%s(%d,%d,%d)",
			added == 0 ? "INSERT INTO `inventory` (`account_id`,`item_id`,`amount`) VALUES " : ",",
			PlayerData[playerid][pAccountId],
			i,
			PlayerItems[playerid][i]
		);
		strcat(insert, line);
		added++;
	}
	if (added > 0)
	{
		mysql_tquery(g_SQL, insert);
	}
	LogAuthEvent(playerid, "save_inventory");
	return 1;
}

stock LoadPlayerInventory(playerid)
{
	if (PlayerData[playerid][pAccountId] == INVALID_ACCOUNT_ID)
	{
		return 0;
	}
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		PlayerItems[playerid][i] = 0;
	}
	new query[128];
	mysql_format(g_SQL, query, sizeof(query),
		"SELECT `item_id`,`amount` FROM `inventory` WHERE `account_id`=%d",
		PlayerData[playerid][pAccountId]
	);
	mysql_tquery(g_SQL, query, "OnInventoryLoad", "i", playerid);
	LogAuthEvent(playerid, "load_inventory");
	return 1;
}

stock SavePlayerState(playerid)
{
	if (!PlayerData[playerid][pLogged])
	{
		return 0;
	}
	SavePlayerPosition(playerid);
	SavePlayerInventory(playerid);
	Job_SavePlayer(playerid);
	Faction_SavePlayer(playerid);
	SavePlayerDmvStatus(playerid);
	return 1;
}

stock TeleportPlayerToPoint(playerid, const point[eTeleportPoint])
{
	SetPlayerInterior(playerid, point[tInterior]);
	SetPlayerVirtualWorld(playerid, point[tWorld]);
	SetPlayerPos(playerid, point[tX], point[tY], point[tZ]);
	SetPlayerFacingAngle(playerid, point[tA]);
	return 1;
}

stock TryPropertyTeleport(playerid, index, bool:fromEntry)
{
	if (GetTickCount() - PlayerData[playerid][pLastTeleportTick] < TELEPORT_COOLDOWN_MS)
	{
		return 0;
	}

	if (!PlayerData[playerid][pLogged])
	{
		return 0;
	}

	if (index < 0 || index >= sizeof(gTeleports))
	{
		return 0;
	}

	if (fromEntry)
	{
		PlayerData[playerid][pLastTeleportTick] = GetTickCount();
		TeleportPlayerToPoint(playerid, gTeleports[index][tExit]);
		SendClientMessage(playerid, -1, "You use the property teleport.");
		return 1;
	}

	PlayerData[playerid][pLastTeleportTick] = GetTickCount();
	TeleportPlayerToPoint(playerid, gTeleports[index][tEntry]);
	SendClientMessage(playerid, -1, "You use the property teleport.");
	return 1;
}

stock CreatePropertyTeleports()
{
	for (new i = 0; i < sizeof(gTeleports); i++)
	{
		gTeleportLabels[i][tEntry] = _:Create3DTextLabel(
			"Property Entrance\nUse /enter.",
			0xFFFFFFFF,
			gTeleports[i][tEntry][tX],
			gTeleports[i][tEntry][tY],
			gTeleports[i][tEntry][tZ] + 0.8,
			TELEPORT_LABEL_DISTANCE,
			0,
			gTeleports[i][tEntry][tWorld]
		);
		gTeleportLabels[i][tExit] = _:Create3DTextLabel(
			"Property Exit\nUse /exit.",
			0xFFFFFFFF,
			gTeleports[i][tExit][tX],
			gTeleports[i][tExit][tY],
			gTeleports[i][tExit][tZ] + 0.8,
			TELEPORT_LABEL_DISTANCE,
			0,
			gTeleports[i][tExit][tWorld]
		);
	}
	return 1;
}

stock DestroyPropertyTeleports()
{
	for (new i = 0; i < sizeof(gTeleports); i++)
	{
		if (Text3D:gTeleportLabels[i][tEntry] != Text3D:0)
		{
			Delete3DTextLabel(Text3D:gTeleportLabels[i][tEntry]);
			gTeleportLabels[i][tEntry] = 0;
		}
		if (Text3D:gTeleportLabels[i][tExit] != Text3D:0)
		{
			Delete3DTextLabel(Text3D:gTeleportLabels[i][tExit]);
			gTeleportLabels[i][tExit] = 0;
		}
	}
	return 1;
}

stock bool:IsPlayerNearTeleport(playerid, index, bool:entry)
{
	new interior = GetPlayerInterior(playerid);
	new world = GetPlayerVirtualWorld(playerid);

	if (entry)
	{
		if (interior != gTeleports[index][tEntry][tInterior] || world != gTeleports[index][tEntry][tWorld])
		{
			return false;
		}
		return bool:(IsPlayerInRangeOfPoint(playerid, TELEPORT_RADIUS,
			gTeleports[index][tEntry][tX],
			gTeleports[index][tEntry][tY],
			gTeleports[index][tEntry][tZ]));
	}

	if (interior != gTeleports[index][tExit][tInterior] || world != gTeleports[index][tExit][tWorld])
	{
		return false;
	}
	return bool:(IsPlayerInRangeOfPoint(playerid, TELEPORT_RADIUS,
		gTeleports[index][tExit][tX],
		gTeleports[index][tExit][tY],
		gTeleports[index][tExit][tZ]));
}

main()
{
	print("Account system loaded.");
}

public OnGameModeInit()
{
	SetGameModeText("MySQL Accounts");
	UsePlayerPedAnims();
	DisableInteriorEnterExits();
	gStolenPlateCount = 0;
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		gStorePrices[i] = STORE_PRICE_NONE;
	}
	gStorePrices[ITEM_WATER] = 25;
	gStorePrices[ITEM_SANDWICH] = 35;
	gStorePrices[ITEM_BANDAGE] = 75;
	gStorePrices[ITEM_MEDKIT] = 150;
	gStorePrices[ITEM_PHONE] = 500;
	gStorePrices[ITEM_FLASHLIGHT] = 120;
	gStorePrices[ITEM_REPAIR_KIT] = 220;
	gStorePrices[ITEM_NOTEBOOK] = 40;
	gStorePrices[ITEM_ROPE] = 120;
	gStorePrices[ITEM_FISHING_ROD] = 250;
	gStorePrices[ITEM_FUEL_CAN] = 300;
	for (new i = 0; i < MAX_VEHICLES; i++)
	{
		gVehicleOwner[i] = INVALID_PLAYER_ID;
	}
	SetTimer("TaxiRentalTick", 60000, true);
	SetTimer("TaxiMeterTick", 1000, true);
	SetTimer("OnAddictionTick", DRUG_EFFECT_INTERVAL, true);
	SetTimer("NeedsTick", 60000, true);
	SetTimer("EconomyTick", ECON_TICK_MS, true);
	SetTimer("FactionSalaryTick", FACTION_SALARY_TICK_MS, true);
	SetTimer("CrimeTick", 60000, true);
	SetTimer("AutoSaveTick", AUTO_SAVE_INTERVAL_MS, true);
	for (new i = 0; i < MAX_DROPS; i++)
	{
		Drops[i][dropActive] = false;
		Drops[i][dropPickupId] = -1;
	}

	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		BusinessData[i][bOwner] = INVALID_PLAYER_ID;
		BusinessData[i][bComponents] = BUSINESS_COMPONENTS_DEFAULT;
		BusinessData[i][bComponentPrice] = 750;
		BusinessData[i][bEarnings] = 0;
		UpdateBusinessLabel(i);
	}

	WarehouseLabel = Create3DTextLabel("Warenlager\nTippe /buycrates", 0x67B7FFFF, COMPONENT_WAREHOUSE_X, COMPONENT_WAREHOUSE_Y, COMPONENT_WAREHOUSE_Z + 0.7, 15.0, 0, 0);
	CreatePropertyTeleports();
	FishingVendorLabel = Create3DTextLabel("Angel-Verkauf\nTippe /buyrod", 0x67B7FFFF, FISH_VENDOR_X, FISH_VENDOR_Y, FISH_VENDOR_Z + 0.7, 15.0, 0, 0);

	for (new i = 0; i < sizeof(gSkinList); i++)
	{
		AddPlayerClass(gSkinList[i], PREVIEW_X, PREVIEW_Y, PREVIEW_Z, PREVIEW_A, 0, 0, 0, 0, 0, 0);
	}

	GarageLabel = Create3DTextLabel("Garage\nTippe /garage", 0x67B7FFFF, GARAGE_X, GARAGE_Y, GARAGE_Z + 0.7, 15.0, 0, 0);
	ChopLabel = Create3DTextLabel("Chop-Shop\nTippe /chop", 0x67B7FFFF, CHOP_X, CHOP_Y, CHOP_Z + 0.7, 15.0, 0, 0);

	new vehicleid = CreateVehicle(411, PREVIEW_X + 6.0, PREVIEW_Y + 4.0, PREVIEW_Z, 0.0, 0, 0, -1);
	InitVehiclePlate(vehicleid);
	LoadVehicleStorage(vehicleid);
	SetVehicleParamsEx(vehicleid, 0, 0, 0, 1, 0, 0, 0);
	gVehicleLockLevel[vehicleid] = 3;
	gVehicleAlarmLevel[vehicleid] = 2;
	gVehicleMarketPrice[vehicleid] = 120000;
	gVehicleManufacturer[vehicleid] = 2;

	vehicleid = CreateVehicle(560, PREVIEW_X + 8.0, PREVIEW_Y - 3.0, PREVIEW_Z, 180.0, 0, 0, -1);
	InitVehiclePlate(vehicleid);
	LoadVehicleStorage(vehicleid);
	SetVehicleParamsEx(vehicleid, 0, 0, 0, 1, 0, 0, 0);
	gVehicleLockLevel[vehicleid] = 2;
	gVehicleAlarmLevel[vehicleid] = 1;
	gVehicleMarketPrice[vehicleid] = 60000;
	gVehicleManufacturer[vehicleid] = 1;

	vehicleid = CreateVehicle(489, PREVIEW_X + 12.0, PREVIEW_Y + 6.0, PREVIEW_Z, 90.0, 0, 0, -1);
	InitVehiclePlate(vehicleid);
	LoadVehicleStorage(vehicleid);
	SetVehicleParamsEx(vehicleid, 0, 0, 0, 1, 0, 0, 0);
	gVehicleLockLevel[vehicleid] = 4;
	gVehicleAlarmLevel[vehicleid] = 3;
	gVehicleMarketPrice[vehicleid] = 90000;
	gVehicleManufacturer[vehicleid] = 3;

	new MySQLOpt:options = mysql_init_options();
	mysql_set_option(options, SERVER_PORT, MYSQL_PORT);
	g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB, options);
	if (g_SQL == MYSQL_INVALID_HANDLE)
	{
		print("[MySQL] Connection failed (invalid handle).");
		gDatabaseReady = false;
	}
	else if (mysql_errno(g_SQL) != 0)
	{
		new errMsg[128];
		mysql_error(errMsg, sizeof(errMsg), g_SQL);
		printf("[MySQL] Connection failed (errno=%d msg=%s).", mysql_errno(g_SQL), errMsg);
		gDatabaseReady = false;
	}
	else
	{
		print("[MySQL] Connection successful.");
		gDatabaseReady = EnsureDatabaseSchema();
		if (gDatabaseReady)
		{
			LoadStolenPlates();
		}
		else
		{
			print("[MySQL] Schema initialization failed.");
		}
	}

	InitCinemaObjects();
	SetupCinemaInterior();
	Job_Init();
	Faction_Init();
	Map_Init();
	return 1;
}

public OnGameModeExit()
{
	DestroyPropertyTeleports();
	if (g_SQL != MYSQL_INVALID_HANDLE)
	{
		mysql_close(g_SQL);
	}
	if (WarehouseLabel != Text3D:0)
	{
		Delete3DTextLabel(WarehouseLabel);
		WarehouseLabel = Text3D:0;
	}
	if (FishingVendorLabel != Text3D:0)
	{
		Delete3DTextLabel(FishingVendorLabel);
		FishingVendorLabel = Text3D:0;
	}
	if (GarageLabel != Text3D:0)
	{
		Delete3DTextLabel(GarageLabel);
		GarageLabel = Text3D:0;
	}
	if (ChopLabel != Text3D:0)
	{
		Delete3DTextLabel(ChopLabel);
		ChopLabel = Text3D:0;
	}
	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		if (BusinessLabels[i] != Text3D:0)
		{
			Delete3DTextLabel(BusinessLabels[i]);
		}
	}
	CleanupCinemaInterior();
	Job_Shutdown();
	Faction_SaveStorage();
	for (new i = 1; i < MAX_VEHICLES; i++)
	{
		if (GetVehicleModel(i) != 0)
		{
			SaveVehicleStorage(i);
		}
	}
	return 1;
}

public OnPlayerConnect(playerid)
{
	ResetPlayerData(playerid);
	TogglePlayerSpectating(playerid, true);
	LogAuthEvent(playerid, "connect");

	if (!gDatabaseReady || g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
	{
		new detail[64];
		format(detail, sizeof(detail), "db_offline errno=%d", mysql_errno(g_SQL));
		LogAuthEvent(playerid, "connect_fail", detail);
		SendClientMessage(playerid, -1, "Database offline. Try again later.");
		Kick(playerid);
		return 1;
	}
	PlayerData[playerid][pAuthRetries] = 0;
	StartAccountCheck(playerid);
	SetTimerEx("AuthTimeoutCheck", 5000, false, "i", playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	new detail[64];
	format(detail, sizeof(detail), "reason=%d logged=%d", reason, PlayerData[playerid][pLogged]);
	LogAuthEvent(playerid, "disconnect", detail);
	CancelMiniGame(playerid);
	DestroyPet(playerid);
	StopStationForPlayer(playerid);
	gCinemaWatching[playerid] = false;
	if (gTaxiRequesting[playerid])
	{
		TaxiResetRequestForCustomer(playerid);
	}
	if (TaxiCustomerForDriver[playerid] != INVALID_PLAYER_ID)
	{
		TaxiResetRequestForDriver(playerid);
	}
	if (TaxiRentalVehicle[playerid] != INVALID_VEHICLE_ID)
	{
		DestroyVehicle(TaxiRentalVehicle[playerid]);
		TaxiRentalVehicle[playerid] = INVALID_VEHICLE_ID;
	}
	ReleasePlayerBusinesses(playerid);
	ClearDeliveryCheckpoint(playerid);
	if (PlayerData[playerid][pLogged])
	{
		SavePlayerState(playerid);
	}
	if (PlayerData[playerid][pNextBilling] != 0)
	{
		KillTimer(PlayerData[playerid][pNextBilling]);
		PlayerData[playerid][pNextBilling] = 0;
	}
	ResetPlayerData(playerid);
	return 1;
}

public OnPlayerSpawn(playerid)
{
	if (PlayerData[playerid][pLogged] && !PlayerData[playerid][pTutorialDone])
	{
		GiveStarterKit(playerid);
		ShowTutorialDialog(playerid);
		SendClientMessage(playerid, -1, "Nutze /inv (oder /inventory) fuer dein Inventar. Druecke Y zum Aufheben.");
		SendClientMessage(playerid, -1, "Use /help or /todo if you're unsure what to do next.");
	}
	if (PlayerData[playerid][pLogged])
	{
		Map_RebuildForPlayer(playerid);
	}
	if (PlayerData[playerid][pAddiction] >= 50)
	{
		SetPlayerHealth(playerid, 50.0);
	}
	if (PlayerData[playerid][pLogged])
	{
		if (PlayerData[playerid][pNextBilling] != 0)
		{
			KillTimer(PlayerData[playerid][pNextBilling]);
		}
		PlayerData[playerid][pNextBilling] = SetTimerEx("OnDmvBilling", DMV_BILLING_INTERVAL, false, "i", playerid);
	}
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if (PlayerData[playerid][pMiniGame] != MINIGAME_NONE)
	{
		if ((newkeys & KEY_ACTION) && !(oldkeys & KEY_ACTION))
		{
			ShowMiniGameHelp(playerid);
			return 1;
		}

		for (new i = 0; i < sizeof(gMiniKeys); i++)
		{
			if ((newkeys & gMiniKeys[i]) && !(oldkeys & gMiniKeys[i]))
			{
				new expectedIndex = PlayerData[playerid][pMiniKeySequence][PlayerData[playerid][pMiniStep]];
				if (i == expectedIndex)
				{
					PlayerData[playerid][pMiniStep]++;
					if (PlayerData[playerid][pMiniStep] >= MINIGAME_KEYS)
					{
						CompleteMiniGame(playerid);
						return 1;
					}

					ShowMiniGamePrompt(playerid);
				}
				else
				{
					FailMiniGame(playerid, "Wrong key pressed. The attempt failed.");
				}
				return 1;
			}
		}
		return 1;
	}

	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES))
	{
		if (Constructor_OnKeyAction(playerid))
		{
			return 1;
		}
		new dropid = GetNearestActiveDrop(playerid);
		if (dropid != -1)
		{
			if (!CanPlayerCarryItem(playerid, Drops[dropid][dropItemId], Drops[dropid][dropAmount]))
			{
				ShowInventoryFullMessage(playerid, Drops[dropid][dropItemId], Drops[dropid][dropAmount]);
				return 1;
			}
			new itemName[MAX_ITEM_NAME];
			GetItemName(Drops[dropid][dropItemId], itemName, sizeof(itemName));
			AddPlayerItem(playerid, Drops[dropid][dropItemId], Drops[dropid][dropAmount]);
			new message[96];
			format(message, sizeof(message), "Du hast %s x%d aufgehoben.", itemName, Drops[dropid][dropAmount]);
			SendClientMessage(playerid, -1, message);
			ClearDrop(dropid);
			return 1;
		}

		if (PlayerData[playerid][pLogged])
		{
			new businessId = GetNearestBusiness(playerid);
			if (businessId != -1)
			{
				if (BusinessData[businessId][bOwner] == playerid)
				{
					ShowBusinessStatus(playerid, businessId);
					SendClientMessage(playerid, -1, "Use /setcomponentprice [amount] or /sellbiz to manage this business.");
				}
				else if (BusinessData[businessId][bOwner] == INVALID_PLAYER_ID)
				{
					new message[96];
					format(message, sizeof(message), "This business is for sale: $%d. Use /buybiz to purchase it.", BusinessData[businessId][bPrice]);
					SendClientMessage(playerid, -1, message);
				}
				else
				{
					ShowBusinessStatus(playerid, businessId);
				}
				return 1;
			}
		}

		if (IsPlayerAtCinema(playerid))
		{
			if (!gCinemaActive)
			{
				SendClientMessage(playerid, -1, "The cinema is not playing anything right now.");
				return 1;
			}

			gCinemaWatching[playerid] = true;
			ShowCinemaStatus(playerid);
			return 1;
		}
	}
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	if (!PlayerData[playerid][pRegistering])
	{
		return 1;
	}

	if (classid >= 0 && classid < sizeof(gSkinList))
	{
		PlayerData[playerid][pSkin] = gSkinList[classid];
	}

	SetupPreviewCamera(playerid);
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	if (PlayerData[playerid][pRegistering])
	{
		PlayerData[playerid][pRegistering] = false;
		PlayerData[playerid][pLogged] = true;
		LogAuthEvent(playerid, "register_spawn");
		RegisterPlayer(playerid);
	}
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if (dialogid == DIALOG_GARAGE_HELP)
	{
		return 1;
	}

	if (Job_OnDialogResponse(playerid, dialogid, response, listitem, inputtext))
	{
		return 1;
	}
	if (Faction_OnDialogResponse(playerid, dialogid, response, listitem, inputtext))
	{
		return 1;
	}
	if (Map_OnDialogResponse(playerid, dialogid, response, listitem, inputtext))
	{
		return 1;
	}

	if (dialogid == DIALOG_LOGIN)
	{
		if (!response)
		{
			ShowPlayerDialog(
				playerid,
				DIALOG_LOGIN_CANCEL,
				DIALOG_STYLE_MSGBOX,
				"Quit Login?",
				"Do you want to quit?\n\nUse /login to reopen the login screen.",
				"Quit",
				"Back"
			);
			return 1;
		}

		if (strlen(inputtext) < 1)
		{
			ShowLoginDialog(playerid, "Password is required:\n\nEnter your password:");
			return 1;
		}

		new name[MAX_PLAYER_NAME];
		GetPlayerName(playerid, name, sizeof(name));

		new hash[PASSWORD_LEN + 1];
		SHA256_PassHash(inputtext, name, hash, sizeof(hash));

		if (!strcmp(hash, PlayerData[playerid][pPassHash], false))
		{
			PlayerData[playerid][pLoginAttempts] = 0;
			PlayerData[playerid][pLogged] = true;
			LogAuthEvent(playerid, "login_success");
			TogglePlayerSpectating(playerid, false);

			ResetPlayerMoney(playerid);
			if (PlayerData[playerid][pMoney] > 0)
			{
				GivePlayerMoney(playerid, PlayerData[playerid][pMoney]);
			}
			UpdateLastLogin(playerid);

			SetPlayerInterior(playerid, PlayerData[playerid][pInterior]);
			SetPlayerVirtualWorld(playerid, PlayerData[playerid][pWorld]);
			SetSpawnInfo(playerid, 0, PlayerData[playerid][pSkin],
				PlayerData[playerid][pX], PlayerData[playerid][pY], PlayerData[playerid][pZ],
				PlayerData[playerid][pA], 0, 0, 0, 0, 0, 0);
			SpawnPlayer(playerid);
		}
		else
		{
			PlayerData[playerid][pLoginAttempts]++;
			new detail[48];
			format(detail, sizeof(detail), "attempt=%d", PlayerData[playerid][pLoginAttempts]);
			LogAuthEvent(playerid, "login_fail", detail);
			if (PlayerData[playerid][pLoginAttempts] >= MAX_LOGIN_ATTEMPTS)
			{
				SendClientMessage(playerid, -1, "Too many failed login attempts.");
				Kick(playerid);
				return 1;
			}
			ShowLoginDialog(playerid, "Wrong password.\n\nEnter your password:");
		}
		return 1;
	}

	if (dialogid == DIALOG_LOGIN_CANCEL)
	{
		if (response)
		{
			LogAuthEvent(playerid, "login_cancel_quit");
			Kick(playerid);
			return 1;
		}
		LogAuthEvent(playerid, "login_cancel_back");
		ShowLoginDialog(playerid);
		return 1;
	}

	if (dialogid == DIALOG_SETSTATION)
	{
		if (!response)
		{
			return 1;
		}

		new station = strval(inputtext);
		if (station < 1 || station > MAX_STATIONS)
		{
			new prompt[64];
			format(prompt, sizeof(prompt), "Enter station number (1-%d):", MAX_STATIONS);
			ShowPlayerDialog(playerid, DIALOG_SETSTATION, DIALOG_STYLE_INPUT, "Set Station", prompt, "Set", "Cancel");
			return 1;
		}

		PlayStationForPlayer(playerid, station);
		return 1;
	}

	if (dialogid == DIALOG_REGISTER)
	{
		if (!response)
		{
			ShowPlayerDialog(
				playerid,
				DIALOG_REGISTER_CANCEL,
				DIALOG_STYLE_MSGBOX,
				"Quit Registration?",
				"Do you want to quit?\n\nUse /register to reopen registration.",
				"Quit",
				"Back"
			);
			return 1;
		}

		if (strlen(inputtext) < MIN_PASSWORD_LEN)
		{
			new message[96];
			format(message, sizeof(message), "Password must be at least %d characters.\n\nCreate a password:", MIN_PASSWORD_LEN);
			ShowRegisterDialog(playerid, message);
			return 1;
		}

		new name[MAX_PLAYER_NAME];
		GetPlayerName(playerid, name, sizeof(name));

		SHA256_PassHash(inputtext, name, PlayerData[playerid][pPassHash], PASSWORD_LEN + 1);
		PlayerData[playerid][pRegistering] = true;
		LogAuthEvent(playerid, "register_begin");

		TogglePlayerSpectating(playerid, false);
		ForceClassSelection(playerid);
		SetupPreviewCamera(playerid);
		SendClientMessage(playerid, -1, "Choose a skin and press Spawn to finish registration.");
		return 1;
	}

	if (dialogid == DIALOG_REGISTER_CANCEL)
	{
		if (response)
		{
			LogAuthEvent(playerid, "register_cancel_quit");
			Kick(playerid);
			return 1;
		}
		LogAuthEvent(playerid, "register_cancel_back");
		ShowRegisterDialog(playerid);
		return 1;
	}

	if (dialogid == DIALOG_DMV)
	{
		if (!response)
		{
			return 1;
		}

		switch (listitem)
		{
			case 0:
			{
				if (PlayerData[playerid][pVehicleRegistered])
				{
					SendClientMessage(playerid, -1, "Your vehicle is already registered.");
				}
				else
				{
					ShowDmvPaymentDialog(playerid, "Register vehicle and issue plates", GetRegistrationCost());
				}
			}
			case 1:
			{
				if (!PlayerData[playerid][pVehicleRegistered])
				{
					SendClientMessage(playerid, -1, "Register your vehicle before paying road taxes.");
				}
				else if (PlayerData[playerid][pTaxesPaid])
				{
					SendClientMessage(playerid, -1, "Your road taxes are already paid.");
				}
				else
				{
					ShowDmvPaymentDialog(playerid, "Pay road taxes", GetTaxCost());
				}
			}
			case 2:
			{
				if (!PlayerData[playerid][pVehicleRegistered])
				{
					SendClientMessage(playerid, -1, "Register your vehicle before insuring it.");
				}
				else if (PlayerData[playerid][pInsured])
				{
					SendClientMessage(playerid, -1, "Your vehicle is already insured.");
				}
				else
				{
					ShowDmvPaymentDialog(playerid, "Purchase vehicle insurance", GetInsuranceCost());
				}
			}
		}
		return 1;
	}

	if (dialogid == DIALOG_DMV_PAY)
	{
		if (!response)
		{
			ShowDmvDialog(playerid);
			return 1;
		}

		new bool:paid = false;
		new cost;
		if (!PlayerData[playerid][pVehicleRegistered])
		{
			cost = GetRegistrationCost();
			if (ChargePlayer(playerid, cost))
			{
				PlayerData[playerid][pVehicleRegistered] = true;
				paid = true;
				new vehicleid = GetPlayerVehicleID(playerid);
				if (vehicleid != 0)
				{
					new plate[MAX_PLATE_LEN];
					GenerateVehiclePlate(vehicleid, plate, sizeof(plate));
					SetVehiclePlate(vehicleid, plate);
				}
				SendClientMessage(playerid, -1, "Vehicle registered and plates issued.");
			}
		}
		else if (!PlayerData[playerid][pTaxesPaid])
		{
			cost = GetTaxCost();
			if (ChargePlayer(playerid, cost))
			{
				PlayerData[playerid][pTaxesPaid] = true;
				paid = true;
				SendClientMessage(playerid, -1, "Road taxes paid.");
			}
		}
		else if (!PlayerData[playerid][pInsured])
		{
			cost = GetInsuranceCost();
			if (ChargePlayer(playerid, cost))
			{
				PlayerData[playerid][pInsured] = true;
				paid = true;
				SendClientMessage(playerid, -1, "Insurance activated.");
			}
		}

		if (paid)
		{
			if (Activity_Mark(playerid, ACTIVITY_DMV))
			{
				SendClientMessage(playerid, -1, "Vielfalt +1 (DMV).");
			}
		}
		SavePlayerDmvStatus(playerid);
		ShowDmvDialog(playerid);
		return 1;
	}

	if (dialogid == DIALOG_INVENTORY)
	{
		if (!response)
		{
			return 1;
		}
		new itemid = GetItemIdFromList(playerid, listitem);
		if (!IsValidItem(itemid))
		{
			return 1;
		}

		PlayerData[playerid][pSelectedItem] = itemid;
		new options[96];
		if (gItems[itemid][itemConsumable])
		{
			format(options, sizeof(options), "Benutzen\nFallenlassen\nGeben\nWegwerfen\nShortcut");
		}
		else
		{
			format(options, sizeof(options), "Fallenlassen\nGeben\nWegwerfen\nShortcut");
		}
		ShowPlayerDialog(playerid, DIALOG_ITEM_ACTIONS, DIALOG_STYLE_LIST, "Gegenstaende", options, "Waehlen", "Zurueck");
		return 1;
	}

	if (dialogid == DIALOG_ITEM_ACTIONS)
	{
		if (!response)
		{
			ShowInventoryDialog(playerid);
			return 1;
		}

		new itemid = PlayerData[playerid][pSelectedItem];
		if (!IsValidItem(itemid))
		{
			return 1;
		}

		new invAction:action = ACTION_NONE;
		if (gItems[itemid][itemConsumable])
		{
			if (listitem == 0) action = ACTION_USE;
			else if (listitem == 1) action = ACTION_DROP;
			else if (listitem == 2) action = ACTION_GIVE;
			else if (listitem == 3) action = ACTION_DELETE;
			else if (listitem == 4) action = ACTION_SHORTCUT;
		}
		else
		{
			if (listitem == 0) action = ACTION_DROP;
			else if (listitem == 1) action = ACTION_GIVE;
			else if (listitem == 2) action = ACTION_DELETE;
			else if (listitem == 3) action = ACTION_SHORTCUT;
		}

		PlayerData[playerid][pSelectedAction] = action;
		if (action == ACTION_USE)
		{
			if (!RemovePlayerItem(playerid, itemid, 1))
			{
				SendClientMessage(playerid, -1, "Du hast diesen Gegenstand nicht.");
				return 1;
			}
			if (!UseInventoryItem(playerid, itemid))
			{
				SendClientMessage(playerid, -1, "Nichts passiert.");
				return 1;
			}
			new itemName[MAX_ITEM_NAME];
			GetItemName(itemid, itemName, sizeof(itemName));
			new message[96];
			format(message, sizeof(message), "Du hast %s benutzt.", itemName);
			SendClientMessage(playerid, -1, message);
			return 1;
		}

		if (action == ACTION_GIVE)
		{
			ShowPlayerDialog(playerid, DIALOG_ITEM_GIVE, DIALOG_STYLE_INPUT, "Gegenstand geben", "Eingabe: <player> <menge>", "Geben", "Abbrechen");
			return 1;
		}

		if (action == ACTION_SHORTCUT)
		{
			ShowPlayerDialog(playerid, DIALOG_ITEM_SHORTCUT, DIALOG_STYLE_LIST, "Shortcut setzen", "Slot 1\nSlot 2\nSlot 3\nSlot 4\nSlot 5", "Setzen", "Abbrechen");
			return 1;
		}

		if (action == ACTION_DROP || action == ACTION_DELETE)
		{
			ShowPlayerDialog(playerid, DIALOG_ITEM_AMOUNT, DIALOG_STYLE_INPUT, "Menge", "Eingabe: menge", "OK", "Abbrechen");
			return 1;
		}
	}

	if (dialogid == DIALOG_ITEM_SHORTCUT)
	{
		if (!response)
		{
			ShowInventoryDialog(playerid);
			return 1;
		}
		if (listitem < 0 || listitem >= MAX_ITEM_SHORTCUTS)
		{
			return 1;
		}
		new itemid = PlayerData[playerid][pSelectedItem];
		if (!IsValidItem(itemid))
		{
			return 1;
		}
		gItemShortcuts[playerid][listitem] = itemid;
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Shortcut %d gesetzt: %s.", listitem + 1, itemName);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (dialogid == DIALOG_ITEM_AMOUNT)
	{
		if (!response)
		{
			return 1;
		}
		new amount = strval(inputtext);
		new itemid = PlayerData[playerid][pSelectedItem];
		new invAction:action = PlayerData[playerid][pSelectedAction];
		if (!IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Ungueltige Menge.");
			return 1;
		}

		if (action == ACTION_DROP)
		{
			if (!RemovePlayerItem(playerid, itemid, amount))
			{
				SendClientMessage(playerid, -1, "Du hast nicht genug davon.");
				return 1;
			}

			new dropid = CreateDrop(playerid, itemid, amount);
			if (dropid == -1)
			{
				AddPlayerItem(playerid, itemid, amount);
				SendClientMessage(playerid, -1, "Kein Platz zum Ablegen.");
				return 1;
			}
			new itemName[MAX_ITEM_NAME];
			GetItemName(itemid, itemName, sizeof(itemName));
			new message[96];
			format(message, sizeof(message), "Du hast %s x%d fallengelassen. Druecke Y zum Aufheben.", itemName, amount);
			SendClientMessage(playerid, -1, message);
			return 1;
		}

		if (action == ACTION_DELETE)
		{
			if (!RemovePlayerItem(playerid, itemid, amount))
			{
				SendClientMessage(playerid, -1, "Du hast nicht genug davon.");
				return 1;
			}
			new itemName[MAX_ITEM_NAME];
			GetItemName(itemid, itemName, sizeof(itemName));
			new message[96];
			format(message, sizeof(message), "Du hast %s x%d entsorgt.", itemName, amount);
			SendClientMessage(playerid, -1, message);
			return 1;
		}
	}

	if (dialogid == DIALOG_ITEM_GIVE)
	{
		if (!response)
		{
			return 1;
		}
		new idx;
		new targetArg[64];
		targetArg = strtok(inputtext, idx);
		new amountArg[64];
		amountArg = strtok(inputtext, idx);

		new targetid = GetTargetPlayerId(targetArg);
		new amount = strval(amountArg);
		new itemid = PlayerData[playerid][pSelectedItem];

		if (targetid == INVALID_PLAYER_ID || amount < 1 || !IsValidItem(itemid))
		{
			SendClientMessage(playerid, -1, "Eingabe: <player> <menge>");
			return 1;
		}
		if (!CanPlayerCarryItem(targetid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "Zielinventar ist voll.");
			return 1;
		}

		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "Du hast nicht genug davon.");
			return 1;
		}

		AddPlayerItem(targetid, itemid, amount);
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Du hast %s x%d gegeben.", itemName, amount);
		SendClientMessage(playerid, -1, message);

		format(message, sizeof(message), "Du hast %s x%d erhalten.", itemName, amount);
		SendClientMessage(targetid, -1, message);
		return 1;
	}

	if (dialogid == DIALOG_PHONE)
	{
		if (!response)
		{
			return 1;
		}
		switch (listitem)
		{
			case 0:
			{
				SendClientMessage(playerid, -1, "Rufe ein Taxi mit /taxi.");
			}
			case 1:
			{
				SendClientMessage(playerid, -1, "Kleinanzeigen sind noch geschlossen. Schau spaeter vorbei.");
			}
			case 2:
			{
				ShowStatusDialog(playerid);
			}
		}
		return 1;
	}

	if (dialogid == DIALOG_VEHICLE_ITEMS)
	{
		if (!response)
		{
			return 1;
		}
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keinem Fahrzeug.");
			return 1;
		}
		new itemid = GetVehicleItemIdFromList(vehicleid, listitem);
		if (!IsValidItem(itemid))
		{
			return 1;
		}
		PlayerData[playerid][pSelectedItem] = itemid;
		PlayerData[playerid][pSelectedAction] = ACTION_VEH_TAKE;
		ShowPlayerDialog(playerid, DIALOG_VEHICLE_AMOUNT, DIALOG_STYLE_INPUT, "Menge", "Eingabe: menge", "Nehmen", "Abbrechen");
		return 1;
	}

	if (dialogid == DIALOG_VEHICLE_AMOUNT)
	{
		if (!response)
		{
			return 1;
		}
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keinem Fahrzeug.");
			return 1;
		}
		new amount = strval(inputtext);
		new itemid = PlayerData[playerid][pSelectedItem];
		if (!IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Ungueltige Menge.");
			return 1;
		}
		if (!CanPlayerCarryItem(playerid, itemid, amount))
		{
			ShowInventoryFullMessage(playerid, itemid, amount);
			return 1;
		}
		if (!RemoveVehicleItem(vehicleid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "Der Gegenstand ist nicht im Fahrzeug.");
			return 1;
		}
		if (!AddPlayerItem(playerid, itemid, amount))
		{
			AddVehicleItem(vehicleid, itemid, amount);
			ShowInventoryFullMessage(playerid, itemid, amount);
			return 1;
		}
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Du hast %s x%d aus dem Fahrzeug genommen.", itemName, amount);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	return 0;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
	if (Job_OnPlayerPickUpPickup(playerid, pickupid))
	{
		return 1;
	}
	return 0;
}

public OnPlayerEnterCheckpoint(playerid)
{
	if (Job_OnPlayerEnterCheckpoint(playerid))
	{
		return 1;
	}
	if (PlayerData[playerid][pWarehouseWaypoint])
	{
		if (GetPlayerDistanceFromPoint(playerid, COMPONENT_WAREHOUSE_X, COMPONENT_WAREHOUSE_Y, COMPONENT_WAREHOUSE_Z) <= 4.0)
		{
			ClearPlayerCheckpointEx(playerid);
			PlayerData[playerid][pWarehouseWaypoint] = false;
			SendClientMessage(playerid, -1, "Du bist am Lager angekommen. Nutze /buycrates [anzahl].");
			return 1;
		}
	}
	if (!PlayerData[playerid][pHasDelivery])
	{
		return 0;
	}

	new businessId = PlayerData[playerid][pDeliveryBiz];
	if (businessId < 0 || businessId >= MAX_BUSINESSES)
	{
		ClearDeliveryCheckpoint(playerid);
		return 0;
	}

	DeliverComponents(playerid, businessId);
	ClearDeliveryCheckpoint(playerid);
	PlayerData[playerid][pWarehouseWaypoint] = false;
	return 1;
}

public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ)
{
	new driverid = TaxiDriverForCustomer[playerid];
	if (driverid != INVALID_PLAYER_ID)
	{
		SetPlayerCheckpointEx(driverid, fX, fY, fZ, 4.0);
		SendClientMessage(driverid, -1, "Customer updated their waypoint.");
	}
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	if (oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER && gAlprEnabled[playerid])
	{
		StopAlpr(playerid);
	}
	return 1;
}

public OnVehicleSpawn(vehicleid)
{
	if (GetVehicleModel(vehicleid) != 0)
	{
		LoadVehicleStorage(vehicleid);
	}
	return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
	SaveVehicleStorage(vehicleid);
	return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
	if (PlayerData[playerid][pMiniGame] == MINIGAME_HOTWIRE)
	{
		FailMiniGame(playerid, "You left the vehicle and failed to hotwire it.");
	}
	return 1;
}

public OnMiniGameTimeout(playerid)
{
	if (PlayerData[playerid][pMiniGame] == MINIGAME_NONE)
	{
		return 0;
	}

	FailMiniGame(playerid, "You ran out of time and failed the attempt.");
	return 1;
}

public PetUpdate(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return 0;
	}

	if (PlayerData[playerid][pPetActor] == INVALID_ACTOR_ID)
	{
		return 0;
	}

	new Float:x, Float:y, Float:z, Float:a;
	GetPlayerPos(playerid, x, y, z);
	GetPlayerFacingAngle(playerid, a);

	SetActorVirtualWorld(PlayerData[playerid][pPetActor], GetPlayerVirtualWorld(playerid));

	switch (PlayerData[playerid][pPetTask])
	{
		case PET_TASK_FOLLOW:
		{
			new Float:angle = a + 180.0;
			new Float:px = x + floatsin(angle, degrees) * PET_FOLLOW_DISTANCE;
			new Float:py = y + floatcos(angle, degrees) * PET_FOLLOW_DISTANCE;
			SetActorPos(PlayerData[playerid][pPetActor], px, py, z);
		}
		case PET_TASK_WANDER:
		{
			new Float:angle = float(random(360));
			new Float:distance = float(random(5000)) / 100.0;
			if (distance > PET_WANDER_RADIUS)
			{
				distance = PET_WANDER_RADIUS;
			}
			new Float:px = x + floatsin(angle, degrees) * distance;
			new Float:py = y + floatcos(angle, degrees) * distance;
			SetActorPos(PlayerData[playerid][pPetActor], px, py, z);
		}
	}
	return 1;
}

public TaxiRentalTick()
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i) || TaxiRentalEndTick[i] == 0)
		{
			continue;
		}

		new minutes_left = TaxiMinutesRemaining(i);
		if (minutes_left == 0)
		{
			TaxiRentalEndTick[i] = 0;
			TaxiRentalNotifiedFive[i] = false;
			TaxiRentalNotifiedOne[i] = false;
			SendClientMessage(i, -1, "Taxi rental has ended. Return the taxi to avoid towing fees.");
			if (TaxiRentalVehicle[i] != INVALID_VEHICLE_ID)
			{
				DestroyVehicle(TaxiRentalVehicle[i]);
				TaxiRentalVehicle[i] = INVALID_VEHICLE_ID;
			}
			continue;
		}

		if (minutes_left <= TAXI_RENTAL_REMINDER_FIVE && !TaxiRentalNotifiedFive[i])
		{
			TaxiRentalNotifiedFive[i] = true;
			SendClientMessage(i, -1, "Taxi rental reminder: 5 minutes remaining.");
		}

		if (minutes_left <= TAXI_RENTAL_REMINDER_ONE && !TaxiRentalNotifiedOne[i])
		{
			TaxiRentalNotifiedOne[i] = true;
			SendClientMessage(i, -1, "Taxi rental reminder: 1 minute remaining.");
		}
	}
	return 1;
}

public TaxiMeterTick()
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i) || !TaxiMeterActive[i])
		{
			continue;
		}

		if (GetPlayerState(i) != PLAYER_STATE_DRIVER)
		{
			TaxiStopMeter(i);
			continue;
		}

		new vehicleid = GetPlayerVehicleID(i);
		if (!TaxiIsVehicleTaxi(vehicleid))
		{
			TaxiStopMeter(i);
			continue;
		}

		new Float:vel_x, Float:vel_y, Float:vel_z;
		GetVehicleVelocity(vehicleid, vel_x, vel_y, vel_z);
		if (floatsqroot((vel_x * vel_x) + (vel_y * vel_y) + (vel_z * vel_z)) < 0.01)
		{
			continue;
		}

		TaxiMeterElapsed[i] += 1000;
		if (TaxiMeterElapsed[i] >= TAXI_METER_RATE_MS)
		{
			TaxiMeterElapsed[i] = 0;
			TaxiMeterFareTotal[i] += TaxiFare[i];
			new message[64];
			format(message, sizeof(message), "Taxi fare increased to $%d.", TaxiMeterFareTotal[i]);
			SendClientMessage(i, -1, message);
		}
	}
	return 1;
}

public AutoSaveTick()
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i) || !PlayerData[i][pLogged])
		{
			continue;
		}
		SavePlayerState(i);
	}
	for (new v = 1; v < MAX_VEHICLES; v++)
	{
		if (GetVehicleModel(v) != 0)
		{
			SaveVehicleStorage(v);
		}
	}
	return 1;
}

public AuthTimeoutCheck(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return 0;
	}
	if (PlayerData[playerid][pAuthChecked])
	{
		return 1;
	}
	PlayerData[playerid][pAuthRetries]++;
	new detail[32];
	format(detail, sizeof(detail), "retry=%d", PlayerData[playerid][pAuthRetries]);
	LogAuthEvent(playerid, "account_check_timeout", detail);

	if (!gDatabaseReady || mysql_errno(g_SQL) != 0 || PlayerData[playerid][pAuthRetries] > 1)
	{
		SendClientMessage(playerid, -1, "Database is busy or offline. Please reconnect.");
		Kick(playerid);
		return 1;
	}

	StartAccountCheck(playerid);
	SetTimerEx("AuthTimeoutCheck", 5000, false, "i", playerid);
	return 1;
}

public AlprScan(playerid)
{
	if (!IsPlayerConnected(playerid) || !gAlprEnabled[playerid])
	{
		return 0;
	}

	if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
	{
		StopAlpr(playerid);
		return 0;
	}

	new playerVehicle = GetPlayerVehicleID(playerid);
	if (!IsPoliceVehicle(playerVehicle))
	{
		StopAlpr(playerid);
		SendClientMessage(playerid, -1, "ALPR disabled. You are no longer in a police vehicle.");
		return 0;
	}

	new Float:px, Float:py, Float:pz;
	GetVehiclePos(playerVehicle, px, py, pz);

	new nearestVehicle = INVALID_VEHICLE_ID;
	new Float:nearestDist = ALPR_RANGE + 1.0;

	for (new vid = 1; vid <= MAX_VEHICLES; vid++)
	{
		if (vid == playerVehicle)
		{
			continue;
		}
		if (!IsVehicleStreamedIn(vid, playerid))
		{
			continue;
		}
		new Float:vx, Float:vy, Float:vz;
		GetVehiclePos(vid, vx, vy, vz);
		new Float:dist = floatsqroot((vx - px) * (vx - px) + (vy - py) * (vy - py) + (vz - pz) * (vz - pz));
		if (dist <= ALPR_RANGE && dist < nearestDist)
		{
			nearestDist = dist;
			nearestVehicle = vid;
		}
	}

	if (nearestVehicle == INVALID_VEHICLE_ID)
	{
		return 1;
	}

	new plate[MAX_PLATE_LEN];
	GetVehicleNumberPlate(nearestVehicle, plate, sizeof(plate));
	ToUpperStr(plate);

	new driverid = GetVehicleOccupant(nearestVehicle, 0);
	new ownerName[MAX_PLAYER_NAME] = "Unknown";
	new bool:licenseOk = false;
	new bool:taxDue = false;

	if (driverid != INVALID_PLAYER_ID)
	{
		GetPlayerName(driverid, ownerName, sizeof(ownerName));
		licenseOk = gHasLicense[driverid];
		taxDue = gTaxDue[driverid];
	}

	new bool:stolen = IsPlateStolen(plate);
	PlayerPlaySound(playerid, 1052, 0.0, 0.0, 0.0);

	new message[144];
	format(message, sizeof(message),
		"ALPR: Plate %s | Owner: %s | License: %s | Stolen: %s | Taxes: %s",
		plate,
		ownerName,
		licenseOk ? "OK" : "NO",
		stolen ? "YES" : "NO",
		taxDue ? "DUE" : "OK"
	);
	SendClientMessage(playerid, -1, message);
	return 1;
}

public OnAddictionTick()
{
	new currentTick = GetTickCount();
	for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
	{
		if (!IsPlayerConnected(playerid) || !PlayerData[playerid][pLogged])
		{
			continue;
		}

		if (PlayerData[playerid][pDrugEffectEndTick] > 0 && currentTick >= PlayerData[playerid][pDrugEffectEndTick])
		{
			SetPlayerDrunkLevel(playerid, 0);
			PlayerData[playerid][pDrugEffectEndTick] = 0;
		}

		if (currentTick - PlayerData[playerid][pLastAddictionTick] >= ADDICTION_DECAY_INTERVAL)
		{
			if (PlayerData[playerid][pAddiction] > 0)
			{
				PlayerData[playerid][pAddiction] -= 1;
			}
			PlayerData[playerid][pLastAddictionTick] = currentTick;
		}

		if (PlayerData[playerid][pAddiction] >= 50)
		{
			new Float:health;
			GetPlayerHealth(playerid, health);
			if (health > 1.0)
			{
				SetPlayerHealth(playerid, health - 1.0);
			}
		}
	}
	return 1;
}

stock HandleGarageCommand(playerid, const command[])
{
	if (!strcmp(command, "/garagehelp", true))
	{
		return ShowGarageHelp(playerid);
	}
	if (!strcmp(command, "/plock", true))
	{
		PlayerData[playerid][pGarageLocked] = !PlayerData[playerid][pGarageLocked];
		SendClientMessage(playerid, -1, PlayerData[playerid][pGarageLocked] ? "Garage locked." : "Garage unlocked.");
		return 1;
	}
	if (!strcmp(command, "/pentrance", true))
	{
		SendClientMessage(playerid, -1, "Garage entrance updated (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/pinv", true))
	{
		SendClientMessage(playerid, -1, "Garage inventory opened (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/ptitem", true) || !strcmp(command, "/ptitems", true))
	{
		SendClientMessage(playerid, -1, "Removed item(s) from the garage (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/ppitem", true) || !strcmp(command, "/ppitems", true))
	{
		SendClientMessage(playerid, -1, "Placed item(s) in the garage (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/outfit", true))
	{
		SendClientMessage(playerid, -1, "Outfit menu opened (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/pmenu", true))
	{
		SendClientMessage(playerid, -1, "Garage info menu opened (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/pinfo", true))
	{
		SendClientMessage(playerid, -1, "Garage info displayed (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/setrentable", true))
	{
		SendClientMessage(playerid, -1, "Garage rentable state updated (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/rent", true))
	{
		SendClientMessage(playerid, -1, "Garage rented (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/stoprent", true))
	{
		SendClientMessage(playerid, -1, "Stopped renting (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/tenants", true))
	{
		SendClientMessage(playerid, -1, "Tenant list shown (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/kicktenant", true))
	{
		SendClientMessage(playerid, -1, "Tenant removed (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/evictall", true))
	{
		SendClientMessage(playerid, -1, "All tenants evicted (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/pdeposit", true))
	{
		SendClientMessage(playerid, -1, "Deposited money (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/pwithdrawl", true))
	{
		SendClientMessage(playerid, -1, "Withdrew money (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/sellproperty", true))
	{
		SendClientMessage(playerid, -1, "Garage sold back to market (placeholder).");
		return 1;
	}
	if (!strcmp(command, "/playersellproperty", true))
	{
		SendClientMessage(playerid, -1, "Garage sold to player (placeholder).");
		return 1;
	}
	return 0;
}

public OnAccountCheck(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return 0;
	}

	new err = mysql_errno(g_SQL);
	if (err != 0)
	{
		new detail[64];
		format(detail, sizeof(detail), "query_errno=%d", err);
		LogAuthEvent(playerid, "account_check_error", detail);
		if (err == 1054 || err == 1146)
		{
			if (EnsureDatabaseSchema())
			{
				StartAccountCheck(playerid);
				return 1;
			}
		}
		SendClientMessage(playerid, -1, "Account lookup failed. Please reconnect.");
		Kick(playerid);
		return 1;
	}

	LogAuthEvent(playerid, "account_check_cb");
	PlayerData[playerid][pAuthChecked] = true;
	PlayerData[playerid][pLoginAttempts] = 0;
	new rows;
	cache_get_row_count(rows);
	new rowsDetail[32];
	format(rowsDetail, sizeof(rowsDetail), "rows=%d", rows);
	LogAuthEvent(playerid, "account_check_rows", rowsDetail);
	if (rows > 0)
	{
		cache_get_value_name_int(0, "id", PlayerData[playerid][pAccountId]);
		cache_get_value_name(0, "password", PlayerData[playerid][pPassHash], PASSWORD_LEN + 1);
		cache_get_value_name_int(0, "skin", PlayerData[playerid][pSkin]);
		cache_get_value_name_float(0, "x", PlayerData[playerid][pX]);
		cache_get_value_name_float(0, "y", PlayerData[playerid][pY]);
		cache_get_value_name_float(0, "z", PlayerData[playerid][pZ]);
		cache_get_value_name_float(0, "a", PlayerData[playerid][pA]);
		cache_get_value_name_int(0, "interior", PlayerData[playerid][pInterior]);
		cache_get_value_name_int(0, "world", PlayerData[playerid][pWorld]);
		cache_get_value_name_int(0, "vehicle_registered", PlayerData[playerid][pVehicleRegistered]);
		cache_get_value_name_int(0, "taxes_paid", PlayerData[playerid][pTaxesPaid]);
		cache_get_value_name_int(0, "insured", PlayerData[playerid][pInsured]);
		cache_get_value_name_int(0, "addiction", PlayerData[playerid][pAddiction]);
		cache_get_value_name_int(0, "hunger", PlayerData[playerid][pHunger]);
		cache_get_value_name_int(0, "thirst", PlayerData[playerid][pThirst]);
		cache_get_value_name_int(0, "fatigue", PlayerData[playerid][pFatigue]);
		ApplyNeedClamp(playerid);
		cache_get_value_name_int(0, "money", PlayerData[playerid][pMoney]);
		cache_get_value_name_int(0, "carry_limit", PlayerData[playerid][pCarryLimit]);
		if (PlayerData[playerid][pCarryLimit] < BASE_CARRY_LIMIT_KG)
		{
			PlayerData[playerid][pCarryLimit] = BASE_CARRY_LIMIT_KG;
		}
		cache_get_value_name_int(0, "tutorial_done", PlayerData[playerid][pTutorialDone]);
		LogAuthEvent(playerid, "account_found");

		LoadPlayerInventory(playerid);
		Job_LoadPlayer(playerid);
		Faction_LoadPlayer(playerid);
		ShowLoginDialog(playerid);
	}
	else
	{
		PlayerData[playerid][pAccountId] = INVALID_ACCOUNT_ID;
		LogAuthEvent(playerid, "account_missing");
		ShowRegisterDialog(playerid);
	}
	return 1;
}

public OnAccountCreated(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return 0;
	}
	PlayerData[playerid][pAccountId] = cache_insert_id();
	if (PlayerData[playerid][pAccountId] == 0)
	{
		new errMsg[128];
		mysql_error(errMsg, sizeof(errMsg), g_SQL);
		printf("[MySQL] Account insert failed for player %d: %s", playerid, errMsg);
		SendClientMessage(playerid, -1, "Registrierung fehlgeschlagen (DB-Fehler). Bitte erneut versuchen.");
		return 1;
	}
	PlayerData[playerid][pMoney] = STARTER_CASH;
	if (GetPlayerMoney(playerid) < STARTER_CASH)
	{
		ResetPlayerMoney(playerid);
		GivePlayerMoney(playerid, STARTER_CASH);
	}
	UpdateLastLogin(playerid);
	SavePlayerState(playerid);
	LogAuthEvent(playerid, "register_complete");
	return 1;
}

public OnInventoryLoad(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return 0;
	}

	new rows;
	cache_get_row_count(rows);
	for (new row = 0; row < rows; row++)
	{
		new itemid;
		new amount;
		cache_get_value_name_int(row, "item_id", itemid);
		cache_get_value_name_int(row, "amount", amount);
		if (itemid >= 0 && itemid < MAX_ITEMS && amount > 0)
		{
			PlayerItems[playerid][itemid] = amount;
		}
	}
	return 1;
}

public OnStolenPlatesLoad()
{
	new rows;
	cache_get_row_count(rows);
	gStolenPlateCount = 0;
	for (new row = 0; row < rows && row < MAX_STOLEN_PLATES; row++)
	{
		cache_get_value_name(row, "plate", gStolenPlates[gStolenPlateCount], MAX_PLATE_LEN);
		gStolenPlateCount++;
	}
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	new lspdCmd[32];
	new lspdParams[96];
	new lspdLen = strlen(cmdtext);
	new lspdIdx = 0;
	new lspdCmdLen = 0;

	if (lspdLen == 0 || cmdtext[0] != '/')
	{
		return 0;
	}

	lspdIdx = 1;
	while (lspdIdx < lspdLen && cmdtext[lspdIdx] > ' ' && lspdCmdLen < sizeof(lspdCmd) - 1)
	{
		lspdCmd[lspdCmdLen++] = cmdtext[lspdIdx++];
	}
	lspdCmd[lspdCmdLen] = '\0';

	while (lspdIdx < lspdLen && cmdtext[lspdIdx] <= ' ')
	{
		lspdIdx++;
	}

	strmid(lspdParams, cmdtext, lspdIdx, lspdLen, sizeof(lspdParams));

	if (HandleLspdCommand(playerid, lspdCmd, lspdParams))
	{
		return 1;
	}

	if (HandleGarageCommand(playerid, cmdtext))
	{
		return 1;
	}

	if (Job_OnPlayerCommandText(playerid, cmdtext))
	{
		return 1;
	}
	if (Faction_OnPlayerCommandText(playerid, cmdtext))
	{
		return 1;
	}
	if (Map_OnPlayerCommandText(playerid, cmdtext))
	{
		return 1;
	}

	new idx;
	new cmd[64];
	cmd = strtok(cmdtext, idx);

	if (!strlen(cmd))
	{
		return 0;
	}

	if (!strcmp(cmd, "/login", true))
	{
		if (PlayerData[playerid][pLogged])
		{
			SendClientMessage(playerid, -1, "You are already logged in.");
			return 1;
		}
		if (!PlayerData[playerid][pAuthChecked])
		{
			SendClientMessage(playerid, -1, "Loading your account, retrying...");
			StartAccountCheck(playerid);
			return 1;
		}
		if (PlayerData[playerid][pPassHash][0] == '\0')
		{
			ShowRegisterDialog(playerid);
			return 1;
		}
		ShowLoginDialog(playerid);
		return 1;
	}

	if (!strcmp(cmd, "/register", true))
	{
		if (PlayerData[playerid][pLogged])
		{
			SendClientMessage(playerid, -1, "You are already logged in.");
			return 1;
		}
		if (!PlayerData[playerid][pAuthChecked])
		{
			SendClientMessage(playerid, -1, "Loading your account, retrying...");
			StartAccountCheck(playerid);
			return 1;
		}
		if (PlayerData[playerid][pPassHash][0] != '\0')
		{
			ShowLoginDialog(playerid);
			return 1;
		}
		ShowRegisterDialog(playerid);
		return 1;
	}

	if (!strcmp(cmd, "/help", true))
	{
		ShowHelpDialog(playerid);
		return 1;
	}
	if (!strcmp(cmd, "/status", true))
	{
		ShowStatusDialog(playerid);
		return 1;
	}
	if (!strcmp(cmd, "/tp", true))
	{
		if (!gCheckpointActive[playerid])
		{
			SendClientMessage(playerid, -1, "Kein aktiver Marker.");
			return 1;
		}
		new Float:x = gCheckpointX[playerid];
		new Float:y = gCheckpointY[playerid];
		new Float:z = gCheckpointZ[playerid];
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid != 0)
		{
			new Float:a;
			GetVehicleZAngle(vehicleid, a);
			SetVehiclePos(vehicleid, x, y, z + 0.5);
			SetVehicleZAngle(vehicleid, a);
		}
		else
		{
			SetPlayerPos(playerid, x, y, z);
		}
		SendClientMessage(playerid, -1, "Teleportiert zum Marker.");
		return 1;
	}

	if (!strcmp(cmd, "/stats", true))
	{
		new msg[144];
		format(msg, sizeof(msg), "Hunger: %d | Durst: %d | Muedigkeit: %d | Inventar: %d/%dkg",
			PlayerData[playerid][pHunger], PlayerData[playerid][pThirst], PlayerData[playerid][pFatigue],
			GetPlayerInventoryWeight(playerid), PlayerData[playerid][pCarryLimit]);
		SendClientMessage(playerid, -1, msg);
		return 1;
	}

	if (!strcmp(cmd, "/guide", true))
	{
		ShowTutorialDialog(playerid);
		return 1;
	}

	if (!strcmp(cmd, "/phone", true) || !strcmp(cmd, "/handy", true))
	{
		ShowPlayerDialog(playerid, DIALOG_PHONE, DIALOG_STYLE_LIST, "Handy", "Taxi rufen\nKleinanzeigen\nStatus", "Waehlen", "Schliessen");
		return 1;
	}

	if (!strcmp(cmd, "/todo", true) || !strcmp(cmd, "/next", true) || !strcmp(cmd, "/whattodo", true))
	{
		ShowNextStepHint(playerid);
		return 1;
	}

	if (!strcmp(cmd, "/warehouse", true) || !strcmp(cmd, "/wh", true))
	{
		if (PlayerData[playerid][pHasDelivery])
		{
			SendClientMessage(playerid, -1, "You already have a delivery route. Use /cancelbiz to clear it first.");
			return 1;
		}
		PlayerData[playerid][pWarehouseWaypoint] = true;
		SetPlayerCheckpointEx(playerid, COMPONENT_WAREHOUSE_X, COMPONENT_WAREHOUSE_Y, COMPONENT_WAREHOUSE_Z, 4.0);
		SendClientMessage(playerid, -1, "Warehouse waypoint set.");
		return 1;
	}

	if (!strcmp(cmd, "/enter", true))
	{
		if (!PlayerData[playerid][pLogged])
		{
			SendClientMessage(playerid, -1, "You must be logged in to use property teleports.");
			return 1;
		}

		for (new i = 0; i < sizeof(gTeleports); i++)
		{
			if (IsPlayerNearTeleport(playerid, i, true))
			{
				if (!TryPropertyTeleport(playerid, i, true))
				{
					SendClientMessage(playerid, -1, "Teleport is on cooldown.");
				}
				return 1;
			}
		}

		SendClientMessage(playerid, -1, "You are not near a property entrance.");
		return 1;
	}

	if (!strcmp(cmd, "/exit", true))
	{
		if (!PlayerData[playerid][pLogged])
		{
			SendClientMessage(playerid, -1, "You must be logged in to use property teleports.");
			return 1;
		}

		for (new i = 0; i < sizeof(gTeleports); i++)
		{
			if (IsPlayerNearTeleport(playerid, i, false))
			{
				if (!TryPropertyTeleport(playerid, i, false))
				{
					SendClientMessage(playerid, -1, "Teleport is on cooldown.");
				}
				return 1;
			}
		}

		SendClientMessage(playerid, -1, "You are not near a property exit.");
		return 1;
	}

	if (!strcmp(cmd, "/myitems", true) || !strcmp(cmd, "/inv", true) || !strcmp(cmd, "/items", true) || !strcmp(cmd, "/inventory", true) || !strcmp(cmd, "/i", true))
	{
		ShowInventoryDialog(playerid);
		return 1;
	}

	if (!strcmp(cmd, "/showitems", true))
	{
		new targetArg[64];
		targetArg = strtok(cmdtext, idx);
		new targetid = GetTargetPlayerId(targetArg);
		if (targetid == INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "Eingabe: /showitems <player>");
			return 1;
		}
		new name[MAX_PLAYER_NAME];
		GetPlayerName(playerid, name, sizeof(name));
		new title[96];
		format(title, sizeof(title), "%s zeigt dir sein Inventar:", name);
		SendInventoryList(playerid, targetid, title);
		SendClientMessage(playerid, -1, "Du hast dein Inventar gezeigt.");
		return 1;
	}

	if (!strcmp(cmd, "/giveitem", true))
	{
		new targetArg[64];
		targetArg = strtok(cmdtext, idx);
		new itemArg[64];
		itemArg = strtok(cmdtext, idx);
		new amountArg[64];
		amountArg = strtok(cmdtext, idx);

		new targetid = GetTargetPlayerId(targetArg);
		new itemid = strval(itemArg);
		new amount = strval(amountArg);

		if (targetid == INVALID_PLAYER_ID || !IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Eingabe: /giveitem <player> <itemid> <menge>");
			return 1;
		}
		if (!CanPlayerCarryItem(targetid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "Zielinventar ist voll.");
			return 1;
		}

		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "Du hast nicht genug davon.");
			return 1;
		}

		AddPlayerItem(targetid, itemid, amount);
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));

		new message[96];
		format(message, sizeof(message), "Du hast %s x%d gegeben.", itemName, amount);
		SendClientMessage(playerid, -1, message);

		format(message, sizeof(message), "Du hast %s x%d erhalten.", itemName, amount);
		SendClientMessage(targetid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/useitem", true))
	{
		new itemArg[64];
		itemArg = strtok(cmdtext, idx);

		new itemid = -1;
		if (strlen(itemArg))
		{
			itemid = strval(itemArg);
		}
		else
		{
			for (new i = 0; i < MAX_ITEMS; i++)
			{
				if (PlayerItems[playerid][i] > 0 && gItems[i][itemConsumable])
				{
					itemid = i;
					break;
				}
			}
		}

		if (!IsValidItem(itemid))
		{
			SendClientMessage(playerid, -1, "Eingabe: /useitem <itemid>");
			return 1;
		}

		if (!gItems[itemid][itemConsumable])
		{
			SendClientMessage(playerid, -1, "Dieser Gegenstand kann nicht benutzt werden.");
			return 1;
		}

		if (!RemovePlayerItem(playerid, itemid, 1))
		{
			SendClientMessage(playerid, -1, "Du hast diesen Gegenstand nicht.");
			return 1;
		}
		if (!UseInventoryItem(playerid, itemid))
		{
			SendClientMessage(playerid, -1, "Nichts passiert.");
			return 1;
		}

		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Du hast %s benutzt.", itemName);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/item", true))
	{
		new slotArg[16];
		slotArg = strtok(cmdtext, idx);
		new slot = strval(slotArg);
		if (slot < 1 || slot > MAX_ITEM_SHORTCUTS)
		{
			SendClientMessage(playerid, -1, "Eingabe: /item <slot>");
			return 1;
		}
		new itemid = gItemShortcuts[playerid][slot - 1];
		if (!IsValidItem(itemid))
		{
			SendClientMessage(playerid, -1, "Kein Shortcut auf diesem Slot.");
			return 1;
		}
		if (PlayerItems[playerid][itemid] < 1)
		{
			SendClientMessage(playerid, -1, "Du hast diesen Gegenstand nicht.");
			return 1;
		}
		if (gItems[itemid][itemConsumable])
		{
			if (!RemovePlayerItem(playerid, itemid, 1))
			{
				SendClientMessage(playerid, -1, "Du hast diesen Gegenstand nicht.");
				return 1;
			}
			if (!UseInventoryItem(playerid, itemid))
			{
				SendClientMessage(playerid, -1, "Nichts passiert.");
				return 1;
			}
			new itemName[MAX_ITEM_NAME];
			GetItemName(itemid, itemName, sizeof(itemName));
			new message[96];
			format(message, sizeof(message), "Du hast %s benutzt.", itemName);
			SendClientMessage(playerid, -1, message);
			return 1;
		}
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Du hast %s aus dem Inventar genommen.", itemName);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/deleteitem", true))
	{
		new itemArg[64];
		itemArg = strtok(cmdtext, idx);
		new amountArg[64];
		amountArg = strtok(cmdtext, idx);

		new itemid = strval(itemArg);
		new amount = strval(amountArg);
		if (!IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Eingabe: /deleteitem <itemid> <menge>");
			return 1;
		}
		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "Du hast nicht genug davon.");
			return 1;
		}
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Du hast %s x%d entsorgt.", itemName, amount);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/dropitem", true))
	{
		new itemArg[64];
		itemArg = strtok(cmdtext, idx);
		new amountArg[64];
		amountArg = strtok(cmdtext, idx);

		new itemid = strval(itemArg);
		new amount = strval(amountArg);
		if (!IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Eingabe: /dropitem <itemid> <menge>");
			return 1;
		}
		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "Du hast nicht genug davon.");
			return 1;
		}

		new dropid = CreateDrop(playerid, itemid, amount);
		if (dropid == -1)
		{
			AddPlayerItem(playerid, itemid, amount);
			SendClientMessage(playerid, -1, "Kein Platz zum Ablegen.");
			return 1;
		}
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Du hast %s x%d fallengelassen. Druecke Y zum Aufheben.", itemName, amount);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/vehmenu", true) || !strcmp(cmd, "/vmenu", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keinem Fahrzeug.");
			return 1;
		}
		if (!CanAccessVehicleTrunk(playerid, vehicleid))
		{
			SendClientMessage(playerid, -1, "Fahrzeug ist abgeschlossen.");
			return 1;
		}
		ShowVehicleItemsDialog(playerid, vehicleid);
		return 1;
	}

	if (!strcmp(cmd, "/trunk", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keinem Fahrzeug.");
			return 1;
		}
		if (!CanAccessVehicleTrunk(playerid, vehicleid))
		{
			SendClientMessage(playerid, -1, "Fahrzeug ist abgeschlossen.");
			return 1;
		}
		SendClientMessage(playerid, -1, "Du oeffnest den Kofferraum. Nutze /vehitems.");
		return 1;
	}

	if (!strcmp(cmd, "/vclaim", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keinem Fahrzeug.");
			return 1;
		}
		if (gVehicleOwner[vehicleid] != INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "Dieses Fahrzeug gehoert bereits jemandem.");
			return 1;
		}
		gVehicleOwner[vehicleid] = playerid;
		ToggleVehicleLock(vehicleid, true);
		SendClientMessage(playerid, -1, "Fahrzeug beansprucht. Es ist nun abgeschlossen.");
		return 1;
	}

	if (!strcmp(cmd, "/vehitems", true) || !strcmp(cmd, "/vinv", true) || !strcmp(cmd, "/vitems", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keinem Fahrzeug.");
			return 1;
		}
		if (!CanAccessVehicleTrunk(playerid, vehicleid))
		{
			SendClientMessage(playerid, -1, "Fahrzeug ist abgeschlossen.");
			return 1;
		}
		SendVehicleInventoryList(playerid, vehicleid, "Fahrzeug-Inventar:");
		return 1;
	}

	if (!strcmp(cmd, "/vtitem", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keinem Fahrzeug.");
			return 1;
		}
		if (!CanAccessVehicleTrunk(playerid, vehicleid))
		{
			SendClientMessage(playerid, -1, "Fahrzeug ist abgeschlossen.");
			return 1;
		}
		new itemArg[64];
		itemArg = strtok(cmdtext, idx);
		new amountArg[64];
		amountArg = strtok(cmdtext, idx);

		new itemid = strval(itemArg);
		new amount = strlen(amountArg) ? strval(amountArg) : 1;
		if (!IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Eingabe: /vtitem <itemid> (<menge>)");
			return 1;
		}
		if (!CanPlayerCarryItem(playerid, itemid, amount))
		{
			ShowInventoryFullMessage(playerid, itemid, amount);
			return 1;
		}
		if (!RemoveVehicleItem(vehicleid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "Der Gegenstand ist nicht im Fahrzeug.");
			return 1;
		}
		if (!AddPlayerItem(playerid, itemid, amount))
		{
			AddVehicleItem(vehicleid, itemid, amount);
			ShowInventoryFullMessage(playerid, itemid, amount);
			return 1;
		}
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Du hast %s x%d aus dem Fahrzeug genommen.", itemName, amount);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/vpitem", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keinem Fahrzeug.");
			return 1;
		}
		if (!CanAccessVehicleTrunk(playerid, vehicleid))
		{
			SendClientMessage(playerid, -1, "Fahrzeug ist abgeschlossen.");
			return 1;
		}
		new itemArg[64];
		itemArg = strtok(cmdtext, idx);
		new amountArg[64];
		amountArg = strtok(cmdtext, idx);

		new itemid = strval(itemArg);
		new amount = strlen(amountArg) ? strval(amountArg) : 1;
		if (!IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Eingabe: /vpitem <itemid> (<menge>)");
			return 1;
		}
		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "Du hast nicht genug davon.");
			return 1;
		}
		if (!AddVehicleItem(vehicleid, itemid, amount))
		{
			AddPlayerItem(playerid, itemid, amount);
			SendClientMessage(playerid, -1, "Kofferraum ist voll.");
			return 1;
		}
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Du hast %s x%d ins Fahrzeug gelegt.", itemName, amount);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/vtitems", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keinem Fahrzeug.");
			return 1;
		}
		if (!CanAccessVehicleTrunk(playerid, vehicleid))
		{
			SendClientMessage(playerid, -1, "Fahrzeug ist abgeschlossen.");
			return 1;
		}
		new freeKg = PlayerData[playerid][pCarryLimit] - GetPlayerInventoryWeight(playerid);
		new bool:partial = false;
		for (new i = 0; i < MAX_ITEMS; i++)
		{
			if (VehicleItems[vehicleid][i] < 1 || freeKg < 1)
			{
				continue;
			}
			new weightKg = gItems[i][itemWeightKg];
			if (weightKg < 1)
			{
				continue;
			}
			new canAmount = freeKg / weightKg;
			if (canAmount < 1)
			{
				partial = true;
				continue;
			}
			new take = VehicleItems[vehicleid][i];
			if (take > canAmount)
			{
				take = canAmount;
				partial = true;
			}
			if (AddPlayerItem(playerid, i, take))
			{
				VehicleItems[vehicleid][i] -= take;
				freeKg -= take * weightKg;
			}
		}
		if (partial)
		{
			SendClientMessage(playerid, -1, "Inventar voll. Nicht alles konnte genommen werden.");
		}
		else
		{
			SendClientMessage(playerid, -1, "Du hast alle Gegenstaende aus dem Fahrzeug genommen.");
		}
		return 1;
	}

	if (!strcmp(cmd, "/vpitems", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keinem Fahrzeug.");
			return 1;
		}
		if (!CanAccessVehicleTrunk(playerid, vehicleid))
		{
			SendClientMessage(playerid, -1, "Fahrzeug ist abgeschlossen.");
			return 1;
		}
		new freeKg = GetVehicleTrunkCapacity(vehicleid) - GetVehicleInventoryWeight(vehicleid);
		new bool:partial = false;
		for (new i = 0; i < MAX_ITEMS; i++)
		{
			if (PlayerItems[playerid][i] < 1 || freeKg < 1)
			{
				continue;
			}
			new weightKg = gItems[i][itemWeightKg];
			if (weightKg < 1)
			{
				continue;
			}
			new canAmount = freeKg / weightKg;
			if (canAmount < 1)
			{
				partial = true;
				continue;
			}
			new put = PlayerItems[playerid][i];
			if (put > canAmount)
			{
				put = canAmount;
				partial = true;
			}
			if (AddVehicleItem(vehicleid, i, put))
			{
				PlayerItems[playerid][i] -= put;
				freeKg -= put * weightKg;
			}
		}
		if (partial)
		{
			SendClientMessage(playerid, -1, "Kofferraum voll. Nicht alles passte rein.");
		}
		else
		{
			SendClientMessage(playerid, -1, "Du hast alle Gegenstaende ins Fahrzeug gelegt.");
		}
		return 1;
	}

	if (!strcmp(cmd, "/garage", true))
	{
		ShowGarageInfoDialog(playerid);
		return 1;
	}

	if (!strcmp(cmd, "/repair", true))
	{
		if (!EnsureGarageAccess(playerid) || !EnsureVehicleAccess(playerid))
		{
			return 1;
		}
		new vehicleid = GetPlayerVehicleID(playerid);
		RepairVehicle(vehicleid);
		SendClientMessage(playerid, -1, "Your vehicle has been repaired.");
		return 1;
	}

	if (!strcmp(cmd, "/paint", true))
	{
		if (!EnsureGarageAccess(playerid) || !EnsureVehicleAccess(playerid))
		{
			return 1;
		}
		new vehicleid = GetPlayerVehicleID(playerid);
		new color1 = random(256);
		new color2 = random(256);
		ChangeVehicleColor(vehicleid, color1, color2);
		SendClientMessage(playerid, -1, "Fresh paint applied.");
		return 1;
	}

	if (!strcmp(cmd, "/mod", true))
	{
		if (!EnsureGarageAccess(playerid) || !EnsureVehicleAccess(playerid))
		{
			return 1;
		}
		new vehicleid = GetPlayerVehicleID(playerid);
		new component = 1010 + random(8);
		AddVehicleComponent(vehicleid, component);
		SendClientMessage(playerid, -1, "A basic component has been installed.");
		return 1;
	}

	if (!strcmp(cmd, "/lock", true))
	{
		if (!EnsureGarageAccess(playerid) || !EnsureVehicleAccess(playerid))
		{
			return 1;
		}
		new vehicleid = GetPlayerVehicleID(playerid);
		new engine, lights, alarm, doors, bonnet, boot, objective;
		GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
		new bool:locked = (doors == 0);
		ToggleVehicleLock(vehicleid, locked);
		SendClientMessage(playerid, -1, locked ? "Vehicle locked." : "Vehicle unlocked.");
		return 1;
	}

	if (!strcmp(cmd, "/alarm", true))
	{
		if (!EnsureGarageAccess(playerid) || !EnsureVehicleAccess(playerid))
		{
			return 1;
		}
		new vehicleid = GetPlayerVehicleID(playerid);
		gVehicleAlarmOn[vehicleid] = !gVehicleAlarmOn[vehicleid];
		SendClientMessage(playerid, -1, gVehicleAlarmOn[vehicleid] ? "Alarm installed." : "Alarm removed.");
		return 1;
	}

	if (!strcmp(cmd, "/wanted", true))
	{
		new message[128];
		format(message, sizeof(message),
			"Wanted cars: %d, %d, %d, %d, %d",
			gWantedList[0],
			gWantedList[1],
			gWantedList[2],
			gWantedList[3],
			gWantedList[4]
		);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/chop", true))
	{
		if (!EnsureChopAccess(playerid) || !EnsureVehicleAccess(playerid))
		{
			return 1;
		}
		new vehicleid = GetPlayerVehicleID(playerid);
		new modelid = GetVehicleModel(vehicleid);
		new bool:wanted = false;
		for (new i = 0; i < sizeof(gWantedList); i++)
		{
			if (gWantedList[i] == modelid)
			{
				wanted = true;
				break;
			}
		}
		new partsGained = PARTS_PER_CHOP + (wanted ? 2 : 0);
		PlayerData[playerid][pParts] += partsGained;
		DestroyVehicle(vehicleid);
		SendClientMessage(playerid, -1, "Vehicle chopped for parts.");
		if (wanted)
		{
			SendClientMessage(playerid, -1, "Bonus parts for a wanted car.");
		}
		return 1;
	}

	if (!strcmp(cmd, "/craft", true))
	{
		if (PlayerData[playerid][pParts] < PARTS_FOR_METAL)
		{
			SendClientMessage(playerid, -1, "Not enough parts. Chop more vehicles.");
			return 1;
		}
		PlayerData[playerid][pParts] -= PARTS_FOR_METAL;
		GivePlayerMoney(playerid, 500);
		SendClientMessage(playerid, -1, "Crafted metal parts and sold for $500.");
		return 1;
	}

	if (!strcmp(cmd, "/alpr", true))
	{
		if (gAlprEnabled[playerid])
		{
			StopAlpr(playerid);
			return 1;
		}

		if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
		{
			SendClientMessage(playerid, -1, "You must be driving a police vehicle to use ALPR.");
			return 1;
		}

		new vehicleid = GetPlayerVehicleID(playerid);
		if (!IsPoliceVehicle(vehicleid))
		{
			SendClientMessage(playerid, -1, "This vehicle is not equipped with ALPR.");
			return 1;
		}

		gAlprEnabled[playerid] = true;
		StartAlpr(playerid);
		SendClientMessage(playerid, -1, "ALPR enabled. Scanning for nearby plates.");
		return 1;
	}

	if (!strcmp(cmd, "/reportvehiclestolen", true)
		|| !strcmp(cmd, "/reportvehstolen", true)
		|| !strcmp(cmd, "/reportstolen", true))
	{
		if (lspdParams[0] == '\0')
		{
			SendClientMessage(playerid, -1, "Usage: /reportvehiclestolen [numberplate]");
			return 1;
		}

		new plate[MAX_PLATE_LEN];
		format(plate, sizeof(plate), "%s", lspdParams);
		ToUpperStr(plate);

		if (AddStolenPlate(plate))
		{
			SendClientMessage(playerid, -1, "Vehicle reported stolen. ALPR will flag it.");
		}
		else
		{
			SendClientMessage(playerid, -1, "Unable to report vehicle stolen. Try again later.");
		}
		return 1;
	}

	if (!strcmp(cmd, "/reportvehiclefound", true)
		|| !strcmp(cmd, "/reportvehfound", true)
		|| !strcmp(cmd, "/reportfound", true))
	{
		if (lspdParams[0] == '\0')
		{
			SendClientMessage(playerid, -1, "Usage: /reportvehiclefound [numberplate]");
			return 1;
		}

		new plate[MAX_PLATE_LEN];
		format(plate, sizeof(plate), "%s", lspdParams);
		ToUpperStr(plate);

		if (RemoveStolenPlate(plate))
		{
			SendClientMessage(playerid, -1, "Vehicle report cleared.");
		}
		else
		{
			SendClientMessage(playerid, -1, "No stolen vehicle report found for that plate.");
		}
		return 1;
	}

	if (!strcmp(cmd, "/license", true))
	{
		if (!strcmp(lspdParams, "on", true))
		{
			gHasLicense[playerid] = true;
			SendClientMessage(playerid, -1, "Your driver's license is now valid.");
			return 1;
		}
		if (!strcmp(lspdParams, "off", true))
		{
			gHasLicense[playerid] = false;
			SendClientMessage(playerid, -1, "Your driver's license has been suspended.");
			return 1;
		}
		SendClientMessage(playerid, -1, "Usage: /license [on|off]");
		return 1;
	}

	if (!strcmp(cmd, "/taxdue", true))
	{
		if (!strcmp(lspdParams, "on", true))
		{
			gTaxDue[playerid] = true;
			SendClientMessage(playerid, -1, "Your vehicle taxes are now marked overdue.");
			return 1;
		}
		if (!strcmp(lspdParams, "off", true))
		{
			gTaxDue[playerid] = false;
			SendClientMessage(playerid, -1, "Your vehicle taxes are up to date.");
			return 1;
		}
		SendClientMessage(playerid, -1, "Usage: /taxdue [on|off]");
		return 1;
	}

	if (!strcmp(cmd, "/dmv", true))
	{
		if (!PlayerData[playerid][pLogged])
		{
			SendClientMessage(playerid, -1, "You must be logged in to use the DMV.");
			return 1;
		}

		ShowDmvDialog(playerid);
		return 1;
	}

	if (!strcmp(cmd, "/teleports", true))
	{
		SendClientMessage(playerid, -1, "Property teleports are marked with green pickups.");
		SendClientMessage(playerid, -1, "Use /enter at entrances and /exit at exits.");
		return 1;
	}

	if (!strcmp(cmd, "/radioshow", true))
	{
		PlayerData[playerid][pRadioVisible] = true;
		SendClientMessage(playerid, -1, "XM Radio UI is now visible.");
		return 1;
	}

	if (!strcmp(cmd, "/radiohide", true))
	{
		PlayerData[playerid][pRadioVisible] = false;
		SendClientMessage(playerid, -1, "XM Radio UI is now hidden.");
		return 1;
	}

	if (!strcmp(cmd, "/setstation", true))
	{
		if (GetPlayerInterior(playerid) == 0)
		{
			SendClientMessage(playerid, -1, "You must be inside a house or property to use this command.");
			return 1;
		}

		new arg[16];
		if (!GetCommandArg(cmdtext, 1, arg, sizeof(arg)))
		{
			new prompt[64];
			format(prompt, sizeof(prompt), "Enter station number (1-%d):", MAX_STATIONS);
			ShowPlayerDialog(playerid, DIALOG_SETSTATION, DIALOG_STYLE_INPUT, "Set Station", prompt, "Set", "Cancel");
			return 1;
		}

		new station = strval(arg);
		if (!PlayStationForPlayer(playerid, station))
		{
			return 1;
		}

		new message[64];
		format(message, sizeof(message), "Tuned to station %d.", station);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/reloadcinema", true))
	{
		SetupCinemaInterior();
		SendClientMessage(playerid, -1, "Cinema interior reloaded.");
		return 1;
	}

	if (!strcmp(cmd, "/cinemaoff", true))
	{
		if (!IsPlayerAdmin(playerid))
		{
			SendClientMessage(playerid, -1, "You must be an RCON admin to stop broadcasts.");
			return 1;
		}

		StopCinemaBroadcast();
		return 1;
	}

	if (!strcmp(cmd, "/leavecinema", true))
	{
		if (!gCinemaWatching[playerid])
		{
			SendClientMessage(playerid, -1, "You are not watching the cinema.");
			return 1;
		}

		gCinemaWatching[playerid] = false;
		SendClientMessage(playerid, -1, "You stopped watching the cinema.");
		return 1;
	}

	if (!strcmp(cmd, "/cinema", true))
	{
		if (!IsPlayerAdmin(playerid))
		{
			SendClientMessage(playerid, -1, "You must be an RCON admin to start broadcasts.");
			return 1;
		}

		if (strlen(lspdParams) < 3)
		{
			SendClientMessage(playerid, -1, "Usage: /cinema <youtube_id_or_url>");
			return 1;
		}

		StartCinemaBroadcast(lspdParams);
		return 1;
	}

	if (!strcmp(cmd, "/businesses", true))
	{
		SendClientMessage(playerid, -1, "Businesses for sale:");
		for (new i = 0; i < MAX_BUSINESSES; i++)
		{
			if (BusinessData[i][bOwner] == INVALID_PLAYER_ID)
			{
				new message[96];
				format(message, sizeof(message), "%d) %s - $%d", i + 1, gBusinessTypeNames[_:BusinessData[i][bType]], BusinessData[i][bPrice]);
				SendClientMessage(playerid, -1, message);
			}
		}
		return 1;
	}

	if (!strcmp(cmd, "/bizhelp", true))
	{
		SendClientMessage(playerid, -1, "Business commands: /businesses, /buybiz, /bizstatus, /setcomponentprice, /sellbiz, /buyitem, /buycrates, /deliverbiz, /cancelbiz");
		SendClientMessage(playerid, -1, "Tip: press Y near a business for details. Buy crates at the warehouse marker.");
		return 1;
	}

	if (!strcmp(cmd, "/buybiz", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			SendClientMessage(playerid, -1, "You are not near a business.");
			return 1;
		}

		if (BusinessData[businessId][bOwner] != INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "This business is already owned.");
			return 1;
		}

		if (GetPlayerMoney(playerid) < BusinessData[businessId][bPrice])
		{
			SendClientMessage(playerid, -1, "You cannot afford this business.");
			return 1;
		}

		GivePlayerMoneyLogged(playerid, -BusinessData[businessId][bPrice], "biz_buy");
		BusinessData[businessId][bOwner] = playerid;
		BusinessData[businessId][bComponents] = BUSINESS_COMPONENTS_DEFAULT;
		UpdateBusinessLabel(businessId);
		SendClientMessage(playerid, -1, "Business purchased. Press Y to manage it.");
		return 1;
	}

	if (!strcmp(cmd, "/bizstatus", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			SendClientMessage(playerid, -1, "You are not near a business.");
			return 1;
		}

		ShowBusinessStatus(playerid, businessId);
		return 1;
	}

	if (!strcmp(cmd, "/setcomponentprice", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			SendClientMessage(playerid, -1, "You are not near a business.");
			return 1;
		}

		if (BusinessData[businessId][bOwner] != playerid)
		{
			SendClientMessage(playerid, -1, "Only the owner can update component prices.");
			return 1;
		}

		new priceToken[16];
		GetCommandToken(cmdtext, idx, priceToken, sizeof(priceToken));
		new price = strval(priceToken);
		if (price < 1)
		{
			SendClientMessage(playerid, -1, "Usage: /setcomponentprice [amount]");
			return 1;
		}

		BusinessData[businessId][bComponentPrice] = price;
		SendClientMessage(playerid, -1, "Component purchase price updated.");
		ShowBusinessStatus(playerid, businessId);
		return 1;
	}

	if (!strcmp(cmd, "/sellbiz", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			SendClientMessage(playerid, -1, "You are not near a business.");
			return 1;
		}

		if (BusinessData[businessId][bOwner] != playerid)
		{
			SendClientMessage(playerid, -1, "Only the owner can sell this business.");
			return 1;
		}

		new refund = BusinessData[businessId][bPrice] / 2;
		Economy_Payout(playerid, refund, "biz_sell");
		BusinessData[businessId][bOwner] = INVALID_PLAYER_ID;
		BusinessData[businessId][bComponents] = 0;
		BusinessData[businessId][bEarnings] = 0;
		UpdateBusinessLabel(businessId);
		SendClientMessage(playerid, -1, "Business sold back to the market.");
		return 1;
	}

	if (!strcmp(cmd, "/buyitem", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			if (!IsPlayerNearFishingVendor(playerid))
			{
				SendClientMessage(playerid, -1, "Du bist bei keinem Geschaeft.");
				return 1;
			}
			new itemToken[16];
			GetCommandToken(cmdtext, idx, itemToken, sizeof(itemToken));
			if (itemToken[0] == '\0')
			{
				SendClientMessage(playerid, -1, "Usage: /buyitem [itemid] [count]");
				return 1;
			}
			new itemid = strval(itemToken);
			new countToken[16];
			GetCommandToken(cmdtext, idx, countToken, sizeof(countToken));
			new count = strval(countToken);
			if (count < 1)
			{
				count = 1;
			}
			if (itemid != ITEM_FISHING_ROD)
			{
				SendClientMessage(playerid, -1, "Hier gibt es nur Angeln (Item 13).");
				return 1;
			}
			BuyStoreItem(playerid, itemid, count);
			return 1;
		}

		if (BusinessData[businessId][bType] == BUSINESS_247)
		{
			new itemToken[16];
			GetCommandToken(cmdtext, idx, itemToken, sizeof(itemToken));
			if (itemToken[0] == '\0')
			{
				SendClientMessage(playerid, -1, "Usage: /buyitem [itemid] [count]");
				return 1;
			}
			new itemid = strval(itemToken);
			new countToken[16];
			GetCommandToken(cmdtext, idx, countToken, sizeof(countToken));
			new count = strval(countToken);
			if (count < 1)
			{
				count = 1;
			}
			if (!CanStoreSellItem(itemid))
			{
				SendClientMessage(playerid, -1, "Dieser Artikel wird hier nicht verkauft.");
				return 1;
			}
			if (BusinessData[businessId][bComponents] < count)
			{
				SendClientMessage(playerid, -1, "Der Laden ist gerade leer.");
				return 1;
			}
			new cost = gStorePrices[itemid] * count;
			if (GetPlayerMoney(playerid) < cost)
			{
				SendClientMessage(playerid, -1, "Du hast nicht genug Geld.");
				return 1;
			}
			if (!CanPlayerCarryItem(playerid, itemid, count))
			{
				ShowInventoryFullMessage(playerid, itemid, count);
				return 1;
			}
			GivePlayerMoneyLogged(playerid, -cost, "store_buy");
			BusinessData[businessId][bComponents] -= count;
			AddPlayerItem(playerid, itemid, count);
			new owner = BusinessData[businessId][bOwner];
			if (owner != INVALID_PLAYER_ID && IsPlayerConnected(owner))
			{
				Economy_Payout(owner, cost, "store_sale");
				BusinessData[businessId][bEarnings] += cost;
			}
			UpdateBusinessLabel(businessId);
			new itemName[MAX_ITEM_NAME];
			GetItemName(itemid, itemName, sizeof(itemName));
			new msg[96];
			format(msg, sizeof(msg), "Gekauft: %s x%d fuer $%d.", itemName, count, cost);
			SendClientMessage(playerid, -1, msg);
			return 1;
		}

		if (BusinessData[businessId][bType] == BUSINESS_AMMUNATION)
		{
			new itemToken[16];
			GetCommandToken(cmdtext, idx, itemToken, sizeof(itemToken));
			if (itemToken[0] == '\0')
			{
				SendClientMessage(playerid, -1, "Waffenliste: /buyitem 1-5 [packs]");
				SendClientMessage(playerid, -1, "1=9mm ($600/80 Schuss), 2=Shotgun ($1800/25), 3=Uzi ($3500/150)");
				SendClientMessage(playerid, -1, "4=MP5 ($4800/200), 5=M4 ($7500/220)");
				return 1;
			}
			new itemIndex = strval(itemToken) - 1;
			if (itemIndex < 0 || itemIndex >= sizeof(gAmmuWeaponIds))
			{
				SendClientMessage(playerid, -1, "Ungueltige Waffe. Nutze /buyitem 1-5 [packs].");
				return 1;
			}
			new countToken[16];
			GetCommandToken(cmdtext, idx, countToken, sizeof(countToken));
			new count = strval(countToken);
			if (count < 1)
			{
				count = 1;
			}
			if (BusinessData[businessId][bComponents] < count)
			{
				SendClientMessage(playerid, -1, "Der Laden hat nicht genug Ware.");
				return 1;
			}
			new cost = gAmmuWeaponPrices[itemIndex] * count;
			if (GetPlayerMoney(playerid) < cost)
			{
				SendClientMessage(playerid, -1, "Du hast nicht genug Geld.");
				return 1;
			}
			GivePlayerMoneyLogged(playerid, -cost, "ammu_buy");
			BusinessData[businessId][bComponents] -= count;
			GivePlayerWeapon(playerid, gAmmuWeaponIds[itemIndex], gAmmuWeaponAmmo[itemIndex] * count);
			new owner = BusinessData[businessId][bOwner];
			if (owner != INVALID_PLAYER_ID && IsPlayerConnected(owner))
			{
				new payout = cost / 2;
				Economy_Payout(owner, payout, "biz_sale");
				BusinessData[businessId][bEarnings] += payout;
			}
			new msg[96];
			format(msg, sizeof(msg), "Gekauft: %s x%d fuer $%d.", gAmmuWeaponNames[itemIndex], count, cost);
			SendClientMessage(playerid, -1, msg);
			UpdateBusinessLabel(businessId);
			return 1;
		}

		new countToken[16];
		GetCommandToken(cmdtext, idx, countToken, sizeof(countToken));
		new count = strval(countToken);
		if (count < 1)
		{
			count = 1;
		}
		new cost = BusinessData[businessId][bComponentPrice] * count;

		if (BusinessData[businessId][bComponents] < count)
		{
			SendClientMessage(playerid, -1, "This business is out of components.");
			return 1;
		}

		if (GetPlayerMoney(playerid) < cost)
		{
			SendClientMessage(playerid, -1, "You cannot afford that purchase.");
			return 1;
		}

		GivePlayerMoneyLogged(playerid, -cost, "biz_buyitem");
		BusinessData[businessId][bComponents] -= count;

		new owner = BusinessData[businessId][bOwner];
		if (owner != INVALID_PLAYER_ID && IsPlayerConnected(owner))
		{
			new payout = cost;
			if (BusinessData[businessId][bType] == BUSINESS_AMMUNATION)
			{
				payout = cost / 2;
			}
			Economy_Payout(owner, payout, "biz_sale");
			BusinessData[businessId][bEarnings] += payout;
		}

		SendClientMessage(playerid, -1, "Kauf abgeschlossen.");
		UpdateBusinessLabel(businessId);
		return 1;
	}

	if (!strcmp(cmd, "/buyrod", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (!IsPlayerNearFishingVendor(playerid) && businessId == -1)
		{
			SendClientMessage(playerid, -1, "Du musst bei einem 24/7 oder dem Angel-Verkauf sein.");
			return 1;
		}

		if (businessId != -1 && BusinessData[businessId][bType] == BUSINESS_247)
		{
			if (BusinessData[businessId][bComponents] < 1)
			{
				SendClientMessage(playerid, -1, "Der Laden ist gerade leer.");
				return 1;
			}
			if (!BuyStoreItem(playerid, ITEM_FISHING_ROD, 1))
			{
				return 1;
			}
			BusinessData[businessId][bComponents] -= 1;
			new owner = BusinessData[businessId][bOwner];
			if (owner != INVALID_PLAYER_ID && IsPlayerConnected(owner))
			{
				Economy_Payout(owner, gStorePrices[ITEM_FISHING_ROD], "store_sale");
				BusinessData[businessId][bEarnings] += gStorePrices[ITEM_FISHING_ROD];
			}
			UpdateBusinessLabel(businessId);
			return 1;
		}

		if (!IsPlayerNearFishingVendor(playerid))
		{
			SendClientMessage(playerid, -1, "Du musst bei einem 24/7 oder dem Angel-Verkauf sein.");
			return 1;
		}

		BuyStoreItem(playerid, ITEM_FISHING_ROD, 1);
		return 1;
	}

	if (!strcmp(cmd, "/buycrates", true))
	{
		if (!IsNearComponentWarehouse(playerid))
		{
			SendClientMessage(playerid, -1, "You must be at the component warehouse to buy crates.");
			return 1;
		}

		new countToken[16];
		GetCommandToken(cmdtext, idx, countToken, sizeof(countToken));
		new count = strval(countToken);
		if (count < 1)
		{
			SendClientMessage(playerid, -1, "Usage: /buycrates [count]");
			return 1;
		}

		new totalCost = count * COMPONENT_CRATE_COST;
		if (GetPlayerMoney(playerid) < totalCost)
		{
			SendClientMessage(playerid, -1, "You cannot afford that many crates.");
			return 1;
		}

		if (!CanPlayerCarryItem(playerid, ITEM_CRATE, count))
		{
			ShowInventoryFullMessage(playerid, ITEM_CRATE, count);
			return 1;
		}

		GivePlayerMoneyLogged(playerid, -totalCost, "buy_crates");
		AddPlayerItem(playerid, ITEM_CRATE, count);
		SendClientMessage(playerid, -1, "Kisten gekauft. Liefere sie mit /deliverbiz [businessId].");
		return 1;
	}

	if (!strcmp(cmd, "/deliverbiz", true))
	{
		new businessToken[16];
		GetCommandToken(cmdtext, idx, businessToken, sizeof(businessToken));
		new businessId = strval(businessToken) - 1;
		if (businessId < 0 || businessId >= MAX_BUSINESSES)
		{
			SendClientMessage(playerid, -1, "Usage: /deliverbiz [businessId]");
			return 1;
		}
		if (PlayerItems[playerid][ITEM_CRATE] < 1)
		{
			SendClientMessage(playerid, -1, "You have no crates to deliver.");
			return 1;
		}
		SetPlayerCheckpointEx(playerid, BusinessData[businessId][bX], BusinessData[businessId][bY], BusinessData[businessId][bZ], 4.0);
		PlayerData[playerid][pHasDelivery] = true;
		PlayerData[playerid][pDeliveryBiz] = businessId;
		SendClientMessage(playerid, -1, "Delivery GPS set. Drive to the checkpoint to deliver components.");
		return 1;
	}

	if (!strcmp(cmd, "/cancelbiz", true))
	{
		ClearDeliveryCheckpoint(playerid);
		SendClientMessage(playerid, -1, "Delivery route cleared.");
		return 1;
	}

	if (!strcmp(cmd, "/launder", true))
	{
		if (!IsPlayerAtChopShop(playerid))
		{
			SendClientMessage(playerid, -1, "Du musst am Chop Shop sein.");
			return 1;
		}
		new total = 0;
		for (new i = 0; i < MAX_ITEMS; i++)
		{
			if (PlayerItems[playerid][i] < 1 || !IsItemIllegal(i))
			{
				continue;
			}
			new value = GetIllegalItemValue(i);
			if (value < 1)
			{
				continue;
			}
			total += value * PlayerItems[playerid][i];
			PlayerItems[playerid][i] = 0;
		}
		if (total < 1)
		{
			SendClientMessage(playerid, -1, "Keine illegalen Gegenstaende zum Waschen.");
			return 1;
		}
		Economy_Payout(playerid, total, "launder");
		SendClientMessage(playerid, -1, "Geldwaesche abgeschlossen.");
		return 1;
	}

	if (!strcmp(cmd, "/vbreakin", true) || !strcmp(cmd, "/vbi", true))
	{
		if (PlayerData[playerid][pMiniGame] != MINIGAME_NONE)
		{
			SendClientMessage(playerid, -1, "You are already attempting a minigame.");
			return 1;
		}

		if (GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
		{
			SendClientMessage(playerid, -1, "You need to be on foot to start lockpicking.");
			return 1;
		}

		new vehicleid = GetNearestVehicle(playerid, 3.5);
		if (vehicleid == INVALID_VEHICLE_ID)
		{
			SendClientMessage(playerid, -1, "No vehicle nearby to break into.");
			return 1;
		}

		new engine, lights, alarm, doors, bonnet, boot, objective;
		GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
		if (doors == 0)
		{
			SendClientMessage(playerid, -1, "This vehicle is already unlocked.");
			return 1;
		}

		StartMiniGame(playerid, vehicleid, MINIGAME_LOCKPICK);
		SendClientMessage(playerid, -1, "Lockpicking started. Follow the on-screen prompts.");
		return 1;
	}

	if (!strcmp(cmd, "/hotwire", true))
	{
		if (PlayerData[playerid][pMiniGame] != MINIGAME_NONE)
		{
			SendClientMessage(playerid, -1, "You are already attempting a minigame.");
			return 1;
		}

		if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
		{
			SendClientMessage(playerid, -1, "You need to be in the driver's seat to hotwire.");
			return 1;
		}

		new vehicleid = GetPlayerVehicleID(playerid);
		new engine, lights, alarm, doors, bonnet, boot, objective;
		GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
		if (engine == 1)
		{
			SendClientMessage(playerid, -1, "The engine is already running.");
			return 1;
		}

		StartMiniGame(playerid, vehicleid, MINIGAME_HOTWIRE);
		SendClientMessage(playerid, -1, "Hotwiring started. Follow the on-screen prompts.");
		return 1;
	}

	if (!strcmp(cmd, "/taxistart", true))
	{
		if (gTaxiOnDuty[playerid])
		{
			SendClientMessage(playerid, -1, "You are already on duty as a taxi driver.");
			return 1;
		}
		if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
		{
			SendClientMessage(playerid, -1, "You must be driving a taxi to go on duty.");
			return 1;
		}
		if (!TaxiIsVehicleTaxi(GetPlayerVehicleID(playerid)))
		{
			SendClientMessage(playerid, -1, "You must be driving a taxi vehicle to go on duty.");
			return 1;
		}
		gTaxiOnDuty[playerid] = true;
		TaxiFare[playerid] = TAXI_DEFAULT_FARE;
		SendClientMessage(playerid, -1, "You are now on duty as a taxi driver.");
		return 1;
	}

	if (!strcmp(cmd, "/taxistop", true))
	{
		if (!gTaxiOnDuty[playerid])
		{
			SendClientMessage(playerid, -1, "You are not on duty as a taxi driver.");
			return 1;
		}
		TaxiResetRequestForDriver(playerid);
		gTaxiOnDuty[playerid] = false;
		TaxiStopMeter(playerid);
		SendClientMessage(playerid, -1, "You are now off duty.");
		return 1;
	}

	if (!strcmp(cmd, "/taxi", true))
	{
		if (gTaxiRequesting[playerid])
		{
			SendClientMessage(playerid, -1, "You already have a pending taxi request.");
			return 1;
		}
		if (TaxiCustomerForDriver[playerid] != INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "You cannot request a taxi while on a job.");
			return 1;
		}
		gTaxiRequesting[playerid] = true;
		TaxiDriverForCustomer[playerid] = INVALID_PLAYER_ID;

		new name[MAX_PLAYER_NAME];
		new message[96];
		GetPlayerName(playerid, name, sizeof(name));
		format(message, sizeof(message), "Taxi request from %s. Use /taxiaccept to take the call.", name);
		TaxiSendToOnDuty(message);
		SendClientMessage(playerid, -1, "Taxi request sent. Please wait for a driver to accept.");
		return 1;
	}

	if (!strcmp(cmd, "/taxiaccept", true))
	{
		if (!gTaxiOnDuty[playerid])
		{
			SendClientMessage(playerid, -1, "You must be on duty to accept taxi requests.");
			return 1;
		}
		if (TaxiCustomerForDriver[playerid] != INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "You already accepted a taxi request.");
			return 1;
		}

		new customerid = INVALID_PLAYER_ID;
		for (new i = 0; i < MAX_PLAYERS; i++)
		{
			if (IsPlayerConnected(i) && gTaxiRequesting[i] && TaxiDriverForCustomer[i] == INVALID_PLAYER_ID)
			{
				customerid = i;
				break;
			}
		}

		if (customerid == INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "There are no pending taxi requests.");
			return 1;
		}

		TaxiDriverForCustomer[customerid] = playerid;
		TaxiCustomerForDriver[playerid] = customerid;

		new name[MAX_PLAYER_NAME];
		new message[96];
		GetPlayerName(playerid, name, sizeof(name));
		format(message, sizeof(message), "Taxi request accepted by %s.", name);
		SendClientMessage(customerid, -1, message);
		SendClientMessage(playerid, -1, "Taxi request accepted. Contact the customer and proceed.");
		new Float:x, Float:y, Float:z;
		GetPlayerPos(customerid, x, y, z);
		SetPlayerCheckpointEx(playerid, x, y, z, 4.0);
		return 1;
	}

	if (!strcmp(cmd, "/taxicancel", true))
	{
		if (gTaxiRequesting[playerid])
		{
			new driverid = TaxiDriverForCustomer[playerid];
			TaxiResetRequestForCustomer(playerid);
			SendClientMessage(playerid, -1, "Taxi request cancelled.");
			if (driverid != INVALID_PLAYER_ID)
			{
				SendClientMessage(driverid, -1, "Customer cancelled the taxi request.");
			}
			return 1;
		}

		if (TaxiCustomerForDriver[playerid] != INVALID_PLAYER_ID)
		{
			new customerid = TaxiCustomerForDriver[playerid];
			TaxiResetRequestForDriver(playerid);
			SendClientMessage(playerid, -1, "You cancelled the accepted taxi request.");
			if (customerid != INVALID_PLAYER_ID)
			{
				SendClientMessage(customerid, -1, "The taxi driver cancelled your request.");
			}
			TaxiStopMeter(playerid);
			return 1;
		}

		SendClientMessage(playerid, -1, "You have no taxi request to cancel.");
		return 1;
	}

	if (!strcmp(cmd, "/taxidone", true))
	{
		if (TaxiCustomerForDriver[playerid] == INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "You have no active taxi request.");
			return 1;
		}

		new customerid = TaxiCustomerForDriver[playerid];
		TaxiResetRequestForDriver(playerid);
		SendClientMessage(playerid, -1, "Taxi request completed.");
		SendClientMessage(customerid, -1, "Taxi ride completed. Please roleplay the payment.");
		TaxiStopMeter(playerid);
		Activity_Mark(playerid, ACTIVITY_TAXI);
		return 1;
	}

	if (!strcmp(cmd, "/fare", true))
	{
		if (!gTaxiOnDuty[playerid])
		{
			SendClientMessage(playerid, -1, "You must be on duty to set a fare.");
			return 1;
		}

		new amountArg[64];
		amountArg = strtok(cmdtext, idx);
		if (!strlen(amountArg))
		{
			SendClientMessage(playerid, -1, "Usage: /fare [amount]");
			return 1;
		}

		new amount = strval(amountArg);
		if (amount < TAXI_MIN_FARE || amount > TAXI_MAX_FARE)
		{
			SendClientMessage(playerid, -1, "Fare must be between $1 and $100.");
			return 1;
		}

		TaxiFare[playerid] = amount;
		new message[64];
		format(message, sizeof(message), "Taxi fare set to $%d.", amount);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/taximeter", true))
	{
		if (!gTaxiOnDuty[playerid])
		{
			SendClientMessage(playerid, -1, "You must be on duty to use the taxi meter.");
			return 1;
		}
		if (TaxiCustomerForDriver[playerid] == INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "You must have an active request to use the taxi meter.");
			return 1;
		}
		if (TaxiMeterActive[playerid])
		{
			TaxiStopMeter(playerid);
		}
		else
		{
			TaxiStartMeter(playerid);
		}
		return 1;
	}

	if (!strcmp(cmd, "/taxirent", true))
	{
		new minutes_left = TaxiMinutesRemaining(playerid);
		if (minutes_left == 0)
		{
			if (!ChargePlayer(playerid, TAXI_RENTAL_COST))
			{
				return 1;
			}
			TaxiRentalEndTick[playerid] = GetTickCount() + (TAXI_RENTAL_MINUTES * 60000);
			TaxiRentalNotifiedFive[playerid] = false;
			TaxiRentalNotifiedOne[playerid] = false;
			if (TaxiRentalVehicle[playerid] == INVALID_VEHICLE_ID)
			{
				new Float:x, Float:y, Float:z, Float:a;
				GetPlayerPos(playerid, x, y, z);
				GetPlayerFacingAngle(playerid, a);
				TaxiRentalVehicle[playerid] = CreateVehicle(420, x + 2.0, y, z, a, -1, -1, 0);
				InitVehiclePlate(TaxiRentalVehicle[playerid]);
				PutPlayerInVehicle(playerid, TaxiRentalVehicle[playerid], 0);
			}
			new message[64];
			format(message, sizeof(message), "Taxi rented for %d minutes. Cost: $%d.", TAXI_RENTAL_MINUTES, TAXI_RENTAL_COST);
			SendClientMessage(playerid, -1, message);
			return 1;
		}

		if (minutes_left > TAXI_RENTAL_REMINDER_FIVE)
		{
			SendClientMessage(playerid, -1, "You can only extend rental time when 5 minutes or less remain.");
			return 1;
		}

		if (!ChargePlayer(playerid, TAXI_RENTAL_COST))
		{
			return 1;
		}
		TaxiRentalEndTick[playerid] += TAXI_RENTAL_EXTEND_MINUTES * 60000;
		TaxiRentalNotifiedFive[playerid] = false;
		TaxiRentalNotifiedOne[playerid] = false;
		new message[64];
		format(message, sizeof(message), "Taxi rental extended by %d minutes. Cost: $%d.", TAXI_RENTAL_EXTEND_MINUTES, TAXI_RENTAL_COST);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/stoptaxirent", true))
	{
		if (TaxiRentalEndTick[playerid] == 0)
		{
			SendClientMessage(playerid, -1, "You are not renting a taxi.");
			return 1;
		}

		TaxiRentalEndTick[playerid] = 0;
		TaxiRentalNotifiedFive[playerid] = false;
		TaxiRentalNotifiedOne[playerid] = false;
		SendClientMessage(playerid, -1, "Taxi rental stopped. Return the taxi to avoid towing fees.");
		new message[96];
		format(message, sizeof(message), "Potential fees: $%d towing, $%d damage (if applicable).", TAXI_TOW_FEE, TAXI_DAMAGE_FEE);
		SendClientMessage(playerid, -1, message);
		if (TaxiRentalVehicle[playerid] != INVALID_VEHICLE_ID)
		{
			DestroyVehicle(TaxiRentalVehicle[playerid]);
			TaxiRentalVehicle[playerid] = INVALID_VEHICLE_ID;
		}
		return 1;
	}

	if (!strcmp(cmd, "/pet", true))
	{
		new action[64];
		action = strtok(cmdtext, idx);

		if (!strlen(action))
		{
			SendClientMessage(playerid, -1, "Usage: /pet spawn <dog1|dog2|dog3|dog4|dog5|cat>");
			SendClientMessage(playerid, -1, "Tasks: /pet follow | come | stay | wander | sit | bark | dismiss");
			return 1;
		}

		if (!strcmp(action, "spawn", true))
		{
			new petName[64];
			petName = strtok(cmdtext, idx);
			if (!strlen(petName))
			{
				SendClientMessage(playerid, -1, "Usage: /pet spawn <dog1|dog2|dog3|dog4|dog5|cat>");
				return 1;
			}

			new petIndex = GetPetIndex(petName);
			if (petIndex == -1)
			{
				SendClientMessage(playerid, -1, "Unknown pet type. Try dog1-5 or cat.");
				return 1;
			}

			if (!CreatePet(playerid, petIndex))
			{
				SendClientMessage(playerid, -1, "Failed to spawn pet.");
				return 1;
			}

			SendClientMessage(playerid, -1, "Your pet is ready. Use /pet follow to make it follow you.");
			return 1;
		}

		if (!PetExists(playerid))
		{
			SendClientMessage(playerid, -1, "You don't have a pet yet. Use /pet spawn <type>.");
			return 1;
		}

		if (!strcmp(action, "follow", true))
		{
			SetPetTask(playerid, PET_TASK_FOLLOW);
			SendClientMessage(playerid, -1, "Your pet will follow you.");
			return 1;
		}

		if (!strcmp(action, "come", true))
		{
			new Float:x, Float:y, Float:z;
			GetPlayerPos(playerid, x, y, z);
			SetActorPos(PlayerData[playerid][pPetActor], x + 1.0, y, z);
			SetPetTask(playerid, PET_TASK_STAY);
			SendClientMessage(playerid, -1, "Your pet comes to you.");
			return 1;
		}

		if (!strcmp(action, "stay", true))
		{
			SetPetTask(playerid, PET_TASK_STAY);
			SendClientMessage(playerid, -1, "Your pet will stay here.");
			return 1;
		}

		if (!strcmp(action, "wander", true))
		{
			SetPetTask(playerid, PET_TASK_WANDER);
			SendClientMessage(playerid, -1, "Your pet will wander nearby.");
			return 1;
		}

		if (!strcmp(action, "sit", true))
		{
			ApplyPetAnimation(playerid, "PED", "SEAT_idle", 4.1, 1, 0, 0, 0, 0);
			SendClientMessage(playerid, -1, "Your pet sits down.");
			return 1;
		}

		if (!strcmp(action, "bark", true))
		{
			ApplyPetAnimation(playerid, "PED", "IDLE_chat", 4.1, 0, 0, 0, 0, 0);
			SendClientMessage(playerid, -1, "Your pet barks.");
			return 1;
		}

		if (!strcmp(action, "dismiss", true))
		{
			DestroyPet(playerid);
			SendClientMessage(playerid, -1, "Your pet has been dismissed.");
			return 1;
		}

		SendClientMessage(playerid, -1, "Unknown pet command. Use /pet for help.");
		return 1;
	}

	if (!strcmp(cmd, "/drug", true))
	{
		new drug[64];
		drug = strtok(cmdtext, idx);
		if (!strlen(drug))
		{
			SendClientMessage(playerid, -1, "Usage: /drug [marijuana|cocaine|heroin]");
			return 1;
		}

		if (!strcmp(drug, "marijuana", true))
		{
			UseMarijuana(playerid);
			SendClientMessage(playerid, -1, "You smoke marijuana and feel a light buzz.");
			return 1;
		}
		if (!strcmp(drug, "cocaine", true))
		{
			UseCocaine(playerid);
			SendClientMessage(playerid, -1, "You take cocaine and feel a strong rush.");
			return 1;
		}
		if (!strcmp(drug, "heroin", true))
		{
			UseHeroin(playerid);
			SendClientMessage(playerid, -1, "You take heroin and feel a heavy effect.");
			return 1;
		}

		SendClientMessage(playerid, -1, "Unknown drug. Use marijuana, cocaine, or heroin.");
		return 1;
	}

	if (!strcmp(cmd, "/methadone", true))
	{
		UseMethadone(playerid);
		SendClientMessage(playerid, -1, "You take methadone and your addiction eases.");
		return 1;
	}

	if (!strcmp(cmd, "/addiction", true))
	{
		new message[64];
		format(message, sizeof(message), "Addiction: %d | Inventar: %d/%dkg", PlayerData[playerid][pAddiction], GetPlayerInventoryWeight(playerid), PlayerData[playerid][pCarryLimit]);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	return 0;
}

public bool:HandleLspdCommand(playerid, const cmd[], const params[])
{
	if (!strcmp(cmd, "pduty", true))
	{
		SetPlayerHealth(playerid, 100.0);
		SetPlayerArmour(playerid, 100.0);
		SetPlayerColor(playerid, 0x3399FFFF);
		gLspdDuty[playerid] = true;
		SendClientMessage(playerid, -1, "LSPD duty loadout applied.");
		return true;
	}

	if (!strcmp(cmd, "poff", true) || !strcmp(cmd, "pdutyoff", true))
	{
		gLspdDuty[playerid] = false;
		SetPlayerColor(playerid, 0xFFFFFFFF);
		SendClientMessage(playerid, -1, "LSPD duty ended.");
		return true;
	}

	if (!strcmp(cmd, "equipment", true))
	{
		if (!gLspdDuty[playerid])
		{
			SendClientMessage(playerid, -1, "You must be on duty to take equipment.");
			return true;
		}
		if (HasCommandPrefix(params, "swat"))
		{
			SetPlayerHealth(playerid, 100.0);
			SetPlayerArmour(playerid, 100.0);
			GivePlayerWeapon(playerid, 24, 150);
			GivePlayerWeapon(playerid, 31, 300);
			SetPlayerColor(playerid, 0x3399FFFF);
			SendClientMessage(playerid, -1, "LSPD SWAT equipment issued.");
			return true;
		}

		if (HasCommandPrefix(params, "db"))
		{
			SetPlayerHealth(playerid, 100.0);
			GivePlayerWeapon(playerid, 22, 120);
			SendClientMessage(playerid, -1, "LSPD DB equipment issued.");
			return true;
		}

		SetPlayerHealth(playerid, 100.0);
		SetPlayerArmour(playerid, 100.0);
		GivePlayerWeapon(playerid, 23, 150);
		GivePlayerWeapon(playerid, 22, 120);
		SetPlayerColor(playerid, 0x3399FFFF);
		SendClientMessage(playerid, -1, "LSPD equipment issued.");
		return true;
	}

	if (!strcmp(cmd, "search", true))
	{
		if (!gLspdDuty[playerid])
		{
			SendClientMessage(playerid, -1, "You must be on duty to search.");
			return true;
		}
		new targetId = GetTargetPlayerId(params);
		if (targetId == INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "Usage: /search <player>");
			return true;
		}
		if (GetPlayerDistanceFromPlayer(playerid, targetId) > 4.0)
		{
			SendClientMessage(playerid, -1, "Target is too far away.");
			return true;
		}
		new list[256];
		new found = Law_BuildIllegalListPlayer(targetId, list, sizeof(list));
		if (found == 0)
		{
			SendClientMessage(playerid, -1, "No illegal items found.");
			LogLawEvent("search_clear", playerid, targetId);
		}
		else
		{
			ShowPlayerDialog(playerid, 2100, DIALOG_STYLE_MSGBOX, "Illegale Gegenstaende", list, "OK", "");
			LogLawEvent("search_hit", playerid, targetId, list);
		}
		return true;
	}

	if (!strcmp(cmd, "searchveh", true))
	{
		if (!gLspdDuty[playerid])
		{
			SendClientMessage(playerid, -1, "You must be on duty to search vehicles.");
			return true;
		}
		new targetId = GetTargetPlayerId(params);
		if (targetId == INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "Usage: /searchveh <player>");
			return true;
		}
		new vehicleid = GetPlayerVehicleID(targetId);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "Target is not in a vehicle.");
			return true;
		}
		new list[256];
		new found = Law_BuildIllegalListVehicle(vehicleid, list, sizeof(list));
		if (found == 0)
		{
			SendClientMessage(playerid, -1, "No illegal items found in the vehicle.");
			LogLawEvent("searchveh_clear", playerid, targetId);
		}
		else
		{
			ShowPlayerDialog(playerid, 2101, DIALOG_STYLE_MSGBOX, "Illegale Fahrzeugladung", list, "OK", "");
			LogLawEvent("searchveh_hit", playerid, targetId, list);
		}
		return true;
	}

	if (!strcmp(cmd, "take", true))
	{
		new weapon_id = strval(params);
		switch (weapon_id)
		{
			case 1: GivePlayerWeapon(playerid, 31, 200);
			case 2: GivePlayerWeapon(playerid, 25, 40);
			case 3: GivePlayerWeapon(playerid, 34, 20);
			default:
			{
				SendClientMessage(playerid, -1, "Usage: /take [1=AR, 2=Shotgun, 3=Sniper]");
				return true;
			}
		}

		SendClientMessage(playerid, -1, "Weapon taken from cruiser.");
		return true;
	}

	if (!strcmp(cmd, "takespike", true))
	{
		SendClientMessage(playerid, -1, "You retrieve a spike strip from the cruiser.");
		return true;
	}

	if (!strcmp(cmd, "spike", true))
	{
		SendClientMessage(playerid, -1, "Spike strip placed.");
		return true;
	}

	if (!strcmp(cmd, "removespike", true))
	{
		SendClientMessage(playerid, -1, "Spike strip picked up.");
		return true;
	}

	if (!strcmp(cmd, "placespike", true))
	{
		SendClientMessage(playerid, -1, "Spike strip returned to the cruiser.");
		return true;
	}

	if (!strcmp(cmd, "uniform", true))
	{
		SendClientMessage(playerid, -1, "Uniform customization is not implemented yet.");
		return true;
	}

	if (!strcmp(cmd, "r", true) || !strcmp(cmd, "radio", true))
	{
		if (!strlen(params))
		{
			SendClientMessage(playerid, -1, "Usage: /r [message]");
			return true;
		}
		SendClientMessage(playerid, 0x33CCFFFF, params);
		return true;
	}

	if (!strcmp(cmd, "dep", true) || !strcmp(cmd, "department", true))
	{
		if (!strlen(params))
		{
			SendClientMessage(playerid, -1, "Usage: /dep [message]");
			return true;
		}
		SendClientMessage(playerid, 0x66FFCCFF, params);
		return true;
	}

	if (!strcmp(cmd, "m", true) || !strcmp(cmd, "megaphone", true))
	{
		if (!strlen(params))
		{
			SendClientMessage(playerid, -1, "Usage: /m [message]");
			return true;
		}
		SendClientMessage(playerid, 0xFFFF99FF, params);
		return true;
	}

	if (!strcmp(cmd, "arrest", true))
	{
		SendClientMessage(playerid, -1, "Arrest command acknowledged.");
		return true;
	}

	if (!strcmp(cmd, "cuff", true))
	{
		SendClientMessage(playerid, -1, "Suspect cuffed.");
		return true;
	}

	if (!strcmp(cmd, "uncuff", true))
	{
		SendClientMessage(playerid, -1, "Suspect uncuffed.");
		return true;
	}

	if (!strcmp(cmd, "panic", true))
	{
		SendClientMessage(playerid, 0xFF4444FF, "PANIC BUTTON ACTIVATED!");
		return true;
	}

	if (!strcmp(cmd, "mdc", true))
	{
		SendClientMessage(playerid, -1, "MDC terminal not implemented yet.");
		return true;
	}

	if (!strcmp(cmd, "radar", true))
	{
		new dist;
		new speed;
		if (!ParseTwoInts(params, dist, speed))
		{
			SendClientMessage(playerid, -1, "Usage: /radar [distance] [speed]");
			return true;
		}
		SendClientMessage(playerid, -1, "Speed radar enabled.");
		return true;
	}

	if (!strcmp(cmd, "radaroff", true))
	{
		SendClientMessage(playerid, -1, "Speed radar disabled.");
		return true;
	}

	if (!strcmp(cmd, "setpatrol", true))
	{
		SendClientMessage(playerid, -1, "Vehicle patrol label set.");
		return true;
	}

	if (!strcmp(cmd, "fine", true))
	{
		SendClientMessage(playerid, -1, "Fine issued.");
		return true;
	}

	if (!strcmp(cmd, "vfine", true))
	{
		SendClientMessage(playerid, -1, "Vehicle fine issued.");
		return true;
	}

	if (!strcmp(cmd, "checkfines", true))
	{
		SendClientMessage(playerid, -1, "No active fines found.");
		return true;
	}

	if (!strcmp(cmd, "checkvehiclefines", true))
	{
		SendClientMessage(playerid, -1, "No active vehicle fines found.");
		return true;
	}

	return false;
}
