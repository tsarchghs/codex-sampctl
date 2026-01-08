#if defined _rp_factions_included
	#endinput
#endif
#define _rp_factions_included

#define MAX_FACTIONS 3
#define DIALOG_FACTION_STORAGE 2200

enum eFactionInfo
{
	fName[24],
	fShort[8]
};

new const gFactions[MAX_FACTIONS][eFactionInfo] =
{
	{"Stadtverwaltung", "CITY"},
	{"LSPD", "LSPD"},
	{"Logistik", "LOG"}
};

new gFactionId[MAX_PLAYERS];
new gFactionRank[MAX_PLAYERS];
new bool:gFactionDuty[MAX_PLAYERS];
new gFactionStorage[MAX_FACTIONS][MAX_ITEMS];

stock Faction_ResetPlayer(playerid)
{
	gFactionId[playerid] = -1;
	gFactionRank[playerid] = 0;
	gFactionDuty[playerid] = false;
	return 1;
}

stock Faction_Init()
{
	for (new f = 0; f < MAX_FACTIONS; f++)
	{
		for (new i = 0; i < MAX_ITEMS; i++)
		{
			gFactionStorage[f][i] = 0;
		}
	}
	if (!gDatabaseReady || g_SQL == MYSQL_INVALID_HANDLE)
	{
		return 0;
	}
	Faction_LoadStorage();
	return 1;
}

stock Faction_LoadPlayer(playerid)
{
	if (PlayerData[playerid][pAccountId] == INVALID_ACCOUNT_ID)
	{
		return 0;
	}
	new query[128];
	mysql_format(g_SQL, query, sizeof(query),
		"SELECT `faction_id`,`rank` FROM `faction_members` WHERE `account_id`=%d",
		PlayerData[playerid][pAccountId]
	);
	mysql_tquery(g_SQL, query, "OnFactionLoad", "i", playerid);
	return 1;
}

stock Faction_SavePlayer(playerid)
{
	if (PlayerData[playerid][pAccountId] == INVALID_ACCOUNT_ID)
	{
		return 0;
	}
	if (gFactionId[playerid] < 0)
	{
		new query[96];
		mysql_format(g_SQL, query, sizeof(query),
			"DELETE FROM `faction_members` WHERE `account_id`=%d",
			PlayerData[playerid][pAccountId]
		);
		mysql_tquery(g_SQL, query);
		return 1;
	}
	new query[160];
	mysql_format(g_SQL, query, sizeof(query),
		"INSERT INTO `faction_members` (`account_id`,`faction_id`,`rank`) VALUES (%d,%d,%d) ON DUPLICATE KEY UPDATE `faction_id`=VALUES(`faction_id`),`rank`=VALUES(`rank`)",
		PlayerData[playerid][pAccountId], gFactionId[playerid], gFactionRank[playerid]
	);
	mysql_tquery(g_SQL, query);
	return 1;
}

stock Faction_LoadStorage()
{
	new query[128];
	mysql_format(g_SQL, query, sizeof(query), "SELECT `faction_id`,`item_id`,`amount` FROM `faction_storage`");
	if (!gDatabaseReady || g_SQL == MYSQL_INVALID_HANDLE)
	{
		return 0;
	}
	mysql_tquery(g_SQL, query, "OnFactionStorageLoad", "");
	return 1;
}

stock Faction_SaveStorage()
{
	new query[512];
	new len = format(query, sizeof(query), "INSERT INTO `faction_storage` (`faction_id`,`item_id`,`amount`) VALUES ");
	new first = 1;
	for (new f = 0; f < MAX_FACTIONS; f++)
	{
		for (new i = 0; i < MAX_ITEMS; i++)
		{
			if (gFactionStorage[f][i] < 1)
			{
				continue;
			}
			len += format(query[len], sizeof(query) - len, "%s(%d,%d,%d)",
				first ? "" : ",", f, i, gFactionStorage[f][i]
			);
			first = 0;
		}
	}
	if (first)
	{
		return 1;
	}
	format(query[len], sizeof(query) - len,
		" ON DUPLICATE KEY UPDATE `amount`=VALUES(`amount`)"
	);
	mysql_tquery(g_SQL, query);
	return 1;
}

forward OnFactionLoad(playerid);
public OnFactionLoad(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return 0;
	}
	new rows;
	cache_get_row_count(rows);
	if (rows > 0)
	{
		cache_get_value_name_int(0, "faction_id", gFactionId[playerid]);
		cache_get_value_name_int(0, "rank", gFactionRank[playerid]);
		return 1;
	}
	gFactionId[playerid] = -1;
	gFactionRank[playerid] = 0;
	return 1;
}

forward OnFactionStorageLoad();
public OnFactionStorageLoad()
{
	new rows;
	cache_get_row_count(rows);
	for (new row = 0; row < rows; row++)
	{
		new factionid;
		new itemid;
		new amount;
		cache_get_value_name_int(row, "faction_id", factionid);
		cache_get_value_name_int(row, "item_id", itemid);
		cache_get_value_name_int(row, "amount", amount);
		if (factionid >= 0 && factionid < MAX_FACTIONS && itemid >= 0 && itemid < MAX_ITEMS)
		{
			gFactionStorage[factionid][itemid] = amount;
		}
	}
	return 1;
}

stock Faction_ShowStorage(playerid)
{
	if (gFactionId[playerid] < 0)
	{
		SendClientMessage(playerid, -1, "Du bist in keiner Fraktion.");
		return 1;
	}
	new list[768];
	list[0] = EOS;
	new itemName[MAX_ITEM_NAME];
	new hasItems = 0;
	new f = gFactionId[playerid];
	for (new i = 0; i < MAX_ITEMS; i++)
	{
		if (gFactionStorage[f][i] < 1)
		{
			continue;
		}
		hasItems = 1;
		GetItemName(i, itemName, sizeof(itemName));
		new line[64];
		format(line, sizeof(line), "%s x%d\n", itemName, gFactionStorage[f][i]);
		strcat(list, line);
	}
	if (!hasItems)
	{
		strcat(list, "(leer)\n");
	}
	ShowPlayerDialog(playerid, DIALOG_FACTION_STORAGE, DIALOG_STYLE_LIST, "Fraktionslager", list, "OK", "");
	return 1;
}

stock Faction_GetSalary(playerid)
{
	if (gFactionId[playerid] < 0)
	{
		return 0;
	}
	new base = 150;
	switch (gFactionId[playerid])
	{
		case 1: base = 250; // LSPD
		case 2: base = 200; // Logistik
	}
	return base + (gFactionRank[playerid] * 50);
}

stock bool:Faction_OnPlayerCommandText(playerid, const cmdtext[])
{
	new idx;
	new cmd[64];
	cmd = strtok(cmdtext, idx);
	if (!strlen(cmd))
	{
		return false;
	}
	if (!strcmp(cmd, "/faction", true))
	{
		if (gFactionId[playerid] < 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keiner Fraktion.");
			return true;
		}
		new msg[128];
		format(msg, sizeof(msg), "Fraktion: %s | Rang: %d | Dienst: %s", gFactions[gFactionId[playerid]][fName], gFactionRank[playerid], gFactionDuty[playerid] ? "Ja" : "Nein");
		SendClientMessage(playerid, -1, msg);
		return true;
	}
	if (!strcmp(cmd, "/dienst", true))
	{
		if (gFactionId[playerid] < 0)
		{
			SendClientMessage(playerid, -1, "Du bist in keiner Fraktion.");
			return true;
		}
		gFactionDuty[playerid] = !gFactionDuty[playerid];
		if (gFactionId[playerid] == 1)
		{
			gLspdDuty[playerid] = gFactionDuty[playerid];
		}
		SendClientMessage(playerid, -1, gFactionDuty[playerid] ? "Dienst angetreten." : "Dienst beendet.");
		return true;
	}
	if (!strcmp(cmd, "/flager", true))
	{
		Faction_ShowStorage(playerid);
		return true;
	}
	if (!strcmp(cmd, "/fdeposit", true))
	{
		new itemArg[64];
		new amountArg[64];
		itemArg = strtok(cmdtext, idx);
		amountArg = strtok(cmdtext, idx);
		new itemid = strval(itemArg);
		new amount = strval(amountArg);
		if (gFactionId[playerid] < 0 || !IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Eingabe: /fdeposit <itemid> <menge>");
			return true;
		}
		if (!RemovePlayerItem(playerid, itemid, amount))
		{
			SendClientMessage(playerid, -1, "Du hast nicht genug davon.");
			return true;
		}
		gFactionStorage[gFactionId[playerid]][itemid] += amount;
		SendClientMessage(playerid, -1, "Eingelagert.");
		return true;
	}
	if (!strcmp(cmd, "/fwithdraw", true))
	{
		new itemArg[64];
		new amountArg[64];
		itemArg = strtok(cmdtext, idx);
		amountArg = strtok(cmdtext, idx);
		new itemid = strval(itemArg);
		new amount = strval(amountArg);
		if (gFactionId[playerid] < 0 || !IsValidItem(itemid) || amount < 1)
		{
			SendClientMessage(playerid, -1, "Eingabe: /fwithdraw <itemid> <menge>");
			return true;
		}
		if (gFactionStorage[gFactionId[playerid]][itemid] < amount)
		{
			SendClientMessage(playerid, -1, "Nicht genug im Lager.");
			return true;
		}
		if (!CanPlayerCarryItem(playerid, itemid, amount))
		{
			ShowInventoryFullMessage(playerid, itemid, amount);
			return true;
		}
		gFactionStorage[gFactionId[playerid]][itemid] -= amount;
		AddPlayerItem(playerid, itemid, amount);
		SendClientMessage(playerid, -1, "Entnommen.");
		return true;
	}
	return false;
}

stock bool:Faction_OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	#pragma unused playerid
	#pragma unused response
	#pragma unused listitem
	#pragma unused inputtext
	if (dialogid == DIALOG_FACTION_STORAGE)
	{
		return true;
	}
	return false;
}

public FactionSalaryTick()
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i) || !PlayerData[i][pLogged])
		{
			continue;
		}
		if (!gFactionDuty[i])
		{
			continue;
		}
		new salary = Faction_GetSalary(i);
		if (salary > 0)
		{
			Economy_Payout(i, salary, "faction_salary");
			SendClientMessage(i, -1, "Gehalt eingegangen.");
		}
	}
	return 1;
}
