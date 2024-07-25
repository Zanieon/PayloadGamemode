untyped

global function GamemodePLD_Init
global function RateSpawnpoints_PLD

global function Payload_SetMilitiaHarvesterLocation
global function Payload_SetNukeTitanSpawnLocation

global function AddPayloadCheckpointWithZones
global function AddPayloadCustomMapProp
global function AddPayloadCustomShipStart
global function AddPayloadFixedSpawnZoneForTeam
global function AddPayloadRouteNode

global function AddCallback_PayloadMode



const float PLD_HARVESTER_PERIMETER_DIST = 8000.0
const float PLD_PUSH_DIST = 400.0
const float PLD_BASE_NUKE_TITAN_MOVESPEED_SCALE = 0.1

const int PAYLOAD_SCORE_OBJECTIVE_DEFENSE_KILL = 6
const int PAYLOAD_SCORE_OBJECTIVE_DEFENSE_BONUS = 15
const int PAYLOAD_SCORE_OBJECTIVE_DEFENSE_HALT = 1
const int PAYLOAD_SCORE_OBJECTIVE_ESCORT = 1
const int PAYLOAD_SCORE_OBJECTIVE_ESCORT_KILL = 2
const int PAYLOAD_SCORE_OBJECTIVE_ESCORT_BONUS = 30
const int PAYLOAD_SCORE_OBJECTIVE_SHIELD_HARVESTER = 35
const int PAYLOAD_SCORE_OBJECTIVE_SHIELD_TITAN = 20

const int PLD_MAX_SHIELD_NUKE_AND_HARVESTER = 25000

const asset NUKETITAN_SHIELDWALL = $"P_shield_hld_01_CP" // "P_turret_shield_wall" is also a potential use



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
	
	PrecacheParticleSystem( FLAG_FX_FRIENDLY )
	
	RegisterSignal( "FD_ReachedHarvester" ) //For Nuke Titan navigation
	RegisterSignal( "PayloadNukeTitanStopped" )
	RegisterSignal( "BatteryActivate" ) //From Frontier War, to give shields to the Harvester
	
	SetTimeoutWinnerDecisionFunc( PLD_TimeoutWinner )
	
	ClassicMP_ForceDisableEpilogue( true )
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
	
	AddSpawnCallback( "npc_turret_sentry", AddTurretSentry )
	
	ScoreEvent_SetDisplayType( GetScoreEvent( "FDShieldHarvester" ), eEventDisplayType.GAMEMODE | eEventDisplayType.MEDAL | eEventDisplayType.CALLINGCARD )
	ScoreEvent_SetDisplayType( GetScoreEvent( "PilotBatteryApplied" ), eEventDisplayType.GAMEMODE | eEventDisplayType.MEDAL | eEventDisplayType.CALLINGCARD )
	ScoreEvent_SetDisplayType( GetScoreEvent( "PilotBatteryStolen" ), eEventDisplayType.GAMEMODE | eEventDisplayType.MEDAL | eEventDisplayType.CALLINGCARD )
	
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
	
	level.endOfRoundPlayerState = ENDROUND_MOVEONLY
}

void function LoadPayloadContent()
{
	foreach ( callback in file.payloadCallbacks )
		callback()
}

void function StartHarvesterAndPrepareNukeTitan()
{
	thread StartHarvesterAndPrepareNukeTitan_threaded()
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
	foreach ( player in GetPlayerArray() )
		Remote_CallFunction_NonReplay( player, "ServerCallback_PLD_PlayBattleMusic" )
	
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
	
	Remote_CallFunction_NonReplay( player, "ServerCallback_PLD_PlayBattleMusic" )
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
	if ( GamePlaying() )
		return
	
	if( attacker.GetTeam() == TEAM_IMC && file.matchPlayers[victim].nearNukeTitan )
		attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, PAYLOAD_SCORE_OBJECTIVE_DEFENSE_KILL )
	
	if( attacker.GetTeam() == TEAM_MILITIA && file.matchPlayers[attacker].nearNukeTitan && victim.GetTeam() == TEAM_MILITIA )
		attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, PAYLOAD_SCORE_OBJECTIVE_ESCORT_KILL )
}

void function PLD_ShieldedNukeTitan( entity rider, entity titan, entity battery )
{
	foreach ( player in GetPlayerArray() )
		Remote_CallFunction_NonReplay( player, "ServerCallback_PLD_ShowTutorialHint", ePLDTutorials.NukeTitanBattery )
	
	rider.AddToPlayerGameStat( PGS_DEFENSE_SCORE, PAYLOAD_SCORE_OBJECTIVE_SHIELD_TITAN )
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
	zone.s.zoneRadius <- zoneRadius
	SetTeamSpawnZoneMinimapMarker( zone, team )
	file.payloadSpawnZones.append( zone )
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
			
			spawn.CalculateRating( checkClass, team, rating, rating )
		}
	}
}

void function PayloadPlayerRespawned( entity player ) // Actual hack because the function above is not doing its job idk why
{
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
	
	file.militiaHarvester.harvester.SetShieldHealthMax( PLD_MAX_SHIELD_NUKE_AND_HARVESTER )
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
	npc.SetNoTarget( true )
	HideName( npc )
	npc.EnableNPCFlag( NPC_DISABLE_SENSING | NPC_IGNORE_ALL )
	npc.EnableNPCMoveFlag( NPCMF_WALK_ALWAYS | NPCMF_WALK_NONCOMBAT )
	npc.DisableNPCMoveFlag( NPCMF_PREFER_SPRINT )
	npc.DisableNPCFlag( NPC_DIRECTIONAL_MELEE )
	npc.SetCapabilityFlag( bits_CAP_INNATE_MELEE_ATTACK1 | bits_CAP_INNATE_MELEE_ATTACK2 | bits_CAP_SYNCED_MELEE_ATTACK , false )
	npc.SetValidHealthBarTarget( false )
	AddEntityCallback_OnFinalDamaged( npc, OnNukeTitanDamaged )
	file.theNukeTitan = npc
	
	entity soul = npc.GetTitanSoul()
	soul.SetPreventCrits( true )
	soul.SetShieldHealthMax( PLD_MAX_SHIELD_NUKE_AND_HARVESTER )
	
	npc.AssaultSetFightRadius( 0 )
	npc.SetDangerousAreaReactionTime( 99 )
	
	npc.Minimap_AlwaysShow( TEAM_IMC, null )
	npc.Minimap_AlwaysShow( TEAM_MILITIA, null )
	npc.Minimap_SetHeightTracking( true )
	npc.Minimap_SetAlignUpright( true )
	npc.Minimap_SetZOrder( MINIMAP_Z_NPC )
	npc.Minimap_SetCustomState( eMinimapObject_npc_titan.AT_BOUNTY_BOSS )
	
	npc.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )
	NukeTitanThink( npc, file.militiaHarvester.harvester )
	
	npc.GetTitanSoul().SetTitanSoulNetBool( "showOverheadIcon", true )
	thread PayloadNukeTitanShieldTracker( npc )
	thread PayloadNukeTitanProximityChecker( npc )
	thread Payload_WaitForNukeTitanDeath( npc )
}

void function AddTurretSentry( entity turret )
{
	entity player = turret.GetBossPlayer()
	if ( player != null )
	{
		turret.SetMaxHealth( DEPLOYABLE_TURRET_HEALTH )
		turret.SetHealth( DEPLOYABLE_TURRET_HEALTH )
		turret.kv.AccuracyMultiplier = DEPLOYABLE_TURRET_ACCURACY_MULTIPLIER
		if ( turret.GetMainWeapons()[0].GetWeaponClassName() == "mp_weapon_yh803_bullet" )
			turret.GetMainWeapons()[0].AddMod( "fd" )
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
	if ( titan != file.theNukeTitan )
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
	
	int timeLimit = GameMode_GetTimeLimit( GAMETYPE ) * 60
	
	SetServerVar( "gameEndTime", Time() + ( 60 * 5 ) )
	SetServerVar( "roundEndTime", Time() + ( 60 * 5 ) )
	
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
		SetSuddenDeathBased( true )
		SetServerVar( "gameEndTime", Time() )
		SetServerVar( "roundEndTime", Time() )
	}
}

void function PayloadNukeTitanProximityChecker( entity titan )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "FD_ReachedHarvester" )
	
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
			titan.SetNPCMoveSpeedScale( PLD_BASE_NUKE_TITAN_MOVESPEED_SCALE * 3 )
		
		TrackCheckpointProgress( file.capturedCheckpoints )
		wait 0.5
	}
}

void function MovePayloadNukeTitan( entity titan, int routeindex )
{
	titan.EndSignal( "PayloadNukeTitanStopped" )
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	
	vector routepoint = file.payloadRoute[routeindex]
	
	while ( true )
	{
		titan.AssaultPointClamped( routepoint )
			
		table result = titan.WaitSignal( "OnFinishedAssault", "OnEnterGoalRadius" )
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

void function OnHarvesterDamaged( entity harvester, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	int damageSourceID = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	float damageAmount = DamageInfo_GetDamage( damageInfo )
	
	if( !GamePlaying() )
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
	
    DamageInfo_SetDamage( damageInfo, damageAmount )
}

void function OnNukeTitanDamaged( entity npc, var damageInfo )
{
	entity soul = npc.GetTitanSoul()
	if ( soul.GetShieldHealth() == 0 )
		DamageInfo_ScaleDamage( damageInfo, 0.0 ) // Basically invulnerability
}










/*

███╗   ███╗██╗███████╗ ██████╗███████╗██╗     ██╗      █████╗ ███╗   ██╗███████╗ ██████╗ ██╗   ██╗███████╗
████╗ ████║██║██╔════╝██╔════╝██╔════╝██║     ██║     ██╔══██╗████╗  ██║██╔════╝██╔═══██╗██║   ██║██╔════╝
██╔████╔██║██║███████╗██║     █████╗  ██║     ██║     ███████║██╔██╗ ██║█████╗  ██║   ██║██║   ██║███████╗
██║╚██╔╝██║██║╚════██║██║     ██╔══╝  ██║     ██║     ██╔══██║██║╚██╗██║██╔══╝  ██║   ██║██║   ██║╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗███████╗███████╗███████╗██║  ██║██║ ╚████║███████╗╚██████╔╝╚██████╔╝███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝

*/

int function PLD_TimeoutWinner()
{
	if (  !IsAlive( file.theNukeTitan ) && IsValid( file.militiaHarvester.harvester ) && file.militiaHarvester.harvester.GetHealth() > 0 )
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

    return ( PlayerHasBattery( player ) && player.GetTeam() == harvester.GetTeam() && harvester.GetShieldHealth() < harvester.GetShieldHealthMax() )
}

function PayloadUseBatteryFunc( batteryPortvar, playervar )
{
	entity batteryPort = expect entity( batteryPortvar )
	entity player = expect entity( playervar )
    entity harvester = expect entity( batteryPort.s.bindedHarvester )
	
	if ( !IsValid( player ) || harvester.GetShieldHealth() == harvester.GetShieldHealthMax() )
		return
	
	AddPlayerScore( player, "FDShieldHarvester" )
	player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, PAYLOAD_SCORE_OBJECTIVE_SHIELD_HARVESTER )
	
	int shieldToBoost = harvester.GetShieldHealth()
	shieldToBoost += harvester.GetShieldHealthMax() / 4
	
    harvester.SetShieldHealth( min( shieldToBoost, harvester.GetShieldHealthMax() ) )
	
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
		wait 3
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
		PlayLoopFXOnEntity( $"P_ar_holopilot_trail", mover )
		PlayLoopFXOnEntity( FLAG_FX_FRIENDLY, mover )
		
		mover.NonPhysicsMoveTo( routepoint, 1.0, 0.0, 0.0 )
		wait 1
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
	if( pilot.GetTeam() != titan.GetTeam() && !PlayerHasBattery( pilot ) )
	{
		Highlight_SetEnemyHighlight( pilot, "sp_objective_entity" )
		pilot.Highlight_SetParam( 2, 0, HIGHLIGHT_COLOR_ENEMY )
	
		foreach ( player in GetPlayerArray() )
			Remote_CallFunction_NonReplay( player, "ServerCallback_PLD_ShowTutorialHint", ePLDTutorials.NukeTitanRodeo )
		
		pilot.SetInvulnerable()
	}
}

void function PLD_PilotEndRodeo( entity pilot, entity titan )
{
	if ( pilot.IsInvulnerable() )
	{
		if( pilot.GetTeam() != titan.GetTeam() )
			Highlight_ClearEnemyHighlight( pilot )
		
		pilot.ClearInvulnerable()
	}
}