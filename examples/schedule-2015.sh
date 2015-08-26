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
cms remove 'Tcl 2015'

cms add 'Tcl 2015'
cms start 09:00

cms track add 'Tutorial A'
cms track add 'Tutorial B'
cms track add 'Tech Session'
cms track add 'Community'

# #############################################################################
cms day select 0

cms track select     'Tutorial A'
cms item event       Tutorials
cms item placeholder @T1m1     -L 03:30 --child
cms track select     'Tutorial B'
cms item event       Tutorials
cms item placeholder @T1m2     -L 03:30 --child

cms item event 'Lunch Break'    --across
cms item event 'Lunch Provided' -L 60 --child

cms track select     'Tutorial A'
cms item event       Tutorials
cms item placeholder @T1a1     -L 03:30 --child
cms track select     'Tutorial B'
cms item event       Tutorials
cms item placeholder @T1a2     -L 03:30 --child

cms track select     'Tutorial A'
cms item event       'Free Tutorial' -L 60

cms track select Community
cms item event   'Social and BOFs' -B 19:00
cms item event   'Hospitality suite' 'Tcl Community Association'  -L 05:00 --child

# #############################################################################
cms day next

cms track select     'Tutorial A'
cms item event       Tutorials
cms item placeholder @T2m1     -L 03:30 --child
cms track select     'Tutorial B'
cms item event       Tutorials
cms item placeholder @T2m2     -L 03:30 --child

cms item event 'Lunch Break'    --across
cms item event 'Lunch Provided' -L 60 --child

cms track select     'Tutorial A'
cms item event       Tutorials
cms item placeholder @T2a1     -L 03:30 --child
cms track select     'Tutorial B'
cms item event       Tutorials
cms item placeholder @T2a2     -L 03:30 --child

cms track select     'Tutorial A'
cms item event       'Certification Exam' -B 19:30
cms item placeholder @T2e1     -L 60 --child

cms track select Community
cms item event   'Social and BOFs' -B 19:00
cms item event   'Hospitality suite' 'Tcl Community Association'  -L 05:00 --child

# #############################################################################
cms day next
cms track select 'Tech Session'

cms item event 'Welcome and Keynote'
cms item event 'Welcome and Announcements' Host -L 0 --child
cms item placeholder @K1                        -L 01:30 --child

cms item event Break
cms item event -L 15 Break --child

cms item placeholder @S1
cms item placeholder @P1.1 -L 30 --child
cms item placeholder @P1.2 -L 30 --child
cms item placeholder @P1.3 -L 30 --child

cms item event 'Lunch Break' --across
cms item event 'Conference Luncheon' 'Tcl Community Association' -L 60 --child

cms item placeholder @S2
cms item placeholder @P2.1 -L 30 --child
cms item placeholder @P2.2 -L 30 --child
cms item placeholder @P2.3 -L 30 --child

cms item event Break
cms item event -L 15 Break --child

cms item placeholder @S3
cms item placeholder @P3.1 -L 30 --child
cms item placeholder @P3.2 -L 30 --child
cms item placeholder @P3.3 -L 30 --child

cms item event 'Dinner Break' --across
cms item event 'See registration or the hospitality suite for suggestions' 'On your own' \
    -L 02:30 --child

cms track select Community
cms item event   'Social and BOFs' -B 19:00
cms item event   'Hospitality suite' 'Tcl Community Association'  -L 05:00 --child

# #############################################################################
cms day next
cms track select 'Tech Session'

cms item event 'Welcome'
cms item event 'Welcome and Announcements' Host -L 0 --child
cms item placeholder @K2                        -L 01:30 --child

cms item event Break
cms item event -L 15 Break --child

cms item placeholder @S4
cms item placeholder @P4.1 -L 30 --child
cms item placeholder @P4.2 -L 30 --child
cms item placeholder @P4.3 -L 30 --child

cms item event 'Lunch Break' --across
cms item event 'Lots within walking distance' 'On your own' -L 60 --child

cms item placeholder @S5
cms item placeholder @P5.1 -L 30 --child
cms item placeholder @P5.2 -L 30 --child
cms item placeholder @P5.3 -L 30 --child

cms item event Break
cms item event -L 15 Break --child

cms item placeholder @S6
cms item placeholder @P6.1 -L 30 --child
cms item placeholder @P6.2 -L 30 --child
cms item placeholder @P6.3 -L 30 --child

cms item event WIPs
cms item event 'Short discussions of an interesting project. Sign up at registration' 'Work in Progress' \
    -L 30 --child

cms item event 'Banquet' -B 18:00 --across
cms item event 'Conference Banquet' 'Tcl Community Association' -L 01:30 --child

cms track select Community
cms item event   'Social and BOFs' -B 19:30
cms item event   'Hospitality suite' 'Tcl Community Association'  -L 05:00 --child

# #############################################################################
cms day next
cms track select 'Tech Session'

cms item event 'Welcome'
cms item event 'Welcome and Announcements' Host -L 0 --child

cms item placeholder @S7
cms item placeholder @P7.1 -L 30 --child
cms item placeholder @P7.2 -L 30 --child

cms item event 'Tcl Community Association'
cms item event 'What is going on with Tcl Community Association' 'Townhall' \
    -L 30 --child

cms track select Community
cms item event   'Social and BOFs' -B 19:00
cms item event   'Hospitality suite' 'Tcl Community Association'  -L 05:00 --child

exit
# #############################################################################
