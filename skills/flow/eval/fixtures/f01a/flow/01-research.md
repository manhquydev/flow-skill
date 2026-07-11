# Stage 01 — Research (inspect first)

Rule: INSPECT what already exists. Evidence required — links, quotes, screenshots.
"I think there's nothing like this" without searching = gate fail.

## Gate — check ALL before `/flow next`
- [x] I actually OPENED 3 existing tools/competitors (links below, with one honest note each)
- [x] I found 3 REAL user complaints online, quoted, with source links
- [x] I wrote what competitors CHARGE (real prices) and who pays
- [x] I named the ONE channel my first 10 users come from (a place, not "social media")
- [x] I wrote why those users would pick this over the status quo (one honest paragraph)
- [x] I wrote what is technically free vs hard for this idea
- [x] No FILL placeholders remain in this file

## What exists already (3 — open them, don't guess)

1. Splitwise (splitwise.com) — handles group expense splitting well, but its recurring-bill
   view buries anything not tagged "rent"; three of our pilot households gave up trying to
   track a shared internet bill inside it and moved back to a spreadsheet.
2. Tricount (tricount.com) — clean mobile UI, free tier caps a group at 1 currency and no
   CSV export unless you pay; the export paywall is the exact friction our target users hit
   when they try to reconcile at month-end.
3. A shared Google Sheet template (the informal incumbent most of our interviewees actually
   use today) — zero cost, but no reminders, no per-person balance view, and it silently
   breaks when two people edit the same cell at once (three separate households reported
   losing an entry this way in the last three months).

## What users say (3 real complaints quoted+linked)

1. > "Splitwise is great until someone doesn't open the app for two weeks and the balance
   >  just sits there. I want a nudge, not a number."
   — u/frugal_flatmate, r/personalfinance thread "How do you actually get roommates to pay
   you back?" (reddit.com/r/personalfinance/comments/17k2xq1)
2. > "We tried three apps and gave up and went back to a spreadsheet because none of them
   >  let us split a bill three unequal ways without doing the math ourselves first."
   — comment on Tricount's App Store listing (apps.apple.com/us/app/tricount/id594204643,
   review dated within the last 6 months)
3. > "Every month it's the same fight about who forgot to pay for internet. I don't need
   >  another budgeting app, I need someone to just tell me the number."
   — reply on r/Roommates, thread "what bill split apps have worked for you long term"
   (reddit.com/r/Roommates/comments/1a8j9k2m/what_bill_split_apps_have_worked_for_you/), posted
   by u/threeway_hcol_split within the last 4 months

## GTM & business reality

Building is the cheap part now. Distribution and willingness-to-pay are where ideas die —
research them BEFORE planning, not after shipping.

### Who pays today, and how much (pricing reference points)

- Splitwise Pro — $3/month or $30/year, paid by the household member who "owns" the group.
- Tricount CSV export — one-time IAP of $2.99, paid by whoever needs the bank reconciliation.
- Manual spreadsheet — $0 cash cost, but our pilot households estimate ~25 minutes/month of
  someone's unpaid time reconciling it, which is the real cost we are competing against.

### The first-10-users channel

The Facebook group "Da Nang Expat Roommates & Housing" (11k members, admin-approved posts
only on Mondays) — two of the founders already have posting rights there from a prior
apartment-hunting post that got 40 comments; that thread is where 6 of our 8 pilot
households were originally recruited from.

### Why switch (vs the status quo)

The named households in that Facebook group are currently using a shared Google Sheet that
breaks under concurrent edits and has no reminder mechanism; they already told us (during
the pilot interviews) that they'd pay a small one-time fee to stop the monthly "who forgot"
argument, provided the switch takes under 5 minutes and doesn't require the whole household
to create new accounts.

## Technically free vs hard

- Free (solved by libraries/platforms): auth via a magic-link email provider, expense CRUD,
  push notifications via a managed service (OneSignal free tier covers our pilot scale).
- Hard (custom work, real risk): the "who forgot" nudge logic needs a debt-simplification
  algorithm (minimize the number of repayment transactions across an N-person group) — this
  is a small graph problem, not off-the-shelf, and the first version will hand-roll it.
