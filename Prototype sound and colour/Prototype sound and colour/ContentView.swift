import SwiftUI
import AVFoundation

// MARK: - MODELLO PER IL TRATTO
struct Stroke {
    var color: Color
    var note: String
    var points: [CGPoint]
    var progress: CGFloat = 1.0  // Default a 1.0 per mostrare subito i nuovi tratti
}

// MARK: - SOUND MANAGER
class SoundManager {
    var audioPlayer: AVAudioPlayer?
    
    func playNote(_ note: String) {
        if let url = Bundle.main.url(forResource: note, withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
            } catch {
                print("Errore nella riproduzione di \(note).mp3: \(error)")
            }
        } else {
            print("File audio \(note).mp3 non trovato!")
        }
    }
    
    func stop() {
        audioPlayer?.stop()
    }
}

// MARK: - VIEWMODEL
class DrawingViewModel: ObservableObject {
    @Published var strokes: [Stroke] = []
    @Published var currentStroke: Stroke?
    @Published var currentColor: Color = .red
    @Published var currentNote: String = "C"
    
    var animationTimer: Timer?
    
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .indigo, .purple]
    let notes: [String] = ["C", "D", "E", "F", "G", "A", "B"]
    
    var soundManager = SoundManager()
    
    func startStroke(at point: CGPoint) {
        var newStroke = Stroke(color: currentColor, note: currentNote, points: [point])
        newStroke.progress = 1.0  // Mostra subito il tratto in fase di disegno
        currentStroke = newStroke
    }
    
    func addPoint(_ point: CGPoint) {
        currentStroke?.points.append(point)
    }
    
    func endStroke() {
        if let stroke = currentStroke {
            strokes.append(stroke)
        }
        currentStroke = nil
    }
    
    func clearCanvas() {
        strokes.removeAll()
    }
    
    // MARK: - Animazione Fluida del Disegno
    func playDrawingWithSmoothAnimation() {
        stopAnimation()  // Stop eventuali animazioni precedenti
        resetProgress()  // Reset progress per ogni tratto
        
        var strokeIndex = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            if strokeIndex < self.strokes.count {
                self.strokes[strokeIndex].progress += 0.02
                if self.strokes[strokeIndex].progress >= 1.0 {
                    self.strokes[strokeIndex].progress = 1.0
                    self.replayStroke(self.strokes[strokeIndex])
                    strokeIndex += 1  // Passa al tratto successivo
                }
            } else {
                self.stopAnimation()  // Ferma l'animazione alla fine
            }
        }
    }
    
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func resetProgress() {
        for index in strokes.indices {
            strokes[index].progress = 0.0
        }
        currentStroke?.progress = 1.0  // Continua a mostrare il tratto corrente
    }
    
    // Suona solo durante il Play Drawing
    private func replayStroke(_ stroke: Stroke) {
        soundManager.playNote(stroke.note)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.soundManager.stop()
        }
    }
}

// MARK: - CANVAS VIEW
struct DrawingCanvasView: View {
    @ObservedObject var viewModel: DrawingViewModel
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if viewModel.currentStroke == nil {
                            viewModel.startStroke(at: value.location)
                        } else {
                            viewModel.addPoint(value.location)
                        }
                    }
                    .onEnded { _ in
                        viewModel.endStroke()
                    }
                )
            
            ForEach(viewModel.strokes, id: \.points) { stroke in
                Path { path in
                    guard let firstPoint = stroke.points.first else { return }
                    path.move(to: firstPoint)
                    for (index, point) in stroke.points.enumerated() {
                        if CGFloat(index) / CGFloat(stroke.points.count) <= stroke.progress {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(stroke.color, lineWidth: 8)
            }
            
            if let currentStroke = viewModel.currentStroke {
                Path { path in
                    guard let firstPoint = currentStroke.points.first else { return }
                    path.move(to: firstPoint)
                    for point in currentStroke.points {
                        path.addLine(to: point)
                    }
                }
                .stroke(currentStroke.color, lineWidth: 8)
            }
        }
        .frame(width: 1000, height: 800)
        .border(Color.black)
    }
}

// MARK: - MAIN VIEW
struct ContentView: View {
    @StateObject var viewModel = DrawingViewModel()
    
    var body: some View {
        VStack {
            DrawingCanvasView(viewModel: viewModel)
            
            HStack {
                ForEach(0..<viewModel.colors.count, id: \.self) { index in
                    Button(action: {
                        viewModel.currentColor = viewModel.colors[index]
                        viewModel.currentNote = viewModel.notes[index]
                    }) {
                        Circle()
                            .fill(viewModel.colors[index])
                            .frame(width: 50, height: 50)
                    }
                }
            }
            .padding()
            
            HStack {
                Button("Play") {
                    viewModel.playDrawingWithSmoothAnimation()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Pulisci la tela") {
                    viewModel.clearCanvas()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}


#Preview {
    ContentView()
}


