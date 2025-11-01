import UIKit
import UserNotifications
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
#if canImport(FirebaseCore)
        FirebaseApp.configure()
#endif
        configureNotifications(for: application)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: LanguageManager.languageDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        logProxyMode()
        if let remoteLaunchInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            print("📬 App launched from notification: \(remoteLaunchInfo)")
            if shouldDisplayNotification(userInfo: remoteLaunchInfo, applicationState: .inactive) {
                handleNotification(userInfo: remoteLaunchInfo, applicationState: .inactive, triggeredByUser: true)
            } else {
                print("⚠️ Launch notification ignored due to language mismatch")
            }
        }
        logFCMTokenDiagnostics()
        updateTopicSubscriptions()
        fetchFCMToken()
        ensureAPNSRegistration()
        return true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

#if canImport(FirebaseMessaging)
    private var currentFCMToken: String?
    private var hasAPNSToken = false
    private let subscribedLanguageKey = "MessagingSubscribedLanguage"
    private let pendingNewsArticleDefaultsKey = "PendingNewsArticleID"
    private let pendingProjectDefaultsKey = "PendingProjectID"
    private var apnsTokenType: MessagingAPNSTokenType {
#if DEBUG
        return .sandbox
#else
        return .prod
#endif
    }
#endif
    private func fetchFCMToken() {
#if canImport(FirebaseMessaging)
        guard hasAPNSToken else {
            print("⚠️ Skipping FCM token fetch until APNS token is available")
            return
        }
        Messaging.messaging().token { [weak self] token, error in
            guard let self else { return }
            if let error {
                print("⚠️ Failed to fetch FCM token: \(error)")
                return
            }
            if let token {
                print("✅ FCM token refreshed: \(token)")
                self.currentFCMToken = token
                self.updateTopicSubscriptions()
            }
        }
#endif
    }

    private func configureNotifications(for application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else if let error {
                print("⚠️ Notification permission error: \(error)")
            }
        }

#if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true
#endif
        ensureAPNSRegistration()
    }

    private func logFCMTokenDiagnostics() {
#if canImport(FirebaseMessaging)
        guard hasAPNSToken else {
            print("⚠️ Skipping FCM diagnostics until APNS token is available")
            return
        }
        print("=== FCM DIAGNOSTICS ===")
        Messaging.messaging().token { token, error in
            if let token {
                print("✅ FCM Token: \(token)")
            } else {
                let message = error?.localizedDescription ?? "unknown"
                print("❌ FCM Token ERROR: \(message)")
            }
        }
#endif
    }

    private func logProxyMode() {
        let key = "FirebaseAppDelegateProxyEnabled"
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? NSNumber {
            let mode = value.boolValue ? "enabled (Firebase swizzling active)" : "disabled (manual handlers)"
            print("ℹ️ \(key) explicitly \(value.boolValue ? "true" : "false"); \(mode)")
        } else {
            print("ℹ️ \(key) not set; default Firebase swizzling active")
        }
    }

    private func ensureAPNSRegistration() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let statusDescription: String
            switch settings.authorizationStatus {
            case .authorized:
                statusDescription = "authorized"
            case .provisional:
                statusDescription = "provisional"
            case .ephemeral:
                statusDescription = "ephemeral"
            case .denied:
                statusDescription = "denied"
            case .notDetermined:
                statusDescription = "not determined"
            @unknown default:
                statusDescription = "unknown (\(settings.authorizationStatus.rawValue))"
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    print("ℹ️ APNS registration requested (status: \(statusDescription))")
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .denied:
                print("⚠️ Notifications denied in system settings; APNS registration skipped")
            case .notDetermined:
                print("ℹ️ Notification authorization not yet determined; waiting for user response")
            @unknown default:
                print("⚠️ Unhandled notification authorization status: \(statusDescription)")
            }
        }
    }

    private func currentLanguageCode() -> String {
        let stored = UserDefaults.standard.string(forKey: LanguageManager.storageKey) ?? "en"
        return LanguageManager.normalizedCode(for: stored)
    }

    private func updateTopicSubscriptions() {
#if canImport(FirebaseMessaging)
        guard hasAPNSToken else {
            print("⚠️ Skipping topic subscription: missing APNS token")
            return
        }
        guard let token = currentFCMToken else {
            print("⚠️ Skipping topic subscription: missing FCM token")
            return
        }

        let normalizedLanguage = currentLanguageCode()
        let messagingCode = LanguageManager.messagingCode(for: normalizedLanguage)
        let newTopics = ["eb5_news_\(messagingCode)", "eb5_projects_\(messagingCode)"]
        let previousMessagingCode = UserDefaults.standard.string(forKey: subscribedLanguageKey)

        if previousMessagingCode == messagingCode {
            print("ℹ️ Topic subscriptions already configured for language: \(messagingCode)")
            return
        }

        if let previousMessagingCode, previousMessagingCode != messagingCode {
            let previousTopics = ["eb5_news_\(previousMessagingCode)", "eb5_projects_\(previousMessagingCode)"]
            for topic in previousTopics {
                Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                    if let error {
                        print("⚠️ Failed to unsubscribe from \(topic): \(error)")
                    } else {
                        print("✅ Unsubscribed from topic \(topic)")
                    }
                }
            }
        }

        // Clean up legacy global topics if they were used previously.
        for legacyTopic in ["eb5_news", "eb5_projects"] {
            Messaging.messaging().unsubscribe(fromTopic: legacyTopic) { error in
                if let error {
                    print("⚠️ Failed to unsubscribe from legacy topic \(legacyTopic): \(error)")
                } else {
                    print("✅ Unsubscribed from legacy topic \(legacyTopic)")
                }
            }
        }

        print("✅ Updating topic subscriptions with FCM token: \(token) for language \(messagingCode)")

        let group = DispatchGroup()
        var subscriptionErrors: [Error] = []

        for topic in newTopics {
            group.enter()
            Messaging.messaging().subscribe(toTopic: topic) { error in
                DispatchQueue.main.async {
                    if let error {
                        subscriptionErrors.append(error)
                        print("⚠️ Failed to subscribe to \(topic): \(error)")
                    } else {
                        print("✅ Subscribed to topic \(topic)")
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            if subscriptionErrors.isEmpty {
                UserDefaults.standard.set(messagingCode, forKey: self.subscribedLanguageKey)
                print("✅ Completed topic subscriptions for language \(messagingCode)")
            } else {
                print("⚠️ Topic subscription completed with \(subscriptionErrors.count) error(s); will retry later")
            }
        }
#endif
    }

    @objc private func handleLanguageChange(_ notification: Notification) {
        updateTopicSubscriptions()
    }

    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        ensureAPNSRegistration()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
#if canImport(FirebaseMessaging)
        Messaging.messaging().appDidReceiveMessage(userInfo)
#endif
        print("📬 Silent notification payload: \(userInfo)")
        let state = application.applicationState
        if shouldDisplayNotification(userInfo: userInfo, applicationState: state) {
            handleNotification(userInfo: userInfo, applicationState: state, triggeredByUser: false)
        } else {
            print("⚠️ Notification dropped due to language mismatch")
        }
        completionHandler(.noData)
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
#if canImport(FirebaseMessaging)
        hasAPNSToken = true
        print("✅ APNS token received: \(deviceToken.map { String(format: "%02x", $0) }.joined())")
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().setAPNSToken(deviceToken, type: apnsTokenType)
        logFCMTokenDiagnostics()
        fetchFCMToken()
        updateTopicSubscriptions()
#endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("📬 Foreground notification payload: \(userInfo)")
        let state = UIApplication.shared.applicationState
        guard shouldDisplayNotification(userInfo: userInfo, applicationState: state) else {
            completionHandler([])
            return
        }
        handleNotification(userInfo: userInfo, applicationState: state, triggeredByUser: false)

        var options: UNNotificationPresentationOptions = [.sound, .badge]
        if #available(iOS 14.0, *) {
            options.insert(.banner)
            options.insert(.list)
        } else {
            options.insert(.alert)
        }
        completionHandler(options)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("📬 Notification response payload: \(userInfo)")
        guard shouldDisplayNotification(userInfo: userInfo, applicationState: UIApplication.shared.applicationState) else {
            completionHandler()
            return
        }
        handleNotification(
            userInfo: userInfo,
            applicationState: UIApplication.shared.applicationState,
            triggeredByUser: true
        )

        completionHandler()
    }

    private func shouldDisplayNotification(userInfo: [AnyHashable: Any], applicationState: UIApplication.State) -> Bool {
        switch applicationState {
        case .background, .inactive:
            return true
        case .active:
            break
        @unknown default:
            break
        }

        guard let targetLang = userInfo["lang"] as? String else {
            return true
        }
        let normalizedTarget = LanguageManager.normalizedCode(for: targetLang)
        return normalizedTarget.caseInsensitiveCompare(currentLanguageCode()) == .orderedSame
    }

    private func handleNotification(
        userInfo: [AnyHashable: Any],
        applicationState: UIApplication.State,
        triggeredByUser: Bool
    ) {
        guard let rawType = userInfo["type"] as? String else {
            print("⚠️ Notification missing type field: \(userInfo)")
            return
        }

        let normalizedType = rawType.lowercased()
        let shouldTriggerNavigation = triggeredByUser || applicationState == .inactive

        switch normalizedType {
        case "news":
            guard let articleID = newsArticleIdentifier(from: userInfo) else {
                print("⚠️ News notification missing article_id: \(userInfo)")
                return
            }
            guard shouldTriggerNavigation else {
                print("ℹ️ News notification ignored without user interaction")
                return
            }
            if applicationState != .active {
                UserDefaults.standard.set(articleID, forKey: pendingNewsArticleDefaultsKey)
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .newsNotificationReceived,
                    object: nil,
                    userInfo: [
                        "article_id": articleID,
                        "state": applicationState.rawValue,
                        "triggered_by_user": triggeredByUser
                    ]
                )
            }
        case "project", "projects":
            guard let projectID = projectIdentifier(from: userInfo) else {
                print("⚠️ Project notification missing project identifier: \(userInfo)")
                return
            }
            guard shouldTriggerNavigation else {
                print("ℹ️ Project notification ignored without user interaction")
                return
            }
            if applicationState != .active {
                UserDefaults.standard.set(projectID, forKey: pendingProjectDefaultsKey)
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .projectNotificationReceived,
                    object: nil,
                    userInfo: [
                        "project_id": projectID,
                        "state": applicationState.rawValue,
                        "triggered_by_user": triggeredByUser
                    ]
                )
            }
        default:
            print("ℹ️ Ignoring notification of unsupported type: \(normalizedType)")
        }
    }

    private func projectIdentifier(from userInfo: [AnyHashable: Any]) -> String? {
        let keys = ["project_id", "projectId", "projectID", "id"]
        for key in keys {
            if let value = userInfo[key] {
                if let stringValue = value as? String, !stringValue.isEmpty {
                    return stringValue
                }
                if let numberValue = value as? NSNumber {
                    return numberValue.stringValue
                }
            }
        }
        return nil
    }

    private func newsArticleIdentifier(from userInfo: [AnyHashable: Any]) -> String? {
        let keys = ["article_id", "articleId", "articleID", "id", "news_id", "newsId", "newsID"]
        for key in keys {
            if let value = userInfo[key] {
                if let stringValue = value as? String, !stringValue.isEmpty {
                    return stringValue
                }
                if let numberValue = value as? NSNumber {
                    return numberValue.stringValue
                }
            }
        }
        return nil
    }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let fcmToken {
            print("✅ Firebase messaging delegate token: \(fcmToken)")
            currentFCMToken = fcmToken
            if hasAPNSToken {
                updateTopicSubscriptions()
            } else {
                print("ℹ️ Deferring topic subscription until APNS token is available")
            }
        } else {
            print("⚠️ Firebase messaging delegate provided nil token")
        }
    }
}
#endif

extension Notification.Name {
    static let newsNotificationReceived = Notification.Name("NewsNotificationReceived")
    static let projectNotificationReceived = Notification.Name("ProjectNotificationReceived")
}
