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
