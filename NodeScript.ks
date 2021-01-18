FUNCTION getEngines {
LIST ENGINES IN engList.
SET FullThrust TO 0.
GLOBAL StageIsp TO 0.
FOR eng in engList {
	IF eng:AVAILABLETHRUST > 0 {
		SET FullThrust TO FullThrust + eng:POSSIBLETHRUST.
		SET StageIsp TO StageIsp + eng:Isp.
		IF (FullThrust = 0 OR StageISP = 0) {
		PRINT "Please activate your engines and try again.".
	}	}
	}
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

FUNCTION PrintTime {
	PARAMETER Text, TimeS, DPlace IS 2.
	IF (TimeS >= 31536000){
		SET TimeY TO FLOOR(TimeS/31536000).
		SET TimeD TO FLOOR((TimeS- TimeY*31536000)/86400).
		SET TimeH TO FLOOR((TimeS - TimeY*31536000 - TimeD*86400)/3600).
		SET TimeM TO FLOOR((TimeS - TimeY*31536000 - TimeD*86400 - TimeH*3600)/60).
		SET TimeS TO ROUND((TimeS - TimeY*31536000 - TimeD*86400 - TimeH*3600 - TimeM*60),DPlace).
		PRINT Text + TimeY + "y " + TimeD + "d " + TimeH + "h " + TimeM + "m " + TimeS + "s".
	}
	ELSE IF (TimeS >= 86400){
		SET TimeD TO FLOOR(TimeS/86400).
		SET TimeH TO FLOOR((TimeS - TimeD*86400)/3600).
		SET TimeM TO FLOOR((TimeS - TimeD*86400 - TimeH*3600)/60).
		SET TimeS TO ROUND((TimeS - TimeD*86400 - TimeH*3600 - TimeM*60),DPlace).
		PRINT Text + TimeD + "d " + TimeH + "h " + TimeM + "m " + TimeS + "s".
	}
	ELSE IF (TimeS >= 3600){
		SET TimeH TO FLOOR(TimeS/3600).
		SET TimeM TO FLOOR((TimeS - TimeH*3600)/60).
		SET TimeS TO ROUND((TimeS - TimeH*3600 - TimeM*60),DPlace).
		PRINT Text + TimeH + "h " + TimeM + "m " + TimeS + "s".
	}
	ELSE IF (TimeS >= 60){
		SET TimeM TO (FLOOR(TimeS/60)).
		SET TimeS TO ROUND((TimeS - TimeM*60),DPlace).
		PRINT Text + TimeM + "m " + TimeS + "s".
	}
	ELSE IF (TimeS < 60){
		PRINT Text + ROUND(TimeS,DPlace) + "s".
	}
}

FUNCTION StopWarp {
PARAMETER targetTime.
LOCK targetRate TO (targetTime - TIME:Seconds)/3.
SET RateList TO KUNIVERSE:TIMEWARP:RAILSRATELIST.
UNTIL (TIME:Seconds >= targetTime) {
	IF (WARPMODE = "RAILS"){
	LOCK Row TO WARP.
		IF (targetRate <= RateList[Row]) AND (targetRate > RateList[2]) {
			SET WARP TO Warp - 1.
		}
	}
}
SET WARP TO 0.
PRINT "Warp Ended.".
}

CLEARSCREEN.
PARAMETER PGD IS 0, NML IS 0, RAD IS 0, ETA IS 0.
IF (PGD = 0) AND (NML = 0) AND (RAD = 0) AND (ETA = 0) {
	SET ND TO NEXTNODE.
}
ELSE {
	SET ND TO NODE(RAD,NML,PGD,TIME+ETA).
}
AutoStage().
PrintTime ("Node in: ", ND:ETA,0).
PRINT "Delta-V: " + ROUND(ND:DELTAV:MAG,2) + "m/s".
SET EndMass TO (MASS/(CONSTANT:e)^(ND:DELTAV:MAG/(StageISP*CONSTANT:g0))).
SET A0 TO SHIP:MAXTHRUST/MASS.
SET Af TO SHIP:MAXTHRUST/ENDMASS.
SET BurnTime TO (ND:DELTAV:MAG/(A0+((Af-A0)/2))).
PrintTime("Estimated Burn Time: ", BurnTime).

StopWarp(TIME:Seconds + ND:ETA - ((BurnTime/2)+30)).
WAIT UNTIL ND:ETA <= ((BurnTime/2)+30).
PRINT "Approaching Maneuver.".
SET WARP TO 0.
SAS OFF.
LOCK NodeVector TO ND:DELTAV.
LOCK STEERING TO NodeVector.
LOCK THROTTLE TO 0.

WAIT UNTIL ND:ETA <= (BurnTime*0.5).
SET BurnStartTime TO TIME:SECONDS.
SET BurnEndTime TO BurnStartTime + BurnTime.
PRINT "Burning.".
UNTIL TIME:SECONDS >= BurnEndTime{
	LOCK THROTTLE TO 1.
	LOCK STEERING TO NodeVector.
	AutoStage().
	WAIT 0.001.
}
LOCK THROTTLE TO 0.

PRINT "Error: " + ROUND(ND:DELTAV:MAG,2) + "m/s".
LOCK STEERING TO NodeVector.
//LOCK NodeVDir TO NodeVector:DIRECTION.
LOCK NodeDir TO V(NodeVector:DIRECTION:PITCH,NodeVector:DIRECTION:YAW,0).
//LOCK NodeDir TO V(NodeVDir:PITCH,NodeVDir:YAW,0).
LOCK Dir TO V(SHIP:FACING:PITCH,SHIP:FACING:YAW,0).
WAIT UNTIL (ABS(NodeDir:MAG - Dir:MAG) <= 0.1).
WAIT 1.
PRINT "Correcting.".
SET FinalMass TO (MASS/(CONSTANT:e)^(ND:DELTAV:MAG/(StageISP*CONSTANT:g0))).
SET T TO (ND:DELTAV:MAG/(SHIP:MAXTHRUST/MASS*5)).
UNTIL (MASS <= FinalMass){
	LOCK THROTTLE TO T.
	LOCK STEERING TO NodeVector.
	AutoStage().
	WAIT 0.001.
}
LOCK THROTTLE TO 0.
PRINT "Final Error: " + ROUND(ND:DELTAV:MAG,3) + "m/s".
PRINT "Maneuver Completed.".
UNLOCK ALL.

HUDTEXT("NodeScript.ks has Finished Running.",5,2,12,BLACK,True).
PRINT "Remove Node? (Backspace)".
PRINT "Or Press any key to end Program.".
SET Input TO TERMINAL:INPUT:GETCHAR().
IF (Input = TERMINAL:INPUT:BACKSPACE) {
	PRINT "Node Removed.".
	REMOVE ND.
}

