NOTE The INTERCAL Blog, INTERCAL on Interstates' sample application. Build it with
ioi-llvm build -s --no-random-bug blog.xc -o blog, then gross --static public --database
sqlite:./blog.db ./blog. Everything up to the first statement is a comment.

PLEASE COME FROM (16000) WITH ROUTE "/blog"
DO NOTE the list of posts: a header, one fragment per post, and a footer.
DO (500) NEXT
(10) DO READ OUT #0 WITH TEMPLATE "templates/header.html"
PLEASE ;49221 <- 'FROM DATABASE #1~#1$#2'
DO (16210) NEXT
DO NOTE .5 counts from one to the number of posts; .4 is one past the last.
DO .1 <- :1
PLEASE (1020) NEXT
DO .4 <- .1
DO .5 <- #1
DO NOTE with no posts at all, the loop renders nothing and stops at once.
PLEASE .3 <- '?.5$.4'~'#0$#65535'
DO .6 <- '.3~.3'~#1
DO .7 <- '?.6$#1'~#1
DO ABSTAIN .7 FROM (20)
PLEASE ABSTAIN .7 FROM (98)
(98) DO COME FROM (99)
DO ;49221 <- 'FROM DATABASE #1~#1$#2' SUB .5
(20) DO READ OUT #2 WITH TEMPLATE "templates/item.html"
PLEASE .1 <- .5
DO (1020) NEXT
DO .5 <- .1
DO NOTE past the last post, the loop abstains from coming back.
PLEASE .3 <- '?.5$.4'~'#0$#65535'
DO .6 <- '.3~.3'~#1
DO .7 <- '?.6$#1'~#1
DO ABSTAIN .7 FROM (98)
(99) PLEASE .7 <- #0
DO READ OUT #0 WITH TEMPLATE "templates/footer.html"
DO GIVE UP
DO COME FROM (20) WITH ROUTE "/blog/post/:id"
PLEASE NOTE one post, reachable only from the list, which links it.
DO (500) NEXT
DO ;49221 <- 'FROM DATABASE #1~#2$#3' HAVING #1 ;4400 SUB #1
DO (16210) NEXT
PLEASE .3 <- :1
DO .6 <- '.3~.3'~#1
DO .7 <- '?.6$#1'~#1
DO NOTE found: skip the not-found lines. missing: skip the post.
PLEASE ABSTAIN .6 FROM (30)
DO ABSTAIN .6 FROM (31)
DO ABSTAIN .7 FROM (32)
DO .1 <- #404
(30) PLEASE (16100) NEXT
(31) DO READ OUT #0 WITH TEMPLATE "templates/missing.html"
(32) DO READ OUT #2 WITH TEMPLATE "templates/post.html"
DO GIVE UP
PLEASE COME FROM (16000) WITH ROUTE "/blog/new"
DO NOTE the form for a new post.
(40) DO READ OUT #0 WITH TEMPLATE "templates/new.html"
DO GIVE UP
PLEASE COME FROM (40) WITH ROUTE "/blog/create"
DO NOTE the form posts here, and only from its own page.
DO (500) NEXT
DO ,1 <- #5
PLEASE ,1 SUB #1 <- #116
DO ,1 SUB #2 <- #105
DO ,1 SUB #3 <- #116
DO ,1 SUB #4 <- #108
PLEASE ,1 SUB #5 <- #101
DO (16050) NEXT
DO ;49221 SUB #1 <- ,2
DO ,1 <- #4
PLEASE ,1 SUB #1 <- #98
DO ,1 SUB #2 <- #111
DO ,1 SUB #3 <- #100
DO ,1 SUB #4 <- #121
PLEASE (16050) NEXT
DO ,1 <- ;49221 SUB #1
DO INTO DATABASE #1~#2$#3 <- ,1 + ,2
DO ,1 <- #5
PLEASE ,1 SUB #1 <- #47
DO ,1 SUB #2 <- #98
DO ,1 SUB #3 <- #108
DO ,1 SUB #4 <- #111
PLEASE ,1 SUB #5 <- #103
DO (16130) NEXT
DO GIVE UP
DO COME FROM (16000)
PLEASE NOTE anything else goes to the list.
DO ,1 <- #5
DO ,1 SUB #1 <- #47
DO ,1 SUB #2 <- #98
PLEASE ,1 SUB #3 <- #108
DO ,1 SUB #4 <- #111
DO ,1 SUB #5 <- #103
DO (16130) NEXT
PLEASE GIVE UP
DO NOTE the table, made the first time any page needs it.
(500) DO ,1 <- #98
DO ,1 SUB #1 <- #67
PLEASE ,1 SUB #2 <- #82
DO ,1 SUB #3 <- #69
DO ,1 SUB #4 <- #65
DO ,1 SUB #5 <- #84
PLEASE ,1 SUB #6 <- #69
DO ,1 SUB #7 <- #32
DO ,1 SUB #8 <- #84
DO ,1 SUB #9 <- #65
PLEASE ,1 SUB #10 <- #66
DO ,1 SUB #11 <- #76
DO ,1 SUB #12 <- #69
DO ,1 SUB #13 <- #32
PLEASE ,1 SUB #14 <- #73
DO ,1 SUB #15 <- #70
DO ,1 SUB #16 <- #32
DO ,1 SUB #17 <- #78
PLEASE ,1 SUB #18 <- #79
DO ,1 SUB #19 <- #84
DO ,1 SUB #20 <- #32
DO ,1 SUB #21 <- #69
PLEASE ,1 SUB #22 <- #88
DO ,1 SUB #23 <- #73
DO ,1 SUB #24 <- #83
DO ,1 SUB #25 <- #84
PLEASE ,1 SUB #26 <- #83
DO ,1 SUB #27 <- #32
DO ,1 SUB #28 <- #112
DO ,1 SUB #29 <- #111
PLEASE ,1 SUB #30 <- #115
DO ,1 SUB #31 <- #116
DO ,1 SUB #32 <- #115
DO ,1 SUB #33 <- #32
PLEASE ,1 SUB #34 <- #40
DO ,1 SUB #35 <- #105
DO ,1 SUB #36 <- #100
DO ,1 SUB #37 <- #32
PLEASE ,1 SUB #38 <- #73
DO ,1 SUB #39 <- #78
DO ,1 SUB #40 <- #84
DO ,1 SUB #41 <- #69
PLEASE ,1 SUB #42 <- #71
DO ,1 SUB #43 <- #69
DO ,1 SUB #44 <- #82
DO ,1 SUB #45 <- #32
PLEASE ,1 SUB #46 <- #80
DO ,1 SUB #47 <- #82
DO ,1 SUB #48 <- #73
DO ,1 SUB #49 <- #77
PLEASE ,1 SUB #50 <- #65
DO ,1 SUB #51 <- #82
DO ,1 SUB #52 <- #89
DO ,1 SUB #53 <- #32
PLEASE ,1 SUB #54 <- #75
DO ,1 SUB #55 <- #69
DO ,1 SUB #56 <- #89
DO ,1 SUB #57 <- #44
PLEASE ,1 SUB #58 <- #32
DO ,1 SUB #59 <- #116
DO ,1 SUB #60 <- #105
DO ,1 SUB #61 <- #116
PLEASE ,1 SUB #62 <- #108
DO ,1 SUB #63 <- #101
DO ,1 SUB #64 <- #32
DO ,1 SUB #65 <- #84
PLEASE ,1 SUB #66 <- #69
DO ,1 SUB #67 <- #88
DO ,1 SUB #68 <- #84
DO ,1 SUB #69 <- #32
PLEASE ,1 SUB #70 <- #78
DO ,1 SUB #71 <- #79
DO ,1 SUB #72 <- #84
DO ,1 SUB #73 <- #32
PLEASE ,1 SUB #74 <- #78
DO ,1 SUB #75 <- #85
DO ,1 SUB #76 <- #76
DO ,1 SUB #77 <- #76
PLEASE ,1 SUB #78 <- #44
DO ,1 SUB #79 <- #32
DO ,1 SUB #80 <- #98
DO ,1 SUB #81 <- #111
PLEASE ,1 SUB #82 <- #100
DO ,1 SUB #83 <- #121
DO ,1 SUB #84 <- #32
DO ,1 SUB #85 <- #84
PLEASE ,1 SUB #86 <- #69
DO ,1 SUB #87 <- #88
DO ,1 SUB #88 <- #84
DO ,1 SUB #89 <- #32
PLEASE ,1 SUB #90 <- #78
DO ,1 SUB #91 <- #79
DO ,1 SUB #92 <- #84
DO ,1 SUB #93 <- #32
PLEASE ,1 SUB #94 <- #78
DO ,1 SUB #95 <- #85
DO ,1 SUB #96 <- #76
DO ,1 SUB #97 <- #76
PLEASE ,1 SUB #98 <- #41
DO :1 <- #0
DO :2 <- #1
DO (16200) NEXT
DO RESUME #1
