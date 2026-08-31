#!/bin/zsh

print -r -- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<plist version=\"1.0\"><dict>
<key>Entitlements</key><dict>
<key>application-identifier</key><string>TEAM.${OMF_FAKE_IOS_PROFILE_BUNDLE:-dev.ventairy.oh-my-flutter.device-display-collector}</string>
</dict>
<key>ProvisionedDevices</key><array><string>FIXTURE-UDID</string></array>
</dict></plist>"
