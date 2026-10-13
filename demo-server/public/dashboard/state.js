// Snapshot cache shared by independent dashboard renderers.
export const store = {
  rooms: [], chatRooms: [], providers: new Map(), chatProviders: new Map(),
  events: [], eventFilter: 'all', providerSelectionEnabled: true,
};
