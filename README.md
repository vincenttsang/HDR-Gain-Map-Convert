### iGainMapHDR (iPadOS/iOS)

- 一款以 Swift + SwiftUI 開發的 iPadOS/iOS 圖形介面工具（從macOS版移植），用於把不同格式的高動態範圍（HDR）圖像轉換成可用的 HDR/SDR 圖像或含 gain map 的 HEIF，用於 Apple/Android 平台或照片服務（例如 Google Photos）。

## 本專案原始實作參考自: https://github.com/chemharuka/PQ_HDR_to_Gain_Map_HDR

## 主要功能

- 將 HDR 圖像（例如 PQ/HLG/其他擴展色域 HDR 圖像）轉換為：
	- PQ（Rec.2100 PQ）或 HLG（Rec.2100 HLG）格式的 HDR 圖片
	- SDR（經過 tone mapping）的圖片（例如用於一般顯示器或網路）
	- Mono gain map（單色增益地圖）適配 Google Photos / Android 的 HEIF
- 支援輸出為多種檔案格式：HEIF, JPEG, PNG, TIFF
- 支援不同色彩空間選項：sRGB / Display P3 / Rec.2020
- 支援 8 / 10 / 16-bit（依輸出格式與色彩空間而定）
- 批次轉換支援與線程（併發）控制，並在完成時發送 macOS 通知

## 文件結構

- `iGainMapHDR/ContentView.swift` — SwiftUI 使用者介面，提供單檔或批次轉換、輸出選項、進度顯示等。
- `iGainMapHDR/Library/Converter.swift` — 轉檔核心邏輯，基於 Core Image 處理 HDR 圖像、計算 gain map、控制輸出格式與 metadata（Apple MakerNote）等。
- `iGainMapHDR/Library/GainMapFilter/` — (包含自定義 Core Image kernel 的濾鏡，會影響 gain map 的計算，請參閱資料夾內檔案)
- 本專案包含多語系字串檔（例如 `Base.lproj`、`zh-Hans.lproj` 等）

## 使用說明（開發者/測試）

1) 以 Xcode 打開專案：
	 - 開啟 `iGainMapHDR.xcodeproj`，選擇適當的 Scheme 並執行。
2) 在程式介面中：
	 - 選擇單一檔案或多檔案模式。
	 - 選擇來源 HDR 圖像與輸出資料夾。
	 - 設定輸出類型（HEIF/JPEG/PNG/TIFF）、色域、位元深度與輸出目標（PQ/HLG/SDR/Google Photos Mono Gain Map）。
	 - 按下轉換；批次模式下可控制併發執行緒數量與畫質（JPEG 壓縮品質）。

## 命令列 / 程式邏輯重點

- Converter 使用 Core Image（CIImage & CIContext）讀取 HDR 檔案（使用 `.expandToHDR`），並用 `CIToneMapHeadroom` 等濾鏡生成 SDR tone-mapped 版本。
- 針對 MonoGainMap（Google Photos 兼容模式），會：
	- 計算影像最大值（HDR max），估算 headroom（經驗公式），產生增益地圖（gain map），並把 gain map 以 `CIImageRepresentationOption.hdrGainMapImage` 附加到輸出的影像 metadata。這會讓輸出 HEIF 能夠被支援單色 gain map 的裝置識別。
- 輸出時會根據使用者設定選擇適合的色彩空間（Rec.709 / Display P3 / Rec.2020）與像素格式（RGBA8 / RGB10 / RGBX16），並使用 CIContext 的 HEIF/JPEG/PNG/TIFF 寫出 API。

## 已知限制與注意事項

- 某些輸出選項在語義上互斥（例如不能同時選擇 SDR 與 PQ/HLG）；UI 上會禁止互相衝突的選項，Converter 也會回報錯誤。
- 對於 JPEG 輸出，實作上僅支援 8-bit；若選擇 10/16-bit 色深時，輸出格式應為 HEIF/PNG/TIFF。
- 部分自定義 Core Image kernel（若存在於 `GainMapFilter`）可能需要在 build 時正確包含與連結，否則會回退到內建濾鏡的替代實作（專案內已有備註）。
- 在大批次大量檔案處理時，建議適度調整併發數以避免記憶體或 I/O 瓶頸。
- iOS/iPadOS 平台：為避免耗盡行動裝置的 SoC 資源（CPU/GPU/記憶體），在 UI 與執行邏輯中已對併發數做保守限制。預設與可選的執行緒數在 iOS 上會比 macOS 小，且實際 semaphore 同時啟動的工作數會根據裝置核心數上限為 4。若需要更改，可在 `ContentView.swift` 中調整相關設定。

## 範例工作流程

- 打開一張 PQ HDR HEIC → 選擇輸出為 Mono Gain Map 的 HEIF（或選 PQ/HLG/SDR）→ 設定位元深度（例如 10-bit）→ 按 Convert → 完成後在選定資料夾看到輸出檔案。

## 開發與貢獻

歡迎提出 Issues 或 Pull Requests。主要程式碼以 Swift 撰寫，建議在 macOS（最新 Xcode）上開發與測試。
