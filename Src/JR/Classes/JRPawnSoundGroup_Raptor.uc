//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRPawnSoundGroup_Raptor extends JRPawnSoundGroup_Dino;

DefaultProperties
{
   DodgeSound=SoundCue'JR_RaptorSounds.JumpCue'
   DoubleJumpSound=SoundCue'JR_RaptorSounds.JumpCue'
   LandSound=SoundCue'A_Character_Footsteps.FootSteps.A_Character_Footstep_DefaultCue'
   FallingDamageLandSound=SoundCue'A_Character_Footsteps.FootSteps.A_Character_Footstep_FleshLandCue'
   DyingSound=SoundCue'JR_RaptorSounds.DieInstantCue'
   HitSounds(0)=SoundCue'JR_RaptorSounds.HitHardCue'
   HitSounds(1)=SoundCue'JR_RaptorSounds.HitHardCue'
   HitSounds(2)=SoundCue'JR_RaptorSounds.HitHardCue'
   GibSound=SoundCue'JR_RaptorSounds.DieInstantCue'
   DrownSound=SoundCue'JR_RaptorSounds.DieInstantCue'
   GaspSound=SoundCue'JR_RaptorSounds.HitHardCue'

}