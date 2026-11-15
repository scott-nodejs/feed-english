# SocialFeedApp

**SocialFeedApp** is a lightweight iOS application. It showcases a vertically scrollable video feed similar to TikTok or Instagram Reels, where each video is full-screen and autoplayed when visible.

---

## ✅ Requirements

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

## 本地后端接入

应用沿用原有首页和布局，只将原数据层替换为 oneCode 接口。默认接口地址为 `https://yima.hazer.top`（不带 `/oneCode`）；本地调试可改为 `http://127.0.0.1:9080/oneCode`，原有点赞／挑战操作需要登录时弹出手机号密码表单，登录表单仅用于登录，不展示服务器配置；没有新增首页导航或账号入口。

完整的数据库迁移、启动方式、媒体发布、接口和验收说明见相邻仓库的 `../oneCode/SOCIAL_APP_LOCAL.md`。Debug 和 Release 默认均访问真实后端 `https://yima.hazer.top`；仅在需要离线预览时显式设置 `ONECODE_USE_LOCAL_PREVIEW=YES`。真实接口失败时不会回退到演示数据。模拟器可直连电脑回环地址，真机需使用电脑局域网地址；开发 HTTP 仅允许本地网络，线上使用 HTTPS。

## 微信小程序登录与互动

登录页支持微信小程序确认登录，并保留手机号登录。微信授权确认后会继续之前的练习、关注、点赞或评论操作；主页布局保持不变。关注、取消关注、点赞、不喜欢、评论分页／发表／本人删除均接服务端；点击视频区域可暂停或继续，手动暂停状态会保留。

微信登录需要部署新后端、执行新 SQL，并将相邻仓库 `../oneCode/wechat-miniapp-integration/` 的确认页接入和发布到实际小程序。完整步骤见 `../oneCode/WECHAT_APP_LOGIN.md`，模拟器无法代替微信真机授权验证。
