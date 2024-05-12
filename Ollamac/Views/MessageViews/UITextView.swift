import SwiftUI
import Highlightr

struct HighlightedCodeBlock: View {
    let code: String
    let theme: String
    
    var body: some View {
        let highlightr = Highlightr()
        highlightr?.setTheme(to: theme)
        
        let highlightedCode: NSAttributedString
        if let attributedString = highlightr?.highlight(code) {
            highlightedCode = attributedString
        } else {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ]
            highlightedCode = NSAttributedString(string: code, attributes: attributes)
        }
        
        return Text(AttributedString(highlightedCode))
            .textSelection(.enabled)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
    }
}
