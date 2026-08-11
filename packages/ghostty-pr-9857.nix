{
  lib,
  stdenv,
  stdenvNoCC,
  fetchFromGitHub,
  fetchzip,
  writeShellScriptBin,
  cacert,
  gettext,
  ncurses,
  pandoc,
  xcodeenv,
  zig_0_16,
}:

let
  rev = "d68bd060ea4f38c7f8d3426355238b14936801fb";
  version = "1.3.2-dev+pr9857.${builtins.substring 0 8 rev}";
  metalToolchain = "com.apple.dt.toolchain.Metal.32023.883";

  src = fetchFromGitHub {
    owner = "ghostty-org";
    repo = "ghostty";
    inherit rev;
    hash = "sha256-h3n7ETZqm+RPICEJMmXXAUG0zoGTOoNuKpIU1KmnkI8=";
  };

  zigArtifacts = stdenvNoCC.mkDerivation {
    pname = "ghostty-pr-9857-zig-cache";
    inherit version src;

    nativeBuildInputs = [
      cacert
      zig_0_16
    ];

    phases = [
      "unpackPhase"
      "installPhase"
    ];

    installPhase = ''
      runHook preInstall

      export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
      ./nix/build-support/fetch-zig-cache.sh

      mkdir -p "$out"
      mv "$ZIG_GLOBAL_CACHE_DIR/p" "$out/p"

      runHook postInstall
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-iBAdrRgKY3nK0FzTT1Uz/FN37KyEMXUK1J/m2oxKMjA=";
  };

  # Zig 0.16 caches remote artifacts as archives, while --system expects
  # unpacked package directories. Re-fetching the fixed local files into a
  # separate cache performs that conversion without network access.
  zigCache = stdenvNoCC.mkDerivation {
    pname = "ghostty-pr-9857-zig-cache-unpacked";
    inherit version;

    dontUnpack = true;

    phases = [ "installPhase" ];

    installPhase = ''
      runHook preInstall

      cache_dir="$TMPDIR/zig-cache"
      mkdir -p "$cache_dir/p"
      for artifact in ${zigArtifacts}/p/*.tar.gz; do
        tar -xzf "$artifact" -C "$cache_dir/p"
      done

      mkdir -p "$out"
      mv "$cache_dir/p" "$out/p"

      runHook postInstall
    '';
  };

  sparkleArtifact = fetchzip {
    url = "https://github.com/sparkle-project/Sparkle/releases/download/2.9.0/Sparkle-for-Swift-Package-Manager.zip";
    hash = "sha256-9Qmig88mvTNUYOfpjoG0dTJAircWN/zG4TLejLmd9No=";
    stripRoot = false;
  };

  xcodeSelect = writeShellScriptBin "xcode-select" ''
    exec /usr/bin/xcode-select "$@"
  '';

  xcodeLibtool = writeShellScriptBin "libtool" ''
    exec /usr/bin/xcrun --sdk macosx libtool "$@"
  '';

  # Ghostty's macOS frontend is an Xcode project. Keep that impure dependency
  # narrow; preBuild below fails if the host moves to an untested release.
  xcodeWrapper = xcodeenv.composeXcodeWrapper { };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ghostty-pr-9857";
  inherit version src;

  strictDeps = true;

  nativeBuildInputs = [
    gettext
    ncurses
    pandoc
    xcodeLibtool
    xcodeSelect
    xcodeWrapper
    zig_0_16
  ];

  postPatch = ''
        project=macos/Ghostty.xcodeproj/project.pbxproj

        substituteInPlace "$project" \
          --replace-fail \
            'A51BFC272B30F1B800E92F16 /* Sparkle in Frameworks */ = {isa = PBXBuildFile; productRef = A51BFC262B30F1B800E92F16 /* Sparkle */; };' \
            'A51BFC272B30F1B800E92F16 /* Sparkle.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = A51BFC252B30F1B700E92F16 /* Sparkle.xcframework */; };
            A51BFC292B30F1B800E92F16 /* Sparkle.xcframework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = A51BFC252B30F1B700E92F16 /* Sparkle.xcframework */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };' \
          --replace-fail \
            '/* End PBXCopyFilesBuildPhase section */' \
            '        A51BFC2A2B30F1B800E92F16 /* Embed Frameworks */ = {
                isa = PBXCopyFilesBuildPhase;
                buildActionMask = 2147483647;
                dstPath = "";
                dstSubfolderSpec = 10;
                files = (
                    A51BFC292B30F1B800E92F16 /* Sparkle.xcframework in Embed Frameworks */,
                );
                name = "Embed Frameworks";
                runOnlyForDeploymentPostprocessing = 0;
            };
    /* End PBXCopyFilesBuildPhase section */' \
          --replace-fail \
            '/* Begin PBXFileReference section */' \
            '/* Begin PBXFileReference section */
            A51BFC252B30F1B700E92F16 /* Sparkle.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; name = Sparkle.xcframework; path = "${sparkleArtifact}/Sparkle.xcframework"; sourceTree = "<absolute>"; };' \
          --replace-fail \
            'A51BFC272B30F1B800E92F16 /* Sparkle in Frameworks */,' \
            'A51BFC272B30F1B800E92F16 /* Sparkle.xcframework in Frameworks */,' \
          --replace-fail \
            'A56B880A2A840447007A0E29 /* Carbon.framework */,' \
            'A56B880A2A840447007A0E29 /* Carbon.framework */,
                    A51BFC252B30F1B700E92F16 /* Sparkle.xcframework */,' \
      --replace-fail \
        'A5B3052E299BEAAA0047F10C /* Frameworks */,' \
        'A5B3052E299BEAAA0047F10C /* Frameworks */,
                A51BFC2A2B30F1B800E92F16 /* Embed Frameworks */,' \
          --replace-fail 'A51BFC262B30F1B800E92F16 /* Sparkle */,' "" \
          --replace-fail 'A51BFC252B30F1B700E92F16 /* XCRemoteSwiftPackageReference "Sparkle" */,' ""

        sed -i '/\/\* Begin XCRemoteSwiftPackageReference section \*\//,/\/\* End XCRemoteSwiftPackageReference section \*\//d' "$project"
        sed -i '/\/\* Begin XCSwiftPackageProductDependency section \*\//,/\/\* End XCSwiftPackageProductDependency section \*\//d' "$project"
        rm -f macos/Ghostty.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

        substituteInPlace src/build/MetallibStep.zig \
          --replace-fail '"/usr/bin/xcrun", "-sdk", sdk, "metal"' '"/usr/bin/xcrun", "--toolchain", "${metalToolchain}", "-sdk", sdk, "metal"' \
          --replace-fail '"/usr/bin/xcrun", "-sdk", sdk, "metallib"' '"/usr/bin/xcrun", "--toolchain", "${metalToolchain}", "-sdk", sdk, "metallib"'

        substituteInPlace src/build/GhosttyXcodebuild.zig \
          --replace-fail \
            '        if (env.get("PATH")) |v| try env_map.put("PATH", v);' \
            '        if (env.get("PATH")) |v| try env_map.put("PATH", v);
            if (env.get("HOME")) |v| {
                try env_map.put("HOME", v);
                try env_map.put("CFFIXED_USER_HOME", v);
            }
            if (env.get("DEVELOPER_DIR")) |v| try env_map.put("DEVELOPER_DIR", v);'
  '';

  preBuild = ''
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    xcode_version="$(xcodebuild -version | sed -n '1p')"
    if [[ "$xcode_version" != "Xcode 26.6" ]]; then
      echo "Expected Xcode 26.6, got: $xcode_version" >&2
      exit 1
    fi

    if ! /usr/bin/xcrun --toolchain ${metalToolchain} metal -v >/dev/null; then
      echo "Expected installed Metal toolchain ${metalToolchain}" >&2
      exit 1
    fi
  '';

  dontSetZigDefaultFlags = true;
  zigBuildFlags = [
    "--system"
    "${zigCache}/p"
    "-Dversion-string=${finalAttrs.version}"
    "-Dcpu=baseline"
    "-Doptimize=ReleaseFast"
    "-Dxcframework-target=native"
  ];

  doCheck = false;

  # Generic Darwin fixups strip Mach-O files and invalidate Xcode's nested
  # signatures. The ReleaseFast build is already optimized by Zig/Xcode.
  dontFixup = true;

  postInstall = ''
    mkdir -p "$out/Applications" "$out/bin"
    mv "$out/Ghostty.app" "$out/Applications/Ghostty.app"
    ln -s ../Applications/Ghostty.app/Contents/MacOS/ghostty "$out/bin/ghostty"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    /usr/bin/lipo "$out/Applications/Ghostty.app/Contents/MacOS/ghostty" -verify_arch arm64
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$out/Applications/Ghostty.app"
    "$out/bin/ghostty" +version | grep -F '${finalAttrs.version}'
  '';

  # The wrapper intentionally calls the locally installed Xcode toolchain.
  __noChroot = true;

  passthru = {
    pr = 9857;
    inherit rev zigArtifacts zigCache;
  };

  meta = {
    description = "Ghostty with Quick Terminal tab support from PR #9857";
    homepage = "https://github.com/ghostty-org/ghostty/pull/9857";
    license = lib.licenses.mit;
    mainProgram = "ghostty";
    platforms = [ "aarch64-darwin" ];
  };
})
