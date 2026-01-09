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
#define ITEM_CHAINSAW 21
#define ITEM_SLEDGEHAMMER 22
#define ITEM_SAFETY_VEST 23
#define ITEM_COAL 24
#define ITEM_BAUXITE_ORE 25
#define ITEM_IRON 26
#define ITEM_ALUMINUM 27

#define MAX_CONSTRUCTOR_OVENS 5
#define MAX_CONSTRUCTOR_FURNACES 2
#define CONSTRUCTOR_COAL_TIME_MS (5 * 60 * 1000)
#define CONSTRUCTOR_SMELT_TIME_MS 10000

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
	{"Konstrukteur", "Sammle Holz und Erz, stelle Kohle und Metall her und liefere Fahrzeuge.", -532.11, -113.46, 62.00, 0, 650}
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

new const Float:gConstructorOvens[MAX_CONSTRUCTOR_OVENS][3] =
{
	{ -526.46, -118.58, 62.00 },
	{ -528.60, -111.34, 62.00 },
	{ -522.08, -106.97, 62.00 },
	{ -515.88, -112.41, 62.00 },
	{ -518.73, -120.86, 62.00 }
};

new const Float:gConstructorFurnaces[MAX_CONSTRUCTOR_FURNACES][3] =
{
	{ -443.12, 1385.90, 35.39 },
	{ -428.65, 1401.72, 35.39 }
};

new const Float:gConstructorFactory[3] = { 1114.30, 2124.57, 10.82 };
new const Float:gConstructorDrop[3] = { 2455.93, -2113.77, 13.55 };

new gConstructorOvenPickups[MAX_CONSTRUCTOR_OVENS];
new Text3D:gConstructorOvenLabels[MAX_CONSTRUCTOR_OVENS];
new gConstructorFurnacePickups[MAX_CONSTRUCTOR_FURNACES];
new Text3D:gConstructorFurnaceLabels[MAX_CONSTRUCTOR_FURNACES];

new bool:gConstructorOvenActive[MAX_CONSTRUCTOR_OVENS];
new gConstructorOvenReadyTick[MAX_CONSTRUCTOR_OVENS];
new bool:gConstructorFurnaceActive[MAX_CONSTRUCTOR_FURNACES];
new gConstructorFurnaceReadyTick[MAX_CONSTRUCTOR_FURNACES];
new gConstructorFurnaceOutput[MAX_CONSTRUCTOR_FURNACES];
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
	for (new i = 0; i < MAX_CONSTRUCTOR_OVENS; i++)
	{
		gConstructorOvenPickups[i] = CreatePickup(19133, 1, gConstructorOvens[i][0], gConstructorOvens[i][1], gConstructorOvens[i][2]);
		gConstructorOvenLabels[i] = Create3DTextLabel("[Ofen]\nDruecke N zum Benutzen", 0xF4D03FFF, gConstructorOvens[i][0], gConstructorOvens[i][1], gConstructorOvens[i][2] + 0.7, 10.0, 0, 0);
		gConstructorOvenActive[i] = false;
		gConstructorOvenReadyTick[i] = 0;
	}
	for (new i = 0; i < MAX_CONSTRUCTOR_FURNACES; i++)
	{
		gConstructorFurnacePickups[i] = CreatePickup(1210, 1, gConstructorFurnaces[i][0], gConstructorFurnaces[i][1], gConstructorFurnaces[i][2]);
		gConstructorFurnaceLabels[i] = Create3DTextLabel("[Hochofen]\nDruecke N zum Benutzen", 0xF39C12FF, gConstructorFurnaces[i][0], gConstructorFurnaces[i][1], gConstructorFurnaces[i][2] + 0.7, 10.0, 0, 0);
		gConstructorFurnaceActive[i] = false;
		gConstructorFurnaceReadyTick[i] = 0;
		gConstructorFurnaceOutput[i] = -1;
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
	for (new i = 0; i < MAX_CONSTRUCTOR_OVENS; i++)
	{
		if (gConstructorOvenPickups[i])
		{
			DestroyPickup(gConstructorOvenPickups[i]);
			gConstructorOvenPickups[i] = 0;
		}
		if (gConstructorOvenLabels[i] != Text3D:0)
		{
			Delete3DTextLabel(gConstructorOvenLabels[i]);
			gConstructorOvenLabels[i] = Text3D:0;
		}
		gConstructorOvenActive[i] = false;
		gConstructorOvenReadyTick[i] = 0;
	}
	for (new i = 0; i < MAX_CONSTRUCTOR_FURNACES; i++)
	{
		if (gConstructorFurnacePickups[i])
		{
			DestroyPickup(gConstructorFurnacePickups[i]);
			gConstructorFurnacePickups[i] = 0;
		}
		if (gConstructorFurnaceLabels[i] != Text3D:0)
		{
			Delete3DTextLabel(gConstructorFurnaceLabels[i]);
			gConstructorFurnaceLabels[i] = Text3D:0;
		}
		gConstructorFurnaceActive[i] = false;
		gConstructorFurnaceReadyTick[i] = 0;
		gConstructorFurnaceOutput[i] = -1;
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

stock Constructor_FindNearestOven(playerid)
{
	for (new i = 0; i < MAX_CONSTRUCTOR_OVENS; i++)
	{
		if (IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorOvens[i][0], gConstructorOvens[i][1], gConstructorOvens[i][2]))
		{
			return i;
		}
	}
	return -1;
}

stock Constructor_FindNearestFurnace(playerid)
{
	for (new i = 0; i < MAX_CONSTRUCTOR_FURNACES; i++)
	{
		if (IsPlayerInRangeOfPoint(playerid, 3.0, gConstructorFurnaces[i][0], gConstructorFurnaces[i][1], gConstructorFurnaces[i][2]))
		{
			return i;
		}
	}
	return -1;
}

stock bool:Constructor_OnKeyAction(playerid)
{
	if (!PlayerData[playerid][pLogged])
	{
		return false;
	}
	new idx = Constructor_FindNearestOven(playerid);
	if (idx != -1)
	{
		if (gConstructorOvenActive[idx])
		{
			if (GetTickCount() >= gConstructorOvenReadyTick[idx])
			{
				if (!CanPlayerCarryItem(playerid, ITEM_COAL, 1))
				{
					ShowInventoryFullMessage(playerid, ITEM_COAL, 1);
					return true;
				}
				AddPlayerItem(playerid, ITEM_COAL, 1);
				gConstructorOvenActive[idx] = false;
				gConstructorOvenReadyTick[idx] = 0;
				SendClientMessage(playerid, -1, "Du hast Kohle aus dem Ofen genommen.");
			}
			else
			{
				SendClientMessage(playerid, -1, "Ofen besetzt. Kohle ist noch nicht fertig.");
			}
			return true;
		}
		if (PlayerItems[playerid][ITEM_WOOD_STACK] < 1)
		{
			SendClientMessage(playerid, -1, "Du brauchst Holz, um Kohle zu machen.");
			return true;
		}
		if (!RemovePlayerItem(playerid, ITEM_WOOD_STACK, 1))
		{
			SendClientMessage(playerid, -1, "Du hast kein Holz.");
			return true;
		}
		gConstructorOvenActive[idx] = true;
		gConstructorOvenReadyTick[idx] = GetTickCount() + CONSTRUCTOR_COAL_TIME_MS;
		SendClientMessage(playerid, -1, "Holz eingelegt. Kohle ist in 5 Minuten fertig.");
		if (gJobActive[playerid] == JOB_CONSTRUCTOR && gJobStage[playerid] == 1)
		{
			gJobStage[playerid] = 2;
			Job_StartStage(playerid);
		}
		return true;
	}

	idx = Constructor_FindNearestFurnace(playerid);
	if (idx != -1)
	{
		if (gConstructorFurnaceActive[idx])
		{
			if (GetTickCount() >= gConstructorFurnaceReadyTick[idx])
			{
				new outputItem = gConstructorFurnaceOutput[idx];
				if (!IsValidItem(outputItem))
				{
					SendClientMessage(playerid, -1, "Der Hochofen ist leer.");
					gConstructorFurnaceActive[idx] = false;
					gConstructorFurnaceReadyTick[idx] = 0;
					gConstructorFurnaceOutput[idx] = -1;
					return true;
				}
				if (!CanPlayerCarryItem(playerid, outputItem, 1))
				{
					ShowInventoryFullMessage(playerid, outputItem, 1);
					return true;
				}
				AddPlayerItem(playerid, outputItem, 1);
				gConstructorFurnaceActive[idx] = false;
				gConstructorFurnaceReadyTick[idx] = 0;
				gConstructorFurnaceOutput[idx] = -1;
				SendClientMessage(playerid, -1, "Metall aus dem Hochofen entnommen.");
				if (gJobActive[playerid] == JOB_CONSTRUCTOR && gJobStage[playerid] == 3)
				{
					gJobStage[playerid] = 4;
					Job_StartStage(playerid);
				}
			}
			else
			{
				SendClientMessage(playerid, -1, "Hochofen besetzt. Das Metall ist noch nicht fertig.");
			}
			return true;
		}
		if (PlayerItems[playerid][ITEM_COAL] < 1)
		{
			SendClientMessage(playerid, -1, "Du brauchst Kohle fuer den Hochofen.");
			return true;
		}
		new oreItem = -1;
		new outputItem = -1;
		if (PlayerItems[playerid][ITEM_IRON_ORE] > 0)
		{
			oreItem = ITEM_IRON_ORE;
			outputItem = ITEM_IRON;
		}
		else if (PlayerItems[playerid][ITEM_BAUXITE_ORE] > 0)
		{
			oreItem = ITEM_BAUXITE_ORE;
			outputItem = ITEM_ALUMINUM;
		}
		if (oreItem == -1)
		{
			SendClientMessage(playerid, -1, "Du brauchst Erz fuer den Hochofen.");
			return true;
		}
		if (!RemovePlayerItem(playerid, oreItem, 1) || !RemovePlayerItem(playerid, ITEM_COAL, 1))
		{
			SendClientMessage(playerid, -1, "Material fehlt.");
			return true;
		}
		gConstructorFurnaceActive[idx] = true;
		gConstructorFurnaceReadyTick[idx] = GetTickCount() + CONSTRUCTOR_SMELT_TIME_MS;
		gConstructorFurnaceOutput[idx] = outputItem;
		SendClientMessage(playerid, -1, "Erz eingeschmolzen. Warte kurz, dann kann das Metall entnommen werden.");
		return true;
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
				gJobTarget[playerid] = random(sizeof(gLumberSpots));
				new idx = gJobTarget[playerid];
				Job_SetCheckpoint(playerid, gLumberSpots[idx][0], gLumberSpots[idx][1], gLumberSpots[idx][2]);
				SendClientMessage(playerid, -1, "Faelle Holz an der Markierung.");
				return 1;
			}
			if (gJobStage[playerid] == 1)
			{
				Job_SetCheckpoint(playerid, gConstructorOvens[0][0], gConstructorOvens[0][1], gConstructorOvens[0][2]);
				SendClientMessage(playerid, -1, "Lege das Holz in einen Ofen.");
				return 1;
			}
			if (gJobStage[playerid] == 2)
			{
				gJobTarget[playerid] = random(sizeof(gMinerSpots));
				new idx = gJobTarget[playerid];
				Job_SetCheckpoint(playerid, gMinerSpots[idx][0], gMinerSpots[idx][1], gMinerSpots[idx][2]);
				SendClientMessage(playerid, -1, "Baue Erz an der Markierung ab.");
				return 1;
			}
			if (gJobStage[playerid] == 3)
			{
				Job_SetCheckpoint(playerid, gConstructorFurnaces[0][0], gConstructorFurnaces[0][1], gConstructorFurnaces[0][2]);
				SendClientMessage(playerid, -1, "Nutze den Hochofen (Erz + Kohle).");
				return 1;
			}
			if (gJobStage[playerid] == 4)
			{
				Job_SetCheckpoint(playerid, gConstructorFactory[0], gConstructorFactory[1], gConstructorFactory[2]);
				SendClientMessage(playerid, -1, "Bringe Aluminium zur Autofabrik.");
				return 1;
			}
			if (gJobStage[playerid] == 5)
			{
				Job_SetCheckpoint(playerid, gConstructorDrop[0], gConstructorDrop[1], gConstructorDrop[2]);
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
		if (PlayerItems[playerid][ITEM_CHAINSAW] < 1)
		{
			if (!AddPlayerItem(playerid, ITEM_CHAINSAW, 1))
			{
				ShowInventoryFullMessage(playerid, ITEM_CHAINSAW, 1);
				Job_Cancel(playerid, true);
				return 0;
			}
		}
		if (PlayerItems[playerid][ITEM_SLEDGEHAMMER] < 1)
		{
			if (!AddPlayerItem(playerid, ITEM_SLEDGEHAMMER, 1))
			{
				ShowInventoryFullMessage(playerid, ITEM_SLEDGEHAMMER, 1);
				Job_Cancel(playerid, true);
				return 0;
			}
		}
		if (PlayerItems[playerid][ITEM_SAFETY_VEST] < 1)
		{
			if (!AddPlayerItem(playerid, ITEM_SAFETY_VEST, 1))
			{
				ShowInventoryFullMessage(playerid, ITEM_SAFETY_VEST, 1);
				Job_Cancel(playerid, true);
				return 0;
			}
		}
		SendClientMessage(playerid, -1, "Ausruestung erhalten: Kettensaege, Vorschlaghammer, Warnweste.");
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
		case JOB_CONSTRUCTOR:
		{
			if (gJobStage[playerid] == 0)
			{
				if (!CanPlayerCarryItem(playerid, ITEM_WOOD_STACK, 1))
				{
					ShowInventoryFullMessage(playerid, ITEM_WOOD_STACK, 1);
					return true;
				}
				AddPlayerItem(playerid, ITEM_WOOD_STACK, 1);
				SendClientMessage(playerid, -1, "Holz gesammelt. Bring es zu den Oefen.");
				gJobStage[playerid] = 1;
				Job_StartStage(playerid);
				return true;
			}
			if (gJobStage[playerid] == 2)
			{
				new chance = random(3);
				if (chance != 0)
				{
					SendClientMessage(playerid, -1, "Kein Erz gefunden. Versuche es erneut.");
					Job_StartStage(playerid);
					return true;
				}
				new oreItem = (random(2) == 0) ? ITEM_IRON_ORE : ITEM_BAUXITE_ORE;
				if (!CanPlayerCarryItem(playerid, oreItem, 1))
				{
					ShowInventoryFullMessage(playerid, oreItem, 1);
					return true;
				}
				AddPlayerItem(playerid, oreItem, 1);
				SendClientMessage(playerid, -1, "Erz gesammelt. Gehe zum Hochofen.");
				gJobStage[playerid] = 3;
				Job_StartStage(playerid);
				return true;
			}
			if (gJobStage[playerid] == 4)
			{
				if (PlayerItems[playerid][ITEM_ALUMINUM] < 1)
				{
					SendClientMessage(playerid, -1, "Du brauchst Aluminium, um ein Fahrzeug zu bauen.");
					return true;
				}
				if (!RemovePlayerItem(playerid, ITEM_ALUMINUM, 1))
				{
					SendClientMessage(playerid, -1, "Du hast kein Aluminium.");
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
				gJobStage[playerid] = 5;
				Job_StartStage(playerid);
				return true;
			}
			if (gJobStage[playerid] == 5)
			{
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
				DestroyVehicle(gConstructorVehicle[playerid]);
				gConstructorVehicle[playerid] = INVALID_VEHICLE_ID;
				Job_Finish(playerid);
				return true;
			}
		}
	}
	return false;
}
