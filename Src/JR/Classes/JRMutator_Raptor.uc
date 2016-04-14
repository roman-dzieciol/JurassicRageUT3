//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRMutator_Raptor extends JRMutator_Dinos;


function InitSpawningData()
{
    local PathNode N;
    local UTVehicleFactory F;

    // Vehicle factories may increase dino count, so count them beforehand
    DinoVehicleRatio = 0;
    if( SpawnForEachVehicle != 0 )
    {
        foreach WorldInfo.AllNavigationPoints(class'UTVehicleFactory', F)
        {
            DinoVehicleRatio += (SpawnForEachVehicle >= 0 ? float(SpawnForEachVehicle) : (-1.0/SpawnForEachVehicle));
        }
    }

    // Get navigation points suitable for spawning
    foreach WorldInfo.AllNavigationPoints(class'PathNode', N)
    {
        // Must be on ground
        if( N.bNotBased )
            continue;

        // Must not be blocked
        if( N.bBlocked )
            continue;

        // Must be a plain PathNode
        if( N.CollisionType != COLLIDE_NoCollision )
            continue;

        SpawnNodes.AddItem(N);
    }
}

function int CalcDinoNumber()
{
    local int DinoCount;
    local JRRaptor D;

    // Count dinos
    foreach WorldInfo.AllPawns(class'JRRaptor', D)
    {
        ++DinoCount;
    }
    
    return DinoCount;
}

static function ResetUIConfig()
{
    default.SpawnForEachPlayer = -2;
    default.SpawnForEachVehicle = -2;
    default.SpawnFrequency = 30;
    default.SpawnLimit = 32;
    StaticSaveConfig();
}

DefaultProperties
{
    DinoClass=class'JRRaptor'
    
    SpawnForEachPlayer=-2
    SpawnForEachVehicle=-2
    SpawnFrequency=30
    SpawnLimit=32
}