//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRDinoController extends UTBot;

var float ChallengeTime;
var() float FearAttackChance;

function bool CanImpactJump()
{
    return False;
}

function SendMessage(PlayerReplicationInfo Recipient, name MessageType, float Wait, optional class<DamageType> DamageType)
{
}

event bool NotifyBump(Actor Other, Vector HitNormal)
{
    local Pawn P;

    // temporarily disable bump notifications to avoid getting overwhelmed by them
    Disable('NotifyBump');
    settimer(1.0, false, 'EnableBumps');

    P = Pawn(Other);
    if( P == None || P.Controller == None || Enemy == P )
        return false;

    if( Squad != None && Squad.SetEnemy(self,P) )
    {
        WhatToDoNext();
        return false;
    }

    if( Enemy == P )
        return false;

    if( CheckPathToGoalAround(P) )
        return false;

    ClearPathFor(P.Controller);
    return false;
}

function SetPeripheralVision()
{
    if( Pawn == None )
        return;

    bSlowerZAcquire = false;
    Pawn.PeripheralVision = -0.7;
    Pawn.SightRadius = Pawn.Default.SightRadius;
}

/* SetOrders()
Called when player gives orders to bot
*/
function SetBotOrders(name NewOrders, Controller OrderGiver, bool bShouldAck)
{
    WhatToDoNext();
}

// Return bot to its previous orders
function ClearTemporaryOrders()
{
}

function Initialize(float InSkill, const out CharacterInfo BotInfo)
{
    Skill = FClamp(InSkill, 0, 7);

    // Verify AI personality
    Aggressiveness = FClamp(Aggressiveness, 0, 1);
    BaseAggressiveness = Aggressiveness;
    Accuracy = FClamp(Accuracy, -5, 5);
    StrafingAbility = FClamp(StrafingAbility, -5, 5);
    CombatStyle = FClamp(CombatStyle, -1, 1);
    Jumpiness = FClamp(Jumpiness, -1, 1);
    Tactics = FClamp(Tactics, -5, 5);
    ReactionTime = FClamp(ReactionTime, -5, 5);

    ReSetSkill();
}

function SetMaxDesiredSpeed()
{
    if( Pawn != None && !bSpawnedByKismet )
    {
        if( Skill >= 4 )
        {
            Pawn.MaxDesiredSpeed = 1;
        }
        else
        {
            Pawn.MaxDesiredSpeed = 0.8 + 0.05 * Skill;
        }
    }
}


/** triggers ExecuteWhatToDoNext() to occur during the next tick
 * this is also where logic that is unsafe to do during the physics tick should be added
 * @note: in state code, you probably want LatentWhatToDoNext() so the state is paused while waiting for ExecuteWhatToDoNext() to be called
 */
event WhatToDoNext()
{
    if (bExecutingWhatToDoNext)
    {
        LogInternal("WhatToDoNext loop:" @ GetHumanReadableName());
        // ScriptTrace();
    }

    if (Pawn == None)
    {
        WarnInternal(GetHumanReadableName() @ "WhatToDoNext with no pawn");
        return;
    }

    if (Enemy == None || Enemy.bDeleteMe || Enemy.Health <= 0)
    {
        BlockedPath = None;
        bFrustrated = false;
        if (Focus == None || (Pawn(Focus) != None && Pawn(Focus).Health <= 0))
        {
            StopFiring();
            // if blew self up, return
            if ( (Pawn == None) || (Pawn.Health <= 0) )
                return;
        }
    }

    RetaskTime = 0.0;
    DecisionComponent.bTriggered = true;
}

/** entry point for AI decision making
 * this gets executed during the physics tick so actions that could change the physics state (e.g. firing weapons) are not allowed
 */
protected event ExecuteWhatToDoNext()
{
    local float StartleRadius, StartleHeight;

    if (Pawn == None)
    {
        // pawn got destroyed between WhatToDoNext() and now - abort
        return;
    }
    bHasFired = false;
    GoalString = "WhatToDoNext at "$WorldInfo.TimeSeconds;

    if (Pawn.Physics == PHYS_None)
        Pawn.SetMovementPhysics();

    if ( (Pawn.Physics == PHYS_Falling) && DoWaitForLanding() )
        return;

    if ( (StartleActor != None) && !StartleActor.bDeleteMe )
    {
        StartleActor.GetBoundingCylinder(StartleRadius, StartleHeight);
        if ( VSize(StartleActor.Location - Pawn.Location) < StartleRadius  )
        {
            Startle(StartleActor);
            return;
        }
    }

    bIgnoreEnemyChange = true;
    if ( (Enemy != None) && ((Enemy.Health <= 0) || (Enemy.Controller == None)) )
        LoseEnemy();

    if ( Enemy == None )
    {
        Squad.FindNewEnemyFor(self,false);
    }
    else if ( !Squad.MustKeepEnemy(Enemy) && !LineOfSightTo(Enemy) )
    {
        // decide if should lose enemy
        if ( Squad.IsDefending(self) )
        {
            if ( LostContact(4) )
                LoseEnemy();
        }
        else if ( LostContact(7) )
            LoseEnemy();
    }

    bIgnoreEnemyChange = false;
    if ( AssignSquadResponsibility() )
    {
        return;
    }

    if ( ShouldDefendPosition() )
    {
        return;
    }

    if ( Enemy != None )
    {
        ChooseAttackMode();
    }
    else
    {
        if (Pawn.FindAnchorFailedTime == WorldInfo.TimeSeconds)
        {
            // we failed the above actions because we couldn't find an anchor.
            GoalString = "No anchor" @ WorldInfo.TimeSeconds;
            if (Pawn.LastValidAnchorTime > 5.0)
            {
                if (bSoaking)
                {
                    SoakStop("NO PATH AVAILABLE!!!");
                }
                if ( (NumRandomJumps > 4) || PhysicsVolume.bWaterVolume )
                {
                    // can't suicide during physics tick, delay it
                    Pawn.SetTimer(0.01, false, 'Suicide');
                    return;
                }
                else
                {
                    // jump
                    NumRandomJumps++;
                    if (!Pawn.IsA('Vehicle') && Pawn.Physics != PHYS_Falling && Pawn.DoJump(false))
                    {
                        Pawn.SetPhysics(PHYS_Falling);
                        Pawn.Velocity = 0.5 * Pawn.GroundSpeed * VRand();
                        Pawn.Velocity.Z = Pawn.JumpZ;
                    }
                }
            }
        }

        GoalString @= "- Wander or Camp at" @ WorldInfo.TimeSeconds;
        bShortCamp = false;
        WanderOrCamp();
    }
}

/* ChooseAttackMode()
Handles tactical attacking state selection - choose which type of attack to do from here
*/
function ChooseAttackMode()
{
    GoalString = " ChooseAttackMode last seen "$(WorldInfo.TimeSeconds - LastSeenTime);

    if( Squad == None || Enemy == None || Pawn == None )
        LogInternal("HERE 1 Squad "$Squad$" Enemy "$Enemy$" pawn "$Pawn);

    GoalString = "ChooseAttackMode FightEnemy";
    FightEnemy(true, RelativeStrength(Enemy));
}


function FightEnemy(bool bCanCharge, float EnemyStrength)
{
    local vector X,Y,Z;
    local float enemyDist;
    local float AdjustedCombatStyle;
    local bool bFarAway, bOldForcedCharge;

    if ( (Squad == None) || (Enemy == None) || (Pawn == None) )
        LogInternal("HERE 3 Squad "$Squad$" Enemy "$Enemy$" pawn "$Pawn);

    if ( (Enemy == FailedHuntEnemy) && (WorldInfo.TimeSeconds == FailedHuntTime) )
    {
        GoalString = "FAILED HUNT - HANG OUT";
        if ( LineOfSightTo(Enemy) )
        {
            bCanCharge = false;
        }
        else
        {
            WanderOrCamp();
            return;
        }
    }

    bOldForcedCharge = bMustCharge;
    bMustCharge = false;
    enemyDist = VSize(Pawn.Location - Enemy.Location);
    AdjustedCombatStyle = CombatStyle + UTWeapon(Pawn.Weapon).SuggestAttackStyle();
    Aggression = 1.5 * FRand() - 0.8 + 2 * AdjustedCombatStyle - 0.5 * EnemyStrength
                + FRand() * (Normal(Enemy.Velocity - Pawn.Velocity) Dot Normal(Enemy.Location - Pawn.Location));
    if ( UTWeapon(Enemy.Weapon) != None )
        Aggression += 2 * UTWeapon(Enemy.Weapon).SuggestDefenseStyle();
    if ( enemyDist > MAXSTAKEOUTDIST )
        Aggression += 0.5;
    if (Squad != None)
    {
        Squad.ModifyAggression(self, Aggression);
    }
    if ( (Pawn.Physics == PHYS_Walking) || (Pawn.Physics == PHYS_Falling) )
    {
        if (Pawn.Location.Z > Enemy.Location.Z + TACTICALHEIGHTADVANTAGE)
            Aggression = FMax(0.0, Aggression - 1.0 + AdjustedCombatStyle);
        else if ( (Skill < 4) && (enemyDist > 0.65 * MAXSTAKEOUTDIST) )
        {
            bFarAway = true;
            Aggression += 0.5;
        }
        else if (Pawn.Location.Z < Enemy.Location.Z - Pawn.GetCollisionHeight()) // below enemy
            Aggression += CombatStyle;
    }

    if (!Pawn.CanAttack(Enemy))
    {
        if ( Squad.MustKeepEnemy(Enemy) )
        {
            GoalString = "Hunt priority enemy";
            GotoState('Hunting');
            return;
        }
        if ( !bCanCharge )
        {
            GoalString = "Stake Out - no charge";
            DoStakeOut();
        }
        else if ( Squad.IsDefending(self) && LostContact(4) && ClearShot(LastSeenPos, false) )
        {
            GoalString = "Stake Out "$LastSeenPos;
            DoStakeOut();
        }
        else if ( (((Aggression < 1) && !LostContact(3+2*FRand())) || IsSniping()) && CanStakeOut() )
        {
            GoalString = "Stake Out2";
            DoStakeOut();
        }
        else if ( Skill + Tactics >= 3.5 + FRand() && !LostContact(1) && VSize(Enemy.Location - Pawn.Location) < MAXSTAKEOUTDIST &&
            Pawn.Weapon != None && Pawn.Weapon.AIRating > 0.5 && !Pawn.Weapon.bMeleeWeapon &&
            FRand() < 0.75 && !LineOfSightTo(Enemy) && !Enemy.LineOfSightTo(Pawn) &&
            (Squad == None || !Squad.HasOtherVisibleEnemy(self)) )
        {
            GoalString = "Stake Out 3";
            DoStakeOut();
        }
        else
        {
            GoalString = "Hunt";
            GotoState('Hunting');
        }
        return;
    }

    // see enemy - decide whether to charge it or strafe around/stand and fire
    BlockedPath = None;
    Focus = Enemy;

    if( Pawn.Weapon.bMeleeWeapon || (bCanCharge && bOldForcedCharge) )
    {
        GoalString = "Charge";
        DoCharge();
        return;
    }

    if ( bCanCharge && (Skill < 5) && bFarAway && (Aggression > 1) && (FRand() < 0.5) )
    {
        GoalString = "Charge closer";
        DoCharge();
        return;
    }

    if ( bCanCharge )
    {
        if ( Aggression > 1 )
        {
            GoalString = "Charge 2";
            DoCharge();
            return;
        }
    }
    GoalString = "Do tactical move";
    if ( !UTWeapon(Pawn.Weapon).bRecommendSplashDamage && (FRand() < 0.7) && (3*Jumpiness + FRand()*Skill > 3) )
    {
        GetAxes(Pawn.Rotation,X,Y,Z);
        GoalString = "Try to Duck ";
        if ( FRand() < 0.5 )
        {
            Y *= -1;
            TryToDuck(Y, true);
        }
        else
            TryToDuck(Y, false);
    }
    DoTacticalMove();
}

function bool NeedWeapon()
{
    return false;
}

function bool ShouldStrafeTo(Actor WayPoint)
{
    return false;
}

function bool SuperPickupNotSpokenFor(UTPickupFactory P)
{
    return false;
}


/* ReceiveWarning()
 AI controlled creatures may duck
 if not falling, and projectile time is long enough
 often pick opposite to current direction (relative to shooter axis)
*/
event ReceiveWarning(Pawn shooter, float projSpeed, vector FireDir)
{
    local float enemyDist, projTime, DodgeTime;
    local vector X,Y,Z, enemyDir;

    LastUnderFire = WorldInfo.TimeSeconds;
    if ( WorldInfo.TimeSeconds - LastWarningTime < 0.5 )
        return;
    LastWarningTime = WorldInfo.TimeSeconds;

    // AI controlled creatures may duck if not falling
    if ( Pawn.bStationary || !Pawn.bCanStrafe || (Pawn.health <= 0) )
        return;

    if ( Enemy == None )
    {
        if ( Squad != None )
            Squad.SetEnemy(self, shooter);
        return;
    }

    if (Pawn.Physics == PHYS_Swimming)
        return;

    enemyDist = VSize(shooter.Location - Pawn.Location);

    if (enemyDist > 2000.0 * (Skill + StrafingAbility - 2.0) && Vehicle(shooter) == None && !Stopped() )
        return;

    // only if tight FOV
    GetAxes(Pawn.Rotation,X,Y,Z);
    enemyDir = shooter.Location - Pawn.Location;
    enemyDir.Z = 0;
    X.Z = 0;
    if ((Normal(enemyDir) Dot Normal(X)) < 0.7)
        return;

    if ( projSpeed > 0 && Vehicle(shooter) == None )
    {
        projTime = enemyDist/projSpeed;
        if ( projTime < 0.11 + 0.15 * FRand())
        {
            if ( Stopped() )
                GotoState('TacticalMove');
            return;
        }
    }

    if (Skill + StrafingAbility < 2.0 + 3.0 * FRand())
    {
        if (Stopped())
        {
            GotoState('TacticalMove');
        }
        return;
    }

    if (projSpeed < 0 && shooter.Weapon != None)
    {
        // instant hit attack
        // consider trying to dodge next shot instead of this one
        DodgeTime = shooter.Weapon.GetFireInterval(shooter.Weapon.CurrentFireMode) - 0.15 - 0.1 * FRand();
        if ( DodgeTime > 0.0 && DodgeTime >= 0.35 - 0.03 * (Skill + ReactionTime) &&
            DodgeTime >= 2.0 - (0.265 + FRand() * 0.2) * (Skill + ReactionTime) )
        {
            // check that we're not already going to dodge
            if ( InstantWarningShooter == None || InstantWarningShooter.bDeleteMe ||
                InstantWarningShooter.Controller == None ||  !IsTimerActive('DelayedInstantWarning') ||
                GetTimerRate('DelayedInstantWarning') - GetTimerCount('DelayedInstantWarning') > DodgeTime )
            {
                InstantWarningShooter = shooter;
                SetTimer(DodgeTime, false, 'DelayedInstantWarning');
            }
            return;
        }
    }

    if ( FRand() * (Skill + 4) < 4 )
    {
        if ( Stopped() )
            GotoState('TacticalMove');
        return;
    }

    if (Pawn.Physics == PHYS_Falling)
    {
        // no point in continuing, dodges below will fail
        return;
    }

    if ( (FireDir Dot Y) > 0 )
    {
        Y *= -1;
        if (TryToDuck(Y, true))
        {
            return;
        }
    }
    else
    {
        if (TryToDuck(Y, false))
        {
            return;
        }
    }

    // FIXME - if duck fails, try back jump if splashdamage landing

    if (Stopped())
    {
        GotoState('TacticalMove');
    }
}

function bool TryToDuck(vector duckDir, bool bReversed)
{
    local vector HitLocation, HitNormal, Extent, Start;
    local actor HitActor;
    local bool bSuccess, bDuckLeft, bWallHit, bChangeStrafe;
    local float MinDist,Dist;


//    if ( Stopped() )
//        GotoState('TacticalMove');    else
 if ( FRand() < 0.6 )
        bChangeStrafe = IsStrafing();


    if ( (Skill < 3) || Pawn.PhysicsVolume.bWaterVolume || (Pawn.Physics == PHYS_Falling)
        || (Pawn.GetGravityZ() > WorldInfo.DefaultGravityZ) )
        return false;
    if ( Pawn.bIsCrouched || Pawn.bWantsToCrouch || (Pawn.Physics != PHYS_Walking) )
        return false;

    duckDir.Z = 0;
    duckDir *= 335;
    bDuckLeft = bReversed;
    Extent = Pawn.GetCollisionRadius() * vect(1,1,0);
    Extent.Z = Pawn.GetCollisionHeight();
    Start = Pawn.Location + vect(0,0,25);
    HitActor = Trace(HitLocation, HitNormal, Start + duckDir, Start, false, Extent);

    MinDist = 150;
    Dist = VSize(HitLocation - Pawn.Location);
    if ( (HitActor == None) || ( Dist > 150) )
    {
        if ( HitActor == None )
            HitLocation = Start + duckDir;

        HitActor = Trace(HitLocation, HitNormal, HitLocation - Pawn.MaxStepHeight * vect(0,0,2.5), HitLocation, false, Extent);
        bSuccess = ( (HitActor != None) && (HitNormal.Z >= 0.7) );
    }
    else
    {
        bWallHit = Skill + 2*Jumpiness > 5;
        MinDist = 30 + MinDist - Dist;
    }

    if ( !bSuccess )
    {
        bDuckLeft = !bDuckLeft;
        duckDir *= -1;
        HitActor = Trace(HitLocation, HitNormal, Start + duckDir, Start, false, Extent);
        bSuccess = ( (HitActor == None) || (VSize(HitLocation - Pawn.Location) > MinDist) );
        if ( bSuccess )
        {
            if ( HitActor == None )
                HitLocation = Start + duckDir;

            HitActor = Trace(HitLocation, HitNormal, HitLocation - Pawn.MaxStepHeight * vect(0,0,2.5), HitLocation, false, Extent);
            bSuccess = ( (HitActor != None) && (HitNormal.Z >= 0.7) );
        }
    }
    if ( !bSuccess )
    {
        if ( bChangeStrafe )
            ChangeStrafe();
        return false;
    }

    if ( Skill + 2*Jumpiness > 3 + 3*FRand() )
        bNotifyFallingHitWall = true;

    if ( bNotifyFallingHitWall && bWallHit )
        bDuckLeft = !bDuckLeft; // plan to wall dodge
    if ( bDuckLeft )
        UTPawn(Pawn).CurrentDir = DCLICK_Left;
    else
        UTPawn(Pawn).CurrentDir = DCLICK_Right;

    bInDodgeMove = true;
    DodgeLandZ = Pawn.Location.Z;
    UTPawn(Pawn).Dodge(UTPawn(Pawn).CurrentDir);
    return true;
}

function TimedFireWeaponAtEnemy()
{
    if( VSize(Pawn.Location - Enemy.Location) > 256 && FRand() > FearAttackChance )
    	return;
    
    Super.TimedFireWeaponAtEnemy();
}

state Charging
{
ignores SeePlayer, HearNoise;


Begin:
    if (Pawn.Physics == PHYS_Falling)
    {
        Focus = Enemy;
        Destination = Enemy.Location;
        WaitForLanding();
    }
    if ( Enemy == None )
        LatentWhatToDoNext();
    if ( !FindBestPathToward(Enemy, false,true) )
        DoTacticalMove();
        
Moving:
//    if( VSize(Pawn.Location - Enemy.Location) < 125 )
//    {
//        GoalString = "Charging: ATTACK";
//        FireWeaponAt(Enemy);
//        Sleep(0.3f+FRand()*0.3f);
//    }

    // Warn enemy AI
    if( Enemy != None && UTBot(Enemy.Controller) != None && UTBot(Enemy.Controller).Enemy != Pawn )
    {
        UTBot(Enemy.Controller).DamageAttitudeTo(self,class'JRDino'.default.DinoDamage);
    }
    

    // Move closer
    GoalString = "Charging: MOVING";
    Focus = FaceActor(1);
    FinishRotation();
    MoveToward(MoveTarget,Focus,256.0f+256.0f*FRand(),ShouldStrafeTo(MoveTarget));
    
    // Leap
    if( VSize(Pawn.Location - Enemy.Location) < 512 && FRand() > 0.2 )
    {
        GoalString = "Charging: LEAP";
        bPlannedJump = true;
        Pawn.SetPhysics(PHYS_Falling);
        Pawn.SuggestJumpVelocity(Pawn.Velocity, Enemy.Location+Enemy.CylinderComponent.CollisionHeight*vect(0,0,0.33), Pawn.Location);
        Pawn.Acceleration = vect(0,0,0);
        Pawn.Velocity += MoveTarget.Velocity;
        bNotifyFallingHitWall = true;
        JRDino(Pawn).AirAttackBlend.SetBlendTarget(1, 0.2);
        if (Pawn.Physics == PHYS_Falling)
        {
            WaitForLanding();
        }
        
        Sleep(FRand()*0.33);

        if( VSize(Pawn.Location - Enemy.Location) < 256 )
        {
            GoalString = "Charging: FALLBACK";
            Destination = Enemy.Location + vector(rotator(Pawn.Location-Enemy.Location)+rot(0,1,0)*RandRange(-32768,+32768)) * (128.0f + FRand() * 128.0f);
            MoveTo(Destination,FaceActor(1));
        }
        else
        {
            GoalString = "Charging: FAIL";
            MoveToward(MoveTarget,FaceActor(1),,ShouldStrafeTo(MoveTarget));
        }
    }


    GoalString = "Charging: WHAT NEXT";
    LatentWhatToDoNext();
    if ( bSoaking )
        SoakStop("STUCK IN CHARGING!");
}


function MoveToDefensePoint()
{
    WanderOrCamp();
}

function MoveAwayFrom(Controller C)
{
    GoalString = "MOVE AWAY FROM/ "$GoalString;
    WanderOrCamp();
    ClearPathFor(C);
}

function WanderOrCamp()
{
    FindRoamDest();
    GotoState('Roaming', 'Begin');
}

state Roaming
{
    ignores EnemyNotVisible;

    function MoveAwayFrom(Controller C)
    {
        local int i;
        local NavigationPoint Best, CurrentPosition;
        local float BestDot, CurrentDot;
        local vector BlockedDir;

        Pawn.bWantsToCrouch = false;

        // if already moving, don't do anything
        if ( InLatentExecution(LATENT_MOVETOWARD) )
            return;

        if ( (Pawn.Anchor != None) && Pawn.ReachedDestination(Pawn.Anchor) )
            CurrentPosition = Pawn.Anchor;

        if ( (CurrentPosition != None) && Pawn.ReachedDestination(CurrentPosition) )
        {
            BlockedDir = Normal(C.Pawn.Acceleration);
            if ( BlockedDir == vect(0,0,0) )
                return;

            // pick a spec off of current position as perpendicular as possible to BlockedDir
            for ( i=0; i<CurrentPosition.PathList.Length; i++ )
            {
                if ( !CurrentPosition.PathList[i].IsBlockedFor(Pawn) )
                {
                    CurrentDot = Abs(Normal(CurrentPosition.Pathlist[i].End.Nav.Location - Pawn.Location) dot BlockedDir);
                    if ( (Best == None) || (CurrentDot < BestDot) )
                    {
                        Best = CurrentPosition.Pathlist[i].End.Nav;
                        BestDot = CurrentDot;
                    }
                }
            }
            if ( Best == None )
            {
                return;
            }
            else
            {
                MoveTarget = Best;
            }
        }
        else
        {
            RouteGoal = None;
            FindRoamDest();
        }
        GotoState('Roaming','Begin');
    }

Begin:
    Sleep(0.5+FRand()*0.5f);
    WaitForLanding();
    Focus = FaceActor(1);
    FinishRotation();
    JRDino(Pawn).PlayIdleSound();
    if( Frand() > 0.66 )
    {
        MoveToward(MoveTarget,FaceActor(1),GetDesiredOffset(),ShouldStrafeTo(MoveTarget));
    }
    else
    {
        Sleep(1.0+FRand()*2.0f);
    }
    
DoneRoaming:
    WaitForLanding();
    LatentWhatToDoNext();
    if ( bSoaking )
        SoakStop("STUCK IN ROAMING!");
}


state Hunting
{
ignores EnemyNotVisible;


    function PickDestination()
    {
        local vector nextSpot, ViewSpot,Dir;
        local float posZ;
        local bool bCanSeeLastSeen;
        local int i;

        // If no enemy, or I should see him but don't, then give up
        if ( (Enemy == None) || (Enemy.Health <= 0) || (Enemy.IsInvisible() && (WorldInfo.TimeSeconds - LastSeenTime > Skill)) )
        {
            LoseEnemy();
            WhatToDoNext();
            return;
        }

        if ( Pawn.JumpZ > 0 )
            Pawn.bCanJump = true;

        if ( ActorReachable(Enemy) )
        {
            BlockedPath = None;
            if ( (LostContact(5) && (((Enemy.Location - Pawn.Location) Dot vector(Pawn.Rotation)) < 0))
                && LoseEnemy() )
            {
                WhatToDoNext();
                return;
            }
            Destination = Enemy.Location;
            MoveTarget = None;
            return;
        }

        ViewSpot = Pawn.Location + Pawn.BaseEyeHeight * vect(0,0,1);
        bCanSeeLastSeen = bEnemyInfoValid && FastTrace(LastSeenPos, ViewSpot);

        if (BlockedPath != None || Squad.BeDevious(Enemy))
        {
            if ( BlockedPath == None )
            {
                // block the first path visible to the enemy
                if ( FindPathToward(Enemy,false) != None )
                {
                    for ( i=0; i<RouteCache.Length; i++ )
                    {
                        if ( RouteCache[i] == None )
                            break;
                        else if ( Enemy.Controller.LineOfSightTo(RouteCache[i]) )
                        {
                            BlockedPath = RouteCache[i];
                            break;
                        }
                    }
                    bForceRefreshRoute = true;
                }
                else if ( CanStakeOut() )
                {
                    GoalString = "Stakeout from hunt";
                    GotoState('StakeOut');
                    return;
                }
                else if ( LoseEnemy() )
                {
                    WhatToDoNext();
                    return;
                }
            }
            // control path weights
            if ( BlockedPath != None )
            {
                BlockedPath.TransientCost = 5000;
            }
        }
        if (!bDirectHunt)
        {
            Squad.MarkHuntingSpots(self);
        }
        if ( FindBestPathToward(Enemy, true, true) )
            return;

        if ( bSoaking && (Physics != PHYS_Falling) )
            SoakStop("COULDN'T FIND PATH TO ENEMY "$Enemy);

        MoveTarget = None;
        if ( !bEnemyInfoValid && LoseEnemy() )
        {
            WhatToDoNext();
            return;
        }

        Destination = LastSeeingPos;
        bEnemyInfoValid = false;
        if ( FastTrace(Enemy.Location, ViewSpot)
            && VSize(Pawn.Location - Destination) > Pawn.CylinderComponent.CollisionRadius )
            {
                SeePlayer(Enemy);
                return;
            }

        posZ = LastSeenPos.Z + Pawn.GetCollisionHeight() - Enemy.GetCollisionHeight();
        nextSpot = LastSeenPos - Normal(Enemy.Velocity) * Pawn.CylinderComponent.CollisionRadius;
        nextSpot.Z = posZ;
        if ( FastTrace(nextSpot, ViewSpot) )
            Destination = nextSpot;
        else if ( bCanSeeLastSeen )
        {
            Dir = Pawn.Location - LastSeenPos;
            Dir.Z = 0;
            if ( VSize(Dir) < Pawn.GetCollisionRadius() )
            {
                GoalString = "Stakeout 3 from hunt";
                GotoState('StakeOut');
                return;
            }
            Destination = LastSeenPos;
        }
        else
        {
            Destination = LastSeenPos;
            if ( !FastTrace(LastSeenPos, ViewSpot) )
            {
                // check if could adjust and see it
                if ( PickWallAdjust(Normal(LastSeenPos - ViewSpot)) || FindViewSpot() )
                {
                    if ( Pawn.Physics == PHYS_Falling )
                        SetFall();
                    else
                        GotoState('Hunting', 'AdjustFromWall');
                }
                else if ( (Pawn.Physics == PHYS_Flying) && LoseEnemy() )
                {
                    WhatToDoNext();
                    return;
                }
                else
                {
                    GoalString = "Stakeout 2 from hunt";
                    GotoState('StakeOut');
                    return;
                }
            }
        }
    }
}


state TacticalMove
{
ignores SeePlayer, HearNoise;


TacticalTick:
    Sleep(0.02);
Begin:
    if ( Enemy == None )
    {
        sleep(0.01);
        Goto('FinishedStrafe');
    }
    if (Pawn.Physics == PHYS_Falling)
    {
        Focus = Enemy;
        Destination = Enemy.Location;
        WaitForLanding();
    }
    if ( Enemy == None )
        Goto('FinishedStrafe');
    PickDestination();

DoMove:
    if ( FocusOnLeader(false) )
        MoveTo(Destination, Focus);
    else if ( !Pawn.bCanStrafe )
    {
        StopFiring();
        MoveTo(Destination);
    }
    else
    {
DoStrafeMove:
        MoveTo(Destination, Enemy);
    }
    if ( bForcedDirection && (WorldInfo.TimeSeconds - StartTacticalTime < 0.2) )
    {
        if ( !Pawn.HasRangedAttack() || Skill > 2 + 3 * FRand() )
        {
            bMustCharge = true;
            LatentWhatToDoNext();
        }
    }
    if ( (Enemy == None) || LineOfSightTo(Enemy) || !FastTrace(Enemy.Location, LastSeeingPos) || (Pawn.Weapon != None && Pawn.Weapon.bMeleeWeapon) )
        Goto('FinishedStrafe');

RecoverEnemy:
    GoalString = "Recover Enemy";
    HidingSpot = Pawn.Location;
    StopFiring();
    Sleep(0.1 + 0.2 * FRand());
    Destination = LastSeeingPos + 4 * Pawn.GetCollisionRadius() * Normal(LastSeeingPos - Pawn.Location);
    MoveTo(Destination, Enemy);

    if (FireWeaponAt(Enemy))
    {
        Pawn.Acceleration = vect(0,0,0);
        if (Pawn.Weapon != None && Pawn.Weapon.GetDamageRadius() > 0)
        {
            StopFiring();
            Sleep(0.05);
        }
        else
            Sleep(0.1 + 0.3 * FRand() + 0.06 * (7 - FMin(7,Skill)));
        if ( (FRand() + 0.3 > Aggression) )
        {
            Enable('EnemyNotVisible');
            Destination = HidingSpot + 4 * Pawn.GetCollisionRadius() * Normal(HidingSpot - Pawn.Location);
            Goto('DoMove');
        }
    }
FinishedStrafe:
    LatentWhatToDoNext();
    if ( bSoaking )
        SoakStop("STUCK IN TACTICAL MOVE!");
}

state StakeOut
{
ignores EnemyNotVisible;

    function FindNewStakeOutDir()
    {
        local NavigationPoint N, Best;
        local vector Dir, EnemyDir;
        local float Dist, BestVal, Val;

        EnemyDir = Normal(Enemy.Location - Pawn.Location);
        foreach WorldInfo.AllNavigationPoints(class'NavigationPoint', N)
        {
            Dir = N.Location - Pawn.Location;
            Dist = VSize(Dir);
            if ( (Dist < MAXSTAKEOUTDIST) && (Dist > MINSTRAFEDIST) )
            {
                Val = (EnemyDir Dot Dir/Dist);
                if ( (Val > BestVal) && LineOfSightTo(N) )
                {
                    BestVal = Val;
                    Best = N;
                }
            }
        }
        if ( Best != None )
            FocalPoint = Best.Location + 0.5 * Pawn.GetCollisionHeight() * vect(0,0,1);
    }


    event SeePlayer(Pawn SeenPlayer)
    {
        if ( SeenPlayer == Enemy )
        {
            VisibleEnemy = Enemy;
            EnemyVisibilityTime = WorldInfo.TimeSeconds;
            bEnemyIsVisible = true;
            if ( !FocusOnLeader(false) && (FRand() < 0.5) )
            {
                Focus = Enemy;
                FireWeaponAt(Focus);
            }
            WhatToDoNext();
        }
        else if ( Squad.SetEnemy(self,SeenPlayer) )
        {
            if ( Enemy == SeenPlayer )
            {
                VisibleEnemy = Enemy;
                EnemyVisibilityTime = WorldInfo.TimeSeconds;
                bEnemyIsVisible = true;
            }
            WhatToDoNext();

            if( ChallengeTime < WorldInfo.TimeSeconds )
            {
                ChallengeTime = WorldInfo.TimeSeconds + 7;
                JRDino(Pawn).PlayChallengeSound();
            }
        }
    }
}

event SeePlayer(Pawn SeenPlayer)
{
    if (Squad == None && !WorldInfo.GRI.OnSameTeam(self, SeenPlayer))
    {
        // maybe scripted pawn; just notify Kismet
        Pawn.TriggerEventClass(class'SeqEvent_AISeeEnemy', SeenPlayer);
    }
    else if (Squad.SetEnemy(self, SeenPlayer))
    {
        // check for any Kismet scripts that might care
        Pawn.TriggerEventClass(class'SeqEvent_AISeeEnemy', SeenPlayer);

        WhatToDoNext();

        if( ChallengeTime < WorldInfo.TimeSeconds )
        {
            ChallengeTime = WorldInfo.TimeSeconds + 7;
            JRDino(Pawn).PlayChallengeSound();
        }
    }
    if ( Enemy == SeenPlayer )
    {
        VisibleEnemy = Enemy;
        EnemyVisibilityTime = WorldInfo.TimeSeconds;
        bEnemyIsVisible = true;
    }
}

state InQueue
{
    function BeginState(Name PreviousStateName)
    {
        Super(AIController).BeginState(PreviousStateName);
    }

    function EndState(Name NextStateName)
    {
        Super(AIController).EndState(NextStateName);
    }
}


state Dead
{
ignores SeePlayer, EnemyNotVisible, HearNoise, ReceiveWarning, NotifyLanded, NotifyPhysicsVolumeChange,
        NotifyHeadVolumeChange, NotifyLanded, NotifyHitWall, NotifyBump, ExecuteWhatToDoNext;

    function BeginState(Name PreviousStateName)
    {
        if (bSpawnedByKismet )
        {
            Destroy();
            return;
        }
        if ( (DefensePoint != None) && (UTHoldSpot(DefensePoint) == None) )
            FreePoint();
        if ( NavigationPoint(MoveTarget) != None )
        {
            NavigationPoint(MoveTarget).FearCost = 2 * NavigationPoint(MoveTarget).FearCost + 600;
            WorldInfo.Game.bDoFearCostFallOff = true;
        }
        PendingMover = None;
        Enemy = None;
        StopFiring();
        bFrustrated = false;
        BlockedPath = None;
        bInitLifeMessage = false;
        bPlannedJump = false;
        bInDodgeMove = false;
        bReachedGatherPoint = false;
        bFinalStretch = false;
        bWasNearObjective = false;
        bPreparingMove = false;
        bPursuingFlag = false;
        bHasSuperWeapon = false;
        bHasTranslocator = false;
        ImpactJumpZ = 0.f;
        RouteGoal = None;
        NoVehicleGoal = None;
        SquadRouteGoal = None;
        bUsingSquadRoute = true;
        bUsePreviousSquadRoute = false;
        MoveTarget = None;
        ImpactVelocity = vect(0,0,0);
        LastSeenTime = -1000;
        bEnemyInfoValid = false;
    }
}

/** state that disables the bot's movement and objective selection, but allows them to target and fire upon any enemies in the area */
state FrozenMovement
{
    ignores ExecuteWhatToDoNext;

    event PushedState()
    {
        StopMovement();
        bScriptedFrozen = true;
    }
}

DefaultProperties
{
	bIsPlayer=False
	
	FearAttackChance=0.5

	Aggressiveness = 0.4	// -+1
	CombatStyle = 0.2		// -+1		
	Jumpiness = 0			// -+1
	Accuracy = 0			// -+5
	StrafingAbility = 0		// -+5
	Tactics = 0				// -+5
	ReactionTime = 0		// -+5
}