NAME := CSign
SCHEME := CSign
PLATFORMS := iphoneos maccatalyst

TMP := ./.derivedData
CERT_JSON_URL := https://backloop.dev/pack.json

.PHONY: all clean deps $(PLATFORMS)

all: $(PLATFORMS)

clean:
	rm -rf $(TMP)
	rm -rf packages
	rm -rf Payload

deps:
	rm -rf deps || true
	mkdir -p deps

	curl -fsSL "$(CERT_JSON_URL)" -o cert.json
	jq -r '.cert' cert.json > deps/server.crt
	jq -r '.key1, .key2' cert.json > deps/server.pem
	jq -r '.info.domains.commonName' cert.json > deps/commonName.txt


$(PLATFORMS): deps
	rm -rf _build

	@if [ "$@" = "iphoneos" ]; then \
		DEST="generic/platform=iOS"; \
	else \
		DEST="generic/platform=macOS,variant=Mac Catalyst"; \
	fi; \
	xcodebuild \
		-project CSign.xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination "$$DEST" \
		-derivedDataPath $(TMP)/$@ \
		-clonedSourcePackagesDirPath SourcePackages \
		-skipPackagePluginValidation \
		-parallelizeTargets \
		CODE_SIGNING_ALLOWED=NO \
		ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO \
		COMPILER_INDEX_STORE_ENABLE=NO \
		DEBUG_INFORMATION_FORMAT=dwarf

	mkdir -p _build/Payload
	cp -R _build/Applications/*.app _build/Payload/CSign.app
	chmod -R 0755 _build/Payload/CSign.app
	codesign --force --sign - --timestamp=none _build/Payload/CSign.app
	cp deps/* _build/Payload/CSign.app/ || true
	mkdir -p _build/Payload/CSign.app/signing-assets/DefaultCert
	cp BuiltInCert/* _build/Payload/CSign.app/signing-assets/DefaultCert/ 2>/dev/null || true

	mkdir -p packages

	@if [ "$@" = "iphoneos" ]; then \
		ditto -c -k --sequesterRsrc --keepParent _build/Payload "packages/CSign.ipa"; \
	else \
		ditto -c -k --sequesterRsrc --keepParent _build/Payload/CSign.app "packages/CSign_Catalyst.zip"; \
	fi
