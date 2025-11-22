import Foundation

struct AiPreset {
    let id: String
    let name: String
}

struct AiRecommendResult {
    let preset: AiPreset
    let debugText: String
}

struct AiRecommender {

    private let cineNight = AiPreset(id: "cine_night", name: "CineNight")
    private let filmFade = AiPreset(id: "film_fade", name: "FilmFade")
    private let kodakGold = AiPreset(id: "kodak_gold", name: "KodakGold")

    func recommend(from stats: HistogramStats) -> AiRecommendResult {
        let l = stats.avgLuma
        let dark = stats.darkFraction
        let bright = stats.brightFraction

        // 非常暗：夜景
        if l < 0.35 || dark > 0.5 {
            let text = "画面整体偏暗，适合高宽容度的夜景胶片。"
            return AiRecommendResult(preset: cineNight, debugText: text)
        }

        // 非常亮：高光、逆光、沙滩之类
        if l > 0.7 || bright > 0.5 {
            let text = "画面整体偏亮，推荐用淡对比、偏柔和的胶片。"
            return AiRecommendResult(preset: filmFade, debugText: text)
        }

        // 中间：日常记录
        let text = "亮度适中，适合日常记录的暖色胶片。"
        return AiRecommendResult(preset: kodakGold, debugText: text)
    }
}
