// Web routes for 내 맵. They must NOT start with /question-sets: the API serves that prefix on the
// same origin, so a reload or shared link to /question-sets/<x> would reach the API (401 JSON)
// instead of the page.
export const mapPaths = {
  list: "/maps",
  create: "/maps/new",
  store: "/maps/store",
  edit: (id: string) => `/maps/${id}`,
} as const;
