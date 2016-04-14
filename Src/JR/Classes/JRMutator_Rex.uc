//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRMutator_Rex extends JRMutator_Dinos;


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
        if( N.bBlocked || N.bBlockedForVehicles )
            continue;

        SpawnNodes.AddItem(N);
    }
}


function int CalcDinoNumber()
{
    local int DinoCount;
    local JRRex D;

    // Count dinos
    foreach WorldInfo.AllPawns(class'JRRex', D)
    {
        ++DinoCount;
    }
    
    return DinoCount;
}

function float RateDinoStart(NavigationPoint N)
{
    local float Score, NextDist;
    local PlayerController C;

    // randomize
    Score = 1000.0f + FRand();
    
    if( N.bPreferredVehiclePath )
        Score += 1000.0f;

    ForEach WorldInfo.AllControllers(class'PlayerController', C)
    {
        if( C.bIsPlayer && C.Pawn != None )
        {
            // avoid starts close to visible enemy
            NextDist = VSize(C.Pawn.Location - N.Location);
            if( NextDist < VisibleCheckDist 
            &&  FastTrace(N.Location, C.Pawn.Location+vect(0,0,1)*C.Pawn.CylinderComponent.CollisionHeight) )
            {
                if( NextDist < 384 )
                {
                    // Avoid spawning very close
                    return -1; 
                }
                else
                {
                    // Avoid spawning in view
                    Score -= (VisibleCheckDist - NextDist)/(VisibleCheckDist * 0.02); // up to -50
                }
            }
        }
    }

    return Score;
}

static function ResetUIConfig()
{
    default.SpawnForEachPlayer = -8;
    default.SpawnForEachVehicle = -4;
    default.SpawnFrequency = 15;
    default.SpawnLimit = 8;
    StaticSaveConfig();
}

DefaultProperties
{
    DinoClass=class'JRRex'
    
    SpawnForEachPlayer=-8
    SpawnForEachVehicle=-4
    SpawnFrequency=15
    SpawnLimit=8
}
