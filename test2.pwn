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

#define PASSWORD_LEN 64

#define PREVIEW_X 1958.3783
#define PREVIEW_Y 1343.1572
#define PREVIEW_Z 15.3746
#define PREVIEW_A 270.0
#define MAX_PLATE_LEN 32
#define MAX_STOLEN_PLATES 256
#define ALPR_SCAN_INTERVAL 4000
#define ALPR_RANGE 20.0

#define MAX_ITEMS 12
#define MAX_DROPS 100
#define MAX_ITEM_NAME 24

#define CINEMA_SCREEN_MODEL 18880
#define CINEMA_SEAT_MODEL_1 1723
#define CINEMA_SEAT_MODEL_2 1724
#define CINEMA_SEAT_MODEL_3 1671

#define CINEMA_POINT_X  1115.0
#define CINEMA_POINT_Y  -1450.0
#define CINEMA_POINT_Z  15.0

#define CINEMA_RADIUS 3.0

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
	pSkin,
	pSelectedItem,
	pSelectedAction,
	Float:pX,
	Float:pY,
	Float:pZ,
	Float:pA,
	pInterior,
	pWorld,
	pPassHash[PASSWORD_LEN + 1]
};
new PlayerData[MAX_PLAYERS][pInfo];

new MySQL:g_SQL;
new bool:gAlprEnabled[MAX_PLAYERS];
new gAlprTimer[MAX_PLAYERS];
new bool:gHasLicense[MAX_PLAYERS];
new bool:gTaxDue[MAX_PLAYERS];
new gStolenPlateCount;
new gStolenPlates[MAX_STOLEN_PLATES][MAX_PLATE_LEN];

forward OnAccountCheck(playerid);
forward AlprScan(playerid);

enum itemInfo
{
	itemName[MAX_ITEM_NAME],
	bool:itemConsumable
};

new const gItems[MAX_ITEMS][itemInfo] =
{
	{"Water Bottle", true},
	{"Sandwich", true},
	{"Bandage", true},
	{"Medkit", true},
	{"Phone", false},
	{"Radio", false},
	{"Flashlight", false},
	{"Repair Kit", false},
	{"Lockpick", false},
	{"Notebook", false},
	{"Pistol Ammo", false},
	{"Rope", false}
};

new PlayerItems[MAX_PLAYERS][MAX_ITEMS];
new VehicleItems[MAX_VEHICLES][MAX_ITEMS];

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
	ACTION_VEH_TAKE
};

stock GetItemName(itemid, name[], size = MAX_ITEM_NAME)
{
	if (itemid < 0 || itemid >= MAX_ITEMS)
	{
		format(name, size, "Unknown");
		return 0;
	}
	format(name, size, "%s", gItems[itemid][itemName]);
	return 1;
}

stock IsValidItem(itemid)
{
	return (itemid >= 0 && itemid < MAX_ITEMS);
}

stock AddPlayerItem(playerid, itemid, amount)
{
	if (!IsValidItem(itemid) || amount < 1)
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
		format(message, sizeof(message), "  [%d] %s x%d", i, itemName, PlayerItems[playerid][i]);
		SendClientMessage(targetid, -1, message);
	}
	if (!hasItems)
	{
		SendClientMessage(targetid, -1, "  (no items)");
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
		format(message, sizeof(message), "  [%d] %s x%d", i, itemName, VehicleItems[vehicleid][i]);
		SendClientMessage(playerid, -1, message);
	}
	if (!hasItems)
	{
		SendClientMessage(playerid, -1, "  (empty)");
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
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (PlayerItems[playerid][i] < 1)
		{
			continue;
		}
		hasItems = 1;
		GetItemName(i, itemName, sizeof(itemName));
		new line[64];
		format(line, sizeof(line), "%s x%d\n", itemName, PlayerItems[playerid][i]);
		strcat(list, line);
	}
	if (!hasItems)
	{
		strcat(list, "(no items)\n");
	}
	ShowPlayerDialog(playerid, DIALOG_INVENTORY, DIALOG_STYLE_LIST, "Inventory", list, "Select", "Close");
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
		format(line, sizeof(line), "%s x%d\n", itemName, VehicleItems[vehicleid][i]);
		strcat(list, line);
	}
	if (!hasItems)
	{
		strcat(list, "(empty)\n");
	}
	ShowPlayerDialog(playerid, DIALOG_VEHICLE_ITEMS, DIALOG_STYLE_LIST, "Vehicle Inventory", list, "Take", "Close");
	return 1;
}

stock ResetPlayerData(playerid)
{
	PlayerData[playerid][pLogged] = false;
	PlayerData[playerid][pRegistering] = false;
	PlayerData[playerid][pSkin] = 0;
	PlayerData[playerid][pSelectedItem] = -1;
	PlayerData[playerid][pSelectedAction] = ACTION_NONE;
	PlayerData[playerid][pX] = PREVIEW_X;
	PlayerData[playerid][pY] = PREVIEW_Y;
	PlayerData[playerid][pZ] = PREVIEW_Z;
	PlayerData[playerid][pA] = PREVIEW_A;
	PlayerData[playerid][pInterior] = 0;
	PlayerData[playerid][pWorld] = 0;
	PlayerData[playerid][pPassHash][0] = '\0';
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		PlayerItems[playerid][i] = 0;
	}
	gAlprEnabled[playerid] = false;
	gHasLicense[playerid] = true;
	gTaxDue[playerid] = false;
	if (gAlprTimer[playerid] != 0)
	{
		KillTimer(gAlprTimer[playerid]);
		gAlprTimer[playerid] = 0;
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

stock IsPlateStolen(const plate[])
{
	for (new i = 0; i < gStolenPlateCount; i++)
	{
		if (!strcmp(gStolenPlates[i], plate, false))
		{
			return 1;
		}
	}
	return 0;
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
		return 1;
	}

	format(gStolenPlates[gStolenPlateCount], MAX_PLATE_LEN, "%s", plate);
	gStolenPlateCount++;
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
			return 1;
		}
	}
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

stock RegisterPlayer(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));

	new query[256];
	mysql_format(g_SQL, query, sizeof(query),
		"INSERT INTO `accounts` (`name`,`password`,`skin`,`x`,`y`,`z`,`a`,`interior`,`world`) VALUES ('%e','%e',%d,%.4f,%.4f,%.4f,%.4f,%d,%d)",
		name,
		PlayerData[playerid][pPassHash],
		PlayerData[playerid][pSkin],
		PREVIEW_X, PREVIEW_Y, PREVIEW_Z, PREVIEW_A,
		0, 0
	);
	mysql_tquery(g_SQL, query);
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

	new query[256];
	mysql_format(g_SQL, query, sizeof(query),
		"UPDATE `accounts` SET `skin`=%d, `x`=%.4f, `y`=%.4f, `z`=%.4f, `a`=%.4f, `interior`=%d, `world`=%d WHERE `name`='%e' LIMIT 1",
		skin, x, y, z, a, interior, world, name
	);
	mysql_tquery(g_SQL, query);
	return 1;
}

main()
{
	print("Account system loaded.");
}

public OnGameModeInit()
{
	SetGameModeText("MySQL Accounts");
	UsePlayerPedAnims();
	for (new i = 0; i < MAX_DROPS; i++)
	{
		Drops[i][dropActive] = false;
		Drops[i][dropPickupId] = -1;
	}
	gStolenPlateCount = 0;

	for (new i = 0; i < sizeof(gSkinList); i++)
	{
		AddPlayerClass(gSkinList[i], PREVIEW_X, PREVIEW_Y, PREVIEW_Z, PREVIEW_A, 0, 0, 0, 0, 0, 0);
	}

	new MySQLOpt:options = mysql_init_options();
	mysql_set_option(options, SERVER_PORT, MYSQL_PORT);
	g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB, options);
	if (g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
	{
		print("[MySQL] Connection failed.");
	}
	else
	{
		print("[MySQL] Connection successful.");
		mysql_tquery(g_SQL,
			"CREATE TABLE IF NOT EXISTS `accounts` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`name` VARCHAR(24) NOT NULL,`password` CHAR(64) NOT NULL,`skin` INT NOT NULL DEFAULT 0,`x` FLOAT NOT NULL DEFAULT 1958.3783,`y` FLOAT NOT NULL DEFAULT 1343.1572,`z` FLOAT NOT NULL DEFAULT 15.3746,`a` FLOAT NOT NULL DEFAULT 270.0,`interior` INT NOT NULL DEFAULT 0,`world` INT NOT NULL DEFAULT 0,PRIMARY KEY (`id`),UNIQUE KEY `name` (`name`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
		);
	}

	InitCinemaObjects();
	SetupCinemaInterior();
	return 1;
}

public OnGameModeExit()
{
	if (g_SQL != MYSQL_INVALID_HANDLE)
	{
		mysql_close(g_SQL);
	}
	CleanupCinemaInterior();
	return 1;
}

public OnPlayerConnect(playerid)
{
	ResetPlayerData(playerid);
	TogglePlayerSpectating(playerid, true);

	if (g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
	{
		SendClientMessage(playerid, -1, "Database offline. Try again later.");
		Kick(playerid);
		return 1;
	}

	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));

	new query[256];
	mysql_format(g_SQL, query, sizeof(query),
		"SELECT `password`,`skin`,`x`,`y`,`z`,`a`,`interior`,`world` FROM `accounts` WHERE `name`='%e' LIMIT 1",
		name
	);
	mysql_tquery(g_SQL, query, "OnAccountCheck", "i", playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	if (PlayerData[playerid][pLogged])
	{
		SavePlayerPosition(playerid);
	}
	gCinemaWatching[playerid] = false;
	ResetPlayerData(playerid);
	return 1;
}

public OnPlayerSpawn(playerid)
{
	AddPlayerItem(playerid, 0, 2);
	AddPlayerItem(playerid, 1, 1);
	AddPlayerItem(playerid, 4, 1);
	SendClientMessage(playerid, -1, "Use /inv (or /inventory) to view items. Press Y to pick up drops.");
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if (newkeys & KEY_YES)
	{
		new dropid = GetNearestActiveDrop(playerid);
		if (dropid != -1)
		{
			new itemName[MAX_ITEM_NAME];
			GetItemName(Drops[dropid][dropItemId], itemName, sizeof(itemName));
			AddPlayerItem(playerid, Drops[dropid][dropItemId], Drops[dropid][dropAmount]);
			new message[96];
			format(message, sizeof(message), "You picked up %s x%d.", itemName, Drops[dropid][dropAmount]);
			SendClientMessage(playerid, -1, message);
			ClearDrop(dropid);
		}
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
		RegisterPlayer(playerid);
	}
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if (dialogid == DIALOG_LOGIN)
	{
		if (!response)
		{
			Kick(playerid);
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
			PlayerData[playerid][pLogged] = true;
			TogglePlayerSpectating(playerid, false);

			SetPlayerInterior(playerid, PlayerData[playerid][pInterior]);
			SetPlayerVirtualWorld(playerid, PlayerData[playerid][pWorld]);
			SetSpawnInfo(playerid, 0, PlayerData[playerid][pSkin],
				PlayerData[playerid][pX], PlayerData[playerid][pY], PlayerData[playerid][pZ],
				PlayerData[playerid][pA], 0, 0, 0, 0, 0, 0);
			SpawnPlayer(playerid);
		}
		else
		{
			ShowLoginDialog(playerid, "Wrong password.\n\nEnter your password:");
		}
		return 1;
	}

	if (dialogid == DIALOG_REGISTER)
	{
		if (!response)
		{
			Kick(playerid);
			return 1;
		}

		if (strlen(inputtext) < 4)
		{
			ShowRegisterDialog(playerid, "Password must be at least 4 characters.\n\nCreate a password:");
			return 1;
		}

		new name[MAX_PLAYER_NAME];
		GetPlayerName(playerid, name, sizeof(name));

		SHA256_PassHash(inputtext, name, PlayerData[playerid][pPassHash], PASSWORD_LEN + 1);
		PlayerData[playerid][pRegistering] = true;

		TogglePlayerSpectating(playerid, false);
		ForceClassSelection(playerid);
		SetupPreviewCamera(playerid);
		SendClientMessage(playerid, -1, "Choose a skin and press Spawn to finish registration.");
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
			format(options, sizeof(options), "Use\nDrop\nGive\nDelete");
		}
		else
		{
			format(options, sizeof(options), "Drop\nGive\nDelete");
		}
		ShowPlayerDialog(playerid, DIALOG_ITEM_ACTIONS, DIALOG_STYLE_LIST, "Item Actions", options, "Select", "Back");
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

		new action = ACTION_NONE;
		if (gItems[itemid][itemConsumable])
		{
			if (listitem == 0) action = ACTION_USE;
			else if (listitem == 1) action = ACTION_DROP;
			else if (listitem == 2) action = ACTION_GIVE;
			else if (listitem == 3) action = ACTION_DELETE;
		}
		else
		{
			if (listitem == 0) action = ACTION_DROP;
			else if (listitem == 1) action = ACTION_GIVE;
			else if (listitem == 2) action = ACTION_DELETE;
		}

		PlayerData[playerid][pSelectedAction] = action;
		if (action == ACTION_USE)
		{
			if (!RemovePlayerItem(playerid, itemid, 1))
			{
				SendClientMessage(playerid, -1, "You do not have that item.");
				return 1;
			}
			new itemName[MAX_ITEM_NAME];
			GetItemName(itemid, itemName, sizeof(itemName));
			new message[96];
			format(message, sizeof(message), "You used %s.", itemName);
			SendClientMessage(playerid, -1, message);
			return 1;
		}

		if (action == ACTION_GIVE)
		{
			ShowPlayerDialog(playerid, DIALOG_ITEM_GIVE, DIALOG_STYLE_INPUT, "Give Item", "Enter <player> <amount>:", "Give", "Cancel");
			return 1;
		}

		if (action == ACTION_DROP || action == ACTION_DELETE)
		{
			ShowPlayerDialog(playerid, DIALOG_ITEM_AMOUNT, DIALOG_STYLE_INPUT, "Item Amount", "Enter amount:", "OK", "Cancel");
			return 1;
		}
	}

	if (dialogid == DIALOG_ITEM_AMOUNT)
	{
		if (!response)
		{
			return 1;
		}
		new amount = strval(inputtext);
		new itemid = PlayerData[playerid][pSelectedItem];
		new action = PlayerData[playerid][pSelectedAction];
		if (!IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Invalid amount.");
			return 1;
		}

		if (action == ACTION_DROP)
		{
			if (!RemovePlayerItem(playerid, itemid, amount))
			{
				SendClientMessage(playerid, -1, "You do not have enough of that item.");
				return 1;
			}

			new dropid = CreateDrop(playerid, itemid, amount);
			if (dropid == -1)
			{
				AddPlayerItem(playerid, itemid, amount);
				SendClientMessage(playerid, -1, "No space to drop items right now.");
				return 1;
			}
			new itemName[MAX_ITEM_NAME];
			GetItemName(itemid, itemName, sizeof(itemName));
			new message[96];
			format(message, sizeof(message), "Dropped %s x%d. Press Y to pick up.", itemName, amount);
			SendClientMessage(playerid, -1, message);
			return 1;
		}

		if (action == ACTION_DELETE)
		{
			if (!RemovePlayerItem(playerid, itemid, amount))
			{
				SendClientMessage(playerid, -1, "You do not have enough of that item.");
				return 1;
			}
			new itemName[MAX_ITEM_NAME];
			GetItemName(itemid, itemName, sizeof(itemName));
			new message[96];
			format(message, sizeof(message), "Deleted %s x%d.", itemName, amount);
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
			SendClientMessage(playerid, -1, "Usage: <player> <amount>");
			return 1;
		}

		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "You do not have enough of that item.");
			return 1;
		}

		AddPlayerItem(targetid, itemid, amount);
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "You gave %s x%d.", itemName, amount);
		SendClientMessage(playerid, -1, message);

		format(message, sizeof(message), "You received %s x%d.", itemName, amount);
		SendClientMessage(targetid, -1, message);
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
			SendClientMessage(playerid, -1, "You are not in a vehicle.");
			return 1;
		}
		new itemid = GetVehicleItemIdFromList(vehicleid, listitem);
		if (!IsValidItem(itemid))
		{
			return 1;
		}
		PlayerData[playerid][pSelectedItem] = itemid;
		PlayerData[playerid][pSelectedAction] = ACTION_VEH_TAKE;
		ShowPlayerDialog(playerid, DIALOG_VEHICLE_AMOUNT, DIALOG_STYLE_INPUT, "Take Item", "Enter amount:", "Take", "Cancel");
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
			SendClientMessage(playerid, -1, "You are not in a vehicle.");
			return 1;
		}
		new amount = strval(inputtext);
		new itemid = PlayerData[playerid][pSelectedItem];
		if (!IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Invalid amount.");
			return 1;
		}
		if (!RemoveVehicleItem(vehicleid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "That item is not available in the vehicle.");
			return 1;
		}
		AddPlayerItem(playerid, itemid, amount);
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Took %s x%d from the vehicle.", itemName, amount);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	return 0;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES))
	{
		if (!IsPlayerAtCinema(playerid))
		{
			return 1;
		}

		if (!gCinemaActive)
		{
			SendClientMessage(playerid, -1, "The cinema is not playing anything right now.");
			return 1;
		}

		gCinemaWatching[playerid] = true;
		ShowCinemaStatus(playerid);
		return 1;
	}
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!strcmp(cmdtext, "/reloadcinema", true))
	{
		SetupCinemaInterior();
		SendClientMessage(playerid, -1, "Cinema interior reloaded.");
		return 1;
	}

	if (!strcmp(cmdtext, "/cinemaoff", true))
	{
		if (!IsPlayerAdmin(playerid))
		{
			SendClientMessage(playerid, -1, "You must be an RCON admin to stop broadcasts.");
			return 1;
		}

		StopCinemaBroadcast();
		return 1;
	}

	if (!strcmp(cmdtext, "/leavecinema", true))
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

	if (!strncmp(cmdtext, "/cinema ", 8, true))
	{
		if (!IsPlayerAdmin(playerid))
		{
			SendClientMessage(playerid, -1, "You must be an RCON admin to start broadcasts.");
			return 1;
		}

		new video[96];
		strmid(video, cmdtext, 8, strlen(cmdtext), sizeof(video));
		if (strlen(video) < 3)
		{
			SendClientMessage(playerid, -1, "Usage: /cinema <youtube_id_or_url>");
			return 1;
		}

		StartCinemaBroadcast(video);
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

	new rows;
	cache_get_row_count(rows);
	if (rows > 0)
	{
		cache_get_value_name(0, "password", PlayerData[playerid][pPassHash], PASSWORD_LEN + 1);
		cache_get_value_name_int(0, "skin", PlayerData[playerid][pSkin]);
		cache_get_value_name_float(0, "x", PlayerData[playerid][pX]);
		cache_get_value_name_float(0, "y", PlayerData[playerid][pY]);
		cache_get_value_name_float(0, "z", PlayerData[playerid][pZ]);
		cache_get_value_name_float(0, "a", PlayerData[playerid][pA]);
		cache_get_value_name_int(0, "interior", PlayerData[playerid][pInterior]);
		cache_get_value_name_int(0, "world", PlayerData[playerid][pWorld]);

		ShowLoginDialog(playerid);
	}
	else
	{
		ShowRegisterDialog(playerid);
	}
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	new idx;
	new cmd[64];
	new params[128];
	cmd = strtok(cmdtext, idx);

	if (!strlen(cmd))
	{
		return 0;
	}

	ParseCommand(cmdtext, cmd, sizeof(cmd), params, sizeof(params));

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
		if (params[0] == '\0')
		{
			SendClientMessage(playerid, -1, "Usage: /reportvehiclestolen [numberplate]");
			return 1;
		}

		new plate[MAX_PLATE_LEN];
		format(plate, sizeof(plate), "%s", params);
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
		if (params[0] == '\0')
		{
			SendClientMessage(playerid, -1, "Usage: /reportvehiclefound [numberplate]");
			return 1;
		}

		new plate[MAX_PLATE_LEN];
		format(plate, sizeof(plate), "%s", params);
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
		if (!strcmp(params, "on", true))
		{
			gHasLicense[playerid] = true;
			SendClientMessage(playerid, -1, "Your driver's license is now valid.");
			return 1;
		}
		if (!strcmp(params, "off", true))
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
		if (!strcmp(params, "on", true))
		{
			gTaxDue[playerid] = true;
			SendClientMessage(playerid, -1, "Your vehicle taxes are now marked overdue.");
			return 1;
		}
		if (!strcmp(params, "off", true))
		{
			gTaxDue[playerid] = false;
			SendClientMessage(playerid, -1, "Your vehicle taxes are up to date.");
			return 1;
		}
		SendClientMessage(playerid, -1, "Usage: /taxdue [on|off]");
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
			SendClientMessage(playerid, -1, "Usage: /showitems <player>");
			return 1;
		}
		new name[MAX_PLAYER_NAME];
		GetPlayerName(playerid, name, sizeof(name));
		new title[96];
		format(title, sizeof(title), "%s shows you their items:", name);
		SendInventoryList(playerid, targetid, title);
		SendClientMessage(playerid, -1, "You showed your items.");
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
			SendClientMessage(playerid, -1, "Usage: /giveitem <player> <itemid> <amount>");
			return 1;
		}

		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "You do not have enough of that item.");
			return 1;
		}

		AddPlayerItem(targetid, itemid, amount);
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));

		new message[96];
		format(message, sizeof(message), "You gave %s x%d.", itemName, amount);
		SendClientMessage(playerid, -1, message);

		format(message, sizeof(message), "You received %s x%d.", itemName, amount);
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
			SendClientMessage(playerid, -1, "Usage: /useitem <itemid>");
			return 1;
		}

		if (!gItems[itemid][itemConsumable])
		{
			SendClientMessage(playerid, -1, "That item cannot be consumed.");
			return 1;
		}

		if (!RemovePlayerItem(playerid, itemid, 1))
		{
			SendClientMessage(playerid, -1, "You do not have that item.");
			return 1;
		}

		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "You used %s.", itemName);
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
			SendClientMessage(playerid, -1, "Usage: /deleteitem <itemid> <amount>");
			return 1;
		}
		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "You do not have enough of that item.");
			return 1;
		}
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Deleted %s x%d.", itemName, amount);
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
			SendClientMessage(playerid, -1, "Usage: /dropitem <itemid> <amount>");
			return 1;
		}
		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "You do not have enough of that item.");
			return 1;
		}

		new dropid = CreateDrop(playerid, itemid, amount);
		if (dropid == -1)
		{
			AddPlayerItem(playerid, itemid, amount);
			SendClientMessage(playerid, -1, "No space to drop items right now.");
			return 1;
		}
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Dropped %s x%d. Press Y to pick up.", itemName, amount);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/vehmenu", true) || !strcmp(cmd, "/vmenu", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "You are not in a vehicle.");
			return 1;
		}
		ShowVehicleItemsDialog(playerid, vehicleid);
		return 1;
	}

	if (!strcmp(cmd, "/trunk", true))
	{
		SendClientMessage(playerid, -1, "You open the trunk. Use /vehitems to manage vehicle inventory.");
		return 1;
	}

	if (!strcmp(cmd, "/vehitems", true) || !strcmp(cmd, "/vinv", true) || !strcmp(cmd, "/vitems", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "You are not in a vehicle.");
			return 1;
		}
		SendVehicleInventoryList(playerid, vehicleid, "Vehicle inventory:");
		return 1;
	}

	if (!strcmp(cmd, "/vtitem", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "You are not in a vehicle.");
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
			SendClientMessage(playerid, -1, "Usage: /vtitem <itemid> (<amount>)");
			return 1;
		}
		if (!RemoveVehicleItem(vehicleid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "That item is not available in the vehicle.");
			return 1;
		}
		AddPlayerItem(playerid, itemid, amount);
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Took %s x%d from the vehicle.", itemName, amount);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/vpitem", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "You are not in a vehicle.");
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
			SendClientMessage(playerid, -1, "Usage: /vpitem <itemid> (<amount>)");
			return 1;
		}
		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "You do not have enough of that item.");
			return 1;
		}
		AddVehicleItem(vehicleid, itemid, amount);
		new itemName[MAX_ITEM_NAME];
		GetItemName(itemid, itemName, sizeof(itemName));
		new message[96];
		format(message, sizeof(message), "Placed %s x%d into the vehicle.", itemName, amount);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmd, "/vtitems", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "You are not in a vehicle.");
			return 1;
		}
		for (new i = 0; i < MAX_ITEMS; i++)
		{
			if (VehicleItems[vehicleid][i] < 1)
			{
				continue;
			}
			AddPlayerItem(playerid, i, VehicleItems[vehicleid][i]);
			VehicleItems[vehicleid][i] = 0;
		}
		SendClientMessage(playerid, -1, "You took all items from the vehicle.");
		return 1;
	}

	if (!strcmp(cmd, "/vpitems", true))
	{
		new vehicleid = GetPlayerVehicleID(playerid);
		if (vehicleid == 0)
		{
			SendClientMessage(playerid, -1, "You are not in a vehicle.");
			return 1;
		}
		for (new i = 0; i < MAX_ITEMS; i++)
		{
			if (PlayerItems[playerid][i] < 1)
			{
				continue;
			}
			AddVehicleItem(vehicleid, i, PlayerItems[playerid][i]);
			PlayerItems[playerid][i] = 0;
		}
		SendClientMessage(playerid, -1, "You placed all items into the vehicle.");
		return 1;
	}

	return 0;
}
