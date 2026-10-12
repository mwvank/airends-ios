// Converts Google Places opening hours into absolute time ranges for one day,
// so the app can compare them directly with arrival times.

export interface DatePoint {
  year: number;
  month: number;
  day: number;
}

export interface PeriodPoint {
  day: number; // 0 = Sunday
  hour: number;
  minute: number;
  date?: DatePoint;
}

export interface Period {
  open: PeriodPoint;
  close?: PeriodPoint;
}

export interface OpeningHours {
  periods?: Period[];
}

export interface TimeRange {
  open: string; // ISO 8601, UTC
  close: string;
}

/** Parses "YYYY-MM-DD". */
export function parseDate(value: string): DatePoint | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  const [year, month, day] = [Number(match[1]), Number(match[2]), Number(match[3])];
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return { year, month, day };
}

function sameDate(a: DatePoint, b: DatePoint): boolean {
  return a.year === b.year && a.month === b.month && a.day === b.day;
}

function dayOfWeek(date: DatePoint): number {
  return new Date(Date.UTC(date.year, date.month - 1, date.day)).getUTCDay();
}

/** The instant of a local wall-clock time at the place, given its UTC offset. */
function instant(date: DatePoint, hour: number, minute: number, utcOffsetMinutes: number): Date {
  return new Date(Date.UTC(date.year, date.month - 1, date.day, hour, minute) - utcOffsetMinutes * 60_000);
}

function addDays(date: DatePoint, days: number): DatePoint {
  const d = new Date(Date.UTC(date.year, date.month - 1, date.day + days));
  return { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() };
}

/**
 * Opening ranges that start on `target`. Uses dated periods (current hours,
 * which include holidays) when present, otherwise matches the weekday of
 * regular hours. A period without a close time means open 24 hours.
 */
export function rangesForDay(hours: OpeningHours | undefined, target: DatePoint, utcOffsetMinutes: number): TimeRange[] {
  const periods = hours?.periods ?? [];
  const weekday = dayOfWeek(target);

  const todays = periods.filter((p) => (p.open.date ? sameDate(p.open.date, target) : p.open.day === weekday));

  return todays.map((period) => {
    if (!period.close) {
      return {
        open: instant(target, 0, 0, utcOffsetMinutes).toISOString(),
        close: instant(addDays(target, 1), 0, 0, utcOffsetMinutes).toISOString(),
      };
    }
    const closeDate =
      period.close.date ?? addDays(target, (period.close.day - period.open.day + 7) % 7);
    return {
      open: instant(target, period.open.hour, period.open.minute, utcOffsetMinutes).toISOString(),
      close: instant(closeDate, period.close.hour, period.close.minute, utcOffsetMinutes).toISOString(),
    };
  });
}
