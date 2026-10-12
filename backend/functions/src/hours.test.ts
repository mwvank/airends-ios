import { test } from "node:test";
import assert from "node:assert/strict";
import { parseDate, rangesForDay } from "./hours";

const monday = { year: 2026, month: 10, day: 12 }; // 12 Oct 2026 is a Monday
const eastern = -240; // UTC-4 (EDT)

test("regular hours match the weekday and convert to UTC", () => {
  const ranges = rangesForDay(
    {
      periods: [
        { open: { day: 1, hour: 8, minute: 0 }, close: { day: 1, hour: 21, minute: 30 } },
        { open: { day: 2, hour: 9, minute: 0 }, close: { day: 2, hour: 17, minute: 0 } },
      ],
    },
    monday,
    eastern,
  );
  assert.deepEqual(ranges, [{ open: "2026-10-12T12:00:00.000Z", close: "2026-10-13T01:30:00.000Z" }]);
});

test("dated current hours take holidays into account", () => {
  const ranges = rangesForDay(
    {
      periods: [
        {
          open: { day: 1, hour: 10, minute: 0, date: monday },
          close: { day: 1, hour: 14, minute: 0, date: monday },
        },
      ],
    },
    monday,
    eastern,
  );
  assert.deepEqual(ranges, [{ open: "2026-10-12T14:00:00.000Z", close: "2026-10-12T18:00:00.000Z" }]);
});

test("closing after midnight lands on the next day", () => {
  const ranges = rangesForDay(
    { periods: [{ open: { day: 1, hour: 18, minute: 0 }, close: { day: 2, hour: 2, minute: 0 } }] },
    monday,
    eastern,
  );
  assert.equal(ranges[0].close, "2026-10-13T06:00:00.000Z");
});

test("no close time means open 24 hours", () => {
  const ranges = rangesForDay({ periods: [{ open: { day: 0, hour: 0, minute: 0 } }] }, { year: 2026, month: 10, day: 11 }, 0);
  assert.deepEqual(ranges, [{ open: "2026-10-11T00:00:00.000Z", close: "2026-10-12T00:00:00.000Z" }]);
});

test("closed days and missing hours return nothing", () => {
  assert.deepEqual(rangesForDay({ periods: [] }, monday, eastern), []);
  assert.deepEqual(rangesForDay(undefined, monday, eastern), []);
});

test("parseDate validates input", () => {
  assert.deepEqual(parseDate("2026-10-12"), monday);
  assert.equal(parseDate("12/10/2026"), null);
  assert.equal(parseDate("2026-13-01"), null);
});
