CLEARSCREEN.
PRINT "Core Stage Seperation Confirmed.".
SET AdjustedSOI TO (KERBIN:SOIRADIUS - 600000).
IF (PERIAPSIS <= 30000) {
    PRINT "Stage Will Reenter the Atmosphere.".
}
ELSE IF (PERIAPSIS <= 70000) {
    PRINT "Stage's Orbit Will Decay, Coasting to Apoapsis.".
    WAIT UNTIL ETA:APOAPSIS <= 20.
    SET WARP TO 0.
    PRINT "Apoapsis Reached, Deorbiting Stage.".
    LOCK STEERING TO SHIP:RETROGRADE.
    LOCK THROTTLE TO 0.01.
    WAIT UNTIL FACING = SHIP:RETROGRADE.
    UNTIL (PERIAPSIS <= 30000) {
        LOCK THROTTLE TO 1.
    }
    PRINT "Stage Will Reenter the Atmosphere.".
    PRINT "Periapsis: " + CEILING(PERIAPSIS) + " m".
    LOCK THROTTLE TO 0.
}
ELSE IF (PERIAPSIS >= 70000 AND APOAPSIS < AdjustedSOI) {
    PRINT apoapsis.
    PRINT AdjustedSOI.
    PRINT "Stage's Orbit Will Not Decay, Coasting to Apoapsis.".
    WAIT UNTIL ETA:APOAPSIS <= 25.
    SET WARP TO 0.
    PRINT "Apoapsis Reached, Deorbiting Stage.".
    LOCK STEERING TO SHIP:RETROGRADE.
    LOCK THROTTLE TO 0.01.
    WAIT UNTIL FACING = SHIP:RETROGRADE.
    UNTIL (PERIAPSIS <= 30000) {
        LOCK THROTTLE TO 1.
    }
    PRINT "Stage Will Reenter the Atmosphere.".
    PRINT "Periapsis: " + CEILING(PERIAPSIS) + " m".
    LOCK THROTTLE TO 0.
}
ELSE IF (APOAPSIS > AdjustedSOI) {
    PRINT apoapsis.
    PRINT AdjustedSOI.
    PRINT "Stage Will Escape SOI, Recapturing Stage.".
    LOCK STEERING TO SHIP:RETROGRADE.
    LOCK THROTTLE TO 0.01.
    WAIT UNTIL FACING = SHIP:RETROGRADE.
    UNTIL (APOAPSIS < AdjustedSOI) {
        LOCK THROTTLE TO 1.
    }
    PRINT "Stage Has Been Recaptured.".
    PRINT "Apoapsis: " + CEILING(APOAPSIS) + " m".
    LOCK THROTTLE TO 0.
    WAIT UNTIL ETA:APOAPSIS <= 25.
    SET WARP TO 0.
    PRINT "Apoapsis Reached, Deorbiting Stage.".
    LOCK STEERING TO SHIP:RETROGRADE.
    LOCK THROTTLE TO 0.01.
    WAIT UNTIL FACING = SHIP:RETROGRADE.
    UNTIL (PERIAPSIS <= 30000) {
        LOCK THROTTLE TO 1.
    }
    PRINT "Stage Will Reenter the Atmosphere.".
    PRINT "Periapsis: " + CEILING(PERIAPSIS) + " m".
    LOCK THROTTLE TO 0.
}