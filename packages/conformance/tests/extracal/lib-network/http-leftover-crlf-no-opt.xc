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
	DO PETITION #3001
	PLEASE (3010) NEXT
	DO (3060) NEXT
	DO .1 <- :1
	DO ,1 <- #9
	PLEASE ,1 SUB #1 <- #108
	DO ,1 SUB #2 <- #111
	DO ,1 SUB #3 <- #99
	DO ,1 SUB #4 <- #97
	PLEASE ,1 SUB #5 <- #108
	DO ,1 SUB #6 <- #104
	DO ,1 SUB #7 <- #111
	DO ,1 SUB #8 <- #115
	PLEASE ,1 SUB #9 <- #116
	DO (9000) NEXT
	DO .7 <- .2
	DO ,1 <- #27
	PLEASE ,1 SUB #1 <- #71
	DO ,1 SUB #2 <- #69
	DO ,1 SUB #3 <- #84
	DO ,1 SUB #4 <- #32
	PLEASE ,1 SUB #5 <- #47
	DO ,1 SUB #6 <- #120
	DO ,1 SUB #7 <- #32
	DO ,1 SUB #8 <- #72
	PLEASE ,1 SUB #9 <- #84
	DO ,1 SUB #10 <- #84
	DO ,1 SUB #11 <- #80
	DO ,1 SUB #12 <- #47
	PLEASE ,1 SUB #13 <- #49
	DO ,1 SUB #14 <- #46
	DO ,1 SUB #15 <- #49
	DO ,1 SUB #16 <- #13
	PLEASE ,1 SUB #17 <- #10
	DO ,1 SUB #18 <- #13
	DO ,1 SUB #19 <- #10
	DO ,1 SUB #20 <- #108
	PLEASE ,1 SUB #21 <- #101
	DO ,1 SUB #22 <- #102
	DO ,1 SUB #23 <- #116
	DO ,1 SUB #24 <- #111
	PLEASE ,1 SUB #25 <- #118
	DO ,1 SUB #26 <- #101
	DO ,1 SUB #27 <- #114
	DO .1 <- .7
	PLEASE (2300) NEXT
	DO (40) NEXT
(40)	DO FORGET #1
	DO .1 <- .7
	PLEASE (2000) NEXT
	DO .5 <- .3~#2
	DO (47) NEXT
	DO (48) NEXT
(47)	PLEASE (1990) NEXT
	DO FORGET #1
	DO .1 <- #1
	DO (2010) NEXT
	PLEASE (40) NEXT
(48)	DO FORGET #1
	DO .1 <- #1
	DO .2 <- #10
	PLEASE (2010) NEXT
	DO .1 <- .7
	DO (2030) NEXT
	DO ,1 <- #16
	PLEASE ,1 SUB #1 <- #67
	DO ,1 SUB #2 <- #73
	DO ,1 SUB #3 <- #87
	DO ,1 SUB #4 <- #65
	PLEASE ,1 SUB #5 <- #80
	DO ,1 SUB #6 <- #65
	DO ,1 SUB #7 <- #95
	DO ,1 SUB #8 <- #84
	PLEASE ,1 SUB #9 <- #69
	DO ,1 SUB #10 <- #83
	DO ,1 SUB #11 <- #84
	DO ,1 SUB #12 <- #95
	PLEASE ,1 SUB #13 <- #80
	DO ,1 SUB #14 <- #79
	DO ,1 SUB #15 <- #82
	DO ,1 SUB #16 <- #84
	PLEASE (8020) NEXT
	DO ,1 <- #17
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
	DO (3010) NEXT
	PLEASE ,2 <- #2
	DO ,2 SUB #1 <- #47
	DO ,2 SUB #2 <- #121
	DO (3010) NEXT
	PLEASE (9100) NEXT
	DO :1 <- .3
	DO (20) NEXT
	DO :1 <- .1
	PLEASE (20) NEXT
	DO (10) NEXT
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
