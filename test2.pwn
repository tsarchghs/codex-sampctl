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
#define DIALOG_DMV      3
#define DIALOG_DMV_PAY  4

#define PASSWORD_LEN 64

#define PREVIEW_X 1958.3783
#define PREVIEW_Y 1343.1572
#define PREVIEW_Z 15.3746
#define PREVIEW_A 270.0

#define DMV_VEHICLE_VALUE 50000
#define DMV_REGISTRATION_RATE 0.20
#define DMV_TAX_RATE 0.05
#define DMV_INSURANCE_RATE 0.05

#define DMV_BILLING_INTERVAL 3600000 // 1 hour in milliseconds

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
	bool:pVehicleRegistered,
	bool:pTaxesPaid,
	bool:pInsured,
	pNextBilling
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
	PlayerData[playerid][pVehicleRegistered] = false;
	PlayerData[playerid][pTaxesPaid] = false;
	PlayerData[playerid][pInsured] = false;
	PlayerData[playerid][pNextBilling] = 0;
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
	mysql_format(g_SQL, query, sizeof(query),
		"UPDATE `accounts` SET `vehicle_registered`=%d, `taxes_paid`=%d, `insured`=%d WHERE `name`='%e' LIMIT 1",
		PlayerData[playerid][pVehicleRegistered],
		PlayerData[playerid][pTaxesPaid],
		PlayerData[playerid][pInsured],
		name
	);
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

	new query[256];
	mysql_format(g_SQL, query, sizeof(query),
		"INSERT INTO `accounts` (`name`,`password`,`skin`,`x`,`y`,`z`,`a`,`interior`,`world`,`vehicle_registered`,`taxes_paid`,`insured`) VALUES ('%e','%e',%d,%.4f,%.4f,%.4f,%.4f,%d,%d,%d,%d,%d)",
		name,
		PlayerData[playerid][pPassHash],
		PlayerData[playerid][pSkin],
		PREVIEW_X, PREVIEW_Y, PREVIEW_Z, PREVIEW_A,
		0, 0,
		PlayerData[playerid][pVehicleRegistered],
		PlayerData[playerid][pTaxesPaid],
		PlayerData[playerid][pInsured]
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
		"UPDATE `accounts` SET `skin`=%d, `x`=%.4f, `y`=%.4f, `z`=%.4f, `a`=%.4f, `interior`=%d, `world`=%d, `vehicle_registered`=%d, `taxes_paid`=%d, `insured`=%d WHERE `name`='%e' LIMIT 1",
		skin, x, y, z, a, interior, world,
		PlayerData[playerid][pVehicleRegistered],
		PlayerData[playerid][pTaxesPaid],
		PlayerData[playerid][pInsured],
		name
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
			"CREATE TABLE IF NOT EXISTS `accounts` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`name` VARCHAR(24) NOT NULL,`password` CHAR(64) NOT NULL,`skin` INT NOT NULL DEFAULT 0,`x` FLOAT NOT NULL DEFAULT 1958.3783,`y` FLOAT NOT NULL DEFAULT 1343.1572,`z` FLOAT NOT NULL DEFAULT 15.3746,`a` FLOAT NOT NULL DEFAULT 270.0,`interior` INT NOT NULL DEFAULT 0,`world` INT NOT NULL DEFAULT 0,`vehicle_registered` TINYINT(1) NOT NULL DEFAULT 0,`taxes_paid` TINYINT(1) NOT NULL DEFAULT 0,`insured` TINYINT(1) NOT NULL DEFAULT 0,PRIMARY KEY (`id`),UNIQUE KEY `name` (`name`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
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
		"SELECT `password`,`skin`,`x`,`y`,`z`,`a`,`interior`,`world`,`vehicle_registered`,`taxes_paid`,`insured` FROM `accounts` WHERE `name`='%e' LIMIT 1",
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
	if (PlayerData[playerid][pNextBilling] != 0)
	{
		KillTimer(PlayerData[playerid][pNextBilling]);
		PlayerData[playerid][pNextBilling] = 0;
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

		new cost;
		if (!PlayerData[playerid][pVehicleRegistered])
		{
			cost = GetRegistrationCost();
			if (ChargePlayer(playerid, cost))
			{
				PlayerData[playerid][pVehicleRegistered] = true;
				SendClientMessage(playerid, -1, "Vehicle registered and plates issued.");
			}
		}
		else if (!PlayerData[playerid][pTaxesPaid])
		{
			cost = GetTaxCost();
			if (ChargePlayer(playerid, cost))
			{
				PlayerData[playerid][pTaxesPaid] = true;
				SendClientMessage(playerid, -1, "Road taxes paid.");
			}
		}
		else if (!PlayerData[playerid][pInsured])
		{
			cost = GetInsuranceCost();
			if (ChargePlayer(playerid, cost))
			{
				PlayerData[playerid][pInsured] = true;
				SendClientMessage(playerid, -1, "Insurance activated.");
			}
		}

		SavePlayerDmvStatus(playerid);
		ShowDmvDialog(playerid);
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
		cache_get_value_name_int(0, "vehicle_registered", PlayerData[playerid][pVehicleRegistered]);
		cache_get_value_name_int(0, "taxes_paid", PlayerData[playerid][pTaxesPaid]);
		cache_get_value_name_int(0, "insured", PlayerData[playerid][pInsured]);

		ShowLoginDialog(playerid);
	}
	else
	{
		ShowRegisterDialog(playerid);
	}
	return 1;
}

public OnPlayerSpawn(playerid)
{
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

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!strcmp(cmdtext, "/dmv", true))
	{
		if (!PlayerData[playerid][pLogged])
		{
			SendClientMessage(playerid, -1, "You must be logged in to use the DMV.");
			return 1;
		}

		ShowDmvDialog(playerid);
		return 1;
	}
	return 0;
}
