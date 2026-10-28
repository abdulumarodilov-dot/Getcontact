Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 3976 bytes (99.8% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Checking the license for package CMake 3.22.1 in /usr/local/lib/android/sdk/licenses
License for package CMake 3.22.1 accepted.
Preparing "Install CMake 3.22.1 v.3.22.1".
"Install CMake 3.22.1 v.3.22.1" ready.
Installing CMake 3.22.1 in /usr/local/lib/android/sdk/cmake/3.22.1
"Install CMake 3.22.1 v.3.22.1" complete.
"Install CMake 3.22.1 v.3.22.1" finished.
Caught exception: Already watching path: /home/runner/work/Getcontact/Getcontact/android
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:44:33 Unresolved reference 'MasterKey'.
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:48:8 Unresolved reference 'net'.
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:49:8 Unresolved reference 'net'.
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:167:22 Unresolved reference 'MasterKey'.
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:168:27 Unresolved reference 'MasterKey'.
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:171:13 Argument type mismatch: actual type is 'Context', but 'String' was expected.
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:289:17 Unresolved reference 'SQLiteDatabase'.
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:293:18 Unresolved reference 'SQLiteDatabase'.
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:301:17 Unresolved reference 'DatabaseErrorHandler'.
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:306:37 Unresolved reference 'rawQuery'.
e: file:///home/runner/work/Getcontact/Getcontact/android/app/src/main/kotlin/com/example/getcontact/MainActivity.kt:323:21 Unresolved reference 'close'.

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileReleaseKotlin'.
> A failure occurred while executing org.jetbrains.kotlin.compilerRunner.btapi.BuildToolsApiCompilationWork
   > Compilation error. See log for more details

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights from a Build Scan (powered by Develocity).
> Get more help at https://help.gradle.org.

BUILD FAILED in 4m 31s
Running Gradle task 'assembleRelease'...                          272.1s
Gradle task assembleRelease failed with exit code 1
Error: Process completed with exit code 1.
