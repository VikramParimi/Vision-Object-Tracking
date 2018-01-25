//
//  ViewController.swift
//  Object Tracking
//
//  Created by Parimi, Vikram (US - Bengaluru) on 1/20/18.
//  Copyright © 2018 vikram. All rights reserved.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private var requests = [VNRequest]()
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let queue = DispatchQueue(label: "com.vision.videoqueue")
    
    private var lastObservation: VNRectangleObservation?
    private let sequenceHandler = VNSequenceRequestHandler()
    private var rectangleLayer: CAShapeLayer?
    
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
    
    //MARK: AVCaptureSession Methods
    
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
    
    //MARK: Vision Setup
    
    func setupVision() {
        let rectanglesDetectionRequest = VNDetectRectanglesRequest(completionHandler: self.handleRectangles)
        rectanglesDetectionRequest.maximumObservations = 0
        rectanglesDetectionRequest.minimumSize = 0.1
        
        self.requests = [rectanglesDetectionRequest]
    }
    
    //MARK: Rectangle Detection and observation
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = self.exifOrientationFromDeviceOrientation()

        guard self.lastObservation != nil else {
            var requestOptions: [VNImageOption : Any] = [:]
            
            if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
                requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
            }
            
            DispatchQueue.global(qos: .background).async {
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation:exifOrientation, options: requestOptions)
                do {
                    try imageRequestHandler.perform(self.requests)
                } catch {
                    print(error)
                }
            }
            return
        }
        
        //Track the detected rectangle here
        
        let observation = self.lastObservation
        
        let trackRequest = VNTrackRectangleRequest(rectangleObservation: observation!, completionHandler: self.handleRectangles)
    //    let trackRequest = VNTrackObjectRequest(detectedObjectObservation: observation!, completionHandler: self.handleSequenceRequestUpdate)
        trackRequest.trackingLevel = .accurate
        
        do {
            try self.sequenceHandler.perform([trackRequest], on: pixelBuffer, orientation: exifOrientation)
        } catch {
            print(error)
        }
    }
    
    //MARK: Vision Completion Handlers
    
    func handleRectangles(request: VNRequest, error: Error?)  {
        DispatchQueue.main.async {
            self.drawVisionRequestResults(results: request.results as? [VNRectangleObservation])
        }
    }
    
    func handleSequenceRequestUpdate(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let newObservation = request.results?.first as? VNRectangleObservation else {return}
            
            self.lastObservation = newObservation
            
            guard newObservation.confidence >= 0.5 else {
                if let layer = self.rectangleLayer {
                    layer.removeFromSuperlayer()
                    self.rectangleLayer = nil
                }
                return
            }
            
            let points = [newObservation.topLeft, newObservation.topRight, newObservation.bottomRight, newObservation.bottomLeft]
            let convertedPoints = points.map { self.convertFromCamera($0) }
            self.rectangleLayer = self.drawBoundingBox(convertedPoints, color: #colorLiteral(red: 0.3328347607, green: 0.236689759, blue: 1, alpha: 1))
            self.captureView.layer.addSublayer(self.rectangleLayer!)
        }
    }
    
    func drawVisionRequestResults(results: [VNRectangleObservation]?) {
        if let layer = self.rectangleLayer {
            layer.removeFromSuperlayer()
            self.rectangleLayer = nil
        }
        
        if let observation = results?.first {
            self.lastObservation = observation
            let points = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
            let convertedPoints = points.map { self.convertFromCamera($0) }
            self.rectangleLayer = self.drawBoundingBox(convertedPoints, color: #colorLiteral(red: 0.3328347607, green: 0.236689759, blue: 1, alpha: 1))
            self.captureView.layer.addSublayer(self.rectangleLayer!)
        }
    }
    
    func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        return CGImagePropertyOrientation(rawValue: UInt32(UIDevice.current.orientation.rawValue))!
    }
    
    //MARK: Bounding Box Drawing Methods
    
    func drawSequence(request: VNRequest, error: Error?)  {
        
        if let layer = self.rectangleLayer {
            layer.removeFromSuperlayer()
            self.rectangleLayer = nil
        }
        
        if let observation = request.results?.first as? VNRectangleObservation {
            let points = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
            let convertedPoints = points.map { self.convertFromCamera($0) }
            self.rectangleLayer = self.drawBoundingBox(convertedPoints, color: #colorLiteral(red: 0.3328347607, green: 0.236689759, blue: 1, alpha: 1))
            self.captureView.layer.addSublayer(self.rectangleLayer!)
        }
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
    
    private func drawBoundingBox(_ points: [CGPoint], color: CGColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = #colorLiteral(red: 0.4506933627, green: 0.5190293554, blue: 0.9686274529, alpha: 0.2050513699)
        layer.strokeColor = color
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

