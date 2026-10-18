	DO ,1 <- #12
	DO ,1 SUB #1 <- #49
	DO ,1 SUB #2 <- #101
	PLEASE ,1 SUB #3 <- #52
	DO ,1 SUB #4 <- #50
	DO ,1 SUB #5 <- #57
	DO ,1 SUB #6 <- #52
	PLEASE ,1 SUB #7 <- #57
	DO ,1 SUB #8 <- #54
	DO ,1 SUB #9 <- #55
	DO ,1 SUB #10 <- #50
	PLEASE ,1 SUB #11 <- #57
	DO ,1 SUB #12 <- #54
	DO (7090) NEXT
	DO GIVE UP
(20)	PLEASE STASH .1 + .2 + .3 + :1
	DO .1 <- #1
	DO (2110) NEXT
	DO .2 <- #10
	PLEASE (2010) NEXT
	DO RETRIEVE .1 + .2 + .3 + :1
	DO RESUME #1
(10)	DO STASH .1 + .3
	PLEASE .1 <- #1
	DO (2310) NEXT
	DO RETRIEVE .1 + .3
	DO RESUME #1
