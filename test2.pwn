// Simple MySQL (BlueG R41-4) account system with skin selection and position saving.
#include <a_samp>
#include <a_mysql>

#define MYSQL_HOST "127.0.0.1"
#define MYSQL_USER "root"
#define MYSQL_PASS "11112222"
#define MYSQL_DB   "samp"
#define MYSQL_PORT 3306

#define DIALOG_LOGIN    1
#define DIALOG_REGISTER 2

#define PASSWORD_LEN 64

#define PREVIEW_X 1958.3783
#define PREVIEW_Y 1343.1572
#define PREVIEW_Z 15.3746
#define PREVIEW_A 270.0
#define TELEPORT_RADIUS 1.5
#define TELEPORT_COOLDOWN_MS 1500

#define TELEPORT_PICKUP_MODEL 1318
#define TELEPORT_LABEL_DISTANCE 15.0

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
	pLastTeleportTick,
	pPassHash[PASSWORD_LEN + 1]
};
new PlayerData[MAX_PLAYERS][pInfo];

new MySQL:g_SQL;

forward OnAccountCheck(playerid);

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
	eTeleportPoint:tEntry,
	eTeleportPoint:tExit
};

enum eTeleportPickup
{
	pEntry,
	pExit
};

new const gTeleports[][eTeleport] =
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

new gTeleportPickups[sizeof(gTeleports)][eTeleportPickup];
new Text3D:gTeleportLabels[sizeof(gTeleports)][eTeleportPickup];

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
	PlayerData[playerid][pLastTeleportTick] = 0;
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

stock TeleportPlayerToPoint(playerid, eTeleportPoint:point)
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
		gTeleportPickups[i][pEntry] = CreatePickup(
			TELEPORT_PICKUP_MODEL,
			1,
			gTeleports[i][tEntry][tX],
			gTeleports[i][tEntry][tY],
			gTeleports[i][tEntry][tZ],
			gTeleports[i][tEntry][tWorld]
		);
		gTeleportPickups[i][pExit] = CreatePickup(
			TELEPORT_PICKUP_MODEL,
			1,
			gTeleports[i][tExit][tX],
			gTeleports[i][tExit][tY],
			gTeleports[i][tExit][tZ],
			gTeleports[i][tExit][tWorld]
		);

		gTeleportLabels[i][pEntry] = Create3DTextLabel(
			"Property Teleport\nWalk into the marker.",
			0xFFFFFFFF,
			gTeleports[i][tEntry][tX],
			gTeleports[i][tEntry][tY],
			gTeleports[i][tEntry][tZ] + 0.8,
			TELEPORT_LABEL_DISTANCE,
			0,
			gTeleports[i][tEntry][tWorld]
		);
		gTeleportLabels[i][pExit] = Create3DTextLabel(
			"Property Teleport\nWalk into the marker.",
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
		if (gTeleportPickups[i][pEntry] != 0)
		{
			DestroyPickup(gTeleportPickups[i][pEntry]);
			gTeleportPickups[i][pEntry] = 0;
		}
		if (gTeleportPickups[i][pExit] != 0)
		{
			DestroyPickup(gTeleportPickups[i][pExit]);
			gTeleportPickups[i][pExit] = 0;
		}

		if (gTeleportLabels[i][pEntry] != Text3D:0)
		{
			Delete3DTextLabel(gTeleportLabels[i][pEntry]);
			gTeleportLabels[i][pEntry] = Text3D:0;
		}
		if (gTeleportLabels[i][pExit] != Text3D:0)
		{
			Delete3DTextLabel(gTeleportLabels[i][pExit]);
			gTeleportLabels[i][pExit] = Text3D:0;
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
		return IsPlayerInRangeOfPoint(playerid, TELEPORT_RADIUS,
			gTeleports[index][tEntry][tX],
			gTeleports[index][tEntry][tY],
			gTeleports[index][tEntry][tZ]);
	}

	if (interior != gTeleports[index][tExit][tInterior] || world != gTeleports[index][tExit][tWorld])
	{
		return false;
	}
	return IsPlayerInRangeOfPoint(playerid, TELEPORT_RADIUS,
		gTeleports[index][tExit][tX],
		gTeleports[index][tExit][tY],
		gTeleports[index][tExit][tZ]);
}

main()
{
	print("Account system loaded.");
}

public OnGameModeInit()
{
	SetGameModeText("MySQL Accounts");
	UsePlayerPedAnims();
	CreatePropertyTeleports();

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
	return 1;
}

public OnGameModeExit()
{
	DestroyPropertyTeleports();
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

public OnPlayerPickUpPickup(playerid, pickupid)
{
	for (new i = 0; i < sizeof(gTeleports); i++)
	{
		if (pickupid == gTeleportPickups[i][pEntry])
		{
			if (IsPlayerNearTeleport(playerid, i, true))
			{
				TryPropertyTeleport(playerid, i, true);
			}
			return 1;
		}

		if (pickupid == gTeleportPickups[i][pExit])
		{
			if (IsPlayerNearTeleport(playerid, i, false))
			{
				TryPropertyTeleport(playerid, i, false);
			}
			return 1;
		}
	}
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!strcmp(cmdtext, "/teleports", true))
	{
		SendClientMessage(playerid, -1, "Property teleports are marked with green pickups.");
		SendClientMessage(playerid, -1, "Walk into the marker to travel between entry/exit points.");
		return 1;
	}
	return 0;
}
