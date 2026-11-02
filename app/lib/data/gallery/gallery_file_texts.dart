import 'dart:convert';
import 'dart:typed_data';

const String galleryReadmeText = r'''
# acme-app

The acme mobile app for iOS and Android, built with React Native.

## Get started

1. Install Node 20 and Xcode 16.
2. Install the packages, then start the iOS app:

```sh
npm install
npm run ios
```

## Project layout

- `src/auth`: sign-in, sessions and redirects
- `src/screens`: one file per screen
- `assets`: icons, fonts and the onboarding video

## Releases

The `release` workflow builds on mac-studio and asks for approval before it
pushes.
''';

const String galleryRedirectText = r'''
import { Router } from "../router";
import { readSession } from "./session";

const LOGIN_PATH = "/login";
const HOME_PATH = "/";

export function readReturnPath(search: string): string {
  const params = new URLSearchParams(search);
  const returnPath = params.get("next");

  if (returnPath === null) {
    return HOME_PATH;
  }

  const isSameSite =
    returnPath.startsWith("/") && !returnPath.startsWith("//");

  if (!isSameSite) {
    return HOME_PATH;
  }

  return returnPath;
}

export async function redirectAfterLogin(
  router: Router,
  search: string,
) {
  const session = await readSession();

  if (session === null) {
    router.replace(LOGIN_PATH);
    return;
  }

  router.replace(readReturnPath(search));
}
''';

const String galleryLoginText = r'''
import { redirectAfterLogin } from "./redirect";

export async function signIn(router, search: string) {
  await redirectAfterLogin(router, search);
}
''';

const String gallerySessionText = r'''
export async function readSession(): Promise<string | null> {
  return localStorage.getItem("session");
}
''';

const String galleryAppText = r'''
import { HomeScreen } from "./screens/Home";

export function App() {
  return <HomeScreen />;
}
''';

const String galleryIndexText = r'''
import { App } from "./App";

export default App;
''';

const String galleryIgnoreText = '''
node_modules/
ios/Pods/
android/build/
''';

const String galleryPackageText = '''
{
  "name": "acme-app",
  "private": true,
  "scripts": {
    "ios": "react-native run-ios"
  }
}
''';

const String galleryTypeScriptSettingsText = '''
{
  "compilerOptions": {
    "strict": true
  }
}
''';

const String galleryWorkflowText = '''
name: release
on: workflow_dispatch
''';

const String galleryGradleText = '''
apply plugin: "com.android.application"
''';

const String galleryPodText = '''
platform :ios, "16.0"
''';

const String galleryButtonText = r'''
export function Button() {
  return null;
}
''';

const String galleryHomeText = r'''
export function HomeScreen() {
  return null;
}
''';

const String _galleryIconBase64 =
    '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';

final Uint8List galleryIconBytes = base64Decode(_galleryIconBase64);
