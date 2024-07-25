global function ClGamemodePLD_Init
global function CLPayload_RegisterNetworkFunctions
global function ServerCallback_PLD_PlayBattleMusic
global function ServerCallback_PLD_ShowTutorialHint

struct {
	var checkpointARui
	var checkpointBRui
	var checkpointCRui
	
	var checkpointAHudRui
	var checkpointBHudRui
	var checkpointCHudRui
	
	var harvesterRui
	var tutorialTip
} file

table< int, bool > tutorialShown










/*

 ██████╗██╗     ██╗███████╗███╗   ██╗████████╗    ██╗███╗   ██╗██╗████████╗
██╔════╝██║     ██║██╔════╝████╗  ██║╚══██╔══╝    ██║████╗  ██║██║╚══██╔══╝
██║     ██║     ██║█████╗  ██╔██╗ ██║   ██║       ██║██╔██╗ ██║██║   ██║   
██║     ██║     ██║██╔══╝  ██║╚██╗██║   ██║       ██║██║╚██╗██║██║   ██║   
╚██████╗███████╗██║███████╗██║ ╚████║   ██║       ██║██║ ╚████║██║   ██║   
 ╚═════╝╚══════╝╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝       ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝   

*/

void function ClGamemodePLD_Init()
{
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_INTRO, "music_mp_coliseum_intro", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_INTRO, "music_mp_lts_intro_countdown", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_WIN, "music_mp_freeagents_outro_win", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_WIN, "music_mp_speedball_game_win", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_DRAW, "music_mp_lts_outro_lose", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_DRAW, "music_mp_coliseum_round_lose", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LOSS, "music_mp_lts_outro_lose", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LOSS, "music_mp_coliseum_round_lose", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.GAMEMODE_1, "music_s2s_04_maltabattle_alt", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.GAMEMODE_1, "music_s2s_04_maltabattle_alt", TEAM_MILITIA )
	
	ClGameState_RegisterGameStateAsset( $"ui/gamestate_info_cp.rpak" )
	CallsignEvents_SetEnabled( true )
	
	AddCreateCallback( "info_hardpoint", OnCheckpointCreated )
	AddCreateCallback( "prop_script", OnPropScriptCreated )
	AddCreateCallback( "npc_titan", OnNukeTitanSpawn )
	
	file.checkpointARui = CreateCockpitRui( $"ui/cp_hardpoint_marker.rpak", 100 )
	file.checkpointBRui = CreateCockpitRui( $"ui/cp_hardpoint_marker.rpak", 100 )
	file.checkpointCRui = CreateCockpitRui( $"ui/cp_hardpoint_marker.rpak", 100 )
	
	file.checkpointAHudRui = CreateCockpitRui( $"ui/cp_hardpoint_hud.rpak", 100 )
	file.checkpointBHudRui = CreateCockpitRui( $"ui/cp_hardpoint_hud.rpak", 100 )
	file.checkpointCHudRui = CreateCockpitRui( $"ui/cp_hardpoint_hud.rpak", 100 )
	
	file.tutorialTip = CreatePermanentCockpitRui( $"ui/fd_tutorial_tip.rpak", MINIMAP_Z_BASE )
	
	AddCallback_OnClientScriptInit( ClGamemodePLD_OnClientScriptInit )
	AddCallback_GameStateEnter( eGameState.WinnerDetermined, ClGamemodePLD_OnWinnerDetermined )
	AddCallback_GameStateEnter( eGameState.Postmatch, DisplayPostMatchTop3 )
	
	AddEventNotificationCallback( eEventNotifications.TEMP_TitanGreenRoom, PLD_AnnounceNukeTitanSpawn )
	AddEventNotificationCallback( eEventNotifications.TEMP_RodeoExpress_Success, PLD_AnnounceCheckpointReached )
}

void function ClGamemodePLD_OnClientScriptInit( entity player )
{
	RegisterMinimapPackage( "npc_titan", eMinimapObject_npc_titan.AT_BOUNTY_BOSS, $"ui/minimap_object.rpak", PLD_MinimapNukeTitanInit )
	
	var rui = ClGameState_GetRui()
	if ( player.GetTeam() == TEAM_IMC )
	{
		RuiTrackInt( rui, "friendlyChevronState", null, RUI_TRACK_SCRIPT_NETWORK_VAR_GLOBAL_INT, GetNetworkedVariableIndex( "imcChevronState" ) )
		RuiTrackInt( rui, "enemyChevronState", null, RUI_TRACK_SCRIPT_NETWORK_VAR_GLOBAL_INT, GetNetworkedVariableIndex( "milChevronState" ) )
	}
	else
	{
		RuiTrackInt( rui, "friendlyChevronState", null, RUI_TRACK_SCRIPT_NETWORK_VAR_GLOBAL_INT, GetNetworkedVariableIndex( "milChevronState" ) )
		RuiTrackInt( rui, "enemyChevronState", null, RUI_TRACK_SCRIPT_NETWORK_VAR_GLOBAL_INT, GetNetworkedVariableIndex( "imcChevronState" ) )
	}
}

void function PLD_MinimapNukeTitanInit( entity ent, var rui )
{
	if ( ent.GetTargetName() == "payloadNukeTitan" )
	{
		RuiSetImage( rui, "defaultIcon", $"rui/hud/gametype_icons/fd/fd_icon_titan_nuke" )
		RuiSetImage( rui, "clampedDefaultIcon", $"rui/hud/gametype_icons/fd/fd_icon_titan_nuke" )
		RuiSetBool( rui, "useTeamColor", false )
		RuiSetBool( rui, "overrideTitanIcon", true )
	}
	
	RuiSetFloat( rui, "sonarDetectedFrac", 1.0 )
	RuiSetGameTime( rui, "lastFireTime", Time() + ( GetCurrentPlaylistVarFloat( "timelimit", 10 ) * 60.0 ) + 999.0 )
	RuiSetBool( rui, "showOnMinimapOnFire", true )
}

void function CLPayload_RegisterNetworkFunctions()
{
	RegisterNetworkedVariableChangeCallback_ent( "checkpoint0Ent", PLD_CheckpointEntChanged )
	RegisterNetworkedVariableChangeCallback_ent( "checkpoint1Ent", PLD_CheckpointEntChanged )
	RegisterNetworkedVariableChangeCallback_ent( "checkpoint2Ent", PLD_CheckpointEntChanged )
}

void function ClGamemodePLD_OnWinnerDetermined()
{
	RuiSetBool( file.checkpointARui, "isVisible", false )
	RuiSetBool( file.checkpointBRui, "isVisible", false )
	RuiSetBool( file.checkpointCRui, "isVisible", false )
	
	RuiSetBool( file.checkpointAHudRui, "isVisible", false )
	RuiSetBool( file.checkpointBHudRui, "isVisible", false )
	RuiSetBool( file.checkpointCHudRui, "isVisible", false )
}











/*

 ██████╗██████╗ ███████╗ █████╗ ████████╗██╗ ██████╗ ███╗   ██╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
██╔════╝██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██║     ██████╔╝█████╗  ███████║   ██║   ██║██║   ██║██╔██╗ ██║    █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║     ██╔══██╗██╔══╝  ██╔══██║   ██║   ██║██║   ██║██║╚██╗██║    ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
╚██████╗██║  ██║███████╗██║  ██║   ██║   ██║╚██████╔╝██║ ╚████║    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
 ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

*/

void function OnPropScriptCreated( entity prop )
{
	if ( prop.GetTeam() == TEAM_MILITIA && prop.GetTargetName() == "militiaHarvester" )
	{
		file.harvesterRui = CreateCockpitRui( $"ui/overhead_icon_generic.rpak", MINIMAP_Z_BASE + 200 )
		RuiSetImage( file.harvesterRui, "icon", $"rui/hud/gametype_icons/fd/coop_harvester" )
		RuiSetBool( file.harvesterRui, "isVisible", true )
		RuiSetBool( file.harvesterRui, "showClampArrow", true )
		RuiSetFloat2( file.harvesterRui, "iconSize", <96,96,0> )
		RuiTrackFloat3( file.harvesterRui, "pos", prop, RUI_TRACK_ABSORIGIN_FOLLOW )
	}
	
	if ( GetLocalViewPlayer().GetTeam() == TEAM_MILITIA && prop.GetTeam() == TEAM_MILITIA && prop.GetTargetName() == "harvesterBoostPort" )
		thread AddOverheadIcon( prop, $"rui/hud/battery/battery_generator", false )
}

void function PLD_CheckpointEntChanged( entity player, entity oldEnt, entity newEnt, bool actuallyChanged )
{
	if ( newEnt == null )
		return

	string progressVar
	string stateVar
	string cappingTeamVar
	int indexID = 0
	var rui

	if ( GetGameState() > eGameState.Playing )
		return
	
	switch ( newEnt.GetHardpointID() )
	{
		case 0:
		progressVar = "objective0Progress"
		stateVar = "objective0State"
		cappingTeamVar = "objective0CappingTeam"
		indexID = 0
		rui = file.checkpointAHudRui
		break
		
		case 1:
		progressVar = "objective1Progress"
		stateVar = "objective1State"
		cappingTeamVar = "objective1CappingTeam"
		indexID = 1
		rui = file.checkpointBHudRui
		break
		
		case 2:
		progressVar = "objective2Progress"
		stateVar = "objective2State"
		cappingTeamVar = "objective2CappingTeam"
		indexID = 2
		rui = file.checkpointCHudRui
		break
		
		default:
		return
	}

	RuiSetInt( rui, "hardpointId", indexID )
	RuiSetInt( rui, "viewerTeam", GetLocalClientPlayer().GetTeam() )
	RuiTrackInt( rui, "cappingTeam", null, RUI_TRACK_SCRIPT_NETWORK_VAR_GLOBAL_INT, GetNetworkedVariableIndex( cappingTeamVar ) )
	RuiTrackInt( rui, "hardpointTeamRelation", newEnt, RUI_TRACK_TEAM_RELATION_VIEWPLAYER )

	RuiTrackInt( rui, "hardpointState", null, RUI_TRACK_SCRIPT_NETWORK_VAR_GLOBAL_INT, GetNetworkedVariableIndex( stateVar ) )
	RuiTrackFloat( rui, "progressFrac", null, RUI_TRACK_SCRIPT_NETWORK_VAR_GLOBAL, GetNetworkedVariableIndex( progressVar ) )

	RuiSetBool(  rui, "isVisible", true )
}

void function OnCheckpointCreated( entity hardpoint )
{
	thread OnCheckpointCreated_Thread( hardpoint )
}

void function OnCheckpointCreated_Thread( entity hardpoint )
{
	hardpoint.EndSignal( "OnDestroy" )

	entity player = GetLocalViewPlayer()

	string progressVar
	string stateVar
	string cappingTeamVar
	int indexID = 0
	var rui
	
	if ( GetGameState() > eGameState.Playing )
		return

	switch ( hardpoint.GetHardpointID() )
	{
		case 0:
		progressVar = "objective0Progress"
		stateVar = "objective0State"
		cappingTeamVar = "objective0CappingTeam"
		indexID = 0
		rui = file.checkpointARui
		break
		
		case 1:
		progressVar = "objective1Progress"
		stateVar = "objective1State"
		cappingTeamVar = "objective1CappingTeam"
		indexID = 1
		rui = file.checkpointBRui
		break
		
		case 2:
		progressVar = "objective2Progress"
		stateVar = "objective2State"
		cappingTeamVar = "objective2CappingTeam"
		indexID = 2
		rui = file.checkpointCRui
		break
		
		default:
		return
	}

	RuiSetFloat3( rui, "pos", hardpoint.GetOrigin() + < 0, 0, 64 > )
	RuiSetInt( rui, "hardpointId", indexID )
	RuiTrackInt( rui, "viewerHardpointId", player, RUI_TRACK_SCRIPT_NETWORK_VAR_INT, GetNetworkedVariableIndex( "playerHardpointID" ) )
	RuiSetInt( rui, "viewerTeam", player.GetTeam() )
	RuiTrackInt( rui, "cappingTeam", null, RUI_TRACK_SCRIPT_NETWORK_VAR_GLOBAL_INT, GetNetworkedVariableIndex( cappingTeamVar ) )

	RuiTrackInt( rui, "hardpointTeamRelation", hardpoint, RUI_TRACK_TEAM_RELATION_VIEWPLAYER )

	RuiTrackInt( rui, "hardpointState", null, RUI_TRACK_SCRIPT_NETWORK_VAR_GLOBAL_INT, GetNetworkedVariableIndex( stateVar ) )
	RuiTrackFloat( rui, "progressFrac", null, RUI_TRACK_SCRIPT_NETWORK_VAR_GLOBAL, GetNetworkedVariableIndex( progressVar ) )


	RuiSetBool(  rui, "isVisible", true )

	while ( GetGameState() <= eGameState.Playing )
	{
		if ( IsValid( player ) )
			RuiSetBool( rui, "isTitan", player.IsTitan() )
		WaitFrame()
	}
}

void function OnNukeTitanSpawn( entity titan )
{
	if ( titan.GetTeam() == TEAM_IMC && titan.GetTargetName() == "payloadNukeTitan" )
		thread AddOverheadIcon( titan, $"rui/hud/gametype_icons/fd/fd_icon_titan_nuke" )
}










/*

██╗ ██████╗ ██████╗ ███╗   ██╗███████╗    ██╗      ██████╗  ██████╗ ██╗ ██████╗
██║██╔════╝██╔═══██╗████╗  ██║██╔════╝    ██║     ██╔═══██╗██╔════╝ ██║██╔════╝
██║██║     ██║   ██║██╔██╗ ██║███████╗    ██║     ██║   ██║██║  ███╗██║██║     
██║██║     ██║   ██║██║╚██╗██║╚════██║    ██║     ██║   ██║██║   ██║██║██║     
██║╚██████╗╚██████╔╝██║ ╚████║███████║    ███████╗╚██████╔╝╚██████╔╝██║╚██████╗
╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝    ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝ ╚═════╝

*/

var function AddOverheadIcon( entity prop, asset icon, bool pinToEdge = true, asset ruiFile = $"ui/overhead_icon_generic.rpak" )
{
	var rui = CreateCockpitRui( ruiFile, MINIMAP_Z_BASE - 20 )
	RuiSetImage( rui, "icon", icon )
	RuiSetBool( rui, "isVisible", true )
	RuiSetBool( rui, "pinToEdge", pinToEdge )
	RuiTrackFloat3( rui, "pos", prop, RUI_TRACK_OVERHEAD_FOLLOW )

	thread AddOverheadIconThread( prop, rui )
	return rui
}

void function AddOverheadIconThread( entity prop, var rui )
{
	prop.EndSignal( "OnDestroy" )
	if ( prop.IsTitan() )
		prop.EndSignal( "OnDeath" )

	OnThreadEnd(
	function() : ( rui )
		{
			RuiDestroy( rui )
		}
	)

	if ( prop.IsTitan() )
	{
		while ( 1 )
		{
			bool showIcon = !IsCloaked( prop )

			if ( IsValid( prop.GetTitanSoul() ) )
				showIcon = showIcon && prop.GetTitanSoul().GetTitanSoulNetBool( "showOverheadIcon" )

			RuiSetBool( rui, "isVisible", showIcon )
			wait 0.5
		}
	}

	WaitForever()
}










/*

 █████╗ ███╗   ██╗███╗   ██╗ ██████╗ ██╗   ██╗███╗   ██╗ ██████╗███████╗███╗   ███╗███████╗███╗   ██╗████████╗███████╗
██╔══██╗████╗  ██║████╗  ██║██╔═══██╗██║   ██║████╗  ██║██╔════╝██╔════╝████╗ ████║██╔════╝████╗  ██║╚══██╔══╝██╔════╝
███████║██╔██╗ ██║██╔██╗ ██║██║   ██║██║   ██║██╔██╗ ██║██║     █████╗  ██╔████╔██║█████╗  ██╔██╗ ██║   ██║   ███████╗
██╔══██║██║╚██╗██║██║╚██╗██║██║   ██║██║   ██║██║╚██╗██║██║     ██╔══╝  ██║╚██╔╝██║██╔══╝  ██║╚██╗██║   ██║   ╚════██║
██║  ██║██║ ╚████║██║ ╚████║╚██████╔╝╚██████╔╝██║ ╚████║╚██████╗███████╗██║ ╚═╝ ██║███████╗██║ ╚████║   ██║   ███████║
╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝

*/

void function PLD_AnnounceNukeTitanSpawn( entity ent, var info )
{
	AnnouncementData announcement = Announcement_Create( "#PLD_NUKE_TITAN_INCOMING" )
	Announcement_SetSoundAlias( announcement,  "UI_InGame_FD_WaveIncoming" )
	Announcement_SetStyle( announcement, ANNOUNCEMENT_STYLE_RESULTS )
	Announcement_SetTitleColor( announcement, TEAM_COLOR_ENEMY )
	Announcement_SetPurge( announcement, true )
	Announcement_SetPriority( announcement, 200 )
	AnnouncementFromClass( GetLocalViewPlayer(), announcement )
}

void function PLD_AnnounceCheckpointReached( entity ent, var info )
{
	AnnouncementData announcement = Announcement_Create( "#PLD_CHECKPOINT_REACHED" )
	announcement.duration = 4.0
	Announcement_SetSoundAlias( announcement,  "UI_InGame_FD_WaveIncoming" )
	Announcement_SetStyle( announcement, ANNOUNCEMENT_STYLE_SWEEP )
	Announcement_SetTitleColor( announcement, TEAM_COLOR_ENEMY )
	Announcement_SetPurge( announcement, true )
	Announcement_SetPriority( announcement, 200 )
	AnnouncementFromClass( GetLocalViewPlayer(), announcement )
}










/*

███╗   ███╗██╗   ██╗███████╗██╗ ██████╗
████╗ ████║██║   ██║██╔════╝██║██╔════╝
██╔████╔██║██║   ██║███████╗██║██║     
██║╚██╔╝██║██║   ██║╚════██║██║██║     
██║ ╚═╝ ██║╚██████╔╝███████║██║╚██████╗
╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝ ╚═════╝

*/

void function ServerCallback_PLD_PlayBattleMusic()
{
	StopMusic()
	thread ForceLoopMusic_DEPRECATED( eMusicPieceID.GAMEMODE_1 )
}









/*

████████╗██╗   ██╗████████╗ ██████╗ ██████╗ ██╗ █████╗ ██╗     ███████╗
╚══██╔══╝██║   ██║╚══██╔══╝██╔═══██╗██╔══██╗██║██╔══██╗██║     ██╔════╝
   ██║   ██║   ██║   ██║   ██║   ██║██████╔╝██║███████║██║     ███████╗
   ██║   ██║   ██║   ██║   ██║   ██║██╔══██╗██║██╔══██║██║     ╚════██║
   ██║   ╚██████╔╝   ██║   ╚██████╔╝██║  ██║██║██║  ██║███████╗███████║
   ╚═╝    ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚══════╝╚══════╝

*/


void function ServerCallback_PLD_ShowTutorialHint( int tutorialID )
{
	entity player = GetLocalClientPlayer()
	
	if ( tutorialID in tutorialShown )
	{
		if ( tutorialShown[tutorialID] )
			return
	}
	
	asset backgroundImage = $""
	asset tipIcon = $""
	string tipTitle = ""
	string tipDesc = ""

	switch ( tutorialID )
	{
		case ePLDTutorials.Teams:
			if ( player.GetTeam() == TEAM_MILITIA )
			{
				backgroundImage = $"rui/menu/boosts/boost_harvester"
				tipTitle = "#PLD_TUTORIAL_DEFENDING_TITLE"
				tipDesc = "#PLD_TUTORIAL_DEFENDING_DESC"
			}
			else
			{
				backgroundImage = $"rui/menu/boosts/boost_nuke"
				tipTitle = "#PLD_TUTORIAL_PUSHING_TITLE"
				tipDesc = "#PLD_TUTORIAL_PUSHING_DESC"
			}
			break
		
		case ePLDTutorials.NukeTitanRodeo:
			if ( player.GetTeam() == TEAM_MILITIA )
			{
				backgroundImage = $"rui/hud/gametype_icons/fd/onboard_core_overload"
				tipTitle = "#PLD_TUTORIAL_RODEO_DEFENDING_TITLE"
				tipDesc = "#PLD_TUTORIAL_RODEO_DEFENDING_DESC"
			}
			else
			{
				backgroundImage = $"rui/hud/gametype_icons/fd/onboard_core_overload"
				tipTitle = "#PLD_TUTORIAL_RODEO_PUSHING_TITLE"
				tipDesc = "#PLD_TUTORIAL_RODEO_PUSHING_DESC"
			}
			break
		
		case ePLDTutorials.NukeTitanBattery:
			if ( player.GetTeam() == TEAM_MILITIA )
			{
				backgroundImage = $"rui/hud/gametype_icons/fd/onboard_titan_nuke"
				tipTitle = "#PLD_TUTORIAL_TITAN_SHIELD_DEFENDING_TITLE"
				tipDesc = "#PLD_TUTORIAL_TITAN_SHIELD_DEFENDING_DESC"
			}
			else
			{
				backgroundImage = $"rui/hud/gametype_icons/fd/onboard_titan_nuke"
				tipTitle = "#PLD_TUTORIAL_TITAN_SHIELD_PUSHING_TITLE"
				tipDesc = "#PLD_TUTORIAL_TITAN_SHIELD_PUSHING_DESC"
			}
			break
		
		case ePLDTutorials.HarvesterBattery:
			if ( player.GetTeam() == TEAM_MILITIA )
			{
				backgroundImage = $"rui/hud/gametype_icons/fd/onboard_harvester"
				tipTitle = "#PLD_TUTORIAL_HARVESTER_SHIELD_DEFENDING_TITLE"
				tipDesc = "#PLD_TUTORIAL_HARVESTER_SHIELD_DEFENDING_DESC"
			}
			else
			{
				backgroundImage = $"rui/hud/gametype_icons/fd/onboard_harvester"
				tipTitle = "#PLD_TUTORIAL_HARVESTER_SHIELD_PUSHING_TITLE"
				tipDesc = "#PLD_TUTORIAL_HARVESTER_SHIELD_PUSHING_DESC"
			}
			break

		default:
			return
	}
	
	if ( !( tutorialID in tutorialShown ) )
		tutorialShown[tutorialID] <- true

	PLDDisplayTutorialTip( backgroundImage, tipIcon, tipTitle, tipDesc )
}

void function PLDDisplayTutorialTip( asset backgroundImage, asset tipIcon, string tipTitle, string tipDesc )
{
	RuiSetImage( file.tutorialTip, "backgroundImage", backgroundImage )
	RuiSetImage( file.tutorialTip, "iconImage", tipIcon )
	RuiSetString( file.tutorialTip, "titleText", tipTitle )
	RuiSetString( file.tutorialTip, "descriptionText", tipDesc )
	RuiSetGameTime( file.tutorialTip, "updateTime", Time() )
	RuiSetFloat( file.tutorialTip, "duration", 10.0 )
	thread PLDTutorialTipSounds()
}

void function PLDTutorialTipSounds()
{
	entity player = GetLocalClientPlayer()
	player.EndSignal( "OnDestroy" )

	EmitSoundOnEntity( player, "UI_InGame_FD_InfoCardSlideIn"  )
	wait 6.0
	EmitSoundOnEntity( player, "UI_InGame_FD_InfoCardSlideOut" )
}