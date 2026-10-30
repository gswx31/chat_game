/**
 * Address of a room's page in the web client.
 *
 * NOT `/rooms/:id`: on the same origin the server answers `GET /rooms/{id}` with the room's JSON,
 * so reloading a page at that address (iPhone Safari does this to a tab you left for a while)
 * would show raw JSON instead of the game. `/room/:id` is not an API path, so a reload falls
 * through to the web client.
 */
export const roomPath = (roomId: string): string => `/room/${roomId}`;
