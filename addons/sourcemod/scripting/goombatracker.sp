#include <sourcemod>
#include <clientprefs>
#include <goomba>

#pragma semicolon			1
#pragma newdecls required
#define PLUGIN_VERSION		"1.1"

#define IsClientValid(%1)		( 0 < (%1) && (%1) <= MaxClients && IsClientInGame((%1)) )

enum //1 cvar atm, I may add more in the future for HUD locations, color, etc
{
	DefaultOn,
	Version
};

ConVar bEnabled = null;
ConVar cvar[Version + 1]; /*Props to nergal, if you want to add cvars on your 
							own, put them above 'Version' under the enum*/ 
Handle CounterHUD, GoombaCookie, CounterCookie;

StringMap PlayerGoomba[MAXPLAYERS + 1];


public Plugin myinfo =  {
	name = "Goomba Tracker", 
	author = "Ragenewb, props to Chdata, Nergal", 
	description = "Count your Goomba Stomps!", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?t=302131"
};


public void OnPluginStart() {
	bEnabled = CreateConVar("goombacounter_enabled", "1", "Enable to Goomba Tracker plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar[Version] = CreateConVar("goombatracker_version", PLUGIN_VERSION, "GoombaTracker version number", FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_CHEAT);
	cvar[DefaultOn] = CreateConVar("goombatracker_default", "0", "Should the Goomba Tracker being on by default?", FCVAR_NOTIFY, true, 0.0, true, 0.0);
	RegConsoleCmd("sm_gcounter", GoombaToggler, "toggle goomba counter");
	RegConsoleCmd("sm_gtracker", GoombaToggler, "toggle goomba counter");
	RegAdminCmd("sm_reloadgtrackercfg", ReloadGCFG, ADMFLAG_GENERIC, "reload Goomba Tracker's cfg file");
	CounterHUD = CreateHudSynchronizer();
	
	CounterCookie = RegClientCookie("counter_cookie", "Shows the HUD of the goomba counter", CookieAccess_Private);
	GoombaCookie = RegClientCookie("goomba_cookie", "Keeps track of your total goomba stomps", CookieAccess_Public);
/*I may add a menu of "records" to see who has the highest # of stomps on the server, which is why its public*/

	AutoExecConfig(true, "GoombaTracker");
	CreateTimer(0.1, Timer_Counter, TIMER_REPEAT, TIMER_FLAG_NO_MAPCHANGE);
	PlayerGoomba[0] = new StringMap();
}

methodmap  GoombaDude
{
	public GoombaDude(const int ind, bool uid=false)
	{
		int player=0;	
		if (uid && GetClientOfUserId(ind) > 0)
			player = ( ind );
		else if ( IsClientValid(ind) )
			player = GetClientUserId(ind);
		return view_as< GoombaDude >( player );
	}

	property int userid {
		public get()				{ return view_as< int >(this); }
	}
	property int index {
		public get()				{ return GetClientOfUserId( view_as< int >(this) ); }
	}
	property int iGoombas
	{
		public get() {
			int player = this.index;
			if (!player)
				return 0;
			else if (!AreClientCookiesCached(player) || IsFakeClient(player)) {  //Fallback in case cookies aren't cached
				int i; PlayerGoomba[player].GetValue("iGoombas", i);
				return i; 
			}
			char strPoints[10];	//If someone gets more than 1000000000 goombas I stg
			GetClientCookie(player, GoombaCookie, strPoints, sizeof(strPoints));
			int points = StringToInt(strPoints);
			PlayerGoomba[player].SetValue("iGoombas", points); 
			return points ;
		}
		public set( const int val ) {
			int player = this.index;
			if (!player)
				return;
			else if (!AreClientCookiesCached(player) || IsFakeClient(player)) {
				PlayerGoomba[player].SetValue("iGoombas", val); 
				return;
			}
			PlayerGoomba[player].SetValue("iGoombas", val); 
			char strPoints[10];
			IntToString(val, strPoints, sizeof(strPoints));
			SetClientCookie(player, GoombaCookie, strPoints);
		}
	}
	property bool bCounter
	{
		public get()
		{
			if (!AreClientCookiesCached(this.index))
				return false;
			char selection[6];
			GetClientCookie(this.index, CounterCookie, selection, sizeof(selection));
			return (StringToInt(selection) == 1);
		}
		public set( const bool val )
		{
			if (!AreClientCookiesCached(this.index))
				return;
			int value;
			if (val)
				value = 1;
			else value = 0;
			char selection[6];
			IntToString(value, selection, sizeof(selection));
			SetClientCookie(this.index, CounterCookie, selection);
		}
	}
}

public void OnClientPutInServer(int client)
{
	if (!bEnabled.BoolValue)
		return;
	GoombaDude player = GoombaDude(client); //New to cookies, half-assing the hell outta this
	char cookie[6]; GetClientCookie(player.index, CounterCookie, cookie, sizeof(cookie));
	if (StringToInt(cookie) >= 1)
		player.bCounter = true;
	else if (StringToInt(cookie) <= 0)
		player.bCounter = false;
	else if (cvar[DefaultOn].BoolValue)
		player.bCounter = true;
	else player.bCounter = false;
	
	if (PlayerGoomba[client] != null)
		delete PlayerGoomba[client];
	
	PlayerGoomba[client] = new StringMap();
	PlayerGoomba[client].SetValue("iGoombas", 0);
}

public Action GoombaToggler(int client, int args) 
{
	if (!IsClientValid(client) || !bEnabled.BoolValue)
		return Plugin_Continue;
	if (args == 0) {
		GoombaDude player = GoombaDude(client);
		if (!player.bCounter)
		{
			player.bCounter = true;
			PrintToChat(client, "[SM] You've toggled the Goomba Tracker on!");
		}
		else
		{
			player.bCounter = false;
			PrintToChat(client, "[SM] You've toggled the Goomba Tracker off.");
		}
	}
	return Plugin_Handled;
}

public int OnStompPost(int attacker, int victim, float damageMultiplier, float damageAdd, float JumpPower)
{
	if (!bEnabled.BoolValue || !IsClientValid(attacker))	//Is the attacker check even necessary?
		return;
	GoombaDude player = GoombaDude(attacker);
	player.iGoombas++;
}

public Action Timer_Counter(Handle timer) {
	if (!bEnabled.BoolValue)
		return;
	CreateTimer(0.1, Timer_Counter);
	int i;
	for (i = MaxClients; i; --i) {
		if (!IsClientValid(i))
			continue;
		GoombaDude player = GoombaDude(i);
		if (player.bCounter) {
			SetHudTextParams(0.60, 0.80, 0.3, 0, 150, 255, 0);
			if (player.iGoombas == 0)	//Once again, not sure if this is needed, but hey why not
				ShowSyncHudText(i, CounterHUD, "Goombas: 0");
			else ShowSyncHudText(i, CounterHUD, "Goombas: %i", player.iGoombas);
		}
	}
}

public Action ReloadGCFG(int client, int arg)
{
	ServerCommand("sm_rcon exec sourcemod/GoombaTracker.cfg");
	ReplyToCommand(client, "~~Reloading Goomba Tracker Config~~");
	return Plugin_Handled;
}
