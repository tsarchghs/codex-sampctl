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
#define MAX_PLATE_LEN 32
#define MAX_STOLEN_PLATES 256
#define ALPR_SCAN_INTERVAL 4000
#define ALPR_RANGE 20.0

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

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	if (oldstate == PLAYER_STATE_DRIVER && newstate != PLAYER_STATE_DRIVER && gAlprEnabled[playerid])
	{
		StopAlpr(playerid);
	}
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	new command[32];
	new params[128];

	if (cmdtext[0] != '/')
	{
		return 0;
	}

	ParseCommand(cmdtext, command, sizeof(command), params, sizeof(params));

	if (!strcmp(command, "/alpr", true))
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

	if (!strcmp(command, "/reportvehiclestolen", true)
		|| !strcmp(command, "/reportvehstolen", true)
		|| !strcmp(command, "/reportstolen", true))
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

	if (!strcmp(command, "/reportvehiclefound", true)
		|| !strcmp(command, "/reportvehfound", true)
		|| !strcmp(command, "/reportfound", true))
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

	if (!strcmp(command, "/license", true))
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

	if (!strcmp(command, "/taxdue", true))
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

	return 0;
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
