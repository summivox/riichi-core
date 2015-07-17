# base64
export function utf8_to_b64
  window.btoa unescape encodeURIComponent it
export function b64_to_utf8
  decodeURIComponent escape window.atob it
export function getDataURI
  'data:text/html;base64,' + utf8_to_b64 it

# escape HTML
# http://stackoverflow.com/a/12034334/4876553
entityMap =
  "&": "&amp;"
  "<": "&lt;"
  ">": "&gt;"
  '"': '&quot;'
  "'": '&#39;'
  "/": '&#x2F;'
export function escapeHTML
  String(it).replace /[&<>"'\/]/g, (entityMap.)
