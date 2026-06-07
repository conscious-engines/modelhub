# Default: list available recipes
default:
    @just --list

# Verify prerequisites (Xcode, xcodebuild)
pre:
    @bash just_scripts/prereqs.sh

# Build the app (Debug by default; pass config=Release to override)
build config="Debug":
    @bash just_scripts/build.sh modelhub {{config}}

# Build and launch the app
run:
    @bash just_scripts/run.sh

# Clean build artifacts
clean:
    @bash just_scripts/clean.sh
