import UIKit

extension UIImage {
    var isRenderable: Bool {
        size.width > 0 && size.height > 0
    }
}
