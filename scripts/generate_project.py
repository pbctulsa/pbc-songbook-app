#!/usr/bin/env python3
"""Generate the dependency-free Xcode project deterministically using Python 3."""
import hashlib
import pathlib
import json

ROOT = pathlib.Path(__file__).resolve().parents[1]
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def ref(name): return uid(name)
def add(identifier, **fields): objects[uid(identifier)] = fields; return uid(identifier)
def raw(value): return ('raw', value)
def quoted(value):
    if isinstance(value, tuple): return value[1]
    if isinstance(value, list): return '(\n' + ''.join(quoted(x) + ',\n' for x in value) + ')'
    if isinstance(value, dict): return '{\n' + ''.join(json.dumps(k) + ' = ' + quoted(v) + ';\n' for k,v in value.items()) + '}'
    return json.dumps(str(value))

def file(path, kind): return add(path, isa=raw('PBXFileReference'), lastKnownFileType=kind, path=path, sourceTree='SOURCE_ROOT')
app_sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT/'PBCSongbook').glob('*.swift'))
test_sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT/'PBCSongbookTests').glob('*.swift'))
for p in app_sources + test_sources: file(p, 'sourcecode.swift')
resources=['PBCSongbook/Assets.xcassets','PBCSongbook/Resources/catalog.json','PBCSongbook/PrivacyInfo.xcprivacy']
for p,k in zip(resources,['folder.assetcatalog','text.json','text.xml']): file(p,k)
for name,ext in [('PBCSongbook','app'),('PBCSongbookTests','xctest')]:
    add(name+'Product',isa=raw('PBXFileReference'),explicitFileType='wrapper.application' if ext=='app' else 'wrapper.cfbundle',path=name+'.'+ext,sourceTree='BUILT_PRODUCTS_DIR')
add('Products',isa=raw('PBXGroup'),children=[ref('PBCSongbookProduct'),ref('PBCSongbookTestsProduct')],name='Products',sourceTree='<group>')
add('Root',isa=raw('PBXGroup'),children=[ref(p) for p in app_sources+test_sources+resources]+[ref('Products')],sourceTree='<group>')

def phase(name,isa,paths):
    builds=[]
    for p in paths: builds.append(add(name+p,isa=raw('PBXBuildFile'),fileRef=ref(p)))
    return add(name,isa=raw(isa),buildActionMask=2147483647,files=builds,runOnlyForDeploymentPostprocessing=0)
phase('AppSources','PBXSourcesBuildPhase',app_sources)
phase('AppResources','PBXResourcesBuildPhase',resources)
phase('AppFrameworks','PBXFrameworksBuildPhase',[])
phase('TestSources','PBXSourcesBuildPhase',test_sources)
phase('TestResources','PBXResourcesBuildPhase',[])
phase('TestFrameworks','PBXFrameworksBuildPhase',[])
base={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'complete','TARGETED_DEVICE_FAMILY':'1,2'}
app={'PRODUCT_BUNDLE_IDENTIFIER':'org.pbctulsa.songbook','PRODUCT_NAME':'$(TARGET_NAME)','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_KEY_CFBundleDisplayName':'PBC Songbook','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.reference','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad':'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor','MARKETING_VERSION':'1.0','CURRENT_PROJECT_VERSION':'1','CODE_SIGN_STYLE':'Automatic','SWIFT_EMIT_LOC_STRINGS':'YES'}
test={'PRODUCT_BUNDLE_IDENTIFIER':'org.pbctulsa.songbook.tests','PRODUCT_NAME':'$(TARGET_NAME)','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/PBCSongbook.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/PBCSongbook','BUNDLE_LOADER':'$(TEST_HOST)','CODE_SIGN_STYLE':'Automatic'}
for group,settings in [('Project',base),('App',app),('Test',test)]:
    configs=[]
    for mode in ['Debug','Release']:
        d=dict(settings)
        if group=='Project': d.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym','ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if mode=='Debug' else ''})
        configs.append(add(group+mode,isa=raw('XCBuildConfiguration'),buildSettings=d,name=mode))
    add(group+'Configs',isa=raw('XCConfigurationList'),buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
add('TestProxy',isa=raw('PBXContainerItemProxy'),containerPortal=ref('Project'),proxyType=1,remoteGlobalIDString=ref('AppTarget'),remoteInfo='PBCSongbook')
add('TestDependency',isa=raw('PBXTargetDependency'),target=ref('AppTarget'),targetProxy=ref('TestProxy'))
add('AppTarget',isa=raw('PBXNativeTarget'),buildConfigurationList=ref('AppConfigs'),buildPhases=[ref('AppSources'),ref('AppFrameworks'),ref('AppResources')],buildRules=[],dependencies=[],name='PBCSongbook',productName='PBCSongbook',productReference=ref('PBCSongbookProduct'),productType='com.apple.product-type.application')
add('TestTarget',isa=raw('PBXNativeTarget'),buildConfigurationList=ref('TestConfigs'),buildPhases=[ref('TestSources'),ref('TestFrameworks'),ref('TestResources')],buildRules=[],dependencies=[ref('TestDependency')],name='PBCSongbookTests',productName='PBCSongbookTests',productReference=ref('PBCSongbookTestsProduct'),productType='com.apple.product-type.bundle.unit-test')
add('Project',isa=raw('PBXProject'),attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2600'},buildConfigurationList=ref('ProjectConfigs'),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=ref('Root'),productRefGroup=ref('Products'),projectDirPath='',projectRoot='',targets=[ref('AppTarget'),ref('TestTarget')])
project=ROOT/'PBCSongbook.xcodeproj'; project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+quoted({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':ref('Project')})+'\n')
schemes=project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
def buildref(name,target,ext): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref(target)}" BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:PBCSongbook.xcodeproj"/>'
a=buildref('PBCSongbook','AppTarget','app'); t=buildref('PBCSongbookTests','TestTarget','xctest')
(schemes/'PBCSongbook.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{a}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{t}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated',project.name)
