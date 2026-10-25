# Play Console — step by step

Checked against the Play Console flow as of September 2026. Values below are
verified against this repo, so the Data safety answers match what the app
actually does.

## Read this first: the order matters

| | Task | Blocked? | Time |
|---|---|---|---|
| **A1** | **App name** — the only listing change that matters | No — do it now | ~2 min |
| **A2** | Short and full description — optional polish | No | ~10 min |
| **B** | Account deletion: in-app path + web page | Needs code | ~half a day |
| **C** | Data safety declaration | **Blocked on B** | ~20 min |

**What does NOT need touching:** the screenshots (six are already uploaded and
they are fine) and the feature graphic. An earlier draft of this file implied
a screenshot experiment was worth setting up now — it is not, there is no
traffic to run it against yet.

**Do not start C before B is done.** The Data safety form asks for a web URL
where users can request account deletion. Play requires that URL for any app
that lets users create an account, which Ustaad does. Without it you either
stall halfway through the form or answer it untruthfully, and an untruthful
answer is the exact problem you are trying to fix.

The current listing declares "No data collected" while the app stores emails,
user IDs and progress in Firebase. That is the live risk. It gets fixed in C.

---

# PART A — Store listing

**Do this now.** Nothing blocks it.

### A1. Open the listing editor

1. Go to https://play.google.com/console
2. Select **Ustaad** from the app list
3. Left sidebar → **Grow** → **Store presence** → **Main store listing**

### A2. App name (30 character limit)

Clear the field and paste:

```
Ustaad: NET, NTS & FAST Prep
```

28 characters. The current name is just "Ustaad", which contains no exam
keyword, so the listing cannot rank for what students actually type. Play is
currently showing GRE and NCLEX apps under "Similar apps" — that is Play
telling you it has no idea what this app is for.

**Do not add MDCAT or NUMS to the name yet.** There is no MDCAT content in the
app. A student who installs on that promise and finds nothing uninstalls, and
may leave the first review — on a listing with zero ratings, the first review
sets the tone for months. Add it the day the content ships.

### A3. Short description (80 character limit) — OPTIONAL

Your current one is already good:

> Ace FAST, NUST & NTS with AI quizzes, full papers & real exam simulation.

73 characters, and it carries FAST, NUST, NTS, AI, quizzes, papers and exam
simulation. There is nothing wrong with it.

The only argument for replacing it is that it spends a word on "Ace" and never
says **Free**, which is the strongest conversion word available to you, and
omits "past papers" and "MCQs" as search terms:

```
Free MCQs & past papers for FAST NU, NUST NET and NTS. AI explains every answer.
```

Exactly 80 characters. This is a marginal gain, not a fix. Swap it if you feel
like it; skip it and lose almost nothing.

### A4. Full description (4000 character limit) — OPTIONAL

Your current description is good and already opens with the exam names in the
first line, which is where they matter. It has two small gaps: the word
**Free** does not appear anywhere in it, and it never states how many
questions there are. Both are worth fixing whenever you next edit it, and
neither is urgent.

If you do want to replace it wholesale, this version front-loads the count and
the price, and is shorter:

```
Free entry test preparation for FAST NU, NUST NET and NTS. 3,900+ real past
paper MCQs with step by step AI explanations in Urdu and English.

Ustaad is built for one thing: Pakistani university entry tests. The FAST NU
entrance test, NUST NET (Engineering, CS, Business) and NTS NAT for COMSATS
and other universities.

WHAT YOU GET

• 3,900+ MCQs from real past papers — Advanced Maths, Basic Maths, Physics,
  English, Analytical and IQ, organised by topic so you can drill your weak
  areas instead of re-reading what you already know.

• AI explanations in Urdu AND English. Galat jawab? Ustu explains why: the
  concept, the solution step by step, and the trick to spot it next time.
  Not just an answer key.

• Real exam simulation, down to the details that catch people out:
  – FAST NU negative marking (+1 correct, −0.25 wrong) so you learn when to
    skip instead of guessing blindly
  – NTS colour coded booklet sections, exactly like the real paper
  – Timed countdown, question navigation, mark for review, auto submit

• Full length mock papers matching the real pattern and marking scheme.

• Progress tracking — daily goal, streaks, and subject wise accuracy, so you
  can see which topic is actually costing you marks.

WHO IT IS FOR

Students preparing for the FAST NU entry test, NUST NET, and NTS NAT (ICS/CS
and general), and anyone applying to COMSATS, GIKI or other universities that
accept NTS.

FREE TO START

Practice quizzes and AI explanations are free. No card needed to begin.

Baaki sab resources incomplete hain — scattered PDFs, no explanations, no
feedback. Ustaad puts real past papers, real marking schemes and a tutor that
explains every mistake in one app.

Download Ustaad and start practising today.
```

Keep the MCQ count honest. It comes from the cleaned files in
`ustaad_extractor/done/` — currently 3,904.

### A5. Save

Click **Save** at the bottom. Changes go to review; text-only edits usually
clear within a few hours to a day.

### A6. Store listing experiment — NOT YET

Skip this. A/B tests need traffic to reach significance and you have 10+
installs. Come back to it once the landing page and the group posting are
actually sending people to the listing — realistically once you are seeing a
few hundred store visits a week. Setting one up now just produces noise you
might act on.

---

# PART B — Account deletion (blocking C)

There is no account deletion flow anywhere in `lib/`. Play requires both an
in-app path and a web URL for any app offering account creation.

1. **In app** — a "Delete my account" action in
   `lib/screens/profile/profile_screen.dart`: re-authenticate, delete the
   Firestore user document, then `FirebaseAuth.instance.currentUser.delete()`.
2. **Web** — a deletion request page next to the existing privacy policy at
   `ustaad-privacy.vercel.app`, stating what gets deleted, what is retained,
   and how long it takes.

Both need to ship in a release before Part C can be answered truthfully.

---

# PART C — Data safety declaration

**Only after Part B is live.**

### C1. Open the form

Left sidebar → **Policy** → **App content** → scroll to **Data safety** →
**Start** (or **Manage**)

### C2. Overview

Read and click **Next**.

### C3. Data collection and security

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** — Firebase is HTTPS only |
| Do you provide a way for users to request that their data is deleted? | **Yes** — then paste the deletion URL from Part B |

Click **Next**.

### C4. Data types — tick exactly these

**Personal info**
- ☑ Name
- ☑ Email address
- ☑ User IDs

**App activity**
- ☑ App interactions
- ☑ Other user-generated content — the free-text `message` field that
  `feedback_screen.dart` writes to the `feedback` collection. Open-ended
  responses count as user-generated content, so this is a separate tick from
  App interactions.

**App info and performance** — added by Crashlytics
- ☑ Crash logs
- ☑ Diagnostics

**Device or other IDs** — added by Analytics and FCM
- ☑ Device or other IDs

Leave every other box unticked. Do **not** tick Financial info, Contacts,
Photos, Files, Messages, or Health — the app collects none of them.

> **This list is now current as of the Analytics / Crashlytics / FCM release.**
> The three new ticks come from: Crashlytics (crash stacks and device state),
> Firebase Analytics (the app instance ID), and FCM (the registration token
> that a notification is addressed to). All three ship in the same build, so
> the declaration and the APK match.

**The one judgment call: Approximate location.**
Firebase Analytics derives a coarse, city-level location from the IP address
of each request. Google's own Firebase data-safety guidance lists it among
what Analytics collects. You have two defensible options:

- **Tick Location → Approximate location** (conservative, and what most apps
  using Analytics do). Purpose: Analytics.
- **Leave it unticked and turn the collection off**, by calling
  `setConsent` / disabling geo signals in Analytics.

Pick one and be consistent. Ticking it costs you nothing with students — it
is one line in a summary nobody reads — and an under-declaration is the thing
that gets apps pulled. I would tick it.

Click **Next**.

### C5. Per data type detail

The form now asks the same four questions for each type you ticked. Answers:

| Data type | Collected | Shared | Processed ephemerally | Required or optional | Purposes |
|---|---|---|---|---|---|
| Name | Yes | **No** | No | Required | App functionality, Account management |
| Email address | Yes | **No** | No | Required | App functionality, Account management |
| User IDs | Yes | **No** | No | Required | App functionality, Account management |
| App interactions | Yes | **No** | No | Required | App functionality, Analytics |
| Other user-generated content | Yes | **No** | No | Optional | App functionality |
| Crash logs | Yes | **No** | No | Required | App functionality, Analytics |
| Diagnostics | Yes | **No** | No | Required | App functionality, Analytics |
| Device or other IDs | Yes | **No** | No | Required | Analytics, App functionality, Developer communications |
| Approximate location *(if ticked)* | Yes | **No** | No | Required | Analytics |

"Shared" is **No** for every row. Sharing means transferring to a third party;
Firebase is your own backend acting as a processor, not a third party you
share with. Google being the vendor does not make it sharing.

"Optional" for Name because Google Sign In supplies it but email/password
signup does not require it.

**Developer communications** appears on Device or other IDs because the FCM
registration token exists to address a push notification to a device. That is
what that purpose means; leaving it off would under-declare.

Everything else is **Required** rather than Optional: none of it has an in-app
toggle. If you later add a "share anonymous usage data" switch, these move to
Optional and the form has to be updated again.

### C6. Preview and submit

Review the generated summary, click **Submit**, then **Save** on the App
content page. The declaration is reviewed with your next release.

---

## Checklist

- [x] A2 — App name → `Ustaad | NET, NTS & FAST`
- [x] A5 — Saved
- [ ] A3 — Short description (optional, marginal)
- [ ] A4 — Full description (optional; at minimum add "Free" and the MCQ count)
- [ ] ~~A6 — store listing experiment~~ — not until there is traffic
- [x] B1 — In-app account deletion built (profile screen, with reauth)
- [ ] B2 — Web deletion request page published ← **still open, still required**
- [ ] B3 — Release shipped containing both
- [ ] **C — Data safety form submitted** ← the only thing that can get the app
      pulled, and it is now further out of date than before: Analytics,
      Crashlytics and FCM add Crash logs, Diagnostics and Device IDs on top of
      the Name / Email / User IDs / App interactions that were already
      undeclared. Play showing "no problems" is not a check — the form is a
      self-declaration and nothing compares it to your APK.

> **Order for the next release.** B2 and C are both required and both cheap.
> Publish the deletion page, submit the form, then ship the build with
> Analytics, Crashlytics and FCM in it. Declaration and binary go out together
> or the declaration is wrong again the moment it lands.
