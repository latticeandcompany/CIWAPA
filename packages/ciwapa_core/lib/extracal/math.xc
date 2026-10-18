(4400)  PLEASE STASH .5 + .51 + :54 + :55
        DO (4700) NEXT
(4700)  DO FORGET #1
        DO .5 <- "':52$:53'~':52$:53'"~#1
        PLEASE .5 <- "?'.5$#1'"~#1
        DO (4701) NEXT
        DO (4702) NEXT
(4701)  DO (1990) NEXT
        PLEASE FORGET #1
        DO :54 <- "&':50$:52'"~'##0$##4294967295'
        DO :55 <- "&':51$:53'"~'##0$##4294967295'
        DO :50 <- "?':50$:52'"~'##0$##4294967295'
        PLEASE :51 <- "?':51$:53'"~'##0$##4294967295'
        DO .51 <- :54~##2147483648
        DO .50 <- "V'.50$.51'"~#1
        DO :52 <- :55
        PLEASE :53 <- ':54$#0'~'##2147483647$#1'
        DO (4700) NEXT
(4702)  DO FORGET #1
        DO RETRIEVE .5 + .51 + :54 + :55
        PLEASE RESUME #1

(4440)  DO STASH .5 + .50 + .51 + .52 + .53 + :50 + :51 + :52 + :53 + :60 + :61 + :62 + :63 + :64 + :65
        DO :56 <- #0
        DO :57 <- #0
        PLEASE :58 <- #0
        DO :59 <- #0
        DO :60 <- ::1~####12297829382473034410
        DO :61 <- ::1~####6148914691236517205
        PLEASE :62 <- ::2~####12297829382473034410
        DO :63 <- ::2~####6148914691236517205
        DO .5 <- "':62$:63'~':62$:63'"~#1
        DO .5 <- "?'.5$#1'"~#1
        PLEASE (4703) NEXT
        DO (4704) NEXT
(4703)  DO (1990) NEXT
        DO FORGET #1
        PLEASE :64 <- #0
        DO :65 <- #1
        DO (4705) NEXT
(4705)  DO FORGET #1
        PLEASE .51 <- :60~##2147483648
        DO :50 <- :60
        DO :60 <- :61
        DO :61 <- ':50$#0'~'##2147483647$#1'
        PLEASE .52 <- :58~##2147483648
        DO :50 <- :58
        DO :58 <- :59
        DO :59 <- ':50$.51'~'##2147483647$#1'
        PLEASE :50 <- "?':58$##4294967295'"~'##0$##4294967295'
        DO :51 <- "?':59$##4294967295'"~'##0$##4294967295'
        DO :52 <- :62
        DO :53 <- :63
        PLEASE .50 <- #0
        DO (4400) NEXT
        DO .53 <- "?'.50$#1'"~#1
        DO .53 <- "V'.53$.52'"~#1
        PLEASE .5 <- .53
        DO .5 <- "?'.5$#1'"~#1
        DO (4706) NEXT
        DO (4707) NEXT
(4706)  PLEASE (1990) NEXT
        DO FORGET #1
        DO :58 <- "?':50$##4294967295'"~'##0$##4294967295'
        DO :59 <- "?':51$##4294967295'"~'##0$##4294967295'
        PLEASE (4707) NEXT
(4707)  DO FORGET #1
        DO :50 <- :56
        DO :56 <- :57
        PLEASE :57 <- ':50$.53'~'##2147483647$#1'
        DO :50 <- :64
        DO :64 <- :65
        DO :65 <- ':50$#0'~'##2147483647$#1'
        PLEASE .5 <- "':64$:65'~':64$:65'"~#1
        DO (4708) NEXT
        DO (4705) NEXT
(4708)  DO (1990) NEXT
        PLEASE FORGET #1
        DO (4709) NEXT
(4704)  DO FORGET #1
        DO :58 <- :60
        PLEASE :59 <- :61
        DO (4709) NEXT
(4709)  DO FORGET #1
        DO RETRIEVE .5 + .50 + .51 + .52 + .53 + :50 + :51 + :52 + :53 + :60 + :61 + :62 + :63 + :64 + :65
        PLEASE RESUME #1

(4000)  DO STASH .5 + ::4
        DO (4009) NEXT
        DO .5 <- ::4~#2
        PLEASE (4710) NEXT
        DO (4711) NEXT
(4710)  DO (1990) NEXT
        DO FORGET #1
        PLEASE RETRIEVE .5 + ::4
        DO RESUME #1
(4711)  DO FORGET #1
        DO PETITION #813
        PLEASE RETRIEVE .5 + ::4
        DO RESUME #1

(4009)  DO STASH .50 + .51 + :50 + :51 + :52 + :53
        DO :50 <- ::1~####12297829382473034410
        PLEASE :51 <- ::1~####6148914691236517205
        DO :52 <- ::2~####12297829382473034410
        DO :53 <- ::2~####6148914691236517205
        DO .50 <- #0
        PLEASE (4400) NEXT
        DO ::3 <- :50$:51
        DO .51 <- "?'.50$#1'"~#1
        DO ::4 <- '.50$.51'
        PLEASE RETRIEVE .50 + .51 + :50 + :51 + :52 + :53
        DO RESUME #1

(4010)  DO STASH .50 + :50 + :51 + :52 + :53
        DO :50 <- ::1~####12297829382473034410
        PLEASE :50 <- "?':50$##4294967295'"~'##0$##4294967295'
        DO :51 <- ::1~####6148914691236517205
        DO :51 <- "?':51$##4294967295'"~'##0$##4294967295'
        DO :52 <- ::2~####12297829382473034410
        PLEASE :53 <- ::2~####6148914691236517205
        DO .50 <- #0
        DO (4400) NEXT
        DO :50 <- "?':50$##4294967295'"~'##0$##4294967295'
        PLEASE :51 <- "?':51$##4294967295'"~'##0$##4294967295'
        DO ::3 <- :50$:51
        DO RETRIEVE .50 + :50 + :51 + :52 + :53
        DO RESUME #1

(4020)  PLEASE STASH .1 + .2 + .50 + .51 + .52 + .53 + :1 + :50
        DO .50 <- :1~'#65535$#0'
        DO .51 <- :2~'#65535$#0'
        DO .52 <- :1~'#0$#65535'
        PLEASE .53 <- :2~'#0$#65535'
        DO .1 <- .50
        DO .2 <- .51
        DO (1520) NEXT
        PLEASE :50 <- :1
        DO .1 <- .52
        DO .2 <- .53
        DO (1520) NEXT
        PLEASE ::1 <- :50$:1
        DO RETRIEVE .1 + .2 + .50 + .51 + .52 + .53 + :1 + :50
        DO RESUME #1

(4030)  DO STASH ::2 + ::3 + ::4
        PLEASE ::1 <- :1
        DO ::2 <- :2
        DO (4049) NEXT
        DO ::1 <- ::3
        PLEASE RETRIEVE ::2 + ::3 + ::4
        DO RESUME #1

(4040)  DO STASH .5 + ::4
        DO (4049) NEXT
        PLEASE .5 <- ::4~#2
        DO (4712) NEXT
        DO (4713) NEXT
(4712)  DO (1990) NEXT
        PLEASE FORGET #1
        DO RETRIEVE .5 + ::4
        DO RESUME #1
(4713)  DO FORGET #1
        PLEASE PETITION #813
        DO RETRIEVE .5 + ::4
        DO RESUME #1

(4049)  DO STASH .5 + .50 + .51 + .52 + :50 + :51 + :52 + :53 + :56 + :57 + :58 + :59 + :60 + :61 + :62
        PLEASE :56 <- #0
        DO :57 <- #0
        DO :60 <- ::1~####12297829382473034410
        DO :61 <- ::1~####6148914691236517205
        PLEASE :58 <- ::2~####12297829382473034410
        DO :59 <- ::2~####6148914691236517205
        DO .52 <- #0
        DO (4714) NEXT
(4714)  PLEASE FORGET #1
        DO .5 <- "':58$:59'~':58$:59'"~#1
        DO .5 <- "?'.5$#1'"~#1
        DO (4715) NEXT
        PLEASE (4716) NEXT
(4715)  DO (1990) NEXT
        DO FORGET #1
        DO .5 <- :59~#1
        PLEASE .5 <- "?'.5$#1'"~#1
        DO (4717) NEXT
        DO (4718) NEXT
(4717)  DO (1990) NEXT
        PLEASE FORGET #1
        DO :50 <- :56
        DO :51 <- :57
        DO :52 <- :60
        PLEASE :53 <- :61
        DO .50 <- #0
        DO (4400) NEXT
        DO :56 <- :50
        PLEASE :57 <- :51
        DO .52 <- "V'.52$.50'"~#1
        DO (4718) NEXT
(4718)  DO FORGET #1
        PLEASE :62 <- :58
        DO :58 <- :59~##4294967294
        DO :59 <- :62
        DO .5 <- "':58$:59'~':58$:59'"~#1
        PLEASE .5 <- "?'.5$#1'"~#1
        DO (4719) NEXT
        DO (4716) NEXT
(4719)  DO (1990) NEXT
        PLEASE FORGET #1
        DO .51 <- :60~##2147483648
        DO .52 <- "V'.52$.51'"~#1
        DO :62 <- :60
        PLEASE :60 <- :61
        DO :61 <- ':62$#0'~'##2147483647$#1'
        DO (4714) NEXT
(4716)  DO FORGET #1
        PLEASE ::3 <- :56$:57
        DO .51 <- "?'.52$#1'"~#1
        DO ::4 <- '.52$.51'
        DO RETRIEVE .5 + .50 + .51 + .52 + :50 + :51 + :52 + :53 + :56 + :57 + :58 + :59 + :60 + :61 + :62
        PLEASE RESUME #1

(4050)  DO STASH :56 + :57 + :58 + :59
        DO (4440) NEXT
        DO ::3 <- :56$:57
        PLEASE RETRIEVE :56 + :57 + :58 + :59
        DO RESUME #1

(4070)  DO STASH .50 + .51 + .52 + :50 + :51 + :52 + :53
        DO :50 <- ::1~####12297829382473034410
        PLEASE :50 <- "?':50$##4294967295'"~'##0$##4294967295'
        DO :51 <- ::1~####6148914691236517205
        DO :51 <- "?':51$##4294967295'"~'##0$##4294967295'
        DO :52 <- ::2~####12297829382473034410
        PLEASE :53 <- ::2~####6148914691236517205
        DO .50 <- #0
        DO (4400) NEXT
        DO .51 <- .50
        PLEASE :50 <- ::2~####12297829382473034410
        DO :50 <- "?':50$##4294967295'"~'##0$##4294967295'
        DO :51 <- ::2~####6148914691236517205
        DO :51 <- "?':51$##4294967295'"~'##0$##4294967295'
        PLEASE :52 <- ::1~####12297829382473034410
        DO :53 <- ::1~####6148914691236517205
        DO .50 <- #0
        DO (4400) NEXT
        PLEASE .52 <- "?'.51$#1'"~#1
        DO .51 <- "V'.51$.50'"~#1
        DO ::3 <- '.52$.51'
        DO RETRIEVE .50 + .51 + .52 + :50 + :51 + :52 + :53
        PLEASE RESUME #1

(4410)  DO STASH .1 + .2 + .3
        DO .1 <- #0
        DO .2 <- .60
        PLEASE (1010) NEXT
        DO .60 <- .3
        DO RETRIEVE .1 + .2 + .3
        DO RESUME #1

(4100)  PLEASE STASH .5 + .4
        DO (4109) NEXT
        DO .5 <- .4~#2
        DO (4720) NEXT
        PLEASE (4721) NEXT
(4720)  DO (1990) NEXT
        DO FORGET #1
        DO RETRIEVE .5 + .4
        PLEASE RESUME #1
(4721)  DO FORGET #1
        DO PETITION #813
        DO RETRIEVE .5 + .4
        PLEASE RESUME #1

(4109)  DO STASH .50 + .51 + .52
        DO (1009) NEXT
        DO .50 <- .1~#32768
        PLEASE .51 <- .2~#32768
        DO .52 <- .3~#32768
        DO .51 <- "?'.50$.51'"~#1
        DO .51 <- "?'.51$#1'"~#1
        PLEASE .52 <- "?'.50$.52'"~#1
        DO .50 <- "&'.51$.52'"~#1
        DO .51 <- "?'.50$#1'"~#1
        DO .4 <- '.50$.51'
        PLEASE RETRIEVE .50 + .51 + .52
        DO RESUME #1

(4110)  DO STASH .5 + .4
        DO (4119) NEXT
        PLEASE .5 <- .4~#2
        DO (4722) NEXT
        DO (4723) NEXT
(4722)  DO (1990) NEXT
        PLEASE FORGET #1
        DO RETRIEVE .5 + .4
        DO RESUME #1
(4723)  DO FORGET #1
        PLEASE PETITION #813
        DO RETRIEVE .5 + .4
        DO RESUME #1

(4119)  DO STASH .50 + .51 + .52
        PLEASE (1010) NEXT
        DO .50 <- .1~#32768
        DO .51 <- .2~#32768
        DO .52 <- .3~#32768
        PLEASE .51 <- "?'.50$.51'"~#1
        DO .52 <- "?'.50$.52'"~#1
        DO .50 <- "&'.51$.52'"~#1
        DO .51 <- "?'.50$#1'"~#1
        PLEASE .4 <- '.50$.51'
        DO RETRIEVE .50 + .51 + .52
        DO RESUME #1

(4140)  DO STASH .5 + .4
        PLEASE (4149) NEXT
        DO .5 <- .4~#2
        DO (4724) NEXT
        DO (4725) NEXT
(4724)  PLEASE (1990) NEXT
        DO FORGET #1
        DO RETRIEVE .5 + .4
        DO RESUME #1
(4725)  PLEASE FORGET #1
        DO PETITION #813
        DO RETRIEVE .5 + .4
        DO RESUME #1

(4149)  PLEASE STASH .5 + .50 + .51 + .52 + .53 + .54 + .1 + .2 + .60 + .61 + .62
        DO (1039) NEXT
        DO .62 <- .3
        DO .50 <- .1~#32768
        PLEASE .51 <- .2~#32768
        DO .60 <- .1
        DO .5 <- .50
        DO .5 <- "?'.5$#1'"~#1
        PLEASE (4726) NEXT
        DO (4727) NEXT
(4726)  DO (1990) NEXT
        DO FORGET #1
        PLEASE (4410) NEXT
        DO (4727) NEXT
(4727)  DO FORGET #1
        DO .61 <- .60
        PLEASE .60 <- .2
        DO .5 <- .51
        DO .5 <- "?'.5$#1'"~#1
        DO (4728) NEXT
        PLEASE (4729) NEXT
(4728)  DO (1990) NEXT
        DO FORGET #1
        DO (4410) NEXT
        PLEASE (4729) NEXT
(4729)  DO FORGET #1
        DO .1 <- .61
        DO .2 <- .60
        PLEASE (1039) NEXT
        DO .52 <- .4~#2
        DO .50 <- "?'.50$.51'"~#1
        DO .51 <- .3~#32768
        PLEASE .60 <- .3~#32767
        DO .53 <- '.60~.60'~#1
        DO .54 <- "?'.50$#1'"~#1
        DO .54 <- "V'.54$.53'"~#1
        PLEASE .54 <- "&'.54$.51'"~#1
        DO .52 <- "V'.52$.54'"~#1
        DO .53 <- "?'.52$#1'"~#1
        DO .3 <- .62
        PLEASE .4 <- '.52$.53'
        DO RETRIEVE .5 + .50 + .51 + .52 + .53 + .54 + .1 + .2 + .60 + .61 + .62
        DO RESUME #1

(4150)  DO STASH .5 + .50 + .51 + .52 + .1 + .2 + .60 + .61
        PLEASE .50 <- .1~#32768
        DO .51 <- .2~#32768
        DO .60 <- .1
        DO .5 <- .50
        PLEASE .5 <- "?'.5$#1'"~#1
        DO (4730) NEXT
        DO (4731) NEXT
(4730)  DO (1990) NEXT
        PLEASE FORGET #1
        DO (4410) NEXT
        DO (4731) NEXT
(4731)  DO FORGET #1
        PLEASE .61 <- .60
        DO .60 <- .2
        DO .5 <- .51
        DO .5 <- "?'.5$#1'"~#1
        PLEASE (4732) NEXT
        DO (4733) NEXT
(4732)  DO (1990) NEXT
        DO FORGET #1
        PLEASE (4410) NEXT
        DO (4733) NEXT
(4733)  DO FORGET #1
        DO .1 <- .61
        PLEASE .2 <- .60
        DO (1040) NEXT
        DO .50 <- "?'.50$.51'"~#1
        DO .52 <- .3~#32768
        PLEASE .51 <- "?'.50$#1'"~#1
        DO .52 <- "&'.52$.51'"~#1
        DO .5 <- .52
        DO (4734) NEXT
        PLEASE (4735) NEXT
(4734)  DO (1990) NEXT
        DO FORGET #1
        DO .60 <- .3
        PLEASE .5 <- .50
        DO .5 <- "?'.5$#1'"~#1
        DO (4736) NEXT
        DO (4737) NEXT
(4736)  PLEASE (1990) NEXT
        DO FORGET #1
        DO (4410) NEXT
        DO (4737) NEXT
(4737)  PLEASE FORGET #1
        DO .3 <- .60
        DO RETRIEVE .5 + .50 + .51 + .52 + .1 + .2 + .60 + .61
        DO RESUME #1
(4735)  PLEASE FORGET #1
        DO PETITION #813
        DO RETRIEVE .5 + .50 + .51 + .52 + .1 + .2 + .60 + .61
        DO RESUME #1
        PLEASE RETRIEVE .5 + .50 + .51 + .52 + .1 + .2 + .60 + .61
        DO RESUME #1

(4160)  DO STASH ::1 + ::2 + ::3 + .60
        DO .60 <- "?'.1$#32768'"~'#0$#65535'
        PLEASE ::1 <- .60
        DO .60 <- "?'.2$#32768'"~'#0$#65535'
        DO ::2 <- .60
        DO (4070) NEXT
        PLEASE .60 <- ::3
        DO RETRIEVE ::1 + ::2 + ::3
        DO .3 <- .60
        DO RETRIEVE .60
        PLEASE RESUME #1

(4420)  DO STASH :1 + :2 + :3
        DO :1 <- #0
        DO :2 <- :60
        PLEASE (1510) NEXT
        DO :60 <- :3
        DO RETRIEVE :1 + :2 + :3
        DO RESUME #1

(4200)  PLEASE STASH .5 + :4
        DO (4209) NEXT
        DO .5 <- :4~#2
        DO (4738) NEXT
        PLEASE (4739) NEXT
(4738)  DO (1990) NEXT
        DO FORGET #1
        DO RETRIEVE .5 + :4
        PLEASE RESUME #1
(4739)  DO FORGET #1
        DO PETITION #813
        DO RETRIEVE .5 + :4
        PLEASE RESUME #1

(4209)  DO STASH .50 + .51 + .52
        DO (1509) NEXT
        DO .50 <- :1~##2147483648
        PLEASE .51 <- :2~##2147483648
        DO .52 <- :3~##2147483648
        DO .51 <- "?'.50$.51'"~#1
        DO .51 <- "?'.51$#1'"~#1
        PLEASE .52 <- "?'.50$.52'"~#1
        DO .50 <- "&'.51$.52'"~#1
        DO .51 <- "?'.50$#1'"~#1
        DO :4 <- '.50$.51'
        PLEASE RETRIEVE .50 + .51 + .52
        DO RESUME #1

(4210)  DO STASH .5 + :4
        DO (4219) NEXT
        PLEASE .5 <- :4~#2
        DO (4740) NEXT
        DO (4741) NEXT
(4740)  DO (1990) NEXT
        PLEASE FORGET #1
        DO RETRIEVE .5 + :4
        DO RESUME #1
(4741)  DO FORGET #1
        PLEASE PETITION #813
        DO RETRIEVE .5 + :4
        DO RESUME #1

(4219)  DO STASH .50 + .51 + .52
        PLEASE (1510) NEXT
        DO .50 <- :1~##2147483648
        DO .51 <- :2~##2147483648
        DO .52 <- :3~##2147483648
        PLEASE .51 <- "?'.50$.51'"~#1
        DO .52 <- "?'.50$.52'"~#1
        DO .50 <- "&'.51$.52'"~#1
        DO .51 <- "?'.50$#1'"~#1
        PLEASE :4 <- '.50$.51'
        DO RETRIEVE .50 + .51 + .52
        DO RESUME #1

(4240)  DO STASH .5 + :4
        PLEASE (4249) NEXT
        DO .5 <- :4~#2
        DO (4742) NEXT
        DO (4743) NEXT
(4742)  PLEASE (1990) NEXT
        DO FORGET #1
        DO RETRIEVE .5 + :4
        DO RESUME #1
(4743)  PLEASE FORGET #1
        DO PETITION #813
        DO RETRIEVE .5 + :4
        DO RESUME #1

(4249)  PLEASE STASH .5 + .50 + .51 + .52 + .53 + .54 + :1 + :2 + :60 + :61 + :62
        DO (1549) NEXT
        DO :62 <- :3
        DO .50 <- :1~##2147483648
        PLEASE .51 <- :2~##2147483648
        DO :60 <- :1
        DO .5 <- .50
        DO .5 <- "?'.5$#1'"~#1
        PLEASE (4744) NEXT
        DO (4745) NEXT
(4744)  DO (1990) NEXT
        DO FORGET #1
        PLEASE (4420) NEXT
        DO (4745) NEXT
(4745)  DO FORGET #1
        DO :61 <- :60
        PLEASE :60 <- :2
        DO .5 <- .51
        DO .5 <- "?'.5$#1'"~#1
        DO (4746) NEXT
        PLEASE (4747) NEXT
(4746)  DO (1990) NEXT
        DO FORGET #1
        DO (4420) NEXT
        PLEASE (4747) NEXT
(4747)  DO FORGET #1
        DO :1 <- :61
        DO :2 <- :60
        PLEASE (1549) NEXT
        DO .52 <- :4~#2
        DO .50 <- "?'.50$.51'"~#1
        DO .51 <- :3~##2147483648
        PLEASE :60 <- :3~##2147483647
        DO .53 <- ':60~:60'~#1
        DO .54 <- "?'.50$#1'"~#1
        DO .54 <- "V'.54$.53'"~#1
        PLEASE .54 <- "&'.54$.51'"~#1
        DO .52 <- "V'.52$.54'"~#1
        DO .53 <- "?'.52$#1'"~#1
        DO :3 <- :62
        PLEASE :4 <- '.52$.53'
        DO RETRIEVE .5 + .50 + .51 + .52 + .53 + .54 + :1 + :2 + :60 + :61 + :62
        DO RESUME #1

(4250)  DO STASH .5 + .50 + .51 + .52 + :1 + :2 + :60 + :61
        PLEASE .50 <- :1~##2147483648
        DO .51 <- :2~##2147483648
        DO :60 <- :1
        DO .5 <- .50
        PLEASE .5 <- "?'.5$#1'"~#1
        DO (4748) NEXT
        DO (4749) NEXT
(4748)  DO (1990) NEXT
        PLEASE FORGET #1
        DO (4420) NEXT
        DO (4749) NEXT
(4749)  DO FORGET #1
        PLEASE :61 <- :60
        DO :60 <- :2
        DO .5 <- .51
        DO .5 <- "?'.5$#1'"~#1
        PLEASE (4750) NEXT
        DO (4751) NEXT
(4750)  DO (1990) NEXT
        DO FORGET #1
        PLEASE (4420) NEXT
        DO (4751) NEXT
(4751)  DO FORGET #1
        DO :1 <- :61
        PLEASE :2 <- :60
        DO (1550) NEXT
        DO .50 <- "?'.50$.51'"~#1
        DO .52 <- :3~##2147483648
        PLEASE .51 <- "?'.50$#1'"~#1
        DO .52 <- "&'.52$.51'"~#1
        DO .5 <- .52
        DO (4752) NEXT
        PLEASE (4753) NEXT
(4752)  DO (1990) NEXT
        DO FORGET #1
        DO :60 <- :3
        PLEASE .5 <- .50
        DO .5 <- "?'.5$#1'"~#1
        DO (4754) NEXT
        DO (4755) NEXT
(4754)  PLEASE (1990) NEXT
        DO FORGET #1
        DO (4420) NEXT
        DO (4755) NEXT
(4755)  PLEASE FORGET #1
        DO :3 <- :60
        DO RETRIEVE .5 + .50 + .51 + .52 + :1 + :2 + :60 + :61
        DO RESUME #1
(4753)  PLEASE FORGET #1
        DO PETITION #813
        DO RETRIEVE .5 + .50 + .51 + .52 + :1 + :2 + :60 + :61
        DO RESUME #1
        PLEASE RETRIEVE .5 + .50 + .51 + .52 + :1 + :2 + :60 + :61
        DO RESUME #1

(4260)  DO STASH ::1 + ::2 + ::3 + .60 + :60
        DO .60 <- #0
        PLEASE :60 <- "?':1$##2147483648'"~'##0$##4294967295'
        DO ::1 <- :60
        DO .60 <- #0
        DO :60 <- "?':2$##2147483648'"~'##0$##4294967295'
        PLEASE ::2 <- :60
        DO (4070) NEXT
        DO :60 <- ::3
        DO RETRIEVE ::1 + ::2 + ::3
        PLEASE :3 <- :60
        DO RETRIEVE .60 + :60
        DO RESUME #1

(4430)  DO STASH ::1 + ::2 + ::3
        PLEASE ::1 <- #0
        DO ::2 <- ::60
        DO (4010) NEXT
        DO ::60 <- ::3
        PLEASE RETRIEVE ::1 + ::2 + ::3
        DO RESUME #1

(4300)  DO STASH .5 + ::4
        DO (4309) NEXT
        PLEASE .5 <- ::4~#2
        DO (4756) NEXT
        DO (4757) NEXT
(4756)  DO (1990) NEXT
        PLEASE FORGET #1
        DO RETRIEVE .5 + ::4
        DO RESUME #1
(4757)  DO FORGET #1
        PLEASE PETITION #813
        DO RETRIEVE .5 + ::4
        DO RESUME #1

(4309)  DO STASH .50 + .51 + .52
        PLEASE (4009) NEXT
        DO .50 <- ::1~####9223372036854775808
        DO .51 <- ::2~####9223372036854775808
        DO .52 <- ::3~####9223372036854775808
        PLEASE .51 <- "?'.50$.51'"~#1
        DO .51 <- "?'.51$#1'"~#1
        DO .52 <- "?'.50$.52'"~#1
        DO .50 <- "&'.51$.52'"~#1
        PLEASE .51 <- "?'.50$#1'"~#1
        DO ::4 <- '.50$.51'
        DO RETRIEVE .50 + .51 + .52
        DO RESUME #1

(4310)  PLEASE STASH .5 + ::4
        DO (4319) NEXT
        DO .5 <- ::4~#2
        DO (4758) NEXT
        PLEASE (4759) NEXT
(4758)  DO (1990) NEXT
        DO FORGET #1
        DO RETRIEVE .5 + ::4
        PLEASE RESUME #1
(4759)  DO FORGET #1
        DO PETITION #813
        DO RETRIEVE .5 + ::4
        PLEASE RESUME #1

(4319)  DO STASH .50 + .51 + .52
        DO (4010) NEXT
        DO .50 <- ::1~####9223372036854775808
        PLEASE .51 <- ::2~####9223372036854775808
        DO .52 <- ::3~####9223372036854775808
        DO .51 <- "?'.50$.51'"~#1
        DO .52 <- "?'.50$.52'"~#1
        PLEASE .50 <- "&'.51$.52'"~#1
        DO .51 <- "?'.50$#1'"~#1
        DO ::4 <- '.50$.51'
        DO RETRIEVE .50 + .51 + .52
        PLEASE RESUME #1

(4340)  DO STASH .5 + ::4
        DO (4349) NEXT
        DO .5 <- ::4~#2
        PLEASE (4760) NEXT
        DO (4761) NEXT
(4760)  DO (1990) NEXT
        DO FORGET #1
        PLEASE RETRIEVE .5 + ::4
        DO RESUME #1
(4761)  DO FORGET #1
        DO PETITION #813
        PLEASE RETRIEVE .5 + ::4
        DO RESUME #1

(4349)  DO STASH .5 + .50 + .51 + .52 + .53 + .54 + ::1 + ::2 + ::60 + ::61 + ::62
        DO (4049) NEXT
        PLEASE ::62 <- ::3
        DO .50 <- ::1~####9223372036854775808
        DO .51 <- ::2~####9223372036854775808
        DO ::60 <- ::1
        PLEASE .5 <- .50
        DO .5 <- "?'.5$#1'"~#1
        DO (4762) NEXT
        DO (4763) NEXT
(4762)  PLEASE (1990) NEXT
        DO FORGET #1
        DO (4430) NEXT
        DO (4763) NEXT
(4763)  PLEASE FORGET #1
        DO ::61 <- ::60
        DO ::60 <- ::2
        DO .5 <- .51
        PLEASE .5 <- "?'.5$#1'"~#1
        DO (4764) NEXT
        DO (4765) NEXT
(4764)  DO (1990) NEXT
        PLEASE FORGET #1
        DO (4430) NEXT
        DO (4765) NEXT
(4765)  DO FORGET #1
        PLEASE ::1 <- ::61
        DO ::2 <- ::60
        DO (4049) NEXT
        DO .52 <- ::4~#2
        PLEASE .50 <- "?'.50$.51'"~#1
        DO .51 <- ::3~####9223372036854775808
        DO ::60 <- ::3~####9223372036854775807
        DO .53 <- '::60~::60'~#1
        PLEASE .54 <- "?'.50$#1'"~#1
        DO .54 <- "V'.54$.53'"~#1
        DO .54 <- "&'.54$.51'"~#1
        DO .52 <- "V'.52$.54'"~#1
        PLEASE .53 <- "?'.52$#1'"~#1
        DO ::3 <- ::62
        DO ::4 <- '.52$.53'
        DO RETRIEVE .5 + .50 + .51 + .52 + .53 + .54 + ::1 + ::2 + ::60 + ::61 + ::62
        PLEASE RESUME #1

(4350)  DO STASH .5 + .50 + .51 + .52 + ::1 + ::2 + ::60 + ::61
        DO .50 <- ::1~####9223372036854775808
        DO .51 <- ::2~####9223372036854775808
        PLEASE ::60 <- ::1
        DO .5 <- .50
        DO .5 <- "?'.5$#1'"~#1
        DO (4766) NEXT
        PLEASE (4767) NEXT
(4766)  DO (1990) NEXT
        DO FORGET #1
        DO (4430) NEXT
        PLEASE (4767) NEXT
(4767)  DO FORGET #1
        DO ::61 <- ::60
        DO ::60 <- ::2
        PLEASE .5 <- .51
        DO .5 <- "?'.5$#1'"~#1
        DO (4768) NEXT
        DO (4769) NEXT
(4768)  PLEASE (1990) NEXT
        DO FORGET #1
        DO (4430) NEXT
        DO (4769) NEXT
(4769)  PLEASE FORGET #1
        DO ::1 <- ::61
        DO ::2 <- ::60
        DO (4050) NEXT
        PLEASE .50 <- "?'.50$.51'"~#1
        DO .52 <- ::3~####9223372036854775808
        DO .51 <- "?'.50$#1'"~#1
        DO .52 <- "&'.52$.51'"~#1
        PLEASE .5 <- .52
        DO (4770) NEXT
        DO (4771) NEXT
(4770)  DO (1990) NEXT
        PLEASE FORGET #1
        DO ::60 <- ::3
        DO .5 <- .50
        DO .5 <- "?'.5$#1'"~#1
        PLEASE (4772) NEXT
        DO (4773) NEXT
(4772)  DO (1990) NEXT
        DO FORGET #1
        PLEASE (4430) NEXT
        DO (4773) NEXT
(4773)  DO FORGET #1
        DO ::3 <- ::60
        PLEASE RETRIEVE .5 + .50 + .51 + .52 + ::1 + ::2 + ::60 + ::61
        DO RESUME #1
(4771)  DO FORGET #1
        DO PETITION #813
        PLEASE RETRIEVE .5 + .50 + .51 + .52 + ::1 + ::2 + ::60 + ::61
        DO RESUME #1
        DO RETRIEVE .5 + .50 + .51 + .52 + ::1 + ::2 + ::60 + ::61
        DO RESUME #1

(4360)  PLEASE STASH ::1 + ::2 + ::3 + :50 + :51 + ::60
        DO :50 <- ::1~####12297829382473034410
        DO :50 <- "?':50$##2147483648'"~'##0$##4294967295'
        DO :51 <- ::1~####6148914691236517205
        PLEASE ::60 <- :50$:51
        DO ::1 <- ::60
        DO :50 <- ::2~####12297829382473034410
        DO :50 <- "?':50$##2147483648'"~'##0$##4294967295'
        PLEASE :51 <- ::2~####6148914691236517205
        DO ::60 <- :50$:51
        DO ::2 <- ::60
        DO (4070) NEXT
        PLEASE ::60 <- ::3
        DO RETRIEVE ::1 + ::2 + ::3
        DO ::3 <- ::60
        DO RETRIEVE :50 + :51 + ::60
        PLEASE RESUME #1

(4500)  DO STASH .5 + :4
        DO (4509) NEXT
        DO .5 <- :4~#2
        PLEASE (4774) NEXT
        DO (4775) NEXT
(4774)  DO (1990) NEXT
        DO FORGET #1
        PLEASE RETRIEVE .5 + :4
        DO RESUME #1
(4775)  DO FORGET #1
        DO PETITION #813
        PLEASE RETRIEVE .5 + :4
        DO RESUME #1

(4509)  DO STASH .5 + .50 + .51 + :1 + :2 + :60 + :61 + :62
        DO :60 <- :1
        PLEASE :61 <- :2
        DO :62 <- #1
        DO .50 <- #0
        DO (4776) NEXT
(4776)  PLEASE FORGET #1
        DO .5 <- ':61~:61'~#1
        DO .5 <- "?'.5$#1'"~#1
        DO (4777) NEXT
        PLEASE (4778) NEXT
(4777)  DO (1990) NEXT
        DO FORGET #1
        DO .5 <- :61~#1
        PLEASE .5 <- "?'.5$#1'"~#1
        DO (4779) NEXT
        DO (4780) NEXT
(4779)  DO (1990) NEXT
        PLEASE FORGET #1
        DO :1 <- :62
        DO :2 <- :60
        DO (1549) NEXT
        PLEASE :62 <- :3
        DO .51 <- :4~#2
        DO .50 <- "V'.50$.51'"~#1
        DO (4780) NEXT
(4780)  PLEASE FORGET #1
        DO :61 <- :61~##4294967294
        DO .5 <- ':61~:61'~#1
        DO .5 <- "?'.5$#1'"~#1
        PLEASE (4781) NEXT
        DO (4778) NEXT
(4781)  DO (1990) NEXT
        DO FORGET #1
        PLEASE :1 <- :60
        DO :2 <- :60
        DO (1549) NEXT
        DO :60 <- :3
        PLEASE .51 <- :4~#2
        DO .50 <- "V'.50$.51'"~#1
        DO (4776) NEXT
(4778)  DO FORGET #1
        PLEASE :3 <- :62
        DO .51 <- "?'.50$#1'"~#1
        DO :4 <- '.50$.51'
        DO RETRIEVE .5 + .50 + .51 + :1 + :2 + :60 + :61 + :62
        PLEASE RESUME #1

(4510)  DO STASH .1 + .2 + .5 + :1 + :60 + :61 + :62 + ::1 + ::2 + ::3
        DO :60 <- :1
        DO :61 <- #0
        PLEASE :62 <- #32768
        DO (4782) NEXT
(4782)  DO FORGET #1
        DO .1 <- "V':61$:62'"~'##0$##4294967295'
        PLEASE .2 <- .1
        DO (1530) NEXT
        DO ::1 <- :60
        DO ::2 <- :1
        PLEASE (4070) NEXT
        DO .5 <- ::3~#2
        DO .5 <- "?'.5$#1'"~#1
        DO (4783) NEXT
        PLEASE (4784) NEXT
(4783)  DO (1990) NEXT
        DO FORGET #1
        DO :61 <- .1
        PLEASE (4784) NEXT
(4784)  DO FORGET #1
        DO :62 <- :62~##4294967294
        DO .5 <- ':62~:62'~#1
        PLEASE (4785) NEXT
        DO (4782) NEXT
(4785)  DO (1990) NEXT
        DO FORGET #1
        PLEASE :2 <- :61
        DO RETRIEVE .1 + .2 + .5 + :1 + :60 + :61 + :62 + ::1 + ::2 + ::3
        DO RESUME #1

(4520)  DO STASH :1 + :2 + :4 + :60 + :61
        PLEASE :60 <- :1
        DO :61 <- :2
        DO (1550) NEXT
        DO :1 <- :3
        PLEASE :2 <- :61
        DO (1549) NEXT
        DO :1 <- :60
        DO :2 <- :3
        PLEASE (1510) NEXT
        DO RETRIEVE :1 + :2 + :4 + :60 + :61
        DO RESUME #1

(4530)  DO STASH .5 + :1 + :2
        PLEASE (4786) NEXT
(4786)  DO FORGET #1
        DO .5 <- ':2~:2'~#1
        DO .5 <- "?'.5$#1'"~#1
        PLEASE (4787) NEXT
        DO (4788) NEXT
(4787)  DO (1990) NEXT
        DO FORGET #1
        PLEASE (4520) NEXT
        DO :1 <- :2
        DO :2 <- :3
        DO (4786) NEXT
(4788)  PLEASE FORGET #1
        DO :3 <- :1
        DO RETRIEVE .5 + :1 + :2
        DO RESUME #1

(4600)  PLEASE STASH .5 + ::4
        DO (4609) NEXT
        DO .5 <- ::4~#2
        DO (4789) NEXT
        PLEASE (4790) NEXT
(4789)  DO (1990) NEXT
        DO FORGET #1
        DO RETRIEVE .5 + ::4
        PLEASE RESUME #1
(4790)  DO FORGET #1
        DO PETITION #813
        DO RETRIEVE .5 + ::4
        PLEASE RESUME #1

(4609)  DO STASH .5 + .50 + .51 + ::1 + ::2 + ::60 + ::61 + ::62
        DO ::60 <- ::1
        DO ::61 <- ::2
        PLEASE ::62 <- #1
        DO .50 <- #0
        DO (4791) NEXT
(4791)  DO FORGET #1
        PLEASE .5 <- '::61~::61'~#1
        DO .5 <- "?'.5$#1'"~#1
        DO (4792) NEXT
        DO (4793) NEXT
(4792)  PLEASE (1990) NEXT
        DO FORGET #1
        DO .5 <- ::61~#1
        DO .5 <- "?'.5$#1'"~#1
        PLEASE (4794) NEXT
        DO (4795) NEXT
(4794)  DO (1990) NEXT
        DO FORGET #1
        PLEASE ::1 <- ::62
        DO ::2 <- ::60
        DO (4049) NEXT
        DO ::62 <- ::3
        PLEASE .51 <- ::4~#2
        DO .50 <- "V'.50$.51'"~#1
        DO (4795) NEXT
(4795)  DO FORGET #1
        PLEASE ::61 <- ::61~####18446744073709551614
        DO .5 <- '::61~::61'~#1
        DO .5 <- "?'.5$#1'"~#1
        DO (4796) NEXT
        PLEASE (4793) NEXT
(4796)  DO (1990) NEXT
        DO FORGET #1
        DO ::1 <- ::60
        PLEASE ::2 <- ::60
        DO (4049) NEXT
        DO ::60 <- ::3
        DO .51 <- ::4~#2
        PLEASE .50 <- "V'.50$.51'"~#1
        DO (4791) NEXT
(4793)  DO FORGET #1
        DO ::3 <- ::62
        PLEASE .51 <- "?'.50$#1'"~#1
        DO ::4 <- '.50$.51'
        DO RETRIEVE .5 + .50 + .51 + ::1 + ::2 + ::60 + ::61 + ::62
        DO RESUME #1

(4610)  PLEASE STASH .5 + :1 + :2 + :60 + :61 + :62 + ::1 + ::3 + ::60
        DO ::60 <- ::1
        DO :61 <- #0
        DO :62 <- ##2147483648
        PLEASE (4797) NEXT
(4797)  DO FORGET #1
        DO :60 <- "V':61$:62'"~'##0$##4294967295'
        DO :1 <- :60
        PLEASE :2 <- :60
        DO (4030) NEXT
        DO ::2 <- ::1
        DO ::1 <- ::60
        PLEASE (4070) NEXT
        DO .5 <- ::3~#2
        DO .5 <- "?'.5$#1'"~#1
        DO (4798) NEXT
        PLEASE (4799) NEXT
(4798)  DO (1990) NEXT
        DO FORGET #1
        DO :61 <- :60
        PLEASE (4799) NEXT
(4799)  DO FORGET #1
        DO :62 <- :62~##4294967294
        DO .5 <- ':62~:62'~#1
        PLEASE (4800) NEXT
        DO (4797) NEXT
(4800)  DO (1990) NEXT
        DO FORGET #1
        PLEASE ::2 <- :61
        DO RETRIEVE .5 + :1 + :2 + :60 + :61 + :62 + ::1 + ::3 + ::60
        DO RESUME #1

(4620)  DO STASH :56 + :57 + :58 + :59
        PLEASE (4440) NEXT
        DO ::3 <- :58$:59
        DO RETRIEVE :56 + :57 + :58 + :59
        DO RESUME #1

(4630)  PLEASE STASH .5 + ::1 + ::2
        DO (4801) NEXT
(4801)  DO FORGET #1
        DO .5 <- '::2~::2'~#1
        PLEASE .5 <- "?'.5$#1'"~#1
        DO (4802) NEXT
        DO (4803) NEXT
(4802)  DO (1990) NEXT
        PLEASE FORGET #1
        DO (4620) NEXT
        DO ::1 <- ::2
        DO ::2 <- ::3
        PLEASE (4801) NEXT
(4803)  DO FORGET #1
        DO ::3 <- ::1
        DO RETRIEVE .5 + ::1 + ::2
        PLEASE RESUME #1
