---
description: The definitive, step-by-step process for building a complete feature from scratch in the Nexus codebase. Follow every phase in order — no phase may be skipped.
---

# Feature Development Workflow

> **GOLDEN RULE:** A feature is NOT complete until it passes ALL phases below.
> Every phase has a **gate** — a condition that must be met before proceeding.
> If a gate fails, you MUST fix the issue before moving forward.

---

## Phase 0 — Discovery & Scoping

**Goal:** Understand what the feature does, who it serves, and where it lives in the domain.

### Steps

1. **Clarify the requirement** with the user. Ask:
   - What domain does this belong to? (e.g. `Identity`, `Treasury`, `ERP`)
   - What is the user-facing outcome?
   - Are there any existing aggregates, commands, or events to extend?
2. **Review existing domain code** in the target domain directory:
   - `lib/nexus/<domain>/aggregates/` — existing aggregates
   - `lib/nexus/<domain>/commands/` — existing commands
   - `lib/nexus/<domain>/events/` — existing events
   - `lib/nexus/<domain>/projections/` — existing read models
   - `lib/nexus/<domain>/projectors/` — existing projectors
3. **Review existing tests** to understand the testing patterns:
   - `test/features/<domain>/` — Gherkin `.feature` files
   - `test/nexus/<domain>/` — ExUnit test modules
4. **Review existing web layer** if the feature has UI:
   - `lib/nexus_web/live/<domain>/` — LiveView modules
   - `assets/js/hooks/` — JavaScript hooks

### Gate

> You can clearly articulate: _"This feature adds [command/event/projection] to the [domain] aggregate, exposed via [LiveView/API], tested by [feature file]."_

---

## Phase 1 — Behaviour-First Specification (BDD)

**Goal:** Write the Gherkin `.feature` file BEFORE any implementation code.

> **WHY FIRST?** The feature file defines the contract. It forces you to think about
> the happy path, edge cases, and security invariants before writing a single line of code.

### Steps

1. **Create the feature file** at `test/features/<domain>/<feature_name>.feature`
2. **Write scenarios** using this exact format:

```gherkin
Feature: <Feature Name>
    As a <persona>
    I want <action>
    So that <business value>

    Scenario: <Happy Path>
        Given <precondition>
        When <action>
        Then <expected outcome>
        And <secondary assertion>

    Scenario: <Edge Case / Failure>
        Given <precondition>
        When <action that should fail>
        Then <expected error/behavior>
```

3. **Naming conventions for scenarios:**
   - Use business language, not technical jargon
   - Each `Given`/`When`/`Then` step should map to exactly one testable assertion
   - Quote dynamic values: `Given a user "bernard" is registered`
   - Use domain terms: "event should be emitted", "found in the database"

### Gate

> The `.feature` file reads like a specification that a non-technical stakeholder could understand. It covers: happy path, at least one failure/edge case, and security invariants (e.g. replay attack prevention).

---

## Phase 2 — Domain Layer (CQRS/ES)

**Goal:** Build the pure domain logic — commands, events, aggregate, and projections.

> **STRICT ORDER:** Commands → Events → Aggregate → Projections → Projectors → Router

### Step 2.1 — Command

Create `lib/nexus/<domain>/commands/<command_name>.ex`:

```elixir
defmodule Nexus.<Domain>.Commands.<CommandName> do
  @moduledoc """
  Brief description of what this command represents in the domain.
  """
  defstruct [:field_1, :field_2, ...]
end
```

**Rules:**

- One module per file — NEVER nest modules
- Commands are plain structs — no logic, no validation
- Field names use snake_case atoms
- Include ALL fields needed by the aggregate's `execute/2`

### Step 2.2 — Event

Create `lib/nexus/<domain>/events/<event_name>.ex`:

```elixir
defmodule Nexus.<Domain>.Events.<EventName> do
  @moduledoc """
  Emitted when <business thing happens>.
  """
  @derive Jason.Encoder
  defstruct [:field_1, :field_2, ...]
end
```

**Rules:**

- Events MUST derive `Jason.Encoder` (required by EventStore serialization)
- Events are immutable facts — they describe what HAPPENED, past tense
- Naming: `UserRegistered`, `BiometricVerified`, `OrderPlaced` (past tense)

### Step 2.3 — Aggregate

Create or modify `lib/nexus/<domain>/aggregates/<aggregate_name>.ex`:

```elixir
defmodule Nexus.<Domain>.Aggregates.<AggregateName> do
  defstruct [:id, :field_1, ...]

  # Command handler — returns event(s) or {:error, reason}
  def execute(%__MODULE__{id: nil} = _aggregate, %Commands.Create{} = cmd) do
    %Events.Created{id: cmd.id, ...}
  end

  # State mutator — applies event to aggregate state
  def apply(%__MODULE__{} = state, %Events.Created{} = event) do
    %{state | id: event.id, ...}
  end
end
```

**Rules:**

- `execute/2` receives current state + command, returns event(s) or `{:error, reason}`
- `apply/2` receives current state + event, returns new state — PURE function, no side effects
- Pattern match on aggregate state to enforce invariants (e.g., `id: nil` = new aggregate)
- If the aggregate needs to look up data (e.g., challenge store), call it in `execute/2`

### Step 2.4 — Projection (Read Model)

Create `lib/nexus/<domain>/projections/<projection_name>.ex`:

```elixir
defmodule Nexus.<Domain>.Projections.<Name> do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "<table_name>" do
    field :field_1, :string
    timestamps()
  end
end
```

**Rules:**

- Projections are Ecto schemas — they represent the read-side database tables
- Use `@primary_key {:id, :binary_id, autogenerate: false}` for UUID primary keys
- Create the corresponding migration in `priv/repo/migrations/`

### Step 2.5 — Projector

Create `lib/nexus/<domain>/projectors/<projector_name>.ex`:

```elixir
defmodule Nexus.<Domain>.Projectors.<Name> do
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "<unique_projector_name>"

  project(%Events.Created{} = event, _metadata, fn multi ->
    case Ecto.UUID.cast(event.id) do
      {:ok, _id} ->
        Ecto.Multi.insert(multi, :projection, %Projections.Name{
          id: event.id,
          field_1: event.field_1
        }, on_conflict: :nothing, conflict_target: :id)
      :error ->
        multi
    end
  end)
end
```

**Rules:**

- Projectors listen for events and update the read-side database
- The `name:` must be unique across ALL projectors (used for event tracking)
- Register projector in `lib/nexus/application.ex` supervisor tree

### Step 2.6 — Router Registration

Add to `lib/nexus/router.ex`:

```elixir
# --- <Domain> Domain ---
dispatch(Nexus.<Domain>.Commands.<CommandName>,
  to: Nexus.<Domain>.Aggregates.<AggregateName>,
  identity: :<id_field>
)
```

**Rules:**

- Group dispatches by domain with a comment header
- `identity:` must match the field in the command struct that identifies the aggregate instance

### Gate — Domain Layer Compilation

```bash
// turbo
mix compile --warnings-as-errors
```

> **MUST pass with ZERO warnings and ZERO errors.** Fix any issues before proceeding.

---

## Phase 3 — Test Implementation

**Goal:** Wire up the Gherkin `.feature` file to ExUnit test module.

### Steps

1. **Create the test module** at `test/nexus/<domain>/<feature_name>_test.exs`:

```elixir
defmodule Nexus.<Domain>.<FeatureName>Test do
  use Cabbage.Feature, file: "<domain>/<feature_name>.feature"
  use Nexus.DataCase

  @moduletag :feature

  setup do
    # Set mock adapters if needed
    Application.put_env(:nexus, :webauthn_adapter, Nexus.Identity.WebAuthn.MockAdapter)
    # Start projectors needed for this test
    start_supervised!(Nexus.<Domain>.Projectors.<ProjectorName>)
    :ok
  end

  # --- Given ---
  defgiven ~r/^regex matching the Given step$/, %{captured: value}, state do
    {:ok, Map.put(state, :key, value)}
  end

  # --- When ---
  defwhen ~r/^regex matching the When step$/, _vars, state do
    # Execute the action
    {:ok, Map.put(state, :result, result)}
  end

  # --- Then ---
  defthen ~r/^regex matching the Then step$/, _vars, state do
    assert <condition>
    {:ok, state}
  end
end
```

**Rules:**

- **EVERY** `Given`, `When`, `Then` step in the `.feature` file MUST have a matching `defgiven`, `defwhen`, `defthen`
- Use `@moduletag :feature` so tests can be run with `mix test.features`
- State is threaded through using `{:ok, Map.put(state, :key, value)}`
- Regex patterns must match the exact wording from the `.feature` file
- Use named captures `(?<name>[^"]+)` for quoted dynamic values
- For async projections, use a retry loop (see `wait_for_user/2` pattern):

```elixir
defp wait_for_record(id, attempts \\ 30)
defp wait_for_record(_id, 0), do: nil
defp wait_for_record(id, attempts) do
  case Repo.get(Schema, id) do
    nil -> Process.sleep(100); wait_for_record(id, attempts - 1)
    record -> record
  end
end
```

2. **Create database migration** if new projections need tables:

```bash
mix ecto.gen.migration create_<table_name>
```

### Gate — Tests Pass

```bash
// turbo
mix test test/nexus/<domain>/<feature_name>_test.exs
```

> **ALL scenarios MUST pass.** If a test fails, debug with `--trace` flag.
> Run the full feature suite to check for regressions:

```bash
// turbo
mix test.features
```

---

## Phase 4 — Web Layer

**Goal:** Expose the domain feature through the Phoenix web interface.

> **STRICT ORDER:** Route → LiveView → Components → Shared Components

### Step 4.1 — Route

Add to `lib/nexus_web/router.ex` in the appropriate scope:

```elixir
scope "/", NexusWeb do
  pipe_through :browser

  live "/<path>", <Domain>.<LiveViewName>
end
```

**Rules:**

- Phoenix `scope` already provides the alias prefix — do NOT duplicate it
- Use the pattern: `live "/path", Domain.LiveViewName`

### Step 4.2 — LiveView

Create `lib/nexus_web/live/<domain>/<live_view_name>.ex`:

```elixir
defmodule NexusWeb.<Domain>.<LiveViewName> do
  use NexusWeb, :live_view
  import NexusWeb.<Domain>.<Components>

  alias Nexus.<Domain>.<Context>
  alias Nexus.App

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, key: value)}
  end

  @impl true
  def handle_event("event_name", params, socket) do
    # Dispatch command, update assigns
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.dark_page>
      <.component_name attr={@assign} />
    </.dark_page>
    """
  end
end
```

**Rules:**

- LiveViews are named with `Live` suffix: `BiometricLive`, `DashboardLive`
- Import domain-specific components at the top
- Use `NexusWeb, :live_view` (NOT raw `Phoenix.LiveView`)
- ALL event handlers MUST have `@impl true`
- Use `push_navigate/2` for navigation, NEVER `live_redirect`
- Use `~p"/path"` for verified routes

### Step 4.3 — Components

Create `lib/nexus_web/live/<domain>/<components_name>.ex`:

```elixir
defmodule NexusWeb.<Domain>.<ComponentsName> do
  use Phoenix.Component

  attr :field, :type, required: true
  def component_name(assigns) do
    ~H"""
    <div>...</div>
    """
  end
end
```

**Rules:**

- Components are PURE render functions — no side effects, no state
- Always declare `attr` types for documentation and compile-time checks
- Use Tailwind CSS classes for styling — NEVER `@apply`
- Use `<.icon name="hero-xxx" />` for icons — NEVER import Heroicons modules
- Use `class={[...]}` list syntax for conditional classes
- Add unique `id` attributes to interactive elements (needed for testing)

### Step 4.4 — JavaScript Hooks (if needed)

Create `assets/js/hooks/<hook_name>.js`:

```javascript
const MyHook = {
  mounted() {
    /* setup */
  },
  // ... lifecycle methods
  destroyed() {
    /* cleanup */
  },
};

export default MyHook;
```

Then register in `assets/js/hooks/index.js`:

```javascript
import MyHook from "./my_hook";
export default { MyHook /* ...existing hooks */ };
```

**Rules:**

- ONE hook per file in `assets/js/hooks/`
- Export from `hooks/index.js` barrel — NEVER put hook logic in `app.js`
- Use `this.pushEvent("name", payload)` to communicate with LiveView
- Use `this.handleEvent("name", callback)` to receive from LiveView
- If the hook manages its own DOM, set `phx-update="ignore"` on the element
- Always clean up timers/listeners in `destroyed()`

### Gate — Web Layer Compiles & Renders

```bash
// turbo
mix compile --warnings-as-errors
```

> Start the server and visually verify the feature renders correctly:

```bash
// turbo
mix phx.server
```

> Navigate to the feature URL in the browser and verify:
>
> 1. Page loads without JS errors (check browser console)
> 2. All interactive elements respond correctly
> 3. Commands dispatch successfully to the domain layer

---

## Phase 5 — UI/UX Polish

**Goal:** Ensure the interface meets world-class design standards.

### Checklist

- [ ] **Copy review:** Replace ALL technical jargon with user-friendly language
  - No: "handshake", "bind", "terminal", "entropy", "hash"
  - Yes: "verification", "scanning", "access", "identity"
- [ ] **Visual hierarchy:** Headlines → subtext → actions → hints (top to bottom)
- [ ] **Feedback states:** Every user action has visible feedback:
  - Idle state (default)
  - Active/scanning state (animation, color change)
  - Success state (green, checkmark)
  - Error state (red/amber, clear message)
  - Loading state (spinner, progress)
- [ ] **Micro-interactions:** Hover effects, transitions, smooth animations
- [ ] **Trust indicators:** Security badges, compliance labels where appropriate
- [ ] **Responsive:** Test at multiple viewport widths
- [ ] **Accessibility:** All buttons have clear labels, sufficient color contrast
- [ ] **Remove debug info:** No hashes, UUIDs, or raw data visible to users

### Gate

> Take a screenshot of every state of the feature. Each state should look premium and professional.

---

## Phase 6 — Full Verification

**Goal:** Prove everything works end-to-end.

### Step 6.1 — Compilation

```bash
// turbo
mix compile --warnings-as-errors
```

### Step 6.2 — Feature Tests

```bash
// turbo
mix test.features
```

### Step 6.3 — Full Test Suite

```bash
// turbo
mix test
```

### Step 6.4 — Static Analysis (if time permits)

```bash
mix credo --strict
```

### Step 6.5 — Browser Verification

1. Navigate to the feature URL
2. Walk through the complete happy path
3. Test at least one error/edge case
4. Check browser console for JS errors
5. Take screenshots of each state as proof

### Gate — ALL PASS

> - `mix compile --warnings-as-errors` → 0 warnings, 0 errors
> - `mix test.features` → all scenarios pass
> - `mix test` → no regressions
> - Browser walkthrough → all states render correctly

---

## Phase 7 — Documentation & Commit

**Goal:** Leave the codebase better than you found it.

### Steps

1. **Ensure moduledocs** on all new modules:

   ```elixir
   @moduledoc """
   Brief description of what this module does.
   """
   ```

2. **Verify file organization:**

   ```
   lib/nexus/<domain>/
   ├── aggregates/<name>.ex
   ├── commands/<command>.ex
   ├── events/<event>.ex
   ├── projections/<projection>.ex
   └── projectors/<projector>.ex

   lib/nexus_web/live/<domain>/
   ├── <name>_live.ex
   └── <name>_components.ex

   assets/js/hooks/
   ├── index.js
   └── <hook_name>.js

   test/features/<domain>/
   └── <feature>.feature

   test/nexus/<domain>/
   └── <feature>_test.exs
   ```

3. **Commit with a descriptive message:**

   ```
   feat(<domain>): <short description>

   - Added <command/event/aggregate> for <feature>
   - Created <LiveView> with <components>
   - BDD scenarios: <count> passing
   ```

---

## Quick Reference — File Naming Conventions

| Layer      | Pattern                                             | Example                                            |
| ---------- | --------------------------------------------------- | -------------------------------------------------- |
| Command    | `lib/nexus/<domain>/commands/<verb_noun>.ex`        | `commands/verify_biometric.ex`                     |
| Event      | `lib/nexus/<domain>/events/<noun_past_tense>.ex`    | `events/biometric_verified.ex`                     |
| Aggregate  | `lib/nexus/<domain>/aggregates/<noun>.ex`           | `aggregates/user.ex`                               |
| Projection | `lib/nexus/<domain>/projections/<noun>.ex`          | `projections/user.ex`                              |
| Projector  | `lib/nexus/<domain>/projectors/<noun>_projector.ex` | `projectors/user_projector.ex`                     |
| LiveView   | `lib/nexus_web/live/<domain>/<noun>_live.ex`        | `live/identity/biometric_live.ex`                  |
| Components | `lib/nexus_web/live/<domain>/<noun>_components.ex`  | `live/identity/biometric_components.ex`            |
| Feature    | `test/features/<domain>/<feature_name>.feature`     | `features/identity/biometric_verification.feature` |
| Test       | `test/nexus/<domain>/<feature_name>_test.exs`       | `nexus/identity/biometric_verification_test.exs`   |
| JS Hook    | `assets/js/hooks/<hook_name>.js`                    | `hooks/webauthn.js`                                |

---

## Quick Reference — Key Commands

| Action                 | Command                                   |
| ---------------------- | ----------------------------------------- |
| Compile with warnings  | `mix compile --warnings-as-errors`        |
| Run all tests          | `mix test`                                |
| Run feature tests only | `mix test.features`                       |
| Run single test file   | `mix test test/nexus/<domain>/<file>.exs` |
| Run failed tests       | `mix test --failed`                       |
| Create migration       | `mix ecto.gen.migration <name>`           |
| Run migrations         | `mix ecto.migrate`                        |
| Start dev server       | `mix phx.server`                          |
| Setup event store      | `mix event_store.setup`                   |
| Static analysis        | `mix credo --strict`                      |
