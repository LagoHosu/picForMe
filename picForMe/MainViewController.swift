//
//  ViewController.swift
//  picForMe
//
//  Created by Lago on 2021/10/07.
//


import UIKit
import AVFoundation
import PhotosUI

class MainViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    //MARK: - Properties
    
    var previewView : UIView!
    var boxView:UIView!
    let myButton: UIButton = UIButton()
    let flipButton: UIButton = UIButton()
    let flashButton: UIButton = UIButton()

    
    //Camera Capture requiered properties
    var videoDataOutput: AVCaptureVideoDataOutput!
    var videoDataOutputQueue: DispatchQueue!
    var previewLayer:AVCaptureVideoPreviewLayer!
    var captureDevice : AVCaptureDevice!
    let session = AVCaptureSession()
    
    var usingFrontCamera = false

    
    private let photoOutput = AVCapturePhotoOutput()
    
    let photoImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    
    //MARK: - Actions
    
    //at the bottom, as an extension
    
    //MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        previewView = UIView(frame: CGRect(x: 0,
                                           y: 0,
                                           width: UIScreen.main.bounds.size.width,
                                           height: UIScreen.main.bounds.size.height))
        previewView.contentMode = UIView.ContentMode.scaleAspectFit
        view.addSubview(previewView)
        
        //Add a view on top of the cameras' view
        boxView = UIView(frame: self.view.frame)
        
        myButton.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        myButton.backgroundColor = UIColor.red
        myButton.layer.masksToBounds = true
        myButton.setTitle("press me", for: .normal)
        myButton.setTitleColor(UIColor.white, for: .normal)
        myButton.layer.cornerRadius = 20.0
        myButton.layer.position = CGPoint(x: self.view.frame.width/2, y:470)
        myButton.addTarget(self, action: #selector(self.onClickMyButton(sender:)), for: .touchUpInside)
        
        flipButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        flipButton.backgroundColor = UIColor.white
//        flipButton.image(for: <#T##UIControl.State#>)
        flipButton.layer.masksToBounds = true
        flipButton.setTitle("flip!", for: .normal)
        flipButton.setTitleColor(UIColor.black, for: .normal)
        flipButton.layer.cornerRadius = 20.0
        flipButton.layer.position = CGPoint(x: self.view.frame.width*3/4, y:50)
        flipButton.addTarget(self, action: #selector(self.onClickFlipButton(sender:)), for: .touchUpInside)
        
        flashButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        flashButton.backgroundColor = UIColor.white
//        flashButton.image(for: <#T##UIControl.State#>)
        flashButton.layer.masksToBounds = true
        flashButton.setTitle("flash", for: .normal)
        flashButton.setTitleColor(UIColor.black, for: .normal)
        flashButton.layer.cornerRadius = 20.0
        flashButton.layer.position = CGPoint(x: self.view.frame.width*1/4, y:50)
        flashButton.addTarget(self, action: #selector(self.onClickFlashButton(sender:)), for: .touchUpInside)
        
        view.addSubview(boxView)
        view.addSubview(myButton)
        view.addSubview(flipButton)
        view.addSubview(flashButton)

        self.setupAVCapture()
        
        requestGalleryPermission()
        requestCameraPermission()
        
        //to access the photo partially, check showUI() method part below
//        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [unowned self] (status) in
//            DispatchQueue.main.async { [unowned self] in
//                showUI(for: status)
//            }
//        }
        
    }
    
    
    override var shouldAutorotate: Bool {
        if (UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft ||
            UIDevice.current.orientation == UIDeviceOrientation.landscapeRight ||
            UIDevice.current.orientation == UIDeviceOrientation.unknown) {
            return false
        }
        else {
            return true
        }
    }
    
    //when press button selected
    @objc func onClickMyButton(sender: UIButton){
        print("button pressed")
        //make the picture saved
        //will you make this auto-save or check it right away?_save directly for now
        handleSavePhoto()
    }
    
    //when flip button selected
    @objc func onClickFlipButton(sender: UIButton){
        print("flip button pressed")
        changeCamera()
    }
    
    
    //when flash button selected
    @objc func onClickFlashButton(sender: UIButton){
        print("flash button pressed")
        toggleFlash()
    }
    
    
}

//MARK: - Helper

// AVCaptureVideoDataOutputSampleBufferDelegate protocol and related methods
extension MainViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
    func setupAVCapture(){
        session.sessionPreset = AVCaptureSession.Preset.vga640x480
        guard let device = AVCaptureDevice
                .default(AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                         for: .video,
                         position: AVCaptureDevice.Position.back) else {
                    return
                }
        captureDevice = device
        beginSession()
    }
    
    func beginSession(){
        var deviceInput: AVCaptureDeviceInput!
        
        do {
            deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            guard deviceInput != nil else {
                print("error: cant get deviceInput")
                return
            }
            
            if self.session.canAddInput(deviceInput){
                self.session.addInput(deviceInput)
            }
            
            videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.alwaysDiscardsLateVideoFrames=true
            videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
            videoDataOutput.setSampleBufferDelegate(self, queue:self.videoDataOutputQueue)
            
            if session.canAddOutput(self.videoDataOutput){
                session.addOutput(self.videoDataOutput)
            }
            
            videoDataOutput.connection(with: .video)?.isEnabled = true
            
            previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
            
            let rootLayer :CALayer = self.previewView.layer
            rootLayer.masksToBounds=true
            previewLayer.frame = rootLayer.bounds
            rootLayer.addSublayer(self.previewLayer)
            session.startRunning()
        } catch let error as NSError {
            deviceInput = nil
            print("error: \(error.localizedDescription)")
        }
    }
    
    
    // clean up AVCapture
    func stopCamera(){
        session.stopRunning()
    }
    
}


//set up capture session
extension MainViewController{
    
    private func setupCaptureSession() {
        let captureSession = AVCaptureSession()
        
        if let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) {
            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                }
            } catch let error {
                print("failed to set input device, error : \(error)")
            }
            
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
            
            let cameraLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            cameraLayer.frame = self.view.frame
            cameraLayer.videoGravity = .resizeAspectFill
            self.view.layer.addSublayer(cameraLayer)
            
            captureSession.startRunning()
            self.setupCaptureSession()
        }
    }
}


//to capture photo
extension MainViewController{
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // do stuff here
        let photoSettings = AVCapturePhotoSettings()
        if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
            
        }
    }
    
    //    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    //        guard let imageData = photo.fileDataRepresentation() else { return }
    //        let previewImage = UIImage(data: imageData)
    //
    //        var photoPreviewContainer1 = photoPreviewContainer(frame: self.view.frame)
    //        photoPreviewContainer1.photoPreviewView.image = previewImage
    //        self.view.addSubview(photoPreviewContainer1)
    //    }
}


//to save photo in library
extension MainViewController {
    @objc private func handleSavePhoto() {
        guard let previewImage = self.photoImageView.image else { return }
        
        PHPhotoLibrary.requestAuthorization { (status) in
            if status == .authorized {
                do {
                    try PHPhotoLibrary.shared().performChangesAndWait {
                        PHAssetChangeRequest.creationRequestForAsset(from: previewImage)
                        print("photo has saved in library!")
                    }
                } catch let error {
                    print("failed to save photo in library with error : \(error)")
                }
            } else {
                print("there is an error with permission,,,!")
            }
        }
        
    }
     
}

//for permissions about camera&photo
extension MainViewController {
    func requestCameraPermission(){
          AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
              if granted {
                  print("Camera: ?????? ??????")
              } else {
                  print("Camera: ?????? ??????")
              }
          })
      }
    
    func requestGalleryPermission(){
        PHPhotoLibrary.requestAuthorization( { status in
            switch status{
            case .authorized:
                print("Gallery: ?????? ??????")
            case .denied:
                print("Gallery: ?????? ??????")
            case .restricted, .notDetermined:
                print("Gallery: ???????????? ??????")
            default:
                break
            }
        })
    }
    
    
}

//to flip the camera
extension MainViewController {
    func getFrontCamera() -> AVCaptureDevice?{
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .front).devices.first
    }

    func getBackCamera() -> AVCaptureDevice?{
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices.first
    }
    
    
    private func changeCamera() {
        usingFrontCamera = !usingFrontCamera
        do{
            session.removeInput(session.inputs.first!)

            if(usingFrontCamera){
                captureDevice = getFrontCamera()
            }else{
                captureDevice = getBackCamera()
            }
            let captureDeviceInput1 = try AVCaptureDeviceInput(device: captureDevice)
            session.addInput(captureDeviceInput1)
        }catch{
            print(error.localizedDescription)
        }
    }
}


extension MainViewController {
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if (device.torchMode == AVCaptureDevice.TorchMode.on) {
                device.torchMode = AVCaptureDevice.TorchMode.off
            } else {
                do {
                    try device.setTorchModeOn(level: 1.0)
                } catch {
                    print(error)
                }
            }

            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
}
