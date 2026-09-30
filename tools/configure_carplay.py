#!/usr/bin/env python3
"""Enable CarPlay only with an Apple-issued provisioning profile granting it.

Run after Apple approves Audio: python3 tools/configure_carplay.py --profile file.mobileprovision
Ordinary builds deliberately remain entitlement-free until then.
"""
import argparse, plistlib, subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--profile',required=True,type=Path);a=p.parse_args()
profile=plistlib.loads(subprocess.check_output(['security','cms','-D','-i',str(a.profile)]))
e=profile.get('Entitlements',{})
if not e.get('com.apple.developer.carplay-audio'):
    raise SystemExit('Profile does not grant com.apple.developer.carplay-audio; Apple approval is still required.')
if e.get('com.apple.developer.team-identifier') != 'YC5JZD3DY7' or not e.get('application-identifier','').endswith('.com.example.yswords'):
    raise SystemExit('Profile is not for this Words app and developer team.')
root=Path(__file__).resolve().parents[1]
ent=root/'ios/Runner/Runner.entitlements'
values=plistlib.loads(ent.read_bytes()) if ent.exists() else {}
values['com.apple.developer.carplay-audio']=True
ent.write_bytes(plistlib.dumps(values))
info=root/'ios/Runner/Info.plist';data=plistlib.loads(info.read_bytes())
manifest=data['UIApplicationSceneManifest'];manifest['UIApplicationSupportsMultipleScenes']=True
scenes=manifest['UISceneConfigurations'];phone=scenes['UIWindowSceneSessionRoleApplication'][0]
phone.pop('UISceneStoryboardFile',None);phone['UISceneDelegateClassName']='$(PRODUCT_MODULE_NAME).WordsPhoneScene'
scenes['CPTemplateApplicationSceneSessionRoleApplication']=[{'UISceneClassName':'CPTemplateApplicationScene','UISceneConfigurationName':'CarPlay','UISceneDelegateClassName':'$(PRODUCT_MODULE_NAME).WordsCarPlayScene'}]
info.write_bytes(plistlib.dumps(data))
# Modify only Runner configs; the watch never uses CarPlay APIs.
script='''require 'xcodeproj'
p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
p.targets.find{|t|t.name=='Runner'}.build_configurations.each do |c|
 c.build_settings['CODE_SIGN_ENTITLEMENTS']='Runner/Runner.entitlements'
 old=c.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] || '$(inherited)'
 c.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']=[old,'CARPLAY_ENABLED'].flatten.uniq.join(' ')
 c.build_settings['IPHONEOS_DEPLOYMENT_TARGET']='15.0'
end
p.save
'''
subprocess.run(['ruby','-e',script],cwd=root,check=True)
print('CarPlay enabled for the verified Apple-granted Words profile. Rebuild and submit a new signed iOS binary.')
