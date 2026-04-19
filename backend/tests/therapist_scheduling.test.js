const test = require('node:test');
const assert = require('node:assert/strict');
const { DateTime } = require('luxon');

const {
  buildSlotId,
  computeNextAvailableAt,
  generateSlotsForDateRange,
  normalizeAvailabilityExceptions,
  normalizeWeeklyRules,
} = require('../therapist_scheduling');

test('generateSlotsForDateRange materializes weekday slots and preserves active bookings', () => {
  const timezone = 'Asia/Karachi';
  const startDateKey = '2026-04-13';
  const weeklyRules = normalizeWeeklyRules([
    {
      weekday: 1,
      enabled: true,
      startTime: '09:00',
      endTime: '11:30',
    },
  ]);
  const bookedSlotId = buildSlotId(startDateKey, '09:00');
  const now = DateTime.fromISO('2026-04-10T00:00:00.000Z').setZone(timezone);
  const generated = generateSlotsForDateRange({
    timezone,
    weeklyRules,
    exceptions: [],
    sessionDurationMinutes: 60,
    bufferMinutes: 15,
    startDateKey,
    horizonDays: 1,
    existingSlots: new Map([
      [
        bookedSlotId,
        {
          slotId: bookedSlotId,
          status: 'booked',
          appointmentId: 'apt-booked',
        },
      ],
    ]),
    now,
  });

  assert.equal(generated.length, 2);
  assert.equal(generated[0].slotId, bookedSlotId);
  assert.equal(generated[0].status, 'booked');
  assert.equal(generated[0].appointmentId, 'apt-booked');
  assert.equal(generated[1].status, 'open');
  assert.equal(
    generated[1].startAt.toISOString(),
    '2026-04-13T05:15:00.000Z',
  );

  const nextAvailableAt = computeNextAvailableAt(
    generated,
    now.toUTC().toJSDate(),
  );
  assert.equal(nextAvailableAt.toISOString(), '2026-04-13T05:15:00.000Z');
});

test('blocked date exceptions remove slots for that date', () => {
  const generated = generateSlotsForDateRange({
    timezone: 'Asia/Karachi',
    weeklyRules: normalizeWeeklyRules([
      {
        weekday: 1,
        enabled: true,
        startTime: '09:00',
        endTime: '12:00',
      },
    ]),
    exceptions: normalizeAvailabilityExceptions([
      {
        dateKey: '2026-04-13',
        blocked: true,
        note: 'Clinic closed',
      },
    ]),
    sessionDurationMinutes: 60,
    bufferMinutes: 15,
    startDateKey: '2026-04-13',
    horizonDays: 1,
    existingSlots: new Map(),
    now: DateTime.fromISO('2026-04-10T00:00:00.000Z').setZone('Asia/Karachi'),
  });

  assert.deepEqual(generated, []);
});
