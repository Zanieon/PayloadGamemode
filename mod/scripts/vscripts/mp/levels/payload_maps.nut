untyped

global function Payload_InitMaps

void function Payload_InitMaps()
{
	if( IsLobby() || GameRules_GetGameMode() != GAMEMODE_PLD ) // Don't wanna this to trigger on menus nor outside payload mode itself
		return
	
	array< entity > entitiesToDestroy = GetEntArrayByClass_Expensive( "info_spawnpoint_dropship_start" )
	entitiesToDestroy.extend( GetEntArrayByClass_Expensive( "info_hardpoint" ) )
	foreach ( entity ent in entitiesToDestroy )
		ent.Destroy()
	
	switch ( GetMapName() )
	{
		case "mp_drydock":
			Payload_SetMilitiaHarvesterLocation( < 174, 3410, 120 >, < 0, 0, 0 >, < -115, 3397, 232 >, < 0, 0, 0 > )
			Payload_SetNukeTitanSpawnLocation( < 2745, -3784, -32 >, < 0, 90, 0 > )
			AddCallback_PayloadMode( ExecDrydockPayload )
			break
		
		case "mp_angel_city":
			Payload_SetMilitiaHarvesterLocation( < -2639, 4625, 119 >, < 0, 0, 0 >, < -2209, 4522, 164 >, < 0, 0, 0 > )
			Payload_SetNukeTitanSpawnLocation( < 2145, -3745, 192 >, < 0, 90, 0 > )
			AddCallback_PayloadMode( ExecAngelCityPayload )
			break
		
		case "mp_black_water_canal":
			Payload_SetMilitiaHarvesterLocation( < -298, 4358, -259 >, < 0, 0, 0 >, < 73, 4097, -257 >, < 0, 90, 0 > )
			Payload_SetNukeTitanSpawnLocation( < 982, -4939, -199 >, < 0, 45, 0 > )
			AddCallback_PayloadMode( ExecBWCPayload )
			break
			
		case "mp_eden":
			Payload_SetMilitiaHarvesterLocation( < 3352, 2733, 67 >, < 0, 0, 0 >, < 3142, 3159, 120 >, < 0, -90, 0 > )
			Payload_SetNukeTitanSpawnLocation( < -2688, 3415, 173 >, < 0, -90, 0 > )
			AddCallback_PayloadMode( ExecEdenPayload )
			break
		
		case "mp_forwardbase_kodai":
			Payload_SetMilitiaHarvesterLocation( < 2470, 3989, 924 >, < 0, 0, 0 >, < 2535, 3634, 989 >, < 0, 90, 0 > )
			Payload_SetNukeTitanSpawnLocation( < -1531, -2932, 791 >, < 0, 90, 0 > )
			AddCallback_PayloadMode( ExecKodaiPayload )
			break
		
		case "mp_thaw":
			Payload_SetMilitiaHarvesterLocation( < 2281, 1928, -336 >, < 0, 0, 0 >, < 2854, 2164, -288 >, < 0, 90, 0 > )
			Payload_SetNukeTitanSpawnLocation( < 2409, -4303, -318 >, < 0, 135, 0 > )
			AddCallback_PayloadMode( ExecExoplanetPayload )
			break
			
		default:
			throw( "The map selected has no support for Payload gamemode" )
	}
}

void function ExecDrydockPayload()
{
	AddPayloadCustomMapProp( $"models/imc_base/cargo_container_imc_01_white.mdl", < -417, 2237, 232 >, < 0, 0, 0 > )
	AddPayloadCustomMapProp( $"models/imc_base/cargo_container_imc_01_orange.mdl", < -290, 2237, 232 >, < 0, 0, 0 > )
	AddPayloadCustomMapProp( $"models/imc_base/cargo_container_imc_01_white.mdl", < -181, 2268, 232 >, < 0, 90, 0 > )
	AddPayloadCustomMapProp( $"models/imc_base/cargo_container_imc_01_orange.mdl", < -417, 2237, 330 >, < 0, 0, 0 > )
	AddPayloadCustomMapProp( $"models/imc_base/cargo_container_imc_01_orange.mdl", < -290, 2237, 330 >, < 0, 0, 0 > )
	AddPayloadCustomMapProp( $"models/imc_base/cargo_container_imc_01_white.mdl", < -181, 2268, 330 >, < 0, 90, 0 > )
	AddPayloadCustomMapProp( $"models/imc_base/cargo_container_imc_01_orange.mdl", < -417, 2237, 427 >, < 0, 0, 0 > )
	AddPayloadCustomMapProp( $"models/imc_base/cargo_container_imc_01_orange.mdl", < -290, 2237, 427 >, < 0, 0, 0 > )
	AddPayloadCustomMapProp( $"models/imc_base/cargo_container_imc_01_white.mdl", < -181, 2268, 427 >, < 0, 90, 0 > )
	
	AddPayloadCustomMapProp( $"models/ola/sewer_drain_wall.mdl", < 922, -3100, 128 >, < 0, -90, 0 > )
	AddPayloadCustomMapProp( $"models/ola/sewer_drain_wall.mdl", < 922, -3050, 128 >, < 0, 90, 0 > )
	
	AddPayloadCustomMapProp( $"models/ola/sewer_drain_wall.mdl", < 2306, -2941, -72 >, < 0, -90, 0 > )
	AddPayloadCustomMapProp( $"models/ola/sewer_drain_wall.mdl", < 2306, -2890, -72 >, < 0, 90, 0 > )
	
	AddPayloadCustomMapProp( $"models/ola/sewer_drain_wall.mdl", < 1167, -970, 256 >, < 0, 180, 0 > )
	AddPayloadCustomMapProp( $"models/ola/sewer_drain_wall.mdl", < 1219, -970, 256 >, < 0, 0, 0 > )
	
	AddPayloadCustomShipStart( < 953, 3909, 1200 >, < 0, -90, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < -949, 3217, 1200 >, < 0, 0, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < -378, -4423, 768 >, < 0, 90, 0 >, TEAM_IMC )
	AddPayloadCustomShipStart( < 362, -4423, 768 >, < 0, 90, 0 >, TEAM_IMC )
	
	AddPayloadRouteNode( < 67, -3201, 162 > )
	AddPayloadRouteNode( < -468, -1213, 256 > )
	AddPayloadRouteNode( < 443, -1049, 256 > )
	AddPayloadRouteNode( < 74, 1349, 256 > )
	AddPayloadRouteNode( < 1279, 1571, 256 > )
	AddPayloadRouteNode( < 1321, 2829, 83 > )
	AddPayloadRouteNode( < 557, 3378, 81 > )
	
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < -33, -4483, 144 >, 1200 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < 741, 4620, 201 >, 2000 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < -2271, 3758, 181 >, 2400 )
	
	array< entity > drydockspawns0
	drydockspawns0.append( CreatePayloadSpawnZone( < -926, -2142, 408 >, 640 ) )
	drydockspawns0.append( CreatePayloadSpawnZone( < 1155, -1899, 240 >, 800 ) )
	AddPayloadCheckpointWithZones( 0, < -520, -2337, 241 >, drydockspawns0 )
	
	array< entity > drydockspawns1
	drydockspawns1.append( CreatePayloadSpawnZone( < 975, -336, 416 >, 512 ) )
	drydockspawns1.append( CreatePayloadSpawnZone( < -165, -720, 410 >, 400 ) )
	drydockspawns1.append( CreatePayloadSpawnZone( < -1042, -716, 408 >, 400 ) )
	AddPayloadCheckpointWithZones( 1, < 348, -302, 255 >, drydockspawns1 )
	
	array< entity > drydockspawns2
	drydockspawns2.append( CreatePayloadSpawnZone( < -1135, 849, 408 >, 400 ) )
	drydockspawns2.append( CreatePayloadSpawnZone( < 721, 1053, 408 >, 400 ) )
	drydockspawns2.append( CreatePayloadSpawnZone( < 1960, 2104, 255 >, 640 ) )
	AddPayloadCheckpointWithZones( 2, < 813, 1551, 256 >, drydockspawns2 )
}

void function ExecAngelCityPayload()
{
	AddPayloadCustomShipStart( < -3440, 3694, 1200 >, < 0, -15, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < -3993, 4948, 1200 >, < 0, 0, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < 2676, -2637, 1200 >, < 0, 90, 0 >, TEAM_IMC )
	AddPayloadCustomShipStart( < 1730, -2978, 1200 >, < 0, 90, 0 >, TEAM_IMC )
	
	AddPayloadRouteNode( < 2130, -219, 120 > )
	AddPayloadRouteNode( < -756, 595, 121 > )
	AddPayloadRouteNode( < -902, 2612, 119 > )
	AddPayloadRouteNode( < -2338, 3323, 120 > )
	AddPayloadRouteNode( < -2642, 4377, 121 > )
	
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < 3260, -2997, 199 >, 1024 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < 1596, -2886, 208 >, 440 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < -3383, 3683, 136 >, 512 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < -3342, 2555, 128 >, 900 )
	
	array< entity > angelCityspawns0
	angelCityspawns0.append( CreatePayloadSpawnZone( < 1579, -872, 128 >, 625 ) )
	angelCityspawns0.append( CreatePayloadSpawnZone( < 1659, 1044, 258 >, 800 ) )
	AddPayloadCheckpointWithZones( 0, < 2061, -221, 120 >, angelCityspawns0 )
	
	array< entity > angelCityspawns1
	angelCityspawns1.append( CreatePayloadSpawnZone( < -1543, 1072, 148 >, 800 ) )
	AddPayloadCheckpointWithZones( 1, < -777, 612, 120 >, angelCityspawns1 )
	
	array< entity > angelCityspawns2
	angelCityspawns2.append( CreatePayloadSpawnZone( < -480, 3765, 131 >, 900 ) )
	AddPayloadCheckpointWithZones( 2, < -1659, 2909, 120 >, angelCityspawns2 )
}

void function ExecBWCPayload()
{
	AddPayloadCustomShipStart( < -1019, 4145, 800 >, < 0, 180, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < 998, 3814, 799 >, < 0, 45, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < 3388, -3364, 1100 >, < 0, 0, 0 >, TEAM_IMC )
	AddPayloadCustomShipStart( < 998, -3717, 1100 >, < 0, -135, 0 >, TEAM_IMC )
	
	AddPayloadRouteNode( < 2281, -3444, -199 > )
	AddPayloadRouteNode( < 2520, -2078, -129 > )
	AddPayloadRouteNode( < 1322, -1585, -45 > )
	AddPayloadRouteNode( < 287, -615, -7 > )
	AddPayloadRouteNode( < 396, 669, -0 > )
	AddPayloadRouteNode( < 1748, 1393, 3 > )
	AddPayloadRouteNode( < 2433, 3156, -223 > )
	AddPayloadRouteNode( < 1355, 3926, -256 > )
	AddPayloadRouteNode( < -59, 4518, -260 > )
	
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < 3362, -3320, 8 >, 680 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < 3362, -2178, 8 >, 800 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < 1321, -2932, 0 >, 1024 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < 376, 3643, -257 >, 720 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < -1232, 3344, -252 >, 460 )

	array< entity > BWCSpawns0
	BWCSpawns0.append( CreatePayloadSpawnZone( < 1760, -787, -63 >, 900 ) )
	BWCSpawns0.append( CreatePayloadSpawnZone( < -198, -1181, 0 >, 680 ) )
	AddPayloadCheckpointWithZones( 0, < 1322, -1585, -45 >, BWCSpawns0 )
	
	array< entity > BWCSpawns1
	BWCSpawns1.append( CreatePayloadSpawnZone( < -418, 427, 128 >, 550 ) )
	BWCSpawns1.append( CreatePayloadSpawnZone( < 1449, 698, 64 >, 500 ) )
	AddPayloadCheckpointWithZones( 1, < 396, 669, -0 >, BWCSpawns1 )
	
	array< entity > BWCSpawns2
	BWCSpawns2.append( CreatePayloadSpawnZone( < 2635, 2056, -30 >, 600 ) )
	AddPayloadCheckpointWithZones( 2, < 2433, 3156, -223 >, BWCSpawns2 )
}

void function ExecEdenPayload()
{
	AddPayloadCustomShipStart( < 3905, 2496, 1100 >, < 0, -135, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < 4795, 2267, 1100 >, < 0, -135, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < -1979, 2851, 1100 >, < 0, -90, 0 >, TEAM_IMC )
	AddPayloadCustomShipStart( < -1296, 2961, 1100 >, < 0, -90, 0 >, TEAM_IMC )
	
	AddPayloadRouteNode( < -2502, 224, 73 > )
	AddPayloadRouteNode( < -271, -346, 55 > )
	AddPayloadRouteNode( < -130, -1368, 65 > )
	AddPayloadRouteNode( < 1579, -1627, 64 > )
	AddPayloadRouteNode( < 2424, -1332, 66 > )
	AddPayloadRouteNode( < 2480, 837, 56 > )
	AddPayloadRouteNode( < 3331, 2480, 64 > )
	
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < -1404, 2474, 306 >, 1000 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < 2595, 3017, 120 >, 800 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < 1847, 1476, 207 >, 680 )
	
	array< entity > EdenSpawns0
	EdenSpawns0.append( CreatePayloadSpawnZone( < -2135, 780, 54 >, 480 ) )
	EdenSpawns0.append( CreatePayloadSpawnZone( < -2269, -755, 72 >, 440 ) )
	AddPayloadCheckpointWithZones( 0, < -2502, 224, 73 >, EdenSpawns0 )
	
	array< entity > EdenSpawns1
	EdenSpawns1.append( CreatePayloadSpawnZone( < 1991, -916, 68 >, 360 ) )
	EdenSpawns1.append( CreatePayloadSpawnZone( < 1904, -2427, 72 >, 720 ) )
	AddPayloadCheckpointWithZones( 1, < 1579, -1627, 64 >, EdenSpawns1 )
	
	array< entity > EdenSpawns2
	EdenSpawns2.append( CreatePayloadSpawnZone( < 3083, 214, 72 >, 500 ) )
	EdenSpawns2.append( CreatePayloadSpawnZone( < 2090, 342, 71 >, 380 ) )
	AddPayloadCheckpointWithZones( 2, < 2480, 837, 56 >, EdenSpawns2 )
}

void function ExecKodaiPayload()
{
	AddPayloadCustomShipStart( < 2006, 4478, 1900 >, < 0, 235, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < 3014, 4028, 1900 >, < 0, 235, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < -750, -2243, 1900 >, < 0, 90, 0 >, TEAM_IMC )
	AddPayloadCustomShipStart( < 764, -2239, 1900 >, < 0, 90, 0 >, TEAM_IMC )
	
	AddPayloadRouteNode( < -1330, -1552, 803 > )
	AddPayloadRouteNode( < 90, -938, 793 > )
	AddPayloadRouteNode( < 34, 1479, 799 > )
	AddPayloadRouteNode( < 288, 2570, 960 > )
	AddPayloadRouteNode( < 433, 3638, 953 > )
	AddPayloadRouteNode( < 2149, 4022, 925 > )
	
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < -723, -1981, 951 >, 512 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < 737, -1998, 951 >, 640 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < 2478, 3433, 992 >, 400 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < 1191, 3001, 960 >, 680 )

	array< entity > KodaiSpawns0
	KodaiSpawns0.append( CreatePayloadSpawnZone( < -1072, -75, 961 >, 800 ) )
	KodaiSpawns0.append( CreatePayloadSpawnZone( < 964, -285, 960 >, 700 ) )
	AddPayloadCheckpointWithZones( 0, < 90, -938, 793 >, KodaiSpawns0 )
	
	array< entity > KodaiSpawns1
	KodaiSpawns1.append( CreatePayloadSpawnZone( < 1004, 1360, 961 >, 800 ) )
	KodaiSpawns1.append( CreatePayloadSpawnZone( < -1181, 1229, 1095 >, 460 ) )
	AddPayloadCheckpointWithZones( 1, < 34, 1479, 799 >, KodaiSpawns1 )
	
	array< entity > KodaiSpawns2
	KodaiSpawns2.append( CreatePayloadSpawnZone( < -891, 2833, 960 >, 1000 ) )
	AddPayloadCheckpointWithZones( 2, < 433, 3638, 953 >, KodaiSpawns2 )
}

void function ExecExoplanetPayload()
{
	AddPayloadCustomShipStart( < 2924, 1790, 800 >, < 0, -135, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < 2062, 2400, 800 >, < 0, -135, 0 >, TEAM_MILITIA )
	AddPayloadCustomShipStart( < 3141, -3125, 600 >, < 0, 135, 0 >, TEAM_IMC )
	AddPayloadCustomShipStart( < 2327, -4191, 600 >, < 0, 135, 0 >, TEAM_IMC )
	
	AddPayloadRouteNode( < 1736, -3868, -258 > )
	AddPayloadRouteNode( < 120, -3774, -222 > )
	AddPayloadRouteNode( < -58, -2383, -374 > )
	AddPayloadRouteNode( < 443, -1448, -191 > )
	AddPayloadRouteNode( < 234, -293, -259 > )
	AddPayloadRouteNode( < -418, 409, -261 > )
	AddPayloadRouteNode( < 117, 1355, -324 > )
	AddPayloadRouteNode( < 510, 2363, -372 > )
	AddPayloadRouteNode( < 1979, 2185, -351 > )
	
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < 3166, -3744, -288 >, 460 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_IMC, < 1281, -4872, -209 >, 810 )
	AddPayloadFixedSpawnZoneForTeam( TEAM_MILITIA, < 2894, 1697, -64 >, 600 )
	
	array< entity > ExoplanetSpawns0
	ExoplanetSpawns0.append( CreatePayloadSpawnZone( < -547, -3146, -107 >, 600 ) )
	AddPayloadCheckpointWithZones( 0, < 120, -3774, -222 >, ExoplanetSpawns0 )
	
	array< entity > ExoplanetSpawns1
	ExoplanetSpawns1.append( CreatePayloadSpawnZone( < -852, -1270, -320 >, 900 ) )
	ExoplanetSpawns1.append( CreatePayloadSpawnZone( < 1232, -533, -211 >, 900 ) )
	AddPayloadCheckpointWithZones( 1, < 234, -293, -259 >, ExoplanetSpawns1 )
	
	array< entity > ExoplanetSpawns2
	ExoplanetSpawns2.append( CreatePayloadSpawnZone( < -659, 1703, -319 >, 830 ) )
	AddPayloadCheckpointWithZones( 2, < 117, 1355, -324 >, ExoplanetSpawns2 )
}