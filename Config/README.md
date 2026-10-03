Register two Apple apps in the same Firebase project, one for the iPhone app and one for its widget extension. Place each downloaded GoogleService-Info.plist in its matching directory:

- App/GoogleService-Info.plist
- Widget/GoogleService-Info.plist

The files are copied into their respective targets by XcodeGen.

The private `list-code.txt` also belongs in this `Config` directory. XcodeGen bundles it into both the app and widget, so neither phone needs a code entered by hand. Keep all three configuration files out of GitHub.
