	DO STASH ,2
	DO ,1 <- #2
	DO ,1 SUB #1 <- #97
	PLEASE ,1 SUB #2 <- #98
	DO ,2 <- #2
	DO ,2 SUB #1 <- #97
	DO ,2 SUB #2 <- #98
	PLEASE (3030) NEXT
	DO :1 <- .1
	DO (20) NEXT
	DO ,1 <- #1
	PLEASE ,1 SUB #1 <- #98
	DO ,2 <- #2
	DO ,2 SUB #1 <- #97
	DO ,2 SUB #2 <- #98
	PLEASE (3030) NEXT
	DO :1 <- .1
	DO (20) NEXT
	DO ,1 <- #2
	PLEASE ,1 SUB #1 <- #97
	DO ,1 SUB #2 <- #98
	DO ,2 <- #3
	DO ,2 SUB #1 <- #97
	PLEASE ,2 SUB #2 <- #98
	DO ,2 SUB #3 <- #99
	DO (3030) NEXT
	DO :1 <- .1
	PLEASE (20) NEXT
	DO ,1 <- #3
	DO ,1 SUB #1 <- #97
	DO ,1 SUB #2 <- #98
	PLEASE ,1 SUB #3 <- #99
	DO ,2 <- #2
	DO ,2 SUB #1 <- #97
	DO ,2 SUB #2 <- #98
	PLEASE (3030) NEXT
	DO :1 <- .1
	DO (20) NEXT
	DO ,1 <- #3
	PLEASE ,1 SUB #1 <- #97
	DO ,1 SUB #2 <- #98
	DO ,1 SUB #3 <- #99
	DO ,2 <- #1
	PLEASE ,2 SUB #1 <- #120
	DO :1 <- #7
	DO (3040) NEXT
	DO (20) NEXT
	PLEASE :1 <- .1
	DO (20) NEXT
	DO RETRIEVE ,2
	DO ,1 <- #3
	PLEASE ,1 SUB #1 <- #97
	DO ,1 SUB #2 <- #98
	DO ,1 SUB #3 <- #99
	DO (3040) NEXT
	PLEASE (20) NEXT
	DO :1 <- .1
	DO (20) NEXT
	DO :1 <- #0
	PLEASE (3050) NEXT
	DO (10) NEXT
	DO ,1 <- #10
	DO ,1 SUB #1 <- #52
	PLEASE ,1 SUB #2 <- #50
	DO ,1 SUB #3 <- #57
	DO ,1 SUB #4 <- #52
	DO ,1 SUB #5 <- #57
	PLEASE ,1 SUB #6 <- #54
	DO ,1 SUB #7 <- #55
	DO ,1 SUB #8 <- #50
	DO ,1 SUB #9 <- #57
	PLEASE ,1 SUB #10 <- #54
	DO :1 <- #5
	DO (3060) NEXT
	DO :2 <- :1
	PLEASE :1 <- .1
	DO (20) NEXT
	DO :1 <- :2
	DO (20) NEXT
	PLEASE PETITION #3001
	DO (3060) NEXT
	DO :1 <- .1
	DO (20) NEXT
	PLEASE ,1 <- #13
	DO ,1 SUB #1 <- #48
	DO ,1 SUB #2 <- #48
	DO ,1 SUB #3 <- #48
	PLEASE ,1 SUB #4 <- #52
	DO ,1 SUB #5 <- #50
	DO ,1 SUB #6 <- #57
	DO ,1 SUB #7 <- #52
	PLEASE ,1 SUB #8 <- #57
	DO ,1 SUB #9 <- #54
	DO ,1 SUB #10 <- #55
	DO ,1 SUB #11 <- #50
	PLEASE ,1 SUB #12 <- #57
	DO ,1 SUB #13 <- #53
	DO (3060) NEXT
	DO (20) NEXT
	PLEASE :1 <- .1
	DO (20) NEXT
	DO STASH ,2
	DO ,1 <- #2
	PLEASE ,1 SUB #1 <- #97
	DO ,1 SUB #2 <- #98
	DO RETRIEVE ,2
	DO (3010) NEXT
	PLEASE (10) NEXT
	DO STASH ,1
	DO PETITION #3001
	DO ,2 <- #2
	PLEASE ,2 SUB #1 <- #99
	DO ,2 SUB #2 <- #100
	DO (3010) NEXT
	DO (10) NEXT
	PLEASE RETRIEVE ,1
	DO ,1 <- #2
	DO ,1 SUB #1 <- #226
	DO ,1 SUB #2 <- #130
	PLEASE (3080) NEXT
	DO (3070) NEXT
	DO (10) NEXT
	DO ,1 <- #4
	PLEASE ,1 SUB #1 <- #245
	DO ,1 SUB #2 <- #128
	DO ,1 SUB #3 <- #128
	DO ,1 SUB #4 <- #128
	PLEASE (3080) NEXT
	DO (3070) NEXT
	DO (10) NEXT
	DO ,1 <- #1
	PLEASE ,1 SUB #1 <- #56320
	DO (3070) NEXT
	DO (10) NEXT
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
