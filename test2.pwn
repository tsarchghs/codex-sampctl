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
forward TaxiRentalTick();
forward TaxiMeterTick();

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
	SetTimer("TaxiRentalTick", 60000, true);
	SetTimer("TaxiMeterTick", 1000, true);

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
	if (TaxiRentalVehicle[playerid] != INVALID_VEHICLE_ID)
	{
		DestroyVehicle(TaxiRentalVehicle[playerid]);
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
		DisablePlayerCheckpoint(driverid);
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
	DisablePlayerCheckpoint(driverid);
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

public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ)
{
	new driverid = TaxiDriverForCustomer[playerid];
	if (driverid != INVALID_PLAYER_ID)
	{
		SetPlayerCheckpoint(driverid, fX, fY, fZ, 4.0);
		SendClientMessage(driverid, -1, "Customer updated their waypoint.");
	}
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!strcmp(cmdtext, "/taxistart", true))
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

	if (!strcmp(cmdtext, "/taxistop", true))
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

	if (!strcmp(cmdtext, "/taxi", true))
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

	if (!strcmp(cmdtext, "/taxiaccept", true))
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
		SetPlayerCheckpoint(playerid, x, y, z, 4.0);
		return 1;
	}

	if (!strcmp(cmdtext, "/taxicancel", true))
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

	if (!strcmp(cmdtext, "/taxidone", true))
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
		return 1;
	}

	if (!strcmp(cmdtext, "/fare", true, 5))
	{
		if (!gTaxiOnDuty[playerid])
		{
			SendClientMessage(playerid, -1, "You must be on duty to set a fare.");
			return 1;
		}

		if (strlen(cmdtext) <= 6)
		{
			SendClientMessage(playerid, -1, "Usage: /fare [amount]");
			return 1;
		}

		new amount = strval(cmdtext[6]);
		if (amount == 0 && cmdtext[6] != '0')
		{
			SendClientMessage(playerid, -1, "Usage: /fare [amount]");
			return 1;
		}

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

	if (!strcmp(cmdtext, "/taximeter", true))
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

	if (!strcmp(cmdtext, "/taxirent", true))
	{
		new minutes_left = TaxiMinutesRemaining(playerid);
		if (minutes_left == 0)
		{
			TaxiRentalEndTick[playerid] = GetTickCount() + (TAXI_RENTAL_MINUTES * 60000);
			TaxiRentalNotifiedFive[playerid] = false;
			TaxiRentalNotifiedOne[playerid] = false;
			if (TaxiRentalVehicle[playerid] == INVALID_VEHICLE_ID)
			{
				new Float:x, Float:y, Float:z, Float:a;
				GetPlayerPos(playerid, x, y, z);
				GetPlayerFacingAngle(playerid, a);
				TaxiRentalVehicle[playerid] = CreateVehicle(420, x + 2.0, y, z, a, -1, -1, 0);
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

		TaxiRentalEndTick[playerid] += TAXI_RENTAL_EXTEND_MINUTES * 60000;
		TaxiRentalNotifiedFive[playerid] = false;
		TaxiRentalNotifiedOne[playerid] = false;
		new message[64];
		format(message, sizeof(message), "Taxi rental extended by %d minutes. Cost: $%d.", TAXI_RENTAL_EXTEND_MINUTES, TAXI_RENTAL_COST);
		SendClientMessage(playerid, -1, message);
		return 1;
	}

	if (!strcmp(cmdtext, "/stoptaxirent", true))
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

	return 0;
}
