FUNCTION getEngines {
LIST ENGINES in engList.
GLOBAL MaxA TO 0.
GLOBAL A TO 0.
GLOBAL FullThrust TO 0.
GLOBAL StageIsp TO 0.
    FOR eng IN engList {
	If eng:AVAILABLETHRUST > 0 {
		Set FullThrust TO eng:POSSIBLETHRUST.
		Set StageIsp TO StageIsp + eng:Isp.
		}
    }
    LOCK MaxA TO FullThrust/MASS.
    LOCK A TO (FullThrust/MASS)*THROTTLE.
}

FUNCTION AutoStage {
getEngines().
IF ((STAGE:LIQUIDFUEL > 0) AND (STAGE:LIQUIDFUEL <= 0.1)) {
	STAGE.
	PRINT "Staging.".
	UNTIL STAGE:READY {WAIT 0.5.}
}
ELSE IF (STAGE:SOLIDFUEL > 0 AND STAGE:SOLIDFUEL <= 0.1) {
	STAGE.
	PRINT "Staging.".
	UNTIL STAGE:READY {WAIT 0.5.}
}
ELSE IF (STAGE:XENONGAS > 0 AND STAGE:XENONGAS <= 0.1) {
	STAGE.
	PRINT "Staging.".
	UNTIL STAGE:READY {WAIT 0.5.}
}
ELSE IF (FullThrust = 0) {
	STAGE.
	PRINT "Staging.".
	UNTIL STAGE:READY {WAIT 0.5.}
}
getEngines().
}

FUNCTION setA {
    PARAMETER targetA.
    getEngines().
    SET targetThrott TO (MASS*targetA)/FullThrust.
    IF (targetThrott >= 0) AND (targetThrott <= 1) {
        LOCK THROTTLE TO targetThrott.
    }
    ELSE IF (targetThrott < 0) {
        LOCK THROTTLE TO 0.
    }
    ELSE IF (targetThrott > 1){
        LOCK THROTTLE TO 1.
    }
}

FUNCTION HoldV {
    PARAMETER targetV.
    getEngines().
    LOCK G TO (ORBIT:BODY:MU/(ALTITUDE+BODY:RADIUS)^2).
    LOCK dV TO (-targetV) - (VERTICALSPEED).
    LOCK t TO (dV/(A + 0.001)).
    SET targetA TO (dV/MaxA + (G + t)).
    IF (targetA > MaxA) {setA(MaxA).}
    ELSE IF (targetA < 0) {setA(0).}
    ELSE {setA(targetA).}
}

FUNCTION setVUntil {
    PARAMETER H, V.
    PRINT "Limiting Velocity to " + V + " m/s Until " + H + " m.".
    UNTIL ALT:RADAR <= H {
    AutoStage().
    HoldV(V).
    WAIT 0.05.
    }
}

FUNCTION BailOut {
    PRINT "BAILING OUT.".
    LOCK STEERING TO UP.
    LOCK THROTTLE TO 1.0.
    WAIT UNTIL APOAPSIS > 10000.
    UNLOCK ALL.
}

CLEARSCREEN.
PRINT "Preparing to Deorbit.".
AutoStage().
LOCK RetroAngle TO (90-ARCTAN(VERTICALSPEED/GROUNDSPEED)).
LOCK SuicideTime TO 0.
SAS OFF.
LOCK STEERING TO SRFRETROGRADE.
LOCK Diff TO (SRFRETROGRADE - FACING).
LOCK DiffVector TO V(Diff:PITCH,Diff:YAW,0).
WAIT UNTIL (DiffVector:MAG <= 1).
WAIT 1.
PRINT "Killing Horizontal Velocity.".
UNTIL (GROUNDSPEED <= 10){
    LOCK THROTTLE TO 1.
    WAIT 0.05.
}
SET NAVMODE TO "SURFACE".
LOCK THROTTLE TO 0.
setVUntil(1000,100).
{
GEAR ON.
SET GearParts TO SHIP:PARTSINGROUP("GEAR").
FOR GEAR IN GearParts {
    IF GEAR:STAGE = -1 {
        UNTIL STAGE:NUMBER = 0 {
            STAGE.
            PRINT "The Current Stage does not have Landing Gears.".
            PRINT "Staging.".
            WAIT 0.5.
        }
    }
    ELSE IF GEAR:STAGE > 0 {
        UNTIL STAGE:NUMBER = GEAR:STAGE {
            STAGE.
            PRINT "The Current Stage does not have Landing Gears.".
            PRINT "Staging.".
            WAIT 0.5.
        }
    }
}
}
setVUntil(500,50).
setVUntil(250,25).
setVUntil(50,5).
setVUntil(20,2.5).
PRINT "Terminal Velocity: 1 m/s.".
UNTIL SHIP:STATUS = "LANDED" {
    HoldV(1).
    AutoStage().
}
PRINT("Touchdown Detected, Cutting Thrust.").
LOCK THROTTLE TO 0.
UNLOCK STEERING.
SAS ON.
SET SASMODE TO "STABILITYASSIST".
WAIT 2.
IF (SHIP:STATUS = "LANDED") {
    PRINT ("Landing Confirmed.").
}
ELSE {BailOut().}
UNLOCK ALL.