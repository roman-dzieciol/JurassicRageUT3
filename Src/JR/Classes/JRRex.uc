//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRRex extends JRDino;



simulated function bool ShouldGib(class<UTDamageType> UTDamageType)
{
    // Do not gib
	return false;
}


simulated function WeaponFired( bool bViaReplication, optional vector HitLocation)
{
    Super(UTPawn).WeaponFired(bViaReplication,HitLocation);

    if(TopHalfAnimSlot != None)
        TopHalfAnimSlot.PlayCustomAnim( 'attack01', 1.0, 0.05, 0.1, False, TRUE );
        
    PlaySound(AttackSound);
}



function AddVelocity( vector NewVelocity, vector HitLocation, class<DamageType> DamageType, optional TraceHitInfo HitInfo )
{
    // Only allow vehicle crush velocity
    if( class<UTDamageType>(DamageType) != None && class<UTDamageType>(DamageType).default.bVehicleHit )
    {
    	Super.AddVelocity(NewVelocity, HitLocation, DamageType, HitInfo);
    }
}

DefaultProperties
{
    bAdjustDino=False

    IdleSound=SoundCue'JR_RexSounds.IdleCue'
    ChallengeSound=SoundCue'JR_RexSounds.ChallengeCue'
    AttackSound=SoundCue'JR_RexSounds.AttackCue'
    
    bCanJump=False
    
    Mass=500
    
    VehicleStopAmount=2.0
    VehicleHitMaxDmg=50
    
    DinoSpeedRange=(Min=400,Optimal=700,Max=1400)
    DinoHealthRange=(Min=300,Optimal=1000,Max=6000)
    DinoSkillRange=(Min=0,Optimal=7,Max=7)
    DinoDamageRange=(Min=30,Optimal=100,Max=600)
    
    DinoSpeed=700
    DinoHealth=1000
    DinoSkill=7
    DinoDamage=100
    
    HealthMax=6000
    
    RotationRate=(Pitch=8192,Yaw=8192,Roll=2048)

    BloodDrawScale=1.5
    
    GroundSpeed=700
    AirSpeed=700
    JumpZ=256
    DefaultAirControl=0.0
    AirControl=0.0
    
    PhysicsHitStrength=0
    PhysicsHitDmgMult=20
	PhysicsHitBaseWeight=0.5
    TakeHitPhysicsBlendOutSpeed=1.0

    DinoWeapon=class'JRWeap_Rex'
    ControllerClass=class'JRRexController'
    DefaultFamily=class'JRFamilyInfo_Rex'

    Begin Object Name=WPawnSkeletalMeshComponent
        SkeletalMesh=SkeletalMesh'JR_Rex.Rex'
        PhysicsAsset=PhysicsAsset'JR_Rex.Rex_Physics'
        AnimSets[0]=AnimSet'JR_Rex.Rex_Anims'
        AnimTreeTemplate=AnimTree'JR_Rex.RexAnimTree'
        Scale=1.5
        Translation=(X=-99,Y=0.0,Z=0.0)
    End Object
    
	Begin Object Name=CollisionCylinder
		CollisionRadius=99
		CollisionHeight=90
		BlockNonZeroExtent=true
		BlockZeroExtent=true
		BlockActors=true
		CollideActors=true
        Translation=(X=0.0,Y=0.0,Z=0.0)
	End Object
    
	Begin Object Class=CylinderComponent Name=CollisionCylinderAlt
		CollisionRadius=66
		CollisionHeight=90
		BlockNonZeroExtent=true
		BlockZeroExtent=true
		BlockActors=true
		CollideActors=true
        Translation=(X=-166.0,Y=0.0,Z=0.0)
	End Object
	
	CylinderComponentAlt=CollisionCylinderAlt
	Components.Add(CollisionCylinderAlt)
}
