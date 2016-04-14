//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRRexController extends JRDinoController;


function bool FireWeaponAt(Actor A)
{
    if ( A == None )
        A = Enemy;
    if ( (A == None) || (Focus != A) )
        return false;
    Focus = A;
    
    if( VSize(A.Location-Pawn.Location) > 1024 )
        return false;
    
    if ( Pawn.Weapon != None )
    {
        if ( Pawn.Weapon.HasAnyAmmo() )
            return WeaponFireAgain(false);
    }
    else
        return WeaponFireAgain(false);

    return false;
}

event ReceiveWarning(Pawn shooter, float projSpeed, vector FireDir)
{
    LastUnderFire = WorldInfo.TimeSeconds;
    if ( WorldInfo.TimeSeconds - LastWarningTime < 0.5 )
        return;
    LastWarningTime = WorldInfo.TimeSeconds;

    // AI controlled creatures may duck if not falling
    if ( Pawn.bStationary || !Pawn.bCanStrafe || (Pawn.health <= 0) )
        return;

    if( Enemy == None )
    {
        if( Squad != None )
            Squad.SetEnemy(self, shooter);
        return;
    }
}

function bool TryToDuck(vector duckDir, bool bReversed)
{
    return false;
}


state Charging
{
ignores SeePlayer, HearNoise;

    function bool TryStrafe(vector sideDir)
    {
    	return false;
    }
    
    function bool StrafeFromDamage(float Damage, class<DamageType> DamageType, bool bFindDest)
    {
    }
    
    function bool TryToDuck(vector duckDir, bool bReversed)
    {
    }

Begin:
    if (Pawn.Physics == PHYS_Falling)
    {
        Focus = Enemy;
        Destination = Enemy.Location;
        WaitForLanding();
    }
    Sleep(0.1);
    if ( Enemy == None )
        LatentWhatToDoNext();
    if ( !FindBestPathToward(Enemy, false,true) )
        DoTacticalMove();
        
Moving:
    Sleep(0.1);
    
    if( VSize(Pawn.Location - Enemy.Location) < 196 )
    {
        GoalString = "Charging: ATTACK";
        FireWeaponAt(Enemy);
        Sleep(0.66+FRand()*0.66f);
    }

    // Warn enemy AI
    if( Enemy != None && UTBot(Enemy.Controller) != None && UTBot(Enemy.Controller).Enemy != Pawn )
    {
        UTBot(Enemy.Controller).DamageAttitudeTo(self,class'JRRex'.default.DinoDamage);
    }

    // Move closer
    GoalString = "Charging: MOVING";
    Focus = FaceActor(1);
    FinishRotation();
    MoveToward(MoveTarget,Focus,0,ShouldStrafeTo(MoveTarget));
    
    GoalString = "Charging: WHAT NEXT";
    LatentWhatToDoNext();
    if ( bSoaking )
        SoakStop("STUCK IN CHARGING!");
}

event MayDodgeToMoveTarget()
{
	// Don't dodge
}

function SetFall()
{
	// Don't adjust
}


state TacticalMove
{
ignores SeePlayer, HearNoise;


	function SetFall()
	{
		// Don't adjust
	}

    function bool EngageDirection(vector StrafeDir, bool bForced)
    {
        local actor HitActor;
        local vector HitLocation, collspec, MinDest, HitNormal;
        
        // Don't jump

        // successfully engage direction if can trace out and down
        MinDest = Pawn.Location + MINSTRAFEDIST * StrafeDir;
        if ( !bForced )
        {
            collSpec = Pawn.GetCollisionRadius() * vect(1,1,0);
            collSpec.Z = FMax(6, Pawn.GetCollisionHeight() - Pawn.MaxStepHeight);

            HitActor = Trace(HitLocation, HitNormal, MinDest, Pawn.Location, false, collSpec);
            if ( (HitActor != None) )
                return false;

            if ( Pawn.Physics == PHYS_Walking )
            {
                collSpec.X = FMin(14, 0.5 * Pawn.GetCollisionRadius());
                collSpec.Y = collSpec.X;
                HitActor = Trace(HitLocation, HitNormal, minDest - (3 * Pawn.MaxStepHeight) * vect(0,0,1), minDest, false, collSpec);
                if ( HitActor == None )
                {
                    HitNormal = -1 * StrafeDir;
                    return false;
                }
            }
        }
        
        Destination = MinDest + StrafeDir * (0.5 * MINSTRAFEDIST
                                            + FMin(VSize(Enemy.Location - Pawn.Location), MINSTRAFEDIST * (FRand() + FRand())));
        return true;
    }
}

function bool TryWallDodge(vector HitNormal, actor HitActor)
{
    return false;
}

DefaultProperties
{
	RotationRate=(Pitch=8192,Yaw=8192,Roll=2048)
	
	
	FearAttackChance=0.2
	
	Aggressiveness = 1.0	// -+1
	CombatStyle = 1.0		// -+1		
	Jumpiness = -1			// -+1
	Accuracy = 0			// -+5
	StrafingAbility = -5	// -+5
	Tactics = 5				// -+5
	ReactionTime = -5		// -+5
}