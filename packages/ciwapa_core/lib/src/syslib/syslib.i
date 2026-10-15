(1000)  PLEASE STASH .4 + .5
        DO (1009) NEXT
        DO .5 <- .4~#2
        DO (1001) NEXT
DOUBLE OR SINGLE PRECISION OVERFLOW
(1001)  DO (1990) NEXT
        DO FORGET #1
        PLEASE RETRIEVE .4 + .5
        PLEASE RESUME #1

(1009)  PLEASE STASH .6 + .7 + .8 + .9 + .10
        DO .6 <- .1~#43690
        DO .7 <- .1~#21845
        DO .8 <- .2~#43690
        DO .9 <- .2~#21845
        DO (1600) NEXT
        DO .3 <- '.6$.7'~#65535
        DO .4 <- .7~#256
        DO .4 <- "?'.4$#1'"~#3
        PLEASE RETRIEVE .6 + .7 + .8 + .9 + .10
        PLEASE RESUME #1

(1010)  PLEASE STASH .6 + .7 + .8 + .9 + .10
        DO .6 <- "?'.1$#65535'"~'#0$#65535'
        DO .7 <- .6~#21845
        DO .6 <- .6~#43690
        DO .8 <- .2~#43690
        DO .9 <- .2~#21845
        DO (1600) NEXT
        DO .3 <- '.6$.7'~#65535
        DO .3 <- "?'.3$#65535'"~'#0$#65535'
        PLEASE RETRIEVE .6 + .7 + .8 + .9 + .10
        PLEASE RESUME #1

(1020)  PLEASE STASH .6 + .7 + .8 + .9 + .10
        DO .6 <- .1~#43690
        DO .7 <- .1~#21845
        DO .8 <- #0
        DO .9 <- #1
        DO (1600) NEXT
        DO .1 <- '.6$.7'~#65535
        PLEASE RETRIEVE .6 + .7 + .8 + .9 + .10
        PLEASE RESUME #1

(1030)  PLEASE STASH .4 + .5
        DO (1039) NEXT
        DO .5 <- .4~#2
        DO (1031) NEXT
DOUBLE OR SINGLE PRECISION OVERFLOW
(1031)  DO (1990) NEXT
        DO FORGET #1
        PLEASE RETRIEVE .4 + .5
        PLEASE RESUME #1

(1039)  PLEASE STASH :1
        DO (1530) NEXT
        DO .3 <- :1~#65535
        DO .4 <- :1~'#65280$#65280'
        DO .4 <- '.4~.4'~#1
        DO .4 <- "?'.4$#1'"~#3
        PLEASE RETRIEVE :1
        PLEASE RESUME #1

(1040)  PLEASE STASH :1 + :2 + :3
        DO :1 <- .1
        DO :2 <- .2
        DO (1550) NEXT
        DO .3 <- :3
        PLEASE RETRIEVE :1 + :2 + :3
        PLEASE RESUME #1

(1050)  PLEASE STASH :2 + :3 + .5
        DO :2 <- .1
        DO (1550) NEXT
        DO .5 <- :3~'#65280$#65280'
        DO .5 <- '.5~.5'~#1
        DO (1051) NEXT
DOUBLE OR SINGLE PRECISION OVERFLOW
(1051)  DO (1990) NEXT
        DO FORGET #1
        DO .2 <- :3
        PLEASE RETRIEVE :2 + :3 + .5
        PLEASE RESUME #1

(1060)  DO .3 <- "V'.1$.2'"~'#0$#65535'
        PLEASE RESUME #1

(1070)  DO .3 <- "&'.1$.2'"~'#0$#65535'
        PLEASE RESUME #1

(1080)  DO .3 <- "?'.1$.2'"~'#0$#65535'
        PLEASE RESUME #1

(1500)  PLEASE STASH :4 + .5
        DO (1509) NEXT
        DO .5 <- :4~#2
        DO (1501) NEXT
DOUBLE OR SINGLE PRECISION OVERFLOW
(1501)  DO (1990) NEXT
        DO FORGET #1
        PLEASE RETRIEVE :4 + .5
        PLEASE RESUME #1

(1509)  PLEASE STASH .6 + .7 + .8 + .9 + .10
        DO .6 <- :1~'#65535$#0'
        DO .7 <- :1~'#0$#65535'
        DO .8 <- :2~'#65535$#0'
        DO .9 <- :2~'#0$#65535'
        DO (1600) NEXT
        DO :3 <- .6$.7
        DO :4 <- "?'.10$#1'"~#3
        PLEASE RETRIEVE .6 + .7 + .8 + .9 + .10
        PLEASE RESUME #1

(1510)  PLEASE STASH .6 + .7 + .8 + .9 + .10
        DO .6 <- :1~'#65535$#0'
        DO .7 <- :1~'#0$#65535'
        DO .6 <- "?'.6$#65535'"~'#0$#65535'
        DO .7 <- "?'.7$#65535'"~'#0$#65535'
        DO .8 <- :2~'#65535$#0'
        DO .9 <- :2~'#0$#65535'
        DO (1600) NEXT
        DO .6 <- "?'.6$#65535'"~'#0$#65535'
        DO .7 <- "?'.7$#65535'"~'#0$#65535'
        DO :3 <- .6$.7
        PLEASE RETRIEVE .6 + .7 + .8 + .9 + .10
        PLEASE RESUME #1

(1520)  PLEASE STASH .3 + .6 + .7
        DO .3 <- .1~#43690
        DO (1525) NEXT
        DO .6 <- .2~#43690
        DO .6 <- "V'.3$.6'"~'#0$#65535'
        DO .3 <- .1~#21845
        DO (1525) NEXT
        DO .7 <- .2~#21845
        DO .7 <- "V'.3$.7'"~'#0$#65535'
        DO :1 <- .6$.7
        PLEASE RETRIEVE .3 + .6 + .7
        PLEASE RESUME #1

(1525)  DO .3 <- '.3$#0'~'#32767$#1'
        DO .3 <- '.3$#0'~'#32767$#1'
        DO .3 <- '.3$#0'~'#32767$#1'
        DO .3 <- '.3$#0'~'#32767$#1'
        DO .3 <- '.3$#0'~'#32767$#1'
        DO .3 <- '.3$#0'~'#32767$#1'
        DO .3 <- '.3$#0'~'#32767$#1'
        DO .3 <- '.3$#0'~'#32767$#1'
        PLEASE RESUME #1

(1530)  PLEASE STASH .6 + .7 + .8 + .9 + .10 + .12 + .13 + .14 + :6
        DO .12 <- .1~#43690
        DO .13 <- .1~#21845
        DO :6 <- .2
        DO (1700) NEXT
        DO :1 <- .6$.7
        PLEASE RETRIEVE .6 + .7 + .8 + .9 + .10 + .12 + .13 + .14 + :6
        PLEASE RESUME #1

(1540)  PLEASE STASH :4 + .5
        DO (1549) NEXT
        DO .5 <- :4~#2
        DO (1541) NEXT
DOUBLE OR SINGLE PRECISION OVERFLOW
(1541)  DO (1990) NEXT
        DO FORGET #1
        PLEASE RETRIEVE :4 + .5
        PLEASE RESUME #1

(1549)  PLEASE STASH .6 + .7 + .8 + .9 + .10 + .12 + .13 + .14 + :6
        DO .12 <- :1~'#65535$#0'
        DO .13 <- :1~'#0$#65535'
        DO :6 <- :2
        DO (1700) NEXT
        DO :3 <- .6$.7
        DO :4 <- "?'.14$#1'"~#3
        PLEASE RETRIEVE .6 + .7 + .8 + .9 + .10 + .12 + .13 + .14 + :6
        PLEASE RESUME #1

(1550)  PLEASE STASH .6 + .7 + .8 + .9 + .10 + .12 + .13 + .14 + .15 + .16 + .17
        DO .12 <- :1~'#65535$#0'
        DO .13 <- :1~'#0$#65535'
        DO .16 <- :2~'#65535$#0'
        DO .17 <- :2~'#0$#65535'
        DO (1800) NEXT
        DO :3 <- .14$.15
        PLEASE RETRIEVE .6 + .7 + .8 + .9 + .10 + .12 + .13 + .14 + .15 + .16 + .17
        PLEASE RESUME #1

(1600)  PLEASE STASH .5 + .11
        DO .10 <- #0
        DO (1601) NEXT
(1601)  DO FORGET #1
        DO .11 <- "&'.6$.8'"~'#0$#65535'
        DO .6 <- "?'.6$.8'"~'#0$#65535'
        DO .8 <- "&'.7$.9'"~'#0$#65535'
        DO .7 <- "?'.7$.9'"~'#0$#65535'
        DO .9 <- '.11$#0'~'#32767$#1'
        DO .10 <- "V'.10$.11'"~'#0$#65535'
        DO .5 <- "'.8$.9'~'.8$.9'"~#1
        DO (1602) NEXT
        DO (1601) NEXT
(1602)  DO (1990) NEXT
        DO FORGET #1
        DO .10 <- .10~#32768
        PLEASE RETRIEVE .5 + .11
        PLEASE RESUME #1

(1700)  PLEASE STASH .5 + .15 + .16
        DO .6 <- #0
        DO .7 <- #0
        DO .14 <- #0
        DO (1701) NEXT
(1701)  DO FORGET #1
        DO .15 <- :6~#1
        DO .15 <- .15$.15
        DO .15 <- .15$.15
        DO .15 <- .15$.15
        DO .15 <- .15$.15
        DO .8 <- .12~.15
        DO .9 <- .13~.15
        DO (1600) NEXT
        DO .14 <- "V'.14$.10'"~#1
        DO :6 <- :6~'#65535$#65534'
        DO .5 <- ':6~:6'~#1
        DO .16 <- .12~#32768
        DO .16 <- .16~.5
        DO .14 <- "V'.14$.16'"~#1
        DO .16 <- .12
        DO .12 <- .13
        DO .13 <- '.16$#0'~'#32767$#1'
        DO (1702) NEXT
        DO (1701) NEXT
(1702)  DO (1990) NEXT
        DO FORGET #1
        PLEASE RETRIEVE .5 + .15 + .16
        PLEASE RESUME #1

(1800)  PLEASE STASH .5 + .18 + .19 + .20 + .21 + .22 + :7
        DO .14 <- #0
        DO .15 <- #0
        DO .5 <- "'.16$.17'~'.16$.17'"~#1
        DO (1804) NEXT
        DO .6 <- "?'.16$#65535'"~'#0$#65535'
        DO .7 <- "?'.17$#65535'"~'#0$#65535'
        DO .8 <- #0
        DO .9 <- #1
        DO (1600) NEXT
        DO .16 <- .6
        DO .17 <- .7
        DO .6 <- #0
        DO .7 <- #0
        DO :7 <- '#65535$#65535'
        DO (1801) NEXT
(1801)  DO FORGET #1
        DO .20 <- .6~#32768
        DO .21 <- .12~#32768
        DO .22 <- .6
        DO .6 <- .7
        DO .7 <- '.22$.21'~'#32767$#1'
        DO .22 <- .12
        DO .12 <- .13
        DO .13 <- '.22$#0'~'#32767$#1'
        DO .18 <- .6
        DO .19 <- .7
        DO .8 <- .16
        DO .9 <- .17
        DO (1600) NEXT
        DO .21 <- "V'.10$.20'"~#1
        DO .5 <- .21
        DO (1803) NEXT
        DO .22 <- .14
        DO .14 <- .15
        DO .15 <- '.22$.21'~'#32767$#1'
        DO :7 <- :7~'#65535$#65534'
        DO .5 <- ':7~:7'~#1
        DO (1802) NEXT
        DO (1801) NEXT
(1802)  DO (1990) NEXT
        DO FORGET #1
        PLEASE RETRIEVE .5 + .18 + .19 + .20 + .21 + .22 + :7
        PLEASE RESUME #1
(1803)  DO (1990) NEXT
        DO .6 <- .18
        DO .7 <- .19
        PLEASE RESUME #1
(1804)  DO (1990) NEXT
        DO FORGET #1
        PLEASE RETRIEVE .5 + .18 + .19 + .20 + .21 + .22 + :7
        PLEASE RESUME #1

(1900)  DO .1 <- #0
        DO %50 .1 <- "V'.1$#1'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#2'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#4'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#8'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#16'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#32'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#64'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#128'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#256'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#512'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#1024'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#2048'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#4096'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#8192'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#16384'"~'#0$#65535'
        DO %50 .1 <- "V'.1$#32768'"~'#0$#65535'
        PLEASE RESUME #1

(1910)  PLEASE STASH .1 + .5 + .6 + :1 + :2 + :3 + :4
        DO .2 <- .1
        DO :1 <- #0
        DO .6 <- #4095
        DO (1911) NEXT
(1911)  DO FORGET #1
        DO .5 <- '.6~.6'~#1
        DO (1912) NEXT
        DO (1900) NEXT
        DO :2 <- .1
        DO (1509) NEXT
        DO :1 <- :3
        DO .6 <- .6~#65534
        DO (1911) NEXT
(1912)  DO (1990) NEXT
        DO FORGET #1
        DO :2 <- #12
        DO (1550) NEXT
        DO .1 <- :3
        DO (1530) NEXT
        DO :2 <- #32767
        DO (1509) NEXT
        DO :1 <- :3
        DO :2 <- #65535
        DO (1550) NEXT
        DO .2 <- :3
        PLEASE RETRIEVE .1 + .5 + .6 + :1 + :2 + :3 + :4
        PLEASE RESUME #1

(1990)  PLEASE RESUME "?'.5$#1'"~#3
