#!/bin/bash

function cms()
{
    echo
    echo === "$@" === === === === === === === === ===
    echo
    cm schedule "$@" --color always
    # --debug cm/db/pschedule
    # --debug cm/schedule
}

# Start clean
cms remove "Tcl 2014"

cms add "Tcl 2014"
cms start 09:00
cms track add 'Tutorial A'
cms track add 'Tutorial B'
cms track add 'Tech Session'
cms track add 'Community'

cms track select     'Tutorial A'
cms item event       Tutorials
cms item placeholder @T0m0     -L 03:30 --child
cms track select     'Tutorial B'
cms item event       Tutorials
cms item placeholder @T0m1     -L 03:30 --child

cms item event 'Lunch Break'    --across
cms item event 'Lunch Provided' -L 60 --child

cms track select     'Tutorial A'
cms item event       Tutorials
cms item placeholder @T0a0     -L 03:30 --child
cms track select     'Tutorial B'
cms item event       Tutorials
cms item placeholder @T0a1     -L 03:30 --child

cms track select     'Tutorial A'
cms item event       'Free Tutorial' -L 60 --child

cms track select Community
cms item event   'Social and BOFs' -B 19:00
cms item event   "Hospitality suite" "Tcl Community Association"  -L 05:00 --child





exit
# #############################################################################
cms ;## WIBNI to duplicate this ((group) item) across days
cms yank
cms day= 1
cms insert --keep-track
cms next
cms insert --keep-track
cms next
cms insert --keep-track
cms next
cms insert --keep-track
cms day= 0

cms ;## WIBNI to duplicate an entire day
cms ;## COST  -- placeholder uniqueness required auto-modify.
cms ;## COST  -- need command to edit other than current item
cms ;## COST  -- or command to switch current item into middle.
cms ;## COST  -- and either restrict editing to non-time attributes
cms ;## COST  -- or handle movement of items after current one.
cms next
cms ;# -- ENTER day 1 - tutorial day 2
cms next
cms track= 'Tech Session'
cms event 'Welcome and Keynote'
cms open
cms event 'Welcome and Announcements' Host
cms placeholder 1:30 @K1
cms close
cms event Break
cms open
cms event 15 Break
cms close
cms placeholder @S1
cms open
cms event 30 @S1.1
cms event 30 @S1.2
cms event 30 @S1.3
cms close
cms event 'Lunch Break'
cms open
cms event 1:00 'Conference Luncheon' "Tcl Community Association"
cms close
cms placeholder @S2
cms open
cms event 30 @S2.1
cms event 30 @S2.2
cms event 30 @S2.3
cms close
cms placeholder @S3
cms open
cms event 30 @S3.1
cms event 30 @S3.2
cms event 30 @S3.3
cms close
cms event 'Dinner Break'
cms open
cms event 2:30 "See registration for suggestions" "On your own"
cms close
cms ;## -- enter hospitality suite
cms ;# enter day 3 - conference day 4
cms ;# enter day 4 - conference day 5
