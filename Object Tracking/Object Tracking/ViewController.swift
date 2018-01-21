//
//  ViewController.swift
//  Object Tracking
//
//  Created by Pairmi, Vikram (US - Bengaluru) on 1/20/18.
//  Copyright © 2018 vikram. All rights reserved.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private var requests = [VNRequest]()
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let queue = DispatchQueue(label: "com.vikram.videoqueue")
    
    @IBOutlet weak var captureView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //Vision rectangle detection request setup
        self.setupVision()
        
        //AVVideo Capture setup and starting the capture
        self.setupAvCaptureSession()
        self.startVideoCapture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = self.captureView.bounds
    }
    
    func setupAvCaptureSession() {
        do {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            captureView.layer.addSublayer(previewLayer)
            
            let input = try AVCaptureDeviceInput(device:AVCaptureDevice.default(for: .video)!)
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: queue)
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

            session.addInput(input)
            session.addOutput(output)
        }catch {
            print(error)
        }
    }
    
    func startVideoCapture() {
        if session.isRunning {
            print("session already exists")
            return
        }
        session.startRunning()
    }
    
    func setupVision() {
        let rectanglesDetectionRequest = VNDetectRectanglesRequest(completionHandler: self.handleRectangles)
        rectanglesDetectionRequest.maximumObservations = 10
        rectanglesDetectionRequest.minimumSize = 0.1
        
        self.requests = [rectanglesDetectionRequest]
    }
    
    func handleRectangles(request: VNRequest, error: Error?)  {
        DispatchQueue.main.async {
            self.drawVisionRequestResults(results: request.results as? [VNRectangleObservation])
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions: [VNImageOption : Any] = [:]
        
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }
        
        let exifOrientation = self.exifOrientationFromDeviceOrientation()
        
        DispatchQueue.global(qos: .background).async {
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation:exifOrientation, options: requestOptions)
            do {
                try imageRequestHandler.perform(self.requests)
            } catch {
                print(error)
            }
        }
    }
    
    func drawVisionRequestResults(results: [VNRectangleObservation]?) {
        if let l_results = results {
            for rect in l_results {
                
                // Outline selected rectangle
                let points = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft]
                let convertedPoints = points.map { self.convertFromCamera($0) }
                self.captureView.layer.addSublayer(self.drawPolygon(convertedPoints, color: UIColor.green))
            }
        }
    }
    
    func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        return CGImagePropertyOrientation(rawValue: UInt32(UIDevice.current.orientation.rawValue))!
    }
    
    func convertFromCamera(_ point: CGPoint) -> CGPoint {
        let orientation = UIApplication.shared.statusBarOrientation
        
        switch orientation {
        case .portrait, .unknown:
            return CGPoint(x: point.y * self.captureView.frame.width, y: point.x * self.captureView.frame.height)
        case .landscapeLeft:
            return CGPoint(x: (1 - point.x) * self.captureView.frame.width, y: point.y * self.captureView.frame.height)
        case .landscapeRight:
            return CGPoint(x: point.x * self.captureView.frame.width, y: (1 - point.y) * self.captureView.frame.height)
        case .portraitUpsideDown:
            return CGPoint(x: (1 - point.y) * self.captureView.frame.width, y: (1 - point.x) * self.captureView.frame.height)
        }
    }
    
    private func drawPolygon(_ points: [CGPoint], color: UIColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.strokeColor = color.cgColor
        layer.lineWidth = 2
        let path = UIBezierPath()
        path.move(to: points.last!)
        points.forEach { point in
            path.addLine(to: point)
        }
        layer.path = path.cgPath
        return layer
    }
}

