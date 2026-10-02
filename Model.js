.pragma library

var order = {bad: 0, warn: 1, unknown: 2, ok: 3, skipped: 4}
var labels = {bad: "Problem", warn: "Attention", unknown: "Unavailable", ok: "Healthy", skipped: "Not checked"}
var domains = [
    {key: "cpu", title: "Processor", metric: "cpu_pct", unit: "%", caption: "processor activity", color: "#b6ef96", check: "cpu"},
    {key: "ram", title: "Memory", metric: "ram_available_gib", unit: "GiB", caption: "available headroom", color: "#79d4df", check: "memory"},
    {key: "disk", title: "Storage", metric: "disk_used_pct", unit: "%", caption: "root filesystem used", color: "#efbd7a", check: "storage"},
    {key: "gpu", title: "Graphics", metric: "gpu_pct", unit: "%", caption: "graphics activity", color: "#a9baf0", check: "gpu"}
]
function validRow(row) {
    return row && typeof row.id === "string" && typeof row.title === "string" && typeof row.summary === "string"
        && order[row.state] !== undefined && typeof row.domain === "string" && typeof row.metrics === "object"
}
function sorted(rows) {
    return rows.slice().sort(function(a,b) { return order[a.state] - order[b.state] || a.title.localeCompare(b.title) })
}
function counts(rows) {
    var result = {ok:0,warn:0,bad:0,unknown:0,skipped:0}
    rows.forEach(function(row) { if (result[row.state] !== undefined) result[row.state]++ })
    return result
}
function state(rows, complete) {
    var c = counts(rows)
    if (c.bad) return "bad"
    if (c.warn) return "warn"
    if (!complete || c.unknown || !c.ok) return "unknown"
    return "ok"
}
function domainState(rows, domain) {
    var matches = rows.filter(function(row) { return row.domain === domain })
    return state(matches, matches.length > 0)
}
function reading(metrics, key) {
    var value = metrics[key]
    if (typeof value !== "number" || !isFinite(value)) return "—"
    return value.toFixed(key.indexOf("gib") >= 0 ? 1 : 0)
}
function stamp(ts) {
    if (!ts) return "Not yet checked"
    return new Date(ts * 1000).toLocaleString()
}
function elapsed(ts, now) {
    if (!ts) return "never"
    var seconds = Math.max(0, Math.round(now - ts))
    if (seconds < 5) return "just now"
    if (seconds < 60) return seconds + "s ago"
    if (seconds < 3600) return Math.floor(seconds / 60) + "m ago"
    return Math.floor(seconds / 3600) + "h ago"
}
function mergeRows(rows, row) {
    var next = rows.filter(function(r) { return r.id !== row.id }); next.push(row); return next
}
function series(samples, key) {
    return samples.filter(function(s) { return s && s.metrics && typeof s.metrics[key] === "number" && isFinite(s.metrics[key]) })
                  .map(function(s) { return {time:s.timestamp, value:s.metrics[key]} })
}
