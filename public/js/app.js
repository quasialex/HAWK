async function msfSearch(q) {
  const res = await fetch(`/api/msf/search?q=${encodeURIComponent(q)}`);
  if (!res.ok) return [];
  return await res.json();
}
