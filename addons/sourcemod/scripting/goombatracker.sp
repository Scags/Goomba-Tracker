#include <sourcemod>
#include <clientprefs>
#include <goomba>

#pragma semicolon			1
#pragma newdecls required
#define PLUGIN_VERSION		"1.2"

#define IsClientValid(%1)		( 0 < (%1) && (%1) <= MaxClients && IsClientInGame((%1)) )


ConVar
	bEnabled = null,
	cvDefault = null,
	cvXCoord = null,
	cvYCoord = null,
	cvALPHA = null,
	cvBLU = null,
	cvGREEN = null,
	cvRED = null
;

Handle
	CounterHUD,
	GoombaCookie,
	CounterCookie
;

public Plugin myinfo =  {
	name = "Goomba Tracker", 
	author = "Ragenewb, props to Chdata, Nergal", 
	description = "Count your Goomba Stomps!", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?t=302131"
};


public void OnPluginStart() 
{
	bEnabled = CreateConVar("goombacounter_enabled", "1", "Enable to Goomba Tracker plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvDefault = CreateConVar("goombatracker_default", "0", "Should the Goomba Tracker being on by default?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvXCoord = CreateConVar("goombatracker_xcoord", "0.60", "X Coordinate for Gooomba HUD.", FCVAR_NOTIFY, true, -1.0, true, 1.0);
	cvYCoord = CreateConVar("goombatracker_ycoord", "0.80", "Y Coordinate for Goomba HUD.", FCVAR_NOTIFY, true, -1.0, true, 1.0);
	cvALPHA = CreateConVar("goombatracker_alpha", "0", "Alpha magnitude for Goomba HUD.", FCVAR_NOTIFY, true, 0.0, true, 255.0);
	cvBLU = CreateConVar("goombatracker_blu", "255", "Blue magnitude for Goomba HUD.", FCVAR_NOTIFY, true, 0.0, true, 255.0);
	cvGREEN = CreateConVar("goombatracker_green", "150", "Green magnitude for Goomba HUD.", FCVAR_NOTIFY, true, 0.0, true, 255.0);
	cvRED = CreateConVar("goombatracker_red", "0", "Red magnitude for Goomba HUD.", FCVAR_NOTIFY, true, 0.0, true, 255.0);

	RegConsoleCmd("sm_gcounter", GoombaToggler, "Toggle goomba counter");
	RegConsoleCmd("sm_gtracker", GoombaToggler, "Toggle goomba counter");
	RegAdminCmd("sm_reloadgtrackercfg", ReloadGCFG, ADMFLAG_GENERIC, "Reload Goomba Tracker's cfg file");

	CounterHUD = CreateHudSynchronizer();
	
	CounterCookie = RegClientCookie("counter_cookie", "Shows the HUD of the goomba counter", CookieAccess_Private);
	GoombaCookie = RegClientCookie("goomba_cookie", "Keeps track of your total goomba stomps", CookieAccess_Public);

	AutoExecConfig(true, "GoombaTracker");
}

public void OnMapStart()
{
	CreateTimer(0.1, Timer_Counter, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action GoombaToggler(int client, int args) 
{
	if (!client)
	{
		ReplyToCommand(client, "[SM] Command must be done in-game.");
		return Plugin_Continue;
	}
	if (!AreClientCookiesCached(client))
	{
		PrintToChat(client, "[SM] Your cookies are not cached!");
		return Plugin_Handled;
	}

	char cookie[6]; GetClientCookie(client, CounterCookie, cookie, sizeof(cookie));
	if (!args)
	{
		int icookie = StringToInt(cookie);
		if (icookie == 1 || (cvDefault.BoolValue && !icookie))
		{
			SetClientCookie(client, CounterCookie, "2");
			PrintToChat(client, "[SM] You've toggled the Goomba Tracker off.");
		}
		else
		{
			SetClientCookie(client, CounterCookie, "1");
			PrintToChat(client, "[SM] You've toggled the Goomba Tracker on!");
		}
		return Plugin_Handled;
	}
	char arg[8]; GetCmdArg(1, arg, sizeof(arg));
	if (StrContains(arg, "on", false) != -1)	// Close enough...
	{
		SetClientCookie(client, CounterCookie, "2");
		PrintToChat(client, "[SM] You've toggled the Goomba Tracker off.");
	}
	else
	{
		SetClientCookie(client, CounterCookie, "1");
		PrintToChat(client, "[SM] You've toggled the Goomba Tracker on!");
	}
	return Plugin_Handled;
}

public int OnStompPost(int attacker, int victim, float damageMultiplier, float damageAdd, float JumpPower)
{
	if (!bEnabled.BoolValue || !AreClientCookiesCached(attacker))
		return;

	char cookie[6]; GetClientCookie(attacker, GoombaCookie, cookie, sizeof(cookie));
	IntToString(StringToInt(cookie)+1, cookie, sizeof(cookie));
	SetClientCookie(attacker, GoombaCookie, cookie);
}

public Action Timer_Counter(Handle timer) 
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	SetHudTextParams(cvXCoord.FloatValue, cvYCoord.FloatValue, 0.2, cvRED.IntValue, cvGREEN.IntValue, cvBLU.IntValue, cvALPHA.IntValue);
	char cookie[6];
	bool def = cvDefault.BoolValue;
	int icookie;
	for (int i = MaxClients; i; --i) 
	{
		if (!IsClientInGame(i))
			continue;
		if (!AreClientCookiesCached(i))
			continue;

		GetClientCookie(i, CounterCookie, cookie, sizeof(cookie));
		icookie = StringToInt(cookie);
		if (icookie == 1 || (!icookie && def))	// If default is true and no setting picked by client, show the hud 
		{
			GetClientCookie(i, GoombaCookie, cookie, sizeof(cookie));
			ShowSyncHudText(i, CounterHUD, "Goombas: %s", cookie);
		}
	}
	return Plugin_Continue;
}

public Action ReloadGCFG(int client, int arg)
{
	ServerCommand("sm_rcon exec sourcemod/GoombaTracker.cfg");
	ReplyToCommand(client, "~~Reloading Goomba Tracker Config~~");
	return Plugin_Handled;
}