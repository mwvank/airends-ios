// The app's backend: a single HTTPS endpoint that proxies the few Google Maps
// Platform calls the app needs, so the paid API key never ships in the app.
//
//   POST /places       { query, latitude?, longitude?, date? }  -> { places }  (with date: each place's hours that day)
//   POST /hours        { placeIds, date: "YYYY-MM-DD" }        -> { hours: { [placeId]: [{ open, close }] } }
//   POST /travelTimes  { points: [{ latitude, longitude }], departureTime? } -> { seconds: number|null[][] }

import { initializeApp } from "firebase-admin/app";
import { getAppCheck } from "firebase-admin/app-check";
import { defineBoolean, defineSecret } from "firebase-functions/params";
import { onRequest, Request } from "firebase-functions/v2/https";
import type { Response } from "express";
import { GoogleError, LatLng, placeHours, searchPlaces, travelTimeMatrix } from "./google";
import { parseDate, rangesForDay, TimeRange } from "./hours";
import { TtlCache, RateLimiter } from "./limits";

initializeApp();

const mapsApiKey = defineSecret("MAPS_API_KEY");
// Turn on once the app ships with Firebase App Check (App Attest), so only the real app can call this.
const enforceAppCheck = defineBoolean("ENFORCE_APP_CHECK", { default: false });

const MAX_POINTS = 10; // 10 x 10 = 100 elements, Google's limit for traffic-aware matrices
const MAX_PLACE_IDS = 10;

const rateLimiter = new RateLimiter(60, 60_000); // per client IP, per instance
const hoursCache = new TtlCache<TimeRange[]>(6 * 60 * 60_000);
const matrixCache = new TtlCache<(number | null)[][]>(10 * 60_000);

class BadRequest extends Error {}

function isLatLng(value: unknown): value is LatLng {
  const v = value as LatLng;
  return (
    typeof v === "object" && v !== null &&
    typeof v.latitude === "number" && Math.abs(v.latitude) <= 90 &&
    typeof v.longitude === "number" && Math.abs(v.longitude) <= 180
  );
}

async function handlePlaces(body: Record<string, unknown>, key: string) {
  const query = typeof body.query === "string" ? body.query.trim() : "";
  if (query.length === 0 || query.length > 200) throw new BadRequest("query must be 1-200 characters");
  const near = { latitude: body.latitude, longitude: body.longitude };
  const date = typeof body.date === "string" ? parseDate(body.date) : null;
  if (body.date !== undefined && !date) throw new BadRequest("date must be YYYY-MM-DD");

  const found = await searchPlaces(key, query, isLatLng(near) ? near : undefined, date !== null);
  const places = found.map(({ openingHours, ...place }) => {
    if (!date || !openingHours) return place;
    const hours = rangesForDay(
      openingHours.currentOpeningHours ?? openingHours.regularOpeningHours, date, openingHours.utcOffsetMinutes ?? 0);
    // Saves a separate paid hours lookup if the user then picks this place.
    hoursCache.set(`${place.id}:${body.date}`, hours);
    return { ...place, hours };
  });
  return { places };
}

async function handleHours(body: Record<string, unknown>, key: string) {
  const date = typeof body.date === "string" ? parseDate(body.date) : null;
  if (!date) throw new BadRequest("date must be YYYY-MM-DD");
  const ids = body.placeIds;
  if (!Array.isArray(ids) || ids.length === 0 || ids.length > MAX_PLACE_IDS ||
      !ids.every((id) => typeof id === "string" && /^[A-Za-z0-9_-]{1,300}$/.test(id))) {
    throw new BadRequest(`placeIds must be 1-${MAX_PLACE_IDS} place IDs`);
  }

  const hours: Record<string, TimeRange[]> = {};
  await Promise.all((ids as string[]).map(async (id) => {
    const cacheKey = `${id}:${body.date}`;
    const cached = hoursCache.get(cacheKey);
    if (cached) {
      hours[id] = cached;
      return;
    }
    const details = await placeHours(key, id);
    const ranges = rangesForDay(details.currentOpeningHours ?? details.regularOpeningHours, date, details.utcOffsetMinutes ?? 0);
    hoursCache.set(cacheKey, ranges);
    hours[id] = ranges;
  }));
  return { hours };
}

async function handleTravelTimes(body: Record<string, unknown>, key: string) {
  const points = body.points;
  if (!Array.isArray(points) || points.length < 2 || points.length > MAX_POINTS || !points.every(isLatLng)) {
    throw new BadRequest(`points must be 2-${MAX_POINTS} coordinates`);
  }
  let departure: Date | undefined;
  if (body.departureTime !== undefined) {
    departure = new Date(String(body.departureTime));
    if (Number.isNaN(departure.getTime())) throw new BadRequest("departureTime must be an ISO date");
  }

  // Round to ~100 m and 10 minutes so repeated re-plans reuse the same result.
  const slot = departure ? Math.round(departure.getTime() / 600_000) : Math.round(Date.now() / 600_000);
  const cacheKey = (points as LatLng[]).map((p) => `${p.latitude.toFixed(3)},${p.longitude.toFixed(3)}`).join("|") + `@${slot}`;
  const cached = matrixCache.get(cacheKey);
  if (cached) return { seconds: cached };

  const seconds = await travelTimeMatrix(key, points as LatLng[], departure);
  matrixCache.set(cacheKey, seconds);
  return { seconds };
}

const routes: Record<string, (body: Record<string, unknown>, key: string) => Promise<unknown>> = {
  "/places": handlePlaces,
  "/hours": handleHours,
  "/travelTimes": handleTravelTimes,
};

async function verifyAppCheck(req: Request): Promise<boolean> {
  if (!enforceAppCheck.value()) return true;
  const token = req.header("X-Firebase-AppCheck");
  if (!token) return false;
  try {
    await getAppCheck().verifyToken(token);
    return true;
  } catch {
    return false;
  }
}

export const api = onRequest(
  { region: "us-central1", secrets: [mapsApiKey], maxInstances: 10, cors: false },
  async (req: Request, res: Response) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Use POST" });
      return;
    }
    const handler = routes[req.path];
    if (!handler) {
      res.status(404).json({ error: "Not found" });
      return;
    }
    if (!(await verifyAppCheck(req))) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }
    if (!rateLimiter.allow(req.ip ?? "unknown")) {
      res.status(429).json({ error: "Too many requests" });
      return;
    }

    try {
      const body = typeof req.body === "object" && req.body !== null ? (req.body as Record<string, unknown>) : {};
      res.json(await handler(body, mapsApiKey.value()));
    } catch (error) {
      if (error instanceof BadRequest) {
        res.status(400).json({ error: error.message });
      } else if (error instanceof GoogleError) {
        res.status(502).json({ error: "Maps service unavailable" });
      } else {
        console.error(error);
        res.status(500).json({ error: "Internal error" });
      }
    }
  },
);
