**AURA**

AURA is an interactive playground that transforms sound into generative art. Built with SwiftUI and AVFoundation, it uses real-time frequency analysis to bridge the gap between our senses, allowing users to "see" and "feel" the architecture of their own voice.

<img width="1352" height="901" alt="image_11" src="https://github.com/user-attachments/assets/77be68b0-31e3-40f6-b2d3-874e9c049bbd" />

**Swift Student Challenge**

This project was developed for the 2026 Swift Student Challenge. It explores the concept of Sensory Substitution using high-fidelity haptics to translate audio energy into tactile feedback.

**Overview**

AURA features a suite of real-time generative engines that react to live microphone input:

**Matrix Engine**

A digital "rain" visualizer that calculates velocity and brightness based on the live amplitude of the user's voice.

SS

**Terrain Engine**

Uses complex trigonometric calculations to render a 3D topographic landscape. The elevation of the terrain is mapped directly to the frequency history of the audio signal.

SS

**Data Log**

A built-in gallery that allows users to save and replay their favorite visual "memories" using custom data persistence logic.

SS

**Technologies**

The playground is built natively in Swift using modern frameworks:

SwiftUI: For a highly reactive, 60 FPS user interface.

AVFoundation: Utilizing AVAudioEngine for low-latency microphone taps and PCM buffer processing.

CoreHaptics: To create a tactile "sound feel" through the iPhone Taptic Engine.

Observation: Utilizing the modern Swift Observation framework for efficient state management.

**The Mathematics**

To ensure the visuals were fluid without causing compiler timeouts, the rendering logic utilizes pre-calculated sub-expressions for wave generation.
The core elevation logic for the Terrain Engine follows this formula:

$$y = mid + (\sin(\theta) \cdot (Amplitude \cdot 90.0 \cdot PerspectiveScale))$$

This allows the landscape to "breathe" in sync with the pitch and volume of incoming audio.

**Accessibility**

Accessibility was a foundational pillar of the design. AURA utilizes Sensory Substitution by scaling Haptic Intensity directly with audio volume. This allows users with hearing impairments to feel the rhythm and energy of their environment through the device’s vibration motor.
