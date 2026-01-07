// Simple MySQL (BlueG R41-4) account system with skin selection and position saving.
#include <a_samp>
#include <a_mysql>

#define MYSQL_HOST "127.0.0.1"
#define MYSQL_USER "root"
#define MYSQL_PASS "11112222"
#define MYSQL_DB   "samp"
#define MYSQL_PORT 3306

#define DIALOG_LOGIN       1
#define DIALOG_REGISTER    2
#define DIALOG_GARAGE_INFO 3

#define PASSWORD_LEN 64

#define PREVIEW_X 1958.3783
#define PREVIEW_Y 1343.1572
#define PREVIEW_Z 15.3746
#define PREVIEW_A 270.0

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

new const gSkinList[] =
{
	0, 2, 7, 15, 20, 21, 23, 24, 28, 29,
	46, 50, 60, 61, 70, 71, 72, 73, 105, 107,
	120, 124, 125, 129, 147, 170, 180, 187, 200, 210
};

enum pInfo
{
	bool:pLogged,
	bool:pRegistering,
	pSkin,
	Float:pX,
	Float:pY,
	Float:pZ,
	Float:pA,
	pInterior,
	pWorld,
	pParts,
	pPassHash[PASSWORD_LEN + 1]
};
new PlayerData[MAX_PLAYERS][pInfo];

new MySQL:g_SQL;
new bool:gVehicleAlarmOn[MAX_VEHICLES];

new const gWantedList[] =
{
	411, 415, 451, 541, 560
};

forward OnAccountCheck(playerid);

stock ResetPlayerData(playerid)
{
	PlayerData[playerid][pLogged] = false;
	PlayerData[playerid][pRegistering] = false;
	PlayerData[playerid][pSkin] = 0;
	PlayerData[playerid][pX] = PREVIEW_X;
	PlayerData[playerid][pY] = PREVIEW_Y;
	PlayerData[playerid][pZ] = PREVIEW_Z;
	PlayerData[playerid][pA] = PREVIEW_A;
	PlayerData[playerid][pInterior] = 0;
	PlayerData[playerid][pWorld] = 0;
	PlayerData[playerid][pParts] = 0;
	PlayerData[playerid][pPassHash][0] = '\0';
	return 1;
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
	ShowPlayerDialog(
		playerid,
		DIALOG_GARAGE_INFO,
		DIALOG_STYLE_MSGBOX,
		"Garage & Chop Shops",
		"Garages are owned by players or organizations.\n"
		"A mechanic can repair, mod, or paint vehicles, plus install locks and alarms.\n"
		"\n"
		"Commands:\n"
		"/repair /paint /lock /alarm /mod\n"
		"/chop /wanted /craft\n"
		"\n"
		"Illegal garage features:\n"
		"- Chop a vehicle to receive car parts.\n"
		"- View the wanted cars list.",
		"Close",
		""
	);
	return 1;
}

stock bool:IsPlayerAtGarage(playerid)
{
	return IsPlayerInRangeOfPoint(playerid, GARAGE_RADIUS, GARAGE_X, GARAGE_Y, GARAGE_Z);
}

stock bool:IsPlayerAtChopShop(playerid)
{
	return IsPlayerInRangeOfPoint(playerid, CHOP_RADIUS, CHOP_X, CHOP_Y, CHOP_Z);
}

stock bool:EnsureVehicleAccess(playerid)
{
	if (!IsPlayerInAnyVehicle(playerid))
	{
		SendClientMessage(playerid, -1, "You need to be in a vehicle.");
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

	for (new i = 0; i < sizeof(gSkinList); i++)
	{
		AddPlayerClass(gSkinList[i], PREVIEW_X, PREVIEW_Y, PREVIEW_Z, PREVIEW_A, 0, 0, 0, 0, 0, 0);
	}

	CreatePickup(1239, 1, GARAGE_X, GARAGE_Y, GARAGE_Z, 0);
	CreatePickup(1239, 1, CHOP_X, CHOP_Y, CHOP_Z, 0);

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
	return 1;
}

public OnGameModeExit()
{
	if (g_SQL != MYSQL_INVALID_HANDLE)
	{
		mysql_close(g_SQL);
	}
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
	ResetPlayerData(playerid);
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!strcmp(cmdtext, "/garage", true))
	{
		ShowGarageInfoDialog(playerid);
		return 1;
	}
	if (!strcmp(cmdtext, "/repair", true))
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
	if (!strcmp(cmdtext, "/paint", true))
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
	if (!strcmp(cmdtext, "/mod", true))
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
	if (!strcmp(cmdtext, "/lock", true))
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
	if (!strcmp(cmdtext, "/alarm", true))
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
	if (!strcmp(cmdtext, "/wanted", true))
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
	if (!strcmp(cmdtext, "/chop", true))
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
	if (!strcmp(cmdtext, "/craft", true))
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
	return 0;
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
