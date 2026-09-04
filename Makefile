.PHONY: build test app setup-release dmg deploy release run clean

build:
	swift build

test:
	swift test

app:
	./Scripts/package-app.sh

setup-release:
	./Scripts/setup-release.sh

dmg:
	./Scripts/build-dmg.sh

deploy:
	./Scripts/deploy-release.sh

release:
	./Scripts/release.sh

run: app
	open "Build/Chad Commander.app"

clean:
	swift package clean
	rm -rf "Build/Chad Commander.app"
