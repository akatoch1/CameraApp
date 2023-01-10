import UIKit
import ARKit
import SceneKit
import AVFoundation
import AVKit

class ViewController: UIViewController, AVCaptureDataOutputSynchronizerDelegate {
    
    
    
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var renderingEnabled = true
   
    private let dataOutputQueue = DispatchQueue(label: "video data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        
        guard let syncedDepthData: AVCaptureSynchronizedDepthData =
        synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData,
        let syncedVideoData: AVCaptureSynchronizedSampleBufferData =
        synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else {
            // only work on synced pairs
            return
    
        }
        let depthData = syncedDepthData.depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        /*let accuracy = depthData.depthDataAccuracy
            switch (accuracy) {
            case .absolute:
                /*
                NOTE - Values within the depth map are absolutely
                accurate within the physical world.
                */
                print("absolute")
                break
            case .relative:
                /*
                NOTE - Values within the depth data map are usable for
                foreground/background separation, but are not absolutely
                accurate in the physical world. iPhone always produces this.
                */
                print("relative")
            }*/
        let depthPixelBuffer = depthData.depthDataMap
        let sampleBuffer = syncedVideoData.sampleBuffer
        
        let point = CGPoint(x:50,y:50)
        let width = CVPixelBufferGetWidth(depthPixelBuffer)
        CVPixelBufferLockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            let depthPointer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthPixelBuffer), to: UnsafeMutablePointer<Float32>.self)

        let distanceAtXYPoint = depthPointer[Int(point.y * CGFloat(width) + point.x)]

        print(distanceAtXYPoint)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        let captureSession = AVCaptureSession()
        
        captureSession.sessionPreset = .photo
        guard let captureDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) else {return}
        let availableFormats = captureDevice.activeFormat.supportedDepthDataFormats
        //print(availableFormats)
        let depthFormat = availableFormats.filter { format in
            let pixelFormatType =
                CMFormatDescriptionGetMediaSubType(format.formatDescription)
            
            return (pixelFormatType == kCVPixelFormatType_DepthFloat16 ||
                    pixelFormatType == kCVPixelFormatType_DepthFloat32)
        }.first
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.activeDepthDataFormat = depthFormat
            captureDevice.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
            
            captureSession.commitConfiguration()
            return
        }

        captureSession.beginConfiguration()
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return}
        captureSession.addInput(input)
        
        
        if captureSession.canAddOutput(depthDataOutput) {
            depthDataOutput.isFilteringEnabled = true
            captureSession.addOutput(depthDataOutput)
            let depthConnection = depthDataOutput.connection(with: .depthData)
            depthConnection?.videoOrientation = .portrait
            
        }
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        }
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
        outputSynchronizer!.setDelegate(self, queue: dataOutputQueue)
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
    }
    
}

