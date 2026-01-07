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

#define MAX_BUSINESSES 6
#define BUSINESS_BUY_RADIUS 3.0
#define BUSINESS_COMPONENTS_DEFAULT 50
#define COMPONENT_CRATE_COST 500
#define BUSINESS_LABEL_DISTANCE 20.0

#define COMPONENT_WAREHOUSE_X 2172.8499
#define COMPONENT_WAREHOUSE_Y -2265.4827
#define COMPONENT_WAREHOUSE_Z 13.3047

#define KEY_YES 16

new BusinessPickups[MAX_BUSINESSES];
new Text3D:BusinessLabels[MAX_BUSINESSES];
new WarehousePickup;

new const gSkinList[] =
{
	0, 2, 7, 15, 20, 21, 23, 24, 28, 29,
	46, 50, 60, 61, 70, 71, 72, 73, 105, 107,
	120, 124, 125, 129, 147, 170, 180, 187, 200, 210
};

enum BusinessType
{
	BUSINESS_AMMUNATION,
	BUSINESS_CLOTHING,
	BUSINESS_247,
	BUSINESS_BARBERSHOP,
	BUSINESS_BEAUTY_SALON,
	BUSINESS_PLASTIC_SURGEON
};

new const gBusinessTypeNames[][24] =
{
	"Ammunation",
	"Clothing shop",
	"24/7",
	"Barbershop",
	"Beauty salon",
	"Plastic surgeon"
};

enum bInfo
{
	Float:bX,
	Float:bY,
	Float:bZ,
	bPrice,
	BusinessType:bType,
	bOwner,
	bComponents,
	bComponentPrice,
	bEarnings
};

new BusinessData[MAX_BUSINESSES][bInfo] =
{
	{1368.5737, -1279.0925, 13.5469, 120000, BUSINESS_AMMUNATION, INVALID_PLAYER_ID, 0, 0, 0},
	{2106.7893, -1795.8391, 13.5547, 90000, BUSINESS_CLOTHING, INVALID_PLAYER_ID, 0, 0, 0},
	{1836.5348, -1682.5930, 13.3281, 60000, BUSINESS_247, INVALID_PLAYER_ID, 0, 0, 0},
	{2037.5316, -1320.1406, 20.0469, 80000, BUSINESS_BARBERSHOP, INVALID_PLAYER_ID, 0, 0, 0},
	{1041.9856, -1025.7467, 32.1016, 85000, BUSINESS_BEAUTY_SALON, INVALID_PLAYER_ID, 0, 0, 0},
	{1154.5022, -1461.0933, 15.7969, 110000, BUSINESS_PLASTIC_SURGEON, INVALID_PLAYER_ID, 0, 0, 0}
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
	pCrates,
	pDeliveryBiz,
	bool:pHasDelivery,
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
	PlayerData[playerid][pCrates] = 0;
	PlayerData[playerid][pDeliveryBiz] = -1;
	PlayerData[playerid][pHasDelivery] = false;
	PlayerData[playerid][pPassHash][0] = '\0';
	return 1;
}

stock GetNearestBusiness(playerid, Float:radius = BUSINESS_BUY_RADIUS)
{
	new Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid, px, py, pz);

	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		if (GetPlayerDistanceFromPoint(playerid, BusinessData[i][bX], BusinessData[i][bY], BusinessData[i][bZ]) <= radius)
		{
			return i;
		}
	}
	return -1;
}

stock UpdateBusinessLabel(businessId)
{
	if (businessId < 0 || businessId >= MAX_BUSINESSES)
	{
		return 0;
	}

	new label[192];
	new ownerName[MAX_PLAYER_NAME] = "For Sale";
	if (BusinessData[businessId][bOwner] != INVALID_PLAYER_ID && IsPlayerConnected(BusinessData[businessId][bOwner]))
	{
		GetPlayerName(BusinessData[businessId][bOwner], ownerName, sizeof(ownerName));
	}

	if (BusinessData[businessId][bOwner] == INVALID_PLAYER_ID)
	{
		format(label, sizeof(label),
			"%s\nPrice: $%d\nPress Y for details",
			gBusinessTypeNames[BusinessData[businessId][bType]],
			BusinessData[businessId][bPrice]
		);
	}
	else
	{
		format(label, sizeof(label),
			"%s\nOwner: %s\nComponents: %d",
			gBusinessTypeNames[BusinessData[businessId][bType]],
			ownerName,
			BusinessData[businessId][bComponents]
		);
	}

	if (BusinessLabels[businessId] != Text3D:0)
	{
		Delete3DTextLabel(BusinessLabels[businessId]);
	}
	BusinessLabels[businessId] = Create3DTextLabel(label, 0xF5E76AFF, BusinessData[businessId][bX], BusinessData[businessId][bY], BusinessData[businessId][bZ] + 0.8, BUSINESS_LABEL_DISTANCE, 0, 0);
	return 1;
}

stock ShowBusinessStatus(playerid, businessId)
{
	if (businessId < 0 || businessId >= MAX_BUSINESSES)
	{
		SendClientMessage(playerid, -1, "Invalid business.");
		return 1;
	}

	new owner = BusinessData[businessId][bOwner];
	new ownerName[MAX_PLAYER_NAME] = "None";
	if (owner != INVALID_PLAYER_ID && IsPlayerConnected(owner))
	{
		GetPlayerName(owner, ownerName, sizeof(ownerName));
	}

	new message[144];
	format(message, sizeof(message),
		"Business %d (%s) | Owner: %s | Components: %d | Component price: $%d | Earnings: $%d",
		businessId + 1,
		gBusinessTypeNames[BusinessData[businessId][bType]],
		ownerName,
		BusinessData[businessId][bComponents],
		BusinessData[businessId][bComponentPrice],
		BusinessData[businessId][bEarnings]
	);
	SendClientMessage(playerid, -1, message);
	return 1;
}

stock ClearDeliveryCheckpoint(playerid)
{
	if (PlayerData[playerid][pHasDelivery])
	{
		DisablePlayerCheckpoint(playerid);
		PlayerData[playerid][pHasDelivery] = false;
		PlayerData[playerid][pDeliveryBiz] = -1;
	}
	return 1;
}

stock bool:IsNearComponentWarehouse(playerid, Float:radius = 4.0)
{
	return GetPlayerDistanceFromPoint(playerid, COMPONENT_WAREHOUSE_X, COMPONENT_WAREHOUSE_Y, COMPONENT_WAREHOUSE_Z) <= radius;
}

stock GetCommandToken(const cmdtext[], &index, token[], size)
{
	new len = strlen(cmdtext);
	while (index < len && cmdtext[index] == ' ')
	{
		index++;
	}

	new i = 0;
	while (index < len && cmdtext[index] != ' ' && i < size - 1)
	{
		token[i++] = cmdtext[index++];
	}
	token[i] = '\0';
	return i;
}

stock DeliverComponents(playerid, businessId)
{
	if (businessId < 0 || businessId >= MAX_BUSINESSES)
	{
		SendClientMessage(playerid, -1, "Usage: /deliverbiz [businessId]");
		return 1;
	}

	if (PlayerData[playerid][pCrates] < 1)
	{
		SendClientMessage(playerid, -1, "You have no crates to deliver.");
		return 1;
	}

	if (GetPlayerDistanceFromPoint(playerid, BusinessData[businessId][bX], BusinessData[businessId][bY], BusinessData[businessId][bZ]) > BUSINESS_BUY_RADIUS)
	{
		SendClientMessage(playerid, -1, "You must be at the business to deliver.");
		return 1;
	}

	new payout = PlayerData[playerid][pCrates] * BusinessData[businessId][bComponentPrice];
	BusinessData[businessId][bComponents] += PlayerData[playerid][pCrates];
	PlayerData[playerid][pCrates] = 0;

	if (payout > 0)
	{
		GivePlayerMoney(playerid, payout);
	}

	SendClientMessage(playerid, -1, "Components delivered. Your crates have been unloaded.");
	ShowBusinessStatus(playerid, businessId);
	UpdateBusinessLabel(businessId);
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

stock ReleasePlayerBusinesses(playerid)
{
	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		if (BusinessData[i][bOwner] == playerid)
		{
			BusinessData[i][bOwner] = INVALID_PLAYER_ID;
			BusinessData[i][bComponents] = 0;
			BusinessData[i][bEarnings] = 0;
			UpdateBusinessLabel(i);
		}
	}
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

	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		BusinessData[i][bOwner] = INVALID_PLAYER_ID;
		BusinessData[i][bComponents] = BUSINESS_COMPONENTS_DEFAULT;
		BusinessData[i][bComponentPrice] = 750;
		BusinessData[i][bEarnings] = 0;
		BusinessPickups[i] = CreatePickup(1274, 1, BusinessData[i][bX], BusinessData[i][bY], BusinessData[i][bZ]);
		UpdateBusinessLabel(i);
	}

	WarehousePickup = CreatePickup(1239, 1, COMPONENT_WAREHOUSE_X, COMPONENT_WAREHOUSE_Y, COMPONENT_WAREHOUSE_Z);

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

	if (WarehousePickup)
	{
		DestroyPickup(WarehousePickup);
	}
	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		if (BusinessPickups[i])
		{
			DestroyPickup(BusinessPickups[i]);
		}
		if (BusinessLabels[i] != Text3D:0)
		{
			Delete3DTextLabel(BusinessLabels[i]);
		}
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
	ReleasePlayerBusinesses(playerid);
	ClearDeliveryCheckpoint(playerid);
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

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if ((newkeys & KEY_YES) && PlayerData[playerid][pLogged])
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			SendClientMessage(playerid, -1, "You are not near a business.");
			return 1;
		}

		if (BusinessData[businessId][bOwner] == playerid)
		{
			ShowBusinessStatus(playerid, businessId);
			SendClientMessage(playerid, -1, "Use /setcomponentprice [amount] or /sellbiz to manage this business.");
		}
		else if (BusinessData[businessId][bOwner] == INVALID_PLAYER_ID)
		{
			new message[96];
			format(message, sizeof(message), "This business is for sale: $%d. Use /buybiz to purchase it.", BusinessData[businessId][bPrice]);
			SendClientMessage(playerid, -1, message);
		}
		else
		{
			ShowBusinessStatus(playerid, businessId);
		}
		return 1;
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

public OnPlayerPickUpPickup(playerid, pickupid)
{
	if (pickupid == WarehousePickup)
	{
		SendClientMessage(playerid, -1, "Component warehouse: use /buycrates [count] to buy crates.");
		return 1;
	}

	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		if (pickupid == BusinessPickups[i])
		{
			ShowBusinessStatus(playerid, i);
			return 1;
		}
	}
	return 0;
}

public OnPlayerEnterCheckpoint(playerid)
{
	if (!PlayerData[playerid][pHasDelivery])
	{
		return 0;
	}

	new businessId = PlayerData[playerid][pDeliveryBiz];
	if (businessId < 0 || businessId >= MAX_BUSINESSES)
	{
		ClearDeliveryCheckpoint(playerid);
		return 0;
	}

	if (GetPlayerDistanceFromPoint(playerid, BusinessData[businessId][bX], BusinessData[businessId][bY], BusinessData[businessId][bZ]) <= BUSINESS_BUY_RADIUS)
	{
		DeliverComponents(playerid, businessId);
		ClearDeliveryCheckpoint(playerid);
	}
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	new cmd[32];
	new idx = 0;
	GetCommandToken(cmdtext, idx, cmd, sizeof(cmd));

	if (!strcmp(cmd, "/businesses", true))
	{
		SendClientMessage(playerid, -1, "Businesses for sale:");
		for (new i = 0; i < MAX_BUSINESSES; i++)
		{
			if (BusinessData[i][bOwner] == INVALID_PLAYER_ID)
			{
				new message[96];
				format(message, sizeof(message), "%d) %s - $%d", i + 1, gBusinessTypeNames[BusinessData[i][bType]], BusinessData[i][bPrice]);
				SendClientMessage(playerid, -1, message);
			}
		}
		return 1;
	}

	if (!strcmp(cmd, "/bizhelp", true))
	{
		SendClientMessage(playerid, -1, "Business commands: /businesses, /buybiz, /bizstatus, /setcomponentprice, /sellbiz, /buyitem, /buycrates, /deliverbiz, /cancelbiz");
		SendClientMessage(playerid, -1, "Tip: press Y near a business for details. Buy crates at the warehouse marker.");
		return 1;
	}

	if (!strcmp(cmd, "/buybiz", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			SendClientMessage(playerid, -1, "You are not near a business.");
			return 1;
		}

		if (BusinessData[businessId][bOwner] != INVALID_PLAYER_ID)
		{
			SendClientMessage(playerid, -1, "This business is already owned.");
			return 1;
		}

		if (GetPlayerMoney(playerid) < BusinessData[businessId][bPrice])
		{
			SendClientMessage(playerid, -1, "You cannot afford this business.");
			return 1;
		}

		GivePlayerMoney(playerid, -BusinessData[businessId][bPrice]);
		BusinessData[businessId][bOwner] = playerid;
		BusinessData[businessId][bComponents] = BUSINESS_COMPONENTS_DEFAULT;
		UpdateBusinessLabel(businessId);
		SendClientMessage(playerid, -1, "Business purchased. Press Y to manage it.");
		return 1;
	}

	if (!strcmp(cmd, "/bizstatus", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			SendClientMessage(playerid, -1, "You are not near a business.");
			return 1;
		}

		ShowBusinessStatus(playerid, businessId);
		return 1;
	}

	if (!strcmp(cmd, "/setcomponentprice", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			SendClientMessage(playerid, -1, "You are not near a business.");
			return 1;
		}

		if (BusinessData[businessId][bOwner] != playerid)
		{
			SendClientMessage(playerid, -1, "Only the owner can update component prices.");
			return 1;
		}

		new priceToken[16];
		GetCommandToken(cmdtext, idx, priceToken, sizeof(priceToken));
		new price = strval(priceToken);
		if (price < 1)
		{
			SendClientMessage(playerid, -1, "Usage: /setcomponentprice [amount]");
			return 1;
		}

		BusinessData[businessId][bComponentPrice] = price;
		SendClientMessage(playerid, -1, "Component purchase price updated.");
		ShowBusinessStatus(playerid, businessId);
		return 1;
	}

	if (!strcmp(cmd, "/sellbiz", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			SendClientMessage(playerid, -1, "You are not near a business.");
			return 1;
		}

		if (BusinessData[businessId][bOwner] != playerid)
		{
			SendClientMessage(playerid, -1, "Only the owner can sell this business.");
			return 1;
		}

		new refund = BusinessData[businessId][bPrice] / 2;
		GivePlayerMoney(playerid, refund);
		BusinessData[businessId][bOwner] = INVALID_PLAYER_ID;
		BusinessData[businessId][bComponents] = 0;
		BusinessData[businessId][bEarnings] = 0;
		UpdateBusinessLabel(businessId);
		SendClientMessage(playerid, -1, "Business sold back to the market.");
		return 1;
	}

	if (!strcmp(cmd, "/buyitem", true))
	{
		new businessId = GetNearestBusiness(playerid);
		if (businessId == -1)
		{
			SendClientMessage(playerid, -1, "You are not near a business.");
			return 1;
		}

		new costToken[16];
		new countToken[16];
		GetCommandToken(cmdtext, idx, costToken, sizeof(costToken));
		GetCommandToken(cmdtext, idx, countToken, sizeof(countToken));
		new cost = strval(costToken);
		new count = strval(countToken);
		if (count < 1)
		{
			count = 1;
		}
		if (cost < 1)
		{
			SendClientMessage(playerid, -1, "Usage: /buyitem [cost] [count]");
			return 1;
		}

		if (BusinessData[businessId][bComponents] < count)
		{
			SendClientMessage(playerid, -1, "This business is out of components.");
			return 1;
		}

		if (GetPlayerMoney(playerid) < cost)
		{
			SendClientMessage(playerid, -1, "You cannot afford that purchase.");
			return 1;
		}

		GivePlayerMoney(playerid, -cost);
		BusinessData[businessId][bComponents] -= count;

		new owner = BusinessData[businessId][bOwner];
		if (owner != INVALID_PLAYER_ID && IsPlayerConnected(owner))
		{
			new payout = cost;
			if (BusinessData[businessId][bType] == BUSINESS_AMMUNATION)
			{
				payout = cost / 2;
			}
			GivePlayerMoney(owner, payout);
			BusinessData[businessId][bEarnings] += payout;
		}

		SendClientMessage(playerid, -1, "Purchase completed.");
		UpdateBusinessLabel(businessId);
		return 1;
	}

	if (!strcmp(cmd, "/buycrates", true))
	{
		if (!IsNearComponentWarehouse(playerid))
		{
			SendClientMessage(playerid, -1, "You must be at the component warehouse to buy crates.");
			return 1;
		}

		new countToken[16];
		GetCommandToken(cmdtext, idx, countToken, sizeof(countToken));
		new count = strval(countToken);
		if (count < 1)
		{
			SendClientMessage(playerid, -1, "Usage: /buycrates [count]");
			return 1;
		}

		new totalCost = count * COMPONENT_CRATE_COST;
		if (GetPlayerMoney(playerid) < totalCost)
		{
			SendClientMessage(playerid, -1, "You cannot afford that many crates.");
			return 1;
		}

		GivePlayerMoney(playerid, -totalCost);
		PlayerData[playerid][pCrates] += count;
		SendClientMessage(playerid, -1, "Crates purchased. Deliver them with /deliverbiz [businessId].");
		return 1;
	}

	if (!strcmp(cmd, "/deliverbiz", true))
	{
		new businessToken[16];
		GetCommandToken(cmdtext, idx, businessToken, sizeof(businessToken));
		new businessId = strval(businessToken) - 1;
		if (businessId < 0 || businessId >= MAX_BUSINESSES)
		{
			SendClientMessage(playerid, -1, "Usage: /deliverbiz [businessId]");
			return 1;
		}
		if (PlayerData[playerid][pCrates] < 1)
		{
			SendClientMessage(playerid, -1, "You have no crates to deliver.");
			return 1;
		}
		SetPlayerCheckpoint(playerid, BusinessData[businessId][bX], BusinessData[businessId][bY], BusinessData[businessId][bZ], 4.0);
		PlayerData[playerid][pHasDelivery] = true;
		PlayerData[playerid][pDeliveryBiz] = businessId;
		SendClientMessage(playerid, -1, "Delivery GPS set. Drive to the checkpoint to deliver components.");
		return 1;
	}

	if (!strcmp(cmd, "/cancelbiz", true))
	{
		ClearDeliveryCheckpoint(playerid);
		SendClientMessage(playerid, -1, "Delivery route cleared.");
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
