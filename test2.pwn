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
	pPetActor,
	pPetTask,
	pPetTimer
};
new PlayerData[MAX_PLAYERS][pInfo];

new MySQL:g_SQL;

forward OnAccountCheck(playerid);
forward PetUpdate(playerid);

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
	PlayerData[playerid][pPetActor] = INVALID_ACTOR_ID;
	PlayerData[playerid][pPetTask] = PET_TASK_NONE;
	PlayerData[playerid][pPetTimer] = 0;
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
	DestroyPet(playerid);
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

stock strtok(const string[], &index)
{
	new length = strlen(string);
	while ((index < length) && (string[index] <= ' '))
	{
		index++;
	}

	new offset = index;
	new result[64];
	while ((index < length) && (string[index] > ' '))
	{
		result[index - offset] = string[index];
		index++;
	}
	result[index - offset] = '\0';
	return result;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	new idx = 0;
	new cmd[64];
	cmd = strtok(cmdtext, idx);
	if (!strlen(cmd))
	{
		return 0;
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

	return 0;
}
