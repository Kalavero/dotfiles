#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/kalavero-ruby-qa-test.XXXXXX")"
project_dir="$test_root/project"
fake_bin="$test_root/bin"
command_log="$test_root/commands.log"
mkdir -p "$project_dir" "$fake_bin"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

cat > "$fake_bin/bundle" <<'BUNDLE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${RUBY_QA_TEST_LOG:?}"
BUNDLE
chmod +x "$fake_bin/bundle"

[ "$("$REPO_DIR/bin/.local/bin/ruby_qa" --version)" = '1.0.0' ] || fail 'ruby_qa should expose its version'
if "$REPO_DIR/bin/.local/bin/ruby_qa" --unknown >/dev/null; then
  fail 'ruby_qa should reject unknown options'
else
  [ "$?" -eq 2 ] || fail 'unknown ruby_qa options should exit 2'
fi

git -C "$project_dir" init -q -b main
git -C "$project_dir" config user.email ruby-qa-test@example.com
git -C "$project_dir" config user.name 'Ruby QA Test'

mkdir -p \
  "$project_dir/app/models" \
  "$project_dir/apps/api/app/services" \
  "$project_dir/apps/api/config" \
  "$project_dir/apps/api/spec/services" \
  "$project_dir/config" \
  "$project_dir/spec/models"
cat > "$project_dir/Gemfile" <<'RUBY'
source "https://rubygems.org"
RUBY
cat > "$project_dir/config/application.rb" <<'RUBY'
class Application
end
RUBY
cat > "$project_dir/app/models/user.rb" <<'RUBY'
class User
end
RUBY
cat > "$project_dir/app/models/account.rb" <<'RUBY'
class Account
end
RUBY
cat > "$project_dir/packwerk.yml" <<'YAML'
include:
  - "**/*.rb"
YAML
cat > "$project_dir/package.yml" <<'YAML'
enforce_dependencies: true
YAML
cat > "$project_dir/apps/api/Gemfile" <<'RUBY'
source "https://rubygems.org"
RUBY
cat > "$project_dir/apps/api/config/application.rb" <<'RUBY'
class ApiApplication
end
RUBY
cat > "$project_dir/apps/api/app/services/billing.rb" <<'RUBY'
class Billing
end
RUBY
cat > "$project_dir/apps/api/packwerk.yml" <<'YAML'
include:
  - "**/*.rb"
YAML
cat > "$project_dir/apps/api/package.yml" <<'YAML'
enforce_dependencies: true
YAML
git -C "$project_dir" add .
git -C "$project_dir" commit -qm 'Initial fixture'
git -C "$project_dir" checkout -qb feature/ruby-qa

cat > "$project_dir/app/models/user.rb" <<'RUBY'
class User
  def active?
    true
  end
end
RUBY
cat > "$project_dir/spec/models/user_spec.rb" <<'RUBY'
RSpec.describe User do
  it { is_expected.to be_active }
end
RUBY
cat > "$project_dir/apps/api/app/services/billing.rb" <<'RUBY'
class Billing
  def charge
    true
  end
end
RUBY
cat > "$project_dir/apps/api/spec/services/billing_spec.rb" <<'RUBY'
RSpec.describe Billing do
  it { is_expected.to respond_to(:charge) }
end
RUBY
cat > "$project_dir/README.md" <<'MARKDOWN'
# Unrelated documentation
MARKDOWN

(
  cd "$project_dir"
  PATH="$fake_bin:$PATH" \
    RUBY_QA_BASE_REF=main \
    RUBY_QA_TEST_LOG="$command_log" \
    "$REPO_DIR/bin/.local/bin/ruby_qa"
)

assert_contains 'exec rubocop --force-exclusion -- app/models/user.rb spec/models/user_spec.rb' "$command_log"
assert_contains 'exec brakeman --no-pager --only-files app/models/user.rb' "$command_log"
assert_contains 'exec packwerk check app/models/user.rb' "$command_log"
assert_contains 'exec rspec spec/models/user_spec.rb' "$command_log"
assert_contains 'exec reek -- app/models/user.rb' "$command_log"
assert_contains 'exec rubocop --force-exclusion -- app/services/billing.rb spec/services/billing_spec.rb' "$command_log"
assert_contains 'exec brakeman --no-pager --only-files app/services/billing.rb' "$command_log"
assert_contains 'exec packwerk check app/services/billing.rb' "$command_log"
assert_contains 'exec rspec spec/services/billing_spec.rb' "$command_log"
assert_contains 'exec reek -- app/services/billing.rb' "$command_log"
assert_not_contains 'packwerk validate' "$command_log"
assert_not_contains 'account.rb' "$command_log"
assert_not_contains 'apps/api/app/services/billing.rb' "$command_log"
assert_not_contains 'README.md' "$command_log"

cat > "$project_dir/package.yml" <<'YAML'
enforce_dependencies: strict
YAML
: > "$command_log"

(
  cd "$project_dir"
  PATH="$fake_bin:$PATH" \
    RUBY_QA_BASE_REF=main \
    RUBY_QA_TEST_LOG="$command_log" \
    "$REPO_DIR/bin/.local/bin/ruby_qa"
)

assert_contains 'exec packwerk validate' "$command_log"

pass 'ruby_qa scopes each quality tool to files affected by the current branch'
