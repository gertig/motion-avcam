### AVCam built with RubyMotion

To get started clone the repo.

    $ bundle
    $ rake device

The app will only work on a device since it uses the camera.

This is essentially the AVCam sample application built using RubyMotion. The goal was to get acquainted with AVFoundation and the camera and I have tried to stay as close to the orginal as possible. The sample uses Storyboards and so I had to make some additions for adding the view and buttons.

One issue I ran into was KVO and the context Pointers for Recording, Camera, and SessionRunning. I couldn't get the context to pass in the correct Pointer so I switched to checking the keyPath instead. Would be interested to see if there is a good way of handling this situation.

Hope you find it useful.