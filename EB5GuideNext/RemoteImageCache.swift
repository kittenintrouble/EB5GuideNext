import Foundation
import UIKit
import CryptoKit

final class RemoteImageCache {
    static let shared = RemoteImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    private let ioQueue = DispatchQueue(label: "RemoteImageCache.io", qos: .utility)
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 60 * 1024 * 1024 // ~60MB in-memory

        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        cacheDirectory = baseDirectory.appendingPathComponent("RemoteImages", isDirectory: true)
        createDirectoryIfNeeded()
    }

    func image(for url: URL) -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        let diskURL = cacheFileURL(for: url)
        guard fileManager.fileExists(atPath: diskURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: diskURL)
            if let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 {
                cache.setObject(image, forKey: url as NSURL, cost: imageCost(image))
                return image
            } else {
                try? fileManager.removeItem(at: diskURL)
            }
        } catch {
#if DEBUG
            print("⚠️ RemoteImageCache disk read failed:", error.localizedDescription)
#endif
        }

        return nil
    }

    func store(_ image: UIImage, for url: URL) {
        guard image.size.width > 0, image.size.height > 0 else { return }

        cache.setObject(image, forKey: url as NSURL, cost: imageCost(image))

        let diskURL = cacheFileURL(for: url)
        ioQueue.async { [weak self] in
            guard let self else { return }
            if self.fileManager.fileExists(atPath: diskURL.path) { return }

            do {
                let data = imageData(for: image)
                guard !data.isEmpty else { return }
                try data.write(to: diskURL, options: [.atomic])
            } catch {
#if DEBUG
                print("⚠️ RemoteImageCache disk write failed:", error.localizedDescription)
#endif
            }
        }
    }

    func remove(_ url: URL) {
        cache.removeObject(forKey: url as NSURL)
        let diskURL = cacheFileURL(for: url)
        ioQueue.async { [weak self] in
            guard let self else { return }
            try? self.fileManager.removeItem(at: diskURL)
        }
    }
}

private extension RemoteImageCache {
    func createDirectoryIfNeeded() {
        if fileManager.fileExists(atPath: cacheDirectory.path) { return }
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
#if DEBUG
            print("⚠️ RemoteImageCache directory creation failed:", error.localizedDescription)
#endif
        }
    }

    func cacheFileURL(for url: URL) -> URL {
        let hashed = sha256(url.absoluteString)
        return cacheDirectory.appendingPathComponent(hashed).appendingPathExtension("img")
    }

    func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func imageCost(_ image: UIImage) -> Int {
        Int(image.size.width * image.size.height * image.scale * image.scale)
    }
}

private func imageData(for image: UIImage) -> Data {
    if let png = image.pngData() {
        return png
    }
    return image.jpegData(compressionQuality: 0.9) ?? Data()
}
