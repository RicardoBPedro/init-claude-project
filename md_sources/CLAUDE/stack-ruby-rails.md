# CLAUDE.md — Ruby on Rails addendum

<!--
  Merged into CLAUDE.md when STACK=ruby-rails.
  Assumed stack: Rails 7+ (Hotwire, Sidekiq, RSpec or minitest, Ruby 3.2+).
-->

Supplements core CLAUDE.md with Rails-specific best practices.

## Commands

```bash
bin/rails server                       # dev server (Puma)
bin/rails console                      # REPL
bin/rails db:migrate                   # run migrations
bin/rails db:rollback STEP=1           # undo last migration
bin/rails generate migration AddXToY   # scaffold migration
bin/rails generate model User name     # scaffold model + migration + spec
bin/rspec spec/models/user_spec.rb     # single test file (or bin/rails test)
bundle exec rubocop -A                 # lint + autofix
bundle exec brakeman --no-pager        # static security scan
bin/rails routes -g users              # filter routes
bin/rails assets:precompile            # build assets
bundle exec sidekiq                    # background workers
```

## Idiomatic patterns (DO)

- **ActiveRecord scopes for reusable queries** — chainable, composable, testable. `scope :active, -> { where(archived_at: nil) }`.
- **Strong params in controllers** — `params.require(:user).permit(:email, :name)`; never `params.permit!`.
- **`before_action :authenticate_user!`** — auth at the controller layer (Devise / custom). Authorization via Pundit policies (`authorize @post`).
- **Serializers separate from models** — JSON shape via `ActiveModel::Serializer`, Jbuilder, or Alba. Models stay free of view concerns.
- **RSpec or minitest with FactoryBot** — `create(:user, :admin)` with traits. Avoid fixtures for non-trivial cases.
- **Sidekiq for background jobs** — wrap with ActiveJob (`ApplicationJob`); idempotent `perform`; pass IDs, not records.

## Anti-patterns (AVOID — call out and fix when seen)

- **Skipping callbacks in tests** — `User.skip_callback(:save, ...)` masks behavior. Test the side effect or use `transactional_fixtures: false`.
- **Business logic inside callbacks** — `after_save :charge_card` causes order-of-execution bugs. Move to a service called from the controller.
- **`Model.all.each` over large tables** — loads everything into memory. Use `find_each` or `in_batches`.
- **Raw SQL when ActiveRecord works** — loses safety, composability, portability. Whitelist for performance-critical reports only, with parameterized bindings.
- **`before_action :load_resource` chains hiding logic** — implicit lookups confuse intent. Prefer explicit `@post = Post.find(params[:id])` and `authorize @post` (Pundit).
- **Mismatched `Gemfile.lock` platforms** — lockfile resolved on macOS breaks Linux CI. Run `bundle lock --add-platform x86_64-linux` and commit.
- **N+1 queries** — `posts.each { |p| p.author.name }` without `.includes(:author)`. Use `bullet` gem in dev; assert no N+1 in tests.
- **String interpolation in `where`** — `where("name = '#{name}'")` is SQL injection. Always `where(name: name)` or `where("name = ?", name)`.

## Test layer hierarchy

1. **Model / unit specs (RSpec or minitest)** — fast, isolated. Validations, scopes, instance methods, service objects. FactoryBot, hit DB only when AR is essential.
2. **Request / controller specs** — exercise routing, params, auth, response shape. Prefer request specs over controller specs in modern Rails.
3. **System specs via Capybara** — **LAST RESORT.** Full-stack browser tests. Reserve for genuine user-flow regressions (checkout, signup) where Turbo / JS interaction matters.

## Tactical testing rules

- One assertion theme per `it` block; use `aggregate_failures` for multi-attribute checks.
- FactoryBot traits over conditional factories. `create(:order, :paid, :shipped)`.
- Stub at boundaries: HTTP via WebMock/VCR, time via `ActiveSupport::Testing::TimeHelpers` (`travel_to`).
- Background jobs: `perform_enqueued_jobs` block; assert `have_enqueued_job(MyJob)`.
- Avoid `allow_any_instance_of` — signals leaking design; refactor to inject the collaborator.
- Run `bin/rspec --bisect` on a flake; fix or delete, never retry.

## Stack-specific gotchas

- **Autoloading (Zeitwerk)** — file path must match constant (`app/services/users/create.rb` → `Users::Create`). Mismatches surface as `NameError` only on first reference.
- **Strong migrations** — adding `NOT NULL` to a large table locks it. `add_column` then backfill in batches then `change_column_null`. Consider `strong_migrations` gem.
- **`update` vs `update!`** — non-bang silently returns false on validation failure. Prefer the bang in services and jobs.
- **Connection pool exhaustion** — Sidekiq concurrency must be `<=` `pool` in `database.yml`. Mismatches cause sporadic `ConnectionTimeoutError`.
- **`enum` collisions** — `enum status: [:active, :archived]` defines `Model.active` shadowing scopes; prefer hash form with `_prefix: true`.
- **CSRF in API mode** — `protect_from_forgery with: :null_session` for JSON; never disable globally.
- **Credentials, not ENV for secrets in repo** — `bin/rails credentials:edit` per environment; commit `config/credentials/*.yml.enc`, never the master key.
