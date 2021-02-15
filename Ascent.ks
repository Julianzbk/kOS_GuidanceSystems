FUNCTION TURN {
	PARAMETER H TO 90, P TO 90.
	IF SAS {SAS OFF.}
	LOCK STEERING TO HEADING(H,P).
}

FUNCTION getEngines {
LIST ENGINES in engList.
{
SET CurrentThrust TO 0.
SET FullThrust TO 0.
SET EngCount TO 0.
GLOBAL IdleThrust TO 0.
GLOBAL StageIsp TO 0.
GLOBAL MaxTWR TO 0.
GLOBAL VariableThrust TO 0.
}
FOR eng IN engList {
	If eng:MAXTHRUST > 0 {
		SET EngCount TO EngCount + 1.
		If eng:ALLOWSHUTDOWN = 1 {
		SET FullThrust TO FullThrust + eng:POSSIBLETHRUST.
		SET StageIsp TO StageIsp + eng:Isp.
		}
		Else {
		SET IdleThrust TO IdleThrust + eng:POSSIBLETHRUST.
		SET FullThrust TO FullThrust + eng:POSSIBLETHRUST.
		SET StageIsp TO StageIsp + eng:Isp.
		}
    }
}
IF EngCount = 0 {
	SET StageIsp TO 0.
}
ELSE {
SET StageIsp TO StageIsp/EngCount.
}
LOCK MaxTWR TO (FullThrust/(MASS*(CONSTANT:g0))).
LOCK VariableThrust TO (FullThrust-IdleThrust).
}

FUNCTION setTWR {
	PARAMETER targetTWR.
	getEngines().
	IF VariableThrust = 0 {
		SET VariableThrust TO 1.
	}
	SET targetThrott TO (((targetTWR*MASS*CONSTANT:g0)-IdleThrust)/VariableThrust).
	IF (targetThrott > 0.05 AND targetThrott <= 1.0) {
	LOCK THROTTLE TO targetThrott.
	}
	ELSE IF (targetThrott > 1.0) {LOCK THROTTLE TO 1.0.}
	ELSE {LOCK THROTTLE TO 0.05.}
}

FUNCTION GTurn {
	PARAMETER Ground, Roof, Rate, TurnPitch, BlockTWR.
	IF (Rate < 0) {
		UNTIL(ALTITUDE >= Roof) {
			TURN(targetHDG,TurnPitch).
			setTWR(BlockTWR).
			AutoStage().
		} RETURN.
	}
	IF (Ground = Roof) {
		UNTIL(APOAPSIS >= Roof) {
			SET targetPitch TO ((Rate/-1000)*(ALTITUDE-30000)+TurnPitch).
			IF (targetPitch <= 0) {SET targetPitch TO 0.}
			TURN(targetHDG,targetPitch).
			setTWR(BlockTWR).
			AutoStage().
		} RETURN.
	}
	UNTIL (ALTITUDE >= Roof) {
		SET targetPitch TO ((Rate/-1000)*(ALTITUDE-Ground)+TurnPitch).
		TURN(targetHDG,targetPitch).
		setTWR(BlockTWR).
		AutoStage().
	}
}

FUNCTION Circularize {
PARAMETER T.
LOCK STEERING TO PROGRADE.
SET t0 TO TIME:SECONDS.
SET dt TO ETA:APOAPSIS - T.
SET f0 TO (-0.06*T + 1).
WAIT UNTIL TIME:SECONDS >= (t0 + dt).
	UNTIL (PERIAPSIS >= TargetPe){
		SET dt TO T - ETA:APOAPSIS.
		AutoStage().
		WAIT 0.01.
		IF dt >= 0 {
		SET dt TO T - ETA:APOAPSIS.
		LOCK THROTTLE TO (0.06*(dt-T)+1).
		}
		ELSE IF (dt < 0 AND dt >= -100){
		SET dt TO 3 - ETA:APOAPSIS.
		LOCK THROTTLE TO (-1/((100*dt)-(1/f0))).
		}
		ELSE IF (ALTITUDE < targetPe){
		UNTIL ((PERIAPSIS >= targetPe-1.5*(targetPe-ALTITUDE)) AND (PERIAPSIS > 70500)){
		LOCK THROTTLE TO 1.
		LOCK STEERING TO PROGRADE + R(3,0,0).
		}
		}
		ELSE {
		UNTIL (PERIAPSIS >= TargetPe){
		LOCK THROTTLE TO 1.
		LOCK STEERING TO PROGRADE + R(3,0,0).
			}
		}
	}
LOCK THROTTLE TO 0.
}

FUNCTION getDeltaV {
getEngines().
SET DMASS TO (MASS - (STAGE:LIQUIDFUEL*5 + STAGE:OXIDIZER*5)/1000).
SET DV TO (StageIsp*CONSTANT:g0*LN(MASS/DMASS)).
PRINT "Delta V left in current stage: " + ROUND(DV,1) + "m/s".
}

FUNCTION AutoStage {
getEngines().
IF (MaxTWR < OldTWR) {
	STAGE.
	PRINT "Staging.".
	UNTIL STAGE:READY {WAIT 0.5.}
	getEngines().
}
ELSE IF ((STAGE:LIQUIDFUEL > 0) AND (STAGE:LIQUIDFUEL <= 10)) {
	WAIT UNTIL STAGE:LIQUIDFUEL <= 0.1.
	STAGE.
	PRINT "Staging.".
	UNTIL STAGE:READY {WAIT 0.5.}
	getEngines().
}
ELSE IF (MaxTWR = 0) {
	STAGE.
	PRINT "Staging.".
	UNTIL STAGE:READY {WAIT 0.5.}
	getEngines().
}
SET OldTWR TO MaxTWR.
}

FUNCTION ImplementTriggers {
	ON ABORT {
		PRINT "MISSION ABORTED, REVERT TO MANUAL CONTROL.".
		HUDTEXT("MISSION ABORTED", 5, 2, 20, RED, false).
		LOCK THROTTLE TO 0.
		UNLOCK ALL.
		SHUTDOWN.
	}
}

FUNCTION Inc{
	PARAMETER Phi IS 0, VStart IS 0, VEnd IS VStart.
	SET VChange TO SQRT(VStart^2 + VEnd^2 - 2*VStart*VEnd*COS(Phi)).
	SET Gamma TO 90-ARCSIN(SIN(Phi)*VEnd/VChange).
	RETURN V(-(SIN(Gamma)*VChange),(-COS(Gamma)*VChange),0).
}

DECLARE PARAMETER tAp TO 80000, tPe TO 75000, tI TO (SHIP:GEOPOSITION:LAT), tP TO 90, Display TO TRUE.
CLEARSCREEN.
PRINT "Initializing...".
{
ImplementTriggers().
IF Display {WAIT 1.}
GLOBAL targetHDG TO 90.
GLOBAL targetPitch TO tP.
GLOBAL targetAp TO tAp. 
GLOBAL targetPe TO tPe.
IF targetPe > targetAp {
	SET targetPe TO targetAp.
}
SET targetA TO (targetAp + targetPe)/2.
SET OBV TO SQRT(KERBIN:MU*((2/(targetA+KERBIN:RADIUS))-(1/(targetAp+KERBIN:RADIUS)))).
{
	IF tI >= GEOPOSITION:LAT {
	SET targetHDG TO ARCSIN(COS(tI)/COS(GEOPOSITION:LAT)).
	}
	ELSE {
	PRINT "Selected Inclination is Unreachable.".
	SET targetHDG TO 90.
	PRINT "Adding a Correction Maneuver.".
	SET IncFix TO TRUE.
	}
	SET KerbinRot TO GEOPOSITION:ALTITUDEVELOCITY(ALTITUDE):ORBIT:MAG.
	SET LaunchV TO SQRT((OBV^2)+(KerbinRot^2)-(2*KerbinRot*COS(90-targetHDG))).
	SET Theta TO ARCSIN((SIN(90-targetHDG)*VELOCITY:ORBIT:MAG)/LaunchV).
	IF (targetHDG - Theta < 0) AND (targetHDG = 0) {
		SET targetHDG TO 360 - Theta.
	}
	ELSE {
		SET targetHDG TO targetHDG - Theta.
	}
}
IF Display {
PRINT "Target Orbit: " + ROUND(targetAp) + "m x " + ROUND(targetPe) + "m, " + ROUND(tI,1) + "°.".
PRINT "Launch Angle: " + ROUND(targetHDG,1) + "°, " + ROUND(targetPitch,1) + "°.".
PRINT "Press Any Key to Proceed with Launch.".
SET Input TO Terminal:Input:GETCHAR().
	}
}

PRINT "Launching Vessel.".
{
LOCK THROTTLE TO 1.0.
SET LaunchRoll TO SHIP:FACING:ROLL.
LOCK STEERING TO UP + R(0,0,LaunchRoll).
WAIT 2.
UNTIL SHIP:VERTICALSPEED > 0.5 {
	STAGE.
	WAIT 1.
	getEngines().
}
}

PRINT "Liftoff Achieved.".
{
getEngines().
setTWR(1.7).
GLOBAL OldTWR TO MaxTWR.
WAIT 2.
GTurn(300,1000,-1,90,1.7).
}

PRINT "Initiating Gravity Turn.".
{
GTurn(1000 ,2000 ,10 ,85,1.7).
GTurn(2000 ,10000,3.5,75,1.7).
GTurn(10000,20000,1  ,47,1.7).
GTurn(20000,30000,1.2,37,1.7).
GTurn(targetAp,targetAp,1,27,1.7).
}

PRINT "Ascension Complete.".
{
LOCK THROTTLE TO 0.
TURN(targetHDG,0).
PRINT "Coasting to Apoapsis: " + FLOOR(APOAPSIS) + "m".
getEngines().
SET CircDV TO OBV - VELOCITYAT(SHIP,TIME:SECONDS+ETA:APOAPSIS):ORBIT:MAG.
LOCK targetETA TO CircDV / (MAXTHRUST/MASS).
PRINT "Target ETA: " + ROUND(targetETA,2) + " s.".
WAIT UNTIL ETA:APOAPSIS <= (targetETA + 15).
SET WARP TO 0.
}

PRINT "Approaching Apoapsis, Circularizing.".
{
Circularize(targetETA).
PRINT "Orbit has been achieved.".
PRINT "Apoapsis: " + FLOOR(APOAPSIS) + "m".
PRINT "Periapsis: " + FLOOR(PERIAPSIS) + "m".
getDeltaV().
IF IncFix {
	CLEARSCREEN.
	PRINT "A Fix Maneuver has been added. Execute? (Y/N)".
	SET Input TO TERMINAL:INPUT:GETCHAR().
	IF (Input = "Y") {
		SET ShipNorm TO VCRS(BODY:POSITION,VELOCITY:ORBIT).
		SET NodeLine TO VCRS(ShipNorm:Normalized,V(0,1,0)).
		SET Theta TO VANG(-BODY:POSITION,NodeLine).
		IF Theta > 180 {
			SET Theta TO 180 - Theta.
		}
	LOCK NodeETA TO Theta/(360/SHIP:ORBIT:PERIOD).
	SET Inclination TO ARCCOS(ShipNorm:Y/ShipNorm:MAG).
	RUN NodeScript(
	Inc(Inclination,VELOCITYAT(SHIP,TIME:SECONDS+NodeETA):ORBIT:MAG):X
	, Inc(Inclination,VELOCITYAT(SHIP,TIME:SECONDS+NodeETA):ORBIT:MAG):Y
	, 0 , NodeETA).
	}
}
HUDTEXT("Ascent.ks has Finished Running.",5,2,12,BLACK,False).
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
UNLOCK ALL.
}