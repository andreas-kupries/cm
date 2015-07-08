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

cms day select 0

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
cms item event       'Free Tutorial' -L 60

cms track select Community
cms item event   'Social and BOFs' -B 19:00
cms item event   "Hospitality suite" "Tcl Community Association"  -L 05:00 --child

cms day next

cms track select     'Tutorial A'
cms item event       Tutorials
cms item placeholder @T1m0     -L 03:30 --child
cms track select     'Tutorial B'
cms item event       Tutorials
cms item placeholder @T1m1     -L 03:30 --child

cms item event 'Lunch Break'    --across
cms item event 'Lunch Provided' -L 60 --child

cms track select     'Tutorial A'
cms item event       Tutorials
cms item placeholder @T1a0     -L 03:30 --child
cms track select     'Tutorial B'
cms item event       Tutorials
cms item placeholder @T1a1     -L 03:30 --child

cms track select     'Tutorial A'
cms item event       'Certification Exam' -B 19:30
cms item placeholder @T1e1     -L 60 --child

cms track select Community
cms item event   'Social and BOFs' -B 19:00
cms item event   "Hospitality suite" "Tcl Community Association"  -L 05:00 --child

cms day next
cms track select 'Tech Session'

cms item event 'Welcome and Keynote'
cms item event 'Welcome and Announcements' Host -L 0 --child
cms item placeholder @K1                        -L 01:30 --child

cms item event Break
cms item event -L 15 Break --child

cms item placeholder @S1
cms item event @S1.1 -L 30 --child
cms item event @S1.2 -L 30 --child
cms item event @S1.3 -L 30 --child

cms item event 'Lunch Break'
cms item event 'Conference Luncheon' "Tcl Community Association" -L 60 --child

cms item placeholder @S2
cms item event @S2.1 -L 30 --child
cms item event @S2.2 -L 30 --child
cms item event @S2.3 -L 30 --child

cms item placeholder @S3
cms item event @S3.1 -L 30 --child
cms item event @S3.2 -L 30 --child
cms item event @S3.3 -L 30 --child

cms item event 'Dinner Break'
cms item event "See registration or the hospitality suite for suggestions" "On your own" \
    -L 2:30 --child

cms track select Community
cms item event   'Social and BOFs' -B 19:00
cms item event   "Hospitality suite" "Tcl Community Association"  -L 05:00 --child

exit
# #############################################################################

cms ;## -- enter hospitality suite
cms ;# enter day 3 - conference day 4
cms ;# enter day 4 - conference day 5
