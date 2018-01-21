# Vision-Object-Tracking

The aim of the project is to detect rectangles in a video frame and track the observations once detected by outlining them with a bounding box.

![N|Solid](http://image.ibb.co/gvxveG/IMG_4040.png) ![N|Solid](http://image.ibb.co/faPmmw/IMG_4041.png) ![N|Solid](http://image.ibb.co/jKQRmw/IMG_4042.png) ![N|Solid](http://image.ibb.co/cX65eG/IMG_4043.png)

# Getting Started

The application uses the Apple iOS11 vision framework to detect rectangles using  VNDetectRectanglesRequest and track the sequence.

# What's available

Using the VNDetectRectanglesRequest the application identifies the rectangles from the video frame and draws a bounding box around it. The next steps are to setup seemless tracking of the detetctions.

------------------------------------
### Setting Up Vision
------------------------------------
```swift
func setupVision() {
let rectanglesDetectionRequest = VNDetectRectanglesRequest(completionHandler: self.handleRectangles)
rectanglesDetectionRequest.maximumObservations = 0
rectanglesDetectionRequest.minimumSize = 0.1

self.requests = [rectanglesDetectionRequest]
}
```
------------------------------------
### Rectangle Detection and observation
------------------------------------
```swift
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
```

## Known issues

Rectangle detection on touch is not implemented
Tracking the reactangle is not implemented

### Also if you would like to contribute please take a pull from develop branch and submit a PR for your changes.



