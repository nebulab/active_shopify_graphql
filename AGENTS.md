# Repository Guidelines

## Project Structure & Module Organization
- Core code lives in `lib/active_shopify_graphql/`, with entrypoint `lib/active_shopify_graphql.rb` and loaders/associations split into focused files.
- Tests sit in `spec/` using RSpec; shared config is in `spec/spec_helper.rb`.
- Executables and setup utilities are in `bin/` (`bin/setup`, `bin/console`); Rake tasks are defined in `Rakefile`.

## Build, Test, and Development Commands
- `bundle install` — install dependencies (required before any other command).
- `bin/setup` — project bootstrap (bundler + any initial prep).
- `bundle exec rake spec` or just `bundle exec rspec` — run the test suite (default Rake task).
- `bundle exec rubocop` — lint/format check using `.rubocop.yml`.
- `bin/console` — interactive console with the gem loaded for quick experiments.

## Coding Style & Naming Conventions
- Ruby 3.2+; prefer idiomatic Ruby with 2-space indentation and frozen string literals already enabled.
- Follow existing module/loader patterns under `ActiveShopifyGraphQL` (e.g., `AdminApiLoader`, `CustomerAccountApiLoader`).
- Keep loaders small: expose `fragment` and `map_response_to_attributes` for clarity.
- Use RuboCop defaults unless explicitly relaxed in `.rubocop.yml`; respect existing disables instead of re-enabling.

## Testing Guidelines
- Framework: RSpec with documentation formatter (`.rspec`).
- Place specs under `spec/` and name files `*_spec.rb` matching the class/module under test.
- Do not use `let` or `before` blocks in specs; each test case should tell a complete story.
- Use verifying doubles instead of normal doubles. Prefer `{instance|class}_{double|spy}` to `double` or `spy`
- Prefer explicit model/loader fixtures; stub external Shopify calls rather than hitting the network.
- Aim to cover happy path and schema edge cases (missing attributes, nil fragments). Add regression specs with minimal fixtures.

## Commit & Pull Request Guidelines
- Use short, imperative commit subjects (≈50 chars) with focused diffs; group related changes together.
- Reference issues in commit messages or PR bodies when relevant.
- PRs should include: what changed, why, and how to test (commands run, expected outcomes). Add screenshots only if user-facing behavior is affected.
- When changing public APIs, update relevant documentation in the README.
- Ensure CI-critical commands (`bundle exec rake spec`, `bundle exec rubocop`) pass locally before opening a PR.

## Security & Configuration Tips
- Verify Admin vs Customer Account API client selection when adding loaders; avoid leaking tokens between contexts.
- If introducing new configuration knobs, document defaults and required environment variables in `README.md` and add minimal validation in configuration objects.
