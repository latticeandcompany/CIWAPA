	DO ,1 <- #16
	DO ,1 SUB #1 <- #67
	DO ,1 SUB #2 <- #73
	PLEASE ,1 SUB #3 <- #87
	DO ,1 SUB #4 <- #65
	DO ,1 SUB #5 <- #80
	DO ,1 SUB #6 <- #65
	PLEASE ,1 SUB #7 <- #95
	DO ,1 SUB #8 <- #84
	DO ,1 SUB #9 <- #69
	DO ,1 SUB #10 <- #83
	PLEASE ,1 SUB #11 <- #84
	DO ,1 SUB #12 <- #95
	DO ,1 SUB #13 <- #80
	DO ,1 SUB #14 <- #79
	PLEASE ,1 SUB #15 <- #82
	DO ,1 SUB #16 <- #84
	DO (8020) NEXT
	DO ,1 <- #17
	PLEASE ,1 SUB #1 <- #104
	DO ,1 SUB #2 <- #116
	DO ,1 SUB #3 <- #116
	DO ,1 SUB #4 <- #112
	PLEASE ,1 SUB #5 <- #58
	DO ,1 SUB #6 <- #47
	DO ,1 SUB #7 <- #47
	DO ,1 SUB #8 <- #108
	PLEASE ,1 SUB #9 <- #111
	DO ,1 SUB #10 <- #99
	DO ,1 SUB #11 <- #97
	DO ,1 SUB #12 <- #108
	PLEASE ,1 SUB #13 <- #104
	DO ,1 SUB #14 <- #111
	DO ,1 SUB #15 <- #115
	DO ,1 SUB #16 <- #116
	PLEASE ,1 SUB #17 <- #58
	DO (3010) NEXT
	DO ,2 <- #5
	DO ,2 SUB #1 <- #47
	PLEASE ,2 SUB #2 <- #101
	DO ,2 SUB #3 <- #99
	DO ,2 SUB #4 <- #104
	DO ,2 SUB #5 <- #111
	PLEASE (3010) NEXT
	DO ,2 <- #4
	DO ,2 SUB #1 <- #112
	DO ,2 SUB #2 <- #105
	PLEASE ,2 SUB #3 <- #110
	DO ,2 SUB #4 <- #103
	DO (9110) NEXT
	DO :1 <- .3
	PLEASE (20) NEXT
	DO :1 <- .1
	DO (20) NEXT
	DO (10) NEXT
	PLEASE GIVE UP
(10)	DO STASH .1 + .3
	DO .1 <- #1
	DO (2310) NEXT
	PLEASE RETRIEVE .1 + .3
	DO RESUME #1
(20)	DO STASH .1 + .2 + .3 + :1
	DO .1 <- #1
	PLEASE (2110) NEXT
	DO .2 <- #10
	DO (2010) NEXT
	DO RETRIEVE .1 + .2 + .3 + :1
	PLEASE RESUME #1
