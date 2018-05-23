//### door-script.lsl
//
// SWING A HINGED DOOR.  NO NEED FOR A SECOND PRIM.
// Works on stand-alone prim doors, a door of several linked parts,
// Or even a door that's a linked child of a larger house.  If the door
// is the root, all the links will swing.  If the door is just a linked,
// child then only the door will swing.
//
// ****************************************************************
// ****************************************************************
// ****************************************************************
// This program is free software: you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// version 3 as published my the Free Software Foundation:
// http://www.gnu.org/licenses/gpl.html
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// This software was originally written by KyleFlynn Resident.
// Mr. Flynn can be reached at kyleflynnresident@gmail.com.
// However, I don't often check that email.  You'd do better
// to catch me online, which I often am.
//
// This software got adjusted for efficient use in OpenSim by
// unregi Resident. This version of the script is for none-hinged
// doors that just need rotating.
// Changes:
//  - Removed all the stuff for hinged doors
//  - Ability to open all doors by saying a command got removed
// Thats the case because llSleep() is locking up threads in OS
// that other scripts could use. Opening all doors at once would
// would clog up threads.
//  - Its possible to set the pysics shape of the door to none when
// open by setting giOpenPhantom
//  - Ability to play sounds got added to this script, instead of
// relying to an other script
//  - Lockable by link message
// ****************************************************************
// ****************************************************************
// ****************************************************************
//
//
// A FEW USER DEFINED PARAMETERS FOLLOW.  THEY CAN BE CUSTOMIZED FOR SPECIFIC DOORS:
//
//
// The following must be 1 or -1.
// It just specifies which direction the door opens.
integer giSwingDirection = 1;
// The following can be any number but something around 90, 
// or maybe up 140 makes sense.
integer giDegreesToOpenDoor = 90;
// The following basically specifies how fast the door opens.
// It's how many degrees the door opens on each loop step.
// To make it just "pop" open, set it to the same as giDegreesToOpenDoor.
// Ideally, it should be an even divisor of giDegreesToOpenDoor, 
// but it doesn't really matter.  The pause is also just another
// way to slow the door down, but set giDegreesPerStep=1 before using pause.
// Since llSleep is a potential risk of lag on OpenSim, it is advised
// to open the door fast, by either setting gfSecondsPausePerStep very low
// or giDegreesPerStep high.
integer giDegreesPerStep = 2;
float   gfSecondsPausePerStep = 0.004;
// Do we wish for the door to automatically close after some interval?
integer gbCloseAfterTimeExpires = FALSE;
float   gfSecondToLeaveOpen = 5.0; // Does nothing unless above is TRUE.
// Do we play sounds on open doors?
// If so, place the sound files into the object inventory
integer giPlaySound = FALSE;
string gsOpeningSound = "open";
string gsClosingSound = "close";
string gsClosedSound = "closed";
// Should the door get set to none physics shape when open?
// (this means that avatars can walk through it and wont get stuck or pushed)
integer giOpenPhantom = TRUE;
// set if the door should be able to be locked by link message
integer gbDoorIsLockable = TRUE;
string gsUnlockMessage = "unlock";
string gsLockMessage = "lock";
// set if the door is paired with another door and its link number
// use this if you have a paire of doors that needs to open/close together
integer gbDoorIsPaired = FALSE;
integer giLinkOfPaired = 10;
//
//
// NOTHING FROM HERE DOWN SHOULD BE TAMPERED WITH, UNLESS YOU'RE A SCRIPTER.
//
//
integer    gbDoorIsClosed = TRUE;
integer    gbDoorIsLocked = FALSE;
rotation   gqClosedDoorRot;
integer    giClosedDoorPhysics;
//

PlaySound(string name)
{
    if(llGetInventoryType(name) == INVENTORY_SOUND && giPlaySound)
        llTriggerSound(name,1.0);
}

SwingTheDoor()
{
    if (llGetTime() < 0.8) return; // Prevent double-clicks and LSL bug.
    llResetTime();
    //
    rotation qDoorRot;
    integer    iStepCount;
    rotation qHingeOrbitStep;
    rotation qHingeOrbitAngle;
    //
    rotation qNewRot;
    //
    integer    iSwingDir;
    //
    // Figure out whether we're opening or closing.
    iSwingDir = giSwingDirection;
    if (gbDoorIsClosed)
    {
        // These are used to prevent the closed door from moving due to rounding errors.
        gqClosedDoorRot = llGetLocalRot();
        //
        PlaySound(gsOpeningSound);
        //
        if (giOpenPhantom) {
            giClosedDoorPhysics = llList2Integer(llGetLinkPrimitiveParams(LINK_THIS, [PRIM_PHYSICS_SHAPE_TYPE]), 0);
            llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_NONE]);
        }
        //
        if (gbDoorIsPaired) llMessageLinked(giLinkOfPaired, 0, "opendoor", NULL_KEY);
    }
    else
    {
        iSwingDir = iSwingDir * -1;
        //
        PlaySound(gsClosingSound);
        //
        if (gbDoorIsPaired) llMessageLinked(giLinkOfPaired, 0, "closedoor", NULL_KEY);
    }
    // Initial parameters.
    qDoorRot = llGetLocalRot();
    //
    // The door orbits in the Z axis (XY plane).
    // Also, we account for swing direction here.
    qHingeOrbitStep = llEuler2Rot(<0.0, 0.0, giDegreesPerStep * DEG_TO_RAD * iSwingDir>);
    // Start an increment loop to slowly open the door.
    for(iStepCount = 1; iStepCount * giDegreesPerStep <= giDegreesToOpenDoor; iStepCount++)
    {
        // Figure out the angle to orbit on this step (from the beginning so no errors accumulate).
        qHingeOrbitAngle = llAxisAngle2Rot(llRot2Axis(qHingeOrbitStep), iStepCount * llRot2Angle(qHingeOrbitStep));
        // We simply add our new angle to the door's starting orientation.
        qNewRot = qDoorRot * qHingeOrbitAngle;
        // Set it fast
        llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_ROT_LOCAL, qNewRot]);
        if (gfSecondsPausePerStep) llSleep(gfSecondsPausePerStep);
    }
    // Toggle opened/closed to new state.
    gbDoorIsClosed = !gbDoorIsClosed;
    if (gbDoorIsClosed)
    {
        // If it's now closed, make sure it's where it started.  
        // In other words, correct any rounding errors from opening and closing it.
        llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_ROT_LOCAL, gqClosedDoorRot]);
        //
        PlaySound(gsClosedSound);
        //
        if (giOpenPhantom) llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_PHYSICS_SHAPE_TYPE, giClosedDoorPhysics]);
    }
    else
    {
        // Make sure it's open to specified degrees.
        qHingeOrbitAngle = llEuler2Rot(<0.0, 0.0, giDegreesToOpenDoor * DEG_TO_RAD * iSwingDir>);
        qNewRot = qDoorRot * qHingeOrbitAngle;
        llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_ROT_LOCAL, qNewRot]);
        // If auto-close, set timer.
        if (gbCloseAfterTimeExpires) llSetTimerEvent(gfSecondToLeaveOpen);
    }
}

default
{
    on_rez(integer iParam) 
    {
        llResetScript();
    }
    touch_start(integer iNumDetected) 
    {
        if (gbDoorIsLocked && gbDoorIsClosed) return;
        SwingTheDoor();
    }
    timer() 
    {
        llSetTimerEvent(0.0);
        if (!gbDoorIsClosed) SwingTheDoor();
    }
    link_message(integer link_num, integer num, string msg, key id)
    {
        if (!gbDoorIsLockable && (!gbDoorIsPaired || link_num != giLinkOfPaired)) return;
        if (!gbDoorIsLockable) return;
        if (msg == gsLockMessage) gbDoorIsLocked = TRUE;
        if (msg == gsUnlockMessage) gbDoorIsLocked = FALSE;
        if ( (msg == "opendoor" && !gbDoorIsLocked && gbDoorIsClosed) || (msg == "closedoor" && !gbDoorIsClosed) ) SwingTheDoor();
    }
}
