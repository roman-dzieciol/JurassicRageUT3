//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRWeap_Dino extends UTWeapon;

var() float CylRangeMult;

function GivenTo(Pawn NewOwner, bool bDoNotActivate)
{
    super.GivenTo(NewOwner, bDoNotActivate);

    if (JRDino(NewOwner) != None)
    {
        InstantHitDamage[0] = JRDino(NewOwner).DinoDamage;
        InstantHitDamage[1] = JRDino(NewOwner).DinoDamage;
    }
}

function float SuggestAttackStyle()
{
    return 1.0;
}

simulated function bool HasAnyAmmo()
{
    return true;
}

function bool CanAttack(Actor Other)
{
    return true;
}

// always have hammer and always have EMPPulse.
simulated function bool HasAmmo( byte FireModeNum, optional int Amount )
{
    return true;
}


/**
 * CalcWeaponFire: Simulate an instant hit shot.
 * This doesn't deal any damage nor trigger any effect. It just simulates a shot and returns
 * the hit information, to be post-processed later.
 *
 * ImpactList returns a list of ImpactInfo containing all listed impacts during the simulation.
 * CalcWeaponFire however returns one impact (return variable) being the first geometry impact
 * straight, with no direction change. If you were to do refraction, reflection, bullet penetration
 * or something like that, this would return exactly when the crosshair sees:
 * The first 'real geometry' impact, skipping invisible triggers and volumes.
 *
 * @param	StartTrace	world location to start trace from
 * @param	EndTrace	world location to end trace at
 * @output	ImpactList	list of all impacts that occured during simulation
 * @return	first 'real geometry' impact that occured.
 *
 * @note if an impact didn't occur, and impact is still returned, with its HitLocation being the EndTrace value.
 */
simulated function ImpactInfo CalcWeaponFire(vector StartTrace, vector EndTrace, optional out array<ImpactInfo> ImpactList)
{
	local ImpactInfo CurrentImpact;	
	local TraceHitInfo NoHitInfo;
	local float CylDist;
	local Actor A;
	
	CylDist = Instigator.default.CylinderComponent.CollisionRadius;
	
	StartTrace = Instigator.Location;
	EndTrace = StartTrace + vector(Instigator.Rotation)*CylDist;
	
	// grab player pawns in front and do not let go
    foreach GetTraceOwner().OverlappingActors(class'Actor', A, CylDist*CylRangeMult, EndTrace, false)
    {
        if( JRDino(A) != None )
            continue;
    
    	CurrentImpact.HitActor		= A;
    	CurrentImpact.HitLocation	= EndTrace;
    	CurrentImpact.HitNormal		= Normal(EndTrace-A.Location);
    	CurrentImpact.RayDir		= Normal(EndTrace-StartTrace);
    	CurrentImpact.HitInfo		= NoHitInfo;
    	
    	A.CheckHitInfo(CurrentImpact.HitInfo, None, Normal(EndTrace-StartTrace), CurrentImpact.HitLocation);
    	
    	// Add this hit to the ImpactList
    	ImpactList[ImpactList.Length] = CurrentImpact;
    }

	return CurrentImpact;
}

DefaultProperties
{
    CylRangeMult=1
    bTargetFrictionEnabled=True
    bTargetAdhesionEnabled=True
    ShotCost(0)=0
    ShotCost(1)=0
    CurrentRating=1.0
    FireInterval(0)=0.33
    FireInterval(1)=0.33
    InstantHitDamage(0)=15.0
    InstantHitDamage(1)=15.0
    InstantHitMomentum(0)=10000.0
    InstantHitMomentum(1)=10000.0
    InstantHitDamageTypes(0)=Class'JR.JRDmgType_Dino'
    InstantHitDamageTypes(1)=Class'JR.JRDmgType_Dino'
    AmmoDisplayType=EAWDS_None
    bCanThrow=False
    bInstantHit=True
    bMeleeWeapon=True
    WeaponRange=100.0
    bExportMenuData=False
}