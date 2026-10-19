# The INTERCAL Blog

INTERCAL on Interstates' sample application (step 10 of
[`docs/INTERSTATES_PLAN.md`](../../../../docs/INTERSTATES_PLAN.md)).

```
ioi-llvm build -s --no-random-bug blog.xc -o blog
gross --static public --database sqlite:./blog.db ./blog
```

Then open <http://127.0.0.1:10585/blog>. (`--no-random-bug` keeps CIWAPA's random compiler bug,
E774, out of a program this long; leave it off for the authentic experience.)

| Route | What it does |
|---|---|
| `/blog` | Lists the posts: a header, then one `item.html` fragment per post, rendered by a loop in INTERCAL, then a footer. |
| `/blog/post/:id` | Shows a post. It is restricted to the list's item fragment, line (20), whose link it must be reached from; anything else is a 403. A missing post is a 404. |
| `/blog/new` | The form for a new post. |
| `/blog/create` | Creates the post with `INTO DATABASE` and redirects to the list. It is restricted to the form's page, line (40). |
| anything else | Redirects to the list. |

The table (`posts`: `id`, `title`, `body`, so columns #1, #2 and #3 of table #1) is made the first
time a page needs it, by the routine at (500).

`blog.xc` is generated from a short script, because INTERCAL builds every string one character at a
time.
