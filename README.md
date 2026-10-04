# Our List for iPhone

Native SwiftUI app and interactive WidgetKit widget backed by Firebase Authentication (anonymous accounts) and Cloud Firestore. The existing ChatGPT Site is not used by this app.

## What works

- Connect both iPhones to one precreated list automatically using a private code bundled during the build.
- Add, check off, and delete tasks in the app. The open app receives Firestore updates from the other phone automatically.
- Check off visible tasks directly in the medium or large Home Screen widget. Tapping a checkbox writes to Firestore and WidgetKit reloads that widget.
- The widget fetches remote changes when iOS requests a new timeline. Its 15-minute refresh policy is a request to iOS, not a guarantee. There is no push notification capability in this free-signing version.
- The app checks whether its widget has been added and updates the setup hint when you return from the Home Screen.
- Scrolling the task list or tapping outside the task field dismisses the keyboard.

The list code grants access to the list. Anyone who extracts it from a signed app build or otherwise learns it and can authenticate anonymously to your Firebase project could read or change that list. Distribute the build only to your two phones. The code is intentionally random and impractical to guess. Firestore rules prevent phones from creating more lists. If the code leaks, create a new list and delete the old one in the Firebase console. Firebase anonymous sign-in creates a separate account for each app installation and widget extension. Those accounts may change when the weekly installed app expires or is reinstalled; access remains tied to the list code, so the list survives reinstalling.

## Firebase setup (Spark/free plan)

The Firestore database, private list document, and both Apple app registrations have been created. Anonymous sign-in is enabled, and the rules in `firebase/firestore.rules` are published. The Firebase configuration files and private list code are intentionally excluded from this public repository; the project owner keeps them in a separate private transfer package.

1. The project uses the **Spark** plan. Google Analytics is not needed.
2. In **Build > Authentication > Sign-in method**, **Anonymous** is enabled.
3. The contents of [`firebase/firestore.rules`](firebase/firestore.rules) are published in Firestore's **Rules** tab. The database is in production mode in the `nam5` US multi-region. Client access requires anonymous sign-in and the private list code.
4. Firebase Apple apps are registered as `com.efelio123.ourlist` and `com.efelio123.ourlist.widget`. These bundle IDs are set in `project.yml`. If Xcode reports a bundle ID conflict, change the IDs in XcodeGen and register matching Apple apps in Firebase.
5. Restore `Config/App/GoogleService-Info.plist`, `Config/Widget/GoogleService-Info.plist`, and `Config/list-code.txt` from the private transfer package before generating the Xcode project. XcodeGen copies the code into both targets and each Firebase plist into its corresponding target. All three files are ignored by Git.
6. One `lists` collection document with a random 32-character lowercase hexadecimal ID and `name: "Our List"` is already created. Its code is in `Config/list-code.txt`. Keep it private; the app and widget read it automatically.

Only Firebase Authentication and Firestore are used. The iPhone app contains no separate web UI or ChatGPT Site dependency. Do not enable Blaze billing unless you decide you need a paid Firebase feature later.

## Generate and install from a Mac

1. Install current Xcode from Apple, sign into your Apple Account under **Xcode > Settings > Accounts**, and connect your iPhone by cable (or enable wireless debugging after the first pairing).
2. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) with `brew install xcodegen`.
3. Clone this repository on the Mac, restore the two Firebase plist files and `Config/list-code.txt` from the private transfer package, then run `xcodegen generate` inside this folder. Regenerate the project after pulling changes to `project.yml`.
4. Open `OurList.xcodeproj`. Select the **OurList** app target and the **OurListWidget** extension target. Under **Signing & Capabilities**, choose your free **Personal Team** for both and make sure their bundle identifiers match step 4 above.
5. Select your iPhone as the run destination and press **Run**. Repeat with your wife's iPhone using the same Xcode project, Firebase project, and Apple Account/team that can sign the app. If iOS asks, enable Developer Mode and trust your developer certificate.
6. The app connects to the precreated list on launch. To add the widget, long press the Home Screen and add **Our List**. It uses the same list automatically.

With a free Personal Team, development signing expires after seven days. When it expires, reconnect each phone to the Mac and use **Run** in Xcode again. The list stays in Firestore even if you reinstall the app.

## Limits and later improvements

- This version needs iOS 17 or later.
- WidgetKit chooses when to refresh remote changes. A checkbox tap does trigger a reload of that widget, but changes from the other phone can take longer to appear on a Home Screen widget than in the open app.
- The free Apple team cannot use APNs-based WidgetKit push updates. If you later buy an Apple Developer Program membership, push can be added separately; Firebase Cloud Messaging alone does not bypass WidgetKit's rules.
- This project uses no App Group entitlement so it can target free signing. The private code is bundled separately into the app and widget at build time.
- No existing items are migrated from the current ChatGPT Site. This is a fresh Firebase list.

## Files

- `App/` — iPhone interface.
- `Widget/` — interactive WidgetKit extension.
- `Shared/` — shared Firebase access and list model.
- `firebase/firestore.rules` — Firestore access and schema rules.
- `project.yml` — XcodeGen project specification.
