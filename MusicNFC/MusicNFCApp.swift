import SwiftUI

@main
struct MusicNFCApp: App {
    // AppDelegateをSwiftUIに連携させる
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// UIApplicationDelegateを実装したクラス
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // ブラウザ経由のユーザーアクティビティか確認
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL,
              let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
            return false
        }

        // URLの内容をデバッグ出力（ここでURLの解析や画面遷移の処理を実装）
        print("Received universal link: \(incomingURL.absoluteString)")

        // 例: components.hostやcomponents.pathを利用して特定の処理を行う

        return true
    }
}
