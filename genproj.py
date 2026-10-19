#!/usr/bin/env python3
"""Generate minimal Fill.xcodeproj for the fill. iOS app (iOS 18, Swift 6)."""
import hashlib, os

ROOT = "/Users/nehilsrivastava/Documents/repos/DoGet"
PROJ = os.path.join(ROOT, "Fill.xcodeproj")
os.makedirs(PROJ, exist_ok=True)

# Code signing: set TEAM_ID to your 10-character Apple Team ID to hardcode
# device signing (else leave empty and pick the team in Xcode on first run).
TEAM_ID = ""

# Bundle identifier: must be globally unique on your development team.
# com.fill.app is taken — change this one constant if Apple rejects it too.
BUNDLE_ID = "app.fill.do"

sources = [
    "Fill/App/FillApp.swift",
    "Fill/App/AppState.swift",
    "Fill/DesignSystem/DesignSystem.swift",
    "Fill/DesignSystem/Components.swift",
    "Fill/Domain/Types.swift",
    "Fill/Domain/Engine.swift",
    "Fill/Domain/Derive.swift",
    "Fill/Domain/Format.swift",
    "Fill/Domain/Copy.swift",
    "Fill/Domain/CreateDraft.swift",
    "Fill/Persistence/Models.swift",
    "Fill/Persistence/Mapping.swift",
    "Fill/Persistence/Repository.swift",
    "Fill/Persistence/Seed.swift",
    "Fill/Persistence/StorePlan.swift",
    "Fill/Activity/ActivitySources.swift",
    "Fill/Activity/HealthKitController.swift",
    "Fill/Engagement/Engagement.swift",
    "Fill/Features/Overview/OverviewView.swift",
    "Fill/Features/ChallengePage/ChallengePageView.swift",
    "Fill/Features/ChallengePage/ShareCard.swift",
    "Fill/Features/Pager/PagerView.swift",
    "Fill/Features/Pager/PageBuilder.swift",
    "Fill/Features/Create/CreateView.swift",
    "Fill/Features/Celebration/MomentsViews.swift",
    "Fill/Features/Rescue/RescueView.swift",
    "Fill/Features/Onboarding/OnboardingView.swift",
    "Fill/Features/Settings/SettingsViews.swift",
    "Fill/Features/Debug/ShotMode.swift",]
test_sources = [
    "Fill/Domain/Types.swift",
    "Fill/Domain/Engine.swift",
    "Fill/Domain/Derive.swift",
    "Fill/Domain/Format.swift",
    "Fill/Domain/Copy.swift",
    "Fill/Domain/CreateDraft.swift",
    "FillTests/DomainTests.swift",
]
uitest_sources = ["FillUITests/CreateFlowTests.swift"]

def uid(name: str) -> str:
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()

lines = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tclasses = {};")
lines.append("\tobjectVersion = 77;")
lines.append("\tobjects = {")

def add(ident, isa, extra):
    extra = extra.strip()
    if extra.endswith(";"):
        extra = extra[:-1].rstrip()
    lines.append(f"\t\t{ident} = {{ isa = {isa}; {extra}; }};")

# IDs
proj_id = uid("project")
main_group = uid("maingroup")
fill_group = uid("fillgroup")
tests_group = uid("testsgroup")
products_group = uid("productsgroup")
app_target = uid("apptarget")
test_target = uid("testtarget")
uitest_target = uid("uitesttarget")
uitests_group = uid("uitestsgroup")
app_product = uid("appproduct")
test_product = uid("testproduct")
uitest_product = uid("uitestproduct")
build_phases_app = [uid("appsources"), uid("appframeworks"), uid("appresources")]
build_phases_test = [uid("testsources"), uid("testframeworks"), uid("testresources")]
cfglist_proj = uid("cfglistproj")
cfglist_app = uid("cfglistapp")
cfglist_test = uid("cfglisttest")
cfg_dbg_proj = uid("cfgdbgproj"); cfg_rel_proj = uid("cfgrelproj")
cfg_dbg_app = uid("cfgdbgapp"); cfg_rel_app = uid("cfgrelapp")
cfg_dbg_test = uid("cfgdbgtest"); cfg_rel_test = uid("cfgreltest")
swift_ver = "6.0"
team_setting = f"DEVELOPMENT_TEAM = {TEAM_ID}; " if TEAM_ID else ""

# File refs (test target gets its own refs even for shared paths)
filerefs = {}
for s in sources:
    filerefs[s] = uid("file" + s)
testrefs = {}
for s in test_sources:
    testrefs[s] = uid("testfile" + s)
for s in uitest_sources:
    testrefs[s] = uid("uitestfile" + s)
filerefs["app"] = app_product
filerefs["test"] = test_product

for s in sources:
    add(filerefs[s], "PBXFileReference", f'path = "{s}"; sourceTree = "<group>"')
for s in test_sources:
    add(testrefs[s], "PBXFileReference", f'path = "{s}"; sourceTree = "<group>"')
for s in uitest_sources:
    add(testrefs[s], "PBXFileReference", f'path = "{s}"; sourceTree = "<group>"')

add(app_product, "PBXFileReference", 'explicitFileType = "wrapper.application"; path = "Fill.app"; sourceTree = BUILT_PRODUCTS_DIR')
add(test_product, "PBXFileReference", 'explicitFileType = "wrapper.cfbundle"; path = "FillTests.xctest"; sourceTree = BUILT_PRODUCTS_DIR')

# Build files
bf_app = [uid("bf" + s) for s in sources]
bf_test = [uid("bft" + s) for s in test_sources]
bf_uitest = [uid("bfu" + s) for s in uitest_sources]
for bf, s in zip(bf_app, sources):
    add(bf, "PBXBuildFile", f"fileRef = {filerefs[s]}")
for bf, s in zip(bf_test, test_sources):
    add(bf, "PBXBuildFile", f"fileRef = {testrefs[s]}")
for bf, s in zip(bf_uitest, uitest_sources):
    add(bf, "PBXBuildFile", f"fileRef = {testrefs[s]}")

# Resources (privacy manifest must ship in the bundle)
resources = ["Fill/Resources/PrivacyInfo.xcprivacy"]
resrefs = {}
for s in resources:
    resrefs[s] = uid("res" + s)
    add(resrefs[s], "PBXFileReference", f'path = "{s}"; sourceTree = "<group>"')
bf_res = [uid("bfr" + s) for s in resources]
for bf, s in zip(bf_res, resources):
    add(bf, "PBXBuildFile", f"fileRef = {resrefs[s]}")

# Groups
children_fill = " ".join(filerefs[s] + "," for s in sources)
children_tests = " ".join(testrefs[s] + "," for s in test_sources)
children_uitests = " ".join(testrefs[s] + "," for s in uitest_sources)
add(fill_group, "PBXGroup", f'children = ({children_fill}); name = Fill; sourceTree = "<group>"')
add(tests_group, "PBXGroup", f'children = ({children_tests}); name = FillTests; sourceTree = "<group>"')
add(uitests_group, "PBXGroup", f'children = ({children_uitests}); name = FillUITests; sourceTree = "<group>"')
add(uitest_product, "PBXFileReference", 'explicitFileType = "wrapper.cfbundle"; path = "FillUITests.xctest"; sourceTree = BUILT_PRODUCTS_DIR')
add(products_group, "PBXGroup", f'children = ({app_product}, {test_product}, {uitest_product},); name = Products; sourceTree = "<group>"')
add(main_group, "PBXGroup", f'children = ({fill_group}, {tests_group}, {uitests_group}, {products_group},); sourceTree = "<group>"')

# Sources phases
add(build_phases_app[0], "PBXSourcesBuildPhase", f'buildActionMask = 2147483647; files = ({" ".join(b + "," for b in bf_app)}); runOnlyForDeploymentPostprocessing = 0')
add(build_phases_app[1], "PBXFrameworksBuildPhase", 'buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0')
add(build_phases_app[2], "PBXResourcesBuildPhase", f'buildActionMask = 2147483647; files = ({" ".join(b + "," for b in bf_res)}); runOnlyForDeploymentPostprocessing = 0')
add(build_phases_test[0], "PBXSourcesBuildPhase", f'buildActionMask = 2147483647; files = ({" ".join(b + "," for b in bf_test)}); runOnlyForDeploymentPostprocessing = 0')
add(build_phases_test[1], "PBXFrameworksBuildPhase", 'buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0')
add(build_phases_test[2], "PBXResourcesBuildPhase", 'buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0')
build_phases_uitest = [uid("uitestsources"), uid("uitestframeworks"), uid("uitestresources")]
add(build_phases_uitest[0], "PBXSourcesBuildPhase", f'buildActionMask = 2147483647; files = ({" ".join(b + "," for b in bf_uitest)}); runOnlyForDeploymentPostprocessing = 0')
add(build_phases_uitest[1], "PBXFrameworksBuildPhase", 'buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0')
add(build_phases_uitest[2], "PBXResourcesBuildPhase", 'buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0')

# Targets
add(app_target, "PBXNativeTarget", f'buildConfigurationList = {cfglist_app}; buildPhases = ({", ".join(build_phases_app)},); buildRules = (); dependencies = (); name = Fill; productName = Fill; productReference = {app_product}; productType = "com.apple.product-type.application"')
add(test_target, "PBXNativeTarget", f'buildConfigurationList = {cfglist_test}; buildPhases = ({", ".join(build_phases_test)},); buildRules = (); dependencies = (); name = FillTests; productName = FillTests; productReference = {test_product}; productType = "com.apple.product-type.bundle.unit-test"')
cfglist_uitest = uid("cfglistuitest")
cfg_dbg_uitest = uid("cfgdbguitest"); cfg_rel_uitest = uid("cfgreluitest")
add(uitest_target, "PBXNativeTarget", f'buildConfigurationList = {cfglist_uitest}; buildPhases = ({", ".join(build_phases_uitest)},); buildRules = (); dependencies = (); name = FillUITests; productName = FillUITests; productReference = {uitest_product}; productType = "com.apple.product-type.bundle.ui-testing"')

# Project
add(proj_id, "PBXProject", f'buildConfigurationList = {cfglist_proj}; compatibilityVersion = "Xcode 16.0"; developmentRegion = en; knownRegions = (en,); mainGroup = {main_group}; targets = ({app_target}, {test_target}, {uitest_target},)')

# Configs
def cfg(ident, name, settings):
    add(ident, "XCBuildConfiguration", f'buildSettings = {{{settings}}}; name = {name}')
common_app = ("ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES; "
    "CLANG_ENABLE_MODULES = YES; CODE_SIGN_STYLE = Automatic; "
    + team_setting +
    "CURRENT_PROJECT_VERSION = 1; INFOPLIST_FILE = Fill/Resources/Info.plist; "
    "CODE_SIGN_ENTITLEMENTS = Fill/Resources/Fill.entitlements; "
    'IPHONEOS_DEPLOYMENT_TARGET = 18.0; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks"); '
    f"MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}; PRODUCT_NAME = Fill; "
    f"SWIFT_VERSION = {swift_ver}; SWIFT_STRICT_CONCURRENCY = complete; SWIFT_EMIT_LOC_STRINGS = YES; "
    'SDKROOT = iphoneos; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; '
    "TARGETED_DEVICE_FAMILY = 1; ")
cfg(cfg_dbg_app, "Debug", common_app + "SWIFT_OPTIMIZATION_LEVEL = -Onone; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; ENABLE_TESTABILITY = YES; ")
cfg(cfg_rel_app, "Release", common_app)
cfg(cfg_dbg_test, "Debug", f'BUNDLE_LOADER = "$(TEST_HOST)"; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 18.0; MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.tests; PRODUCT_NAME = FillTests; SWIFT_VERSION = {swift_ver}; SWIFT_STRICT_CONCURRENCY = complete; SWIFT_OPTIMIZATION_LEVEL = -Onone; SDKROOT = iphoneos; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; TARGETED_DEVICE_FAMILY = 1; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Fill.app/Fill"; ')
cfg(cfg_rel_test, "Release", f'BUNDLE_LOADER = "$(TEST_HOST)"; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 18.0; MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.tests; PRODUCT_NAME = FillTests; SWIFT_VERSION = {swift_ver}; SWIFT_STRICT_CONCURRENCY = complete; SDKROOT = iphoneos; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; TARGETED_DEVICE_FAMILY = 1; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Fill.app/Fill"; ')
uitest_settings = (f'CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; GENERATE_INFOPLIST_FILE = YES; '
    f'IPHONEOS_DEPLOYMENT_TARGET = 18.0; MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.uitests; '
    f'PRODUCT_NAME = FillUITests; SWIFT_VERSION = {swift_ver}; SWIFT_STRICT_CONCURRENCY = complete; '
    'SDKROOT = iphoneos; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; TARGETED_DEVICE_FAMILY = 1; '
    'TEST_TARGET_NAME = Fill; ')
cfg(cfg_dbg_uitest, "Debug", uitest_settings + 'SWIFT_OPTIMIZATION_LEVEL = -Onone; ')
cfg(cfg_rel_uitest, "Release", uitest_settings)
cfg(cfg_dbg_proj, "Debug", 'ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ANALYZER_NONNULL = YES; CLANG_CXX_LANGUAGE_STANDARD = "gnu++20"; GCC_C_LANGUAGE_STANDARD = gnu17; ')
cfg(cfg_rel_proj, "Release", "ALWAYS_SEARCH_USER_PATHS = NO; ")
add(cfglist_proj, "XCConfigurationList", f'buildConfigurations = ({cfg_dbg_proj}, {cfg_rel_proj},); defaultConfigurationIsVisible = 0')
add(cfglist_app, "XCConfigurationList", f'buildConfigurations = ({cfg_dbg_app}, {cfg_rel_app},); defaultConfigurationIsVisible = 0')
add(cfglist_test, "XCConfigurationList", f'buildConfigurations = ({cfg_dbg_test}, {cfg_rel_test},); defaultConfigurationIsVisible = 0')
add(cfglist_uitest, "XCConfigurationList", f'buildConfigurations = ({cfg_dbg_uitest}, {cfg_rel_uitest},); defaultConfigurationIsVisible = 0')

lines.append("\t};")
lines.append(f"\trootObject = {proj_id};")
lines.append("}")

with open(os.path.join(PROJ, "project.pbxproj"), "w") as f:
    f.write("\n".join(lines))
print("wrote", os.path.join(PROJ, "project.pbxproj"))
