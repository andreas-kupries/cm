-- Example of a physical schedule (Tcl 2014)
-- bulk INSERT statements.
--                      
INSERT INTO pschedule -- id name
VALUES                  (1, "Tcl'2014")
;
--                                pschedule
INSERT INTO pschedule_track -- id |  name
VALUES                        (1, 1, "Tutorial A")
,                             (2, 1, "Tutorial B")
,                             (3, 1, "Tech Session")
,                             (4, 1, "Community")
;
--                               pschedule
--				 |  day            length
INSERT INTO pschedule_item -- id |  |  track start |   group label    description           speakerdesc
VALUES
-- day 1 tutorials
                            ( 1, 1, 0, 1,    540, 210, NULL, NULL,    "Tutorials",          NULL)
,                           ( 2, 1, 0, 1,    540, 210, 1,    "@T0m0", NULL,                 NULL)
,                           ( 3, 1, 0, 2,    540, 210, NULL, NULL,    "Tutorials",          NULL)
,                           ( 4, 1, 0, 2,    540, 210, 3,    "@T0m1", NULL,                 NULL)
,                           ( 5, 1, 0, NULL, 750,  60, NULL, NULL,    "Lunch Break",        NULL)
,                           ( 6, 1, 0, NULL, 750,  60, 5,    NULL,    "Lunch",              "Provided")
,                           ( 7, 1, 0, 1,    810, 210, NULL, NULL,    "Tutorials",          NULL)
,                           ( 8, 1, 0, 1,    810, 210, 7     "@T0a0", NULL,                 NULL)
,                           ( 9, 1, 0, 2,    810, 210, NULL, NULL,    "Tutorials",          NULL)
,                           (10, 1, 0, 2,    810, 210, 9,    "@T0a1", NULL,                 NULL)
,                           (11, 1, 0, 1,   1170,  60, NULL, NULL,    "Free tutorial",      NULL)
,                           (12, 1, 0, 4,   1140, 300, NULL, NULL,    "Social and BOFs",    NULL)
,                           (13, 1, 0, 4,   1140, 300, 12,   NULL,    "Hospitality suite", "Tcl Community Association")
-- day 2 tutorials
,                           (14, 1, 1, 1,    540, 210, NULL, NULL,    "Tutorials",          NULL)
,                           (15, 1, 1, 1,    540, 210, 1,    "@T1m0", NULL,                 NULL)
,                           (16, 1, 1, 2,    540, 210, NULL, NULL,    "Tutorials",          NULL)
,                           (17, 1, 1, 2,    540, 210, 3,    "@T1m1", NULL,                 NULL)
,                           (18, 1, 1, NULL, 750,  60, NULL, NULL,    "Lunch Break",        NULL)
,                           (19, 1, 1, NULL, 750,  60, 5,    NULL,    "Lunch",              "Provided")
,                           (20, 1, 1, 1,    810, 210, NULL, NULL,    "Tutorials",          NULL)
,                           (21, 1, 1, 1,    810, 210, 7     "@T1a0", NULL,                 NULL)
,                           (22, 1, 1, 2,    810, 210, NULL, NULL,    "Tutorials",          NULL)
,                           (23, 1, 1, 2,    810, 210, 9,    "@T1a1", NULL,                 NULL)
,                           (24, 1, 1, 1,   1170,  60, NULL, "@T2e0", NULL,                 NULL)
,                           (25, 1, 1, 4,   1140, 300, NULL, NULL,    "Social and BOFs",    NULL)
,                           (26, 1, 1, 4,   1140, 300, 25,   NULL,    "Hospitality suite", "Tcl Community Association")
-- day 3 tech sessions I
,                           (27, 1, 2, 3,    540,  90, NULL, NULL,    "Welcome and Keynote",       NULL)
,                           (28, 1, 2, 3,    540,  0,  27,   NULL,    "Welcome and Announcements", "Host")
,                           (29, 1, 2, 3,    540,  90, 27,   "@K1",   NULL,                        NULL)
,                           (30, 1, 2, 3,    630,  15, NULL, NULL,    "Break", NULL)
,                           (31, 1, 2, 3,    630,  15, 30,   NULL,    "Break", NULL)
,                           (32, 1, 2, 3,    645,  90, NULL, "@S1",   NULL,    NULL)
,                           (33, 1, 2, 3,    645,  30, 32,   "@P1.1", NULL,    NULL)
,                           (34, 1, 2, 3,    675,  30, 32,   "@P1.2", NULL,    NULL)
,                           (35, 1, 2, 3,    705,  30, 32,   "@P1.3", NULL,    NULL)
,                           (36, 1, 2, 3,    735,  60, NULL, NULL,    "Lunch Break",         NULL)
,                           (37, 1, 2, 3,    735,  60, 36,   NULL,    "Conference Luncheon", "Tcl Community Association")
,                           (38, 1, 2, 3,    795,  90, NULL, "@S2",   NULL,    NULL)
,                           (39, 1, 2, 3,    795,  30, 38,   "@P2.1", NULL,    NULL)
,                           (40, 1, 2, 3,    825,  30, 38,   "@P2.2", NULL,    NULL)
,                           (41, 1, 2, 3,    855,  30, 38,   "@P2.3", NULL,    NULL)
,                           (42, 1, 2, 3,    885,  90, NULL, "@S3",   NULL,    NULL)
,                           (43, 1, 2, 3,    885,  30, 42,   "@P3.1", NULL,    NULL)
,                           (44, 1, 2, 3,    915,  30, 42,   "@P3.1", NULL,    NULL)
,                           (45, 1, 2, 3,    945,  30, 42,   "@P3.1", NULL,    NULL)
,                           (46, 1, 2, 3,    975, 150, NULL, NULL,    "Dinner Break", NULL)
,                           (47, 1, 2, 3,    975, 150, NULL, NULL,    "See registration for suggestions", "On your own")
,                           (48, 1, 2, 4,   1140, 300, NULL, NULL,    "Social and BOFs",    NULL)
,                           (49, 1, 2, 4,   1140, 300, 48,   NULL,    "Hospitality suite", "Tcl Community Association")
-- day 4 tech sessions II
,                           (50, 1, 3, 3,    540,  0,  NULL, NULL,    "Welcome", NULL)
,                           (51, 1, 3, 3,    540,  0,  50,   NULL,    "Welcome and Announcements", "Host")
,                           (52, 1, 3, 3,    540, 90,  NULL, "@S4",   NULL, NULL)
,                           (53, 1, 3, 3,    540, 30,  52,   "@P4.1", NULL, NULL)
,                           (54, 1, 3, 3,    570, 30,  52,   "@P4.2", NULL, NULL)
,                           (55, 1, 3, 3,    600, 30,  52,   "@P4.3", NULL, NULL)
,                           (56, 1, 3, 3,    630, 15,  NULL, NULL,    "Break", NULL)
,                           (57, 1, 3, 3,    630, 15,  56,   NULL,    "Break", NULL)
,                           (58, 1, 3, 3,    645, 90,  NULL, "@S5",   NULL, NULL
,                           (59, 1, 3, 3,    645, 30,  58,   "@P5.1", NULL, NULL)
,                           (60, 1, 3, 3,    675, 30,  58,   "@P5.2", NULL, NULL)
,                           (61, 1, 3, 3,    705, 30,  58,   "@P5.3", NULL, NULL)
,                           (62, 1, 3, 3,    735, 60,  NULL, NULL,    "Lunch Break", NULL)
,                           (63, 1, 3, 3,    735, 60,  62,   NULL,    "Lots within walking distance", "On your own")
,                           (64, 1, 3, 3,    795, 90,  NULL, "@S6",   NULL, NULL
,                           (65, 1, 3, 3,    795, 30,  64,   "@P6.1", NULL, NULL)
,                           (66, 1, 3, 3,    825, 30,  64,   "@P6.2", NULL, NULL)
,                           (67, 1, 3, 3,    855, 30,  64,   "@P6.3", NULL, NULL)
,                           (68, 1, 3, 3,    885, 60,  NULL, "@S7",   NULL, NULL)
,                           (69, 1, 3, 3,    885, 30,  68,   "@P7.1", NULL, NULL)
,                           (70, 1, 3, 3,    915, 30,  68,   "@P7.2", NULL, NULL)
,                           (71, 1, 3, 3,    945, 30,  NULL,  NULL,   "WIPs", NULL)
,                           (72, 1, 3, 3,    945, 30,  71,    NULL,   "Short discussion of an interesting project. Sign up at registration", "Work In Progress")
,                           (73, 1, 3, 3,   1080, 90,  NULL,  NULL,   "Banquet", NULL)
,                           (74, 1, 3, 3,   1080, 90,  73,    NULL,   "Conference Banquet", "Tcl Community Association")
,                           (75, 1, 3, 4,   1140, 300, NULL,  NULL,   "Social and BOFs",    NULL)
,                           (76, 1, 3, 4,   1140, 300, 75,    NULL,   "Hospitality suite", "Tcl Community Association")
-- day 5 tech sessions III
,                           (77, 1, 4, 3,    540,  0,  NULL, NULL,    "Welcome", NULL)
,                           (78, 1, 4, 3,    540,  0,  77,   NULL,    "Welcome and Announcements", "Host")
,                           (79, 1, 4, 3,    540, 30,  NULL, "@S8",   NULL, NULL)
,                           (80, 1, 4, 3,    540, 30,  79,   "@P8.1", NULL, NULL)
,                           (81, 1, 4, 3,    570, 30,  NULL, "@S9",   NULL, NULL)
,                           (82, 1, 4, 3,    570, 30,  81,   "@P9.1", NULL, NULL)
,                           (83, 1, 4, 3,    600, 30,  NULL, NULL,    "Tcl Community Association", NULL)
,                           (84, 1, 4, 3,    600, 30,  83,   NULL,    "What's going on with TCA", "Townhall")
,                           (85, 1, 3, 4,   1140, 300, NULL,  NULL,   "Social and BOFs",    NULL)
,                           (86, 1, 3, 4,   1140, 300, 85,    NULL,   "Hospitality suite", "Tcl Community Association")
;
