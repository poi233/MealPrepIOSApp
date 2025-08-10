//
//  MarkdownText.swift
//  MealPrepIOSApp
//
//  Created by AI Assistant on 7/21/25.
//

import SwiftUI

struct MarkdownText: View {
    let content: String
    let font: Font
    let lineSpacing: CGFloat

    init(_ content: String, font: Font = .body, lineSpacing: CGFloat = 4) {
        self.content = content
        self.font = font
        self.lineSpacing = lineSpacing
    }

    var body: some View {
        if #available(iOS 15.0, *) {
            Text(attributedContent)
                .lineSpacing(lineSpacing)
        } else {
            Text(content)
                .font(font)
                .lineSpacing(lineSpacing)
        }
    }

    @available(iOS 15.0, *)
    private var attributedContent: AttributedString {
        do {
            var attributedString = try AttributedString(markdown: content)

            // Apply the base font to the entire string
            let range = attributedString.startIndex..<attributedString.endIndex
            attributedString[range].font = UIFont.systemFont(ofSize: 16) // Default body size

            return attributedString
        } catch {
            // Fallback to plain text if markdown parsing fails
            return AttributedString(content)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        MarkdownText("# Heading 1\n\n**Bold text** and *italic text*")

        MarkdownText("""
        ## Instructions

        1. **Prepare ingredients:** Wash and chop all vegetables
        2. *Heat the pan* over medium heat
        3. Add oil and cook for **5 minutes**

        > **Tip:** For best results, use fresh ingredients
        """)
    }
    .padding()
}