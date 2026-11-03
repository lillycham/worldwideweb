# WorldWideWeb for modern macOS
#
# Builds build/WorldWideWeb.app from src/ (the port) and the resources in
# original/ (used as they are). Uses the Xcode command line tools.

NAME	= WorldWideWeb
APP	= build/$(NAME).app
ORIG	= original/NextStep/Implementation
RES	= $(ORIG)/WorldWideWeb.app

CC	= xcrun clang
ARCHS	?= -arch arm64 -arch x86_64
CFLAGS	= $(ARCHS) -mmacosx-version-min=11.0 -g -O0 \
	  -DNeXT -Isrc/compat -Isrc \
	  -fno-objc-arc -fobjc-exceptions \
	  -Wall -Wno-format -Wno-unused-variable -Wno-unused-function \
	  -Wno-deprecated-declarations -Wno-implicit-int -Wno-parentheses \
	  -Wno-objc-method-access -Wno-mismatched-return-types \
	  -Wno-incompatible-pointer-types -Wno-int-conversion \
	  -Wno-pointer-sign -Wno-dangling-else -Wno-objc-root-class \
	  -Wno-incomplete-implementation -Wno-protocol -Wno-return-type \
	  -Wno-unused-but-set-variable -Wno-sometimes-uninitialized \
	  -Wno-objc-property-no-attribute -Wno-strict-prototypes \
	  -Wno-switch -Wno-missing-braces -Wno-unused-value \
	  -Wno-implicit-function-declaration -Wno-non-literal-null-conversion -Wno-nonportable-include-path
# The compat header goes first, so that AppKit is loaded before the NeXT
# header shims (see src/compat/appkit/appkit.h).
OBJCFLAGS = -include src/compat/NeXTCompat.h
LDFLAGS	= $(ARCHS) -mmacosx-version-min=11.0 \
	  -framework Cocoa -framework UniformTypeIdentifiers

# TBL's files, as listed in his PB.project, then the port's own files.
CFILES	= HTAccess.c HTFile.c HTFTP.c HTParse.c HTString.c HTTCP.c HTTP.c
MFILES	= Anchor.m FileAccess.m HTStyle.m HyperAccess.m HyperManager.m \
	  HyperText.m NewsAccess.m StyleToy.m TcpAccess.m TextToy.m \
	  WWWPageLayout.m WorldWideWeb_main.m \
	  WorldWideWeb_nib.m NeXTMenu.m compat/NeXTCompat.m compat/PageLayout.m

OBJS	= $(addprefix build/obj/,$(CFILES:.c=.o) $(notdir $(MFILES:.m=.o)))

RESOURCES = $(RES)/default.html $(RES)/help.html $(RES)/blank.html \
	    $(RES)/default.style $(RES)/compact.style $(RES)/paper.style \
	    $(RES)/project.style \
	    $(ORIG)/docflash.tiff $(ORIG)/docflash2.tiff $(ORIG)/icon1.tiff \
	    $(ORIG)/worldbook2.tiff \
	    resources/Info.rtf resources/NibTexts.plist

all: $(APP)

$(APP): build/$(NAME) Info.plist $(RESOURCES) build/$(NAME).icns
	rm -rf $@
	mkdir -p $@/Contents/MacOS $@/Contents/Resources
	cp build/$(NAME) $@/Contents/MacOS/
	cp Info.plist $@/Contents/
	cp $(RESOURCES) build/$(NAME).icns $@/Contents/Resources/
	codesign --force --sign - $@ >/dev/null 2>&1 || true

build/$(NAME): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

build/obj/%.o: src/%.c src/*.h | build/obj
	$(CC) $(CFLAGS) -c -o $@ $<

build/obj/%.o: src/%.m src/*.h src/compat/*.h | build/obj
	$(CC) $(CFLAGS) $(OBJCFLAGS) -c -o $@ $<

build/obj/%.o: src/compat/%.m src/compat/*.h | build/obj
	$(CC) $(CFLAGS) $(OBJCFLAGS) -c -o $@ $<

build/obj:
	mkdir -p $@

# The application icon, from TBL's worldbook2.tiff.
build/$(NAME).icns: $(ORIG)/worldbook2.tiff
	rm -rf build/$(NAME).iconset
	mkdir -p build/$(NAME).iconset
	for s in 16 32 128 256 512; do \
	  sips -s format png -z $$s $$s $< --out build/$(NAME).iconset/icon_$${s}x$${s}.png >/dev/null; \
	  d=$$((s*2)); \
	  sips -s format png -z $$d $$d $< --out build/$(NAME).iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	iconutil -c icns -o $@ build/$(NAME).iconset

run: $(APP)
	open $(APP)

clean:
	rm -rf build

.PHONY: all run clean

# Headless test of the HTML reader and writer (opens no windows).
TEST_OBJS = $(filter-out build/obj/WorldWideWeb_main.o build/obj/WorldWideWeb_nib.o,$(OBJS)) \
	    build/obj/htmltest.o

build/obj/htmltest.o: tests/htmltest.m src/*.h src/compat/*.h | build/obj
	$(CC) $(CFLAGS) $(OBJCFLAGS) -c -o $@ $<

build/htmltest: $(TEST_OBJS)
	$(CC) $(LDFLAGS) -o $@ $(TEST_OBJS)

test: build/htmltest
	build/htmltest -w $(RES)/default.html $(RES)/help.html $(RES)/blank.html

.PHONY: test

# Render the NeXT menu panels to PNG files in build/ (opens no windows).
build/menushot: tests/menushot.m src/NeXTMenu.m src/NeXTMenu.h | build/obj
	$(CC) $(ARCHS) -mmacosx-version-min=11.0 -fno-objc-arc -w -Isrc -framework Cocoa -o $@ $<

menushot: build/menushot
	build/menushot build

.PHONY: menushot

# Headless test of TBL's (active mode) FTP client.
build/ftptest: tests/ftptest.c build/obj/HTFTP.o build/obj/HTParse.o build/obj/HTTCP.o build/obj/HTString.o
	$(CC) $(ARCHS) -mmacosx-version-min=11.0 -DNeXT -Isrc/compat -Isrc -w -o $@ $^

ftptest: build/ftptest
	build/ftptest file://ftp.gnu.org/README | head -5

.PHONY: ftptest
