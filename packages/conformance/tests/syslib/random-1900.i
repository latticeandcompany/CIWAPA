DO .2 <- #0
DO .3 <- #65535
DO .4 <- #9
DO :1 <- #8
DO .9 <- #65535
DO (10) NEXT
(10) DO FORGET #1
DO (1900) NEXT
PLEASE DO .2 <- "V'.2$.1'"~'#0$#65535'
DO .3 <- "&'.3$.1'"~'#0$#65535'
DO (1900) NEXT
PLEASE DO .2 <- "V'.2$.1'"~'#0$#65535'
DO .3 <- "&'.3$.1'"~'#0$#65535'
DO (1900) NEXT
PLEASE DO .2 <- "V'.2$.1'"~'#0$#65535'
DO .3 <- "&'.3$.1'"~'#0$#65535'
DO (1900) NEXT
PLEASE DO .2 <- "V'.2$.1'"~'#0$#65535'
DO .3 <- "&'.3$.1'"~'#0$#65535'
DO .9 <- .9~#65534
DO .8 <- '.9~.9'~#1
PLEASE DO .8 <- "?'.8$#1'"~#3
DO (20) NEXT
DO (10) NEXT
(20) DO (30) NEXT
DO FORGET #1
DO READ OUT .2 + .3 + .4 + :1
PLEASE GIVE UP
(30) DO RESUME .8
