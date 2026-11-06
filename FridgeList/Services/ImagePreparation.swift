import UIKit

extension UIImage {
    /// Уменьшает снимок и кодирует в JPEG для отправки в зрительную модель.
    func preparedForVision(maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
