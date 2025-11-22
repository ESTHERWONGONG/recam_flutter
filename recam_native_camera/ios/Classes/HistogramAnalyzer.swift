import UIKit
import CoreGraphics

struct HistogramStats {
    let avgLuma: Double       // 平均亮度 0~1
    let darkFraction: Double  // 偏暗像素比例
    let brightFraction: Double // 偏亮像素比例
}

enum HistogramAnalyzer {
    static func analyze(image: UIImage) -> HistogramStats {
        guard let cgImage = image.cgImage else {
            return HistogramStats(avgLuma: 0.5, darkFraction: 0.0, brightFraction: 0.0)
        }

        let width = cgImage.width
        let height = cgImage.height

        // 降采样，避免太重
        let sampleStep = max(1, min(width, height) / 80)

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return HistogramStats(avgLuma: 0.5, darkFraction: 0.0, brightFraction: 0.0)
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        var totalLuma: Double = 0
        var count: Double = 0
        var darkCount: Double = 0
        var brightCount: Double = 0

        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                if offset + 2 >= CFDataGetLength(data) { continue }

                // 假设是 RGBA/BGRA，这里用常见的 BGRA 读取
                let b = Double(ptr[offset + 0])
                let g = Double(ptr[offset + 1])
                let r = Double(ptr[offset + 2])

                let rNorm = r / 255.0
                let gNorm = g / 255.0
                let bNorm = b / 255.0

                // Rec.709 luma
                let luma = 0.2126 * rNorm + 0.7152 * gNorm + 0.0722 * bNorm

                totalLuma += luma
                count += 1

                if luma < 0.3 {
                    darkCount += 1
                } else if luma > 0.7 {
                    brightCount += 1
                }
            }
        }

        if count == 0 {
            return HistogramStats(avgLuma: 0.5, darkFraction: 0.0, brightFraction: 0.0)
        }

        let avg = totalLuma / count
        return HistogramStats(
            avgLuma: avg,
            darkFraction: darkCount / count,
            brightFraction: brightCount / count
        )
    }
}
