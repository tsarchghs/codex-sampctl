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

forward OnAccountCheck(playerid);
forward bool:HandleLspdCommand(playerid, const cmd[], const params[]);

stock bool:HasCommandPrefix(const cmd[], const prefix[])
{
	return !strcmp(cmd, prefix, true, strlen(prefix));
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

public OnPlayerCommandText(playerid, cmdtext[])
{
	new cmd[32];
	new params[96];
	new len = strlen(cmdtext);
	new idx = 0;
	new cmd_len = 0;

	if (len == 0 || cmdtext[0] != '/')
	{
		return 0;
	}

	idx = 1;
	while (idx < len && cmdtext[idx] > ' ' && cmd_len < sizeof(cmd) - 1)
	{
		cmd[cmd_len++] = cmdtext[idx++];
	}
	cmd[cmd_len] = '\0';

	while (idx < len && cmdtext[idx] <= ' ')
	{
		idx++;
	}

	strmid(params, cmdtext, idx, len, sizeof(params));

	if (HandleLspdCommand(playerid, cmd, params))
	{
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

public bool:HandleLspdCommand(playerid, const cmd[], const params[])
{
	if (!strcmp(cmd, "pduty", true))
	{
		SetPlayerHealth(playerid, 100.0);
		SetPlayerArmour(playerid, 100.0);
		SetPlayerColor(playerid, 0x3399FFFF);
		SendClientMessage(playerid, -1, "LSPD duty loadout applied.");
		return true;
	}

	if (!strcmp(cmd, "equipment", true))
	{
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
