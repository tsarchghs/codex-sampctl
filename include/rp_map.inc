#if defined _rp_map_included
	#endinput
#endif
#define _rp_map_included

#define MAX_MAP_POINTS 64
#define DIALOG_MAP 2300
#define DIALOG_GPS 2301

#define MAP_TOGGLE_JOBS (1 << 0)
#define MAP_TOGGLE_BUSINESS (1 << 1)
#define MAP_TOGGLE_LOGISTICS (1 << 2)
#define MAP_TOGGLE_CINEMA (1 << 3)
#define MAP_TOGGLE_TELEPORTS (1 << 4)

enum eMapCategory
{
	MAP_JOBS,
	MAP_BUSINESS,
	MAP_LOGISTICS,
	MAP_CINEMA,
	MAP_TELEPORTS
};

enum eMapPoint
{
	mapName[32],
	Float:mapX,
	Float:mapY,
	Float:mapZ,
	mapIcon,
	mapColor,
	mapInterior,
	mapWorld,
	mapCategory,
	mapData
};

new gMapPoints[MAX_MAP_POINTS][eMapPoint];
new gMapPointCount = 0;
new gMapToggle[MAX_PLAYERS];
new gMapGpsIndex[MAX_PLAYERS][MAX_MAP_POINTS];

stock Map_ResetPlayer(playerid)
{
	gMapToggle[playerid] = MAP_TOGGLE_JOBS | MAP_TOGGLE_BUSINESS | MAP_TOGGLE_LOGISTICS | MAP_TOGGLE_CINEMA | MAP_TOGGLE_TELEPORTS;
	for (new i = 0; i < MAX_MAP_POINTS; i++)
	{
		gMapGpsIndex[playerid][i] = -1;
	}
	return 1;
}

stock Map_AddPoint(const name[], Float:x, Float:y, Float:z, icon, color, interior, world, category, data)
{
	if (gMapPointCount >= MAX_MAP_POINTS)
	{
		return 0;
	}
	format(gMapPoints[gMapPointCount][mapName], 32, "%s", name);
	gMapPoints[gMapPointCount][mapX] = x;
	gMapPoints[gMapPointCount][mapY] = y;
	gMapPoints[gMapPointCount][mapZ] = z;
	gMapPoints[gMapPointCount][mapIcon] = icon;
	gMapPoints[gMapPointCount][mapColor] = color;
	gMapPoints[gMapPointCount][mapInterior] = interior;
	gMapPoints[gMapPointCount][mapWorld] = world;
	gMapPoints[gMapPointCount][mapCategory] = category;
	gMapPoints[gMapPointCount][mapData] = data;
	gMapPointCount++;
	return 1;
}

stock Map_BuildStatic()
{
	Map_AddPoint("Warehouse", COMPONENT_WAREHOUSE_X, COMPONENT_WAREHOUSE_Y, COMPONENT_WAREHOUSE_Z, 27, 0xFFCC00FF, 0, 0, MAP_LOGISTICS, -1);
	Map_AddPoint("Garage", GARAGE_X, GARAGE_Y, GARAGE_Z, 55, 0x4DD0E1FF, 0, 0, MAP_LOGISTICS, -1);
	Map_AddPoint("Chop Shop", CHOP_X, CHOP_Y, CHOP_Z, 53, 0xFF4444FF, 0, 0, MAP_LOGISTICS, -1);
	Map_AddPoint("Cinema", CINEMA_POINT_X, CINEMA_POINT_Y, CINEMA_POINT_Z, 48, 0xAA77FFFF, 0, 0, MAP_CINEMA, -1);
	return 1;
}

stock Map_BuildJobs()
{
	for (new i = 0; i < MAX_JOBS; i++)
	{
		Map_AddPoint(gJobs[i][jobName], gJobs[i][jobStartX], gJobs[i][jobStartY], gJobs[i][jobStartZ], 56, 0x00C2FFFF, 0, 0, MAP_JOBS, i);
	}
	return 1;
}

stock Map_GetBusinessIcon(BusinessType:type)
{
	switch (type)
	{
		case BUSINESS_AMMUNATION: return 6;
		case BUSINESS_CLOTHING: return 45;
		case BUSINESS_247: return 17;
		case BUSINESS_BARBERSHOP: return 7;
		case BUSINESS_BEAUTY_SALON: return 20;
		case BUSINESS_PLASTIC_SURGEON: return 26;
	}
	return 52;
}

stock Map_BuildBusinesses()
{
	for (new i = 0; i < MAX_BUSINESSES; i++)
	{
		new icon = Map_GetBusinessIcon(BusinessData[i][bType]);
		Map_AddPoint(gBusinessTypeNames[_:BusinessData[i][bType]], BusinessData[i][bX], BusinessData[i][bY], BusinessData[i][bZ], icon, 0x33CC33FF, 0, 0, MAP_BUSINESS, i);
	}
	return 1;
}

stock Map_BuildTeleports()
{
	for (new i = 0; i < sizeof(gTeleports); i++)
	{
		new interior = gTeleports[i][tEntry][tInterior];
		new world = gTeleports[i][tEntry][tWorld];
		if (world != 0)
		{
			continue;
		}
		Map_AddPoint("Property", gTeleports[i][tEntry][tX], gTeleports[i][tEntry][tY], gTeleports[i][tEntry][tZ], 31, 0xFFFFFFFF, interior, world, MAP_TELEPORTS, i);
	}
	return 1;
}

stock Map_Init()
{
	gMapPointCount = 0;
	Map_BuildStatic();
	Map_BuildJobs();
	Map_BuildBusinesses();
	Map_BuildTeleports();
	return 1;
}

stock Map_ClearIcons(playerid)
{
	for (new i = 0; i < gMapPointCount; i++)
	{
		RemovePlayerMapIcon(playerid, i);
	}
	return 1;
}

stock Map_ShouldShow(playerid, idx)
{
	new cat = gMapPoints[idx][mapCategory];
	switch (cat)
	{
		case MAP_JOBS: return (gMapToggle[playerid] & MAP_TOGGLE_JOBS) != 0;
		case MAP_BUSINESS: return (gMapToggle[playerid] & MAP_TOGGLE_BUSINESS) != 0;
		case MAP_LOGISTICS: return (gMapToggle[playerid] & MAP_TOGGLE_LOGISTICS) != 0;
		case MAP_CINEMA: return (gMapToggle[playerid] & MAP_TOGGLE_CINEMA) != 0;
		case MAP_TELEPORTS: return (gMapToggle[playerid] & MAP_TOGGLE_TELEPORTS) != 0;
	}
	return false;
}

stock Map_RebuildForPlayer(playerid)
{
	Map_ClearIcons(playerid);
	new interior = GetPlayerInterior(playerid);
	new world = GetPlayerVirtualWorld(playerid);
	for (new i = 0; i < gMapPointCount; i++)
	{
		if (!Map_ShouldShow(playerid, i))
		{
			continue;
		}
		if (gMapPoints[i][mapInterior] != 0 && gMapPoints[i][mapInterior] != interior)
		{
			continue;
		}
		if (gMapPoints[i][mapWorld] != 0 && gMapPoints[i][mapWorld] != world)
		{
			continue;
		}
		new color = gMapPoints[i][mapColor];
		if (eMapCategory:gMapPoints[i][mapCategory] == MAP_JOBS)
		{
			new jobid = gMapPoints[i][mapData];
			if (jobid >= 0 && jobid < MAX_JOBS && gJobLevel[playerid][jobid] < gJobs[jobid][jobMinLevel])
			{
				color = 0x777777FF;
			}
		}
		if (eMapCategory:gMapPoints[i][mapCategory] == MAP_BUSINESS)
		{
			new biz = gMapPoints[i][mapData];
			if (biz >= 0 && biz < MAX_BUSINESSES)
			{
				if (BusinessData[biz][bOwner] == INVALID_PLAYER_ID)
				{
					color = 0xFFD15CFF;
				}
				else if (BusinessData[biz][bComponents] < 5)
				{
					color = 0xFF4444FF;
				}
				else
				{
					color = 0x33CC33FF;
				}
			}
		}
		SetPlayerMapIcon(playerid, i, gMapPoints[i][mapX], gMapPoints[i][mapY], gMapPoints[i][mapZ], gMapPoints[i][mapIcon], color, 0);
	}
	return 1;
}

stock Map_ShowDialog(playerid)
{
	new list[256];
	format(list, sizeof(list),
		"Jobs	%s\nBusinesses	%s\nLogistics	%s\nCinema	%s\nTeleports	%s\n",
		(gMapToggle[playerid] & MAP_TOGGLE_JOBS) ? "On" : "Off",
		(gMapToggle[playerid] & MAP_TOGGLE_BUSINESS) ? "On" : "Off",
		(gMapToggle[playerid] & MAP_TOGGLE_LOGISTICS) ? "On" : "Off",
		(gMapToggle[playerid] & MAP_TOGGLE_CINEMA) ? "On" : "Off",
		(gMapToggle[playerid] & MAP_TOGGLE_TELEPORTS) ? "On" : "Off"
	);
	ShowPlayerDialog(playerid, DIALOG_MAP, DIALOG_STYLE_LIST, "Map Filter", list, "Toggle", "Close");
	return 1;
}

stock Map_ShowGps(playerid)
{
	new list[1024];
	list[0] = EOS;
	new count = 0;
	new Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid, px, py, pz);
	new interior = GetPlayerInterior(playerid);
	new world = GetPlayerVirtualWorld(playerid);
	for (new i = 0; i < gMapPointCount; i++)
	{
		if (!Map_ShouldShow(playerid, i))
		{
			continue;
		}
		if (gMapPoints[i][mapInterior] != 0 && gMapPoints[i][mapInterior] != interior)
		{
			continue;
		}
		if (gMapPoints[i][mapWorld] != 0 && gMapPoints[i][mapWorld] != world)
		{
			continue;
		}
		new Float:dist = GetPlayerDistanceFromPoint(playerid, gMapPoints[i][mapX], gMapPoints[i][mapY], gMapPoints[i][mapZ]);
		new line[64];
		format(line, sizeof(line), "%s	%.0fm\n", gMapPoints[i][mapName], dist);
		strcat(list, line);
		gMapGpsIndex[playerid][count] = i;
		count++;
		if (count >= MAX_MAP_POINTS)
		{
			break;
		}
	}
	if (count == 0)
	{
		strcat(list, "Keine Punkte verfuegbar.\n");
	}
	ShowPlayerDialog(playerid, DIALOG_GPS, DIALOG_STYLE_LIST, "GPS", list, "Route", "Close");
	return 1;
}

stock bool:Map_OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	#pragma unused inputtext
	if (dialogid == DIALOG_MAP)
	{
		if (!response)
		{
			return true;
		}
		switch (listitem)
		{
			case 0: gMapToggle[playerid] ^= MAP_TOGGLE_JOBS;
			case 1: gMapToggle[playerid] ^= MAP_TOGGLE_BUSINESS;
			case 2: gMapToggle[playerid] ^= MAP_TOGGLE_LOGISTICS;
			case 3: gMapToggle[playerid] ^= MAP_TOGGLE_CINEMA;
			case 4: gMapToggle[playerid] ^= MAP_TOGGLE_TELEPORTS;
		}
		Map_RebuildForPlayer(playerid);
		Map_ShowDialog(playerid);
		return true;
	}
	if (dialogid == DIALOG_GPS)
	{
		if (!response)
		{
			return true;
		}
		if (listitem < 0 || listitem >= MAX_MAP_POINTS)
		{
			return true;
		}
		new idx = gMapGpsIndex[playerid][listitem];
		if (idx < 0 || idx >= gMapPointCount)
		{
			return true;
		}
		SetPlayerCheckpointEx(playerid, gMapPoints[idx][mapX], gMapPoints[idx][mapY], gMapPoints[idx][mapZ], 4.0);
		SendClientMessage(playerid, -1, "GPS Route gesetzt.");
		return true;
	}
	return false;
}

stock bool:Map_OnPlayerCommandText(playerid, const cmdtext[])
{
	new idx;
	new cmd[64];
	cmd = strtok(cmdtext, idx);
	if (!strlen(cmd))
	{
		return false;
	}
	if (!strcmp(cmd, "/map", true))
	{
		Map_ShowDialog(playerid);
		return true;
	}
	if (!strcmp(cmd, "/gps", true) || !strcmp(cmd, "/route", true))
	{
		Map_ShowGps(playerid);
		return true;
	}
	return false;
}
