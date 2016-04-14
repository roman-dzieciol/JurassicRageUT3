//-----------------------------------------------------------
//
//-----------------------------------------------------------
class JRUIFrontEnd_Dinos extends UTUIFrontEnd
    dependson(JRMutator_Dinos)
    abstract;


var transient UTUISlider DinoSpeed;
var transient UTUISlider DinoHealth;
var transient UTUISlider DinoSkill;
var transient UTUISlider DinoDamage;

var transient UTUISlider SpawnFrequency;
var transient UTUISlider SpawnForEachPlayer;
var transient UTUISlider SpawnForEachVehicle;
var transient UTUISlider SpawnLimit;

var class<JRDino> DinoClass;
var class<JRMutator_Dinos> MutatorClass;

var string SpawnForEachPlayerLabel[4];
var string SpawnForEachVehicleLabel[4];
var string SpawnFrequencyLabel[2];
var string SpawnLimitLabel;

event SceneActivated(bool bInitialActivation)
{
    Super.SceneActivated(bInitialActivation);

    if( bInitialActivation )
    {
        DinoSpeed = UTUISlider(FindChild('sliSpeed', true));
        DinoHealth = UTUISlider(FindChild('sliHealth', true));
        DinoSkill = UTUISlider(FindChild('sliSkill', true));
        DinoDamage = UTUISlider(FindChild('sliDamage', true));

        SpawnFrequency = UTUISlider(FindChild('sliFrequency', true));
        SpawnForEachPlayer = UTUISlider(FindChild('sliForEachPlayer', true));
        SpawnForEachVehicle = UTUISlider(FindChild('sliForEachVehicle', true));
        SpawnLimit = UTUISlider(FindChild('sliLimit', true));
    }

    InitWidgets();
}


function OnSliderChanged( UIObject Sender, int PlayerIndex )
{
    local array<UIObject> SliderChildren;
    local UILabel SliderLabel;
    local UTUISlider Slider;
    local int SliderValue;
    local string NewText;
    
    Slider = UTUISlider(Sender);
    if( Slider != None )
    {
        SliderChildren = Slider.GetChildren();
        SliderLabel = SliderChildren.Length > 0 ? UILabel(SliderChildren[0]) : None; 
        if( SliderLabel != None )
        {
            SliderValue = Slider.GetValue();
        
            switch(Sender)
            {
                case SpawnForEachPlayer:
                    if( Abs(SliderValue) == 1 )
                        NewText = SpawnForEachPlayerLabel[0];          
                    else if( SliderValue > 0 )
                        NewText = Repl( SpawnForEachPlayerLabel[1], "%n", int(Abs(SliderValue)) );
                    else if( SliderValue < 0 )
                        NewText = Repl( SpawnForEachPlayerLabel[2], "%n", int(Abs(SliderValue)) );
                    else
                        NewText = SpawnForEachPlayerLabel[3];                               
                    SliderLabel.SetValue( NewText );   
                    break;
                
                case SpawnForEachVehicle:
                    if( Abs(SliderValue) == 1 )
                        NewText = SpawnForEachVehicleLabel[0];          
                    else if( SliderValue > 0 )
                        NewText = Repl( SpawnForEachVehicleLabel[1], "%n", int(Abs(SliderValue)) );
                    else if( SliderValue < 0 )
                        NewText = Repl( SpawnForEachVehicleLabel[2], "%n", int(Abs(SliderValue)) );
                    else
                        NewText = SpawnForEachVehicleLabel[3];                               
                    SliderLabel.SetValue( NewText );   
                    break;
                
                case SpawnFrequency:
                    if( SliderValue > 0 )
                        NewText = Repl( SpawnFrequencyLabel[0], "%n", int(Abs(SliderValue)) );  
                    else
                        NewText = Repl( SpawnFrequencyLabel[1], "%n", int(Abs(SpawnLimit.GetValue())) );                             
                    SliderLabel.SetValue( NewText );   
                    break;
                
                case SpawnLimit:
                    NewText = Repl( SpawnLimitLabel, "%n", int(Abs(SpawnLimit.GetValue())) );                             
                    SliderLabel.SetValue( NewText );   
                    OnSliderChanged(SpawnFrequency, 0); // Update frequency as it depends on us
                    break;
            }
        }
    }
}

function InitWidgets()
{
    DinoClass.static.VerifyUIConfig(DinoClass);

    DinoSpeed.OnValueChanged = OnSliderChanged;
    DinoHealth.OnValueChanged = OnSliderChanged;
    DinoSkill.OnValueChanged = OnSliderChanged;
    DinoDamage.OnValueChanged = OnSliderChanged;
    
    SpawnForEachPlayer.OnValueChanged = OnSliderChanged;
    SpawnForEachVehicle.OnValueChanged = OnSliderChanged;
    SpawnFrequency.OnValueChanged = OnSliderChanged;
    SpawnLimit.OnValueChanged = OnSliderChanged;
    
    DinoSpeed.SetValue( DinoClass.default.DinoSpeed );
    DinoHealth.SetValue( DinoClass.default.DinoHealth );
    DinoSkill.SetValue( DinoClass.default.DinoSkill );
    DinoDamage.SetValue( DinoClass.default.DinoDamage );

    SpawnForEachPlayer.SetValue( MutatorClass.default.SpawnForEachPlayer );
    SpawnForEachVehicle.SetValue( MutatorClass.default.SpawnForEachVehicle );
    SpawnFrequency.SetValue( MutatorClass.default.SpawnFrequency );
    SpawnLimit.SetValue( MutatorClass.default.SpawnLimit );

    UpdateCaptions();
}

function UpdateCaptions()
{
    DinoSpeed.UpdateCaption();
    DinoHealth.UpdateCaption();
    DinoSkill.UpdateCaption();
    DinoDamage.UpdateCaption();

    SpawnForEachPlayer.UpdateCaption();
    SpawnForEachVehicle.UpdateCaption();
    SpawnFrequency.UpdateCaption();
    SpawnLimit.UpdateCaption();
    
    OnSliderChanged(DinoSpeed, 0);
    OnSliderChanged(DinoHealth, 0);
    OnSliderChanged(DinoSkill, 0);
    OnSliderChanged(DinoDamage, 0);
    
    OnSliderChanged(SpawnForEachPlayer, 0);
    OnSliderChanged(SpawnForEachVehicle, 0);
    OnSliderChanged(SpawnFrequency, 0);
    OnSliderChanged(SpawnLimit, 0);
}

/** Sets up the scene's button bar. */
function SetupButtonBar()
{
    ButtonBar.Clear();
    ButtonBar.AppendButton("<Strings:UTGameUI.ButtonCallouts.Accept>", OnButtonBar_Accept);
    ButtonBar.AppendButton("<Strings:UTGameUI.ButtonCallouts.Back>", OnButtonBar_Back);
    ButtonBar.AppendButton("<Strings:UTGameUI.ButtonCallouts.ResetToDefaults>", OnButtonBar_Reset);
}


function OnResetToDefaults()
{
    DinoClass.static.ResetUIConfig(DinoClass);
    MutatorClass.static.ResetUIConfig();

    InitWidgets();
}

/** Callback for when the user wants to back out of this screen. */
function OnBack()
{
    CloseScene(self);
}


/** Callback for when the user accepts the changes. */
function OnAccept()
{
    DinoClass.default.DinoSpeed = DinoSpeed.GetValue();
    DinoClass.default.DinoHealth = DinoHealth.GetValue();
    DinoClass.default.DinoSkill = DinoSkill.GetValue();
    DinoClass.default.DinoDamage = DinoDamage.GetValue();
    DinoClass.static.StaticSaveConfig();

    MutatorClass.default.SpawnForEachPlayer = SpawnForEachPlayer.GetValue();
    MutatorClass.default.SpawnForEachVehicle = SpawnForEachVehicle.GetValue();
    MutatorClass.default.SpawnFrequency = SpawnFrequency.GetValue();
    MutatorClass.default.SpawnLimit = SpawnLimit.GetValue();
    MutatorClass.static.StaticSaveConfig();

    CloseScene(self);
}

/** Buttonbar Callbacks. */
function bool OnButtonBar_Reset(UIScreenObject InButton, int InPlayerIndex)
{
    OnResetToDefaults();

    return true;
}

function bool OnButtonBar_Back(UIScreenObject InButton, int InPlayerIndex)
{
    OnBack();

    return true;
}

function bool OnButtonBar_Accept(UIScreenObject InButton, int InPlayerIndex)
{
    OnAccept();

    return true;
}



/**
 * Provides a hook for unrealscript to respond to input using actual input key names (i.e. Left, Tab, etc.)
 *
 * Called when an input key event is received which this widget responds to and is in the correct state to process.  The
 * keys and states widgets receive input for is managed through the UI editor's key binding dialog (F8).
 *
 * This delegate is called BEFORE kismet is given a chance to process the input.
 *
 * @param   EventParms  information about the input event.
 *
 * @return  TRUE to indicate that this input key was processed; no further processing will occur on this input key event.
 */
function bool HandleInputKey( const out InputEventParameters EventParms )
{
    local bool bResult;

    bResult=false;

    if(EventParms.EventType==IE_Released)
    {

        if(EventParms.InputKeyName=='XboxTypeS_LeftTrigger')
        {
            OnResetToDefaults();
            bResult=true;
        }
        else if(EventParms.InputKeyName=='XboxTypeS_B' || EventParms.InputKeyName=='Escape')
        {
            OnBack();
            bResult=true;
        }
    }

    return bResult;
}

DefaultProperties
{
    DinoClass=class'JRDino'
    MutatorClass=class'JRMutator_Dinos'
    
    SpawnLimitLabel="Max dino count: Up to %n at any given time."
    
    SpawnFrequencyLabel[0]="Max spawn rate: Up to %n per minute."
    SpawnFrequencyLabel[1]="Max spawn rate: Spawn %n once per game."
    
    SpawnForEachPlayerLabel[0]="Spawn ratio: 1 dino for each 1 player."
    SpawnForEachPlayerLabel[1]="Spawn ratio: %n dinos for each 1 player."
    SpawnForEachPlayerLabel[2]="Spawn ratio: 1 dino for each %n players."
    SpawnForEachPlayerLabel[3]="Spawn ratio: Don't use player count."
    
    SpawnForEachVehicleLabel[0]="Spawn ratio: 1 dino for each 1 vehicle."
    SpawnForEachVehicleLabel[1]="Spawn ratio: %n dinos for each 1 vehicle."
    SpawnForEachVehicleLabel[2]="Spawn ratio: 1 dino for each %n vehicles."
    SpawnForEachVehicleLabel[3]="Spawn ratio: Don't use vehicle count."
}