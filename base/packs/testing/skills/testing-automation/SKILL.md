---
name: testing-automation
description: Deterministic mobile UI automation with Maestro and stable accessibility/testID selectors. Auto-invokes for simulator, smoke, regression, or UI automation work.
---

# Testing Automation Skill (Maestro first)

Use Maestro against an installed compiled app. Application-owned interactions must use stable React Native `testID` values or meaningful accessibility selectors. Vision, screenshots, and `simctl` coordinates are diagnostic fallbacks, not the default interaction model.

## Order of preference

1. Stable `testID` derived from a route, control purpose, or canonical item identity.
2. Meaningful accessibility label/role/state when it is itself part of the user contract.
3. Seeded unique text for dynamic content that cannot expose a stable ID.
4. Vision or coordinate interaction only for system-owned UI or a documented framework gap.

Never target styling classes, transient React keys, list positions, or coordinates for application-owned critical actions. Do not replace screen-reader semantics with test-only labels.

## Standard workflow

1. Read the ticket's fixture, selector, isolation, and execution contracts.
2. Reset a production-impossible local scenario. Fail closed outside a proven local development database.
3. Launch with clean app state/keychain and explicit permissions.
4. Sign in through a shared role-specific flow.
5. Assert the starting route and fixture sentinel before mutation.
6. Interact through stable selectors and assert observable user/server outcomes.
7. Preserve Maestro debug output, screenshots, reset logs, and JUnit output on failure.

Every top-level flow must run alone and in arbitrary order. A flow must not consume another flow's session, draft, inventory, transaction, event, or cached query.

## Maestro patterns

```yaml
appId: com.example.app
name: "Example isolated flow"
tags: [smoke, regression, ios]
---
- launchApp:
    clearState: true
    clearKeychain: true
    permissions:
      all: allow
- extendedWaitUntil:
    visible:
      id: "login-screen-root"
    timeout: 20000
- tapOn:
    id: "login-email-input"
- inputText: "${E2E_EMAIL}"
- assertVisible:
    id: "login-submit-button"
    enabled: false
```

Use `extendedWaitUntil` for real asynchronous boundaries. Do not add blind sleeps. Use deterministic server delay/fault injection for double-submit, conflict, auth, and error behavior.

Dynamic row IDs must use the same canonical identity contract as production state, for example `e2e.list.row.<canonical-item-key>`. Database IDs are acceptable for persisted history/detail records only when each scenario reset recreates the records and the flow uses an ID regex rather than baking a value into source.

## Runner boundary

The runner may verify prerequisites, reset fixtures, select a booted simulator, set supported permissions, invoke Maestro, and collect reports. It must not silently start the backend server, the dev server, the bundler, or a build process.

- API target: use the project's API-target script to point the app at the dev backend before building/installing.
- Permissions: prefer Maestro. Use `xcrun simctl privacy` only for a proven unsupported state and document it.
- Timezone: a runner must verify that the setting changes React Native/Hermes behavior; a YAML environment variable alone is not proof.
- Offline/error: prefer deterministic local transport/server fault injection. iOS Simulator has no reliable Maestro airplane-mode contract.
- Background/resume: automate only after a deterministic background transition is proven.

## Vision and simctl fallback

Screenshots are useful evidence and debugging aids:

```bash
xcrun simctl io booted screenshot /tmp/e2e-screenshot.png
```

Coordinate taps are allowed only when all of these are true:

- the target is system-owned UI, or the framework exposes no stable selector;
- the pinned simulator/device geometry is documented;
- the flow is tagged `visual` or otherwise marked as a fallback;
- the reason and coordinates are recorded beside the step;
- a follow-up selector/framework ticket exists when the target is application-owned.

Do not estimate and retry coordinates until a flow happens to pass. A coordinate-only app flow is blocked, not green.

## Test layers

- Maestro: observable cross-layer mobile journeys and navigation contracts.
- Jest/RNTL: synchronous store locks, reducers, serializers, and component behavior.
- Backend tests: service/controller/model contracts, safe fixture tooling, exact arithmetic, and transactional failure behavior.
- Manual/device QA: hardware-only device behavior, unreliable OS transitions, or visual judgment not represented by a stable assertion.

Do not make a brittle UI flow carry an invariant that is more authoritative and deterministic in a lower test layer. Keep the UI assertion that proves the user-observable contract.

## Failure reporting

Report the flow/scenario, first failed stable selector, reset/preflight output, expected versus actual behavior, relevant screenshot/log path, and whether the failure is product, fixture, environment, or automation. Never weaken an assertion, reuse polluted data, or bake a noncanonical catalog label into an expectation to make a flow green.

## Device-run lessons (physical iPhone, iOS 26.1)

Every rule below was learned from an actual failed device run. Author new flows against them; do not rediscover them.

1. **Never use `hideKeyboard`.** It fails intermittently on iOS 26 ("Couldn't hide the keyboard"). Dismiss instead by: `pressKey: Enter` on default/search keyboards (verify `returnKeyType`/`onSubmitEditing` first — on a login password field Enter *submits*); tapping the field's own inert label `testID` for decimal/number pads (no return key exists there); or a mode/side switch **only when it unmounts the focused field** — handled taps on Pressables do NOT dismiss.
2. **Assume any element in the lower half of the screen is keyboard-obscured while typing.** Maestro taps obscured elements' coordinates and the keyboard eats the tap (observed: a result-tile tap typed "x" into the search field). Blur before tapping result tiles, sticky CTAs, picker footers, or the tab bar.
3. **`inputText` appends to pre-filled fields.** Money fields pre-fill from a computed default (observed: "0.24" + "10.00" → "0.241000"). Always `eraseText` first, and **assert the field's exact value after typing** so input corruption fails at the field, not minutes later.
4. **First keyboard summon can race focus.** Use the login pattern everywhere: tap → `waitForAnimationToEnd` → re-tap → type → assert value.
5. **Maestro never auto-scrolls to off-screen taps, and search results rank against the live catalog.** Wait for any result, then `scrollUntilVisible` on the exact bound id before tapping (device-verify the real rank of each fixture item — merged/multi-type result lists push targets several rows down).
6. **A selector having a producer is not enough — check its render condition against the scenario's own fixture data.** A provenance link that only renders for named/sourced records can never appear in a scenario whose fixture deliberately leaves those fields blank.
7. **iOS collapses nested Pressables into one accessibility element.** A `testID` inside a tappable row is invisible to Maestro; the row surfaces as a single element whose label concatenates child texts (`"Purchase, Condition, 2, $5.00, Jul 18"`). Assert the concatenated label with a full-match regex, or add `accessible={false}` to the wrapper (VoiceOver-visible change — needs the user's sign-off).
8. **Triage failures from ground truth, not source reading:** the failure screenshot, `commands-*.json`, the XCTest runner log, backend request params in the development log, and a read-only `maestro hierarchy` dump of the stuck screen. The hierarchy dump is the only reliable way to know what the accessibility tree actually contains.
9. **A multi-mode composer's initial mode is whatever its empty-draft factory defaults to**, not what the flow assumes. Every flow must explicitly select its mode.
10. **Text assertions are full-regex matches against an element's entire label.** A short substring does not match a longer label; amounts render per-unit in batch rows ($10 total for qty 2 shows as $5.00); dates render in local time (a UTC Jul 19 record shows "Jul 18").
