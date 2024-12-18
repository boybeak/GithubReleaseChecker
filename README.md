# GithubReleaseChecker
Check new version from Github release
 
## Installation

Open your project in XCode, **File** -> **Add Package Dependencies**, copy and paste `https://github.com/boybeak/GithubReleaseChecker.git` into the search input, then search library info and **Add Package**.

## Usage
 
```swift
import GithubReleaseChecker
 
let checker = GithubReleaseChecker()

// You can set your own version comparator
checker.versionComparator = { currentVersion, latestRelease in
    return true
}

// If use default UI
checker.width = 400
checker.height = 600

checker.checkUpdate(for: .userRepo("boybeak/JustTodo"), showDefaultUI: true) { result in
    switch result {
    case .success(let (newVersion, hasUpdate)):
        if hasUpdate, let releaseInfo = newVersion {
        } else {
        }
    case .failure(let error):
    }
}
```
