// Thin wrappers around the Google Maps Platform APIs the app uses.
// The API key only ever lives here, on the server.

import { OpeningHours } from "./hours";

export interface LatLng {
  latitude: number;
  longitude: number;
}

export interface FoundPlace {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  /** Only present when the search asked for opening hours. */
  openingHours?: PlaceHours;
}

export class GoogleError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

async function call<T>(url: string, apiKey: string, fieldMask: string, body?: unknown): Promise<T> {
  const response = await fetch(url, {
    method: body === undefined ? "GET" : "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask": fieldMask,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    // Log Google's error for debugging but never return it (or the key) to the client.
    console.error("Google API error", response.status, await response.text());
    throw new GoogleError(response.status, "Upstream request failed");
  }
  return (await response.json()) as T;
}

/**
 * Text search for places by name, address or category, biased to the user's area.
 * Asking for opening hours makes the request a pricier Google tier, so only the
 * app's short "other places" list does that; typing in the search box doesn't.
 */
export async function searchPlaces(apiKey: string, query: string, near?: LatLng, withHours = false): Promise<FoundPlace[]> {
  interface Response {
    places?: ({
      id: string;
      displayName?: { text: string };
      formattedAddress?: string;
      location?: LatLng;
    } & PlaceHours)[];
  }
  const fields = ["places.id", "places.displayName", "places.formattedAddress", "places.location"];
  if (withHours) fields.push("places.currentOpeningHours", "places.regularOpeningHours", "places.utcOffsetMinutes");
  const result = await call<Response>(
    "https://places.googleapis.com/v1/places:searchText",
    apiKey,
    fields.join(","),
    {
      textQuery: query,
      pageSize: 10,
      ...(near && { locationBias: { circle: { center: near, radius: 20_000 } } }),
    },
  );
  return (result.places ?? [])
    .filter((p) => p.location)
    .map((p) => ({
      id: p.id,
      name: p.displayName?.text ?? query,
      address: p.formattedAddress ?? "",
      latitude: p.location!.latitude,
      longitude: p.location!.longitude,
      ...(withHours && {
        openingHours: {
          currentOpeningHours: p.currentOpeningHours,
          regularOpeningHours: p.regularOpeningHours,
          utcOffsetMinutes: p.utcOffsetMinutes,
        },
      }),
    }));
}

export interface PlaceHours {
  currentOpeningHours?: OpeningHours;
  regularOpeningHours?: OpeningHours;
  utcOffsetMinutes?: number;
}

/** Opening hours for one place (Place Details). */
export async function placeHours(apiKey: string, placeId: string): Promise<PlaceHours> {
  return call<PlaceHours>(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`,
    apiKey,
    "currentOpeningHours,regularOpeningHours,utcOffsetMinutes",
  );
}

/**
 * Traffic-aware driving times between every pair of points, in seconds.
 * `null` means no route was found.
 */
export async function travelTimeMatrix(apiKey: string, points: LatLng[], departure?: Date): Promise<(number | null)[][]> {
  interface Element {
    originIndex?: number;
    destinationIndex?: number;
    duration?: string; // e.g. "754s"
    condition?: string;
  }
  const waypoints = points.map((location) => ({ waypoint: { location: { latLng: location } } }));
  // Traffic predictions need a departure time that isn't in the past.
  const useDeparture = departure && departure.getTime() > Date.now() + 60_000;

  const elements = await call<Element[]>(
    "https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix",
    apiKey,
    "originIndex,destinationIndex,duration,condition",
    {
      origins: waypoints,
      destinations: waypoints,
      travelMode: "DRIVE",
      routingPreference: "TRAFFIC_AWARE",
      ...(useDeparture && { departureTime: departure!.toISOString() }),
    },
  );

  const matrix: (number | null)[][] = points.map(() => points.map(() => null));
  for (const element of elements) {
    const from = element.originIndex ?? 0;
    const to = element.destinationIndex ?? 0;
    if (from === to) {
      matrix[from][to] = 0;
    } else if (element.condition === "ROUTE_EXISTS" && element.duration) {
      matrix[from][to] = Number.parseInt(element.duration, 10);
    }
  }
  return matrix;
}
