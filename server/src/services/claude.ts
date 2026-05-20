/**
 * Claude AI Service
 *
 * Wraps the Anthropic SDK for use across the application.
 */

import Anthropic from '@anthropic-ai/sdk'

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
})

// Available models — callers pick the right one for the task
export const CLAUDE_MODELS = {
  haiku: 'claude-haiku-4-5-20251001',
  sonnet: 'claude-sonnet-4-20250514',
  opus: 'claude-opus-4-20250514',
} as const

export type ClaudeModel = keyof typeof CLAUDE_MODELS

export { client as claudeClient }

export interface TagSuggestion {
  tags: string[]
}

/**
 * Suggest tags for a study program based on its full content.
 * Sends all lessons and activities to Claude and requests 5-10 descriptive tags.
 */
export async function suggestProgramTags(program: {
  name: string
  description?: string | null
  days: number
  lessons: {
    dayNumber: number
    title?: string | null
    activities: {
      activityType: string
      title: string
      referenceTitle?: string | null
      readContent?: string | null
      helpTitle?: string | null
      helpDescription?: string | null
    }[]
  }[]
}, model: ClaudeModel = 'sonnet'): Promise<TagSuggestion> {
  // Skip API call if there isn't enough content to analyze
  const totalActivities = program.lessons.reduce((sum, l) => sum + l.activities.length, 0)
  if (program.lessons.length < 2 || totalActivities < 3) {
    return { tags: [] }
  }

  const programSummary = buildProgramSummary(program)

  const message = await client.messages.create({
    model: CLAUDE_MODELS[model],
    max_tokens: 256,
    messages: [
      {
        role: 'user',
        content: `You are a Bible study and church curriculum expert. Analyze this study program and suggest 5 to 10 tags that describe its content, themes, and topics. Tags should be lowercase, 1-3 words each, and useful for categorization and search.

Return ONLY a JSON object with a "tags" array of strings. No other text.

Study Program:
${programSummary}`,
      },
    ],
  })

  const text = message.content[0].type === 'text' ? message.content[0].text : ''

  try {
    // Extract JSON from response (handle markdown code blocks)
    const jsonMatch = text.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      throw new Error('No JSON found in response')
    }
    const parsed = JSON.parse(jsonMatch[0])
    const tags = (parsed.tags || [])
      .map((t: string) => t.toLowerCase().trim())
      .filter((t: string) => t.length > 0)
      .slice(0, 10)

    return { tags }
  } catch {
    console.error('Failed to parse Claude tag response:', text)
    return { tags: [] }
  }
}

// ============================================================================
// Image Analysis
// ============================================================================

export interface ImageAnalysis {
  altText: string
  tags: string[]
}

/**
 * Analyze an image using Claude's vision capabilities.
 * Returns alt text and descriptive tags.
 *
 * Uses Haiku for cost efficiency — vision analysis doesn't need a large model.
 */
export async function analyzeImage(
  imageUrl: string,
  context?: { title?: string; usageContext?: string }
): Promise<ImageAnalysis> {
  const contextHint = context?.usageContext
    ? `\nThis image is used as: ${context.usageContext}.`
    : ''
  const titleHint = context?.title
    ? `\nThe image is titled: "${context.title}".`
    : ''

  const message = await client.messages.create({
    model: CLAUDE_MODELS.haiku,
    max_tokens: 300,
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'image',
            source: { type: 'url', url: imageUrl },
          },
          {
            type: 'text',
            text: `You are analyzing images for a Bible study and church group management app called MakeReady.${titleHint}${contextHint}

Provide:
1. A concise, descriptive alt text (1-2 sentences) suitable for screen readers.
2. 3-8 lowercase tags (1-3 words each) describing the image content, themes, setting, and mood.

Return ONLY a JSON object with "altText" (string) and "tags" (string array). No other text.`,
          },
        ],
      },
    ],
  })

  const text = message.content[0].type === 'text' ? message.content[0].text : ''

  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/)
    if (!jsonMatch) throw new Error('No JSON found')
    const parsed = JSON.parse(jsonMatch[0])

    return {
      altText: typeof parsed.altText === 'string' ? parsed.altText.trim() : '',
      tags: (parsed.tags || [])
        .map((t: string) => t.toLowerCase().trim())
        .filter((t: string) => t.length > 0)
        .slice(0, 8),
    }
  } catch {
    console.error('Failed to parse Claude image analysis:', text)
    return { altText: '', tags: [] }
  }
}

// ============================================================================
// Program Tag Suggestions
// ============================================================================

function buildProgramSummary(program: Parameters<typeof suggestProgramTags>[0]): string {
  const lines: string[] = [
    `Name: ${program.name}`,
    program.description ? `Description: ${program.description}` : '',
    `Duration: ${program.days} days`,
    '',
  ]

  for (const lesson of program.lessons) {
    lines.push(`--- Day ${lesson.dayNumber}${lesson.title ? `: ${lesson.title}` : ''} ---`)
    for (const activity of lesson.activities) {
      lines.push(`  [${activity.activityType}] ${activity.title}`)
      if (activity.referenceTitle) {
        lines.push(`    Reference: ${activity.referenceTitle}`)
      }
      if (activity.readContent) {
        // Truncate long content to avoid token bloat
        const content = activity.readContent.length > 500
          ? activity.readContent.slice(0, 500) + '...'
          : activity.readContent
        lines.push(`    Content: ${content}`)
      }
      if (activity.helpTitle) {
        lines.push(`    Help: ${activity.helpTitle}`)
      }
    }
  }

  return lines.filter(Boolean).join('\n')
}
