	DO .1 <- #0
	DO (9010) NEXT
	DO .4 <- .2
	PLEASE :1 <- .3
	DO (20) NEXT
	DO .1 <- .4
	DO (9030) NEXT
	PLEASE .5 <- .2
	DO ,1 <- #9
	DO ,1 SUB #1 <- #108
	DO ,1 SUB #2 <- #111
	PLEASE ,1 SUB #3 <- #99
	DO ,1 SUB #4 <- #97
	DO ,1 SUB #5 <- #108
	DO ,1 SUB #6 <- #104
	PLEASE ,1 SUB #7 <- #111
	DO ,1 SUB #8 <- #115
	DO ,1 SUB #9 <- #116
	DO .1 <- .5
	PLEASE (9000) NEXT
	DO .6 <- .2
	DO :1 <- .3
	DO (20) NEXT
	PLEASE ,1 <- #5
	DO ,1 SUB #1 <- #104
	DO ,1 SUB #2 <- #101
	DO ,1 SUB #3 <- #108
	PLEASE ,1 SUB #4 <- #108
	DO ,1 SUB #5 <- #111
	DO .1 <- .6
	DO (2310) NEXT
	PLEASE .1 <- .4
	DO (9020) NEXT
	DO .7 <- .2
	DO :1 <- .3
	PLEASE (20) NEXT
	DO .1 <- .7
	DO (2200) NEXT
	DO (2310) NEXT
	PLEASE (2030) NEXT
	DO .1 <- .6
	DO (2200) NEXT
	DO .1 <- #1
	PLEASE (2310) NEXT
	DO .1 <- .6
	DO (2200) NEXT
	DO :1 <- .3
	PLEASE (20) NEXT
	DO .1 <- .6
	DO (2030) NEXT
	DO .1 <- .4
	PLEASE (2030) NEXT
	DO :1 <- .3
	DO (20) NEXT
	DO GIVE UP
(10)	PLEASE STASH .1 + .3
	DO .1 <- #1
	DO (2310) NEXT
	DO RETRIEVE .1 + .3
	PLEASE RESUME #1
(20)	DO STASH .1 + .2 + .3 + :1
	DO .1 <- #1
	DO (2110) NEXT
	PLEASE .2 <- #10
	DO (2010) NEXT
	DO RETRIEVE .1 + .2 + .3 + :1
	DO RESUME #1
