FUNCTION TURN {
	PARAMETER H TO 90, P TO 90.
	IF SAS {SAS OFF.}
	LOCK STEERING TO HEADING(H,P).
}

FUNCTION getTWR {
LIST ENGINES in engList.
{
SET CurrentThrust TO 0.
SET FullThrust TO 0.
GLOBAL IdleThrust TO 0.
GLOBAL StageIsp TO 0.
GLOBAL TWR TO 0.
GLOBAL MaxTWR TO 0.
GLOBAL MinTWR TO 0.
GLOBAL VariableThrust TO 0.
}
FOR eng IN engList {
	If eng:AVAILABLETHRUST > 0 {
		If eng:ALLOWSHUTDOWN = 1 {
		SET CurrentThrust TO CurrentThrust + eng:POSSIBLETHRUST * THROTTLE.
		SET FullThrust TO FullThrust + eng:POSSIBLETHRUST.
		SET StageIsp TO StageIsp + eng:Isp.
		}
		Else {
		SET CurrentThrust TO CurrentThrust + eng:POSSIBLETHRUST.
		SET IdleThrust TO IdleThrust + eng:POSSIBLETHRUST.
		SET FullThrust TO FullThrust + eng:POSSIBLETHRUST.
		SET StageIsp TO StageIsp + eng:Isp.
		}
    }
}
SET TWR TO (CurrentThrust/(MASS*(CONSTANT:g0))).
SET MaxTWR TO (FullThrust/(MASS*(CONSTANT:g0))).
SET MinTWR TO (IdleThrust/(MASS*(CONSTANT:g0))).
SET VariableThrust TO (FullThrust-IdleThrust).
IF VariableThrust <= 0 {SET VariableThrust TO 1.}
}

FUNCTION setTWR {
	PARAMETER targetTWR.
	getTWR().
	LOCK targetThrott TO (((targetTWR*MASS*CONSTANT:g0)-IdleThrust)/VariableThrust).
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
	}
	RETURN.
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
SET t0 TO TIME:SECONDS.
SET dt TO ETA:APOAPSIS - T.
SET maxThrottle TO 1.
SET f0 TO (0.06*(-1*(T))+maxThrottle).
TURN(targetHDG,0).
WAIT UNTIL TIME:SECONDS >= (t0 + dt).
	UNTIL (PERIAPSIS >= TargetPe){
		SET dt TO T - ETA:APOAPSIS.
		AutoStage().
		IF dt >= 0 {
		SET dt TO T - ETA:APOAPSIS.
		LOCK THROTTLE TO (0.06*(dt-T)+maxThrottle).
		}
		ELSE IF (dt < 0 AND dt >= -100){
		SET dt TO 3 - ETA:APOAPSIS.
		LOCK THROTTLE TO (-1/((100*dt)-(1/f0))).
		}
		ELSE IF (ALTITUDE < targetPe){
		UNTIL ((PERIAPSIS >= targetPe-1.5*(targetPe-ALTITUDE)) AND (PERIAPSIS > 70500)){
		LOCK THROTTLE TO maxThrottle.
		LOCK STEERING TO PROGRADE + R(3,0,0).
		}
		}
		ELSE {
		UNTIL (PERIAPSIS >= TargetPe){
		LOCK THROTTLE TO maxThrottle.
		LOCK STEERING TO PROGRADE + R(3,0,0).
			}
		}
	}
LOCK THROTTLE TO 0.
PRINT "Orbit has been achieved.".
PRINT "Apoapsis: " + FLOOR(APOAPSIS) + "m".
PRINT "Periapsis: " + FLOOR(PERIAPSIS) + "m".
}

FUNCTION getDeltaV {
getTWR().
SET DMASS TO (MASS - (STAGE:LIQUIDFUEL*5 + STAGE:OXIDIZER*5)/1000).
SET DV TO (StageIsp*CONSTANT:g0*LN(MASS/DMASS)).
PRINT "Delta V left in current stage: " + ROUND(DV,1) + "m/s".
}

FUNCTION AutoStage {
getTWR().
IF (MaxTWR < OldTWR) {
	STAGE.
	SET OldTWR TO MaxTWR.
	PRINT "Staging.".
	UNTIL STAGE:READY {WAIT 0.5.}
}
ELSE IF ((STAGE:LIQUIDFUEL > 0) AND (STAGE:LIQUIDFUEL <= 1)) {
	STAGE.
	SET OldTWR TO MaxTWR.
	PRINT "Staging.".
	UNTIL STAGE:READY {WAIT 0.5.}
}
ELSE IF (MaxTWR = 0) {
	STAGE.
	PRINT "Staging.".
	UNTIL STAGE:READY {WAIT 0.5.}
}
getTWR().
}

FUNCTION ImplementTriggers {
	ON ABORT {
		PRINT "MISSION ABORTED, REVERT TO MANUAL CONTROL.".
		HUDTEXT("MISSION ABORTED", 5, 2, 15, RED, false).
		LOCK THROTTLE TO 0.
		UNLOCK ALL.
		SHUTDOWN.
	}
}

DECLARE PARAMETER tAp TO 80000, tPe TO 75000, tH TO 90, tP TO 90, Display TO TRUE.
CLEARSCREEN.
PRINT "Initializing...".
{
ImplementTriggers().
WAIT 2.
GLOBAL targetHDG TO tH.
GLOBAL targetPitch TO tP.
GLOBAL targetAp TO tAp. 
GLOBAL targetPe TO tPe.
IF targetPe > targetAp {
	SET targetPe TO targetAp.
}
SET targetA TO (targetAp + targetPe)/2.
SET OBV TO SQRT(KERBIN:MU*((2/(targetA+KERBIN:RADIUS))-(1/(targetAp+KERBIN:RADIUS)))).
{
	SET LaunchLoc TO SHIP:GEOPOSITION.
	SET KerbinRot TO LaunchLoc:ALTITUDEVELOCITY(ALTITUDE):ORBIT:MAG.
	SET OBTInc TO (90 - targetHDG) + LaunchLoc:LAT.
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
PRINT "Target Orbit: " + ROUND(targetAp) + "m x " + ROUND(targetPe) + "m.".
PRINT "Launch Angle: " + ROUND(targetHDG,1) + "°, " + ROUND(targetPitch,1) + "°.".
PRINT "Press Any Key to Proceed with Launch.".
SET Input TO Terminal:Input:GETCHAR().
}
LOCK THROTTLE TO 1.0.
}
PRINT "Launching Vessel.".
{
WAIT 2.
UNTIL SHIP:VERTICALSPEED > 0.5 {
	STAGE.
	WAIT 1.
}
}
PRINT "Liftoff Achieved.".
{
setTWR(1.7).
GLOBAL OldTWR TO MaxTWR.
GTurn(300,1000,-1,90,1.7).
}
PRINT "Initiating Gravity Turn.".
{
GTurn(1000,2000,10,85,1.7).
GTurn(2000,10000,3.5,75,1.7).
GTurn(10000,20000,1,47,1.6).
GTurn(20000,30000,1.2,37,1.7).
UNTIL APOAPSIS >= targetAp {
SET targetPitch TO (-0.001*ALTITUDE+55).
IF (targetPitch <= 0) {SET targetPitch TO 0.}
TURN(targetHDG,targetPitch).
AutoStage().
setTWR(1.7).
}}
PRINT "Ascension Complete.".
{
LOCK THROTTLE TO 0.
LOCK STEERING TO PROGRADE.
PRINT "Coasting to Apoapsis: " + FLOOR(APOAPSIS) + "m".
getTWR().
SET targetETA TO (OBV - GROUNDSPEED) / (MaxTWR*CONSTANT:g0).
PRINT "Target ETA: " + ROUND(targetETA,2) + " s.".
WAIT UNTIL ETA:APOAPSIS <= (targetETA + 15).
SET WARP TO 0.
}
PRINT "Approaching Apoapsis, Circularizing.".
{
LOCK STEERING TO PROGRADE.
Circularize(targetETA).
getDeltaV().
HUDTEXT("Ascent.ks has Finished Running.",5,2,12,BLACK,True).
UNLOCK ALL.
}