elow is a pragmatic recipe you can drop straight into your project. I’ve split it into two flavours—pure-AppKit and SwiftUI-first—so you can pick whichever matches your code base. Both rely on a single window whose frame is animated between a collapsed and an expanded rectangle; everything else (corner-radius, blur, content opacity…) just follows along.

1. Decide on two canonical frames
swift
复制
编辑
let collapsed   = NSSize(width: 66, height: 66)     // the little square in screenshot ①
let expanded    = NSSize(width: 400, height: 620)   // the full chat panel in screenshot ②
Keep only one NSWindow (or NSPanel). Moving the same window’s frame is far smoother than fading one window out and another in.

2A. AppKit implementation (Objective-C or Swift)
swift
复制
编辑
// Wherever you handle the ⌄ / ▢ button:
@IBAction func toggle(_ sender: Any?) {
    guard let win = view.window else { return }

    // isExpanded is your own Bool that tracks state
    isExpanded.toggle()

    // Calculate target rect so the top-left stays put:
    let targetSize  = isExpanded ? expanded : collapsed
    var targetFrame = win.frame
    targetFrame.origin.y += targetFrame.size.height - targetSize.height
    targetFrame.size      = targetSize

    // Animate!
    NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration        = 0.28            // tweak to taste
        ctx.timingFunction  = .init(name: .easeInEaseOut)
        win.animator()
           .setFrame(targetFrame, display: true)   // magic line ✨  :contentReference[oaicite:0]{index=0}
    }
}
Why this works
NSWindow.setFrame(_:display:animate:) (called via its animator() proxy) leverages Core Animation; macOS automatically tweens position, width, and height. Using NSAnimationContext lets you pick easing and duration. This is the exact API Apple uses for Quick Look, Safari settings sheets, etc. 
stackoverflow.com

2B. SwiftUI-friendly version (macOS 11+)
swift
复制
编辑
struct FloatingChat: NSViewControllerRepresentable {
    @Binding var isExpanded

    func makeNSViewController(context: Context) -> VC { VC(isExpanded) }
    func updateNSViewController(_ vc: VC, context: Context) { vc.isExpanded = isExpanded }

    final class VC: NSViewController {
        var isExpanded: Bool
        init(_ state: Bool) { self.isExpanded = state; super.init(nibName: nil, bundle: nil) }

        required init?(coder: NSCoder) { fatalError() }

        override func loadView() { view = NSView() }  // host SwiftUI later if you like

        func toggle() {
            isExpanded.toggle()

            let win = view.window!
            let size = isExpanded ? expanded : collapsed
            var f = win.frame; f.origin.y += f.height - size.height; f.size = size

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25; ctx.timingFunction = .init(name: .easeInEaseOut)
                win.animator().setFrame(f, display: true)
            }
        }
    }
}
Because window-level animation sits outside SwiftUI’s view graph, using withAnimation alone won’t cut it; the snippet above wraps the AppKit call and lets SwiftUI drive it with a simple @State isExpanded boolean. 
stackoverflow.com

Tip: if you want the little blue-bubble icon to morph into the chat header instead of disappearing, put both states inside the same SwiftUI hierarchy and link them with matchedGeometryEffect. Only the window frame animation needs AppKit glue. 
developer.apple.com

3. Polish the illusion
Detail	How
Corner radius	Animate it alongside the frame:
win.contentView?.layer?.cornerRadius = isExpanded ? 20 : 16 inside the same animation block.
Blur/“glass” effect	Use an NSVisualEffectView for the whole window background. macOS will automatically interpolate the blur as its bounds grow.
Shadow	Enable win.hasShadow = true; shadows are recalculated every frame.
Performance	Keep duration ≤ 0.3 s and use .easeInEaseOut for the most “native” feel. Large spring animations can lag when the window floats above every space.

4. Optional helper package
If you’d rather not hand-roll the math, the open-source WindowAnimation SPM package lets you bind a CGSize to a window and get spring animations out of the box. Add:

swift
复制
编辑
.package(url: "https://github.com/Lakr233/WindowAnimation", from: "1.0.0")
to Package.swift, then:

swift
复制
编辑
window.animator().resize(to: isExpanded ? expanded : collapsed, duration: 0.25)
``` :contentReference[oaicite:4]{index=4}

---

### That’s it!

With a single window, a quick `NSAnimationContext`, and (optionally) `matchedGeometryEffect` for internal elements, the small square will *bloom* into the full chat panel in one fluid motion—no jank, no flicker. Happy building!
::contentReference[oaicite:5]{index=5}