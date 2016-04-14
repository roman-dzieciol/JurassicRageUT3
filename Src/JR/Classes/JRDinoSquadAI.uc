//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRDinoSquadAI extends UTSquadAI;


simulated function DisplayDebug(HUD HUD, out float YL, out float YPos)
{
    local string EnemyList;
    local int i;
    local Canvas Canvas;

    Canvas = HUD.Canvas;
    Canvas.SetDrawColor(255,255,255);
    EnemyList = "     Enemies: ";
    for ( i=0; i<ArrayCount(Enemies); i++ )
        if ( Enemies[i] != None )
            EnemyList = EnemyList@Enemies[i].GetHumanReadableName();
    Canvas.DrawText(EnemyList, false);

    YPos += YL;
    Canvas.SetPos(4,YPos);
}

function bool IsDefending(UTBot B)
{
    return false;
}

function AddBot(UTBot B)
{
    Super.AddBot(B);
    SquadLeader = B;
}

function RemoveBot(UTBot B)
{
    if ( B.Squad != self )
        return;
    Destroy();
}

/*
Return true if squad should defer to C
*/
function bool ShouldDeferTo(Controller C)
{
    return false;
}

function bool CheckSquadObjectives(UTBot B)
{
    return false;
}

function bool WaitAtThisPosition(Pawn P)
{
    return false;
}

function bool NearFormationCenter(Pawn P)
{
    return true;
}

/* BeDevious()
return true if bot should use guile in hunting opponent (more expensive)
*/
function bool BeDevious(Pawn Enemy)
{
    return true;
}

function name GetOrders()
{
    return CurrentOrders;
}

function bool SetEnemy( UTBot B, Pawn NewEnemy )
{
    local bool bResult;

    if( JRDino(NewEnemy) != None
    ||  (UTAirVehicle(NewEnemy) != None && NewEnemy.Location.Z - B.Pawn.Location.Z > B.Pawn.JumpZ) )
        return false;

    if((NewEnemy == None)
    || (NewEnemy.Health <= 0)
    || (NewEnemy.Controller == None)
    || ((UTBot(NewEnemy.Controller) != None) && (UTBot(NewEnemy.Controller).Squad == self)) )
        return false;

    // add new enemy to enemy list - return if already there
    if ( !AddEnemy(NewEnemy) )
        return false;

    // reassess squad member enemy
    bResult = FindNewEnemyFor(B,(B.Enemy !=None) && B.LineOfSightTo(SquadMembers.Enemy));
    if ( bResult && (B.Enemy == NewEnemy) )
        B.AcquireTime = WorldInfo.TimeSeconds;

    return bResult;
}

function bool FriendlyToward(Pawn Other)
{
    if( JRDino(Other) != None )
        return true;

    return false;
}

function float VehicleDesireability(UTVehicle V, UTBot B)
{
    return 0;
}

function bool AssignSquadResponsibility(UTBot B)
{
    // if have no enemy
    if (B.Enemy == None)
    {
        // roam around level?
        return B.FindRoamDest();
    }

    return false;
}

defaultproperties
{
   CurrentOrders="Freelance"
}
