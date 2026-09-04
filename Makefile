.PHONY: build test app dmg deploy run clean

build:
	swift build

test:
	swift test

app:
	./Scripts/package-app.sh

dmg:
	./Scripts/build-dmg.sh

deploy:
	./Scripts/deploy-release.sh

run: app
	open "Build/Chad Commander.app"

clean:
	swift package clean
	rm -rf "Build/Chad Commander.app"
