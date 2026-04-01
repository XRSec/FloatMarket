# Engineering Standards / 开发规范

## 1. General

- Prefer clarity over abstraction
- Keep runtime behavior observable through logs
- Do not remove fallback paths unless replacement is verified
- Do not hardcode provider URLs when a setting already exists

## 2. UI

- Floating window changes must preserve glanceability
- Avoid adding dense controls directly into the floating window
- Configuration belongs in the control center unless it is used every few seconds
- Any light-theme change must be checked for contrast

## 3. Data Sources

- WebSocket is preferred for live quote feeds
- HTTP must remain available as fallback for unstable streams
- Any new provider must define:
  - primary endpoint
  - backup endpoint
  - parser
  - reconnect strategy
  - log messages for failures

## 4. Proxy Support

- New networking code must use the shared proxy-aware session factory
- Do not instantiate raw `URLSession.shared` for quote traffic
- Proxy tests must remain lightweight and side-effect free

## 5. Localization

- New user-facing text should be added in bilingual form
- Prefer `store.text(zh, en)` for the current project stage
- Avoid mixing partially translated labels in the same view when possible

## 6. Logging

- Logs should be actionable
- Good logs answer:
  - which provider failed
  - which endpoint was used
  - whether fallback was triggered
  - whether parsing or transport failed

## 7. Sorting And Scheduling

- Global index ordering logic must stay deterministic
- Session-aware sorting should not trigger redundant network calls after close
- Custom sort mode must always override automatic sort mode

## 8. Git Workflow

- Work on `main` only for very small local prototypes
- Prefer feature branches for larger changes
- Keep commits scoped:
  - one behavior area per commit when practical
- Before committing:
  - build successfully
  - verify no placeholder text remains
  - update docs if behavior changed

## 9. Release Readiness Checklist

- App icon present in `AppIcon.appiconset`
- About window reflects current product identity
- README matches actual functionality
- Proxy settings verified
- WebSocket fallback path verified
- Default watchlist symbols verified
- Build passes on current Xcode toolchain
