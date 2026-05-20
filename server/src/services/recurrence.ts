import { prisma } from '../lib/prisma.js'
import { generateUniqueEventCode } from '../lib/event-code.js'
import { RecurrenceFrequency, Prisma } from '../generated/prisma/index.js'
import crypto from 'crypto'

// Default limits for recurring events
const RECURRENCE_LIMITS: Record<RecurrenceFrequency, number> = {
  NONE: 1,
  DAILY: 90,      // 90 days
  WEEKLY: 52,     // 52 weeks (1 year)
  BIWEEKLY: 52,   // 52 instances (2 years)
  MONTHLY: 24,    // 24 months (2 years)
  YEARLY: 5,      // 5 years
}

/**
 * Advance a date based on recurrence frequency
 */
function advanceDate(date: Date, frequency: RecurrenceFrequency): Date {
  const newDate = new Date(date)

  switch (frequency) {
    case 'DAILY':
      newDate.setDate(newDate.getDate() + 1)
      break
    case 'WEEKLY':
      newDate.setDate(newDate.getDate() + 7)
      break
    case 'BIWEEKLY':
      newDate.setDate(newDate.getDate() + 14)
      break
    case 'MONTHLY':
      newDate.setMonth(newDate.getMonth() + 1)
      break
    case 'YEARLY':
      newDate.setFullYear(newDate.getFullYear() + 1)
      break
    default:
      break
  }

  return newDate
}

/**
 * Fields to copy from parent event to child instances
 */
const COPYABLE_FIELDS = [
  'groupId',
  'type',
  'title',
  'description',
  'startTime',
  'endTime',
  'isAllDay',
  'timezone',
  'coverImageUrl',
  'externalUrl',
  'visibility',
  'locationName',
  'locationAddress',
  'locationLat',
  'locationLng',
  'googlePlaceId',
  'alertMinutesBefore',
  'createdById',
] as const

interface RecurrenceOptions {
  frequency: RecurrenceFrequency
  endDate?: Date
  count?: number
}

/**
 * Generate recurring event instances from a parent event
 * Returns the created events including the parent
 */
export async function generateRecurringEvents(
  parentEventId: string,
  options: RecurrenceOptions
): Promise<{ count: number; recurrenceGroupId: string }> {
  const { frequency, endDate, count } = options

  if (frequency === 'NONE') {
    throw new Error('Cannot generate recurrence for NONE frequency')
  }

  // Fetch the parent event
  const parentEvent = await prisma.event.findUnique({
    where: { id: parentEventId },
  })

  if (!parentEvent) {
    throw new Error('Parent event not found')
  }

  // Generate recurrence group ID
  const recurrenceGroupId = crypto.randomUUID()

  // Update parent event with recurrence info
  await prisma.event.update({
    where: { id: parentEventId },
    data: {
      recurrenceFrequency: frequency,
      recurrenceEndDate: endDate,
      recurrenceCount: count,
      recurrenceGroupId,
      isRecurrenceParent: true,
    },
  })

  // Calculate max instances
  const maxInstances = count || RECURRENCE_LIMITS[frequency]

  // Generate child events
  const childEvents: Prisma.EventCreateManyInput[] = []
  let currentDate = advanceDate(new Date(parentEvent.date), frequency)
  let instanceCount = 1 // Parent is instance 0

  while (instanceCount < maxInstances) {
    // Stop if we've passed the end date
    if (endDate && currentDate > endDate) {
      break
    }

    // Generate unique code for this instance
    const code = await generateUniqueEventCode()

    // Build child event data with required fields from parent
    const childData: Prisma.EventCreateManyInput = {
      id: crypto.randomUUID(),
      code,
      groupId: parentEvent.groupId,
      type: parentEvent.type,
      title: parentEvent.title,
      date: currentDate,
      recurrenceGroupId,
      recurrenceFrequency: frequency,
      isRecurrenceParent: false,
      isActive: true,
    }

    // Copy optional fields from parent
    for (const field of COPYABLE_FIELDS) {
      const value = parentEvent[field]
      if (value !== null && value !== undefined) {
        ;(childData as any)[field] = value
      }
    }

    childEvents.push(childData)

    currentDate = advanceDate(currentDate, frequency)
    instanceCount++
  }

  // Batch create child events
  if (childEvents.length > 0) {
    await prisma.event.createMany({
      data: childEvents,
    })
  }

  return {
    count: instanceCount, // Total including parent
    recurrenceGroupId,
  }
}

/**
 * Update all future events in a recurrence series
 */
export async function updateRecurrenceSeries(
  eventId: string,
  data: Prisma.EventUpdateInput,
  updateScope: 'this' | 'future' | 'all'
): Promise<{ updatedCount: number }> {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
  })

  if (!event) {
    throw new Error('Event not found')
  }

  if (!event.recurrenceGroupId) {
    // Single event, just update it
    await prisma.event.update({
      where: { id: eventId },
      data,
    })
    return { updatedCount: 1 }
  }

  // Remove fields that shouldn't be batch-updated
  const safeData = { ...data }
  delete safeData.id
  delete safeData.code
  delete safeData.recurrenceGroupId
  delete safeData.isRecurrenceParent

  let whereClause: Prisma.EventWhereInput = {
    recurrenceGroupId: event.recurrenceGroupId,
    isActive: true,
  }

  switch (updateScope) {
    case 'this':
      // Just update this event
      await prisma.event.update({
        where: { id: eventId },
        data: safeData,
      })
      return { updatedCount: 1 }

    case 'future':
      // Update this event and all future events
      whereClause = {
        ...whereClause,
        date: { gte: event.date },
      }
      break

    case 'all':
      // Update all events in the series
      // whereClause is already set for all events in series
      break
  }

  const result = await prisma.event.updateMany({
    where: whereClause,
    data: safeData as Prisma.EventUpdateManyMutationInput,
  })

  return { updatedCount: result.count }
}

/**
 * Delete events in a recurrence series
 */
export async function deleteRecurrenceSeries(
  eventId: string,
  deleteScope: 'this' | 'future' | 'all'
): Promise<{ deletedCount: number }> {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
  })

  if (!event) {
    throw new Error('Event not found')
  }

  if (!event.recurrenceGroupId) {
    // Single event, just soft delete it
    await prisma.event.update({
      where: { id: eventId },
      data: { isActive: false },
    })
    return { deletedCount: 1 }
  }

  let whereClause: Prisma.EventWhereInput = {
    recurrenceGroupId: event.recurrenceGroupId,
    isActive: true,
  }

  switch (deleteScope) {
    case 'this':
      // Just delete this event
      await prisma.event.update({
        where: { id: eventId },
        data: { isActive: false },
      })
      return { deletedCount: 1 }

    case 'future':
      // Delete this event and all future events
      whereClause = {
        ...whereClause,
        date: { gte: event.date },
      }
      break

    case 'all':
      // Delete all events in the series
      // whereClause is already set
      break
  }

  const result = await prisma.event.updateMany({
    where: whereClause,
    data: { isActive: false },
  })

  return { deletedCount: result.count }
}

/**
 * Get all events in a recurrence series
 */
export async function getRecurrenceSeries(recurrenceGroupId: string) {
  return prisma.event.findMany({
    where: {
      recurrenceGroupId,
      isActive: true,
    },
    orderBy: { date: 'asc' },
  })
}
