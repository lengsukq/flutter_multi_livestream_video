/** Domain panels request orchestration without importing the page controller. */
export function requestRefresh() {
  return new Promise((resolve) => {
    document.dispatchEvent(new CustomEvent('dashboard:refresh', { detail: resolve }));
  });
}
