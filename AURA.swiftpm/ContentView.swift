import SwiftUI
import AVFoundation
import CoreHaptics

// MODELS
enum AuraStyle: String, Codable, CaseIterable {
    case terrain = "Terrain"
    case vortex = "Vortex"
    case spectrum = "Spectrum"
    case fluid = "Fluid"
    case matrix = "Matrix"
    case stardust = "Stardust"
    
    var color: Color {
        switch self {
        case .terrain: return .cyan
        case .vortex: return .purple
        case .spectrum: return .orange
        case .fluid: return .pink
        case .matrix: return .green
        case .stardust: return .white
        }
    }
    
    var icon: String {
        switch self {
        case .terrain: return "chart.bar.doc.horizontal"
        case .vortex: return "tornado"
        case .spectrum: return "waveform.path.ecg"
        case .fluid: return "drop.fill"
        case .matrix: return "terminal.fill"
        case .stardust: return "sparkles"
        }
    }
}

struct AuraMemory: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let style: AuraStyle
    let history: [CGFloat]
}

// AURA ENGINE
@Observable
class AuraEngine {
    var amplitude: CGFloat = 0.0
    var pitch: String = "--"
    var frequencyHistory: [CGFloat] = Array(repeating: 0.0, count: 50)
    
    private var audioEngine: AVAudioEngine?
    private var hapticEngine: CHHapticEngine?
    private var isRunning = false
    private var pitchBuffer: [String] = []
    private let bufferSize = 10
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    init() { prepareHaptics() }
    
    func start() {
        guard !isRunning else { return }
        AVAudioApplication.requestRecordPermission { granted in
            if granted {
                DispatchQueue.main.async { self.setupAudio() }
            }
        }
    }
    
    private func setupAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
            try session.setActive(true)
            
            let engine = AVAudioEngine()
            self.audioEngine = engine
            let input = engine.inputNode
            let format = input.inputFormat(forBus: 0)
            
            engine.connect(input, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0
            
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.processAudio(buffer)
            }
            
            engine.prepare()
            try engine.start()
            try hapticEngine?.start()
            isRunning = true
            
        } catch { print("Audio Error: \(error)") }
    }
    
    private func processAudio(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        
        var sumSq: Float = 0.0
        for frame in frames { sumSq += (frame * frame) }
        let val = sumSq / Float(buffer.frameLength)
        let rms = sqrt(val)
        let amp = CGFloat(min(rms * 15.0, 1.0)) 
        
        var zeroCrossings = 0
        for i in 1..<frames.count {
            if (frames[i-1] > 0 && frames[i] <= 0) || (frames[i-1] <= 0 && frames[i] > 0) {
                zeroCrossings += 1
            }
        }
        
        let sampleRate = Float(buffer.format.sampleRate)
        let totalFrames = Float(frames.count)
        let crossings = Float(zeroCrossings)
        let freq = (sampleRate / 2.0) * (crossings / totalFrames)
        
        DispatchQueue.main.async {
            self.amplitude = amp
            var history = self.frequencyHistory
            history.removeFirst()
            history.append(amp)
            self.frequencyHistory = history
            
            if freq > 60 && amp > 0.05 {
                let rawNote = self.freqToNote(freq)
                self.pitchBuffer.append(rawNote)
                if self.pitchBuffer.count > self.bufferSize { self.pitchBuffer.removeFirst() }
                
                let counts = self.pitchBuffer.reduce(into: [:]) { $0[$1, default: 0] += 1 }
                if let (mostFrequent, _) = counts.max(by: { $0.value < $1.value }) {
                    self.pitch = mostFrequent
                }
            }
            if amp > 0.6 { self.playHaptic(intensity: Float(amp)) }
        }
    }
    
    private func freqToNote(_ freq: Float) -> String {
        let val = Double(freq)
        let ratio = val / 440.0
        if ratio <= 0 { return "--" }
        let logVal = log(ratio)
        let log2Val = log(2.0)
        let num = 12.0 * (logVal / log2Val)
        let index = Int(round(num + 69.0))
        let norm = index % 12
        if norm >= 0 && norm < noteNames.count { return noteNames[norm] }
        return "--"
    }
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch { }
    }
    
    private func playHaptic(intensity: Float) {
        guard let engine = hapticEngine else { return }
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        ], relativeTime: 0)
        try? engine.makePlayer(with: try! CHHapticPattern(events: [event], parameters: [])).start(atTime: 0)
    }
}

// UI COMPONENTS
struct LiquidIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 60
    
    var body: some View {
        ZStack {
            Circle().fill(.black)
            Circle().fill(LinearGradient(colors: [color.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom))
            Circle().trim(from: 0.1, to: 0.4)
                .stroke(LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .rotationEffect(.degrees(180))
                .padding(2)
            Circle().stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

struct CinematicTitle: View {
    var amp: Double
    var body: some View {
        ZStack {
            Text("AURA")
                .font(.system(size: 80, weight: .black, design: .serif))
                .kerning(15 + (amp * 25))
                .foregroundStyle(.white.opacity(0.1))
                .blur(radius: 10 + (amp * 20))
            
            Text("AURA").font(.system(size: 80, weight: .black, design: .serif))
                .kerning(15 + (amp * 25))
                .foregroundStyle(.red.opacity(0.7)).offset(x: -4 * amp).blendMode(.screen).opacity(amp > 0.05 ? 1 : 0)
            
            Text("AURA").font(.system(size: 80, weight: .black, design: .serif))
                .kerning(15 + (amp * 25))
                .foregroundStyle(.cyan.opacity(0.7)).offset(x: 4 * amp).blendMode(.screen).opacity(amp > 0.05 ? 1 : 0)
            
            Text("AURA").font(.system(size: 80, weight: .black, design: .serif))
                .kerning(15 + (amp * 25))
                .foregroundStyle(.white)
        }
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: amp)
    }
}

struct LiquidTextCircle: View {
    let text: String
    let color: Color
    var size: CGFloat = 120
    
    var body: some View {
        ZStack {
            Circle().fill(.black)
            Circle().fill(LinearGradient(colors: [color.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(text)
                .font(.system(size: size * 0.4, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: text)
            Circle().trim(from: 0.1, to: 0.4)
                .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(180))
                .padding(4)
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

// VISUALIZERS
struct UniversalRenderer: View {
    var style: AuraStyle
    var history: [CGFloat]
    var currentAmp: CGFloat
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            getVisualizer(time: time).drawingGroup()
        }
    }
    
    func getVisualizer(time: Double) -> AnyView {
        switch style {
        case .terrain: return AnyView(TerrainView(history: history, time: time))
        case .vortex: return AnyView(VortexView(history: history, time: time))
        case .spectrum: return AnyView(SpectrumView(history: history, time: time))
        case .fluid: return AnyView(FluidView(history: history, time: time))
        case .matrix: return AnyView(MatrixView(history: history, instantAmp: currentAmp, time: time))
        case .stardust: return AnyView(StardustView(history: history, instantAmp: currentAmp, time: time))
        }
    }
}

struct TerrainView: View {
    var history: [CGFloat]; var time: Double
    var body: some View {
        Canvas { ctx, size in
            let w = Double(size.width); let h = Double(size.height); let mid = h * 0.4
            for i in 0...8 {
                let iD = Double(i)
                let x = w * (0.4 + (iD/8.0)*0.2); let xEnd = w * (iD/8.0)
                var p = Path(); p.move(to: CGPoint(x: x, y: mid)); p.addLine(to: CGPoint(x: xEnd, y: h))
                ctx.stroke(p, with: .color(.cyan.opacity(0.3)), lineWidth: 1)
            }
            for r in 0..<12 {
                let rD = Double(r); let prog = rD/12.0; let y = mid + (pow(prog, 2.0) * (h - mid))
                let idx = Int(rD); let safeIdx = min(idx, history.count - 1); let amp = Double(history.reversed()[safeIdx])
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); let step = 10.0; var x = 0.0
                while x < w {
                    let relX = x/w; let off = sin((relX * .pi * 4.0) + (time * 2.0)) * (amp * 80.0 * prog)
                    p.addLine(to: CGPoint(x: x, y: y - off)); x += step
                }
                ctx.stroke(p, with: .color(.cyan.opacity(0.1 + prog)), lineWidth: 1 + (prog * 2))
            }
        }
    }
}

struct VortexView: View {
    var history: [CGFloat]; var time: Double
    var body: some View {
        Canvas { ctx, size in
            let w = Double(size.width); let h = Double(size.height); let cx = w / 2.0; let cy = h / 2.0; let amp = Double(history.last ?? 0)
            for i in 0..<50 {
                let iD = Double(i); let prog = iD / 50.0; let r = 50.0 + (prog * 150.0) + (amp * 50.0)
                let angle = (prog * .pi * 4) + (time * (1.0 - prog))
                let x = cx + cos(angle) * r; let y = cy + sin(angle) * r
                var p = Path(); p.addEllipse(in: CGRect(x: x, y: y, width: 5+(amp*10), height: 5+(amp*10)))
                ctx.addFilter(.blur(radius: 5 * amp)); ctx.fill(p, with: .color(.purple.opacity(1.0 - prog)))
            }
        }
    }
}

struct SpectrumView: View {
    var history: [CGFloat]; var time: Double
    var body: some View {
        Canvas { ctx, size in
            let w = Double(size.width); let h = Double(size.height); let cx = w / 2.0; let cy = h / 2.0; let r = 80.0
            for i in 0..<history.count {
                let iD = Double(i); let countD = Double(history.count); let val = Double(history[i])
                let angle = (iD/countD) * .pi * 2 + time
                let sX = cx + cos(angle)*r; let sY = cy + sin(angle)*r
                let eX = cx + cos(angle)*(r + 10 + val*100); let eY = cy + sin(angle)*(r + 10 + val*100)
                var p = Path(); p.move(to: CGPoint(x: sX, y: sY)); p.addLine(to: CGPoint(x: eX, y: eY))
                ctx.stroke(p, with: .color(.orange), lineWidth: 4)
            }
            var core = Path(); core.addEllipse(in: CGRect(x: cx-60, y: cy-60, width: 120, height: 120))
            ctx.addFilter(.blur(radius: 20)); ctx.fill(core, with: .color(.orange.opacity(0.3)))
        }
    }
}

struct FluidView: View {
    var history: [CGFloat]; var time: Double
    var body: some View {
        Canvas { ctx, size in
            let w = Double(size.width); let h = Double(size.height); let mid = h / 2.0
            var p = Path(); p.move(to: CGPoint(x: 0, y: mid)); let step = 5.0; var x = 0.0
            while x < w {
                let rel = x/w; let idx = Int(rel * Double(history.count - 1)); let amp = Double(history[idx])
                let y1 = sin(rel*10.0 + time) * 20.0; let y2 = cos(rel*20.0 - time) * (amp * 100.0)
                p.addLine(to: CGPoint(x: x, y: mid + y1 + y2)); x += step
            }
            ctx.stroke(p, with: .color(.pink), lineWidth: 3)
            ctx.addFilter(.blur(radius: 10))
            ctx.stroke(p, with: .color(.pink.opacity(0.5)), lineWidth: 8)
        }
    }
}

// ZERO-DELAY MATRIX ENGINE
struct MatrixView: View {
    var history: [CGFloat]; var instantAmp: CGFloat; var time: Double
    var body: some View {
        Canvas { ctx, size in
            // INSTANT KILL: If no sound, draw nothing
            guard instantAmp > 0.05 else { return }
            
            let w = Double(size.width); let h = Double(size.height)
            let cols = 22; let colWidth = w / 22.0
            
            for c in 0..<22 {
                let ratio = Double(c) / 22.0
                let amp = Double(history[Int(ratio * Double(history.count - 1))])
                
                // Frequency-specific visibility
                if amp > 0.08 {
                    let speed = 400.0 + (amp * 900.0)
                    let offset = Double(c) * 123.45
                    let yBase = ((time * speed) + offset).truncatingRemainder(dividingBy: h + 300) - 150
                    
                    for i in 0..<15 {
                        let iD = Double(i)
                        let y = yBase - (iD * 18.0)
                        if y > -20 && y < h + 20 {
                            let rect = CGRect(x: Double(c) * colWidth + (colWidth * 0.1), y: y, width: colWidth * 0.8, height: 14)
                            var char = Path(); char.addRect(rect)
                            let alpha = (1.0 - (iD/15.0)) * min(amp * 2.0, 1.0)
                            ctx.fill(char, with: .color(.green.opacity(alpha)))
                            
                            if i == 0 {
                                ctx.addFilter(.blur(radius: 4))
                                ctx.fill(char, with: .color(.white.opacity(alpha)))
                            }
                        }
                    }
                }
            }
        }
    }
}

struct StardustView: View {
    var history: [CGFloat]; var instantAmp: CGFloat; var time: Double
    var body: some View {
        Canvas { ctx, size in
            // INSTANT KILL: No Sound, No Stars
            guard instantAmp > 0.05 else { return }
            
            let w = Double(size.width); let h = Double(size.height); let cx = w/2; let cy = h/2
            let amp = Double(history.last ?? 0)
            let speed = 0.5 + (amp * 10.0)
            for i in 0..<100 {
                let iD = Double(i); let angle = iD * 137.0; let distBase = iD * 5.0
                let dist = (distBase + (time * 100.0 * speed)).truncatingRemainder(dividingBy: w)
                let x = cx + cos(angle) * dist; let y = cy + sin(angle) * dist
                let sizeStar = (dist/w) * (5.0 + (amp * 5.0))
                var p = Path(); p.addEllipse(in: CGRect(x: x, y: y, width: sizeStar, height: sizeStar))
                ctx.fill(p, with: .color(.white.opacity((dist/w) * amp * 3.0)))
            }
        }
    }
}

// MARK: - 5. INTRO VIEW
struct IntroView: View {
    var amp: Double
    var onStart: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Canvas { ctx, size in
                let w = Double(size.width); let h = Double(size.height); let cy = h/2
                var p = Path(); p.move(to: CGPoint(x: 0, y: cy)); let step = 5.0; var x = 0.0
                while x < w {
                    let rel = x/w; let sine = sin(rel * 20.0 + Date().timeIntervalSince1970 * 5.0)
                    let y = cy + (sine * 150.0 * amp)
                    p.addLine(to: CGPoint(x: x, y: y)); x += step
                }
                ctx.stroke(p, with: .color(.white.opacity(0.1)), lineWidth: 2)
            }
            .ignoresSafeArea()
            VStack(spacing: 30) {
                Spacer()
                CinematicTitle(amp: amp)
                Text("AUDIO INTELLIGENCE").font(.caption.monospaced()).tracking(5).foregroundStyle(.white.opacity(0.5))
                Spacer()
                Button(action: onStart) {
                    Text("INITIALIZE").font(.headline.bold()).tracking(2).foregroundStyle(.black).padding(.vertical, 16).padding(.horizontal, 40).background(Color.white).clipShape(Capsule())
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - 6. TUTORIAL
struct EducationalTutorial: View {
    @Binding var showTutorial: Bool
    @State private var step = 0
    @State private var transitionGrainOpacity = 0.0
    @State private var contentBlurRadius = 0.0
    var audioEngine: AuraEngine
    
    let steps: [(String, String, String)] = [
        ("Precision Input", "High-fidelity audio capture initialized. AURA is listening.", "mic.fill"),
        ("Signal Analysis", "Real-time FFT processing decomposes sound into frequency data.", "waveform.path.ecg"),
        ("Visual Synthesis", "Generative algorithms translate vibration into geometry.", "cube.transparent"),
        ("Pitch Detection", "Algorithms identify the fundamental frequency of your voice.", "tuningfork"), 
        ("Calibration", "Input required. Generate audio to sync the engine.", "slider.horizontal.3")
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let amp = Double(audioEngine.amplitude)
                getBackground(step: step, amp: amp, time: time).ignoresSafeArea()
            }
            .blur(radius: contentBlurRadius)
            VStack(spacing: 40) {
                Spacer()
                if step == 3 { LiquidTextCircle(text: audioEngine.pitch, color: .green).id("pitchIcon") } 
                else { LiquidIcon(systemName: steps[step].2, color: .white, size: 120).id("icon\(step)") }
                Text(steps[step].0).font(.largeTitle.weight(.semibold)).foregroundStyle(.white).id("title\(step)")
                Text(steps[step].1).font(.body).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 40).id("desc\(step)")
                if step == 4 {
                    VStack {
                        Text(audioEngine.amplitude > 0.05 ? "INPUT DETECTED" : "WAITING FOR INPUT").font(.caption.bold()).foregroundStyle(audioEngine.amplitude > 0.05 ? .green : .secondary)
                        Capsule().fill(Color.gray.opacity(0.3)).frame(width: 250, height: 8).overlay(alignment: .leading) { Capsule().fill(audioEngine.amplitude > 0.05 ? Color.green : Color.orange).frame(width: 250 * audioEngine.amplitude) }
                    }.transition(.move(edge: .bottom))
                }
                Spacer()
                Button(action: handleButtonPress) {
                    ZStack {
                        Capsule().fill(Color.white).frame(width: 200, height: 50)
                        if step == 4 { Text("Enter Aura").font(.headline).foregroundStyle(.black).opacity(audioEngine.amplitude > 0.05 ? 1.0 : 0.5) }
                        else { Text("Next").font(.headline).foregroundStyle(.black) }
                    }
                }
                .disabled(step == 4 && audioEngine.amplitude < 0.05)
                .padding(.bottom, 60)
            }
            .blur(radius: contentBlurRadius)
            if transitionGrainOpacity > 0 {
                Canvas { ctx, size in
                    let w = Double(size.width); let h = Double(size.height)
                    for _ in 0..<2000 {
                        let x = Double.random(in: 0...w); let y = Double.random(in: 0...h)
                        ctx.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.4)))
                    }
                }
                .ignoresSafeArea().opacity(transitionGrainOpacity)
            }
        }
    }
    
    func handleButtonPress() {
        if step == 4 {
            if audioEngine.amplitude > 0.05 {
                withAnimation(.easeIn(duration: 0.6)) { transitionGrainOpacity = 1.0; contentBlurRadius = 40.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { withAnimation { showTutorial = false } }
            } else { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        } else {
            withAnimation(.easeIn(duration: 0.2)) { transitionGrainOpacity = 1.0; contentBlurRadius = 20.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                step += 1
                withAnimation(.easeOut(duration: 0.5)) { transitionGrainOpacity = 0.0; contentBlurRadius = 0.0 }
            }
        }
    }
    
    func getBackground(step: Int, amp: Double, time: Double) -> AnyView {
        if step == 0 {
            return AnyView(Canvas { context, size in
                let w = Double(size.width); let h = Double(size.height); let cx = w/2; let cy = h/2; let r = 100.0 + (amp * 200.0)
                var p = Path(); p.addEllipse(in: CGRect(x: cx - r/2, y: cy - r/2, width: r, height: r))
                context.addFilter(.blur(radius: 40)); context.fill(p, with: .color(.green.opacity(0.3)))
            })
        } else if step == 1 {
            return AnyView(Canvas { context, size in
                let w = Double(size.width); let h = Double(size.height); let cy = h/2
                var p = Path(); p.move(to: CGPoint(x: 0, y: cy)); let step = 5.0; var x = 0.0
                while x < w { let rel = x/w; let yOff = sin(rel * 20.0 + time * 5.0) * (30.0 + (amp * 200.0)); p.addLine(to: CGPoint(x: x, y: cy + yOff)); x += step }
                context.stroke(p, with: .color(.blue), lineWidth: 3)
            })
        } else if step == 2 {
            return AnyView(Canvas { context, size in
                let w = Double(size.width); let h = Double(size.height); let cx = w/2; let cy = h/2
                let baseSize = 100.0; let rotationSpeed = time * (1.0 + amp * 5.0); let height = 120.0 + (amp * 100.0)
                var basePoints: [CGPoint] = []
                for i in 0..<4 {
                    let iD = Double(i); let angle = (iD / 4.0) * .pi * 2 + rotationSpeed
                    let x = cx + cos(angle) * baseSize; let y = cy + sin(angle) * baseSize * 0.4; basePoints.append(CGPoint(x: x, y: y + 50))
                }
                let apex = CGPoint(x: cx, y: cy - height + 50)
                for point in basePoints {
                    var line = Path(); line.move(to: point); line.addLine(to: apex)
                    context.stroke(line, with: .color(.orange), lineWidth: 2)
                }
                var base = Path()
                base.move(to: basePoints[0]); base.addLine(to: basePoints[1]); base.addLine(to: basePoints[2]); base.addLine(to: basePoints[3]); base.closeSubpath()
                context.stroke(base, with: .color(.orange.opacity(0.6)), lineWidth: 2)
            })
        } else { return AnyView(Color.black) }
    }
}

// MARK: - 7. MAIN APP
enum AppState { case intro, tutorial, main }

struct ContentView: View {
    @State private var engine = AuraEngine()
    @State private var appState: AppState = .intro
    @State private var showTutorial = false
    @State private var showGallery = false
    @State private var currentStyle: AuraStyle = .terrain
    @State private var memories: [AuraMemory] = []
    @State private var flashOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // MAIN APP
            ZStack {
                UniversalRenderer(style: currentStyle, history: engine.frequencyHistory, currentAmp: engine.amplitude).ignoresSafeArea()
                VStack {
                    HStack {
                        Button { withAnimation { showGallery.toggle() } } label: { LiquidIcon(systemName: "square.grid.2x2.fill", color: .gray, size: 50) }
                        Spacer()
                        VStack(spacing: 2) {
                            Text(engine.pitch).font(.system(size: 24, design: .monospaced)).bold().foregroundStyle(currentStyle.color).id(engine.pitch).contentTransition(.numericText()).animation(.default, value: engine.pitch)
                            Text("HZ: \(Int(engine.amplitude * 1000))").font(.caption2).foregroundStyle(.gray)
                        }
                        Spacer()
                        Button { capture() } label: { LiquidIcon(systemName: "camera.fill", color: .gray, size: 50) }
                    }
                    .padding(.horizontal, 20).padding(.top, 40)
                    Spacer()
                    
                    // PILL BAR
                    HStack(spacing: 25) {
                        ForEach(AuraStyle.allCases, id: \.self) { style in
                            Button { withAnimation { currentStyle = style } } label: {
                                LiquidIcon(systemName: style.icon, color: style.color, size: 55).scaleEffect(currentStyle == style ? 1.2 : 1.0).animation(.spring, value: currentStyle)
                            }
                        }
                    }
                    .padding(15)
                    .background(Capsule().fill(.ultraThinMaterial).overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)))
                    .padding(.bottom, 40)
                }
            }
            .opacity(appState == .main ? 1 : 0)
            
            if appState == .tutorial {
                EducationalTutorial(showTutorial: $showTutorial, audioEngine: engine)
                    .transition(.opacity).zIndex(2)
                    .onChange(of: showTutorial) { _, newValue in if !newValue { withAnimation { appState = .main } } }
            }
            
            if appState == .intro {
                IntroView(amp: Double(engine.amplitude)) { withAnimation { appState = .tutorial; showTutorial = true } }.transition(.opacity).zIndex(3)
            }
            Color.white.ignoresSafeArea().opacity(flashOpacity).allowsHitTesting(false).zIndex(4)
        }
        .sheet(isPresented: $showGallery) { GalleryView(memories: $memories) }
        .onAppear {
            engine.start()
            loadMemories()
        }
    }
    
    func capture() {
        flashOpacity = 1.0
        withAnimation(.easeOut(duration: 0.3)) { flashOpacity = 0.0 }
        let mem = AuraMemory(date: Date(), style: currentStyle, history: engine.frequencyHistory)
        memories.insert(mem, at: 0)
        saveMemories()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    func saveMemories() { if let data = try? JSONEncoder().encode(memories) { UserDefaults.standard.set(data, forKey: "aura_v6_db") } }
    func loadMemories() { if let data = UserDefaults.standard.data(forKey: "aura_v6_db"), let decoded = try? JSONDecoder().decode([AuraMemory].self, from: data) { memories = decoded } }
}

// MARK: - 8. GALLERY
struct GalleryView: View {
    @Binding var memories: [AuraMemory]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if memories.isEmpty { ContentUnavailableView("No Scans", systemImage: "waveform", description: Text("Capture audio data in the studio.")) } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(), GridItem()], spacing: 15) {
                            ForEach(memories) { mem in
                                ZStack(alignment: .topTrailing) {
                                    UniversalRenderer(style: mem.style, history: mem.history, currentAmp: 1.0)
                                        .frame(height: 160).background(Color.black).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2), lineWidth: 1))
                                        .overlay(alignment: .bottomLeading) { Text(mem.style.rawValue.uppercased()).font(.caption2.bold()).foregroundStyle(.white).padding(8).background(.ultraThinMaterial, in: Capsule()).padding(8) }
                                    
                                    Button {
                                        withAnimation {
                                            if let idx = memories.firstIndex(where: { $0.id == mem.id }) {
                                                memories.remove(at: idx)
                                                if let data = try? JSONEncoder().encode(memories) { UserDefaults.standard.set(data, forKey: "aura_v6_db") }
                                            }
                                        }
                                    } label: { Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.white, .red).padding(8) }
                                }
                            }
                        }.padding()
                    }
                }
            }
            .navigationTitle("Data Log").navigationBarTitleDisplayMode(.inline).toolbar { Button("Close") { dismiss() } }
        }
    }
}
