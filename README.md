# SocialFeedApp

**SocialFeedApp** is a lightweight iOS application built as part of a coding assessment. It showcases a vertically scrollable video feed similar to TikTok or Instagram Reels, where each video is full-screen and autoplayed when visible.

---

## ✅ Assessment Requirements

The app implements the following functionality as outlined in the task:

1. **Feed UI**  
   - Displays a scrollable vertical list of short videos.
   - Videos are loaded from a **mock API** (`videos.json` file).
   - Supports **pagination**: videos are fetched in **batches of 20**.

2. **Each video item includes:**
   - 👤 **Creator avatar and name** (top-left).
   - 🎞️ **Autoplaying video** (centered and full-screen).
   - 💬 **Action buttons** (like, dislike, comment) using **SF Symbols**.
   - 📝 **Video description** displayed at the bottom.

---

## 🚀 Key Features

- **SwiftUI + MVVM + Clean Architecture**  
  Modular and testable project structure following best practices.

- **Swift Concurrency (async/await)**  
  Ensures smooth UI updates and scalable data loading.

- **Clear Namespace Structure**  
  Organized into API, Domain, and UI layers.

- **Local Mock API**  
  Loads video feed from a `videos.json` file bundled within the app.

- **Unit Testing**  
  ViewModel and UseCase layers are covered with unit tests using XCTest.

---

## 📱 Requirements

- **Swift** 5.9 or later  
- **Xcode** 16.0 or later  
- **iOS** 17.0 or later  

---

## 📦 Installation

1. **Clone the repository:**
    ```bash
    git clone git@github.com:usman-pucit/SocialFeedApp.git 
    cd SocialFeedApp
    ```
    Or download the ZIP file and extract it manually.

2. **Open the project in Xcode:**
    ```bash
    open SocialFeedApp.xcodeproj
    ```
    *(Use `SocialFeedApp.xcworkspace` instead if you add CocoaPods or SwiftPM later.)*

3. **Build and run the project** using a simulator or real device.

4. **Make sure your device or simulator is connected to the internet** if you later switch from local to remote video URLs.

---

## 🧪 Testing

Run unit tests by selecting the `SocialFeedAppTests` scheme and pressing `Cmd + U` in Xcode.
