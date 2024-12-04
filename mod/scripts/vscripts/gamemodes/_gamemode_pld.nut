untyped

global function GamemodePLD_Init
global function RateSpawnpoints_PLD

global function Payload_SetMilitiaHarvesterLocation
global function Payload_SetNukeTitanSpawnLocation

global function CreatePayloadSpawnZone
global function AddPayloadCheckpointWithZones
global function AddPayloadCustomMapProp
global function AddPayloadCustomShipStart
global function AddPayloadFixedSpawnZoneForTeam
global function AddPayloadRouteNode

global function AddCallback_PayloadMode



const float PLD_HARVESTER_PERIMETER_DIST = 2000.0
const float PLD_PUSH_DIST = 300.0
const float PLD_BASE_NUKE_TITAN_MOVESPEED_SCALE = 0.1
const float PLD_PATH_TRACKER_REFRESH_FREQUENCY = 2
const float PLD_PATH_TRACKER_MOVE_TIME_BETWEN_POINTS = 1

const int PAYLOAD_SCORE_OBJECTIVE_DEFENSE_KILL = 6
const int PAYLOAD_SCORE_OBJECTIVE_DEFENSE_BONUS = 15
const int PAYLOAD_SCORE_OBJECTIVE_DEFENSE_HALT = 1
const int PAYLOAD_SCORE_OBJECTIVE_ESCORT = 1
const int PAYLOAD_SCORE_OBJECTIVE_ESCORT_KILL = 2
const int PAYLOAD_SCORE_OBJECTIVE_ESCORT_BONUS = 30
const int PAYLOAD_SCORE_OBJECTIVE_SHIELD_HARVESTER = 35
const int PAYLOAD_SCORE_OBJECTIVE_SHIELD_TITAN = 20
const int PAYLOAD_GRUNTS_PER_TEAM = 6

const asset NUKETITAN_SHIELDWALL = $"P_turret_shield_wall" // "P_shield_hld_01_CP" is also a potential use
const asset NUKETITAN_PUSHRADIUS_MODEL = $"models/fort_war/fw_turret_territory_512.mdl" // Frontier War Zone Glow, matches push trigger of Nuke Titan



struct PayloadPlayer{
	float pushOrHaltTime = 0.0
	bool nearNukeTitan = false
}

struct {
	array< entity > payloadSpawnZones
	array< entity > checkpointEnts
	
	HarvesterStruct& militiaHarvester
	entity theNukeTitan = null
	bool nukeIsMoving = false
	
	table< entity, PayloadPlayer > matchPlayers
	table< entity, array< entity > > checkPoints
	
	array< void functionref() > payloadCallbacks
	
	vector nukeTitanSpawnSpot = < 0, 0, 0 >
	vector nukeTitanSpawnAngle = < 0, 0, 0 >
	
	vector harvesterSpawnSpot = < 0, 0, 0 >
	vector harvesterSpawnAngle = < 0, 0, 0 >
	
	vector batteryPortPosition = < 0, 0, 0 >
	vector batteryPortAngle = < 0, 0, 0 >
	
	array< vector > payloadRoute
	int currentRouteNode
	int capturedCheckpoints = 0
	
	int nukeTitanShieldHack = 0
	int nukeHarvesterShieldMax = 25000
	int checkpointBonusTime = 5
}file










/*

██╗███╗   ██╗██╗████████╗██╗ █████╗ ██╗     ██╗███████╗ █████╗ ████████╗██╗ ██████╗ ███╗   ██╗
██║████╗  ██║██║╚══██╔══╝██║██╔══██╗██║     ██║╚══███╔╝██╔══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║
██║██╔██╗ ██║██║   ██║   ██║███████║██║     ██║  ███╔╝ ███████║   ██║   ██║██║   ██║██╔██╗ ██║
██║██║╚██╗██║██║   ██║   ██║██╔══██║██║     ██║ ███╔╝  ██╔══██║   ██║   ██║██║   ██║██║╚██╗██║
██║██║ ╚████║██║   ██║   ██║██║  ██║███████╗██║███████╗██║  ██║   ██║   ██║╚██████╔╝██║ ╚████║
╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝   ╚═╝╚═╝  ╚═╝╚══════╝╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝

*/

void function GamemodePLD_Init()
{
	PrecacheModel( CTF_FLAG_BASE_MODEL )
	PrecacheModel( MODEL_FRONTIER_DEFENSE_PORT )
	PrecacheModel( MODEL_FRONTIER_DEFENSE_TURRET_SITE )
	PrecacheModel( NUKETITAN_PUSHRADIUS_MODEL )
	
	PrecacheParticleSystem( FLAG_FX_FRIENDLY )
	
	RegisterSignal( "FD_ReachedHarvester" ) //For Nuke Titan navigation
	RegisterSignal( "PayloadNukeTitanStopped" )
	RegisterSignal( "BatteryActivate" ) //From Frontier War, to give shields to the Harvester
	
	SetTimeoutWinnerDecisionFunc( PLD_TimeoutWinner )
	SetGameModeRulesEarnMeterOnDamage( GameModeRulesEarnMeterOnDamage_PLD )
	
	AddCallback_EntitiesDidLoad( LoadPayloadContent )
	
	AddCallback_OnClientConnected( GamemodePLD_InitPlayer )
	AddCallback_OnClientDisconnected( GamemodePLD_PlayerDisconnected )
	AddCallback_OnPlayerKilled( GamemodePLD_OnPlayerKilled )
	AddCallback_OnPlayerRespawned( PayloadPlayerRespawned )
	AddOnRodeoStartedCallback( PLD_PilotStartRodeo )
	AddOnRodeoEndedCallback( PLD_PilotEndRodeo )
	SetApplyBatteryCallback( PLD_ShieldedNukeTitan )
	
	AddCallback_GameStateEnter( eGameState.Prematch, Payload_SpawnHarvester )
	AddCallback_GameStateEnter( eGameState.Playing, StartHarvesterAndPrepareNukeTitan )
	AddCallback_GameStateEnter( eGameState.WinnerDetermined, PayloadMatchVictoryDecided )
	
	AddSpawnCallback( "npc_turret_sentry", AddTurretSentry )
	
	ScoreEvent_SetDisplayType( GetScoreEvent( "FDShieldHarvester" ), eEventDisplayType.GAMEMODE | eEventDisplayType.MEDAL | eEventDisplayType.CALLINGCARD )
	ScoreEvent_SetDisplayType( GetScoreEvent( "PilotBatteryApplied" ), eEventDisplayType.GAMEMODE | eEventDisplayType.MEDAL | eEventDisplayType.CALLINGCARD )
	ScoreEvent_SetDisplayType( GetScoreEvent( "PilotBatteryStolen" ), eEventDisplayType.GAMEMODE | eEventDisplayType.MEDAL | eEventDisplayType.CALLINGCARD )
	
	ScoreEvent_SetupEarnMeterValuesForMixedModes()
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.07, 0.1 )
	ScoreEvent_SetEarnMeterValues( "PilotBatteryStolen", 0.0, 0.5 )
	ScoreEvent_SetEarnMeterValues( "Headshot", 0.03, 0.07 )
	ScoreEvent_SetEarnMeterValues( "FirstStrike", 0.05, 0.25 )
	ScoreEvent_SetEarnMeterValues( "PilotBatteryApplied", 0.0, 0.5 )
	ScoreEvent_SetEarnMeterValues( "PilotAssist", 0.02, 0.03 )
	ScoreEvent_SetEarnMeterValues( "KillLightTurret", 0.0, 0.05 )
	ScoreEvent_SetEarnMeterValues( "Execution", 0.05, 0.2 )
	ScoreEvent_SetEarnMeterValues( "FDShieldHarvester", 0.0, 0.5 )
	ScoreEvent_SetEarnMeterValues( "Onslaught", 0.1, 0.1 )
	ScoreEvent_SetEarnMeterValues( "Nemesis", 0.01, 0.1 )
	ScoreEvent_SetEarnMeterValues( "KilledMVP", 0.01, 0.05 )
	
	ScoreEvent_SetXPValueFaction( GetScoreEvent( "ChallengeTTDM" ), 1 )
	SetAILethality( eAILethality.VeryHigh )
	
	level.endOfRoundPlayerState = ENDROUND_MOVEONLY
	
	file.nukeHarvesterShieldMax = GetCurrentPlaylistVarInt( "pld_harvester_nuke_shield_amount", 25000 )
	file.checkpointBonusTime = GetCurrentPlaylistVarInt( "pld_checkpoint_bonus_time", 5 )

	if( GetCurrentPlaylistVarInt( "pld_gruntplayers", 0 ) == 1 )
		AddCallback_OnPlayerGetsNewPilotLoadout( PLD_OnPlayerGetsNewPilotLoadout )
	
	AddDamageFinalCallback( "player", PLD_DamagePlayerScale )
}

void function LoadPayloadContent()
{
	Payload_InitMaps()
	foreach ( callback in file.payloadCallbacks )
		callback()
}

void function PayloadMatchVictoryDecided()
{
	foreach ( npc in GetNPCArray() )
	{
		npc.ClearAllEnemyMemory()
		npc.EnableNPCFlag( NPC_DISABLE_SENSING | NPC_IGNORE_ALL )
	}
}

void function StartHarvesterAndPrepareNukeTitan()
{
	thread StartHarvesterAndPrepareNukeTitan_threaded()
	thread Spawner_Threaded( TEAM_IMC )
	thread Spawner_Threaded( TEAM_MILITIA )
	
	switch ( GetMapName() )
	{
		case "mp_angel_city":
		case "mp_thaw":
		case "mp_forwardbase_kodai":
		case "mp_black_water_canal":
		case "mp_eden":
		case "mp_drydock":
			thread StratonHornetDogfightsIntense()
	}
}

void function StartHarvesterAndPrepareNukeTitan_threaded()
{
	entity harvester = file.militiaHarvester.harvester
	
	wait 5
	
	thread Payload_RouteHologramRepeater()
	
	EmitSoundOnEntity( harvester, HARVESTER_SND_STARTUP )
	file.militiaHarvester.rings.Anim_Play( HARVESTER_ANIM_ACTIVATING )
	
	wait 4
	
	harvester.SetNoTarget( false )
	file.militiaHarvester.rings.Anim_Play( HARVESTER_ANIM_ACTIVE )
	generateBeamFX( file.militiaHarvester )
	EmitSoundOnEntity( harvester, HARVESTER_SND_HEALTHY )
	
	wait 15
	
	MessageToAll( eEventNotifications.TEMP_TitanGreenRoom )
	
	wait 5
	
	Payload_SpawnNukeTitan()
}









/*

██████╗ ██╗      █████╗ ██╗   ██╗███████╗██████╗     ██╗      ██████╗  ██████╗ ██╗ ██████╗
██╔══██╗██║     ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗    ██║     ██╔═══██╗██╔════╝ ██║██╔════╝
██████╔╝██║     ███████║ ╚████╔╝ █████╗  ██████╔╝    ██║     ██║   ██║██║  ███╗██║██║     
██╔═══╝ ██║     ██╔══██║  ╚██╔╝  ██╔══╝  ██╔══██╗    ██║     ██║   ██║██║   ██║██║██║     
██║     ███████╗██║  ██║   ██║   ███████╗██║  ██║    ███████╗╚██████╔╝╚██████╔╝██║╚██████╗
╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝    ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝ ╚═════╝

*/

void function GamemodePLD_InitPlayer( entity player )
{
	PayloadPlayer playerData
	file.matchPlayers[player] <- playerData
	
	thread TrackPlayerTimeForPushOrHalt( player )	
}

void function TrackPlayerTimeForPushOrHalt( entity player )
{
	player.EndSignal( "OnDestroy" )
	
	WaitFrame()
	
	bool changedState = false
	
	while( !IsValid( file.theNukeTitan ) ) // Wait for the Nuke Titan to spawn in
		WaitFrame()
	
	Remote_CallFunction_NonReplay( player, "ServerCallback_PLD_SyncSettings", file.nukeHarvesterShieldMax )
	Remote_CallFunction_NonReplay( player, "ServerCallback_PLD_ShowTutorialHint", ePLDTutorials.Teams )
	
	while( IsValidPlayer( player ) )
	{
		if ( player.GetTeam() == TEAM_MILITIA )
		{
			if ( !file.nukeIsMoving && !changedState )
			{
				file.matchPlayers[player].pushOrHaltTime = Time() + 30
				changedState = true
			}
			if ( !file.nukeIsMoving && file.matchPlayers[player].pushOrHaltTime < Time() && !HasPlayerCompletedMeritScore( player ) )
			{
				AddPlayerScore( player, "ChallengeTTDM" )
				SetPlayerChallengeMeritScore( player )
				return
			}
			else if ( file.nukeIsMoving )
				changedState = false
		}
		
		if ( player.GetTeam() == TEAM_IMC )
		{
			if ( file.matchPlayers[player].nearNukeTitan && !changedState )
			{
				file.matchPlayers[player].pushOrHaltTime = Time() + 30
				changedState = true
			}
			if ( file.matchPlayers[player].nearNukeTitan && file.matchPlayers[player].pushOrHaltTime < Time() && !HasPlayerCompletedMeritScore( player ) )
			{
				AddPlayerScore( player, "ChallengeTTDM" )
				SetPlayerChallengeMeritScore( player )
				return
			}
			else if ( !file.matchPlayers[player].nearNukeTitan )
				changedState = false
		}
		
		WaitFrame()
	}
}

void function GamemodePLD_PlayerDisconnected( entity player )
{
	if ( player in file.matchPlayers )
		delete file.matchPlayers[player]
}

void function GamemodePLD_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !GamePlaying() || !IsValidPlayer( attacker ) )
		return
	
	if( attacker.GetTeam() == TEAM_IMC && file.matchPlayers[victim].nearNukeTitan )
		attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, PAYLOAD_SCORE_OBJECTIVE_DEFENSE_KILL )
	
	if( attacker.GetTeam() == TEAM_MILITIA && file.matchPlayers[attacker].nearNukeTitan && victim.GetTeam() == TEAM_MILITIA )
		attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, PAYLOAD_SCORE_OBJECTIVE_ESCORT_KILL )
}

void function PLD_ShieldedNukeTitan( entity rider, entity titan, entity battery )
{
	UpdateShieldTrackingOfNukeOrHarvester( titan, file.nukeHarvesterShieldMax )
	foreach ( player in GetPlayerArray() )
		Remote_CallFunction_NonReplay( player, "ServerCallback_PLD_ShowTutorialHint", ePLDTutorials.NukeTitanBattery )
	
	rider.AddToPlayerGameStat( PGS_ASSAULT_SCORE, PAYLOAD_SCORE_OBJECTIVE_SHIELD_TITAN )
}











/*

 ██████╗ █████╗ ██╗     ██╗     ██████╗  █████╗  ██████╗██╗  ██╗███████╗
██╔════╝██╔══██╗██║     ██║     ██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝
██║     ███████║██║     ██║     ██████╔╝███████║██║     █████╔╝ ███████╗
██║     ██╔══██║██║     ██║     ██╔══██╗██╔══██║██║     ██╔═██╗ ╚════██║
╚██████╗██║  ██║███████╗███████╗██████╔╝██║  ██║╚██████╗██║  ██╗███████║
 ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝
 
 */

void function AddCallback_PayloadMode( void functionref() callback )
{
	file.payloadCallbacks.append( callback )
}

void function Payload_SetMilitiaHarvesterLocation( vector origin, vector angles, vector bPortPosition, vector bPortAngle )
{
	file.harvesterSpawnSpot = origin
	file.harvesterSpawnAngle = angles
	
	file.batteryPortPosition = bPortPosition
	file.batteryPortAngle = bPortAngle
}

void function Payload_SetNukeTitanSpawnLocation( vector origin, vector angles = < 0, 0, 0 > )
{
	file.nukeTitanSpawnSpot = origin
	file.nukeTitanSpawnAngle = angles
}

void function AddPayloadRouteNode( vector origin )
{
	file.payloadRoute.append( origin )
}

void function AddPayloadFixedSpawnZoneForTeam( int team, vector zoneLoc, float zoneRadius )
{
	entity zone = CreatePropScript( $"models/dev/empty_model.mdl", zoneLoc )
	zone.DisableHibernation()
	zone.s.zoneRadius <- zoneRadius
	SetTeamSpawnZoneMinimapMarker( zone, team )
	file.payloadSpawnZones.append( zone )
}

entity function CreatePayloadSpawnZone( vector zoneLoc, float zoneRadius )
{
	entity zone = CreatePropScript( $"models/dev/empty_model.mdl", zoneLoc )
	zone.DisableHibernation()
	zone.s.zoneRadius <- zoneRadius
	return zone
}

void function AddPayloadCheckpointWithZones( int checkpointIndex, vector checkpointPos, array< entity > bindedSpawnZones )
{
	entity checkpoint = CreateEntity( "info_hardpoint" )
	checkpoint.SetOrigin( checkpointPos )
	SetTeam( checkpoint, TEAM_MILITIA )
	DispatchSpawn( checkpoint )
	
	file.checkpointEnts.append( checkpoint )
	checkpoint.SetHardpointID( checkpointIndex )
	checkpoint.SetHardpointState( CAPTURE_POINT_STATE_CAPTURED )
	SetGlobalNetInt( "objective" + checkpointIndex + "State", CAPTURE_POINT_STATE_CAPTURED )
	SetCheckpointMinimapIcon( checkpoint )
	
	SetGlobalNetEnt( "checkpoint" + checkpointIndex + "Ent", checkpoint )
	
	entity trigger = CreateEntity( "trigger_cylinder" )
	trigger.SetRadius( 100 )
	trigger.SetAboveHeight( 100 )
	trigger.SetBelowHeight( 100 )
	trigger.SetOrigin( checkpoint.GetOrigin() )
	trigger.SetParent( checkpoint )
	trigger.kv.triggerFilterNpc = "titan"
	trigger.kv.triggerFilterPlayer = "none"
	DispatchSpawn( trigger )
	trigger.SetEnterCallback( OnNukeTitanEnteredCheckpoint )
	
	entity checkpointBase = CreatePropDynamic( CTF_FLAG_BASE_MODEL, checkpoint.GetOrigin(), checkpoint.GetAngles(), 0 )
	SetTeam( checkpointBase, checkpoint.GetTeam() )
	checkpointBase.SetParent( checkpoint )
	
	foreach ( zone in bindedSpawnZones )
	{
		SetTeamSpawnZoneMinimapMarker( zone, TEAM_MILITIA )
		file.payloadSpawnZones.append( zone )
	}
	
	file.checkPoints[checkpoint] <- bindedSpawnZones
}

void function AddPayloadCustomMapProp( asset modelasset, vector origin, vector angles )
{
	entity prop = CreateEntity( "prop_script" )
	prop.SetValueForModelKey( modelasset )
	prop.SetOrigin( origin )
	prop.SetAngles( angles )
	prop.kv.fadedist = -1
	prop.kv.renderamt = 255
	prop.kv.rendercolor = "255 255 255"
	prop.kv.solid = 6
	ToggleNPCPathsForEntity( prop, false )
	prop.SetAIObstacle( true )
	prop.SetTakeDamageType( DAMAGE_NO )
	prop.SetScriptPropFlags( SPF_BLOCKS_AI_NAVIGATION | SPF_CUSTOM_SCRIPT_3 )
	prop.AllowMantle()
	DispatchSpawn( prop )
}

void function AddPayloadCustomShipStart( vector origin, vector angles, int team )
{
	entity shipSpawn = CreateEntity( "info_spawnpoint_dropship_start" )
	shipSpawn.SetOrigin( origin )
	shipSpawn.SetAngles( angles )
	SetTeam( shipSpawn, team )
	DispatchSpawn( shipSpawn )
}











/*

███████╗██████╗  █████╗ ██╗    ██╗███╗   ██╗    ██╗      ██████╗  ██████╗ ██╗ ██████╗
██╔════╝██╔══██╗██╔══██╗██║    ██║████╗  ██║    ██║     ██╔═══██╗██╔════╝ ██║██╔════╝
███████╗██████╔╝███████║██║ █╗ ██║██╔██╗ ██║    ██║     ██║   ██║██║  ███╗██║██║     
╚════██║██╔═══╝ ██╔══██║██║███╗██║██║╚██╗██║    ██║     ██║   ██║██║   ██║██║██║     
███████║██║     ██║  ██║╚███╔███╔╝██║ ╚████║    ███████╗╚██████╔╝╚██████╔╝██║╚██████╗
╚══════╝╚═╝     ╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═══╝    ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝ ╚═════╝

*/

void function RateSpawnpoints_PLD( int checkClass, array<entity> spawnpoints, int team, entity player )
{
	foreach ( entity spawn in spawnpoints )
	{
		foreach ( entity zone in file.payloadSpawnZones )
		{
			float rating = 0.0
			float distance = Distance2D( spawn.GetOrigin(), zone.GetOrigin() )
			
			if( zone.GetTeam() == team )
			{
				if ( distance < zone.s.zoneRadius )
				{
					if( IsAlive( file.theNukeTitan ) )
						rating = 10.0 / Distance2D( spawn.GetOrigin(), file.theNukeTitan.GetOrigin() )
					else if ( IsValid( file.militiaHarvester ) )
						rating = 10.0 / Distance2D( spawn.GetOrigin(), file.militiaHarvester.harvester.GetOrigin() )
					else
						rating = 10.0 / distance
				}
				
				if ( spawn == player.p.lastSpawnPoint )
					rating += GetConVarFloat( "spawnpoint_last_spawn_rating" )
			}
			
			spawn.CalculateRatingDontCache( checkClass, team, rating, rating )
		}
	}
}

void function PayloadPlayerRespawned( entity player ) // Actual hack because the function above is not doing its job idk why
{
	if( GetCurrentPlaylistVarInt( "pld_gruntplayers", 0 ) == 1 )
	{
		player.e.hasDefaultEnemyHighlight = false
		Highlight_ClearEnemyHighlight( player )
		HideName( player )
	}
	
	array<entity> teamZones
	foreach ( entity zone in file.payloadSpawnZones )
	{
		if ( zone.GetTeam() != player.GetTeam() )
			continue
		
		teamZones.append( zone )
	}
	
	if ( IsAlive( file.theNukeTitan ) )
	{
		teamZones = ArrayClosest( teamZones, file.theNukeTitan.GetOrigin() )
		while( teamZones.len() > 3 )
			teamZones.pop()
	}
	
	array<entity> spawnpoints = GetEntArrayByClass_Expensive( "info_spawnpoint_human" )
	//spawnpoints.extend( GetEntArrayByClass_Expensive( "info_spawnpoint_human_start" ) )
	
	array<entity> teamSpawns
	foreach ( entity spawn in spawnpoints )
	{
		foreach ( entity zone in teamZones )
		{
			if ( IsValid( zone ) )
			{
				float distance = Distance2D( spawn.GetOrigin(), zone.GetOrigin() )
				if ( distance < zone.s.zoneRadius )
					teamSpawns.append( spawn )
			}
		}
	}
	
	while( teamSpawns.len() )
	{
		entity decidedSpawn = teamSpawns.getrandom()
		if( !decidedSpawn.IsVisibleToEnemies( player.GetTeam() ) )
		{
			player.SetOrigin( decidedSpawn.GetOrigin() )
			player.SetAngles( decidedSpawn.GetAngles() )
			break
		}
		else
			teamSpawns.removebyvalue( decidedSpawn )
	}
}

void function Payload_SpawnHarvester()
{
	file.militiaHarvester = SpawnHarvester( file.harvesterSpawnSpot, file.harvesterSpawnAngle, 100, 0, TEAM_MILITIA )
	SetTargetName( file.militiaHarvester.harvester, "militiaHarvester" )
	SetGlobalNetEnt( "militiaHarvester", file.militiaHarvester.harvester )
	
	file.militiaHarvester.harvester.SetShieldHealthMax( file.nukeHarvesterShieldMax )
	file.militiaHarvester.harvester.Minimap_SetAlignUpright( true )
	file.militiaHarvester.harvester.Minimap_AlwaysShow( TEAM_IMC, null )
	file.militiaHarvester.harvester.Minimap_AlwaysShow( TEAM_MILITIA, null )
	file.militiaHarvester.harvester.Minimap_SetHeightTracking( true )
	file.militiaHarvester.harvester.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	file.militiaHarvester.harvester.Minimap_SetCustomState( eMinimapObject_prop_script.FD_HARVESTER )
	file.militiaHarvester.harvester.SetTakeDamageType( DAMAGE_EVENTS_ONLY )
	file.militiaHarvester.harvester.SetArmorType( ARMOR_TYPE_HEAVY )
	file.militiaHarvester.harvester.SetAIObstacle( true )
	file.militiaHarvester.harvester.SetScriptPropFlags( SPF_DISABLE_CAN_BE_MELEED )
	file.militiaHarvester.harvester.SetNoTarget( true )
	
	ToggleNPCPathsForEntity( file.militiaHarvester.harvester, false )
	AddEntityCallback_OnFinalDamaged( file.militiaHarvester.harvester, OnHarvesterDamaged )
	
	entity batteryPort = CreatePropScript( $"models/props/battery_port/battery_port_animated.mdl", file.batteryPortPosition + < 0, 0, 12 >, file.batteryPortAngle, 6 )
	entity batteryPortBase = CreatePropDynamicLightweight( $"models/props/turret_base/turret_base.mdl", file.batteryPortPosition, file.batteryPortAngle, 6 )
	
	batteryPort.kv.fadedist = 16384
	SetTargetName( batteryPort, "harvesterBoostPort" )
	InitTurretBatteryPort( batteryPort )

	SetTeam( batteryPort, file.militiaHarvester.harvester.GetTeam() )
	batteryPort.s.bindedHarvester <- file.militiaHarvester.harvester
	batteryPort.s.isUsable <- PayloadBatteryPortUseCheck
	batteryPort.s.useBattery <- PayloadUseBatteryFunc
	batteryPort.s.hackAvaliable = false
	batteryPort.SetUsableByGroup( "friendlies pilot" )
}

void function Payload_SpawnNukeTitan()
{
	entity npc = CreateNPCTitan( "titan_ogre", TEAM_IMC, file.nukeTitanSpawnSpot, file.nukeTitanSpawnAngle )
	SetSpawnOption_AISettings( npc, "npc_titan_ogre_minigun_nuke" )
	SetSpawnOption_Titanfall( npc )
	SetTargetName( npc, "payloadNukeTitan" )
	DispatchSpawn( npc )
	HideName( npc )
	npc.EnableNPCFlag( NPC_DISABLE_SENSING | NPC_IGNORE_ALL )
	npc.EnableNPCMoveFlag( NPCMF_WALK_ALWAYS | NPCMF_WALK_NONCOMBAT )
	npc.DisableNPCMoveFlag( NPCMF_PREFER_SPRINT )
	npc.DisableNPCFlag( NPC_DIRECTIONAL_MELEE )
	npc.SetCapabilityFlag( bits_CAP_INNATE_MELEE_ATTACK1 | bits_CAP_INNATE_MELEE_ATTACK2 | bits_CAP_SYNCED_MELEE_ATTACK , false )
	npc.SetValidHealthBarTarget( false )
	AddEntityCallback_OnDamaged( npc, OnNukeTitanDamaged )
	AddEntityCallback_OnPostDamaged( npc, OnNukeTitanPostDamaged )
	file.theNukeTitan = npc
	
	entity soul = npc.GetTitanSoul()
	soul.SetPreventCrits( true )
	soul.SetDamageNotifications( false )
	soul.SetShieldHealthMax( file.nukeHarvesterShieldMax )
	SetGlobalNetEnt( "nukeTitanSoul", soul )
	
	npc.AssaultSetFightRadius( 0 )
	npc.SetDangerousAreaReactionTime( 30 )
	
	npc.Minimap_AlwaysShow( TEAM_IMC, null )
	npc.Minimap_AlwaysShow( TEAM_MILITIA, null )
	npc.Minimap_SetHeightTracking( true )
	npc.Minimap_SetAlignUpright( true )
	npc.Minimap_SetZOrder( MINIMAP_Z_NPC )
	npc.Minimap_SetCustomState( eMinimapObject_npc_titan.AT_BOUNTY_BOSS )
	
	npc.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )
	NukeTitanThink( npc, file.militiaHarvester.harvester )
	
	entity radiusModel = CreatePropDynamic( NUKETITAN_PUSHRADIUS_MODEL, file.nukeTitanSpawnSpot, file.nukeTitanSpawnAngle, 0 )
	radiusModel.SetParent( npc )

	npc.SetNPCPriorityOverride_NoThreat()
	npc.GetTitanSoul().SetTitanSoulNetBool( "showOverheadIcon", true )
	thread PayloadNukeTitanShieldTracker( npc )
	thread PayloadNukeTitanProximityChecker( npc )
	thread Payload_WaitForNukeTitanDeath( npc )
}

void function AddTurretSentry( entity turret )
{
	turret.SetShieldHealthMax( 1250 )
	turret.SetShieldHealth( turret.GetShieldHealthMax() )
	entity player = turret.GetBossPlayer()
	if ( player != null )
	{
		turret.kv.AccuracyMultiplier = 6.0
		turret.kv.WeaponProficiency = eWeaponProficiency.VERYGOOD
		turret.kv.meleeable = 0
		if ( turret.GetMainWeapons()[0].GetWeaponClassName() == "mp_weapon_yh803_bullet" )
			turret.GetMainWeapons()[0].AddMod( "fd" )
	}
}

void function PLD_SpawnDroppodGrunts( entity node, int team )
{
	vector pos = node.GetOrigin()
	entity pod = CreateDropPod( pos, < 0, RandomIntRange( 0, 359 ), 0 > )
	SetTeam( pod, team )
	InitFireteamDropPod( pod )

	string squadName = MakeSquadName( team, UniqueString() )
	array<entity> guys

	for ( int i = 0; i < 4; i++ )
    {
		entity guy = CreateSoldier( team, pos, < 0, 0, 0 > )
		SetSpawnflags( guy, SF_NPC_START_EFFICIENT )
		SetSpawnOption_Alert( guy )
		guy.kv.grenadeWeaponName = ["mp_weapon_grenade_electric_smoke","mp_weapon_grenade_emp","mp_weapon_frag_grenade","mp_weapon_thermite_grenade"].getrandom()
		SetSpawnOption_Weapon( guy, [ "mp_weapon_rspn101", "mp_weapon_dmr", "mp_weapon_vinson", "mp_weapon_hemlok_smg", "mp_weapon_mastiff", "mp_weapon_shotgun_pistol", "mp_weapon_g2", "mp_weapon_doubletake", "mp_weapon_hemlok", "mp_weapon_rspn101_og", "mp_weapon_r97", "mp_weapon_shotgun_doublebarrel", "mp_weapon_esaw", "mp_weapon_lstar", "mp_weapon_shotgun", "mp_weapon_lmg", "mp_weapon_smr", "mp_weapon_epg" ].getrandom() )
		DispatchSpawn( guy )
		guy.EnableNPCFlag( NPC_NO_WEAPON_DROP | NPC_NO_PAIN | NPC_NO_GESTURE_PAIN | NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS | NPC_IGNORE_FRIENDLY_SOUND | NPC_NEW_ENEMY_FROM_SOUND | NPC_AIM_DIRECT_AT_ENEMY )
		guy.DisableNPCFlag( NPC_ALLOW_FLEE )
		guy.SetParent( pod, "ATTACH", true )
		SetSquad( guy, squadName )

		foreach ( entity weapon in guy.GetMainWeapons() )
		{
			if ( weapon.GetWeaponClassName() == "mp_weapon_rocket_launcher" )
				guy.TakeWeapon( weapon.GetWeaponClassName() )
		}

		guy.MakeInvisible()
		entity weapon = guy.GetActiveWeapon()
		if ( IsValid( weapon ) )
			weapon.MakeInvisible()
		
		guy.AssaultSetGoalRadius( 640 )
		guy.AssaultSetGoalHeight( 640 )
		guy.AssaultSetFightRadius( 2048 )
		guy.kv.AccuracyMultiplier = 4.0
		guy.kv.WeaponProficiency = eWeaponProficiency.VERYGOOD
		guy.SetBehaviorSelector( "behavior_sp_soldier" )
		spawnedNPCs.append( guy )
		guys.append( guy )
	}
	
	ToggleSpawnNodeInUse( node, true )
	waitthread LaunchAnimDropPod( pod, "pod_testpath", pos, < 0, RandomIntRange( 0, 359 ), 0 > )
	ArrayRemoveDead( guys )
	ActivateFireteamDropPod( pod, guys )
	ToggleSpawnNodeInUse( node, false )

	foreach ( npc in guys )
	{
		AddMinimapForHumans( npc )
		npc.SetEfficientMode( false )
		thread GruntPathsToObjectives( npc )
	}
}










/*

 ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗██████╗  ██████╗ ██╗███╗   ██╗████████╗    ██╗      ██████╗  ██████╗ ██╗ ██████╗
██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝██╔══██╗██╔═══██╗██║████╗  ██║╚══██╔══╝    ██║     ██╔═══██╗██╔════╝ ██║██╔════╝
██║     ███████║█████╗  ██║     █████╔╝ ██████╔╝██║   ██║██║██╔██╗ ██║   ██║       ██║     ██║   ██║██║  ███╗██║██║     
██║     ██╔══██║██╔══╝  ██║     ██╔═██╗ ██╔═══╝ ██║   ██║██║██║╚██╗██║   ██║       ██║     ██║   ██║██║   ██║██║██║     
╚██████╗██║  ██║███████╗╚██████╗██║  ██╗██║     ╚██████╔╝██║██║ ╚████║   ██║       ███████╗╚██████╔╝╚██████╔╝██║╚██████╗
 ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝╚═╝  ╚═══╝   ╚═╝       ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝ ╚═════╝

*/

void function OnNukeTitanEnteredCheckpoint( entity trigger, entity titan )
{
	if ( titan != file.theNukeTitan || !GamePlaying() )
		return
	
	entity checkpoint = trigger.GetParent()
	
	SetTeam( checkpoint, TEAM_IMC )
	
	foreach ( zone in file.checkPoints[checkpoint] )
		SetTeamSpawnZoneMinimapMarker( zone, TEAM_IMC )
	
	file.checkpointEnts[file.capturedCheckpoints].SetHardpointState( CAPTURE_POINT_STATE_CAPTURED )
	SetGlobalNetFloat( "objective" + file.capturedCheckpoints + "Progress", 1.0 )
	SetGlobalNetInt( "objective" + file.capturedCheckpoints + "CappingTeam", TEAM_UNASSIGNED )

	file.capturedCheckpoints++
	if( file.capturedCheckpoints < file.checkpointEnts.len() )
	{
		SetGlobalNetInt( "objective" + file.capturedCheckpoints + "CappingTeam", TEAM_IMC )
		file.checkpointEnts[file.capturedCheckpoints].SetHardpointState( CAPTURE_POINT_STATE_CAPPING )
	}
	
	thread FactionAnnouncesCheckpointDelayed()
	
	MessageToAll( eEventNotifications.TEMP_RodeoExpress_Success )
	
	foreach ( player in GetPlayerArrayOfTeam( TEAM_MILITIA ) )
		EmitSoundOnEntityOnlyToPlayer( player, player, "UI_CTF_3P_EnemyScores" )
	
	foreach ( player in GetPlayerArrayOfTeam( TEAM_IMC ) )
		EmitSoundOnEntityOnlyToPlayer( player, player, "UI_CTF_1P_PlayerScore" )
	
	SetServerVar( "gameEndTime", Time() + ( 60 * file.checkpointBonusTime ) )
	SetServerVar( "roundEndTime", Time() + ( 60 * file.checkpointBonusTime ) )
	
	trigger.Destroy()
}

void function SetCheckpointMinimapIcon( entity point )
{
	int miniMapObjectCheckpoint = point.GetHardpointID() + 1

	point.Minimap_SetCustomState( miniMapObjectCheckpoint )
	point.Minimap_AlwaysShow( TEAM_MILITIA, null )
	point.Minimap_AlwaysShow( TEAM_IMC, null )
	point.Minimap_SetAlignUpright( true )
	
	SetTeam( point, TEAM_MILITIA )
}

void function SetTeamSpawnZoneMinimapMarker( entity marker, int team )
{
	marker.Minimap_SetObjectScale( marker.s.zoneRadius / 16000 )
	marker.Minimap_SetAlignUpright( true )
	marker.Minimap_AlwaysShow( TEAM_IMC, null )
	marker.Minimap_AlwaysShow( TEAM_MILITIA, null )
	marker.Minimap_SetHeightTracking( true )
	marker.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	
	SetTeam( marker, team )
	
	if ( team == TEAM_IMC )
		marker.Minimap_SetCustomState( eMinimapObject_prop_script.SPAWNZONE_IMC )
	else
		marker.Minimap_SetCustomState( eMinimapObject_prop_script.SPAWNZONE_MIL )
}










/*

███╗   ██╗██╗   ██╗██╗  ██╗███████╗    ████████╗██╗████████╗ █████╗ ███╗   ██╗    ██╗      ██████╗  ██████╗ ██╗ ██████╗
████╗  ██║██║   ██║██║ ██╔╝██╔════╝    ╚══██╔══╝██║╚══██╔══╝██╔══██╗████╗  ██║    ██║     ██╔═══██╗██╔════╝ ██║██╔════╝
██╔██╗ ██║██║   ██║█████╔╝ █████╗         ██║   ██║   ██║   ███████║██╔██╗ ██║    ██║     ██║   ██║██║  ███╗██║██║     
██║╚██╗██║██║   ██║██╔═██╗ ██╔══╝         ██║   ██║   ██║   ██╔══██║██║╚██╗██║    ██║     ██║   ██║██║   ██║██║██║     
██║ ╚████║╚██████╔╝██║  ██╗███████╗       ██║   ██║   ██║   ██║  ██║██║ ╚████║    ███████╗╚██████╔╝╚██████╔╝██║╚██████╗
╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝       ╚═╝   ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝    ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝ ╚═════╝

*/


void function Payload_WaitForNukeTitanDeath( entity titan )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )
	
	titan.WaitSignal( "OnDestroy" )
	wait 3
	
	if( file.militiaHarvester.harvester.GetHealth() > 1 )
	{
		Riff_ForceSetEliminationMode( eEliminationMode.Pilots )
		SetServerVar( "gameEndTime", Time() )
		SetServerVar( "roundEndTime", Time() )
	}
}

void function PayloadNukeTitanProximityChecker( entity titan )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" ) // Stop this for any change game state, timeout or winner determined in case
	
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "TitanEjectionStarted" ) // We only stop this if the Titan is successfully nuking nearby the Harvester
	
	entity soul = titan.GetTitanSoul()
	soul.EndSignal( "OnDeath" )
	soul.EndSignal( "OnDestroy" )
	
	titan.AssaultSetGoalRadius( titan.GetMinGoalRadius() )
	titan.AssaultPointClamped( titan.GetOrigin() )
	titan.AssaultSetFightRadius( 0 )
	titan.SetNPCMoveSpeedScale( 0.01 )
	
	while ( true )
	{
		array<entity> nearbyFriendlies
		array<entity> nearbyEnemies
		foreach ( player in GetPlayerArrayOfTeam_Alive( titan.GetTeam() ) )
		{
			if ( Distance( player.GetOrigin(), titan.GetOrigin() ) < PLD_PUSH_DIST )
			{
				nearbyFriendlies.append( player )
				player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, PAYLOAD_SCORE_OBJECTIVE_ESCORT )
				file.matchPlayers[player].nearNukeTitan = true
			}
			else
				file.matchPlayers[player].nearNukeTitan = false
		}
		
		foreach ( enemy in GetPlayerArrayOfTeam_Alive( GetOtherTeam( titan.GetTeam() ) ) )
		{
			if ( Distance( enemy.GetOrigin(), titan.GetOrigin() ) < PLD_PUSH_DIST )
			{
				enemy.AddToPlayerGameStat( PGS_ASSAULT_SCORE, PAYLOAD_SCORE_OBJECTIVE_DEFENSE_HALT )
				nearbyEnemies.append( enemy )
			}
		}
		
		if ( soul.GetShieldHealth() == 0 )
		{
			if ( nearbyFriendlies.len() )
				SetGlobalNetInt( "imcChevronState", nearbyFriendlies.len() )
			else
				SetGlobalNetInt( "imcChevronState", 0 )
			
			if ( nearbyEnemies.len() )
				SetGlobalNetInt( "milChevronState", nearbyEnemies.len() )
			else
				SetGlobalNetInt( "milChevronState", 0 )
			
			if ( !nearbyFriendlies.len() && file.nukeIsMoving || nearbyEnemies.len() )
			{
				titan.Signal( "PayloadNukeTitanStopped" )
				titan.AssaultPointClamped( titan.GetOrigin() )
				
				if( file.capturedCheckpoints < file.checkpointEnts.len() )
				{
					SetGlobalNetInt( "objective" + file.capturedCheckpoints + "CappingTeam", TEAM_UNASSIGNED )
					file.checkpointEnts[file.capturedCheckpoints].SetHardpointState( CAPTURE_POINT_STATE_HALTED )
				}
				
				file.nukeIsMoving = false
			}
			else if ( nearbyFriendlies.len() && !nearbyEnemies.len() )
			{
				int playerMultiplier = nearbyFriendlies.len()
				if ( playerMultiplier > 4 ) // In the other TF2 the cap is 4 player to max boost
					playerMultiplier = 4
				
				float moveSpeedScale = PLD_BASE_NUKE_TITAN_MOVESPEED_SCALE * playerMultiplier.tofloat()
				
				titan.SetNPCMoveSpeedScale( moveSpeedScale )
				
				if ( !file.nukeIsMoving )
				{
					file.nukeIsMoving = true
					
					if( file.capturedCheckpoints < file.checkpointEnts.len() )
					{
						SetGlobalNetInt( "objective" + file.capturedCheckpoints + "CappingTeam", titan.GetTeam() )
						file.checkpointEnts[file.capturedCheckpoints].SetHardpointState( CAPTURE_POINT_STATE_CAPPING )
					}
					
					thread MovePayloadNukeTitan( titan, file.currentRouteNode )
				}
			}
		}
		else
		{
			SetGlobalNetInt( "imcChevronState", 3 )
			SetGlobalNetInt( "milChevronState", 0 )
			
			if ( !file.nukeIsMoving )
			{
				file.nukeIsMoving = true
					
				if( file.capturedCheckpoints < file.checkpointEnts.len() )
				{
					SetGlobalNetInt( "objective" + file.capturedCheckpoints + "CappingTeam", titan.GetTeam() )
					file.checkpointEnts[file.capturedCheckpoints].SetHardpointState( CAPTURE_POINT_STATE_CAPPING )
				}
					
				thread MovePayloadNukeTitan( titan, file.currentRouteNode )
			}
			titan.SetNPCMoveSpeedScale( PLD_BASE_NUKE_TITAN_MOVESPEED_SCALE * 3 )
		}
		
		TrackCheckpointProgress( file.capturedCheckpoints )
		
		wait 0.5
	}
}

void function MovePayloadNukeTitan( entity titan, int routeindex )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )
	titan.EndSignal( "PayloadNukeTitanStopped" )
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	
	vector routepoint = file.payloadRoute[routeindex]
	
	while ( true )
	{
		titan.AssaultPointClamped( routepoint )
			
		table result = titan.WaitSignal( "OnFinishedAssault" )
		routeindex++
		if ( routeindex < file.payloadRoute.len() )
		{
			routepoint = file.payloadRoute[routeindex]
			file.currentRouteNode = routeindex
		}
		else
			break
	}

	titan.AssaultSetGoalHeight( 128 )

	titan.Signal( "FD_ReachedHarvester" )
}

void function PayloadNukeTitanShieldTracker( entity titan )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	
	entity soul = titan.GetTitanSoul()
	soul.EndSignal( "OnDeath" )
	soul.EndSignal( "OnDestroy" )
	
	int attachID = titan.LookupAttachment( "ORIGIN" )
	entity TitanShield
	
	while( true )
	{
		if( soul.GetShieldHealth() > 0 )
		{
			if ( IsValid( TitanShield ) )
			{
				vector shieldColor = GetShieldTriLerpColor( 1.0 - ( soul.GetShieldHealth().tofloat() / soul.GetShieldHealthMax().tofloat() ) )
				EffectSetControlPointVector( TitanShield, 1, shieldColor )
			}
			else
				TitanShield = StartParticleEffectOnEntity_ReturnEntity( titan, GetParticleSystemIndex( NUKETITAN_SHIELDWALL ), FX_PATTACH_POINT_FOLLOW, attachID )
		}
		else
		{
			if ( IsValid( TitanShield ) )
				TitanShield.Destroy()
		}
		
		WaitFrame()
	}
	
	OnThreadEnd(
		function() : ( TitanShield )
		{
			if ( IsValid( TitanShield ) )
				TitanShield.Destroy()
		}
	)
}

void function TrackCheckpointProgress( int checkpointIndex )
{
	vector previousCheckpointPos
	switch ( checkpointIndex )
	{
		case 0:
			previousCheckpointPos = file.nukeTitanSpawnSpot
			break
		
		case 1:
			previousCheckpointPos = file.checkpointEnts[0].GetOrigin()
			break
		
		case 2:
			previousCheckpointPos = file.checkpointEnts[1].GetOrigin()
			break
		
		default:
			return
	}
	
	float progress = clamp( GetProgressAlongLineSegment( file.theNukeTitan.GetOrigin(), previousCheckpointPos, file.checkpointEnts[checkpointIndex].GetOrigin() ) , 0.0, 1.0 )
	
	SetGlobalNetFloat( "objective" + checkpointIndex + "Progress", progress )
}










/*

██████╗  █████╗ ███╗   ███╗ █████╗  ██████╗ ███████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
██╔══██╗██╔══██╗████╗ ████║██╔══██╗██╔════╝ ██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
██║  ██║███████║██╔████╔██║███████║██║  ███╗█████╗      █████╗  ██║   ██║██╔██╗ ██║██║        ██║   ██║██║   ██║██╔██╗ ██║███████╗
██║  ██║██╔══██║██║╚██╔╝██║██╔══██║██║   ██║██╔══╝      ██╔══╝  ██║   ██║██║╚██╗██║██║        ██║   ██║██║   ██║██║╚██╗██║╚════██║
██████╔╝██║  ██║██║ ╚═╝ ██║██║  ██║╚██████╔╝███████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝

*/


//This is intentionally blank just so it doesn't give boost meter for Defenders if they use Anti-Titan weapons against the Nuke Titan or damage its Shields
void function GameModeRulesEarnMeterOnDamage_PLD( entity attacker, entity victim, TitanDamage titanDamage, float savedDamage )
{
}

void function OnHarvesterDamaged( entity harvester, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	int damageSourceID = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	float damageAmount = DamageInfo_GetDamage( damageInfo )
	
	if( !GamePlaying() || attacker.GetTeam() == harvester.GetTeam() )
	{
		DamageInfo_ScaleDamage( damageInfo, 0.0 )
		return
	}
	
	if ( IsValid( inflictor ) )
	{
		if ( inflictor.IsProjectile() && IsValid( inflictor.GetOwner() ) )
			attacker = inflictor.GetOwner()
		
		else if ( inflictor.IsNPC() )
			attacker = inflictor
	}
	
	if ( harvester.GetShieldHealth() == 0 )
	{
		if ( IsValid( file.militiaHarvester.particleShield ) )
			file.militiaHarvester.particleShield.Destroy()
		
		if ( damageSourceID != eDamageSourceId.damagedef_nuclear_core ) //Block all damage that isn't the Nuke Titan one
		{
			if ( attacker.IsPlayer() && attacker.GetTeam() == TEAM_IMC )
			{
				SendHudMessage( attacker, "#MSG_HARVESTER_DESTROY_HINT", -1, 0.4, 255, 255, 255, 255, 0.0, 2.0, 0.5 )
				DamageInfo_ScaleDamage( damageInfo, 0.0 )
				return
			}
		}
	}
	else
	{
		if ( attacker.IsNPC() && attacker != file.theNukeTitan ) // Turrets wont help breaking the Harvester shield
		{
			DamageInfo_SetDamage( damageInfo, 0.0 )
			return
		}
		
		if ( Distance2D( harvester.GetOrigin(), attacker.GetOrigin() ) > PLD_HARVESTER_PERIMETER_DIST )
		{
			DamageInfo_SetDamage( damageInfo, 0.0 )
			if ( attacker.IsPlayer() )
				SendHudMessage( attacker, "#MSG_HARVESTER_SHIELD_HINT", -1, 0.4, 255, 255, 255, 255, 0.0, 2.0, 0.5 )
			return
		}
	}
	
	if ( IsValid( file.militiaHarvester.particleShield ) && harvester.GetShieldHealth() > 0 )
	{
		vector shieldColor = GetShieldTriLerpColor( 1.0 - ( harvester.GetShieldHealth().tofloat() / harvester.GetShieldHealthMax().tofloat() ) )
		EffectSetControlPointVector( file.militiaHarvester.particleShield, 1, shieldColor )
	}
	
	if ( harvester.GetShieldHealth() == 0 )
	{
		if( DamageInfo_GetDamageSourceIdentifier( damageInfo ) != eDamageSourceId.damagedef_nuclear_core )
		{
			DamageInfo_SetDamage( damageInfo, 0.0 )
			return
		}
		
		float newHealth = harvester.GetHealth() - damageAmount
		if ( newHealth <= 0 )
		{
			newHealth = 1
			harvester.SetInvulnerable()
			DamageInfo_SetDamage( damageInfo, 0.0 )
			file.militiaHarvester.rings.Anim_Play( HARVESTER_ANIM_DESTROYED )
			playHarvesterDestructionFX( file.militiaHarvester )
			
			harvester.SetHealth( newHealth )
			
			if ( IsValid( file.militiaHarvester.particleShield ) )
				file.militiaHarvester.particleShield.Destroy()
			
			SetWinner( TEAM_IMC, "#PLD_VICTORY_MESSAGE_OBJECTIVE", "#PLD_DEFEAT_MESSAGE_OBJECTIVE" )
		}
	}
	
	UpdateShieldTrackingOfNukeOrHarvester( harvester, harvester.GetShieldHealth() )
}

void function OnNukeTitanDamaged( entity npc, var damageInfo )
{
	int damageSourceID = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	entity soul = npc.GetTitanSoul()
	
	if( IsValid( soul ) && damageSourceID == eDamageSourceId.mp_weapon_grenade_emp )
		file.nukeTitanShieldHack = soul.GetShieldHealth()
}

void function OnNukeTitanPostDamaged( entity npc, var damageInfo )
{
	int damageSourceID = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	entity soul = npc.GetTitanSoul()
	
	if( IsValid( soul ) )
	{
		if ( damageSourceID == eDamageSourceId.mp_weapon_grenade_emp ) // Bypass the Arc Grenade taking shield by percentage because funni Respawn design towards it
		{
			int shieldTakeSegment = soul.GetShieldHealthMax() / 10
			file.nukeTitanShieldHack -= shieldTakeSegment
			soul.SetShieldHealth( maxint( 0, file.nukeTitanShieldHack ) )
		}
		
		UpdateShieldTrackingOfNukeOrHarvester( npc, soul.GetShieldHealth() )
		if ( soul.GetShieldHealth() == 0 )
			DamageInfo_SetDamage( damageInfo, 0.0 ) // Basically invulnerability
	}
}

void function PLD_DamagePlayerScale( entity ent, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValidPlayer( attacker ) && GetCurrentPlaylistVarInt( "pld_gruntplayers", 0 ) == 1 )
		DamageInfo_ScaleDamage( damageInfo, 0.2 )
	else if( IsAlive( file.theNukeTitan ) )
	{
		if ( Distance( ent.GetOrigin(), file.theNukeTitan.GetOrigin() ) < PLD_PUSH_DIST )
		{
			switch ( DamageInfo_GetDamageSourceIdentifier( damageInfo ) )
			{
				case eDamageSourceId.mp_weapon_sniper:
				case eDamageSourceId.mp_weapon_mastiff:
				case eDamageSourceId.mp_weapon_shotgun:
				case eDamageSourceId.mp_weapon_defender:
				case eDamageSourceId.mp_weapon_epg:
				case eDamageSourceId.mp_weapon_softball:
				case eDamageSourceId.mp_weapon_satchel:
				case eDamageSourceId.mp_weapon_frag_grenade:
				case eDamageSourceId.mp_weapon_thermite_grenade:
				case eDamageSourceId.mp_weapon_pulse_lmg:
				DamageInfo_ScaleDamage( damageInfo, 0.1 )
				break
				
				case eDamageSourceId.mp_weapon_lstar:
				case eDamageSourceId.mp_weapon_smr:
				DamageInfo_ScaleDamage( damageInfo, 0.2 )
				break
				
				default:
				DamageInfo_ScaleDamage( damageInfo, 0.4 )
			}
		}
	}
}










/*

███╗   ███╗██╗███████╗ ██████╗███████╗██╗     ██╗      █████╗ ███╗   ██╗███████╗ ██████╗ ██╗   ██╗███████╗
████╗ ████║██║██╔════╝██╔════╝██╔════╝██║     ██║     ██╔══██╗████╗  ██║██╔════╝██╔═══██╗██║   ██║██╔════╝
██╔████╔██║██║███████╗██║     █████╗  ██║     ██║     ███████║██╔██╗ ██║█████╗  ██║   ██║██║   ██║███████╗
██║╚██╔╝██║██║╚════██║██║     ██╔══╝  ██║     ██║     ██╔══██║██║╚██╗██║██╔══╝  ██║   ██║██║   ██║╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗███████╗███████╗███████╗██║  ██║██║ ╚████║███████╗╚██████╔╝╚██████╔╝███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝

*/

void function Spawner_Threaded( int team )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )

	wait 5.0
	while( true )
	{
		array<entity> npcs = GetNPCArrayOfTeam( team )
		
		ArrayRemoveDead( npcs )
		foreach ( entity npc in npcs )
		{
			if( IsMinion( npc ) || IsStalker( npc ) )
				continue
			
			npcs.removebyvalue( npc )
		}
		
		int count = npcs.len()
		if ( count <= PAYLOAD_GRUNTS_PER_TEAM )
		{
			entity node = GetBestNodeForGruntPod( team )
			thread PLD_SpawnDroppodGrunts( node, team )
		}
		
		wait 1.0
	}
}

entity function GetBestNodeForGruntPod( int team )
{
	SpawnPoints_InitRatings( null, team )
	float distance = Distance2D( file.harvesterSpawnSpot, file.nukeTitanSpawnSpot )
	foreach ( entity spawnpoint in SpawnPoints_GetDropPod() )
	{
		float currentRating = 1.0 * ( 1 - ( distance / 4000.0 ) )
		float friendliesScore = spawn.NearbyAllyScore( team, "ai" ) + spawn.NearbyAllyScore( team, "titan" ) + spawn.NearbyAllyScore( team, "pilot" )
		float enemiesRating = spawn.NearbyEnemyScore( team, "ai" ) + spawn.NearbyEnemyScore( team, "titan" ) + spawn.NearbyEnemyScore( team, "pilot" )
		currentRating += friendliesScore + enemiesRating
		spawnpoint.CalculateRating( TD_AI, team, currentRating, currentRating * 0.25 )
	}
	
	SpawnPoints_SortDropPod()
	
	array< entity > spawnpoints = SpawnPoints_GetDropPod()
	
	return spawnpoints[0]
}

void function GruntPathsToObjectives( entity npc )
{
	npc.EndSignal( "OnDestroy" )
	npc.EndSignal( "OnDeath" )

	if( !GamePlaying() )
		return
	
	int team = npc.GetTeam()
	
	while ( IsAlive( npc ) )
	{
		vector assaultPoint
		if( team == TEAM_IMC )
		{
			if( IsAlive( file.theNukeTitan ) )
				assaultPoint = file.theNukeTitan.GetOrigin()
			else
				assaultPoint = file.nukeTitanSpawnSpot
		}
		else if( team == TEAM_MILITIA )
		{
			assaultPoint = file.harvesterSpawnSpot
			foreach( entity point in file.checkpointEnts )
			{
				if( point.GetTeam() == TEAM_MILITIA )
				{
					assaultPoint = point.GetOrigin()
					break
				}
			}
		}

		npc.AssaultPoint( assaultPoint )
		wait 5
	}
}

void function PLD_OnPlayerGetsNewPilotLoadout( entity player, PilotLoadoutDef loadout )
{
	loadout.setFileMods.append( "disable_wallrun" )
	loadout.setFileMods.append( "disable_doublejump" )
	loadout.race = "race_human_male"
	loadout.setFile = GetSuitAndGenderBasedSetFile( loadout.suit, loadout.race )
	player.SetPlayerSettingsWithMods( loadout.setFile, loadout.setFileMods )
	
	player.TakeOffhandWeapon( OFFHAND_SPECIAL )
	SyncedMelee_Disable( player )
	
	entity weapon = player.GetActiveWeapon()
	string weaponSubClass
	if ( IsValid( weapon ) )
		weaponSubClass = string( weapon.GetWeaponInfoFileKeyField( "weaponSubClass" ) )
	
	asset model
	switch ( player.GetTeam() )
	{
		case TEAM_MILITIA:
			switch ( weaponSubClass )
			{
				case "lmg":
				case "sniper":
					model = TEAM_MIL_GRUNT_MODEL_LMG
					break

				case "rocket":
				case "shotgun":
				case "projectile_shotgun":
					model = TEAM_MIL_GRUNT_MODEL_SHOTGUN
					break

				case "handgun":
				case "smg":
				case "sidearm":
					model = TEAM_MIL_GRUNT_MODEL_SMG
					break

				case "rifle":
				default:
					model = TEAM_MIL_GRUNT_MODEL_RIFLE
					break
			}
			break

		case TEAM_IMC:
		default:
			switch ( weaponSubClass )
			{
				case "lmg":
				case "sniper":
					model = TEAM_IMC_GRUNT_MODEL_LMG
					break

				case "rocket":
				case "shotgun":
				case "projectile_shotgun":
					model = TEAM_IMC_GRUNT_MODEL_SHOTGUN
					break

				case "handgun":
				case "smg":
				case "sidearm":
					model = TEAM_IMC_GRUNT_MODEL_SMG
					break

				case "rifle":
				default:
					model = TEAM_IMC_GRUNT_MODEL
					break
			}
			break
	}
	player.SetModel( model )
}

int function PLD_TimeoutWinner()
{
	if (  !IsAlive( file.theNukeTitan ) && IsValid( file.militiaHarvester.harvester ) && file.militiaHarvester.harvester.GetHealth() > 1 )
		return TEAM_UNASSIGNED
	
	// Make those score overrides because reason message won't display properly if both teams are still tied by this moment
	GameRules_SetTeamScore( TEAM_IMC, 0 )
	GameRules_SetTeamScore( TEAM_MILITIA, 1 )
	
	return TEAM_MILITIA
}

void function FactionAnnouncesCheckpointDelayed()
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )
	wait 2
	
	switch ( file.capturedCheckpoints )
	{
		case 1:
		PlayFactionDialogueToTeam( "amphp_friendlyCappedA", TEAM_IMC )
		PlayFactionDialogueToTeam( "amphp_enemyCappedA", TEAM_MILITIA )
		wait 3
		PlayFactionDialogueToTeam( "scoring_winningClose", TEAM_IMC )
		PlayFactionDialogueToTeam( "scoring_losingClose", TEAM_MILITIA )
		break
		
		case 2:
		PlayFactionDialogueToTeam( "amphp_friendlyCappedB", TEAM_IMC )
		PlayFactionDialogueToTeam( "amphp_enemyCappedB", TEAM_MILITIA )
		wait 3
		PlayFactionDialogueToTeam( "scoring_winning", TEAM_IMC )
		PlayFactionDialogueToTeam( "scoring_losing", TEAM_MILITIA )
		break
		
		case 3:
		PlayFactionDialogueToTeam( "amphp_friendlyCappedC", TEAM_IMC )
		PlayFactionDialogueToTeam( "amphp_enemyCappedC", TEAM_MILITIA )
		wait 3
		PlayFactionDialogueToTeam( "amphp_friendlyCapAll", TEAM_IMC )
		PlayFactionDialogueToTeam( "amphp_enemyCapAll", TEAM_MILITIA )
		wait 4
		PlayFactionDialogueToTeam( "scoring_winningLarge", TEAM_IMC )
		PlayFactionDialogueToTeam( "scoring_losingLarge", TEAM_MILITIA )
		break
	}
}

function PayloadBatteryPortUseCheck( batteryPortvar, playervar )
{	
	entity batteryPort = expect entity( batteryPortvar )
	entity player = expect entity( playervar )
	entity harvester = expect entity( batteryPort.s.bindedHarvester )
	
    if ( !IsValid( harvester ) )
        return false

    return ( PlayerHasBattery( player ) && player.GetTeam() == harvester.GetTeam() && harvester.GetShieldHealth() < harvester.GetShieldHealthMax() && harvester.GetHealth() > 1 )
}

function PayloadUseBatteryFunc( batteryPortvar, playervar )
{
	entity batteryPort = expect entity( batteryPortvar )
	entity player = expect entity( playervar )
    entity harvester = expect entity( batteryPort.s.bindedHarvester )
	
	if ( !IsValid( player ) || harvester.GetShieldHealth() == harvester.GetShieldHealthMax() )
		return
	
	AddPlayerScore( player, "FDShieldHarvester", player )
	player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, PAYLOAD_SCORE_OBJECTIVE_SHIELD_HARVESTER )
	
	int shieldToBoost = harvester.GetShieldHealth()
	shieldToBoost += harvester.GetShieldHealthMax() / 4
	
    harvester.SetShieldHealth( min( shieldToBoost, harvester.GetShieldHealthMax() ) )
	UpdateShieldTrackingOfNukeOrHarvester( harvester, minint( shieldToBoost, harvester.GetShieldHealthMax() ) )
	
	if ( !IsValid( file.militiaHarvester.particleShield ) )
	{
		generateShieldFX( file.militiaHarvester )
		EmitSoundOnEntity( file.militiaHarvester.harvester, "shieldwall_deploy" )
		
		vector shieldColor = GetShieldTriLerpColor( 1.0 - ( harvester.GetShieldHealth().tofloat() / harvester.GetShieldHealthMax().tofloat() ) )
		EffectSetControlPointVector( file.militiaHarvester.particleShield, 1, shieldColor )
	}
	else
	{
		vector shieldColor = GetShieldTriLerpColor( 1.0 - ( harvester.GetShieldHealth().tofloat() / harvester.GetShieldHealthMax().tofloat() ) )
		EffectSetControlPointVector( file.militiaHarvester.particleShield, 1, shieldColor )
	}
	
	foreach ( player in GetPlayerArray() )
		Remote_CallFunction_NonReplay( player, "ServerCallback_PLD_ShowTutorialHint", ePLDTutorials.HarvesterBattery )
}

void function Payload_RouteHologramRepeater()
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )
	
	while( true )
	{
		thread Payload_ShowRouteHologram()
		wait PLD_PATH_TRACKER_REFRESH_FREQUENCY
	}
}

void function Payload_ShowRouteHologram()
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )
	
	int routeindex = 0
	vector routepoint = file.payloadRoute[routeindex] + < 0, 0, 64 >
	entity mover = CreateScriptMover( file.nukeTitanSpawnSpot + < 0, 0, 64 > )
	
	while( true )
	{
		PlayLoopFXOnEntity( FLAG_FX_FRIENDLY, mover )
		
		mover.NonPhysicsMoveTo( routepoint, PLD_PATH_TRACKER_MOVE_TIME_BETWEN_POINTS, 0.0, 0.0 )
		wait PLD_PATH_TRACKER_MOVE_TIME_BETWEN_POINTS
		routeindex++
		if ( routeindex < file.payloadRoute.len() )
			routepoint = file.payloadRoute[routeindex] + < 0, 0, 64 >
		else
		{
			mover.Destroy()
			break
		}
	}
}

void function PLD_PilotStartRodeo( entity pilot, entity titan )
{
	Highlight_SetFriendlyHighlight( pilot, "sp_friendly_hero" )
	pilot.Highlight_SetParam( 1, 0, < 0.5, 2.0, 0.5 > )
	
	Highlight_SetEnemyHighlight( pilot, "sp_objective_entity" )
	pilot.Highlight_SetParam( 2, 0, HIGHLIGHT_COLOR_ENEMY )
	
	if( pilot.GetTeam() != titan.GetTeam() && !PlayerHasBattery( pilot ) )
	{
		foreach ( player in GetPlayerArray() )
			Remote_CallFunction_NonReplay( player, "ServerCallback_PLD_ShowTutorialHint", ePLDTutorials.NukeTitanRodeo )
		
		pilot.SetInvulnerable()
	}
}

void function PLD_PilotEndRodeo( entity pilot, entity titan )
{
	HideName( pilot )
	Highlight_ClearEnemyHighlight( pilot )
	Highlight_ClearFriendlyHighlight( pilot )
	
	if ( pilot.IsInvulnerable() )
		pilot.ClearInvulnerable()
}

void function UpdateShieldTrackingOfNukeOrHarvester( entity ent, int shieldAmount )
{
	int shieldStack = int( max( ( shieldAmount - ( shieldAmount % 256 ) ) / 256, 0 ) )
	int shieldRemainder = ( shieldAmount % 256 )

	if( ent == file.theNukeTitan )
	{
		SetGlobalNetInt( "nukeTitanShield", shieldRemainder )
		SetGlobalNetInt( "nukeTitanShield256", shieldStack )
	}
	
	else if( ent == file.militiaHarvester.harvester )
	{
		SetGlobalNetInt( "militiaHarvesterShield", shieldRemainder )
		SetGlobalNetInt( "militiaHarvesterShield256", shieldStack )
	}
}