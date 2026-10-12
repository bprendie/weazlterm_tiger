CC ?= cc
CFLAGS ?= -O2 -g
WARN = -Wall -Wextra -Wpedantic
CORE = src/screen.c src/parser.c src/csi.c src/color.c
SESSION = src/session.c src/session_io.c
COCOA = src/main.m src/WeazlView.m src/WeazlDrawing.m src/WeazlInput.m
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
PTY_LIB =
THREAD_LIB =
else
PTY_LIB = -lutil
THREAD_LIB = -pthread
endif
TIGER_FLAGS ?= -arch ppc -mmacosx-version-min=10.4
APP = build/Weazlterm.app

.PHONY: all test sanitize ssh ssh-ppc objc-frontend-ppc app app-ppc clean
all: test

build:
	mkdir -p build

build/test-terminal: $(CORE) src/terminal.h tests/test_terminal.c | build
	$(CC) $(CFLAGS) $(WARN) -std=c99 -Isrc $(CORE) tests/test_terminal.c -o $@

build/test-session: $(SESSION) src/session.h tests/test_session.c | build
	$(CC) $(CFLAGS) $(WARN) -std=c99 -Isrc $(SESSION) tests/test_session.c $(THREAD_LIB) $(PTY_LIB) -o $@

test: build/test-terminal build/test-session
	./build/test-terminal
	./build/test-session
	sh tests/test_shell_resolution.sh

sanitize: | build
	$(CC) -O1 -g $(WARN) -std=c99 -Isrc -fsanitize=address,undefined -fno-omit-frame-pointer $(CORE) tests/test_terminal.c -o build/test-terminal-sanitize
	./build/test-terminal-sanitize
	$(CC) -O1 -g $(WARN) -std=c99 -Isrc -fsanitize=address,undefined -fno-omit-frame-pointer $(SESSION) tests/test_session.c $(THREAD_LIB) $(PTY_LIB) -o build/test-session-sanitize
	./build/test-session-sanitize

ssh:
	sh scripts/build-ssh.sh

# Requires the verified OpenSSH sources and PPC Tiger cross-toolchain.
ssh-ppc:
	sh scripts/build-ssh-ppc.sh

# Build the missing Darwin/PPC Objective-C compiler front end.
objc-frontend-ppc:
	sh scripts/build-objc-frontend.sh

# Build the release bundle from Linux with the pinned Tiger PPC toolchain.
app-ppc: ssh-ppc objc-frontend-ppc
	sh scripts/build-app-ppc.sh

# Development bundle using a native Darwin SDK/compiler.
app: | build
	@test "$(UNAME_S)" = Darwin || { echo 'AppKit requires a Mac OS X SDK and compiler; run this target on Tiger.' >&2; exit 1; }
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources/shell $(APP)/Contents/Helpers
	$(CC) $(CFLAGS) -Wall -Wextra -std=gnu99 $(TIGER_FLAGS) -Isrc $(CORE) $(SESSION) $(COCOA) -framework Cocoa $(THREAD_LIB) $(PTY_LIB) -o $(APP)/Contents/MacOS/weazlterm
	cp resources/Info.plist $(APP)/Contents/Info.plist
	cp resources/WeazlTerm.icns $(APP)/Contents/Resources/WeazlTerm.icns
	cp resources/shell/weazlterm.bashrc $(APP)/Contents/Resources/shell/weazlterm.bashrc
	@echo 'Development app built. SSH packaging is a separate, verified step.'

clean:
	rm -f build/test-terminal build/test-session build/test-terminal-sanitize build/test-session-sanitize
