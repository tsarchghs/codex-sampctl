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

#define MINIGAME_NONE     0
#define MINIGAME_LOCKPICK 1
#define MINIGAME_HOTWIRE  2

#define MINIGAME_KEYS 3

#define PREVIEW_X 1958.3783
#define PREVIEW_Y 1343.1572
#define PREVIEW_Z 15.3746
#define PREVIEW_A 270.0

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
	pPassHash[PASSWORD_LEN + 1],
	pMiniGame,
	pMiniVehicle,
	pMiniStep,
	pMiniKeySequence[MINIGAME_KEYS],
	pMiniTimer
};
new PlayerData[MAX_PLAYERS][pInfo];

new MySQL:g_SQL;

forward OnAccountCheck(playerid);
forward OnMiniGameTimeout(playerid);

new gVehicleLockLevel[MAX_VEHICLES];
new gVehicleAlarmLevel[MAX_VEHICLES];
new gVehicleMarketPrice[MAX_VEHICLES];
new gVehicleManufacturer[MAX_VEHICLES];

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
	PlayerData[playerid][pPassHash][0] = '\0';
	PlayerData[playerid][pMiniGame] = MINIGAME_NONE;
	PlayerData[playerid][pMiniVehicle] = INVALID_VEHICLE_ID;
	PlayerData[playerid][pMiniStep] = 0;
	PlayerData[playerid][pMiniTimer] = 0;
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

	new vehicleid = CreateVehicle(411, PREVIEW_X + 6.0, PREVIEW_Y + 4.0, PREVIEW_Z, 0.0, 0, 0, -1);
	SetVehicleParamsEx(vehicleid, 0, 0, 0, 1, 0, 0, 0);
	gVehicleLockLevel[vehicleid] = 3;
	gVehicleAlarmLevel[vehicleid] = 2;
	gVehicleMarketPrice[vehicleid] = 120000;
	gVehicleManufacturer[vehicleid] = 2;

	vehicleid = CreateVehicle(560, PREVIEW_X + 8.0, PREVIEW_Y - 3.0, PREVIEW_Z, 180.0, 0, 0, -1);
	SetVehicleParamsEx(vehicleid, 0, 0, 0, 1, 0, 0, 0);
	gVehicleLockLevel[vehicleid] = 2;
	gVehicleAlarmLevel[vehicleid] = 1;
	gVehicleMarketPrice[vehicleid] = 60000;
	gVehicleManufacturer[vehicleid] = 1;

	vehicleid = CreateVehicle(489, PREVIEW_X + 12.0, PREVIEW_Y + 6.0, PREVIEW_Z, 90.0, 0, 0, -1);
	SetVehicleParamsEx(vehicleid, 0, 0, 0, 1, 0, 0, 0);
	gVehicleLockLevel[vehicleid] = 4;
	gVehicleAlarmLevel[vehicleid] = 3;
	gVehicleMarketPrice[vehicleid] = 90000;
	gVehicleManufacturer[vehicleid] = 3;

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
	CancelMiniGame(playerid);
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

public OnMiniGameTimeout(playerid)
{
	if (PlayerData[playerid][pMiniGame] == MINIGAME_NONE)
	{
		return 0;
	}

	FailMiniGame(playerid, "You ran out of time and failed the attempt.");
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if (PlayerData[playerid][pMiniGame] == MINIGAME_NONE)
	{
		return 1;
	}

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

public OnPlayerExitVehicle(playerid, vehicleid)
{
	if (PlayerData[playerid][pMiniGame] == MINIGAME_HOTWIRE)
	{
		FailMiniGame(playerid, "You left the vehicle and failed to hotwire it.");
	}
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!strcmp(cmdtext, "/vbreakin", true) || !strcmp(cmdtext, "/vbi", true))
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

	if (!strcmp(cmdtext, "/hotwire", true))
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

	return 0;
}
