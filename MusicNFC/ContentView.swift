import Foundation
import CoreNFC
import SwiftUI
import AppIntents

final class NFCSession: NSObject, ObservableObject {

    private var session: NFCNDEFReaderSession!
    private var isWriting = false
    private var ndefMessage: NFCNDEFMessage!
    var writeHandler: ((Error?) -> Void)?
    var readHandler: ((String?, Error?) -> Void)?
    static let shared = NFCSession()


    // 書き込みのセッションをスタートする
    func startWriteSession(text: String, writeHandler: ((Error?) -> Void)?) {
        // ハンドラの設定
        self.writeHandler = writeHandler
        isWriting = true
        // 書き込みデータの設定
        let textPayload = NFCNDEFPayload(
            format: NFCTypeNameFormat.nfcWellKnown,
            type: "T".data(using: .utf8)!, // いろんなタイプがあるのかな
            identifier: Data(),
            payload: text.data(using: .utf8)!)
        // Payloadの設定
        let uriPayload = NFCNDEFPayload.wellKnownTypeURIPayload(url: .init(string: "https://music.line.me/app-bridge?target=track&item=mb00000000038a43e8&subitem=mt000000001ea53b13&cc=JP")!)
        ndefMessage = NFCNDEFMessage(records: [textPayload, uriPayload!])
        startSession()
    }

    // 読み込みのセッション開始
    func startReadSession(readHandler: ((String?, Error?) -> Void)?) {
        self.readHandler = readHandler
        print(readHandler)
        isWriting = false
        startSession()
    }

    // セッション、スキャンの開始
    private func startSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            return
        }
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = "スキャン中"
        session.begin()
    }
}

extension NFCSession: NFCNDEFReaderSessionDelegate {

    // 必須
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
    }

    // 必須
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
    }

    // 必須ではないけどコンソールになんかでる
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }

    // delegateメソッド 感知したら発火する
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        // 発見したタグの一番初めを取得
        let tag = tags.first!
        // コネクションはじめ
        session.connect(to: tag) { error in
            // 情報を取得
            tag.queryNDEFStatus() { [unowned self] status, capacity, error in
                if self.isWriting {
                    // 書き込み
                    if status == .readWrite {
                        self.write(tag: tag, session: session)
                        return
                    }
                } else {
                    // 読み込み
                    if status == .readOnly || status == .readWrite {
                        self.read(tag: tag, session: session)
                        return
                    }
                }
                session.invalidate(errorMessage: "タグがおかしいよ(´∇｀)")
            }
        }
    }

    // 書き込みの処理
    private func write(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.writeNDEF(self.ndefMessage) { [unowned self] error in
            session.alertMessage = "書き込み完了♬(ノ゜∇゜)ノ♩"
            session.invalidate()
            DispatchQueue.main.async {
                self.writeHandler?(error)
            }
        }
    }


    // 読み込みの処理
    private func read(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { [unowned self] message, error in
            session.alertMessage = "読み込み完了♬(ノ゜∇゜)ノ♩"
            session.invalidate()
            let text = message?.records.compactMap {
                switch $0.typeNameFormat {
                case .nfcWellKnown:
                    if let url = $0.wellKnownTypeURIPayload() {
                        return url.absoluteString
                    }
                    if let text = String(data: $0.payload, encoding: .utf8) {
                        return text
                    }
                    return nil
                default:
                    return nil
                }
            }.joined(separator: "\n\n")
            DispatchQueue.main.async {
                self.readHandler?(text, error)
            }
        }
    }
}

struct ContentView: View {
    @State private var isAlertShown = false
    @State private var alertMessage = ""
    @State private var text = ""
    @StateObject private var session = NFCSession.shared
    var body: some View {
        VStack(spacing: 16) {
            TextField("何か入力", text: $text)

            Button {
                session.startReadSession { text, error in
                    if let error = error {
                        alertMessage = error.localizedDescription
                        print("error")
                    } else {
                        if let text = text {
                            var filterString = text.filter{ $0 != "\n" }

                            if let url = URL(string: filterString), UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url, options: [:]) { success in
                                    if success {
                                        print("URLを開きました。")
                                    } else {
                                        print("URLを開くことができませんでした。")
                                    }
                                }
                            } else {
                                print("無効なURLです。")
                            }
                        }
                    }
                    isAlertShown = true
                }
            } label: {
                Text("Read")
            }

            Button {
                session.startWriteSession(text: text) { error in
                    if let error = error {
                        alertMessage = error.localizedDescription
                        isAlertShown = true
                    }
                }
            } label: {
                Text("Write")
            }
        }
        .padding(16)
    }
}

struct OpenNFCReader: AppIntent {
    static let title: LocalizedStringResource = "音楽NFC"
    static let openAppWhenRun: Bool = true
    let nfcSession = NFCSession.shared
    let readHandler = NFCSession.shared.readHandler
    @MainActor
    func perform() async throws -> some IntentResult {
        nfcSession.startReadSession(readHandler: { text, error in
            if let error = error {
                print("error")
            } else {
                if let text = text {
                    var filterString = text.filter{ $0 != "\n" }

                    if let url = URL(string: filterString), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if success {
                                print("URLを開きました。")
                            } else {
                                print("URLを開くことができませんでした。")
                            }
                        }
                    } else {
                        print("無効なURLです。")
                    }
                }
            }
        })
        return .result()
    }
}

struct OpenNFCReaderShortscuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenNFCReader(),
            phrases: [
                "NFCの読み取りを開始したい",
                "NFCの書き込みを開始したい"
            ]
        )
    }
}
