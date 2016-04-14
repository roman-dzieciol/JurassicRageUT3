//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRMutator_Dinos extends UTMutator
    config(JR)
    abstract;


var int SpawnCount;
var int DesiredDinoCount;
var float DinoPlayerRatio;
var float DinoVehicleRatio;
var array<PathNode> SpawnNodes;
var array<Pawn> PlayerPawns;

var() config int SpawnForEachPlayer;
var() config int SpawnForEachVehicle;
var() config float SpawnFrequency;
var() config int SpawnLimit;

var() class<JRDino> DinoClass;
var() float VisibleCheckDist;


static function ResetUIConfig();
function InitSpawningData();
function int CalcDinoNumber();


function MatchStarting()
{
    SpawnCount = 0;
    
    DinoClass.static.VerifyUIConfig(DinoClass);
    
    InitSpawningData();

    // Init spawning timer to desired frequency, or to very rapid rate if dinos should be spawned at the beginning only
    if( SpawnFrequency > 0.0f )
    {
        SetTimer(60.0f/SpawnFrequency, true, 'DinoSpawnTimer');
    }
    else
    {
        SetTimer(0.2f, true, 'DinoSpawnTimerNoFrequency');
    }
}

final function DinoSpawnTimerNoFrequency()
{
    local NavigationPoint N;
    local JRDino D;
    
    // Spawn a dino    
    if( SpawnCount < SpawnLimit )
    {
        N = ChooseDinoStart();
        if( N != None )
        {
            D = Spawn(DinoClass,,,N.Location,N.Rotation);
            if( D != None )
            {
                ++SpawnCount;
            }
        }
    }
    else
    {
        // Stop spawning once the desired dino count is reached
        ClearTimer('DinoSpawnTimerNoFrequency');
    }
}

final function DinoSpawnTimer()
{
    local int DinoCount;
    local NavigationPoint N;
    local JRDino D;
    
    // Get desired dino count
    DinoPlayerRatio = (WorldInfo.Game.GetNumPlayers() + WorldInfo.Game.NumBots) * (SpawnForEachPlayer >= 0 ? float(SpawnForEachPlayer) : (-1.0/SpawnForEachPlayer));
    DesiredDinoCount = DinoVehicleRatio + DinoPlayerRatio;

    DinoCount = CalcDinoNumber();

    // Spawn a dino if needed
    if( DinoCount < Min(DesiredDinoCount,SpawnLimit) )
    {
        N = ChooseDinoStart();
        if( N != None )
        {
            D = Spawn(DinoClass,,,N.Location,N.Rotation);
            if( D != None )
            {
                ++SpawnCount;
            }
        }
    }
}

final function NavigationPoint ChooseDinoStart()
{
    local PathNode N, BestStart;
    local float BestRating, NewRating;

    // Find best start
    foreach SpawnNodes(N)
    {
        NewRating = RateDinoStart(N);
        if( NewRating > BestRating )
        {
            BestRating = NewRating;
            BestStart = N;
        }
    }
    return BestStart;
}

function float RateDinoStart(NavigationPoint N)
{
    local float Score, NextDist;
    local PlayerController C;

    // randomize
    Score = 1000.0f + FRand();

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

DefaultProperties
{
    VisibleCheckDist=4096
}