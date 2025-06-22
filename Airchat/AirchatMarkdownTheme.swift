//
//  AirchatMarkdownTheme.swift
//  Airchat
//
//  Created by Claude on 2025/6/22.
//

import SwiftUI
import MarkdownUI

extension Theme {
    static let airchat = Theme()
        .text {
            ForegroundColor(.primary)
            FontSize(14)
        }
        .strong {
            FontWeight(.bold)
        }
        .emphasis {
            FontStyle(.italic)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(12)
            BackgroundColor(Color.gray.opacity(0.2))
            ForegroundColor(.primary)
        }
        .codeBlock { configuration in
            VStack(alignment: .leading, spacing: 4) {
                if let language = configuration.language {
                    HStack {
                        Text(language)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    configuration.label
                        .relativeLineSpacing(.em(0.225))
                        .markdownMargin(top: 0, bottom: 16)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .markdownMargin(top: 0, bottom: 16)
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: 24, bottom: 16)
                .markdownTextStyle {
                    FontSize(24)
                    FontWeight(.bold)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: 20, bottom: 12)
                .markdownTextStyle {
                    FontSize(20)
                    FontWeight(.bold)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: 16, bottom: 8)
                .markdownTextStyle {
                    FontSize(16)
                    FontWeight(.semibold)
                }
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 0)
        }
        .taskListMarker { configuration in
            Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isCompleted ? .accentColor : .secondary)
                .imageScale(.small)
        }
        .blockquote { configuration in
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(.secondary)
                        FontStyle(.italic)
                    }
            }
            .markdownMargin(top: 8, bottom: 8)
        }
        .table { configuration in
            configuration.label
                .markdownTableBorderStyle(.init(color: .secondary.opacity(0.3)))
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.gray.opacity(0.05), Color.clear)
                )
                .markdownMargin(top: 12, bottom: 12)
        }
        .link {
            ForegroundColor(.accentColor)
            UnderlineStyle(.single)
        }
        .strikethrough {
            StrikethroughStyle(.single)
        }
}