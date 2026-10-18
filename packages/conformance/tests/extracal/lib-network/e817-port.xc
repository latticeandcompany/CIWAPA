	DO ,1 <- #23
	DO ,1 SUB #1 <- #104
	DO ,1 SUB #2 <- #116
	PLEASE ,1 SUB #3 <- #116
	DO ,1 SUB #4 <- #112
	DO ,1 SUB #5 <- #58
	DO ,1 SUB #6 <- #47
	PLEASE ,1 SUB #7 <- #47
	DO ,1 SUB #8 <- #108
	DO ,1 SUB #9 <- #111
	DO ,1 SUB #10 <- #99
	PLEASE ,1 SUB #11 <- #97
	DO ,1 SUB #12 <- #108
	DO ,1 SUB #13 <- #104
	DO ,1 SUB #14 <- #111
	PLEASE ,1 SUB #15 <- #115
	DO ,1 SUB #16 <- #116
	DO ,1 SUB #17 <- #58
	DO ,1 SUB #18 <- #57
	PLEASE ,1 SUB #19 <- #57
	DO ,1 SUB #20 <- #57
	DO ,1 SUB #21 <- #57
	DO ,1 SUB #22 <- #57
	PLEASE ,1 SUB #23 <- #47
	DO (9100) NEXT
	DO GIVE UP
(10)	DO STASH .1 + .3
	PLEASE .1 <- #1
	DO (2310) NEXT
	DO RETRIEVE .1 + .3
	DO RESUME #1
(20)	PLEASE STASH .1 + .2 + .3 + :1
	DO .1 <- #1
	DO (2110) NEXT
	DO .2 <- #10
	PLEASE (2010) NEXT
	DO RETRIEVE .1 + .2 + .3 + :1
	DO RESUME #1
