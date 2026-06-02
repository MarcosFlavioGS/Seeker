default: run

# Start the Phoenix dev server
run:
    mix phx.server

# Start the Phoenix dev server with an IEx shell
iex:
    iex -S mix phx.server

# Install dependencies and set up assets
setup:
    mix setup

# Fetch dependencies
deps:
    mix deps.get

# Compile the project
compile:
    mix compile

# Run all tests
test:
    mix test

# Run a specific test file: just test-file test/my_test.exs
test-file file:
    mix test {{ file }}

# Re-run previously failing tests
test-failed:
    mix test --failed

# Format code
format:
    mix format

# Run pre-commit checks (compile, clean deps, format, test)
precommit:
    mix precommit
