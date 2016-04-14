//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRDino extends UTPawn
    config(JR);


struct ConfigRange
{
	var() float Min, Max, Optimal;
};

var() SoundCue IdleSound;
var() SoundCue AttackSound;
var() SoundCue ChallengeSound;
var float LastIdleSound;
var float LastChallengeSound;

var() config repnotify int DinoSpeed;
var() config repnotify int DinoHealth;
var() config int DinoSkill;
var() config int DinoDamage;

var AnimNodeBlend AirAttackBlend;

var bool bTestDino;

var() class<UTWeapon> DinoWeapon;
var() bool bGrabPlayer;
var() bool bAdjustDino;
var() float AdjustCheckDist;
var Pawn RepEnemy;

var CylinderComponent CylinderComponentAlt;

var() ConfigRange DinoSpeedRange;
var() ConfigRange DinoHealthRange;
var() ConfigRange DinoSkillRange;
var() ConfigRange DinoDamageRange;

var SkelControlFootPlacement LeftLegControl2, RightLegControl2;

var() float VehicleStopAmount;

var() float RagdollDamage;
var() float VehicleHitMult;
var() float VehicleHitMinDmg;
var() float VehicleHitMaxDmg;

var() float BloodDrawScale;

var() float PhysicsHitDistMult;
var() float PhysicsHitDmgMult;
var() float PhysicsHitStrength;
var() ERadialImpulseFalloff PhysicsHitFalloff;
var() float PhysicsHitDriveScale;
var() float PhysicsHitBaseWeight;

var() bool bDinoBodyMat;

replication
{
    // replicated properties
    if ( bNetInitial && bNetDirty )
        DinoSpeed, DinoHealth, DinoSkill, DinoDamage;
        
    if( bNetDirty )
        RepEnemy;
}


simulated event PostInitAnimTree(SkeletalMeshComponent SkelComp)
{
    Super.PostInitAnimTree(SkelComp);
    
	if (SkelComp == Mesh)
	{
	    // Use different variable name so native code won't interfere
        LeftLegControl2 = LeftLegControl;
        RightLegControl2 = RightLegControl;
        LeftLegControl = None;
        RightLegControl = None;
        
        FixFootControl(LeftLegControl2);
        FixFootControl(RightLegControl2);
	}
}

simulated function FixFootControl( SkelControlFootPlacement C )
{
    local float AdjustScale;
    
    C.SetSkelControlActive(True);
    C.SetSkelControlStrength(1,0);
    
    AdjustScale = Mesh.Scale;
    C.FootOffset = C.FootOffset * AdjustScale;
    C.MaxUpAdjustment = C.MaxUpAdjustment * AdjustScale;
    C.MaxDownAdjustment = C.MaxDownAdjustment * AdjustScale;
    //`log(C.FootOffset);
}

/**
 * Check on various replicated data and act accordingly.
 */
simulated event ReplicatedEvent(name VarName)
{
    if (VarName == 'DinoSpeed')
    {
        GroundSpeed = DinoSpeed;
        AirSpeed = DinoSpeed;
    }
    else if (VarName == 'DinoHealth')
    {
        Health = DinoHealth;
    }
    else
    {
        Super.ReplicatedEvent(VarName);
    }
}

simulated event PostBeginPlay()
{
    Super.PostBeginPlay();

    if( Health > 0 && Controller == None)
    {
        SetInfoFromFamily(DefaultFamily, Mesh.SkeletalMesh);
        if( !bTestDino )
            SpawnDefaultController();
        AddDefaultInventory();
    }

    InitDinoProps();
}


simulated function InitDinoProps()
{
    if( GroundSpeed == default.GroundSpeed )
        GroundSpeed = DinoSpeed;

    if( AirSpeed == default.AirSpeed )
        AirSpeed = DinoSpeed;

    if( Health == default.Health )
        Health = DinoHealth;
}


function SpawnDefaultController()
{
    local UTGame Game;
    local UTBot Bot;
    local CharacterInfo EmptyBotInfo;
    local UTSquadAI S;

    Super(Pawn).SpawnDefaultController();

    Game = UTGame(WorldInfo.Game);
    Bot = UTBot(Controller);
    if (Game != None && Bot != None)
    {
        Bot.Initialize(DinoSkill, EmptyBotInfo);
        S = Spawn(class'JRDinoSquadAI');
        S.Initialize(None,None,Bot);
    }
}

function AddDefaultInventory()
{
    Super.AddDefaultInventory();
    CreateInventory(DinoWeapon);
}

//event EncroachedBy(Actor Other)
//{
//    Super.EncroachedBy(Other);
//
//    `log("EncroachedBy" @Other);
//}
//
//event bool EncroachingOn( actor Other )
//{
//    `log("EncroachingOn" @Other);
//
//    return Super.EncroachingOn(Other);
//}



//simulated function SetPawnRBChannels(bool bRagdollMode)
//{
//    if(bRagdollMode)
//    {
//        Mesh.SetRBChannel(RBCC_Pawn);
//        Mesh.SetRBCollidesWithChannel(RBCC_Default,TRUE);
//        Mesh.SetRBCollidesWithChannel(RBCC_Pawn,TRUE);
//        Mesh.SetRBCollidesWithChannel(RBCC_Vehicle,TRUE);
//        Mesh.SetRBCollidesWithChannel(RBCC_Untitled3,FALSE);
//    }
//    else
//    {
//        Mesh.SetRBChannel(RBCC_Untitled3);
//        Mesh.SetRBCollidesWithChannel(RBCC_Default,FALSE);
//        Mesh.SetRBCollidesWithChannel(RBCC_Pawn,FALSE);
//        Mesh.SetRBCollidesWithChannel(RBCC_Vehicle,FALSE);
//        Mesh.SetRBCollidesWithChannel(RBCC_Untitled3,FALSE); // don't let dinos get stuck on pawns
//    }
//}

simulated function WeaponFired( bool bViaReplication, optional vector HitLocation)
{
    Super.WeaponFired(bViaReplication,HitLocation);

    if( Physics != PHYS_Falling )
    {
        if( VSize(Velocity) > 100 )
        {
            if(TopHalfAnimSlot != None)
                TopHalfAnimSlot.PlayCustomAnim( 'attack01', 1.0, 0.05, 0.1, False, TRUE );
        }
        else
        {
            if( FRand() > 0.5 )
            {
                if(TopHalfAnimSlot != None)
                    TopHalfAnimSlot.PlayCustomAnim( 'attack01', 1.0, 0.05, 0.1, False, TRUE );
            }
            else
            {
                if(FullBodyAnimSlot != None)
                    FullBodyAnimSlot.PlayCustomAnim( 'attack02', 1.0, 0.05, 0.1, False, TRUE );
            }
        }
    }
    PlaySound(AttackSound);
}

function PlayIdleSound()
{
    if( FRand() < 0.1f && LastIdleSound < WorldInfo.TimeSeconds )
    {
        LastIdleSound = WorldInfo.TimeSeconds + 1.0 + Frand()*2.0;
        PlaySound(IdleSound);
    }
}

/** Enable or disable IK that keeps hands on IK bones. */
simulated function SetHandIKEnabled(bool bEnabled)
{
}



function PlayChallengeSound()
{
    if( LastChallengeSound < WorldInfo.TimeSeconds )
    {
        LastChallengeSound = WorldInfo.TimeSeconds + 2.0 + Frand()*2.0;
        PlaySound(ChallengeSound);
    }
}


function bool HasRangedAttack()
{
    return false;
}





/**
 * This pawn has died.
 *
 * @param   Killer          Who killed this pawn
 * @param   DamageType      What killed it
 * @param   HitLocation     Where did the hit occur
 *
 * @returns true if allowed
 */
function bool Died(Controller Killer, class<DamageType> damageType, vector HitLocation)
{
    local SeqAct_Latent Action;
    local Controller KilledController;

    // allow the current killer to override with a different one for kill credit
    if ( Killer != None )
    {
        Killer = Killer.GetKillerController();
    }
    // ensure a valid damagetype
    if ( damageType == None )
    {
        damageType = class'DamageType';
    }
    // if already destroyed or level transition is occuring then ignore
    if ( bDeleteMe || WorldInfo.Game == None || WorldInfo.Game.bLevelChange )
    {
        return FALSE;
    }
    // if this is an environmental death then refer to the previous killer so that they receive credit (knocked into lava pits, etc)
    if ( DamageType.default.bCausedByWorld && (Killer == None || Killer == Controller) && LastHitBy != None )
    {
        Killer = LastHitBy;
    }
    // gameinfo hook to prevent deaths
    // WARNING - don't prevent bot suicides - they suicide when really needed
    if ( WorldInfo.Game.PreventDeath(self, Killer, damageType, HitLocation) )
    {
        Health = max(Health, 1);
        return false;
    }
    Health = Min(0, Health);
    // activate death events
    TriggerEventClass( class'SeqEvent_Death', self );
    // and abort any latent actions
    foreach LatentActions(Action)
    {
        Action.AbortFor(self);
    }
    LatentActions.Length = 0;
    // notify the vehicle we are currently driving
    if ( DrivenVehicle != None )
    {
        Velocity = DrivenVehicle.Velocity;
        DrivenVehicle.DriverDied();
    }
    else if ( Weapon != None )
    {
        Weapon.HolderDied();
        ThrowActiveWeapon();
    }

    // JR: DO NOT call WorldInfo.Game.Killed(), but call relevant functions manually
    // awarding points for dinos breaks scoring.

    KilledController = Controller != None ? Controller : Controller(Owner);

    if( UTBot(KilledController) != None )
        UTBot(KilledController).WasKilledBy(Killer);

    if( WorldInfo.Game.GameRulesModifiers != None )
        WorldInfo.Game.GameRulesModifiers.ScoreKill(Killer, KilledController);

    WorldInfo.Game.DiscardInventory(self, Killer);
    WorldInfo.Game.NotifyKilled(Killer, KilledController, self);


    DrivenVehicle = None;
    // notify inventory manager
    if ( InvManager != None )
    {
        InvManager.OwnerEvent('died');
        // and destroy
        InvManager.Destroy();
        InvManager = None;
    }
    // push the corpse upward (@fixme - somebody please remove this?)
    Velocity.Z *= 1.3;
    // if this is a human player then force a replication update
    if ( IsHumanControlled() )
    {
        PlayerController(Controller).ForceDeathUpdate();
    }
    NetUpdateFrequency = Default.NetUpdateFrequency;
    PlayDying(DamageType, HitLocation);
    return TRUE;
}




/** called when bPlayingFeignDeathRecovery and interpolating our Mesh's PhysicsWeight to 0 has completed
 *	starts the recovery anim playing
 */
simulated event StartFeignDeathRecoveryAnim()
{
	local UTWeapon UTWeap;
	
	//`log( "StartFeignDeathRecoveryAnim" );

	// we're done with the ragdoll, so get rid of it
	RestorePreRagdollCollisionComponent();
	Mesh.PhysicsWeight = 0.f;
	Mesh.MinDistFactorForKinematicUpdate = default.Mesh.MinDistFactorForKinematicUpdate;
	Mesh.PhysicsAssetInstance.SetAllBodiesFixed(TRUE);
	Mesh.PhysicsAssetInstance.SetFullAnimWeightBonesFixed(FALSE, Mesh);
	SetPawnRBChannels(FALSE);
	Mesh.bUpdateKinematicBonesFromAnimation=TRUE;
	Mesh.SetTranslation(Mesh.default.Translation);

	// Turn collision on for cylinder and off for skelmeshcomp
	CylinderComponent.SetActorCollision(true, true);
	if( CylinderComponentAlt != None )
	{
        CylinderComponentAlt.SetActorCollision(true, true);
	}
	Mesh.SetActorCollision(false, false);
	Mesh.SetTraceBlocking(false, false);

	Mesh.SetTickGroup(TG_PreAsyncWork);

	if (Physics == PHYS_RigidBody)
	{
		setPhysics(PHYS_Falling);
	}

	UTWeap = UTWeapon(Weapon);
	if (UTWeap != None)
	{
		UTWeap.PlayWeaponEquip();
	}

	if (FeignDeathBlend != None && FeignDeathBlend.Children[1].Anim != None)
	{
		FeignDeathBlend.Children[1].Anim.PlayAnim(false, 20.0);
	}
	else
	{
		// failed to find recovery node, so just pop out of ragdoll
		//`log( "StartFeignDeathRecoveryAnim pop out" );
		bNoWeaponFiring = default.bNoWeaponFiring;
		GotoState('Auto');
	}
}

simulated function PlayFeignDeath()
{
	local vector FeignLocation, HitLocation, HitNormal, TraceEnd, Impulse;
	local UTWeapon UTWeap;
	local UTVehicle V;
	local Controller Killer;
	local float UnFeignZAdjust;
	//local rotator NewRotation;

	//`log( "PlayFeignDeath" @bFeigningDeath @FeignDeathBlend @bIsCrouched );
	
	if (bFeigningDeath)
	{
		StartFallImpactTime = WorldInfo.TimeSeconds;
		bCanPlayFallingImpacts=true;
		GotoState('FeigningDeath');

		// if we had some other rigid body thing going on, cancel it
		if (Physics == PHYS_RigidBody)
		{
			//@note: Falling instead of None so Velocity/Acceleration don't get cleared
			setPhysics(PHYS_Falling);
		}

		// Ensure we are always updating kinematic
		Mesh.MinDistFactorForKinematicUpdate = 0.0;

		SetPawnRBChannels(TRUE);
		Mesh.ForceSkelUpdate();

		// Move into post so that we are hitting physics from last frame, rather than animated from this
		Mesh.SetTickGroup(TG_PostAsyncWork);

		bBlendOutTakeHitPhysics = false;

		PreRagdollCollisionComponent = CollisionComponent;
		CollisionComponent = Mesh;

		// Turn collision on for skelmeshcomp and off for cylinder
		CylinderComponent.SetActorCollision(false, false);
    	if( CylinderComponentAlt != None )
    	{
            CylinderComponentAlt.SetActorCollision(false, false);
    	}
		Mesh.SetActorCollision(true, true);
		Mesh.SetTraceBlocking(true, true);

		SetPhysics(PHYS_RigidBody);
		Mesh.PhysicsWeight = 1.0;

		// If we had stopped updating kinematic bodies on this character due to distance from camera, force an update of bones now.
		if( Mesh.bNotUpdatingKinematicDueToDistance )
		{
			Mesh.UpdateRBBonesFromSpaceBases(TRUE, TRUE);
		}

		Mesh.PhysicsAssetInstance.SetAllBodiesFixed(FALSE);
		Mesh.bUpdateKinematicBonesFromAnimation=FALSE;

		FeignDeathStartTime = WorldInfo.TimeSeconds;
		// reset mesh translation since adjustment code isn't executed on the server
		// but the ragdoll code uses the translation so we need them to match up for the
		// most accurate simulation
		//`log("tr" @Mesh.Translation @BaseTranslationOffset );
		//Mesh.SetTranslation(vect(0,0,1) * BaseTranslationOffset); // JR:  no vertical offset, no overriding horizontal translation
		Mesh.SetTranslation(Mesh.default.Translation + vect(0,0,1)*CylinderComponent.CollisionHeight);
		// we'll use the rigid body collision to check for falling damage
		Mesh.ScriptRigidBodyCollisionThreshold = MaxFallSpeed;
		Mesh.SetNotifyRigidBodyCollision(true);
		Mesh.WakeRigidBody();

		if (Role == ROLE_Authority)
		{
			SetTimer(0.15, true, 'FeignDeathDelayTimer');
		}
	}
	else
	{
		// fit cylinder collision into location, crouching if necessary
		FeignLocation = Location;
		CollisionComponent = PreRagdollCollisionComponent;
		TraceEnd = Location + vect(0,0,1) * GetCollisionHeight();
		if (Trace(HitLocation, HitNormal, TraceEnd, Location, true, GetCollisionExtent()) == None )
		{
			HitLocation = TraceEnd;
		}
		if ( !SetFeignEndLocation(HitLocation, FeignLocation) )
		{
			CollisionComponent = Mesh;
			SetLocation(FeignLocation);
			bFeigningDeath = true;
			Impulse = VRand();
			Impulse.Z = 0.5;
			Mesh.AddImpulse(800.0*Impulse, Location);
			UnfeignFailedCount++;
			if ( UnFeignfailedCount > 4 )
			{
				Suicide();
			}
			return;
		}

		// Calculate how far we just moved the actor up.
		UnFeignZAdjust = Location.Z - FeignLocation.Z;
		// If its positive, move back down by that amount until it hits the floor
		if(UnFeignZAdjust > 0.0)
		{
			moveSmooth(vect(0,0,-1) * UnFeignZAdjust);
		}

		UnfeignFailedCount = 0;

		CollisionComponent = Mesh;

		bPlayingFeignDeathRecovery = true;
		FeignDeathRecoveryStartTime = WorldInfo.TimeSeconds;

		// don't need collision events anymore
		Mesh.SetNotifyRigidBodyCollision(false);
		// don't allow player to move while animation is in progress
		SetPhysics(PHYS_None);

		if (Role == ROLE_Authority)
		{
			// if cylinder is penetrating a vehicle, kill the pawn to prevent exploits
			CollisionComponent = PreRagdollCollisionComponent;
			foreach CollidingActors(class'UTVehicle', V, GetCollisionRadius(),, true)
			{
				if (IsOverlapping(V))
				{
					if (V.Class == HoverboardClass)
					{
						// don't want to kill pawn in this case, so push vehicle away instead
						Impulse = VRand() * V.GroundSpeed;
						Impulse.Z = 500.0;
						V.Mesh.AddImpulse(Impulse,,, true);
					}
					else
					{
						CollisionComponent = Mesh;
						if (V.Controller != None)
						{
							Killer = V.Controller;
						}
						else if (V.Instigator != None)
						{
							Killer = V.Instigator.Controller;
						}
						Died(Killer, V.RanOverDamageType, Location);
						return;
					}
				}
			}
			CollisionComponent = Mesh;
		}

		// find getup animation, and freeze it at the first frame
		if ( (FeignDeathBlend != None) && !bIsCrouched )
		{
			//`log("FeignDeathBlend");
			// physics weight interpolated to 0 in C++, then StartFeignDeathRecoveryAnim() is called
			Mesh.PhysicsWeight = 1.0;
			FeignDeathBlend.SetBlendTarget(1.0, 0.0);
//			// force rotation to match the body's direction so the blend to the getup animation looks more natural
//			NewRotation = Rotation;
//			NewRotation.Yaw = rotator(Mesh.GetBoneAxis('b_Hips', AXIS_X)).Yaw;
//			// flip it around if the head is facing upwards, since the animation for that makes the character
//			// end up facing in the opposite direction that its body is pointing on the ground
//			// FIXME: generalize this somehow (stick it in the AnimNode, I guess...)
//			if (Mesh.GetBoneAxis(HeadBone, AXIS_Y).Z < 0.0)
//			{
//				NewRotation.Yaw += 32768;
//			}
//			SetRotation(NewRotation);
		}
		else
		{
			// failed to find recovery node, so just pop out of ragdoll
			//`log("pop out of ragdoll");
			RestorePreRagdollCollisionComponent();
			Mesh.PhysicsWeight = 0.f;
			Mesh.PhysicsAssetInstance.SetAllBodiesFixed(TRUE);
			Mesh.bUpdateKinematicBonesFromAnimation=TRUE;
			Mesh.MinDistFactorForKinematicUpdate = default.Mesh.MinDistFactorForKinematicUpdate;
			SetPawnRBChannels(FALSE);

			if (Physics == PHYS_RigidBody)
			{
				setPhysics(PHYS_Falling);
			}

			UTWeap = UTWeapon(Weapon);
			if (UTWeap != None)
			{
				UTWeap.PlayWeaponEquip();
			}
			GotoState('Auto');
			
			// JR: HACK!
			StartFeignDeathRecoveryAnim();
		}
	}
}


state FeigningDeath
{
	ignores ServerHoverboard, SwitchWeapon, QuickPick, FaceRotation, ForceRagdoll, AdjustCameraScale, SetMovementPhysics;
	
	simulated event BeginState(name PreviousStateName)
	{
		//`log("BeginState" @PreviousStateName);
		Super.BeginState(PreviousStateName);
		
    	LeftLegControl2.SetSkelControlActive(False);
    	RightLegControl2.SetSkelControlActive(False);
	}
	
	simulated function EndState(name NextStateName)
	{
		//`log("EndState" @NextStateName);
		Super.EndState(NextStateName);
    	LeftLegControl2.SetSkelControlActive(True);
    	RightLegControl2.SetSkelControlActive(True);
	}

	simulated event OnAnimEnd(AnimNodeSequence SeqNode, float PlayedTime, float ExcessTime)
	{
		if (Physics != PHYS_RigidBody && !bPlayingFeignDeathRecovery)
		{
			// blend out of feign death animation
			if (FeignDeathBlend != None)
			{
				FeignDeathBlend.SetBlendTarget(0.0, 0.1);
			}
			GotoState('Auto');
		}
	}
}


final simulated function OverlapCheck()
{
	local GamePawn P;
	
	// attack player pawns in front and do not let go
    foreach OverlappingActors(class'GamePawn', P, CylinderComponent.CollisionRadius*2, Location + vector(rotation)*CylinderComponent.CollisionRadius)
    {
        if( JRDino(P) != None || P.Health <= 0 || P.Physics == PHYS_RigidBody )
            continue;
            
        // reduce all player velocity except for downward
    	if( bGrabPlayer )
    	{
            P.Velocity *= vect(0.1,0.1,1);
            if( P.Velocity.Z > 0 )
                P.Velocity.Z *= 0.1;
        }
            
        if( Controller != None && Weapon != None &&  !Weapon.IsFiring() )
        {
            JRDinoController(Controller).FireWeaponAt(P);
        }
    }
}

//
// TODO : OPTIMIZE!!!
//
final simulated function AdjustCheck()
{
    local Actor A;
    local vector HL,HN,Extent;
	local float  Dist;
	local int Flags;
	local TraceHitInfo HitInfo;
	
	Flags = TRACEFLAG_Blocking;
	
	//Extent = CylinderComponent.CollisionRadius * vect(1,1,0);
	//Extent.Z = CylinderComponent.CollisionHeight;
    
    // Move dino's ass out of obstacles immediately
    // TODO: sweep from old ass coords to prevent visible teleport caused by sideway movement or rotation into obstacle
    A = Trace(HL, HN, Location-vector(Rotation)*AdjustCheckDist, Location, true, Extent, HitInfo, Flags); // 65% of perf hit
    if( A != None )
    {
        Dist = AdjustCheckDist-VSize(HL-Location);
        if( MoveSmooth(vector(Rotation)*Dist) ) // 35% of perf hit
        {   
            //`log("adjusted" @A @Dist);
        }
        else
        {
            //`log("adjust failed" @A @Dist);
        }
                
        if( Controller != None )
        {
            // Notify AI that movement failed
            Controller.MoveTimer = -1;
        }

        // Collision notifications
        if( A.bWorldGeometry )
        {
            // HitWall
            if( Controller == None || !Controller.NotifyHitWall(HN*vect(1,1,0), A) )
            {
                HitWall(HN, A, HitInfo.HitComponent );
            }
        }
        else if( !IsBasedOn(A) )
        {
            // Bump
            if( Pawn(A) == None || Pawn(A).Controller == None || !Pawn(A).Controller.NotifyBump(self, HN) )
            {
                A.Bump(self, CollisionComponent, HN);
            }
            
            if( Controller == None || !Controller.NotifyBump(A, HN) )
            {
                Bump(A, HitInfo.HitComponent, HN);
            }
        }
    }
}

simulated event Tick(float DeltaTime)
{
	local float MaxSpeed;
	local vector LocalVelocity;
	
	// skip if ragdolled
	if( Health <= 0 || Physics == PHYS_RigidBody )
	   return;
	
	if( Role == ROLE_Authority && Controller != None )
	{
	   RepEnemy = Controller.Enemy;
	}
	
	if( RepEnemy != None && VSize(RepEnemy.Location-Location) < 512 )
	{
	   OverlapCheck();
	}
	
	
	if( bAdjustDino )
	{
        AdjustCheck();
    }
    
    // reduce strafe and backwards velocity
    if( Physics == PHYS_Walking )
    {
        // Get velocity in local space
        LocalVelocity = Velocity << Rotation;
        
        // Apply limit
        MaxSpeed = GroundSpeed * 0.4f;
        LocalVelocity.X = FClamp(LocalVelocity.X, -MaxSpeed, VSize(Velocity));
        LocalVelocity.Y = FClamp(LocalVelocity.Y, -MaxSpeed, MaxSpeed);
        //`log("LocalVelocity" @LocalVelocity);
        
        // Update velocity
        Velocity = LocalVelocity >> Rotation;
    }
}


simulated State Dying
{
ignores OnAnimEnd, Bump, HitWall, HeadVolumeChange, PhysicsVolumeChange, Falling, BreathTimer, StartFeignDeathRecoveryAnim, ForceRagdoll, FellOutOfWorld;

    simulated function BeginState(Name PreviousStateName)
    {
        Super.BeginState(PreviousStateName);
        
		Mesh.PhysicsAssetInstance.SetAllMotorsAngularPositionDrive(False,False);

        if( Role == ROLE_Authority )
        {
            SetTimer(1,false,'SelfDestruct');
        }
        
        if( CylinderComponentAlt != None )
        {
            CylinderComponentAlt.SetActorCollision(false, false);
        }
    }

    function SelfDestruct()
    {
        // todo
    }

	simulated event TakeDamage(int Damage, Controller InstigatedBy, vector HitLocation, vector Momentum, class<DamageType> DamageType, optional TraceHitInfo HitInfo, optional Actor DamageCauser)
	{
		local Vector shotDir, ApplyImpulse,BloodMomentum;
		local class<UTDamageType> UTDamage;
		local UTEmit_HitEffect HitEffect;
		local ParticleSystem BloodTemplate;

		if ( class'GameInfo'.Static.UseLowGore(WorldInfo) )
		{
			if ( !bGibbed )
			{
				UTDamage = class<UTDamageType>(DamageType);
				if (UTDamage != None && ShouldGib(UTDamage))
				{
					bTearOffGibs = true;
					bGibbed = true;
				}
			}
			return;
		}

		// When playing death anim, we keep track of how long since we took that kind of damage.
		if(DeathAnimDamageType != None)
		{
			if(DamageType == DeathAnimDamageType)
			{
				TimeLastTookDeathAnimDamage = WorldInfo.TimeSeconds;
			}
		}

		if (!bGibbed && (InstigatedBy != None || EffectIsRelevant(Location, true, 0)))
		{
			UTDamage = class<UTDamageType>(DamageType);

			// accumulate damage taken in a single tick
			if ( AccumulationTime != WorldInfo.TimeSeconds )
			{
				AccumulateDamage = 0;
				AccumulationTime = WorldInfo.TimeSeconds;
			}
			AccumulateDamage += Damage;

			Health -= Damage;
			if (UTDamage != None && ShouldGib(UTDamage))
			{
				if ( bHideOnListenServer || (WorldInfo.NetMode == NM_DedicatedServer) )
				{
					bTearOffGibs = true;
					bGibbed = true;
					return;
				}
				SpawnGibs(UTDamage, HitLocation);
			}
			else if ( !bHideOnListenServer && (WorldInfo.NetMode != NM_DedicatedServer) )
			{
				CheckHitInfo( HitInfo, Mesh, Normal(Momentum), HitLocation );
				if ( UTDamage != None )
				{
					UTDamage.Static.SpawnHitEffect(self, Damage, Momentum, HitInfo.BoneName, HitLocation);
				}
				
				if ( !class'GameInfo'.Static.UseLowGore(WorldInfo) )
				{				
					if (!IsZero(Momentum) )
					{
						LeaveABloodSplatterDecal( HitLocation, Momentum );
					}

    				BloodTemplate = class'UTEmitter'.static.GetTemplateForDistance(GetFamilyInfo().default.BloodEffects, HitLocation, WorldInfo);
    				if (BloodTemplate != None)
    				{
    					BloodMomentum = Normal(-1.0 * Momentum) + (0.5 * VRand());
    					if( BloodMomentum.Z > 0 )
    						BloodMomentum.Z *= 0.5;
    					HitEffect = Spawn(GetFamilyInfo().default.BloodEmitterClass, self,, HitLocation, rotator(BloodMomentum));
    					HitEffect.SetTemplate(BloodTemplate, true);
    					HitEffect.AttachTo(self, HitInfo.BoneName);
    					HitEffect.SetDrawScale(BloodDrawScale);
    				}
				}

				if ( (UTDamage != None) && (UTDamage.default.DamageOverlayTime > 0) && (UTDamage.default.DamageBodyMatColor != class'UTDamageType'.default.DamageBodyMatColor) )
				{
					SetBodyMatColor(UTDamage.default.DamageBodyMatColor, UTDamage.default.DamageOverlayTime);
				}

				if( (Physics != PHYS_RigidBody) || (Momentum == vect(0,0,0)) || (HitInfo.BoneName == '') )
					return;

				shotDir = Normal(Momentum);
				ApplyImpulse = (DamageType.Default.KDamageImpulse * shotDir);

				if( (UTDamage != None) && UTDamage.Default.bThrowRagdoll && (Velocity.Z > -10) )
				{
					ApplyImpulse += Vect(0,0,1)*DamageType.default.KDeathUpKick;
				}
				// AddImpulse() will only wake up the body for the bone we hit, so force the others to wake up
				Mesh.WakeRigidBody();
				Mesh.AddImpulse(ApplyImpulse, HitLocation, HitInfo.BoneName, true);
			}
		}
	}
}

/**
 * This will trace against the world and leave a blood splatter decal.
 *
 * This is used for having a back spray / exit wound blood effect on the wall behind us.
 **/
simulated function LeaveABloodSplatterDecal( vector HitLoc, vector HitNorm )
{
	local Actor TraceActor;
	local vector out_HitLocation;
	local vector out_HitNormal;
	local vector TraceDest;
	local vector TraceStart;
	local vector TraceExtent;
	local TraceHitInfo HitInfo;
	local MaterialInstanceTimeVarying MITV_Decal;

	TraceStart = HitLoc;
	//HitNorm.Z = 0; // todo: make accurate
	TraceDest =  HitLoc  + ( HitNorm * 105 );

	TraceActor = Trace( out_HitLocation, out_HitNormal, TraceDest, TraceStart, false, TraceExtent, HitInfo, TRACEFLAG_PhysicsVolumes );

	if (TraceActor != None && Pawn(TraceActor) == None)
	{
		// we might want to move this to the UTFamilyInfo
		MITV_Decal = new(Outer) class'MaterialInstanceTimeVarying';
		MITV_Decal.SetParent( GetFamilyInfo().default.BloodSplatterDecalMaterial );

		WorldInfo.MyDecalManager.SpawnDecal(MITV_Decal, out_HitLocation, rotator(-out_HitNormal), 100, 100, 50, false,, HitInfo.HitComponent, true, false, HitInfo.BoneName, HitInfo.Item, HitInfo.LevelIndex);

		MITV_Decal.SetScalarStartTime( class'UTGib'.default.DecalDissolveParamName, class'UTGib'.default.DecalWaitTimeBeforeDissolve );
	}
}

/** plays clientside hit effects using the data in LastTakeHitInfo */
simulated function PlayTakeHitEffects()
{
	local vector BloodMomentum;
	local UTEmit_HitEffect HitEffect;
	local ParticleSystem BloodTemplate;
	local class<UTDamageType> UTDamage;

	// set if you want to be able to test in a level and not be tossed around nor have damage effects on screen making it impossible to see what is going on
	if( !AffectedByHitEffects() )
	{
		return;
	}

	if (EffectIsRelevant(Location, false))
	{
		if (!IsZero(LastTakeHitInfo.Momentum) && !class'GameInfo'.Static.UseLowGore(WorldInfo) )
		{
			LeaveABloodSplatterDecal( LastTakeHitInfo.HitLocation, LastTakeHitInfo.Momentum );
		}

		if (!IsFirstPerson() || class'Engine'.static.IsSplitScreen() )
		{
			if ( !class'GameInfo'.Static.UseLowGore(WorldInfo) )
			{
				BloodTemplate = class'UTEmitter'.static.GetTemplateForDistance(GetFamilyInfo().default.BloodEffects, LastTakeHitInfo.HitLocation, WorldInfo);
				if (BloodTemplate != None)
				{
					BloodMomentum = Normal(-1.0 * LastTakeHitInfo.Momentum) + (0.5 * VRand());
					HitEffect = Spawn(GetFamilyInfo().default.BloodEmitterClass, self,, LastTakeHitInfo.HitLocation, rotator(BloodMomentum));
					HitEffect.SetTemplate(BloodTemplate, true);
					HitEffect.AttachTo(self, LastTakeHitInfo.HitBone);
    				HitEffect.SetDrawScale(BloodDrawScale);
				}
			}

			if ( !Mesh.bNotUpdatingKinematicDueToDistance )
			{				
				// physics based takehit animations
				if(!class'Engine'.static.IsSplitScreen() 
				&&  Health > 0 
				&&  DrivenVehicle == None && Physics != PHYS_RigidBody 
				&&  Mesh.PhysicsWeight <= PhysicsHitBaseWeight * 0.9 )	
				{
					PlayPhysicsTakeHit();	
				}			
				
				UTDamage = class<UTDamageType>(LastTakeHitInfo.DamageType);
				if (UTDamage != None)
				{		
					UTDamage.static.SpawnHitEffect(self, LastTakeHitInfo.Damage, LastTakeHitInfo.Momentum, LastTakeHitInfo.HitBone, LastTakeHitInfo.HitLocation);
				}
			}
		}
	}
}

simulated function PlayPhysicsTakeHit()
{
	local TakeHitInfo PhysicsHitInfo;
	local float ImpulseStrength;
				
	PhysicsHitInfo = LastTakeHitInfo;
	//`log("PlayPhysicsTakeHit" @VSize(PhysicsHitInfo.Momentum) @rotator(PhysicsHitInfo.Momentum) @PhysicsHitInfo.HitBone @VSize(PhysicsHitInfo.HitLocation-Location));
	
	
	if( IsZero(PhysicsHitInfo.Momentum) )
	{
		PhysicsHitInfo.Momentum = VRand() * 10.0f;
	}
	
	if( IsZero(PhysicsHitInfo.HitLocation) )
	{
		PhysicsHitInfo.HitLocation = Location;
	}
	
	if( PhysicsHitInfo.HitBone == '' )
	{
		//PhysicsHitInfo.HitBone = Mesh.FindClosestBone(PhysicsHitInfo.HitLocation, PhysicsHitInfo.HitLocation, 4);
	}
	
//	if( Mesh.PhysicsWeight > 0 )
//	{
//		Mesh.UpdateRBBonesFromSpaceBases(True,True);
//	}
	
	Mesh.PhysicsWeight = PhysicsHitBaseWeight;
	Mesh.PhysicsAssetInstance.SetNamedBodiesFixed(true, TakeHitPhysicsFixedBones, Mesh, true);
	Mesh.PhysicsAssetInstance.SetAllMotorsAngularPositionDrive(true,true);
	//Mesh.PhysicsAssetInstance.SetAngularDriveScale(PhysicsHitDriveScale, PhysicsHitDriveScale, PhysicsHitDriveScale);
	

//	`log("PlayPhysicsTakeHit2" @VSize(PhysicsHitInfo.Momentum) @rotator(PhysicsHitInfo.Momentum) @PhysicsHitInfo.HitBone @VSize(PhysicsHitInfo.HitLocation-Location));
//	if( PhysicsHitInfo.HitBone != '' )
//	{
//		Mesh.AddImpulse(Normal(PhysicsHitInfo.Momentum)*250,, PhysicsHitInfo.HitBone);
//	}
//	else
//	{
		ImpulseStrength = PhysicsHitStrength + FClamp(PhysicsHitInfo.Damage, 0, 100) * PhysicsHitDmgMult;
		Mesh.AddRadialImpulse(PhysicsHitInfo.HitLocation, CylinderComponent.CollisionRadius*PhysicsHitDistMult, ImpulseStrength, PhysicsHitFalloff, true);
//	}
	
	bBlendOutTakeHitPhysics = true;
}


/** called when bBlendOutTakeHitPhysics is true and our Mesh's PhysicsWeight has reached 0.0 */
simulated event TakeHitBlendedOut()
{
	Mesh.PhysicsWeight = 0.0;
	Mesh.PhysicsAssetInstance.SetAllBodiesFixed(TRUE);
	Mesh.PhysicsAssetInstance.SetAllMotorsAngularPositionDrive(False,False);
}

simulated function SetBodyMatColor(LinearColor NewBodyMatColor, float NewOverlayDuration)
{
	if( !bDinoBodyMat )
		return;
		
	Super.SetBodyMatColor(NewBodyMatColor, NewOverlayDuration);
}

event TakeDamage(int Damage, Controller EventInstigator, vector HitLocation, vector Momentum, class<DamageType> DamageType, optional TraceHitInfo HitInfo, optional Actor DamageCauser)
{
    // Reduce vehicle crush damage
    if( class<UTDamageType>(DamageType) != None && class<UTDamageType>(DamageType).default.bVehicleHit )
    {
        // Ragdoll
        if( RagdollDamage != 0 && Damage > RagdollDamage )
        {
            ForceRagdoll();
        }
    
        Damage = Clamp(Damage*VehicleHitMult,VehicleHitMinDmg,VehicleHitMaxDmg);
        
        // Reduce vehicle speed
        if( EventInstigator != None && SVehicle(EventInstigator.Pawn) != None )
            StopPushingVehicle(SVehicle(EventInstigator.Pawn));
    }
    
	Super.TakeDamage(Damage, EventInstigator, HitLocation, Momentum, DamageType, HitInfo, DamageCauser);
}

simulated function StopPushingVehicle(SVehicle V)
{
	local RB_BodyInstance Body;
	local vector WorldLinVel;
	
	if( V.Physics != PHYS_RigidBody )
	   return;
	   	
	Body = V.CollisionComponent.GetRootBodyInstance();
	WorldLinVel = Body.GetUnrealWorldVelocity();
	
	V.CollisionComponent.AddImpulse(-WorldLinVel*VehicleStopAmount,,,False);
}


static function ResetUIConfig(class<JRDino> DinoClass)
{
    DinoClass.default.DinoSpeed = DinoClass.default.DinoSpeedRange.Optimal;
    DinoClass.default.DinoHealth = DinoClass.default.DinoHealthRange.Optimal;
    DinoClass.default.DinoSkill = DinoClass.default.DinoSkillRange.Optimal;
    DinoClass.default.DinoDamage = DinoClass.default.DinoDamageRange.Optimal;
    DinoClass.static.StaticSaveConfig();
}

static function VerifyUIConfig(class<JRDino> DinoClass)
{
    if( DinoClass.default.DinoSpeed < DinoClass.default.DinoSpeedRange.Min )        DinoClass.default.DinoSpeed = DinoClass.default.DinoSpeedRange.Optimal;
    if( DinoClass.default.DinoHealth < DinoClass.default.DinoHealthRange.Min )      DinoClass.default.DinoHealth = DinoClass.default.DinoHealthRange.Optimal;
    if( DinoClass.default.DinoSkill < DinoClass.default.DinoSkillRange.Min )        DinoClass.default.DinoSkill = DinoClass.default.DinoSkillRange.Optimal;
    if( DinoClass.default.DinoDamage < DinoClass.default.DinoDamageRange.Min )      DinoClass.default.DinoDamage = DinoClass.default.DinoDamageRange.Optimal;
    DinoClass.static.StaticSaveConfig();
}

DefaultProperties
{
    //bTestDino=True
	bDinoBodyMat=True

    VehicleStopAmount=0.1
    bCanClimbLadders=False
    bCanUse=False
    bWeaponAttachmentVisible=False
    bCanPickupInventory=False
    bCanSwim=True
    bCanStrafe=False
    RotationRate=(Pitch=32768,Yaw=32768,Roll=32768)
    
    CrouchTranslationOffset=0
	CrouchMeshZOffset=0    
    
    PhysicsHitStrength=2000
    PhysicsHitDistMult=2
    PhysicsHitDmgMult=1
    PhysicsHitFalloff=RIF_Constant
    PhysicsHitDriveScale=1
	PhysicsHitBaseWeight=1.0
    TakeHitPhysicsBlendOutSpeed=1.0
	FeignDeathPhysicsBlendOutSpeed=2

    DinoSpeed=540
    DinoHealth=70
    DinoSkill=4
    DinoDamage=15

    GroundSpeed=540
    AirSpeed=540
    JumpZ=640
    DefaultAirControl=0.1
    AirControl=0.1

    Mass=75
    AdjustCheckDist=96
    
    RagdollDamage=0
    VehicleHitMult=0.1
    VehicleHitMinDmg=1
    VehicleHitMaxDmg=100
    
    BloodDrawScale=1.0
    
    bEnableFootPlacement=False


    DinoWeapon = class'JRWeap_Dino'
    ControllerClass=class'JRDinoController'
    DefaultFamily=class'JRFamilyInfo_Dino'

    IdleSound=SoundCue'JR_RaptorSounds.IdleCue'
    ChallengeSound=SoundCue'JR_RaptorSounds.KillsTauntsCue'
    AttackSound=SoundCue'JR_RaptorSounds.MeleeMotionCue'

    Begin Object Name=MyLightEnvironment
        ModShadowFadeoutTime=1.0
        AmbientGlow=(R=0.0,G=0.0,B=0.0,A=0.0)
        AmbientShadowColor=(R=0.0,G=0.0,B=0.0)
    End Object

    Begin Object Name=WPawnSkeletalMeshComponent
        Translation=(X=0.0,Y=0.0,Z=0.0)
        Scale3D=(X=1.0,Y=1.0,Z=1.0)
        Scale=1.0
        LightEnvironment=MyLightEnvironment
    End Object
    
}