import { describe, expect, it } from 'vitest'
import { lessonAvailability } from '../lesson-availability'
import { zonedMidnight } from '../../utils/timezone'

const TZ = 'America/Chicago'
const lesson = zonedMidnight('2035-01-10', TZ) // Wed Jan 10, 00:00 Chicago

describe('lessonAvailability (D4, D15)', () => {
  it('ALL_AT_ONCE is open on any day', () => {
    expect(lessonAvailability(lesson, { lessonAccess: 'ALL_AT_ONCE', timezone: TZ }, new Date('2035-01-01T12:00:00Z'))).toEqual({ available: true })
  })

  it('ONE_AT_A_TIME is closed before its day, with the date and message', () => {
    expect(lessonAvailability(lesson, { lessonAccess: 'ONE_AT_A_TIME', timezone: TZ }, new Date('2035-01-10T05:59:00Z'))).toEqual({
      available: false, availableOn: '2035-01-10', message: 'This lesson is available on Wednesday, January 10',
    })
  })

  it('ONE_AT_A_TIME opens at 00:00 on its day in the enrollment zone', () => {
    expect(lessonAvailability(lesson, { lessonAccess: 'ONE_AT_A_TIME', timezone: TZ }, new Date('2035-01-10T06:00:00Z')).available).toBe(true)
  })

  it('a null timezone reads UTC', () => {
    const utcLesson = zonedMidnight('2035-01-10', 'UTC')
    expect(lessonAvailability(utcLesson, { lessonAccess: 'ONE_AT_A_TIME', timezone: null }, new Date('2035-01-09T23:00:00Z')).available).toBe(false)
    expect(lessonAvailability(utcLesson, { lessonAccess: 'ONE_AT_A_TIME', timezone: null }, new Date('2035-01-10T00:00:00Z')).available).toBe(true)
  })
})
