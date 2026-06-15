<h1 align="center" style="letter-spacing: 4px;">ΛＵＲΛ</h1>

AURA is an interactive playground that transforms sound into generative art. Built with SwiftUI and AVFoundation, it uses real-time frequency analysis to bridge the gap between our senses, allowing users to "see" and "feel" the architecture of their own voice.

<img width="1500" alt="image_11 (1)" src="https://github.com/user-attachments/assets/246554f5-44f4-42d7-8e78-c280ba72c6d7" />

**Swift Student Challenge**

This project was developed for the 2026 Swift Student Challenge. It explores the concept of Sensory Substitution using high-fidelity haptics to translate audio energy into tactile feedback.

<div align="center">

<img width="300" alt="ssc-logo-code-status_2x" src="https://github.com/user-attachments/assets/f8cdf3de-08ae-442a-a65b-1015441d886f" />

</div>

**Overview**

AURA features a suite of real-time generative engines that react to live microphone input:

<div align="center">

<img width="500" alt="Screenshot 2026-06-15 at 1 21 13 AM - Edited" src="https://github.com/user-attachments/assets/0ababffd-0ea3-45e3-aea9-cd5c70fe9370" />

</div>

**Matrix Engine**

A digital "rain" visualizer that calculates velocity and brightness based on the live amplitude of the user's voice.

<div align="center">

<img width="400" alt="Screenshot 2026-06-15 at 1 10 28 AM-portrait" src="https://github.com/user-attachments/assets/c188d54e-42d5-48f9-b07c-1888da49be09" />

</div>

**Terrain Engine**

Uses complex trigonometric calculations to render a 3D topographic landscape. The elevation of the terrain is mapped directly to the frequency history of the audio signal.

<div align="center">

<img width="400" alt="Screenshot 2026-06-15 at 1 10 57 AM-portrait" src="https://github.com/user-attachments/assets/369548c2-92bd-473b-9c8a-33fa88cf426a" />

</div>

**Data Log**

<div align="center">

  <p>A built-in gallery that allows users to save and replay their favorite visual "memories" using custom data persistence logic.</p>

<img width="400" alt="Screenshot3" src="https://github.com/user-attachments/assets/b8cf14f0-84f7-4385-a9d6-1f3ac975651e" />

</div>

**Technologies**

The playground is built natively in Swift using modern frameworks:

SwiftUI: For a highly reactive, 60 FPS user interface.

AVFoundation: Utilizing AVAudioEngine for low-latency microphone taps and PCM buffer processing.

CoreHaptics: To create a tactile "sound feel" through the iPhone Taptic Engine.

Observation: Utilizing the modern Swift Observation framework for efficient state management.

<div align="center">

<img width="350" alt="swiftui-256x256_2x" src="https://github.com/user-attachments/assets/c21de5ca-cf34-44c0-9daa-5b2a1dd58e1b" />

</div>

**The Mathematics**

To ensure the visuals were fluid without causing compiler timeouts, the rendering logic utilizes pre-calculated sub-expressions for wave generation.
The core elevation logic for the Terrain Engine follows this formula:

$$y = mid + (\sin(\theta) \cdot (Amplitude \cdot 90.0 \cdot PerspectiveScale))$$

This allows the landscape to "breathe" in sync with the pitch and volume of incoming audio.

<div align="center">

<img width="600" alt="Screenshot 2026-06-15 at 1 30 49 AM" src="https://github.com/user-attachments/assets/76eba3e3-82b1-4e55-ad3c-00276a7dda60" />

</div>

**Accessibility**

Accessibility was a foundational pillar of the design. AURA utilizes Sensory Substitution by scaling Haptic Intensity directly with audio volume. This allows users with hearing impairments to feel the rhythm and energy of their environment through the device’s vibration motor.

<div align="center">

<img width="500" alt="kUvaxoYwuPxaEseH_6bd3a67d-3a6e-482b-b60f-01d01db10432 - Edited - Edited" src="https://github.com/user-attachments/assets/1bc939ce-87c4-41a4-854d-bbc628eb023d" />

</div>
