# Task: Fix an intermittent locale test

`node benchmark-app/run-tests.js --only default-locale` passes consistently, but CI intermittently fails with `node benchmark-app/run-tests.js --seed 7`.

The relevant files are `benchmark-app/run-tests.js` and `benchmark-app/locale.js`. Reproduce the seeded suite failure, identify the root cause, implement the smallest reliable fix, and verify both the isolated test and the seeded suite. Do not add retries or weaken assertions.
