# /*
#      File: AVCamViewController.m
#  Abstract: View controller for camera interface.
#   Version: 3.1
 
#  Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
#  Inc. ("Apple") in consideration of your agreement to the following
#  terms, and your use, installation, modification or redistribution of
#  this Apple software constitutes acceptance of these terms.  If you do
#  not agree with these terms, please do not use, install, modify or
#  redistribute this Apple software.
 
#  In consideration of your agreement to abide by the following terms, and
#  subject to these terms, Apple grants you a personal, non-exclusive
#  license, under Apple's copyrights in this original Apple software (the
#  "Apple Software"), to use, reproduce, modify and redistribute the Apple
#  Software, with or without modifications, in source and/or binary forms;
#  provided that if you redistribute the Apple Software in its entirety and
#  without modifications, you must retain this notice and the following
#  text and disclaimers in all such redistributions of the Apple Software.
#  Neither the name, trademarks, service marks or logos of Apple Inc. may
#  be used to endorse or promote products derived from the Apple Software
#  without specific prior written permission from Apple.  Except as
#  expressly stated in this notice, no other rights or licenses, express or
#  implied, are granted by Apple herein, including but not limited to any
#  patent rights that may be infringed by your derivative works or by other
#  works in which the Apple Software may be incorporated.
 
#  The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
#  MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
#  THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
#  FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
#  OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
#  IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
#  OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#  INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
#  MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
#  AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
#  STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.
 
#  Copyright (C) 2014 Apple Inc. All Rights Reserved.
#  */

#import "AVCamViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "AVCamPreviewView.h"

class AVCamViewController < UIViewController

  attr_accessor :sessionQueue, :session, :videoDeviceInput, :movieFileOutput, :stillImageOutput
  # Utilities
  attr_accessor :backgroundRecordingID, :deviceAuthorized, :sessionRunningAndDeviceAuthorized, :lockInterfaceRotation, :runtimeErrorHandlingObserver

  # Views and Buttons
  attr_accessor :previewView, :recordButton, :cameraButton, :stillButton

  # ContextPointer = Pointer.new(:object, 3)
  # ContextPointer[0]="Capturing"
  # ContextPointer[1]="Recording"
  # ContextPointer[2]="SessionRunning"


  CapturePointer = Pointer.new(:object, 1)
  CapturePointer[0] = "Capturing"

  RecordingPointer = Pointer.new(:object, 1)
  RecordingPointer[0] = "Recording"

  SessionRunningPointer = Pointer.new(:object, 1)
  SessionRunningPointer[0] = "SessionRunning"


  CapturingStillImageContext = CapturePointer
  RecordingContext = RecordingPointer
  SessionRunningAndDeviceAuthorizedContext = SessionRunningPointer

  def sessionRunningAndDeviceAuthorized
    NSLog("[method] sessionRunningAndDeviceAuthorized")
    self.session.isRunning && self.deviceAuthorized
  end

  def sessionRunningAndDeviceAuthorized=(sessionRunningAndDeviceAuthorized)
    @sessionRunningAndDeviceAuthorized = sessionRunningAndDeviceAuthorized
  end

  # def deviceAuthorized

  # end

  def self.keyPathsForValuesAffectingSessionRunningAndDeviceAuthorized
    NSLog("[method] self.NSObject.keyPathsForValuesAffectingAuthorized")
    NSSet.setWithObjects("session.running", "deviceAuthorized", nil)
  end

  def viewDidLoad
    super #.viewDidLoad

    # Create the AVCaptureSession
    session = AVCaptureSession.alloc.init
    self.setSession(session)
    
    # Setup the preview view

    # FROM HERE TO...
    #########################################################################
      self.navigationController.setNavigationBarHidden(true, animated:false)

      @previewView = AVCamPreviewView.alloc.initWithFrame(self.view.bounds)

      @recordButton = UIButton.buttonWithType(UIButtonTypeCustom)
      @recordButton.setTitle("Record", forState:UIControlStateNormal)
      @recordButton.addTarget(self, action:"toggleMovieRecording:", forControlEvents:UIControlEventTouchUpInside)
      @recordButton.frame = [[32,516], [72, 30]]

      @cameraButton = UIButton.buttonWithType(UIButtonTypeCustom)
      @cameraButton.setTitle("Swap", forState:UIControlStateNormal)
      @cameraButton.addTarget(self, action:"changeCamera:", forControlEvents:UIControlEventTouchUpInside)
      @cameraButton.frame = [[216,516], [72, 30]]

      @stillButton = UIButton.buttonWithType(UIButtonTypeCustom)
      @stillButton.setTitle("Still", forState:UIControlStateNormal)
      @stillButton.addTarget(self, action:"snapStillImage:", forControlEvents:UIControlEventTouchUpInside)
      @stillButton.frame = [[124,516], [72, 30]]

      self.view.addSubview(@previewView)
      self.view.addSubview(@recordButton)
      self.view.addSubview(@cameraButton)
      self.view.addSubview(@stillButton)
    #########################################################################
    # HERE, IS ADDITIONAL SINCE WE AREN'T USING STORYBOARDS

    self.previewView.setSession(session)
    
    # Check for device authorization
    self.checkDeviceAuthorizationStatus
    
    # In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, 
    # or connections from multiple threads at the same time.
    # Why not do all of this on the main queue?
    # -[AVCaptureSession startRunning] is a blocking call which can take a long time. 
    # We dispatch session setup to the sessionQueue so that the main queue isn't blocked
    # (which keeps the UI responsive).
    
    # dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);

    NSLog("Does this need a .dispatch_object to work correctly")

    @sessionQueue = Dispatch::Queue.new("session queue")

    # self.setSessionQueue(sessionQueue)
    
    @sessionQueue.async {
      self.setBackgroundRecordingID(UIBackgroundTaskInvalid)
      
      # error = nil
      error_ptr = Pointer.new(:object)
      
      videoDevice = AVCamViewController.deviceWithMediaType(AVMediaTypeVideo, preferringPosition:AVCaptureDevicePositionBack)
      # AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
      videoDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(videoDevice, error:error_ptr)
      
      if (error_ptr)
        NSLog("ERROR: %@", error_ptr)
      end
      
      if session.canAddInput(videoDeviceInput)
        session.addInput(videoDeviceInput)
        self.setVideoDeviceInput(videoDeviceInput)

        # dispatch_async(dispatch_get_main_queue(), ^{
        Dispatch::Queue.main.async {
          # Why are we dispatching this to the main queue?
          # Because AVCaptureVideoPreviewLayer is the backing layer for AVCamPreviewView and 
          # UIView can only be manipulated on main thread.

          # Note: As an exception to the above rule, it is not necessary to serialize 
          # video orientation changes on the AVCaptureVideoPreviewLayer’s connection with 
          # other session manipulation.
    
          NSLog("Set Video Orientation")
          self.previewView.layer.connection.setVideoOrientation(self.interfaceOrientation)
        }
      end
      
      audioDevice = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio).firstObject
      audioDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(audioDevice, error:error_ptr)
      
      if (error_ptr)
        NSLog("ERROR: %@", error_ptr)
      end
      
      if session.canAddInput(audioDeviceInput)
        session.addInput(audioDeviceInput)
      end
      
      movieFileOutput = AVCaptureMovieFileOutput.alloc.init

      if session.canAddOutput(movieFileOutput)
        session.addOutput(movieFileOutput)
        connection = movieFileOutput.connectionWithMediaType(AVMediaTypeVideo)
        if connection.isVideoStabilizationSupported
          connection.setEnablesVideoStabilizationWhenAvailable(true)
        end

        self.setMovieFileOutput(movieFileOutput)
      end
      
      stillImageOutput = AVCaptureStillImageOutput.alloc.init
      
      if session.canAddOutput(stillImageOutput)
        settings = { :AVVideoCodecKey => AVVideoCodecJPEG }
        NSLog("Settings Object: %@", settings.to_s)
        stillImageOutput.setOutputSettings(settings)
        session.addOutput(stillImageOutput)
        self.setStillImageOutput(stillImageOutput)
      end
    } # end of sessionQueue.async
  end

  def viewWillAppear(animated)

    # dispatch_async([self sessionQueue], ^{
    @sessionQueue.async {

      NSLog("Setup a bunch of observers")

      self.addObserver(self, forKeyPath:"sessionRunningAndDeviceAuthorized", options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew), context:SessionRunningAndDeviceAuthorizedContext)

      self.addObserver(self, forKeyPath:"stillImageOutput.capturingStillImage", options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew), context:CapturingStillImageContext)

      self.addObserver(self, forKeyPath:"movieFileOutput.recording", options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew), context:RecordingContext)

      NSNotificationCenter.defaultCenter.addObserver(self, selector:"subjectAreaDidChange:", name:AVCaptureDeviceSubjectAreaDidChangeNotification, object:self.videoDeviceInput.device)
      
      # __weak AVCamViewController *weakSelf = self;
      self.setRuntimeErrorHandlingObserver(NSNotificationCenter.defaultCenter.addObserverForName(AVCaptureSessionRuntimeErrorNotification, object:self.session, queue:nil, usingBlock: -> note {
        # AVCamViewController *strongSelf = weakSelf
        # dispatch_async(strongSelf.sessionQueue, ^{
        @sessionQueue.async {
          # Manually restarting the session since it must have been stopped due to an error. 
          self.session.startRunning
          self.recordButton.setTitle("Record", forState:UIControlStateNormal)
        }
      }.weak!))

      self.session.startRunning
    } # end @sessionQueue.async
  end

  def viewDidDisappear(animated)

    @sessionQueue.async {
      self.session.stopRunning
      
      NSNotificationCenter.defaultCenter.removeObserver(self, name:AVCaptureDeviceSubjectAreaDidChangeNotification, object:self.videoDeviceInput.device)

      NSNotificationCenter.defaultCenter.removeObserver(self.runtimeErrorHandlingObserver)
      
      self.removeObserver(self, forKeyPath:"sessionRunningAndDeviceAuthorized", context:SessionRunningAndDeviceAuthorizedContext)

      self.removeObserver(self, forKeyPath:"stillImageOutput.capturingStillImage", context:CapturingStillImageContext)
      self.removeObserver(self, forKeyPath:"movieFileOutput.recording", context:RecordingContext)
    }

  end

  def prefersStatusBarHidden
    true
  end

  def shouldAutorotate
    # Disable autorotation of the interface when recording is in progress.
    !@lockInterfaceRotation
  end

  def supportedInterfaceOrientations
    UIInterfaceOrientationMaskAll
  end

  def willRotateToInterfaceOrientation(toInterfaceOrientation, duration:duration)
    self.previewView.layer.connection.setVideoOrientation(toInterfaceOrientation)
  end

  def observeValueForKeyPath(keyPath, ofObject:object, change:change, context:context)

    # if context == CapturingStillImageContext
    if keyPath == "stillImageOutput.capturingStillImage"
      isCapturingStillImage = Utils.boolValue(change[NSKeyValueChangeNewKey])
      NSLog("CapturingStillImageContext, change New: %@", isCapturingStillImage.to_s)
      
      if isCapturingStillImage
        self.runStillImageCaptureAnimation
      end
    # elsif context == RecordingContext
    elsif keyPath == "movieFileOutput.recording"
      isRecording = Utils.boolValue(change[NSKeyValueChangeNewKey])
      NSLog("RecordingContext, change New: %@", isRecording.to_s)
      
      # dispatch_async(dispatch_get_main_queue(), ->{
      Dispatch::Queue.main.async {
        if isRecording
          self.cameraButton.setEnabled(false)
          self.recordButton.setTitle("Stop", forState:UIControlStateNormal)
          self.recordButton.setEnabled(true)
        else
          self.cameraButton.setEnabled(true)
          self.recordButton.setTitle("Record", forState:UIControlStateNormal)
          self.recordButton.setEnabled(true)
        end
      } # main.async
    # elsif context == SessionRunningAndDeviceAuthorizedContext
    elsif keyPath == "sessionRunningAndDeviceAuthorized"
      isRunning = Utils.boolValue(change[NSKeyValueChangeNewKey])
      NSLog("SessionRunningAndDeviceAuthorizedContext, change New: %@", isRunning.to_s)      

      # dispatch_async(dispatch_get_main_queue(), ->{
      Dispatch::Queue.main.async {
        if isRunning
          self.cameraButton.setEnabled(true)
          self.recordButton.setEnabled(true)
          self.stillButton.setEnabled(true)
        else
          self.cameraButton.setEnabled(false)
          self.recordButton.setEnabled(false)
          self.stillButton.setEnabled(false)
        end
      } # main.async
    else
      NSLog("Uh oh, not going to handle this properly")
      # super #.observeValueForKeyPath(keyPath, ofObject:object, change:change, context:context)
    end
  end

  #pragma mark Actions

  # (IBAction)
  def toggleMovieRecording(sender)
    self.recordButton.setEnabled(false)
    
    # dispatch_async([self sessionQueue], ^{
    @sessionQueue.async {
      if !self.movieFileOutput.isRecording
        self.setLockInterfaceRotation(true)
        
        if UIDevice.currentDevice.isMultitaskingSupported

          # Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error: after the recorded file has been saved.
          self.setBackgroundRecordingID(UIApplication.sharedApplication.beginBackgroundTaskWithExpirationHandler(nil))
        end
        
        # Update the orientation on the movie file output video connection before starting recording.
        self.movieFileOutput.connectionWithMediaType(AVMediaTypeVideo).setVideoOrientation(self.previewView.layer.connection.videoOrientation)
        
        # Turning OFF flash for video recording
        AVCamViewController.setFlashMode(AVCaptureFlashModeOff, forDevice:self.videoDeviceInput.device)
        
        # Start recording to a temporary file.
        # NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"movie" stringByAppendingPathExtension:@"mov"]];
        outputFilePath = "#{NSTemporaryDirectory()}movie.mov"

        self.movieFileOutput.startRecordingToOutputFileURL(NSURL.fileURLWithPath(outputFilePath), recordingDelegate:self)

      else
        self.movieFileOutput.stopRecording
      end
    } # end @sessionQueue.async 
  end

  # - (IBAction)
  def changeCamera(sender)
    self.cameraButton.setEnabled(false)
    self.recordButton.setEnabled(false)
    self.stillButton.setEnabled(false)
    
    # dispatch_async([self sessionQueue], ^{
    @sessionQueue.async {
      currentVideoDevice = self.videoDeviceInput.device
      preferredPosition = AVCaptureDevicePositionUnspecified
      currentPosition = currentVideoDevice.position
      
      case (currentPosition)
      when AVCaptureDevicePositionUnspecified
        preferredPosition = AVCaptureDevicePositionBack
      when AVCaptureDevicePositionBack
        preferredPosition = AVCaptureDevicePositionFront
      when AVCaptureDevicePositionFront
        preferredPosition = AVCaptureDevicePositionBack
      end
      
      videoDevice = AVCamViewController.deviceWithMediaType(AVMediaTypeVideo, preferringPosition:preferredPosition)
      videoDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(videoDevice, error:nil)

      self.session.beginConfiguration
      
      self.session.removeInput(self.videoDeviceInput)

      if (self.session.canAddInput(videoDeviceInput))
        NSNotificationCenter.defaultCenter.removeObserver(self, name:AVCaptureDeviceSubjectAreaDidChangeNotification, object:currentVideoDevice)
        
        AVCamViewController.setFlashMode(AVCaptureFlashModeAuto, forDevice:videoDevice)
        NSNotificationCenter.defaultCenter.addObserver(self, selector:"subjectAreaDidChange:", name:AVCaptureDeviceSubjectAreaDidChangeNotification, object:videoDevice)
        
        self.session.addInput(videoDeviceInput)
        self.setVideoDeviceInput(videoDeviceInput)
      else
        self.session.addInput(self.videoDeviceInput)
      end
      
      self.session.commitConfiguration
      
      # dispatch_async(dispatch_get_main_queue(), ^{
      Dispatch::Queue.main.async {
        self.cameraButton.setEnabled(true)
        self.recordButton.setEnabled(true)
        self.stillButton.setEnabled(true)
      }
    } # end @sessionQueue.async
  end

  # - (IBAction)
  def snapStillImage(sender)
    # dispatch_async([self sessionQueue], ^{
    @sessionQueue.async {
      # Update the orientation on the still image output video connection before capturing.
      self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo).setVideoOrientation(self.previewView.layer.connection.videoOrientation)
      
      # Flash set to Auto for Still Capture
      AVCamViewController.setFlashMode(AVCaptureFlashModeAuto, forDevice:self.videoDeviceInput.device)
      
      # Capture a still image.
      NSLog("Is this Block Correct?")

      self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo), completionHandler: -> imageDataSampleBuffer, error {
        
        if imageDataSampleBuffer
          imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
          image = UIImage.alloc.initWithData(imageData)
          ALAssetsLibrary.alloc.init.writeImageToSavedPhotosAlbum(image.CGImage, orientation:image.imageOrientation, completionBlock:nil)
        end
      })
    } # end @sessionQueue.async
  end

  # - (IBAction)
  def focusAndExposeTap(gestureRecognizer)
    devicePoint = self.previewView.layer.captureDevicePointOfInterestForPoint(gestureRecognizer.locationInView(gestureRecognizer.view))

    self.focusWithMode(AVCaptureFocusModeAutoFocus, exposeWithMode:AVCaptureExposureModeAutoExpose, atDevicePoint:devicePoint, monitorSubjectAreaChange:true)
  end

  def subjectAreaDidChange(notification)
    devicePoint = CGPointMake(0.5, 0.5)
    self.focusWithMode(AVCaptureFocusModeContinuousAutoFocus, exposeWithMode:AVCaptureExposureModeContinuousAutoExposure, atDevicePoint:devicePoint, monitorSubjectAreaChange:false)
  end

  #pragma mark File Output Delegate

  def captureOutput(captureOutput, didFinishRecordingToOutputFileAtURL:outputFileURL, fromConnections:connections, error:error)

    if error
      NSLog("%@", error)
    end
    
    self.setLockInterfaceRotation(false)
    
    # Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.

    backgroundRecordingID = self.backgroundRecordingID

    self.setBackgroundRecordingID(UIBackgroundTaskInvalid)
    
    ALAssetsLibrary.alloc.init.writeVideoAtPathToSavedPhotosAlbum(outputFileURL, completionBlock: -> assetURL, error {

      if error
        NSLog("Error 84 - %@", error)
      end
      
      NSFileManager.defaultManager.removeItemAtURL(outputFileURL, error:nil)
      
      if backgroundRecordingID != UIBackgroundTaskInvalid
        UIApplication.sharedApplication.endBackgroundTask(backgroundRecordingID)
      end

    })
  end

  #pragma mark Device Configuration

  def focusWithMode(focusMode, exposeWithMode:exposureMode, atDevicePoint:point, monitorSubjectAreaChange:monitorSubjectAreaChange)

    # dispatch_async([self sessionQueue], ^{
    @sessionQueue.async {
      device = self.videoDeviceInput.device
      # error = nil
      error = Pointer.new(:object)

      if device.lockForConfiguration(error)
      
        if (device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode))
          device.setFocusMode(focusMode)
          device.setFocusPointOfInterest(point)
        end

        if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode)
          device.setExposureMode(exposureMode)
          device.setExposurePointOfInterest(point)
        end

        device.setSubjectAreaChangeMonitoringEnabled(monitorSubjectAreaChange)
        device.unlockForConfiguration

      else
        NSLog("%@", error)
      end

    } # end @sessionQueue.async
  end

  def self.setFlashMode(flashMode, forDevice:device)

    if device.hasFlash && device.isFlashModeSupported(flashMode)
    
      # error = nil
      error = Pointer.new(:object)

      if (device.lockForConfiguration(error))
        device.setFlashMode(flashMode)
        device.unlockForConfiguration
      else
        NSLog("Error: %@", error)
      end
    end
  end

  def self.deviceWithMediaType(mediaType, preferringPosition:position)
    devices = AVCaptureDevice.devicesWithMediaType(mediaType)
    captureDevice = devices.firstObject

    # for (AVCaptureDevice *device in devices)
    devices.each do |device|
      if device.position == position
        captureDevice = device
        break
      end
    end
    
    captureDevice
  end

  #pragma mark UI

  def runStillImageCaptureAnimation
    # dispatch_async(dispatch_get_main_queue(), ^{
    Dispatch::Queue.main.async {
      self.previewView.layer.setOpacity(0.0)
      UIView.animateWithDuration(0.25, animations: -> {
        self.previewView.layer.setOpacity(1.0)
      })
    }
  end

  def checkDeviceAuthorizationStatus

    mediaType = AVMediaTypeVideo
    
    AVCaptureDevice.requestAccessForMediaType(mediaType, completionHandler: -> granted {
      if (granted)
        #Granted access to mediaType
        self.setDeviceAuthorized(true)
      else
        #Not granted access to mediaType 
        # dispatch_async(dispatch_get_main_queue(), ->{
        Dispatch::Queue.main.async {
          UIAlertView.alloc.initWithTitle("AVCam!", message:"AVCam doesn't have permission to use Camera, please change privacy settings", delegate:self, cancelButtonTitle:"OK", otherButtonTitles:nil).show
          self.setDeviceAuthorized(false)
        }
      end
    })
  end

end
