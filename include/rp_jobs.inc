#if defined _rp_jobs_included
	#endinput
#endif
#define _rp_jobs_included

#define JOB_NONE -1
#define MAX_JOBS 5
#define JOB_XP_PER_LEVEL 100
#define JOB_MAX_LEVEL 10
#define JOB_CHECKPOINT_RADIUS 4.0
#define JOB_STAGE_TIMEOUT_MS (6 * 60 * 1000)
#define JOB_DAILY_GOAL 5
#define JOB_DAILY_BONUS 350

#define DIALOG_JOB_INFO 2001
#define DIALOG_JOB_QUIT 2002
#define DIALOG_CONSTRUCTOR_BRANCH 2003

#define JOB_MINER 0
#define JOB_LUMBER 1
#define JOB_TRUCKER 2
#define JOB_FISHER 3
#define JOB_CONSTRUCTOR 4

#define ITEM_PICKAXE 12
#define ITEM_FISHING_ROD 13
#define ITEM_WOOD_STACK 14
#define ITEM_IRON_ORE 15
#define ITEM_FISH_CRATE 16
#define ITEM_TOOLKIT 17
#define ITEM_CHARCOAL 21
#define ITEM_IRON_INGOT 22
#define ITEM_BAUXITE_INGOT 23
#define ITEM_OIL_BARREL 24

#define CONSTRUCTOR_PUMP_TIME_MS (10 * 60 * 1000)

#define CONSTRUCTOR_BRANCH_NONE 0
#define CONSTRUCTOR_BRANCH_OIL 1
#define CONSTRUCTOR_BRANCH_VEHICLE 2

enum eJobInfo
{
	jobName[32],
	jobDesc[160],
	Float:jobStartX,
	Float:jobStartY,
	Float:jobStartZ,
	jobMinLevel,
	jobBasePay
};

new const gJobs[MAX_JOBS][eJobInfo] =
{
	{"Bergbau", "Baue Erz ab. Du brauchst eine Spitzhacke. Liefere die Ausbeute ab.", -433.47, 1388.67, 35.39, 0, 350},
	{"Holzfaeller", "Faelle Holz. Du brauchst Werkzeug. Liefere die Stapel zur Saege.", -532.11, -113.46, 62.00, 0, 320},
	{"Trucker", "Hole Fracht am Depot und liefere sie ab.", 2234.36, -2212.54, 13.55, 1, 550},
	{"Fischer", "Fische am Steg. Du brauchst eine Angel. Liefere den Fang ab.", 394.40, -2072.55, 7.83, 0, 300},
	{"Konstrukteur", "Sammle Holz und Erz, stelle Kohle und Metall her und entscheide dich fuer Oel oder Fahrzeuge.", -517.22, -131.67, 62.00, 0, 650}
};

new JobPickups[MAX_JOBS];
new Text3D:JobLabels[MAX_JOBS];

new gJobActive[MAX_PLAYERS];
new gJobStage[MAX_PLAYERS];
new gJobTarget[MAX_PLAYERS];
new gJobSelected[MAX_PLAYERS];
new gJobXp[MAX_PLAYERS][MAX_JOBS];
new gJobLevel[MAX_PLAYERS][MAX_JOBS];
new gJobTimer[MAX_PLAYERS];
new bool:gJobCargo[MAX_PLAYERS];

new const Float:gMinerSpots[][3] =
{
	{ -426.51, 1406.38, 35.39 },
	{ -449.06, 1417.89, 35.39 },
	{ -469.23, 1434.82, 35.39 }
};

new const Float:gLumberSpots[][3] =
{
	{ -542.14, -126.90, 62.00 },
	{ -517.22, -131.67, 62.00 },
	{ -497.11, -118.50, 62.00 }
};

new const Float:gTruckerPickup[3] = { 2231.02, -2201.62, 13.55 };
new const Float:gTruckerDrop[][3] =
{
	{ 2113.38, -1788.73, 13.55 },
	{ 1369.16, -1279.12, 13.55 },
	{ 1836.53, -1682.59, 13.33 }
};

new const Float:gFisherSpots[][3] =
{
	{ 396.12, -2083.37, 7.83 },
	{ 410.30, -2095.50, 7.83 },
	{ 381.17, -2086.33, 7.83 }
};

new const Float:gConstructorStart[3] = { -517.22, -131.67, 62.00 };
new const Float:gConstructorLumberHut[3] = { -532.11, -113.46, 62.00 };
new const Float:gConstructorCharcoalOven[3] = { -526.46, -118.58, 62.00 };
new const Float:gConstructorQuarryGear[3] = { -437.71, 1383.64, 35.39 };
new const Float:gConstructorSmelter[3] = { -428.65, 1401.72, 35.39 };
new const Float:gConstructorOilContainer[3] = { -760.32, 1548.29, 27.12 };
new const Float:gConstructorOilSpots[][3] =
{
	{ -830.14, 1596.44, 27.12 },
	{ -792.35, 1628.77, 27.12 },
	{ -856.48, 1571.90, 27.12 }
};
new const Float:gConstructorRefinery[3] = { 2071.29, -2230.48, 13.54 };
new const Float:gConstructorFactory[3] = { 1114.30, 2124.57, 10.82 };
new const Float:gConstructorVehicleDrops[][3] =
{
	{ 2455.93, -2113.77, 13.55 },
	{ 2161.45, -1970.34, 13.55 },
	{ 2040.77, -1418.61, 17.17 }
};

new gConstructorBranch[MAX_PLAYERS];
new gConstructorPumpReadyTick[MAX_PLAYERS];
new bool:gConstructorPumpPlaced[MAX_PLAYERS];
new gConstructorVehicle[MAX_PLAYERS];

stock Job_Init()
{
	for (new i = 0; i < MAX_JOBS; i++)
	{
		JobPickups[i] = CreatePickup(1239, 1, gJobs[i][jobStartX], gJobs[i][jobStartY], gJobs[i][jobStartZ]);
		new label[96];
		format(label, sizeof(label), "[%s]\nArbeitsstart: Marker betreten", gJobs[i][jobName]);
		JobLabels[i] = Create3DTextLabel(label, 0x4DD0E1FF, gJobs[i][jobStartX], gJobs[i][jobStartY], gJobs[i][jobStartZ] + 0.7, 15.0, 0, 0);
	}
	return 1;
}

stock Job_Shutdown()
{
	for (new i = 0; i < MAX_JOBS; i++)
	{
		if (JobPickups[i])
		{
			DestroyPickup(JobPickups[i]);
			JobPickups[i] = 0;
		}
		if (JobLabels[i] != Text3D:0)
		{
			Delete3DTextLabel(JobLabels[i]);
			JobLabels[i] = Text3D:0;
		}
	}
	return 1;
}

stock Job_ResetPlayer(playerid)
{
	gJobActive[playerid] = JOB_NONE;
	gJobStage[playerid] = 0;
	gJobTarget[playerid] = -1;
	gJobSelected[playerid] = -1;
	gJobCargo[playerid] = false;
	gConstructorBranch[playerid] = CONSTRUCTOR_BRANCH_NONE;
	gConstructorPumpReadyTick[playerid] = 0;
	gConstructorPumpPlaced[playerid] = false;
	if (gConstructorVehicle[playerid] != INVALID_VEHICLE_ID)
	{
		DestroyVehicle(gConstructorVehicle[playerid]);
		gConstructorVehicle[playerid] = INVALID_VEHICLE_ID;
	}
	if (gJobTimer[playerid] != 0)
	{
		KillTimer(gJobTimer[playerid]);
		gJobTimer[playerid] = 0;
	}
	for (new i = 0; i < MAX_JOBS; i++)
	{
		gJobXp[playerid][i] = 0;
		gJobLevel[playerid][i] = 0;
	}
	ClearPlayerCheckpointEx(playerid);
	return 1;
}

stock Job_LoadPlayer(playerid)
{
	if (PlayerData[playerid][pAccountId] == INVALID_ACCOUNT_ID)
	{
		return 0;
	}
	new query[128];
	mysql_format(g_SQL, query, sizeof(query),
		"SELECT `job_id`,`xp`,`level` FROM `job_progress` WHERE `account_id`=%d",
		PlayerData[playerid][pAccountId]
	);
	mysql_tquery(g_SQL, query, "OnJobDataLoad", "i", playerid);
	return 1;
}

stock Job_SavePlayer(playerid)
{
	if (PlayerData[playerid][pAccountId] == INVALID_ACCOUNT_ID)
	{
		return 0;
	}
	new query[512];
	new len = format(query, sizeof(query), "INSERT INTO `job_progress` (`account_id`,`job_id`,`xp`,`level`) VALUES ");
	for (new i = 0; i < MAX_JOBS; i++)
	{
		len += format(query[len], sizeof(query) - len, "(%d,%d,%d,%d)%s",
			PlayerData[playerid][pAccountId], i, gJobXp[playerid][i], gJobLevel[playerid][i],
			(i == MAX_JOBS - 1) ? "" : ","
		);
	}
	format(query[len], sizeof(query) - len,
		" ON DUPLICATE KEY UPDATE `xp`=VALUES(`xp`),`level`=VALUES(`level`)"
	);
	mysql_tquery(g_SQL, query);
	return 1;
}

forward OnJobDataLoad(playerid);
public OnJobDataLoad(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return 0;
	}
	for (new i = 0; i < MAX_JOBS; i++)
	{
		gJobXp[playerid][i] = 0;
		gJobLevel[playerid][i] = 0;
	}
	new rows;
	cache_get_row_count(rows);
	for (new row = 0; row < rows; row++)
	{
		new jobid;
		new xp;
		new level;
		cache_get_value_name_int(row, "job_id", jobid);
		cache_get_value_name_int(row, "xp", xp);
		cache_get_value_name_int(row, "level", level);
		if (jobid >= 0 && jobid < MAX_JOBS)
		{
			gJobXp[playerid][jobid] = xp;
			gJobLevel[playerid][jobid] = level;
		}
	}
	return 1;
}

stock Job_ShowInfoDialog(playerid, jobid)
{
	new info[256];
	new level = gJobLevel[playerid][jobid];
	format(info, sizeof(info),
		"%s\n\n%s\n\nLevel: %d | Dein Level: %d\nGrundlohn: $%d",
		gJobs[jobid][jobName], gJobs[jobid][jobDesc], gJobs[jobid][jobMinLevel], level, gJobs[jobid][jobBasePay]
	);
	ShowPlayerDialog(playerid, DIALOG_JOB_INFO, DIALOG_STYLE_MSGBOX, "Arbeit", info, "Annehmen", "Abbrechen");
	return 1;
}

stock Job_SetCheckpoint(playerid, Float:x, Float:y, Float:z)
{
	SetPlayerCheckpointEx(playerid, x, y, z, JOB_CHECKPOINT_RADIUS);
	return 1;
}

stock Job_SetStageTimeout(playerid)
{
	if (gJobTimer[playerid] != 0)
	{
		KillTimer(gJobTimer[playerid]);
		gJobTimer[playerid] = 0;
	}
	new jobid = gJobActive[playerid];
	new level = (jobid >= 0 && jobid < MAX_JOBS) ? gJobLevel[playerid][jobid] : 0;
	new timeout = JOB_STAGE_TIMEOUT_MS - (level * 15000);
	if (timeout < (3 * 60 * 1000))
	{
		timeout = (3 * 60 * 1000);
	}
	gJobTimer[playerid] = SetTimerEx("Job_StageTimeout", timeout, false, "i", playerid);
	return 1;
}

forward Job_StageTimeout(playerid);
public Job_StageTimeout(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return 0;
	}
	if (gJobActive[playerid] == JOB_NONE)
	{
		return 0;
	}
	SendClientMessage(playerid, -1, "Der Auftrag ist fehlgeschlagen (Zeit abgelaufen).");
	Job_Cancel(playerid, false);
	return 1;
}

stock Job_GetLevelXp(level)
{
	return (level + 1) * JOB_XP_PER_LEVEL;
}

stock Job_AddXP(playerid, jobid, amount)
{
	if (jobid < 0 || jobid >= MAX_JOBS)
	{
		return 0;
	}
	if (gJobLevel[playerid][jobid] < 1)
	{
		amount += amount / 2;
	}
	gJobXp[playerid][jobid] += amount;
	while (gJobLevel[playerid][jobid] < JOB_MAX_LEVEL)
	{
		new needed = Job_GetLevelXp(gJobLevel[playerid][jobid]);
		if (gJobXp[playerid][jobid] < needed)
		{
			break;
		}
		gJobXp[playerid][jobid] -= needed;
		gJobLevel[playerid][jobid] += 1;
		SendClientMessage(playerid, -1, "Job-Level aufgestiegen.");
	}
	return 1;
}

stock Job_ResetDailyIfNeeded(playerid)
{
	new year, month, day;
	getdate(year, month, day);
	if (PlayerData[playerid][pJobDailyDay] != day || PlayerData[playerid][pJobDailyMonth] != month || PlayerData[playerid][pJobDailyYear] != year)
	{
		PlayerData[playerid][pJobDailyDay] = day;
		PlayerData[playerid][pJobDailyMonth] = month;
		PlayerData[playerid][pJobDailyYear] = year;
		PlayerData[playerid][pJobDailyCount] = 0;
	}
	return 1;
}

stock Job_GetDailyGoal(playerid, jobid)
{
	new level = 0;
	if (jobid >= 0 && jobid < MAX_JOBS)
	{
		level = gJobLevel[playerid][jobid];
	}
	new goal = JOB_DAILY_GOAL + (level / 3);
	if (goal < JOB_DAILY_GOAL)
	{
		goal = JOB_DAILY_GOAL;
	}
	return goal;
}

stock Job_GetDailyBonus(playerid, jobid)
{
	new level = 0;
	if (jobid >= 0 && jobid < MAX_JOBS)
	{
		level = gJobLevel[playerid][jobid];
	}
	return JOB_DAILY_BONUS + (level * 50);
}

stock bool:Constructor_OnKeyAction(playerid)
{
	if (!PlayerData[playerid][pLogged])
	{
		return false;
	}
	if (gJobActive[playerid] != JOB_CONSTRUCTOR)
	{
		return false;
	}
	switch (gJobStage[playerid])
	{
		case 0:
		{
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorLumberHut[0], gConstructorLumberHut[1], gConstructorLumberHut[2]))
			{
				return false;
			}
			if (PlayerItems[playerid][ITEM_TOOLKIT] < 1)
			{
				if (!AddPlayerItem(playerid, ITEM_TOOLKIT, 1))
				{
					ShowInventoryFullMessage(playerid, ITEM_TOOLKIT, 1);
					return true;
				}
			}
			SendClientMessage(playerid, -1, "Werkzeug erhalten. Ab zum Holz.");
			gJobStage[playerid] = 1;
			Job_StartStage(playerid);
			return true;
		}
		case 1:
		{
			new idx = gJobTarget[playerid];
			if (idx < 0 || idx >= sizeof(gLumberSpots))
			{
				return false;
			}
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gLumberSpots[idx][0], gLumberSpots[idx][1], gLumberSpots[idx][2]))
			{
				return false;
			}
			if (!CanPlayerCarryItem(playerid, ITEM_WOOD_STACK, 1))
			{
				ShowInventoryFullMessage(playerid, ITEM_WOOD_STACK, 1);
				return true;
			}
			AddPlayerItem(playerid, ITEM_WOOD_STACK, 1);
			SendClientMessage(playerid, -1, "Holz gesammelt. Bring es zum Ofen.");
			gJobStage[playerid] = 2;
			Job_StartStage(playerid);
			return true;
		}
		case 2:
		{
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorCharcoalOven[0], gConstructorCharcoalOven[1], gConstructorCharcoalOven[2]))
			{
				return false;
			}
			if (PlayerItems[playerid][ITEM_WOOD_STACK] < 1)
			{
				SendClientMessage(playerid, -1, "Du brauchst Holz fuer die Kohle.");
				return true;
			}
			if (!RemovePlayerItem(playerid, ITEM_WOOD_STACK, 1))
			{
				SendClientMessage(playerid, -1, "Du hast kein Holz.");
				return true;
			}
			if (!CanPlayerCarryItem(playerid, ITEM_CHARCOAL, 1))
			{
				ShowInventoryFullMessage(playerid, ITEM_CHARCOAL, 1);
				AddPlayerItem(playerid, ITEM_WOOD_STACK, 1);
				return true;
			}
			AddPlayerItem(playerid, ITEM_CHARCOAL, 1);
			SendClientMessage(playerid, -1, "Kohle hergestellt. Hol dir die Grubenausruestung.");
			gJobStage[playerid] = 3;
			Job_StartStage(playerid);
			return true;
		}
		case 3:
		{
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorQuarryGear[0], gConstructorQuarryGear[1], gConstructorQuarryGear[2]))
			{
				return false;
			}
			if (PlayerItems[playerid][ITEM_PICKAXE] < 1)
			{
				if (!AddPlayerItem(playerid, ITEM_PICKAXE, 1))
				{
					ShowInventoryFullMessage(playerid, ITEM_PICKAXE, 1);
					return true;
				}
			}
			SendClientMessage(playerid, -1, "Spitzhacke erhalten. Ab zur Mine.");
			gJobStage[playerid] = 4;
			Job_StartStage(playerid);
			return true;
		}
		case 4:
		{
			new idx = gJobTarget[playerid];
			if (idx < 0 || idx >= sizeof(gMinerSpots))
			{
				return false;
			}
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gMinerSpots[idx][0], gMinerSpots[idx][1], gMinerSpots[idx][2]))
			{
				return false;
			}
			if (!CanPlayerCarryItem(playerid, ITEM_IRON_ORE, 1))
			{
				ShowInventoryFullMessage(playerid, ITEM_IRON_ORE, 1);
				return true;
			}
			AddPlayerItem(playerid, ITEM_IRON_ORE, 1);
			SendClientMessage(playerid, -1, "Erz gesammelt. Bringe es zum Hochofen.");
			gJobStage[playerid] = 5;
			Job_StartStage(playerid);
			return true;
		}
		case 5:
		{
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorSmelter[0], gConstructorSmelter[1], gConstructorSmelter[2]))
			{
				return false;
			}
			if (PlayerItems[playerid][ITEM_IRON_ORE] < 1 || PlayerItems[playerid][ITEM_CHARCOAL] < 1)
			{
				SendClientMessage(playerid, -1, "Du brauchst Erz und Kohle.");
				return true;
			}
			if (!RemovePlayerItem(playerid, ITEM_IRON_ORE, 1) || !RemovePlayerItem(playerid, ITEM_CHARCOAL, 1))
			{
				SendClientMessage(playerid, -1, "Material fehlt.");
				return true;
			}
			if (!CanPlayerCarryItem(playerid, ITEM_IRON_INGOT, 1))
			{
				ShowInventoryFullMessage(playerid, ITEM_IRON_INGOT, 1);
				AddPlayerItem(playerid, ITEM_IRON_ORE, 1);
				AddPlayerItem(playerid, ITEM_CHARCOAL, 1);
				return true;
			}
			AddPlayerItem(playerid, ITEM_IRON_INGOT, 1);
			SendClientMessage(playerid, -1, "Eisenbarren hergestellt. Waehle deinen Weg.");
			gJobStage[playerid] = 6;
			ShowPlayerDialog(playerid, DIALOG_CONSTRUCTOR_BRANCH, DIALOG_STYLE_LIST, "Konstrukteur", "Oel\nFahrzeug", "Waehlen", "Abbrechen");
			return true;
		}
		case 7:
		{
			if (gConstructorBranch[playerid] != CONSTRUCTOR_BRANCH_OIL)
			{
				return false;
			}
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorOilContainer[0], gConstructorOilContainer[1], gConstructorOilContainer[2]))
			{
				return false;
			}
			if (PlayerItems[playerid][ITEM_IRON_INGOT] < 3)
			{
				SendClientMessage(playerid, -1, "Du brauchst 3 Eisenbarren fuer die Oelpumpe.");
				return true;
			}
			if (!RemovePlayerItem(playerid, ITEM_IRON_INGOT, 3))
			{
				SendClientMessage(playerid, -1, "Du hast nicht genug Eisenbarren.");
				return true;
			}
			SendClientMessage(playerid, -1, "Oelpumpe erhalten. Platziere sie im Oelfeld.");
			gJobStage[playerid] = 8;
			Job_StartStage(playerid);
			return true;
		}
		case 8:
		{
			if (gConstructorBranch[playerid] != CONSTRUCTOR_BRANCH_OIL)
			{
				return false;
			}
			new idx = gJobTarget[playerid];
			if (idx < 0 || idx >= sizeof(gConstructorOilSpots))
			{
				return false;
			}
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorOilSpots[idx][0], gConstructorOilSpots[idx][1], gConstructorOilSpots[idx][2]))
			{
				return false;
			}
			gConstructorPumpReadyTick[playerid] = GetTickCount() + CONSTRUCTOR_PUMP_TIME_MS;
			gConstructorPumpPlaced[playerid] = true;
			SendClientMessage(playerid, -1, "Oelpumpe platziert. Warte 10 Minuten.");
			gJobStage[playerid] = 9;
			Job_StartStage(playerid);
			return true;
		}
		case 9:
		{
			if (gConstructorBranch[playerid] != CONSTRUCTOR_BRANCH_OIL)
			{
				return false;
			}
			new idx = gJobTarget[playerid];
			if (idx < 0 || idx >= sizeof(gConstructorOilSpots))
			{
				return false;
			}
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorOilSpots[idx][0], gConstructorOilSpots[idx][1], gConstructorOilSpots[idx][2]))
			{
				return false;
			}
			if (!gConstructorPumpPlaced[playerid] || GetTickCount() < gConstructorPumpReadyTick[playerid])
			{
				SendClientMessage(playerid, -1, "Die Pumpe ist noch nicht fertig.");
				return true;
			}
			if (!CanPlayerCarryItem(playerid, ITEM_OIL_BARREL, 1))
			{
				ShowInventoryFullMessage(playerid, ITEM_OIL_BARREL, 1);
				return true;
			}
			AddPlayerItem(playerid, ITEM_OIL_BARREL, 1);
			SendClientMessage(playerid, -1, "Oelfass aufgenommen. Bring es zur Raffinerie.");
			gJobStage[playerid] = 10;
			Job_StartStage(playerid);
			return true;
		}
		case 10:
		{
			if (gConstructorBranch[playerid] != CONSTRUCTOR_BRANCH_OIL)
			{
				return false;
			}
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorRefinery[0], gConstructorRefinery[1], gConstructorRefinery[2]))
			{
				return false;
			}
			if (PlayerItems[playerid][ITEM_OIL_BARREL] < 1)
			{
				SendClientMessage(playerid, -1, "Du brauchst ein Oelfass.");
				return true;
			}
			if (!RemovePlayerItem(playerid, ITEM_OIL_BARREL, 1))
			{
				SendClientMessage(playerid, -1, "Kein Oelfass vorhanden.");
				return true;
			}
			Economy_Payout(playerid, 15000, "constructor_oil");
			SendClientMessage(playerid, -1, "Oel verkauft. Auftrag abgeschlossen.");
			Job_Finish(playerid);
			return true;
		}
		case 11:
		{
			if (gConstructorBranch[playerid] != CONSTRUCTOR_BRANCH_VEHICLE)
			{
				return false;
			}
			if (!IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorFactory[0], gConstructorFactory[1], gConstructorFactory[2]))
			{
				return false;
			}
			if (PlayerItems[playerid][ITEM_BAUXITE_INGOT] < 10)
			{
				SendClientMessage(playerid, -1, "Du brauchst 10 Bauxitbarren.");
				return true;
			}
			if (!RemovePlayerItem(playerid, ITEM_BAUXITE_INGOT, 10))
			{
				SendClientMessage(playerid, -1, "Du hast nicht genug Bauxitbarren.");
				return true;
			}
			if (gConstructorVehicle[playerid] != INVALID_VEHICLE_ID)
			{
				DestroyVehicle(gConstructorVehicle[playerid]);
				gConstructorVehicle[playerid] = INVALID_VEHICLE_ID;
			}
			gConstructorVehicle[playerid] = CreateVehicle(411, gConstructorFactory[0] + 2.0, gConstructorFactory[1], gConstructorFactory[2], 0.0, -1, -1, 0);
			PutPlayerInVehicle(playerid, gConstructorVehicle[playerid], 0);
			SendClientMessage(playerid, -1, "Fahrzeug gebaut. Liefere es nach Los Santos.");
			gJobTarget[playerid] = random(sizeof(gConstructorVehicleDrops));
			gJobStage[playerid] = 12;
			Job_StartStage(playerid);
			return true;
		}
		case 12:
		{
			if (gConstructorBranch[playerid] != CONSTRUCTOR_BRANCH_VEHICLE)
			{
				return false;
			}
			new idx = gJobTarget[playerid];
			if (idx < 0 || idx >= sizeof(gConstructorVehicleDrops))
			{
				return false;
			}
			if (!IsPlayerInRangeOfPoint(playerid, 4.0, gConstructorVehicleDrops[idx][0], gConstructorVehicleDrops[idx][1], gConstructorVehicleDrops[idx][2]))
			{
				return false;
			}
			if (gConstructorVehicle[playerid] == INVALID_VEHICLE_ID)
			{
				SendClientMessage(playerid, -1, "Du hast kein Fahrzeug zum Liefern.");
				return true;
			}
			if (GetPlayerVehicleID(playerid) != gConstructorVehicle[playerid])
			{
				SendClientMessage(playerid, -1, "Du musst das hergestellte Fahrzeug liefern.");
				return true;
			}
			new Float:health;
			GetVehicleHealth(gConstructorVehicle[playerid], health);
			new payout = (health >= 800.0) ? 20000 : 12000;
			Economy_Payout(playerid, payout, "constructor_vehicle");
			DestroyVehicle(gConstructorVehicle[playerid]);
			gConstructorVehicle[playerid] = INVALID_VEHICLE_ID;
			SendClientMessage(playerid, -1, "Fahrzeug geliefert. Auftrag abgeschlossen.");
			Job_Finish(playerid);
			return true;
		}
	}
	return false;
}

stock Job_StartStage(playerid)
{
	new jobid = gJobActive[playerid];
	Job_SetStageTimeout(playerid);
	switch (jobid)
	{
		case JOB_MINER:
		{
			if (gJobStage[playerid] == 0)
			{
				if (PlayerItems[playerid][ITEM_PICKAXE] < 1)
				{
					SendClientMessage(playerid, -1, "Du brauchst eine Spitzhacke.");
					Job_Cancel(playerid, true);
					return 1;
				}
				gJobTarget[playerid] = random(sizeof(gMinerSpots));
				new idx = gJobTarget[playerid];
				Job_SetCheckpoint(playerid, gMinerSpots[idx][0], gMinerSpots[idx][1], gMinerSpots[idx][2]);
				SendClientMessage(playerid, -1, "Baue Erz an der Markierung ab.");
				return 1;
			}
			Job_SetCheckpoint(playerid, gJobs[jobid][jobStartX], gJobs[jobid][jobStartY], gJobs[jobid][jobStartZ]);
			SendClientMessage(playerid, -1, "Liefere das Erz am Depot ab.");
		}
		case JOB_LUMBER:
		{
			if (gJobStage[playerid] == 0)
			{
				if (PlayerItems[playerid][ITEM_TOOLKIT] < 1)
				{
					SendClientMessage(playerid, -1, "Du brauchst Werkzeug.");
					Job_Cancel(playerid, true);
					return 1;
				}
				gJobTarget[playerid] = random(sizeof(gLumberSpots));
				new idx = gJobTarget[playerid];
				Job_SetCheckpoint(playerid, gLumberSpots[idx][0], gLumberSpots[idx][1], gLumberSpots[idx][2]);
				SendClientMessage(playerid, -1, "Faelle Holz an der Markierung.");
				return 1;
			}
			Job_SetCheckpoint(playerid, gJobs[jobid][jobStartX], gJobs[jobid][jobStartY], gJobs[jobid][jobStartZ]);
			SendClientMessage(playerid, -1, "Bringe das Holz zur Saege.");
		}
		case JOB_TRUCKER:
		{
			if (gJobStage[playerid] == 0)
			{
				Job_SetCheckpoint(playerid, gTruckerPickup[0], gTruckerPickup[1], gTruckerPickup[2]);
				SendClientMessage(playerid, -1, "Hole die Fracht am Depot.");
				return 1;
			}
			gJobTarget[playerid] = random(sizeof(gTruckerDrop));
			new idx = gJobTarget[playerid];
			Job_SetCheckpoint(playerid, gTruckerDrop[idx][0], gTruckerDrop[idx][1], gTruckerDrop[idx][2]);
			SendClientMessage(playerid, -1, "Liefere die Fracht ab.");
		}
		case JOB_FISHER:
		{
			if (gJobStage[playerid] == 0)
			{
				if (PlayerItems[playerid][ITEM_FISHING_ROD] < 1)
				{
					SendClientMessage(playerid, -1, "Du brauchst eine Angel.");
					Job_Cancel(playerid, true);
					return 1;
				}
				gJobTarget[playerid] = random(sizeof(gFisherSpots));
				new idx = gJobTarget[playerid];
				Job_SetCheckpoint(playerid, gFisherSpots[idx][0], gFisherSpots[idx][1], gFisherSpots[idx][2]);
				SendClientMessage(playerid, -1, "Fische an der Markierung.");
				return 1;
			}
			Job_SetCheckpoint(playerid, gJobs[jobid][jobStartX], gJobs[jobid][jobStartY], gJobs[jobid][jobStartZ]);
			SendClientMessage(playerid, -1, "Bringe den Fang zum Markt.");
		}
		case JOB_CONSTRUCTOR:
		{
			if (gJobStage[playerid] == 0)
			{
				Job_SetCheckpoint(playerid, gConstructorLumberHut[0], gConstructorLumberHut[1], gConstructorLumberHut[2]);
				SendClientMessage(playerid, -1, "Hol dir Werkzeug an der Huette.");
				return 1;
			}
			if (gJobStage[playerid] == 1)
			{
				gJobTarget[playerid] = random(sizeof(gLumberSpots));
				new idx = gJobTarget[playerid];
				Job_SetCheckpoint(playerid, gLumberSpots[idx][0], gLumberSpots[idx][1], gLumberSpots[idx][2]);
				SendClientMessage(playerid, -1, "Faelle Holz an der Markierung.");
				return 1;
			}
			if (gJobStage[playerid] == 2)
			{
				Job_SetCheckpoint(playerid, gConstructorCharcoalOven[0], gConstructorCharcoalOven[1], gConstructorCharcoalOven[2]);
				SendClientMessage(playerid, -1, "Brenne Holz zu Kohle.");
				return 1;
			}
			if (gJobStage[playerid] == 3)
			{
				Job_SetCheckpoint(playerid, gConstructorQuarryGear[0], gConstructorQuarryGear[1], gConstructorQuarryGear[2]);
				SendClientMessage(playerid, -1, "Hol dir die Grubenausruestung.");
				return 1;
			}
			if (gJobStage[playerid] == 4)
			{
				gJobTarget[playerid] = random(sizeof(gMinerSpots));
				new idx = gJobTarget[playerid];
				Job_SetCheckpoint(playerid, gMinerSpots[idx][0], gMinerSpots[idx][1], gMinerSpots[idx][2]);
				SendClientMessage(playerid, -1, "Baue Erz an der Markierung ab.");
				return 1;
			}
			if (gJobStage[playerid] == 5)
			{
				Job_SetCheckpoint(playerid, gConstructorSmelter[0], gConstructorSmelter[1], gConstructorSmelter[2]);
				SendClientMessage(playerid, -1, "Schmelze Erz und Kohle.");
				return 1;
			}
			if (gJobStage[playerid] == 7)
			{
				Job_SetCheckpoint(playerid, gConstructorOilContainer[0], gConstructorOilContainer[1], gConstructorOilContainer[2]);
				SendClientMessage(playerid, -1, "Hole dir eine Oelpumpe.");
				return 1;
			}
			if (gJobStage[playerid] == 8)
			{
				gJobTarget[playerid] = random(sizeof(gConstructorOilSpots));
				new idx = gJobTarget[playerid];
				Job_SetCheckpoint(playerid, gConstructorOilSpots[idx][0], gConstructorOilSpots[idx][1], gConstructorOilSpots[idx][2]);
				SendClientMessage(playerid, -1, "Platziere die Oelpumpe im Oelfeld.");
				return 1;
			}
			if (gJobStage[playerid] == 9)
			{
				Job_SetCheckpoint(playerid, gConstructorOilSpots[gJobTarget[playerid]][0], gConstructorOilSpots[gJobTarget[playerid]][1], gConstructorOilSpots[gJobTarget[playerid]][2]);
				SendClientMessage(playerid, -1, "Warte und sammle das Oel ein.");
				return 1;
			}
			if (gJobStage[playerid] == 10)
			{
				Job_SetCheckpoint(playerid, gConstructorRefinery[0], gConstructorRefinery[1], gConstructorRefinery[2]);
				SendClientMessage(playerid, -1, "Bringe das Oel zur Raffinerie.");
				return 1;
			}
			if (gJobStage[playerid] == 11)
			{
				Job_SetCheckpoint(playerid, gConstructorFactory[0], gConstructorFactory[1], gConstructorFactory[2]);
				SendClientMessage(playerid, -1, "Baue ein Fahrzeug in der Fabrik.");
				return 1;
			}
			if (gJobStage[playerid] == 12)
			{
				Job_SetCheckpoint(playerid, gConstructorVehicleDrops[gJobTarget[playerid]][0], gConstructorVehicleDrops[gJobTarget[playerid]][1], gConstructorVehicleDrops[gJobTarget[playerid]][2]);
				SendClientMessage(playerid, -1, "Liefere das Fahrzeug nach Los Santos.");
				return 1;
			}
		}
	}
	return 1;
}

stock Job_Finish(playerid)
{
	new jobid = gJobActive[playerid];
	ClearPlayerCheckpointEx(playerid);
	new base = gJobs[jobid][jobBasePay];
	new bonus = gJobLevel[playerid][jobid] * 50;
	new payout = base + bonus;
	Economy_Payout(playerid, payout, "job_payout");
	Job_AddXP(playerid, jobid, 35 + gJobLevel[playerid][jobid] * 5);
	Job_ResetDailyIfNeeded(playerid);
	PlayerData[playerid][pJobDailyCount] += 1;
	new goal = Job_GetDailyGoal(playerid, jobid);
	if (PlayerData[playerid][pJobDailyCount] == goal)
	{
		new dailyBonus = Job_GetDailyBonus(playerid, jobid);
		Economy_Payout(playerid, dailyBonus, "job_daily");
		SendClientMessage(playerid, -1, "Tagesziel erreicht! Bonus ausgezahlt.");
	}
	new msg[96];
	format(msg, sizeof(msg), "Auftrag erledigt! Du erhaelst $%d.", payout);
	SendClientMessage(playerid, -1, msg);
	Activity_Mark(playerid, ACTIVITY_JOB);
	Job_Cancel(playerid, false);
	return 1;
}

stock Job_Cancel(playerid, bool:notify)
{
	if (gJobActive[playerid] == JOB_NONE)
	{
		return 0;
	}
	ClearPlayerCheckpointEx(playerid);
	if (gJobTimer[playerid] != 0)
	{
		KillTimer(gJobTimer[playerid]);
		gJobTimer[playerid] = 0;
	}
	if (gConstructorVehicle[playerid] != INVALID_VEHICLE_ID)
	{
		DestroyVehicle(gConstructorVehicle[playerid]);
		gConstructorVehicle[playerid] = INVALID_VEHICLE_ID;
	}
	gConstructorBranch[playerid] = CONSTRUCTOR_BRANCH_NONE;
	gConstructorPumpReadyTick[playerid] = 0;
	gConstructorPumpPlaced[playerid] = false;
	gJobActive[playerid] = JOB_NONE;
	gJobStage[playerid] = 0;
	gJobTarget[playerid] = -1;
	gJobCargo[playerid] = false;
	if (notify)
	{
		SendClientMessage(playerid, -1, "Auftrag abgebrochen.");
	}
	return 1;
}

stock Job_Start(playerid, jobid)
{
	if (gJobActive[playerid] != JOB_NONE)
	{
		SendClientMessage(playerid, -1, "Du hast bereits einen Auftrag.");
		return 0;
	}
	Job_ResetDailyIfNeeded(playerid);
	if (PlayerData[playerid][pHasDelivery])
	{
		SendClientMessage(playerid, -1, "Beende zuerst deine Lieferung.");
		return 0;
	}
	new minLevel = gJobs[jobid][jobMinLevel];
	if (gJobLevel[playerid][jobid] < minLevel)
	{
		SendClientMessage(playerid, -1, "Du erfuellst die Level-Anforderung nicht.");
		return 0;
	}
	gJobActive[playerid] = jobid;
	gJobStage[playerid] = 0;
	gJobTarget[playerid] = -1;
	if (jobid == JOB_CONSTRUCTOR)
	{
		gConstructorBranch[playerid] = CONSTRUCTOR_BRANCH_NONE;
		gConstructorPumpReadyTick[playerid] = 0;
		gConstructorPumpPlaced[playerid] = false;
	}
	Job_StartStage(playerid);
	return 1;
}

stock bool:Job_OnPlayerCommandText(playerid, const cmdtext[])
{
	new idx;
	new cmd[64];
	cmd = strtok(cmdtext, idx);
	if (!strlen(cmd))
	{
		return false;
	}
	if (!strcmp(cmd, "/arbeit", true) || !strcmp(cmd, "/job", true))
	{
		for (new i = 0; i < MAX_JOBS; i++)
		{
			if (IsPlayerInRangeOfPoint(playerid, 3.0, gJobs[i][jobStartX], gJobs[i][jobStartY], gJobs[i][jobStartZ]))
			{
				gJobSelected[playerid] = i;
				Job_ShowInfoDialog(playerid, i);
				return true;
			}
		}
		SendClientMessage(playerid, -1, "Sprich mit dem Vorarbeiter am Job-Punkt.");
		return true;
	}
	if (!strcmp(cmd, "/jobdaily", true) || !strcmp(cmd, "/tagesziel", true))
	{
		if (!PlayerData[playerid][pLogged])
		{
			SendClientMessage(playerid, -1, "Logge dich zuerst ein.");
			return true;
		}
		Job_ResetDailyIfNeeded(playerid);
		new bestJob = 0;
		for (new i = 1; i < MAX_JOBS; i++)
		{
			if (gJobLevel[playerid][i] > gJobLevel[playerid][bestJob])
			{
				bestJob = i;
			}
		}
		new goal = Job_GetDailyGoal(playerid, bestJob);
		new bonusAmount = Job_GetDailyBonus(playerid, bestJob);
		new msg[128];
		format(msg, sizeof(msg), "Tagesziel: %d/%d Jobs. Bonus: $%d.", PlayerData[playerid][pJobDailyCount], goal, bonusAmount);
		SendClientMessage(playerid, -1, msg);
		return true;
	}
	if (!strcmp(cmd, "/fisch", true) || !strcmp(cmd, "/fischen", true) || !strcmp(cmd, "/fishing", true))
	{
		if (!PlayerData[playerid][pLogged])
		{
			SendClientMessage(playerid, -1, "Logge dich zuerst ein.");
			return true;
		}
		if (!IsPlayerInRangeOfPoint(playerid, 3.0, gJobs[JOB_FISHER][jobStartX], gJobs[JOB_FISHER][jobStartY], gJobs[JOB_FISHER][jobStartZ]))
		{
			SendClientMessage(playerid, -1, "Du musst am Steg sein, um zu fischen.");
			return true;
		}
		gJobSelected[playerid] = JOB_FISHER;
		Job_ShowInfoDialog(playerid, JOB_FISHER);
		return true;
	}
	if (!strcmp(cmd, "/jobquit", true) || !strcmp(cmd, "/quitjob", true) || !strcmp(cmd, "/jobabbruch", true))
	{
		if (gJobActive[playerid] == JOB_NONE)
		{
			SendClientMessage(playerid, -1, "Du hast keinen Auftrag.");
			return true;
		}
		ShowPlayerDialog(playerid, DIALOG_JOB_QUIT, DIALOG_STYLE_MSGBOX, "Auftrag abbrechen", "Auftrag wirklich abbrechen?", "Ja", "Nein");
		return true;
	}
	return false;
}

stock bool:Job_OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	#pragma unused inputtext
	#pragma unused listitem
	if (dialogid == DIALOG_JOB_INFO)
	{
		if (!response)
		{
			return true;
		}
		if (gJobSelected[playerid] < 0 || gJobSelected[playerid] >= MAX_JOBS)
		{
			return true;
		}
		Job_Start(playerid, gJobSelected[playerid]);
		return true;
	}
	if (dialogid == DIALOG_JOB_QUIT)
	{
		if (response)
		{
			Job_Cancel(playerid, true);
		}
		return true;
	}
	if (dialogid == DIALOG_CONSTRUCTOR_BRANCH)
	{
		if (!response)
		{
			Job_Cancel(playerid, true);
			return true;
		}
		if (gJobActive[playerid] != JOB_CONSTRUCTOR)
		{
			return true;
		}
		if (listitem == 0)
		{
			gConstructorBranch[playerid] = CONSTRUCTOR_BRANCH_OIL;
			gJobStage[playerid] = 7;
		}
		else
		{
			gConstructorBranch[playerid] = CONSTRUCTOR_BRANCH_VEHICLE;
			gJobStage[playerid] = 11;
		}
		Job_StartStage(playerid);
		return true;
	}
	return false;
}

stock bool:Job_OnPlayerPickUpPickup(playerid, pickupid)
{
	for (new i = 0; i < MAX_JOBS; i++)
	{
		if (pickupid == JobPickups[i])
		{
			if (!PlayerData[playerid][pLogged])
			{
				SendClientMessage(playerid, -1, "Logge dich ein, um zu arbeiten.");
				return true;
			}
			gJobSelected[playerid] = i;
			Job_ShowInfoDialog(playerid, i);
			return true;
		}
	}
	return false;
}

stock bool:Job_OnPlayerEnterCheckpoint(playerid)
{
	if (gJobActive[playerid] == JOB_NONE)
	{
		return false;
	}
	new jobid = gJobActive[playerid];
	switch (jobid)
	{
		case JOB_MINER:
		{
			if (gJobStage[playerid] == 0)
			{
				if (!CanPlayerCarryItem(playerid, ITEM_IRON_ORE, 1))
				{
					ShowInventoryFullMessage(playerid, ITEM_IRON_ORE, 1);
					return true;
				}
				AddPlayerItem(playerid, ITEM_IRON_ORE, 1);
				SendClientMessage(playerid, -1, "Erz gesammelt.");
				gJobStage[playerid] = 1;
				Job_StartStage(playerid);
				return true;
			}
			Job_Finish(playerid);
			return true;
		}
		case JOB_LUMBER:
		{
			if (gJobStage[playerid] == 0)
			{
				if (!CanPlayerCarryItem(playerid, ITEM_WOOD_STACK, 1))
				{
					ShowInventoryFullMessage(playerid, ITEM_WOOD_STACK, 1);
					return true;
				}
				AddPlayerItem(playerid, ITEM_WOOD_STACK, 1);
				SendClientMessage(playerid, -1, "Holz gesammelt.");
				gJobStage[playerid] = 1;
				Job_StartStage(playerid);
				return true;
			}
			Job_Finish(playerid);
			return true;
		}
		case JOB_TRUCKER:
		{
			if (gJobStage[playerid] == 0)
			{
				gJobCargo[playerid] = true;
				SendClientMessage(playerid, -1, "Fracht aufgenommen.");
				gJobStage[playerid] = 1;
				Job_StartStage(playerid);
				return true;
			}
			if (!gJobCargo[playerid])
			{
				SendClientMessage(playerid, -1, "Keine Fracht geladen.");
				return true;
			}
			Job_Finish(playerid);
			return true;
		}
		case JOB_FISHER:
		{
			if (gJobStage[playerid] == 0)
			{
				if (!CanPlayerCarryItem(playerid, ITEM_FISH_CRATE, 1))
				{
					ShowInventoryFullMessage(playerid, ITEM_FISH_CRATE, 1);
					return true;
				}
				AddPlayerItem(playerid, ITEM_FISH_CRATE, 1);
				SendClientMessage(playerid, -1, "Fang aufgenommen.");
				gJobStage[playerid] = 1;
				Job_StartStage(playerid);
				return true;
			}
			Job_Finish(playerid);
			return true;
		}
		}
	return false;
}
