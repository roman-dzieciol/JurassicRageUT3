//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRRaptor extends JRDino;




function AddVelocity( vector NewVelocity, vector HitLocation, class<DamageType> DamageType, optional TraceHitInfo HitInfo )
{
    Super.AddVelocity(NewVelocity, HitLocation, DamageType, HitInfo);

    if (!bIgnoreForces && !IsZero(NewVelocity))
    {
        // stronger hits may ragdoll
        if (VSize(NewVelocity) > 400 && FRand() > 0.33 )
        {
            ForceRagdoll();
        }
    }
}



simulated event PostInitAnimTree(SkeletalMeshComponent SkelComp)
{
    if (SkelComp == Mesh)
    {
        AirAttackBlend = AnimNodeBlend(Mesh.FindAnimNode('AirAttackBlend'));
    }

    Super.PostInitAnimTree(SkelComp);
}



event Landed(vector HitNormal, actor FloorActor)
{
    Super.Landed(HitNormal, FloorActor);

    if( AirAttackBlend != None )
        AirAttackBlend.SetBlendTarget(0, 0.1);
}


simulated function FixFootControl( SkelControlFootPlacement C )
{
    local float AdjustScale;
    
    C.SetSkelControlActive(True);
    C.SetSkelControlStrength(1,0);
    
    AdjustScale = 1.0f / Mesh.Scale; // Inverse!?
    C.FootOffset = C.FootOffset * AdjustScale;
    C.MaxUpAdjustment = C.MaxUpAdjustment * AdjustScale;
    C.MaxDownAdjustment = C.MaxDownAdjustment * AdjustScale;
    //`log(C.FootOffset);
}


DefaultProperties
{
    DinoSpeedRange=(Min=400,Optimal=540,Max=900)
    DinoHealthRange=(Min=30,Optimal=1000,Max=30)
    DinoSkillRange=(Min=0,Optimal=4,Max=7)
    DinoDamageRange=(Min=5,Optimal=10,Max=100)
    
    DinoSpeed=540
    DinoHealth=70
    DinoSkill=4
    DinoDamage=10
    
    RotationRate=(Pitch=65535,Yaw=65535,Roll=65535)

    GroundSpeed=540
    AirSpeed=540
    JumpZ=640
    DefaultAirControl=0.1
    AirControl=0.1
    
    bGrabPlayer=True
    bAdjustDino=True
    
    RagdollDamage=50
    VehicleHitMult=0.1
    VehicleHitMinDmg=1
    VehicleHitMaxDmg=100
    
    DinoWeapon=class'JRWeap_Raptor'
    ControllerClass=class'JRRaptorController'
    DefaultFamily=class'JRFamilyInfo_Raptor'

    Begin Object Name=WPawnSkeletalMeshComponent
        SkeletalMesh=SkeletalMesh'JR_Raptor.RaptorMesh'
        PhysicsAsset=PhysicsAsset'JR_Raptor.RaptorPhysics'
        AnimSets[0]=AnimSet'JR_Raptor.RaptorAnim'
        AnimTreeTemplate=AnimTree'JR_Raptor.RaptorAnimTree'
        Translation=(X=-50.0,Y=0.0,Z=0.0)
        Scale=0.66
        LightEnvironment=MyLightEnvironment
    End Object
    
	Begin Object Class=CylinderComponent Name=CollisionCylinderAlt
		CollisionRadius=21
		CollisionHeight=38
		BlockNonZeroExtent=true
		BlockZeroExtent=true
		BlockActors=true
		CollideActors=true
        Translation=(X=-42.0,Y=0.0,Z=0.0)
	End Object
    
	Begin Object Name=CollisionCylinder
		CollisionRadius=21
		CollisionHeight=38
		BlockNonZeroExtent=true
		BlockZeroExtent=true
		BlockActors=true
		CollideActors=true
        Translation=(X=0.0,Y=0.0,Z=0.0)
	End Object
	
	CylinderComponentAlt=CollisionCylinderAlt
	Components.Add(CollisionCylinderAlt)
}