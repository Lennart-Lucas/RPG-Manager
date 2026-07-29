import Cocoa
import FlutterMacOS
import Vision

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    Self.registerVisionOcrChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private static func registerVisionOcrChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "rpg_manager/vision_ocr",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "recognizeText":
        Self.handleRecognizeText(call: call, result: result)
      case "isAvailable":
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func handleRecognizeText(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let width = args["width"] as? Int,
      let height = args["height"] as? Int,
      width > 0,
      height > 0
    else {
      result(
        FlutterError(
          code: "bad_args",
          message: "width, height, and pixels are required",
          details: nil
        )
      )
      return
    }

    let pixelData: Data?
    if let typed = args["pixels"] as? FlutterStandardTypedData {
      pixelData = typed.data
    } else if let raw = args["pixels"] as? Data {
      pixelData = raw
    } else {
      pixelData = nil
    }

    guard let pixels = pixelData, pixels.count >= width * height * 4 else {
      result(
        FlutterError(
          code: "bad_pixels",
          message: "pixels must be BGRA8888 with width*height*4 bytes",
          details: nil
        )
      )
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let text = try Self.recognizeText(bgra: pixels, width: width, height: height)
        DispatchQueue.main.async {
          result(text)
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "ocr_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private static func recognizeText(bgra: Data, width: Int, height: Int) throws -> String {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo =
      CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard
      let provider = CGDataProvider(data: bgra as CFData),
      let cgImage = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    else {
      throw NSError(
        domain: "rpg_manager.vision_ocr",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not create CGImage from page pixels"]
      )
    }

    var recognized = ""
    var requestError: Error?
    let request = VNRecognizeTextRequest { request, error in
      if let error {
        requestError = error
        return
      }
      guard let observations = request.results as? [VNRecognizedTextObservation] else {
        return
      }
      recognized = observations.compactMap { observation in
        observation.topCandidates(1).first?.string
      }.joined(separator: "\n")
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])
    if let requestError {
      throw requestError
    }
    return recognized
  }
}
