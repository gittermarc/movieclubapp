//
//  MemberAvatarImageProcessor.swift
//  filmfreaks
//
//  Square crop and metadata-free JPEG rendering for member avatars.
//

internal import UIKit

struct MemberAvatarCrop: Equatable {
    var zoom: CGFloat = 1
    var horizontalPosition: CGFloat = 0
    var verticalPosition: CGFloat = 0

    static let minimumZoom: CGFloat = 1
    static let maximumZoom: CGFloat = 3

    func clamped() -> MemberAvatarCrop {
        MemberAvatarCrop(
            zoom: min(max(zoom, Self.minimumZoom), Self.maximumZoom),
            horizontalPosition: min(max(horizontalPosition, -1), 1),
            verticalPosition: min(max(verticalPosition, -1), 1)
        )
    }
}

enum MemberAvatarImageProcessor {

    static let outputSideLength: CGFloat = 512
    static let jpegCompressionQuality: CGFloat = 0.82

    static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func jpegData(from image: UIImage, crop: MemberAvatarCrop) -> Data? {
        let normalizedImage = normalizedImage(image)
        let outputSize = CGSize(width: outputSideLength, height: outputSideLength)
        let drawingRect = drawingRect(
            for: normalizedImage.size,
            sideLength: outputSideLength,
            crop: crop
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let renderedImage = renderer.image { _ in
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: outputSize))
            normalizedImage.draw(in: drawingRect)
        }

        return renderedImage.jpegData(compressionQuality: jpegCompressionQuality)
    }

    static func drawnSize(
        for sourceSize: CGSize,
        sideLength: CGFloat,
        crop: MemberAvatarCrop
    ) -> CGSize {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return CGSize(width: sideLength, height: sideLength)
        }

        let normalizedCrop = crop.clamped()
        let scale = max(sideLength / sourceSize.width, sideLength / sourceSize.height)
            * normalizedCrop.zoom
        return CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    }

    static func drawingRect(
        for sourceSize: CGSize,
        sideLength: CGFloat,
        crop: MemberAvatarCrop
    ) -> CGRect {
        let normalizedCrop = crop.clamped()
        let size = drawnSize(for: sourceSize, sideLength: sideLength, crop: normalizedCrop)
        let maximumHorizontalOffset = max((size.width - sideLength) / 2, 0)
        let maximumVerticalOffset = max((size.height - sideLength) / 2, 0)

        return CGRect(
            x: (sideLength - size.width) / 2 + normalizedCrop.horizontalPosition * maximumHorizontalOffset,
            y: (sideLength - size.height) / 2 + normalizedCrop.verticalPosition * maximumVerticalOffset,
            width: size.width,
            height: size.height
        )
    }
}
