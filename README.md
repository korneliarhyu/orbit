# orbit
AI Social Universe - ChatApp

# How to run the apps:
flutter pub get
dart pub global activate flutterfire_cli

cd functions
npm install
npm run build
cd ..

$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr" 
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
firebase emulators:start --only auth,firestore,functions --project orbit-9cd6b --import=./emulator-data --export-on-exit=./emulator-data

flutter run -d emulator-5554

save the data manually: firebase emulators:export ./emulator-data
