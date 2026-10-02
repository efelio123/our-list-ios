Register two Apple apps in the same Firebase project, one for the iPhone app and one for its widget extension. Place each downloaded GoogleService-Info.plist in its matching directory:

- App/GoogleService-Info.plist
- Widget/GoogleService-Info.plist

The files are copied into their respective targets by XcodeGen.
