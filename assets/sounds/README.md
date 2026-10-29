# Answer feedback sounds

Two files are expected here. The app runs without them — SoundService falls
back to haptics alone and logs once — so these can be added at any time
without a code change.

| File | When it plays | What it should sound like |
| --- | --- | --- |
| `correct.mp3` | The student picked the right option | Short rising chime, 150-300ms. Bright, not triumphant: it fires many times per quiz and anything theatrical wears out inside one session. |
| `wrong.mp3` | The student picked a wrong option | Soft, low, 150-300ms. **Not a buzzer.** Students are wrong often while practising, and a punishing sound teaches them to stop opening the app. |

Keep both under ~20KB. Mono is fine. Normalise them to roughly the same
loudness, or the wrong answer will feel like a telling-off purely because it
is louder.

Sources: freesound.org (filter to CC0) or any royalty-free UI sound pack.
Whatever is used must be licensed for commercial redistribution, since these
ship inside the APK on the Play Store.
