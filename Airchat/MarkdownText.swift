//
//  MarkdownText.swift
//  Airchat
//
//  Created by Claude on 2025/6/20.
//

import SwiftUI

struct MarkdownText: View {
    let text: String
    let isUserMessage: Bool
    
    init(_ text: String, isUserMessage: Bool = false) {
        self.text = text
        self.isUserMessage = isUserMessage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(groupElementsIntoLines(parseMarkdown(text)), id: \.id) { line in
                renderLine(line)
            }
        }
    }
    
    @ViewBuilder
    private func renderLine(_ line: MarkdownLine) -> some View {
        if line.isBlockElement && line.elements.count == 1 {
            // Render block elements normally
            renderElement(line.elements[0])
        } else {
            // Render inline elements in a horizontal flow
            Text(attributedString(from: line.elements))
                .textSelection(.enabled)
        }
    }
    
    private func attributedString(from elements: [MarkdownElement]) -> AttributedString {
        var result = AttributedString()
        
        for element in elements {
            var attributedText = AttributedString(element.content)
            
            switch element.type {
            case .bold:
                attributedText.font = .system(size: 14, weight: .bold)
            case .italic:
                attributedText.font = .system(size: 14).italic()
            case .code:
                attributedText.font = .system(.caption, design: .monospaced)
                attributedText.backgroundColor = Color.gray.opacity(0.2)
            default:
                attributedText.font = .system(size: 14)
            }
            
            result.append(attributedText)
        }
        
        return result
    }
    
    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element.type {
        case .text:
            Text(element.content)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .font(.system(size: 14))
            
        case .bold:
            Text(element.content)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .font(.system(size: 14, weight: .bold))
            
        case .italic:
            Text(element.content)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .font(.system(size: 14).italic())
            
        case .code:
            Text(element.content)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .textSelection(.enabled)
            
        case .codeBlock:
            VStack(alignment: .leading, spacing: 4) {
                if !element.language.isEmpty {
                    HStack {
                        Text(element.language)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(element.content)
                        .font(.system(.caption, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
        case .header1:
            Text(element.content)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.vertical, 4)
            
        case .header2:
            Text(element.content)
                .font(.title3.bold())
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.vertical, 2)
            
        case .header3:
            Text(element.content)
                .font(.headline)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.vertical, 2)
            
        case .listItem:
            HStack(alignment: .top, spacing: 12) {
                Text("•")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.accentColor)
                    .frame(width: 12, alignment: .center)
                
                Text(attributedString(from: parseInlineMarkdown(element.content)))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 8)
            
        case .numberedListItem:
            HStack(alignment: .top, spacing: 12) {
                Text("\(element.number).")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(minWidth: 24, alignment: .trailing)
                
                Text(attributedString(from: parseInlineMarkdown(element.content)))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 8)
            
        case .blockquote:
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                
                Text(element.content)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            
        case .thinking:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("思考过程")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Text(element.content)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Markdown Parser

struct MarkdownElement: Identifiable {
    let id = UUID()
    let type: MarkdownType
    let content: String
    let language: String
    let number: Int
}

struct MarkdownLine: Identifiable {
    let id = UUID()
    let elements: [MarkdownElement]
    let isBlockElement: Bool
}

enum MarkdownType {
    case text
    case bold
    case italic
    case code
    case codeBlock
    case header1
    case header2
    case header3
    case listItem
    case numberedListItem
    case blockquote
    case thinking
}

private func parseMarkdown(_ text: String) -> [MarkdownElement] {
    var elements: [MarkdownElement] = []
    let lines = text.components(separatedBy: .newlines)
    var i = 0
    var numberedListCounter = 1
    
    while i < lines.count {
        let line = lines[i].trimmingCharacters(in: .whitespaces)
        
        if line.isEmpty {
            i += 1
            continue
        }
        
        // Thinking blocks
        if line.hasPrefix("<thinking>") || line.hasPrefix("🤔") {
            var thinkingContent = ""
            if line.hasPrefix("<thinking>") {
                thinkingContent = String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces)
                i += 1
                
                while i < lines.count && !lines[i].contains("</thinking>") {
                    thinkingContent += "\n" + lines[i]
                    i += 1
                }
                
                if i < lines.count && lines[i].contains("</thinking>") {
                    let endIndex = lines[i].range(of: "</thinking>")?.lowerBound ?? lines[i].endIndex
                    thinkingContent += "\n" + String(lines[i][..<endIndex])
                }
            } else {
                thinkingContent = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
            
            if !thinkingContent.isEmpty {
                elements.append(MarkdownElement(
                    type: .thinking,
                    content: thinkingContent.trimmingCharacters(in: .whitespacesAndNewlines),
                    language: "",
                    number: 0
                ))
            }
            i += 1
            continue
        }
        
        // Code blocks
        if line.hasPrefix("```") {
            let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            var codeContent = ""
            i += 1
            
            while i < lines.count && !lines[i].hasPrefix("```") {
                codeContent += lines[i] + "\n"
                i += 1
            }
            
            if !codeContent.isEmpty {
                codeContent = String(codeContent.dropLast())
            }
            
            elements.append(MarkdownElement(
                type: .codeBlock,
                content: codeContent,
                language: language,
                number: 0
            ))
            i += 1
            continue
        }
        
        // Headers
        if line.hasPrefix("### ") {
            elements.append(MarkdownElement(
                type: .header3,
                content: String(line.dropFirst(4)),
                language: "",
                number: 0
            ))
        } else if line.hasPrefix("## ") {
            elements.append(MarkdownElement(
                type: .header2,
                content: String(line.dropFirst(3)),
                language: "",
                number: 0
            ))
        } else if line.hasPrefix("# ") {
            elements.append(MarkdownElement(
                type: .header1,
                content: String(line.dropFirst(2)),
                language: "",
                number: 0
            ))
        }
        // Blockquotes
        else if line.hasPrefix("> ") {
            elements.append(MarkdownElement(
                type: .blockquote,
                content: String(line.dropFirst(2)),
                language: "",
                number: 0
            ))
        }
        // Numbered headers (e.g., "1. 介绍", "2. 创作与生成")
        else if let match = line.range(of: #"^\d+\.\s+[^\s].*"#, options: .regularExpression) {
            let content = String(line[match.upperBound...])
            // If the content is short (likely a header) or looks like a title, treat as header
            if content.count <= 20 || !content.contains("：") && !content.contains(":") && !content.contains("。") {
                elements.append(MarkdownElement(
                    type: .header2, // Use header2 for numbered sections
                    content: String(line), // Include the number in the header
                    language: "",
                    number: 0
                ))
            } else {
                // Treat as numbered list item
                elements.append(MarkdownElement(
                    type: .numberedListItem,
                    content: content,
                    language: "",
                    number: numberedListCounter
                ))
                numberedListCounter += 1
            }
        }
        // List items (support -, *, and • characters)
        else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
            elements.append(MarkdownElement(
                type: .listItem,
                content: String(line.dropFirst(2)),
                language: "",
                number: 0
            ))
            numberedListCounter = 1 // Reset numbered list counter
        }
        // Regular text with inline formatting
        else {
            numberedListCounter = 1 // Reset numbered list counter
            let inlineElements = parseInlineMarkdown(line)
            elements.append(contentsOf: inlineElements)
        }
        
        i += 1
    }
    
    return elements
}

private func parseInlineMarkdown(_ text: String) -> [MarkdownElement] {
    var elements: [MarkdownElement] = []
    var currentText = text
    
    // Handle inline code first
    while let codeRange = currentText.range(of: #"`([^`]+)`"#, options: .regularExpression) {
        let beforeCode = String(currentText[..<codeRange.lowerBound])
        if !beforeCode.isEmpty {
            elements.append(contentsOf: parseTextFormatting(beforeCode))
        }
        
        let codeContent = String(currentText[codeRange])
        let cleanCode = String(codeContent.dropFirst().dropLast())
        elements.append(MarkdownElement(
            type: .code,
            content: cleanCode,
            language: "",
            number: 0
        ))
        
        currentText = String(currentText[codeRange.upperBound...])
    }
    
    if !currentText.isEmpty {
        elements.append(contentsOf: parseTextFormatting(currentText))
    }
    
    return elements
}

private func parseTextFormatting(_ text: String) -> [MarkdownElement] {
    let result = parseFormattingRecursive(text)
    return result.isEmpty ? [MarkdownElement(type: .text, content: text, language: "", number: 0)] : result
}

private func parseFormattingRecursive(_ text: String) -> [MarkdownElement] {
    var elements: [MarkdownElement] = []
    let currentText = text
    
    // Find the first occurrence of any formatting
    var earliestRange: Range<String.Index>?
    var earliestType: MarkdownType = .text
    var earliestPrefix = ""
    var earliestSuffix = ""
    
    // Check for bold (**text**)
    if let boldRange = currentText.range(of: #"\*\*([^*\n]+?)\*\*"#, options: .regularExpression) {
        earliestRange = boldRange
        earliestType = .bold
        earliestPrefix = "**"
        earliestSuffix = "**"
    }
    
    // Check for italic (*text*) but not if it's part of bold
    if let italicRange = currentText.range(of: #"(?<!\*)\*([^*\n]+?)\*(?!\*)"#, options: .regularExpression) {
        if earliestRange == nil || italicRange.lowerBound < earliestRange!.lowerBound {
            earliestRange = italicRange
            earliestType = .italic
            earliestPrefix = "*"
            earliestSuffix = "*"
        }
    }
    
    guard let range = earliestRange else {
        // No formatting found, return as plain text
        return currentText.isEmpty ? [] : [MarkdownElement(type: .text, content: currentText, language: "", number: 0)]
    }
    
    // Add text before the formatted section
    let beforeText = String(currentText[..<range.lowerBound])
    if !beforeText.isEmpty {
        elements.append(MarkdownElement(type: .text, content: beforeText, language: "", number: 0))
    }
    
    // Add the formatted section
    let formattedContent = String(currentText[range])
    let cleanContent = String(formattedContent.dropFirst(earliestPrefix.count).dropLast(earliestSuffix.count))
    elements.append(MarkdownElement(type: earliestType, content: cleanContent, language: "", number: 0))
    
    // Process the rest of the text
    let afterText = String(currentText[range.upperBound...])
    if !afterText.isEmpty {
        elements.append(contentsOf: parseFormattingRecursive(afterText))
    }
    
    return elements
}

private func groupElementsIntoLines(_ elements: [MarkdownElement]) -> [MarkdownLine] {
    var lines: [MarkdownLine] = []
    var currentLineElements: [MarkdownElement] = []
    
    for element in elements {
        let isBlockElement = [.header1, .header2, .header3, .listItem, .numberedListItem, .blockquote, .codeBlock, .thinking].contains(element.type)
        
        if isBlockElement {
            // Finish current line if it has content
            if !currentLineElements.isEmpty {
                lines.append(MarkdownLine(elements: currentLineElements, isBlockElement: false))
                currentLineElements = []
            }
            
            // Add block element as its own line
            lines.append(MarkdownLine(elements: [element], isBlockElement: true))
        } else {
            // Add to current line
            currentLineElements.append(element)
        }
    }
    
    // Add remaining inline elements
    if !currentLineElements.isEmpty {
        lines.append(MarkdownLine(elements: currentLineElements, isBlockElement: false))
    }
    
    return lines
}